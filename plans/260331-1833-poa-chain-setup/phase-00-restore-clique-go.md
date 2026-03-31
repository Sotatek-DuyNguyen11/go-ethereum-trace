# Phase 0: Restore Clique PoA Go Code

**Priority:** Critical (blocks all other phases)
**Status:** Pending
**Description:** Restore Clique sealing (`Seal()`) và RPC APIs (`api.go`) đã bị xóa trong upstream geth. Không thêm dependency mới — dùng `crypto.Sign` trực tiếp thay vì `accounts.SignerFn`.

## Context Links

- `consensus/clique/clique.go` — Current code, Seal() = panic
- Git commit `c6823c77a` — Removed Seal() logic + signFn + wiggleTime
- Git commit `f21adaf24` — Removed api.go (235 LOC)
- `consensus/beacon/consensus.go` — Beacon wrapper, delegates to Clique for pre-merge blocks
- `eth/ethconfig/config.go:217` — CreateConsensusEngine requires TTD
- `eth/backend.go:392` — APIs() registration point
- `internal/web3ext/web3ext.go:32-86` — JS extension already defines clique methods

## Key Insights

### Beacon + Clique interaction (pre-merge mode)

```
Chain config: TerminalTotalDifficulty = math.MaxInt64 (never reached)
→ Beacon.IsPoSHeader() = false (Difficulty > 0 for all Clique blocks)
→ Beacon.Seal() delegates to Clique.Seal()
→ Beacon.VerifyHeader() delegates to Clique.VerifyHeader()
→ Beacon.Prepare() delegates to Clique.Prepare()
→ Everything works through Clique engine
```

**Key: TTD = MaxInt64 means chain stays pre-merge forever.** TTD = 0 would mean post-merge (Beacon takes over, Clique Seal ignored).

### Old Seal() logic (from commit c6823c77a)

Sealing flow:
1. Check signer authorized in snapshot
2. Check not recently signed
3. Calculate delay (in-turn = immediate, out-of-turn = random wiggle)
4. Sign header with signFn
5. Wait delay, then send sealed block to results channel

### Old SignerFn dependency

Old code used `accounts.SignerFn` which depends on `accounts` package (heavyweight).
New approach: use `crypto.Sign(hash, privateKey)` directly — simpler, no accounts dependency.

## Architecture Change

```
OLD (removed):
  Clique.Authorize(address, accounts.SignerFn)
  Clique.signFn = func(account, mimeType, msg) → signed bytes

NEW (to implement):
  Clique.Authorize(address, crypto.PrivateKey)
  Clique.signFn = func(hash) → signature bytes (using crypto.Sign internally)
```

## Related Code Files

**Modify:**
- `consensus/clique/clique.go` — Restore Seal(), add signFn, update Authorize()
- `eth/backend.go` — Register clique RPC API namespace

**Create:**
- `consensus/clique/api.go` — Restore from git history (commit f21adaf24~1)

**Read-only reference:**
- `consensus/beacon/consensus.go` — Verify Beacon delegation works
- `eth/ethconfig/config.go` — CreateConsensusEngine flow
- `params/config.go` — IsPostMerge logic, TTD
- `internal/web3ext/web3ext.go` — JS extension (already exists)
- `miner/payload_building_test.go` — Test reference for Authorize()

## Implementation Steps

### Step 0.1: Restore `Seal()` in `clique.go`

1. Add back constants:
   ```go
   wiggleTime = 500 * time.Millisecond // Random delay (per signer)
   ```

2. Add signFn type and field to Clique struct:
   ```go
   // SignFn is a function to sign the block hash with the signer's private key
   type SignFn func(hash []byte) ([]byte, error)
   ```
   ```go
   type Clique struct {
       // ... existing fields ...
       signer common.Address
       signFn SignFn          // ADD: signing function
       lock   sync.RWMutex
   }
   ```

3. Update `Authorize()`:
   ```go
   func (c *Clique) Authorize(signer common.Address, signFn ...SignFn) {
       c.lock.Lock()
       defer c.lock.Unlock()
       c.signer = signer
       if len(signFn) > 0 {
           c.signFn = signFn[0]
       }
   }
   ```
   Note: variadic signFn to keep backward compatibility with existing callers that pass only address.

4. Replace panic in `Seal()` with restored logic:
   ```go
   func (c *Clique) Seal(chain consensus.ChainHeaderReader, block *types.Block, results chan<- *types.Block, stop <-chan struct{}) error {
       header := block.Header()
       number := header.Number.Uint64()
       if number == 0 {
           return errUnknownBlock
       }
       if c.config.Period == 0 && len(block.Transactions()) == 0 {
           return errors.New("sealing paused while waiting for transactions")
       }
       c.lock.RLock()
       signer, signFn := c.signer, c.signFn
       c.lock.RUnlock()

       if signFn == nil {
           return errors.New("clique sealing requires a signing function, call Authorize() first")
       }

       snap, err := c.snapshot(chain, number-1, header.ParentHash, nil)
       if err != nil {
           return err
       }
       if _, authorized := snap.Signers[signer]; !authorized {
           return errUnauthorizedSigner
       }
       for seen, recent := range snap.Recents {
           if recent == signer {
               if limit := uint64(len(snap.Signers)/2 + 1); number < limit || seen > number-limit {
                   return errors.New("signed recently, must wait for others")
               }
           }
       }

       delay := time.Unix(int64(header.Time), 0).Sub(time.Now())
       if header.Difficulty.Cmp(diffNoTurn) == 0 {
           wiggle := time.Duration(len(snap.Signers)/2+1) * wiggleTime
           delay += time.Duration(rand.Int63n(int64(wiggle)))
       }

       // Sign the block header
       sighash, err := signFn(SealHash(header).Bytes())
       if err != nil {
           return err
       }
       copy(header.Extra[len(header.Extra)-extraSeal:], sighash)

       go func() {
           select {
           case <-stop:
               return
           case <-time.After(delay):
           }
           select {
           case results <- block.WithSeal(header):
           default:
               log.Warn("Sealing result is not read by miner", "sealhash", SealHash(header))
           }
       }()
       return nil
   }
   ```

### Step 0.2: Restore `api.go`

1. Recreate `consensus/clique/api.go` from git history (`git show f21adaf24~1:consensus/clique/api.go`)
2. Keep the full API: GetSnapshot, GetSigners, Propose, Discard, Status, GetSigner
3. Remove `accounts` dependency import if present (it shouldn't be in api.go)

### Step 0.3: Register Clique RPC API in `eth/backend.go`

1. In `Ethereum.APIs()`, add clique namespace:
   ```go
   // Check if engine is Clique (possibly wrapped in Beacon)
   if beaconEngine, ok := s.engine.(*beacon.Beacon); ok {
       if cliqueEngine, ok := beaconEngine.InnerEngine().(*clique.Clique); ok {
           apis = append(apis, rpc.API{
               Namespace: "clique",
               Service:   cliqueEngine.NewAPI(s.blockchain),
           })
       }
   }
   ```

2. Add `NewAPI()` method to Clique:
   ```go
   func (c *Clique) NewAPI(chain consensus.ChainHeaderReader) *API {
       return &API{chain: chain, clique: c}
   }
   ```

### Step 0.4: Signer hookup (CRITICAL — `--unlock` is deprecated!)

**⚠️ `--unlock` flag has NO effect** (cmd/geth/main.go:344):
```go
log.Warn(`The "unlock" flag has been deprecated and has no effect`)
```

The old approach of `--unlock <addr> --password file` is dead. Need a NEW mechanism to inject the signing key at startup.

**Option A (Recommended): Env var / key file approach**
- Add a new flag `--clique.signerkey <path>` that reads private key from file
- In `startNode()` or `eth/backend.go`, load the key and call `Authorize(addr, signFn)`
- SignFn wraps `crypto.Sign(hash, privKey)`

**Option B: Reuse keystore + restore unlock**
- Too invasive, `--unlock` was deprecated for good reasons

**Implementation (Option A):**

1. Add flag in `cmd/utils/flags.go`:
   ```go
   CliqueSignerKeyFlag = &cli.StringFlag{
       Name:  "clique.signerkey",
       Usage: "Path to private key file for Clique block signing",
   }
   ```

2. In `cmd/geth/main.go` `startNode()`, after node starts:
   ```go
   if ctx.IsSet(utils.CliqueSignerKeyFlag.Name) {
       keyPath := ctx.String(utils.CliqueSignerKeyFlag.Name)
       key, err := crypto.LoadECDSA(keyPath)
       // Get the Ethereum backend
       var eth *ethservice.Ethereum
       stack.Service(&eth)
       // Extract Clique from Beacon wrapper
       if beaconEngine, ok := eth.Engine().(*beacon.Beacon); ok {
           if cliqueEngine, ok := beaconEngine.InnerEngine().(*clique.Clique); ok {
               addr := crypto.PubkeyToAddress(key.PublicKey)
               cliqueEngine.Authorize(addr, func(hash []byte) ([]byte, error) {
                   return crypto.Sign(hash, key)
               })
           }
       }
   }
   ```

3. Each Docker container will mount a private key file (generated by init.sh)

### Step 0.5: Verify build compiles

```sh
cd /Users/sotatek/sotatek/traceability/go-ethereum-trace
make geth
```

### Step 0.6: Run existing clique tests

```sh
go test ./consensus/clique/ -v -run TestClique
go test ./miner/ -v -run TestBuildPayload
```

## Genesis Config Strategy

For the PoA chain genesis:
```json
{
  "config": {
    "terminalTotalDifficulty": 9223372036854775807,
    "clique": { "period": 5, "epoch": 30000 }
  }
}
```
- `terminalTotalDifficulty = math.MaxInt64` → chain never transitions to PoS
- Beacon wrapper still present but always delegates to Clique (IsPoSHeader = false)
- All Clique consensus rules apply (difficulty > 0, signer rotation, voting)

## Success Criteria

- [ ] `make geth` compiles without errors
- [ ] `go test ./consensus/clique/ -v` passes
- [ ] `go test ./miner/ -v` passes
- [ ] `Seal()` signs blocks correctly (no panic)
- [ ] Clique RPC APIs respond (`clique_getSigners`, `clique_propose`, etc.)
- [ ] Backward compatible — existing Authorize(address) callers still work

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ~~`--unlock` deprecated~~ | ~~Signing never works~~ | Use `--clique.signerkey` flag (new) |
| Miner doesn't call signFn | Blocks not produced | `--clique.signerkey` hookup in startNode() |
| accounts package pulled back | Dependency bloat | Use crypto.Sign directly |
| Beacon wrapper interferes | Block validation fails | TTD=MaxInt64 ensures pre-merge mode |
| Test failures | Build broken | Run full test suite before proceeding |

## Security Considerations

- Private keys stored as files on disk, mounted into Docker containers
- `--clique.signerkey` replaces deprecated `--unlock` flow
- Key files should be readable only by container user (chmod 600)
- Password file no longer needed for signing
- NEVER commit key files to git
