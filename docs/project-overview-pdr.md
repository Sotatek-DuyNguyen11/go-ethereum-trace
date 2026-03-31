# go-ethereum-trace: Project Overview & PDR

## Project Purpose

**go-ethereum-trace** is a fork of [go-ethereum](https://github.com/ethereum/go-ethereum) (geth v1.14+) extended with comprehensive **traceability infrastructure** for Ethereum state mutations during EVM execution.

This fork captures every state change during block & transaction execution with **typed reasons**, enabling:
- Deep audit trails for state mutations
- Compliance & debugging tooling
- Advanced transaction analysis (call trees, storage access patterns, gas breakdowns)
- Historical state reconstruction
- Token flow tracking & supply analytics

## What Makes This Fork Different

Upstream go-ethereum provides basic tracing via RPC endpoints (`debug_traceTransaction`). This fork adds:

| Feature | Upstream | This Fork |
|---------|----------|-----------|
| **Typed mutation reasons** | Limited | ✅ Full reason enums (e.g., BalanceChangeReason: `GasRefund`, `SelfDestruct`, `Transfer`) |
| **Hooked state mutations** | No | ✅ `statedb_hooked.go` - transparent StateDB wrapper firing hooks on every mutation |
| **Central tracing hooks** | No | ✅ `core/tracing/hooks.go` - unified hook interface with OpCode, Call, Storage, Balance events |
| **Journal-based reversions** | No | ✅ Auto-emit reverse events on call failure / tx revert |
| **Historical state indexing** | Basic pathdb | ✅ Enhanced `pathdb/history_*` - block→state transition reverse diffs |
| **Workload testing framework** | No | ✅ `cmd/workload/` - trace test generation & validation from live blocks |
| **Synthetic ERC-7528 events** | No | ✅ `internal/ethapi/logtracer.go` - ether transfer as log events |
| **State overlay mode** | No | ✅ `core/overlay/` - state mutation overlays for simulation |
| **Stateless witness support** | No | ✅ `core/stateless/` - Verkle witness generation (alpha) |

## Project Goals

1. **Enable advanced auditing** — Track every reason a balance or storage value changed
2. **Support compliance tools** — Provide clean RPC APIs for transaction tracing with reason annotations
3. **Accelerate debugging** — Enable engineers to understand state transitions deeply
4. **Future-proof archive nodes** — Support historical state queries with compressed diffs
5. **Support protocol research** — Build testbeds for EVM enhancements (Verkle, statelessness)

## Architecture Summary

**Core Stack:**
- Language: Go 1.24.0
- Module: `github.com/ethereum/go-ethereum`
- Build: `make geth` / `make all`

**Key Custom Components:**
```
core/tracing/            → Hooks structs & reason enums (21KB)
core/state/statedb_hooked.go → StateDB wrapper (9.2KB)
eth/tracers/api.go       → RPC endpoints (41KB)
eth/tracers/native/      → Call, flat, prestate, 4byte tracers
triedb/pathdb/history_*  → State history indexing
cmd/workload/            → Trace testing framework
```

**Tracing Data Flow:**
```
RPC (debug_traceTransaction)
  → eth/tracers/api.go::TraceTransaction
    → core/state_processor.go (re-execute block)
      → core/state/statedb_hooked.go (wrap StateDB)
        → core/vm/evm.go (opcodes)
          → core/tracing/hooks.go (fire OnBalanceChange, OnStorageChange...)
            → Tracer consumer (call, prestate, 4byte, flatCall, mux, etc.)
              → JSON RPC response
```

## Codebase Stats

- **~1,338 Go files** across 30+ top-level packages
- **~265 files** in `core/` (EVM, state, tracing)
- **~141 files** in `eth/` (protocol, tracers)
- **~112 files** in `cmd/` (CLI tools)
- **~1,279 lines** in `core/tracing/` alone

## Key Commitments

- **Upstream compatibility** — Minimal divergence; easy to rebase against upstream releases
- **Zero-cost when disabled** — Hooks are function pointers; nil hooks = no overhead
- **Production-ready** — Consensus-critical paths unchanged; tracing is additive
- **Clean commit format** — Conventional commits with package prefixes (e.g., `core/vm: fix stack overflow`)

## Development Model

**Consensus Engines:** Ethash (PoW), Beacon (PoS), Clique (PoA)

**Build & Test:**
```sh
make geth                              # Build geth
make all                               # Build all executables
go run ./build/ci.go test -short       # Quick tests
go run ./build/ci.go test              # Full test suite
go run ./build/ci.go lint              # Linting
```

**Pre-Commit Checklist:**
- `gofmt -w <files>` + `goimports -w <files>`
- `make all` (no build errors)
- `go run ./build/ci.go test` (all tests pass)
- `go run ./build/ci.go lint` (linting)
- `go run ./build/ci.go check_generate` (code generation)
- `go run ./build/ci.go check_baddeps` (dependency checks)

## Roadmap Status

### ✅ Implemented
- Core tracing hooks & reason enums
- StateDB hooked wrapper
- RPC trace endpoints (call, flatCall, prestate, 4byte, mux)
- JavaScript tracer support
- Historical state indexing (pathdb)
- Workload testing framework
- Live token supply tracker

### 🚧 In Progress / Experimental
- Stateless witness generation (Verkle alpha)
- State overlay mode refinements

### 📋 Future
- Compressed historical state snapshots
- Real-time trace streaming RPC
- Enhanced call tree compression
- Distributed trace archival

## Licensing

- **Library (`/` excluding `cmd/`):** GNU LGPL v3.0
- **Binaries (`cmd/`):** GNU GPL v3.0

See `COPYING` and `COPYING.LESSER` files.

---

**For technical details, see:**
- `docs/codebase-summary.md` — directory structure & file map
- `docs/system-architecture.md` — architecture & data flows
- `docs/code-standards.md` — Go standards & contribution guidelines
