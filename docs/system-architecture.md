# System Architecture: go-ethereum-trace

## High-Level Overview

**go-ethereum-trace** is a fork of go-ethereum with comprehensive traceability infrastructure layered on top. The architecture preserves upstream consensus-critical paths while adding orthogonal tracing capabilities.

```
┌──────────────────────────────────────────────────────────────┐
│                        RPC API Layer                          │
│  (debug_traceTransaction, debug_traceBlock, debug_traceCall)  │
└────────────────┬─────────────────────────────────────────────┘
                 │
         ┌───────▼────────────────────────────┐
         │  eth/tracers/api.go (TraceAPI)     │
         │  - Routes trace requests            │
         │  - Selects tracer (call, prestate) │
         │  - Manages state re-execution       │
         └───────┬────────────────────────────┘
                 │
    ┌────────────┼────────────────┐
    │            │                │
    ▼            ▼                ▼
  Tracer   State Re-execution   Hooks System
  Impl.     (state_processor)   (core/tracing)
            (VM + StateDB)


┌─────────────────────────────────────────────────────────────────────┐
│                    Core Tracing Infrastructure                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  core/tracing/hooks.go (Hooks struct)                              │
│  ├─ Function pointers for trace events                             │
│  ├─ OnEnter, OnExit (call frame lifecycle)                         │
│  ├─ OnBalanceChange, OnStorageChange (state mutations)             │
│  ├─ OnOpcode (EVM opcode execution)                                │
│  └─ Reason enums (typed mutation annotations)                      │
│                                                                     │
│  core/state/statedb_hooked.go (hookedStateDB wrapper)              │
│  ├─ Wraps original StateDB                                         │
│  ├─ Intercepts all state mutations                                 │
│  ├─ Fires hooks via core/tracing/Hooks                             │
│  └─ Zero overhead when hooks nil                                   │
│                                                                     │
│  core/tracing/journal.go (Journal)                                 │
│  ├─ Records state mutations in call stack                          │
│  ├─ On call revert: emits reverse events                           │
│  └─ Enables tracers to see "undo" operations                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                        Tracer Implementations                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  eth/tracers/native/call.go                                        │
│  └─ Hierarchical call tree: enter/exit events per call             │
│                                                                     │
│  eth/tracers/native/call_flat.go                                   │
│  └─ Flat call list (Parity-compatible)                             │
│                                                                     │
│  eth/tracers/native/prestate.go                                    │
│  └─ Pre/post state snapshots: accounts, storage, code              │
│                                                                     │
│  eth/tracers/native/4byte.go                                       │
│  └─ Function selector (4-byte prefix) frequency count              │
│                                                                     │
│  eth/tracers/native/mux.go                                         │
│  └─ Multi-tracer: combine multiple tracers in one pass             │
│                                                                     │
│  eth/tracers/js/goja.go                                            │
│  └─ JavaScript tracer: user-defined custom logic (Goja engine)     │
│                                                                     │
│  eth/tracers/live/supply.go                                        │
│  └─ Token supply tracker: balance deltas per address               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                     State & Storage Layer                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  core/state/statedb.go (StateDB - canonical state)                 │
│  ├─ Account & storage cache                                        │
│  ├─ Balance, nonce, code mutations                                 │
│  └─ Commit to trie & database                                      │
│                                                                     │
│  trie/ (Merkle Trie)                                               │
│  ├─ Account trie (address → account hash)                          │
│  ├─ Storage trie per account (slot → value hash)                   │
│  └─ Trie node hashing & persistence                                │
│                                                                     │
│  triedb/pathdb/ (Path-based Storage Engine)                        │
│  ├─ storage_layer.go: transient in-memory trie nodes               │
│  ├─ database_layer.go: persistent key-value storage                │
│  ├─ history_state.go: state history with reverse diffs             │
│  ├─ history_reader.go: query any historical block's state          │
│  └─ history_indexer*.go: block→state transition index              │
│                                                                     │
│  ethdb/ (Key-Value Database)                                       │
│  └─ Pebble (default), LevelDB (optional)                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                    EVM Execution Engine                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  core/vm/evm.go (EVM Executor)                                     │
│  ├─ Opcode dispatch & execution                                    │
│  ├─ Call/delegatecall/staticcall handling                          │
│  ├─ Transfer (with BalanceChangeReason)                            │
│  └─ Gas tracking & refunds                                         │
│                                                                     │
│  core/vm/operations.go                                             │
│  ├─ Individual opcode implementations (PUSH, ADD, SSTORE, etc.)    │
│  └─ Gas cost & stack effects                                       │
│                                                                     │
│  core/state_processor.go (Block Executor)                          │
│  ├─ For each transaction:                                          │
│  │  1. Create StateDB snapshot (or recovery state)                 │
│  │  2. Wrap StateDB with hooks if tracer configured                │
│  │  3. Execute TX against wrapped StateDB                          │
│  │  4. Commit or discard mutations                                 │
│  └─ Finalize with rewards & withdrawals                            │
│                                                                     │
│  core/vm/logic.go (Call Stack Management)                          │
│  ├─ Contract context (address, value, code)                        │
│  ├─ Call frame depth tracking                                      │
│  └─ Call lifecycle (enter/exit hooks fired here)                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Tracing Data Flow

Complete sequence for `debug_traceTransaction`:

```
1. RPC: debug_traceTransaction(txHash, config)
   └─ config.Tracer = "call" (or "prestate", "4byte", etc.)

2. eth/tracers/api.TraceTransaction(txHash, config)
   └─ Fetch block & transaction from database

3. Recover historical state at tx execution time
   └─ StateAtTransaction() → re-execute prior txs to reach state

4. Create tracer instance (based on config.Tracer)
   ├─ call.New() → creates Call tracer
   ├─ prestate.New() → creates Prestate tracer
   └─ ...

5. Create tracing.Hooks wired to tracer
   ├─ hooks.OnEnter → tracer.CaptureEnter()
   ├─ hooks.OnExit → tracer.CaptureExit()
   ├─ hooks.OnBalanceChange → tracer.CaptureBalanceChange()
   └─ ...

6. Get StateDB at block pre-state
   └─ state.NewStateDB(tridb.Database, stateRoot)

7. Wrap StateDB with hooks
   └─ statedb_hooked.NewHookedState(stateDB, hooks)

8. Re-execute transaction against hooked StateDB
   ├─ statedb_hooked intercepts all mutations
   ├─ Fires hooks (OnBalanceChange, OnStorageChange, etc.)
   ├─ Tracer consumes hook events in real-time
   └─ VM executes normally otherwise

9. Tracer builds result object
   └─ For call tracer: hierarchical call tree
   └─ For prestate: before/after state snapshots
   └─ For 4byte: frequency map

10. Return JSON to RPC client
```

## State Mutation Capture

When StateDB mutates, hooked wrapper fires hooks with **reasons**:

```
Transaction execution:
  TX cost (OnGasChange, GasChangeTxInitialGas)
  ↓
  Contract code loaded (OnCodeChange for deployed contracts)
  ↓
  CALL to contract A:
    OnEnter(depth=1, frame=callframe_A)
    ├─ Opcode SSTORE (OnStorageChange, StorageChangeReason=XXX)
    ├─ Opcode CALL to contract B (OnEnter, depth=2)
    │  ├─ Opcode SELFDESTRUCT (OnBalanceChange, BalanceChangeSelfDestruct)
    │  ├─ (reverse: journal records undo)
    │  └─ OnExit(depth=2, error=none)
    ├─ GasRefund logic (OnGasChange, GasChangeRefund)
    └─ OnExit(depth=1, result=bytes, error=none)

Result: Call tracer outputs hierarchical tree with reason annotations
```

## Reason Enums (Mutation Annotation)

Each state mutation is annotated with a **typed reason**:

```go
// BalanceChangeReason
type BalanceChangeReason int
const (
  BalanceChangeTransfer        // ETH transfer (sender → recipient)
  BalanceChangeSelfDestruct    // Contract self-destruct
  BalanceChangeGasRefund       // TX gas refund
  BalanceChangeTouchAccount    // Account touched (0-wei min)
  BalanceChangeMinerReward     // Block miner reward
  ...
)

// GasChangeReason
type GasChangeReason int
const (
  GasChangeTxInitialGas        // TX gas limit allocation
  GasChangeCallDataGas         // Calldata gas cost
  GasChangeOpFuel              // Opcode execution cost
  GasChangeOpLog               // LOG opcode cost
  GasChangeOpCreate            // CREATE opcode cost
  GasChangeOpCreateAccount     // Account creation substate cost
  GasChangeOpSelfDestruct      // SELFDESTRUCT opcode cost
  GasChangeRefund              // Refund counter applied
  ...
)

// CodeChangeReason
type CodeChangeReason int
const (
  CodeChangeContractCreation   // Contract deployed (CREATE/CREATE2)
  CodeChangeSelfDestruct       // Code cleared on self-destruct
  ...
)

// NonceChangeReason
type NonceChangeReason int
const (
  NonceChangeTxNonce           // TX nonce increment (sender)
  NonceChangeContractCreation  // Contract creation increments nonce
  ...
)
```

**Tracers read these reasons** to understand *why* mutations occurred, enabling:
- Breakdown of gas by reason
- Identification of all balance changes
- Classification of contract interactions
- Compliance audit trails

## Journal: Revert Event Emission

When a call fails (revert, out-of-gas), the journal auto-emits **reverse events**:

```
CALL to contract A:
  OnEnter(depth=1)
  └─ SSTORE x (OnStorageChange, x←old_val)
  └─ CALL to B
     └─ OnEnter(depth=2)
     └─ CALL to C (REVERT)
        └─ OnExit(error=reverted)
     ← Journal replays: OnStorageChange reverse (x←new_val)
     └─ OnExit(depth=1, error=none) [A continues]
```

**Benefit:** Tracers see complete revert lifecycle without extra logic.

## Component Interactions

### TraceAPI ↔ Tracer

```go
// TraceAPI creates tracer instance
tracer := call.New(config)

// Sets up hooks pointing to tracer's callback methods
hooks := &tracing.Hooks{
  OnEnter: tracer.CaptureEnter,
  OnExit:  tracer.CaptureExit,
  OnBalanceChange: tracer.CaptureBalanceChange,
  ...
}

// During VM execution, hooks fire → tracer methods called
// Tracer buffers events into result object (call tree, etc.)

// After execution completes
result := tracer.GetResult()  // e.g., CallFrame tree
return json.Marshal(result)
```

### StateDB ↔ hookedStateDB ↔ Hooks

```go
// TraceAPI wraps StateDB
hookedState := statedb_hooked.NewHookedState(stateDB, hooks)

// During TX execution
hookedState.SubBalance(addr, amount, reason)
  ├─ stateDB.SubBalance(addr, amount)  // actual mutation
  └─ if hooks.OnBalanceChange != nil {
       hooks.OnBalanceChange(addr, oldVal, newVal, reason)
     }

// Hook fires → tracer.CaptureBalanceChange(addr, oldVal, newVal, reason)
```

### Block Execution Flow

```
core/state_processor.go::ApplyTransaction()
  ├─ stateDB := state.NewStateDB(...)              // base state at block start
  ├─ if tracer != nil {
  │    hookedState := NewHookedState(stateDB, hooks)
  │    stateDB = hookedState  // replace with hooked version
  │  }
  ├─ vm.NewEVM(..., stateDB, ...)                  // EVM uses (hooked) StateDB
  ├─ evm.Call / evm.Create (execute TX)            // hooks fired during execution
  ├─ stateDB.Finalise()                             // snapshot root
  └─ return receipt, gas_used
```

## Historical State & Archive

**pathdb** stores **reverse diffs** per block:

```
Block N:   StateRoot = H_N
  └─ reverse_diff = {
       account_addr: { balance: (N_val, N-1_val), nonce: ... },
       ...
     }

Query: State at block N-1?
  ├─ Start with H_N
  ├─ Apply reverse_diff
  └─ Get H_N-1
```

**Benefit:** Archive nodes can query historical state without full replay.

**Files:**
- `triedb/pathdb/history_state.go` — state mutations + reverse diffs
- `triedb/pathdb/history_reader.go` — query interface
- `triedb/pathdb/history_indexer*.go` — indexing block→state transitions

## Consensus & Finalization

Three consensus engines plugged into `core/consensus.Engine`:

| Engine | Type | Networks |
|--------|------|----------|
| **Ethash** | Proof-of-Work | Mainnet (pre-Merge) |
| **Beacon** | Proof-of-Stake | Mainnet (post-Merge), Testnet |
| **Clique** | Proof-of-Authority | Goerli, private chains |

Each engine validates blocks independently; tracing layer is orthogonal.

**Block finality:**
```
Beacon engine marks:
  ├─ Justified: 2 epochs back (≈12.8 min on mainnet)
  ├─ Finalized: 3 epochs back (≈32 min)
  └─ Safe: highest witnessed justified checkpoint
```

Tracers can access finality info via `tracing.BlockEvent.Finalized`.

## Networking & P2P

**p2p/** package handles peer discovery & message relay:
- DevP2P protocols (subprotocols like `eth`)
- Peer scoring & disconnection logic
- Transaction pool propagation

**Not directly affected by tracing;** isolated layer.

## RPC API Layer

**Entry points for tracing:**

| Method | Package | Purpose |
|--------|---------|---------|
| `debug_traceTransaction` | `eth/tracers/api.go` | Single TX trace |
| `debug_traceBlock` | `eth/tracers/api.go` | All TXs in block |
| `debug_traceCall` | `eth/tracers/api.go` | Simulated call (state overrides) |
| `eth_call` | `internal/ethapi/` | Standard call (no trace) |
| `eth_simulateV1` | `internal/ethapi/simulate.go` | **[Custom]** Simulation with overrides |
| `debug_traceLog` | `internal/ethapi/logtracer.go` | **[Custom]** ERC-7528 ether transfers |

## Workload Testing Framework

**`cmd/workload/`** — custom tool for trace testing:

```
workload generate [--block N] [--tracer call]
  └─ Fetch block N from node
  └─ Generate trace test JSON
  └─ Save to workload test suite

workload validate [--file test.json] [--node http://localhost:8545]
  └─ Load trace test
  └─ Execute trace RPC against node
  └─ Compare results
  └─ Report pass/fail
```

**Use:** Validate trace implementations against live blocks.

## Stateless Execution (Verkle Alpha)

**`core/stateless/`** — experimental witness generation for stateless clients:

- Captures all state accessed during TX execution
- Generates Verkle proof witness
- Enables light clients to verify TX effects without full state

**Status:** Alpha; not production-ready.

## State Overlay Mode

**`core/overlay/`** — state mutation overlays for simulation:

```
Simulate TX with modified state:
  ├─ Start with canonical state
  ├─ Apply overlay (balance overrides, storage overwrites)
  ├─ Execute TX
  └─ Trace results reflect overlaid state
```

**Use:** "What if" scenario testing.

## Metrics & Observability

**`metrics/`** integrates Prometheus/InfluxDB:

- Block processing time
- Trie node cache hit rates
- RPC endpoint latencies
- Tracer execution time

**Disabled by default;** enable via `--metrics` flag on geth.

---

**Summary:** Tracing is a layered system orthogonal to consensus. Hooks fire during state mutations; tracers consume events to build rich execution traces. Historical state support via pathdb enables archive queries. No consensus path changes — fully additive design.
