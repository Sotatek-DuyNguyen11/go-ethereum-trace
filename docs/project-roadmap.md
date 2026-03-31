# Project Roadmap: go-ethereum-trace

**Last Updated:** March 2026

## Current Status Overview

**go-ethereum-trace** is a stable, production-ready fork of go-ethereum with comprehensive tracing capabilities. Core tracing infrastructure is mature; development focuses on refinement, compatibility, and next-generation features.

### Overall Progress

| Phase | Status | Progress |
|-------|--------|----------|
| **Foundation** (Core tracing hooks, StateDB wrapper) | ✅ Complete | 100% |
| **Tracer Implementations** (call, prestate, 4byte, etc.) | ✅ Complete | 100% |
| **Historical State** (pathdb reverse diffs) | ✅ Complete | 100% |
| **Workload Testing** (trace test framework) | ✅ Complete | 100% |
| **Stateless Execution** (Verkle witness) | 🚧 Alpha | 35% |
| **Advanced Features** (streaming, compression) | 📋 Future | 0% |

---

## Phase 1: Foundation & Core Tracing ✅ Complete

**Status:** Stable & production-ready

**Deliverables:**
- ✅ `core/tracing/hooks.go` — Hooks struct with 20+ callback types
- ✅ Reason enums (BalanceChangeReason, GasChangeReason, etc.)
- ✅ `core/state/statedb_hooked.go` — Transparent StateDB wrapper
- ✅ `core/tracing/journal.go` — Revert event emission
- ✅ Zero-overhead design (nil hooks = no cost)

**Key Metrics:**
- 1,279 lines in `core/tracing/`
- Zero performance regression on non-traced TXs
- All upstream go-ethereum functionality preserved

**Notes:**
- Core design stable; unlikely to change
- Reason enum additions possible (e.g., new opcode reasons)
- Backward compatibility maintained

---

## Phase 2: Tracer Implementations ✅ Complete

**Status:** Stable; all major tracers implemented

### Implemented Tracers

| Tracer | File | Output | Status |
|--------|------|--------|--------|
| **call** | `eth/tracers/native/call.go` | Hierarchical call tree | ✅ Stable |
| **callFlat** | `eth/tracers/native/call_flat.go` | Flat call list (Parity-compat) | ✅ Stable |
| **prestate** | `eth/tracers/native/prestate.go` | Pre/post state snapshots | ✅ Stable |
| **4byte** | `eth/tracers/native/4byte.go` | Function selector frequency | ✅ Stable |
| **mux** | `eth/tracers/native/mux.go` | Multi-tracer combiner | ✅ Stable |
| **js** | `eth/tracers/js/goja.go` | JavaScript custom tracer | ✅ Stable |
| **logger** | `eth/tracers/logger/` | Structured logs | ✅ Stable |
| **supply** | `eth/tracers/live/supply.go` | Token supply tracker | ✅ Stable |

### Tracer Compatibility

- ✅ Parity-compatible output (callFlat)
- ✅ Upstream go-ethereum API compatibility
- ✅ JavaScript tracer with Goja engine
- ✅ Multi-tracer support (run 2+ tracers in one pass)

---

## Phase 3: Historical State & Archive ✅ Complete

**Status:** Stable; production-ready for archive nodes

**Deliverables:**
- ✅ `triedb/pathdb/history_state.go` — Reverse diff storage
- ✅ `triedb/pathdb/history_reader.go` — Historical state queries
- ✅ `triedb/pathdb/history_indexer*.go` — Block→state indexing
- ✅ Full block history queryable (no replay needed)

**Capabilities:**
- Query state at any historical block
- Reverse diff compression (minimal storage overhead)
- Compatible with pruned archive nodes

**Known Limitations:**
- Requires history indexing enabled at startup
- Retrofit on existing chains requires re-indexing

---

## Phase 4: Workload Testing Framework ✅ Complete

**Status:** Functional; used for internal validation

**Deliverables:**
- ✅ `cmd/workload/` — Trace test generation & validation
- ✅ Block-based trace test extraction
- ✅ Trace result comparison

**Use Cases:**
- Validate trace implementations against live blocks
- Regression testing for tracer changes
- Integration test suite for protocol upgrades

**Current Scope:**
- Generate traces from mainnet blocks
- Compare results across implementations

**Future Enhancements:**
- Streaming test generation (large block ranges)
- Distributed test execution

---

## Phase 5: Stateless Execution (Verkle) 🚧 Alpha

**Status:** Experimental; not production-ready

**Timeline:** 2026-2027

**Deliverables (Planned):**
- 🚧 `core/stateless/` — Witness generation for stateless clients
- 🚧 Verkle proof integration
- 🚧 Witness validation logic

**Current Progress:** ~35%
- Witness data structure defined
- Trie traversal hooks in place
- Proof generation: in progress

**Known Issues:**
- Performance overhead not yet optimized
- Verkle curve integration (c-kzg-4844) still stabilizing
- Missing some edge case coverage

**Expected Outcome:**
- Light clients can verify TX effects with Verkle proofs
- No full state required to validate transactions

**Upstream Status:**
- Verkle spec still evolving in Ethereum Protocol Research
- Implementation expected Q3 2026+

---

## Phase 6: Advanced Tracing Features (Future) 📋 Planned

### 6.1 Compressed Historical Snapshots

**Target:** 2026-2027

**Problem:** Historical state snapshots consume disk space.

**Solution:**
- Compression of reverse diffs (zstd or brotli)
- Periodic full snapshot checkpoints
- Incremental diff storage

**Expected Benefit:**
- 70-80% reduction in history DB size
- Faster historical state queries

### 6.2 Real-Time Trace Streaming RPC

**Target:** 2027

**Feature:** Stream trace events in real-time as block is being traced.

```
RPC: debug_traceTransaction (streaming mode)
Response (streaming):
  OnEnter event → JSON frame
  OnStorageChange event → JSON frame
  OnExit event → JSON frame
  ...
```

**Benefit:**
- Enable live dashboards & analytics
- Reduced latency for trace analysis
- Support for very large traces (no buffering)

**Challenge:**
- RPC protocol change (streaming JSON)
- Buffering at tracer level (currently buffered until completion)

### 6.3 Enhanced Call Tree Compression

**Target:** 2027

**Problem:** Large call trees can be 100+ MB for complex contracts.

**Solution:**
- Delta-encoding of similar frames
- Trie-based call tree representation
- Lazy decompression on demand

**Expected Benefit:**
- 50% reduction in call tree JSON size
- Faster transmission to clients

### 6.4 Distributed Trace Archival

**Target:** 2027-2028

**Vision:** Distribute historical traces across cluster nodes.

**Components:**
- Trace sharding by block range or address
- Peer discovery for trace nodes
- P2P trace data sync

**Use Case:**
- Avoid single-node bottleneck for trace queries
- Horizontal scaling of archive infrastructure

---

## Phase 7: Protocol Upgrades & Compatibility

### Upcoming Ethereum Upgrades

**Dencun (2024)** ✅ Already integrated
- EIP-4844 (Proto-Danksharding) — blob TX support
- EIP-7044 (Perpetual Transactionality of Withdrawals)

**Prague (2025)** 🚧 Integrating
- EIP-7702 (Set Code Transaction Type)
- EIP-2537 (Precompiled for BLS) — expected
- Verkle activation — expected (draft)

**Osaka (2026)** 📋 Planning
- Proposed: Further Verkle refinements
- Proposed: Light client improvements

**Trace Compatibility:**
- All protocol upgrades maintain hook interface
- New opcodes: add reason enums as needed
- Reason enum versioning: maintain backward compat

---

## Known Issues & Technical Debt

### Minor Issues (Low Priority)

| Issue | Impact | Fix Timeline |
|-------|--------|--------------|
| Tracer timeout (5s) inflexible | Limits very large traces | 2026 Q3 |
| Journal memory overhead | ~5-10% for deep call stacks | 2026 Q4 |
| pathdb reverse diff not compressed | Disk usage: ~2% overhead | 2027 Q1 |

### Potential Future Changes

| Area | Note | Timeline |
|------|------|----------|
| Hooks interface | May add async callback support | 2027+ |
| Reason enum versioning | Breaking change if needed | TBD |
| StateDB wrapper | Could be simplified with Go generics (1.25+) | 2027+ |

---

## Dependency Management

### Critical Dependencies

| Dependency | Version | Risk | Plan |
|------------|---------|------|------|
| `ethereum/c-kzg-4844` | v2.1.6+ | Verkle-critical | Follow upstream |
| `consensys/gnark-crypto` | v0.18.1+ | Proof generation | Track updates |
| `cockroachdb/pebble` | v1.1.5+ | Storage engine | Stable; minor updates |
| `golang.org` | 1.24.0+ | Language evolution | Upgrade 6mo after release |

### No External API Dependencies
- All tracing is internal to go-ethereum
- No external service calls
- Backward compatible with upstream geth

---

## Maintenance Schedule

### Regular Maintenance

| Task | Frequency | Owner |
|------|-----------|-------|
| Rebase against upstream geth | Monthly | Core team |
| Security audit (external) | Annually | TBD |
| Dependency updates | Quarterly | Core team |
| Performance regression testing | Per-release | QA |
| Documentation updates | Per-feature | Eng team |

### Release Cadence

- **Major release:** Every 6 months (aligned with Ethereum protocol upgrades)
- **Minor release:** Every 3 months (bug fixes, optimizations)
- **Patch release:** As needed (security, critical bugs)

---

## Success Metrics

### Adoption
- [ ] 50+ production deployments of trace node instances
- [ ] 5+ third-party integrations using trace RPC endpoints
- [ ] 10K+ monthly trace RPC requests from external services

### Performance
- [ ] Trace latency: <500ms for typical transactions
- [ ] Memory overhead: <5% vs non-traced geth
- [ ] Disk overhead: <10% for history mode

### Quality
- [ ] >85% test coverage for tracing packages
- [ ] Zero consensus-layer regressions
- [ ] Annual security audit with no critical findings

### Developer Experience
- [ ] <1 hour to implement custom tracer
- [ ] JavaScript tracer support for 80% of use cases
- [ ] Comprehensive documentation & examples

---

## Risk Assessment

### Technical Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Verkle spec changes | Medium | Monitor EIP process; design for flexibility |
| Performance regression on EVM opcodes | Medium | Comprehensive benchmarking per release |
| Historical state index corruption | Low | Validation & recovery tools; backup strategy |

### Organizational Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Upstream geth divergence | Low | Monthly rebase; feature parity checks |
| Key maintainer departure | Low | Documentation; cross-training |
| Resource constraints | Medium | Prioritize core features; defer nice-to-haves |

---

## Stakeholder Alignment

### Internal
- **Engineering:** Focus on stability, performance, testability
- **QA:** Validate traces against live blocks; regression testing
- **DevOps:** Build archive node infrastructure; monitoring

### External
- **Protocol Researchers:** Verkle, stateless execution use cases
- **Dapp Developers:** JavaScript tracer, call tree analysis
- **Blockchain Auditors:** Compliance, detailed state tracking

---

## Unresolved Questions

1. **Streaming RPC protocol:** How to standardize trace event streaming in JSON-RPC?
2. **Verkle timeline:** Will Prague include Verkle activation? Impact on roadmap?
3. **Historical state queries:** Should archive nodes expose raw reverse diffs or only reconstructed state?
4. **Backward compatibility:** How to version reason enums if new opcodes added?

---

## Next Steps (Next Quarter)

### Q2 2026 (April-June)

**High Priority:**
- [ ] Integrate Prague testnet protocol upgrades
- [ ] Optimize journal memory usage (reduce overhead)
- [ ] Add comprehensive workload test suite (1000+ blocks)

**Medium Priority:**
- [ ] Evaluate Verkle witness generation performance
- [ ] Prototype compressed historical snapshots

**Documentation:**
- [ ] Update tracer integration guide
- [ ] Add Verkle explainer for developers

### Q3 2026 (July-September)

**High Priority:**
- [ ] Prague mainnet activation support
- [ ] Release Verkle witness generation (beta, optional)
- [ ] Performance optimization pass

**Medium Priority:**
- [ ] Explore real-time trace streaming RPC

---

**For details on current issues, feature requests, and discussions, see the project's issue tracker on Gitea.**
