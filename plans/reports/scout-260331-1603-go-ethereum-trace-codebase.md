# Scout Report: go-ethereum-trace Codebase

**Date:** 2026-03-31 | **Branch:** master | **Module:** `github.com/ethereum/go-ethereum`

## Overview

Go-ethereum fork focused on **traceability** — ~1,325 Go files across 30 top-level packages. Go 1.24.0. Builds via `make geth` / `make all`.

## Codebase Scale

| Directory | Go Files | Key Role |
|-----------|----------|----------|
| core/ | 265 | EVM, state, types, tracing hooks |
| eth/ | 141 | Ethereum protocol, **tracers** |
| cmd/ | 112 | CLI tools (geth, evm, **workload**) |
| p2p/ | 93 | Networking, peer discovery |
| accounts/ | 86 | Wallets, ABI, keystores |
| crypto/ | 83 | Cryptographic primitives |
| internal/ | 72 | JSON-RPC API, debug |
| metrics/ | 60 | Prometheus/InfluxDB metrics |
| triedb/ | 58 | Path-based storage, **state history** |
| trie/ | 51 | Merkle trie, **operation tracers** |
| Others | ~304 | common, rpc, node, params, etc. |

## Architecture — Tracing Data Flow

```
RPC Request (debug_traceTransaction / debug_traceBlock)
  → eth/tracers/api.go (TraceTransaction, TraceBlock, TraceCall)
    → core/state_processor.go (re-execute block)
      → core/state/statedb_hooked.go (wrap StateDB with hooks)
        → core/vm/evm.go (execute opcodes)
          → core/evm.go (Transfer → SubBalance/AddBalance with reason)
            → hookedStateDB fires OnBalanceChange, OnStorageChange, etc.
              → Tracer (call, prestate, 4byte, flatCall...) consumes events
                → JSON result returned via RPC
```

## Critical Custom Files (Traceability Features)

### Core Tracing Infrastructure
| File | Purpose |
|------|---------|
| `core/tracing/hooks.go` (21KB) | Central `Hooks` struct — On{Enter,Exit,BalanceChange,StorageChange,...} with reason enums |
| `core/tracing/journal.go` (8.6KB) | Auto-emit revert events on call failure (no manual rollback) |
| `core/state/statedb_hooked.go` (9.2KB) | StateDB wrapper that fires tracing hooks on every state mutation |
| `core/state_processor.go` | Block execution — wraps StateDB with hooks if tracer configured |
| `core/evm.go` | Transfer() calls SubBalance/AddBalance with BalanceChangeReason |

### Tracer Implementations
| File | Purpose |
|------|---------|
| `eth/tracers/api.go` (41KB) | Main RPC endpoints: TraceTransaction, TraceBlock, TraceCall |
| `eth/tracers/native/call.go` | Call tree tracer (nested call frames) |
| `eth/tracers/native/call_flat.go` | Flat call trace (Parity-compatible) |
| `eth/tracers/native/prestate.go` | Pre-execution state snapshot |
| `eth/tracers/native/4byte.go` | Function selector frequency |
| `eth/tracers/native/mux.go` | Multi-tracer multiplexer |
| `eth/tracers/js/goja.go` | JavaScript custom tracer support |
| `eth/tracers/live/supply.go` | Live token supply tracker |

### Workload Testing Framework (CUSTOM — not in upstream)
| File | Purpose |
|------|---------|
| `cmd/workload/main.go` | Trace testing framework entry point |
| `cmd/workload/tracetestgen.go` (193L) | Generate trace test cases from live blocks |
| `cmd/workload/tracetest.go` (133L) | Execute trace tests & validate consistency |
| `cmd/workload/queries/trace_mainnet.json` | Mainnet trace test vectors |
| `cmd/workload/queries/trace_sepolia.json` | Sepolia trace test vectors |

### State History (pathdb — enhanced storage)
| File | Purpose |
|------|---------|
| `triedb/pathdb/history_state.go` | State history with reverse diffs per block |
| `triedb/pathdb/history_reader.go` | Query historical state at any block |
| `triedb/pathdb/history_indexer*.go` (5 files) | Block→state transition indexing |
| `triedb/pathdb/history_trienode.go` | Historical trie node access |

### Trie Operation Tracers
| File | Purpose |
|------|---------|
| `trie/tracer.go` | `opTracer` (insert/delete tracking), `PrevalueTracer` (node value caching) |
| `trie/inspect.go` | Trie introspection & inspection |

### Other Custom/Enhanced
| File | Purpose |
|------|---------|
| `internal/ethapi/logtracer.go` (155L) | Custom tracer: logs + synthetic ether transfer events (ERC-7528) |
| `internal/ethapi/simulate.go` (20KB) | Transaction simulation with state overrides |
| `core/stateless/` (4 files) | Stateless execution witness (Verkle support) |
| `core/overlay/` (1 file) | Overlay state transitions |
| `core/history/` (1 file) | History mode configuration |
| `crypto/keccak_ziren.go` | Custom keccak implementation |

## Key Design Patterns

1. **Hooks struct (not interface)** — `core/tracing/Hooks` uses function pointers, not interfaces. Nil = no overhead.
2. **Reason enums** — Every state mutation includes typed reason (BalanceChangeReason, NonceChangeReason, etc.)
3. **Depth tracking** — Call frames tracked by integer depth (0 = top-level tx)
4. **Journal-based revert** — `tracing.WrapWithJournal()` auto-emits reverse events on revert
5. **Hooked StateDB pattern** — Transparent wrapper, zero-cost when hooks are nil

## Consensus Engines

| Engine | Dir | Usage |
|--------|-----|-------|
| Ethash (PoW) | `consensus/ethash/` | Pre-merge (historical) |
| Beacon (PoS) | `consensus/beacon/` | Post-merge (current) |
| Clique (PoA) | `consensus/clique/` | Testnets, private chains |

## Build & Test Commands

```sh
make geth           # Build geth binary
make all            # Build all executables
gofmt -w <files>    # Format before commit
goimports -w <files>
go run ./build/ci.go test -short  # Fast test iteration
go run ./build/ci.go test         # Full test suite (pre-commit)
go run ./build/ci.go lint         # Linting
go run ./build/ci.go check_generate  # Verify generated code
go run ./build/ci.go check_baddeps   # Dependency check
```

## Non-Standard Config

- `HoodiGenesisHash` in `params/config.go` — custom network (not standard mainnet/testnet)
- Module remains `github.com/ethereum/go-ethereum` (not rebranded)

## Unresolved Questions

1. What is `HoodiGenesisHash` network? Custom testnet or production fork?
2. What's `crypto/keccak_ziren.go`? Custom keccak or alternate implementation?
3. Are `trie/bintrie/` and `trie/transitiontrie/` actively used or experimental?
4. Does GraphQL expose trace queries via custom schema extensions?
5. What's the relationship between `core/history/` config and archive node mode?
6. How do live tracers (`eth/tracers/live/`) differ from API tracers in operational mode?
