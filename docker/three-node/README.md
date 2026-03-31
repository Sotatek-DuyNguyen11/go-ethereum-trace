# Three-Node Docker Guide

Thư mục này dựng một lab gồm 3 execution nodes bằng Docker.

Quan trọng:

- đây là 3 `geth` execution nodes nối P2P với nhau
- đây không phải một mạng 3 node có consensus hoàn chỉnh
- vì repo hiện tại không hỗ trợ Clique sealing nữa, setup này không tự sản xuất block như một PoA network thật
- mục tiêu chính là test P2P, RPC, peer discovery, và các behavior ở lớp execution node

## Flow chạy

Build image:

```sh
docker compose -f docker/three-node/docker-compose.yml build node1
```

Init datadir cho cả 3 node:

```sh
docker compose -f docker/three-node/docker-compose.yml run --rm init-node1
docker compose -f docker/three-node/docker-compose.yml run --rm init-node2
docker compose -f docker/three-node/docker-compose.yml run --rm init-node3
```

Start cả 3 node:

```sh
docker compose -f docker/three-node/docker-compose.yml up -d node1 node2 node3
```

Compose đã cố định:

- nodekey cho từng node
- Docker subnet nội bộ
- bootnode của node2/node3 trỏ sẵn vào node1

## RPC

- node1: `http://127.0.0.1:18545`
- node2: `http://127.0.0.1:28545`
- node3: `http://127.0.0.1:38545`

Ví dụ kiểm tra peer count:

```sh
curl -s -X POST http://127.0.0.1:18545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

Kết quả mong đợi sau khi các node lên ổn định:

- node1 peer count: `0x2`
- node2 peer count: `0x1`
- node3 peer count: `0x1`

## Dừng lab

```sh
docker compose -f docker/three-node/docker-compose.yml down
```
