# Codebase Summary: go-ethereum-trace

## Directory Structure & File Organization

```
go-ethereum-trace/
├── accounts/              (86 files)  Wallets, ABI, keystores, hardware signers
├── api/                   Remote API definitions
├── build/                 Build scripts & CI config (build/ci.go is main entry)
├── cmd/                   (112 files) CLI executables
│   ├── geth/             Main Ethereum client
│   ├── clef/             Standalone signing tool
│   ├── devp2p/           P2P utilities
│   ├── abigen/           Contract ABI code generator
│   ├── evm/              EVM bytecode debugger
│   ├── rlpdump/          RLP dump utility
│   └── workload/         **[CUSTOM]** Trace testing framework
├── common/               (28 files)  Utilities (math, hexutil, types)
├── consensus/            (31 files) Consensus engines
│   ├── ethash/           Proof-of-Work engine
│   ├── beacon/           Proof-of-Stake beacon chain
│   └── clique/           Proof-of-Authority clique
├── core/                 (265 files) **[CORE DOMAIN]** EVM, state, block processing
│   ├── tracing/          **[CUSTOM]** Hooks & reason enums (21KB, 1,279 LOC)
│   │   ├── hooks.go      Central Hooks struct with On* callbacks
│   │   ├── journal.go    Auto-revert event emission (8.6KB)
│   │   ├── CHANGELOG.md  Tracing-specific changes
│   │   └── gen_*_stringer.go (auto-generated reason enums)
│   ├── state/            State database & mutation tracking
│   │   ├── statedb_hooked.go **[CUSTOM]** StateDB wrapper (9.2KB)
│   │   └── statedb.go    Original StateDB implementation
│   ├── vm/               EVM executor, opcodes, call handling
│   │   └── evm.go        **[Modified]** Transfer with BalanceChangeReason
│   ├── state_processor.go **[Modified]** Wraps StateDB with hooks
│   ├── types/            Transaction, block, receipt types
│   ├── genesis.go        Genesis block handling
│   └── ...
├── crypto/               (83 files) Cryptographic primitives (ECDSA, AES, hashing)
├── docs/                 **[PROJECT DOCS]** Architecture, standards, roadmap
│   ├── audits/          Historical audit PDFs
│   ├── postmortems/     Historical postmortem docs
│   └── ...
├── eth/                  (141 files) **[PROTOCOL LAYER]** Ethereum protocol, RPC tracers
│   ├── tracers/          **[CUSTOM TRACERS]** Tracer API & implementations
│   │   ├── api.go        **[Custom, 41KB]** Main RPC endpoints (TraceTransaction, TraceBlock, TraceCall)
│   │   ├── native/       Built-in tracer implementations
│   │   │   ├── call.go          Call tree tracer
│   │   │   ├── call_flat.go     Flat call trace (Parity-compatible)
│   │   │   ├── prestate.go      Pre-execution state snapshot
│   │   │   ├── 4byte.go         Function selector frequency
│   │   │   ├── mux.go           Multi-tracer multiplexer
│   │   │   └── ...
│   │   ├── js/           JavaScript tracer (Goja engine)
│   │   ├── live/         Live tracers
│   │   │   └── supply.go **[Custom]** Token supply tracker
│   │   └── logger/       Structured logging tracer
│   ├── filters/          Event filters (logs, blocks)
│   ├── catalyst/         Beacon chain consensus integration
│   └── ...
├── ethdb/                (19 files) Key-value database interfaces
├── ethstats/             Protocol stats collection
├── graphql/              GraphQL API definitions
├── internal/             (72 files) JSON-RPC APIs, debug tools
│   ├── ethapi/           Ethereum API (JSON-RPC)
│   │   ├── logtracer.go **[Custom]** Synthetic ERC-7528 ether transfers
│   │   ├── simulate.go   **[Custom]** TX simulation with state overrides
│   │   └── ...
│   └── ...
├── les/                  Light client (experimental)
├── metrics/              (60 files) Prometheus/InfluxDB metrics
├── miner/                (14 files) Block production, transaction pool
├── node/                 (20 files) Node management, services
├── p2p/                  (93 files) P2P networking, peer discovery, protocols
├── params/               (10 files) Network parameters, chain configs
├── rlp/                  Recursive Length Prefix encoding/decoding
├── rpc/                  JSON-RPC framework (HTTP, WS, IPC)
├── signer/               Signing services
├── tests/                Ethereum test vectors (execution specs)
├── trie/                 (51 files) Merkle trie implementation
│   ├── tracer.go        Trie operation tracing
│   └── ...
├── triedb/               (58 files) Path-based storage engine
│   ├── pathdb/          Path-based database
│   │   ├── history_*.go **[Custom]** State history indexing & reverse diffs
│   │   ├── history_reader.go **[Custom]** Query historical state
│   │   └── ...
│   └── ...
├── version/              Version constants
├── core/
│   ├── stateless/       **[Custom]** Stateless execution witness (Verkle alpha)
│   ├── overlay/         **[Custom]** State mutation overlays
│   ├── history/         **[Custom]** History mode configuration
│   └── ...
├── go.mod, go.sum        Module dependencies (Go 1.24.0)
├── Makefile              Build targets (geth, evm, all, test, lint, fmt)
├── README.md             Upstream project README
├── AGENTS.md             Contribution guidelines & pre-commit checklist
├── COPYING, COPYING.LESSER  GPL/LGPL license files
└── .gitea/               Gitea-specific config (forks are on Gitea)
```

## File Counts by Package

| Package | Files | Key Role |
|---------|-------|----------|
| `core/` | 265 | EVM execution, state, block processing, **tracing hooks** |
| `eth/` | 141 | Protocol layer, **RPC tracers** |
| `cmd/` | 112 | CLI tools & **workload testing** |
| `p2p/` | 93 | Peer-to-peer networking |
| `accounts/` | 86 | Wallets, keystores, signers |
| `crypto/` | 83 | Cryptography (ECDSA, hashing) |
| `internal/` | 72 | JSON-RPC API, **ERC-7528 logtracer** |
| `metrics/` | 60 | Prometheus/InfluxDB metrics |
| `triedb/` | 58 | Path-based storage, **history indexing** |
| `trie/` | 51 | Merkle trie operations |
| Others | 304 | `common/`, `rpc/`, `node/`, `params/`, `consensus/`, etc. |
| **Total** | ~1,338 | |

## Critical Custom Files (Fork-Specific)

### Tracing Core

| File | Size | Purpose |
|------|------|---------|
| `core/tracing/hooks.go` | 21KB | Central Hooks struct: OnEnter, OnExit, OnBalanceChange, OnStorageChange, etc. + reason enums |
| `core/tracing/journal.go` | 8.6KB | Auto-emit reverse events on revert |
| `core/tracing/CHANGELOG.md` | 13KB | Tracing feature changelog |
| `core/state/statedb_hooked.go` | 9.2KB | Transparent StateDB wrapper firing hooks |
| `core/state_processor.go` | *Modified* | Wraps StateDB with hooks if tracer configured |
| `core/vm/evm.go` | *Modified* | Transfer() includes BalanceChangeReason |

### Tracer Implementations

| File | Purpose |
|------|---------|
| `eth/tracers/api.go` | Main RPC endpoints (41KB): TraceTransaction, TraceBlock, TraceCall |
| `eth/tracers/native/call.go` | Call tree tracer |
| `eth/tracers/native/call_flat.go` | Flat call trace (Parity-compatible) |
| `eth/tracers/native/prestate.go` | Pre-execution state snapshot |
| `eth/tracers/native/4byte.go` | Function selector frequency analysis |
| `eth/tracers/native/mux.go` | Multi-tracer multiplexer |
| `eth/tracers/js/goja.go` | JavaScript custom tracer support |
| `eth/tracers/live/supply.go` | Live token supply tracker |

### Workload Testing (Custom Framework)

| File | Purpose |
|------|---------|
| `cmd/workload/` | Trace test generation & validation from live blocks |

### State History & Archive

| File | Purpose |
|------|---------|
| `triedb/pathdb/history_state.go` | State history with reverse diffs per block |
| `triedb/pathdb/history_reader.go` | Query historical state at any block |
| `triedb/pathdb/history_indexer*.go` | Block→state transition indexing |

### Advanced Features

| File | Purpose |
|------|---------|
| `internal/ethapi/logtracer.go` | Synthetic ether transfer events (ERC-7528) |
| `internal/ethapi/simulate.go` | Transaction simulation with state overrides |
| `core/stateless/` | Stateless execution witness (Verkle, alpha) |
| `core/overlay/` | Overlay state transitions |
| `core/history/` | History mode configuration |

## Key Types & Interfaces

### `core/tracing/hooks.go`

```go
type Hooks struct {
  OnEnter             // OnEnter(depth, frame *Frame)
  OnExit              // OnExit(depth, frame *Frame, result []byte, err error)
  OnBalanceChange     // OnBalanceChange(addr Address, prev, new *big.Int, reason BalanceChangeReason)
  OnStorageChange     // OnStorageChange(addr Address, slot, prev, new Hash)
  OnCodeChange        // OnCodeChange(addr Address, prev, new []byte, reason CodeChangeReason)
  OnNonceChange       // OnNonceChange(addr Address, prev, new uint64, reason NonceChangeReason)
  OnGasChange         // OnGasChange(remaining uint64, reason GasChangeReason)
  // ... 20+ hook types
}

// Reason enums
type BalanceChangeReason int  // Transfer, SelfDestruct, GasRefund, ...
type StorageChangeReason int  // (for typed storage mutations)
type CodeChangeReason int     // ContractCreation, SelfDestruct
type NonceChangeReason int    // TxNonce, ContractCreation
type GasChangeReason int      // TxInitialGas, CallDataGas, OpFuel, ...
```

### `core/state/statedb_hooked.go`

```go
type hookedStateDB struct {
  inner *StateDB         // Original StateDB
  hooks *tracing.Hooks   // Hooked callbacks
}
// NewHookedState(stateDb *StateDB, hooks *tracing.Hooks) *hookedStateDB
```

### `eth/tracers/api.go`

```go
type API struct {
  backend Backend
}

// Main RPC methods
func (api *API) TraceTransaction(ctx context.Context, hash common.Hash, config *TraceConfig) (interface{}, error)
func (api *API) TraceBlock(ctx context.Context, block rpc.BlockNumber, config *TraceConfig) (interface{}, error)
func (api *API) TraceCall(ctx context.Context, args TransactionArgs, blockNrOrHash rpc.BlockNumberOrHash, config *TraceConfig) (interface{}, error)
```

### Reason Enums (Auto-Generated)

```go
type BalanceChangeReason int
const (
  BalanceChangeUnspecified BalanceChangeReason = iota
  BalanceChangeTransfer
  BalanceChangeSelfDestruct
  BalanceChangeGasRefund
  // ... ~15 total
)

type GasChangeReason int
const (
  GasChangeUnspecified GasChangeReason = iota
  GasChangeTxInitialGas
  GasChangeCallDataGas
  GasChangeOpFuel
  GasChangeOpLog
  // ... ~20 total
)
// Similar for CodeChangeReason, NonceChangeReason, etc.
```

## Consensus Engines

| Engine | Package | Type | Chain |
|--------|---------|------|-------|
| Ethash | `consensus/ethash/` | Proof-of-Work | Mainnet (pre-Merge) |
| Beacon | `consensus/beacon/` | Proof-of-Stake | Mainnet (post-Merge) |
| Clique | `consensus/clique/` | Proof-of-Authority | Goerli, other PoA chains |

## Tracer Types (Implementations)

| Tracer | Module | Output Format | Use Case |
|--------|--------|---------------|----------|
| `call` | `eth/tracers/native/call.go` | Call tree (JSON) | Full execution trace |
| `callFlat` | `eth/tracers/native/call_flat.go` | Flat call list (Parity-compatible) | Simple call sequence |
| `prestate` | `eth/tracers/native/prestate.go` | Pre/post state diff | State mutations |
| `4byte` | `eth/tracers/native/4byte.go` | Function selector frequencies | ABI analysis |
| `mux` | `eth/tracers/native/mux.go` | Multiple outputs | Multi-tracer execution |
| `js` | `eth/tracers/js/goja.go` | Custom (user-defined) | Custom analysis |
| `logger` | `eth/tracers/logger/` | Structured logs | Debugging |
| `supply` | `eth/tracers/live/supply.go` | Token supply deltas | Token flow analysis |

## Build Artifacts

**Executables** (`build/bin/`):
- `geth` — Main Ethereum client
- `clef` — Signing tool
- `devp2p` — P2P utilities
- `abigen` — ABI code generator
- `evm` — EVM debugger
- `rlpdump` — RLP dump utility
- `workload` — Trace testing framework

## Dependency Groups

**Critical:**
- `github.com/ethereum/go-ethereum` (core module)
- `github.com/holiman/uint256` (256-bit arithmetic)
- `github.com/ethereum/c-kzg-4844/v2` (KZG commitments)

**Consensus & Crypto:**
- `github.com/consensys/gnark-crypto` (Verkle proofs)
- `github.com/decred/dcred/dcrec/secp256k1/v4` (ECDSA)

**Storage:**
- `github.com/cockroachdb/pebble` (Key-value DB)
- `github.com/VictoriaMetrics/fastcache` (Memory cache)

**RPC & Networking:**
- `github.com/gorilla/websocket` (WebSocket)
- `github.com/dop251/goja` (JavaScript execution)
- `google.golang.org/grpc` (gRPC)

**Metrics:**
- `github.com/influxdata/influxdb-client-go/v2` (InfluxDB)

---

**For more details:**
- Read `go.mod` for complete dependency list
- See `docs/system-architecture.md` for data flows
