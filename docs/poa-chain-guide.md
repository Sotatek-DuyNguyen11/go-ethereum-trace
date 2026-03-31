# Hướng dẫn chạy Clique PoA chain

## Mục tiêu

Setup này tạo một private chain 3 node, trong đó cả 3 node đều là validator Clique.

Mỗi node có 2 loại key khác nhau:

- `signerkey`: private key dùng để ký block Clique
- `nodekey`: private key dùng cho devp2p identity và `enode`

## Các file chính

- `docker/poa-chain/Dockerfile`
- `docker/poa-chain/docker-compose.yml`
- `docker/poa-chain/scripts/init.sh`
- `docker/poa-chain/scripts/start.sh`
- `docker/poa-chain/scripts/stop.sh`

## Cách chạy

Tạo genesis, signer keys, node keys và datadirs:

```sh
bash docker/poa-chain/scripts/init.sh
```

Khởi động 3 validator:

```sh
bash docker/poa-chain/scripts/start.sh
```

Kiểm tra chain ID:

```sh
curl -s -X POST http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Kiểm tra signer set:

```sh
curl -s -X POST http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"clique_getSigners","params":["latest"],"id":1}'
```

## Genesis strategy

Genesis được generate với:

- `clique.period = 5`
- `clique.epoch = 30000`
- `terminalTotalDifficulty = 9223372036854775807`
- tất cả fork block từ `homestead` tới `london` = `0`
- không bật `shanghaiTime` hoặc `cancunTime`

Mục tiêu là giữ chain ở pre-merge path để Beacon wrapper tiếp tục delegate về Clique.

## Cách block được tạo

Sau khi node start:

1. `--clique.signerkey` nạp signer private key vào Clique engine
2. `--mine` kích sealing loop cục bộ
3. node build block mới trên head hiện tại
4. `Clique.Seal()` ký header bằng `signerkey`
5. block được broadcast sang 2 validator còn lại
6. các node còn lại verify signer theo snapshot/signer set của Clique

## Dừng và reset

Dừng cluster:

```sh
bash docker/poa-chain/scripts/stop.sh
```

Xóa toàn bộ chain data và genesis đã generate:

```sh
bash docker/poa-chain/scripts/stop.sh --clean
```
