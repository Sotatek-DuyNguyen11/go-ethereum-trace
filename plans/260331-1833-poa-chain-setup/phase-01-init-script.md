# Phase 1: Init Script

**Priority:** High
**Status:** Pending
**Description:** Tạo script tự động generate raw signer keys, node keys, build genesis.json với Clique extraData, và init datadirs cho 3 nodes.

## Context Links

- `consensus/clique/clique.go` — Clique engine (seal, verify, authorize)
- `core/genesis.go` — Genesis validation, extraData parsing
- `params/config.go` — `CliqueConfig` struct (Period, Epoch)
- `docker/private-chain/` — Reference dev mode setup

## Key Insights

- Clique extraData format: `[32 bytes vanity] + [N × 20 bytes signer addresses] + [65 bytes signature (zeroed)]`
- Genesis cần `clique` config với `period` và `epoch`
- **PHẢI có `terminalTotalDifficulty`** — `CreateConsensusEngine()` reject genesis nếu thiếu TTD
- Set `terminalTotalDifficulty = 9223372036854775807` (MaxInt64) → chain never transitions to PoS
- `signerkey` phải là raw private key file đọc được bởi `crypto.LoadECDSA`
- `nodekey` là artifact riêng cho devp2p; không reuse signer key làm node identity
- Keystore chỉ là artifact phụ nếu muốn inspect/import account; không dùng làm nguồn sự thật cho signing
- Password file trống ("") chỉ cần nếu tạo thêm keystore JSON cho reference/debug

## Related Code Files

**Create:**
- `docker/poa-chain/scripts/init.sh`

**Generate (by init.sh):**
- `docker/poa-chain/genesis.json`
- `docker/poa-chain/data/node{1,2,3}/` (datadirs)
- `docker/poa-chain/data/node{1,2,3}/signerkey`
- `docker/poa-chain/data/node{1,2,3}/geth/nodekey`
- `docker/poa-chain/enodes.txt`
- `docker/poa-chain/password.txt`

## Implementation Steps

1. Tạo `docker/poa-chain/scripts/init.sh`:
   - Check if `geth` binary available (hoặc dùng docker run)
   - Tạo password file trống (chỉ dùng nếu cần sinh keystore)
   - Với mỗi node, generate **signerkey** raw:
     - `go run ./cmd/devp2p key generate docker/poa-chain/data/nodeX/signerkey`
   - Derive signer address từ `signerkey` bằng tool/code có sẵn, không parse từ filename:
     - preferred: small `go run` helper trong script hoặc reusable shell helper gọi `crypto.LoadECDSA`
     - alternative: `go run ./cmd/ethkey generate --privatekey signerkey ...` rồi lấy address từ output
   - Optional nhưng khuyến nghị: tạo keystore từ chính `signerkey` để debug/reference:
     - `go run ./cmd/ethkey generate --privatekey docker/poa-chain/data/nodeX/signerkey --passwordfile docker/poa-chain/password.txt docker/poa-chain/data/nodeX/keystore/keyfile.json`
   - Với mỗi node, generate **nodekey** riêng cho P2P:
     - `go run ./cmd/devp2p key generate docker/poa-chain/data/nodeX/geth/nodekey`
   - Tạo enode URLs từ `nodekey`:
     - `go run ./cmd/devp2p key to-enode --ip node1 --tcp 30303 --udp 30303 docker/poa-chain/data/node1/geth/nodekey`
     - save toàn bộ vào `docker/poa-chain/enodes.txt`
   - Build extraData: `printf '0x%064x' 0` + 3 signer addresses (no 0x prefix) + 65 bytes zero
   - Generate `genesis.json` với:
     - chainId: 31337
     - **terminalTotalDifficulty: 9223372036854775807** (MaxInt64 — REQUIRED)
     - clique: { period: 5, epoch: 30000 }
     - extradata chứa 3 signer addresses
     - alloc: balance cho 3 signers
     - Tất cả fork blocks = 0 (homestead → london)
     - **KHÔNG set shanghaiTime, cancunTime** (Clique rejects these forks)
   - Init 3 datadirs: `geth init --datadir ./data/node{1,2,3} genesis.json`

2. Script phải idempotent — check if data exists, warn before overwrite

## Success Criteria

- [ ] `init.sh` chạy không lỗi
- [ ] Genesis.json được generate đúng format
- [ ] 3 datadirs initialized thành công
- [ ] 3 file `signerkey` raw được generate và load được bằng `crypto.LoadECDSA`
- [ ] 3 file `nodekey` được generate và convert được thành enode
- [ ] `enodes.txt` chứa 3 enode URLs ổn định
- [ ] extraData format đúng (32 + 3×20 + 65 bytes)
- [ ] Signer addresses được derive chính xác từ `signerkey`

## Risk Assessment

- **geth binary không có:** Script nên hỗ trợ cả local geth và docker run
- **Không có cách export raw key từ `geth account new`:** Generate raw `signerkey` trước, rồi mới tạo keystore nếu cần
- **Node enode không ổn định:** Persist `geth/nodekey` từ đầu, không để node tự random identity
