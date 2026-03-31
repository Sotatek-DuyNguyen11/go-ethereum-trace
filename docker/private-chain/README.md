# Docker Private Chain

Các file trong thư mục này cho phép chạy một local private chain bằng Docker.

Flow chuẩn:

```sh
docker compose -f docker/private-chain/docker-compose.yml build
docker compose -f docker/private-chain/docker-compose.yml run --rm init
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```

Kiểm tra node:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Dữ liệu chain sẽ nằm trong:

```sh
docker/private-chain/data
```

Lưu ý:

- chain này chạy bằng `--dev` trên một datadir đã được init bằng `genesis.json`
- điều này cho phép vừa có custom `chainId` và `alloc`, vừa có block production local
- đây vẫn là single-node development chain, không phải multi-node production network
- RPC chỉ được publish trên `127.0.0.1` của host để tránh expose ra các interface khác
