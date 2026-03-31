# Phase 2: Docker Compose

**Priority:** High
**Status:** Pending
**Description:** Docker Compose orchestration cho 3 geth validator nodes với peer discovery dùng `nodekey` + `--bootnodes`.

## Context Links

- Phase 1 output: `docker/poa-chain/genesis.json`, datadirs
- `docker/private-chain/` — Reference existing setup

## Key Insights

- ~~Dùng static nodes thay vì bootnode~~ **static-nodes.json deprecated & ignored** (node/config.go:448)
- Peer discovery: dùng `P2P.StaticNodes` trong config.toml HOẶC `--bootnodes` enode URLs
- ~~`--unlock` để ký block~~ **`--unlock` deprecated, no effect** (cmd/geth/main.go:344)
- Dùng `--clique.signerkey /keys/signerkey` (new flag from Phase 0)
- Port binding `127.0.0.1:PORT:8545` — không expose ra ngoài
- `--http.api` phải bao gồm `clique` namespace cho voting
- ~~Nodes cần `--allow-insecure-unlock` khi dùng HTTP~~ **Không cần (unlock removed)**
- `--syncmode full` cho private chain
- `nodekey` đã được generate ở Phase 1 và đặt sẵn trong `datadir/geth/nodekey`, nên enode của mỗi node sẽ ổn định

## Related Code Files

**Create:**
- `docker/poa-chain/docker-compose.yml`
- `docker/poa-chain/Dockerfile` (nếu cần build custom image)

## Implementation Steps

1. Tạo Dockerfile build geth từ repo hiện tại:
   ```dockerfile
   FROM golang:1.21-alpine AS builder
   # Build geth binary
   FROM alpine:latest
   # Copy binary, expose ports
   ```

2. Tạo `docker-compose.yml` với 3 services:
   - **node1:** HTTP 8545, WS 8546, P2P 30303
   - **node2:** HTTP 8547, WS 8548, P2P 30304
   - **node3:** HTTP 8549, WS 8550, P2P 30305
   - Shared network `poa-net`
   - Volume mounts cho data + config
   - Mỗi service mount datadir đã có sẵn:
     - `signerkey` cho Clique sealing
     - `geth/nodekey` cho devp2p identity
   - Geth flags:
     ```
     --datadir /data
     --networkid 31337
     --port 30303
     --http --http.addr 0.0.0.0 --http.port 8545
     --http.api eth,net,web3,debug,txpool,clique
     --http.corsdomain "*"
     --ws --ws.addr 0.0.0.0 --ws.port 8546
     --ws.api eth,net,web3,debug,txpool,clique
     --mine
     --miner.etherbase <addr>
     --clique.signerkey /keys/signerkey
     --nodiscover
     --bootnodes "enode://...@node1:30303,enode://...@node2:30303,enode://...@node3:30303"
     ```

3. Peer discovery strategy:
   - **Primary:** `--bootnodes` with enode URLs of other 2 nodes
   - init.sh generates persistent `nodekey` files first
   - init.sh converts each `nodekey` thành enode URL → saved to `enodes.txt`
   - docker-compose injects `--bootnodes` from `enodes.txt`
   - **DO NOT** use `static-nodes.json` (deprecated & ignored, node/config.go:448)
   - Fallback nếu không muốn nhồi chuỗi `--bootnodes` dài vào compose: generate `config.toml` với `P2P.StaticNodes`
   - Không dựa vào `admin_addPeer` qua HTTP làm path chính; nếu dùng path này thì phải bật `admin` namespace một cách explicit

## Port Mapping

| Service | Host HTTP | Host WS | Container HTTP | Container WS |
|---------|-----------|---------|----------------|--------------|
| node1 | 127.0.0.1:8545 | 127.0.0.1:8546 | 8545 | 8546 |
| node2 | 127.0.0.1:8547 | 127.0.0.1:8548 | 8545 | 8546 |
| node3 | 127.0.0.1:8549 | 127.0.0.1:8550 | 8545 | 8546 |

## Success Criteria

- [ ] `docker compose build` thành công
- [ ] `docker compose up` start 3 nodes
- [ ] 3 nodes peer với nhau (net_peerCount = 2)
- [ ] Blocks được produce mỗi 5s
- [ ] RPC accessible qua mapped ports

## Risk Assessment

- **Build time lâu:** Cache Go modules trong Dockerfile
- **Peer discovery fail:** Validate `enodes.txt` từ Phase 1 và/hoặc switch sang `config.toml` với `P2P.StaticNodes`
- ~~**Unlock fail:** Ensure password.txt mount đúng path~~ — N/A, dùng `--clique.signerkey`
- **Key file not mounted:** Docker will fail to start → clear error message
