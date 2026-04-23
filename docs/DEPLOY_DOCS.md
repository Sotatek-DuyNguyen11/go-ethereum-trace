# Deploy Docs — PoA Tracing Dev Chain

Hướng dẫn deploy 3-node Clique PoA chain của `go-ethereum-trace` lên môi trường dev.

> Supporting refs: `docs/poa-chain-guide.md`, `docker/poa-chain/README.md`, `docker/poa-chain/rpc-test-scripts.md`.

---

## 1. Tổng quan

| Thành phần | Giá trị |
|---|---|
| Branch | `poa-tracing` |
| Consensus | Clique PoA, `period=5s`, `epoch=30000` |
| ChainId / networkId | `31337` |
| Số validator | 3 (fixed dev signer keys) |
| Base fee | 1 gwei (`0x3b9aca00`) |
| Gas limit | 30,000,000 |
| `terminalTotalDifficulty` | `MaxInt64` → chain luôn pre-merge, Beacon delegate cho Clique |
| Public endpoints | `rpc.poa-tracing.sotatek.works`, `scan.poa-tracing.sotatek.works` |

Custom geth build bao gồm full tracing stack (`core/tracing`, `statedb_hooked`, `eth/tracers/*`) + RPC `debug`/`clique`/`txpool` bật sẵn.

---

## 2. Prerequisites

Trên host dev:

- Docker Engine + Docker Compose plugin (>= v2)
- `bash`, `curl`, `jq`
- Ports trống: `9545-9550` (HTTP/WS), `30413-30415` (P2P TCP/UDP)
- Quyền write vào `docker/poa-chain/data/`

Image build yêu cầu internet pull Go 1.26 alpine + go modules.

---

## 3. Artifacts & source of truth

| File | Vai trò |
|---|---|
| `docker/poa-chain/Dockerfile` | Multi-stage build: Go 1.26-alpine → alpine runtime, static `geth`/`devp2p`/`ethkey` |
| `docker/poa-chain/docker-compose.yml` | 3 service `node1..node3` + 1 service `tools` |
| `docker/poa-chain/scripts/init.sh` | Fixed dev keys → sinh `signerkey`/`nodekey`/`genesis.json`/`.env`/`enodes.txt` |
| `docker/poa-chain/scripts/init_generate.sh` | Random keys mode (không dùng cho env shared) |
| `docker/poa-chain/scripts/start.sh` | `compose up -d`, health-check peers + block advance |
| `docker/poa-chain/scripts/stop.sh` | `compose down` (+ `--clean` xoá artifacts) |
| `docker/poa-chain/genesis.json` | Sinh bởi `init.sh`, đừng sửa tay |
| `docker/poa-chain/.env` | Chứa `BOOTNODES=<enode1>,<enode2>,<enode3>` |
| `docker/poa-chain/data/nodeX/` | Datadir geth (bao gồm `signerkey`, `geth/nodekey`, `keystore/`) |

`.gitignore` đã loại `docker/poa-chain/data/`.

---

## 4. Deploy lần đầu

```sh
cd /path/to/go-ethereum-trace
git checkout poa-tracing
git pull --ff-only

# Sinh artifacts (fixed dev keys, reproducible)
bash docker/poa-chain/scripts/init.sh

# Start 3 validator
bash docker/poa-chain/scripts/start.sh
```

`start.sh` đợi `net_peerCount==0x2` và `eth_blockNumber` tăng trong ≤60s. Nếu timeout → xem `docker compose logs`.

### Smoke test

```sh
curl -s -X POST http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# -> "0x7a69"

curl -s -X POST http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"clique_getSigners","params":["latest"],"id":1}'
# -> 3 addresses
```

Test tracer:

```sh
curl -s -X POST http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"debug_traceBlockByNumber","params":["latest",{"tracer":"callTracer"}],"id":1}'
```

---

## 5. Network topology

```
                  host
 ┌────────────────────────────────────────────────────┐
 │  9545/9546 → node1 : 0.0.0.0 (LAN/public exposed)  │
 │  9547/9548 → node2 : 127.0.0.1 only                │
 │  9549/9550 → node3 : 127.0.0.1 only                │
 └────────────────────────────────────────────────────┘
           │
 docker bridge 172.32.0.0/24
           │
 ┌──────────┬──────────┬──────────┐
 │ node1    │ node2    │ node3    │
 │ .11      │ .12      │ .13      │
 │ 8545/8546│ 8545/8546│ 8545/8546│
 │ 30303    │ 30303    │ 30303    │
 └──────────┴──────────┴──────────┘
 bootnodes đọc từ .env, `--nat extip:<fixed IP>`
```

### Runtime flags mỗi node

```
geth --datadir /data --networkid 31337 --syncmode full
     --port 30303 --bootnodes ${BOOTNODES}
     --http --http.addr 0.0.0.0 --http.port 8545
     --http.corsdomain https://scan.poa-tracing.sotatek.works
     --http.vhosts    localhost,rpc.poa-tracing.sotatek.works
     --http.api  eth,net,web3,debug,txpool,clique
     --ws   --ws.addr 0.0.0.0 --ws.port 8546
     --ws.origins http://localhost,https://rpc.poa-tracing.sotatek.works
     --ws.api    eth,net,web3,debug,txpool,clique
     --mine --clique.signerkey /data/signerkey
     --nat extip:<172.32.0.1X>
```

---

## 6. Public exposure (reverse proxy)

Compose file **chỉ deploy nodes**. Public hostname tồn tại ngoài repo — cần reverse proxy/TLS bên ngoài:

| Hostname | Upstream mục tiêu |
|---|---|
| `rpc.poa-tracing.sotatek.works` | `http://<host>:9545` (node1 HTTP RPC) |
| `scan.poa-tracing.sotatek.works` | Blockscout UI (deploy riêng) |

Yêu cầu proxy:
- Forward `Host` header `rpc.poa-tracing.sotatek.works` → node chấp nhận (đã có trong `--http.vhosts`).
- CORS `https://scan.poa-tracing.sotatek.works` đã allow sẵn ở geth.
- WebSocket upgrade cho `/ws` nếu expose WS (mặc định chỉ HTTP trên 9545).

Blockscout kết nối tới RPC qua docker network nội bộ (`http://172.32.0.11:8545`) hoặc qua public RPC — chọn theo môi trường.

---

## 7. Validator accounts (dev, KHÔNG dùng cho prod)

| Node | Signer address | Signer privkey |
|---|---|---|
| node1 | `0xb51f552feb2969514c5842ba8b631734df3ab20e` | `0x0f342169…008b984` |
| node2 | `0x07a0975e4bc9707edbcb21ed035ccf97c4e51ad2` | `0xe9996d7a…56f614e` |
| node3 | `0x6a160560ec3b81de4a46897aac5f9413c8086066` | `0xf64e0e95…cecf04a0` |

Mỗi account được prefund 100,000,000 ETH trong genesis.

⚠️ **Private keys public trong repo** — chỉ dùng cho lab/dev internal. Không reuse cho testnet/mainnet.

---

## 8. Vòng đời deployment

### Restart giữ nguyên state

```sh
bash docker/poa-chain/scripts/stop.sh
bash docker/poa-chain/scripts/start.sh
```

### Redeploy code change (geth binary)

```sh
bash docker/poa-chain/scripts/stop.sh
docker compose -f docker/poa-chain/docker-compose.yml build tools
bash docker/poa-chain/scripts/start.sh
```

Geth rebuild → container `nodeX` sẽ pick up image mới ở lần `up -d` tiếp theo vì cùng tag `go-ethereum-trace:poa-chain`. Nếu compose không detect → `docker compose up -d --force-recreate node1 node2 node3`.

### Reset hoàn toàn (genesis + data)

```sh
bash docker/poa-chain/scripts/stop.sh --clean
bash docker/poa-chain/scripts/init.sh --force
bash docker/poa-chain/scripts/start.sh
```

### Backup data (archive/incident)

```sh
bash docker/poa-chain/scripts/stop.sh
tar czf poa-backup-$(date +%Y%m%d%H%M).tar.gz \
    docker/poa-chain/data \
    docker/poa-chain/genesis.json \
    docker/poa-chain/.env \
    docker/poa-chain/enodes.txt
bash docker/poa-chain/scripts/start.sh
```

---

## 9. Observability

- `docker compose -f docker/poa-chain/docker-compose.yml logs -f node1`
- RPC health: `eth_blockNumber`, `net_peerCount`, `clique_getSigners`, `clique_status`.
- Tracing sanity: `debug_traceTransaction`, `debug_traceBlockByNumber` (xem `docker/poa-chain/rpc-test-scripts.md`).
- Không có Prometheus/metrics exporter mặc định; bật bằng thêm `--metrics --metrics.addr 0.0.0.0 --metrics.port 6060` + map port ở compose.

---

## 10. Troubleshooting

| Triệu chứng | Nguyên nhân thường gặp | Xử lý |
|---|---|---|
| `start.sh` báo timeout | Bootnodes mismatch / firewall chặn P2P | Check `.env` đã có enode mới; verify 30413-30415/TCP+UDP mở |
| Block không tiến | Chỉ node1 up, không đủ signer online | Start đủ 3 node; xem log `Clique: Signed recently, must wait` |
| 403 ở reverse proxy | `Host` header không nằm trong `--http.vhosts` | Thêm domain vào flag hoặc override header ở proxy |
| CORS block | Origin không match `--http.corsdomain` | Thêm origin mới vào compose, recreate container |
| Genesis mismatch giữa các node | Sửa tay `genesis.json` sau `geth init` | Chạy `stop.sh --clean` → `init.sh --force` |
| Image không rebuild | Compose cache | `docker compose build --no-cache tools` |
