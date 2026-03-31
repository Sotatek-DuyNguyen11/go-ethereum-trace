# Private Chain Guide

Tài liệu này mô tả cách chạy local private chain cho repo này.

## Docker + genesis

Các file liên quan:

- `docker/private-chain/docker-compose.yml`
- `docker/private-chain/genesis.json`
- `docker/private-chain/README.md`

Flow chạy:

```sh
docker compose -f docker/private-chain/docker-compose.yml build
docker compose -f docker/private-chain/docker-compose.yml run --rm init
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```

Node hiện được cấu hình:

- `chainId = 31337`
- HTTP RPC tại `http://127.0.0.1:8545`
- WS RPC tại `ws://127.0.0.1:8546`
- block tự sinh mỗi `2` giây bằng `--dev.period 2`
- port chỉ publish trên `127.0.0.1`

Lý do dùng `init genesis` rồi chạy với `--dev`:

- datadir được init trước bằng custom `genesis.json`
- sau đó `--dev` được dùng để local node tự sinh block
- flow này đã được verify thực tế trên fork này
- genesis phải tương thích dev mode, cụ thể:
  - `terminalTotalDifficulty = 0`
  - `difficulty = 0`

Kiểm tra node:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## Ví mẫu

Ví mẫu đã được prefund trong `docker/private-chain/genesis.json`:

- address: `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
- private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

Ví nhận tiền test:

- `0x70997970c51812dc3a010c7d01b50e0d17dc79c8`

Các private key này chỉ dùng cho local development chain.

## Hardhat

Ví dụ `hardhat.config.ts`:

```ts
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    localgeth: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ],
    },
  },
};

export default config;
```

Deploy:

```sh
npx hardhat run scripts/deploy.ts --network localgeth
```

## Nếu không có cast

Repo này không yêu cầu `cast`. Bạn có thể:

- dùng `curl` để gọi RPC trực tiếp
- dùng `Hardhat` qua `npx hardhat ...`

## Nếu muốn chạy 3 node PoA với Docker

Repo này đã có setup Clique PoA riêng tại:

- `docker/poa-chain/docker-compose.yml`
- `docker/poa-chain/scripts/init.sh`
- `docker/poa-chain/scripts/start.sh`
- `docker/poa-chain/scripts/stop.sh`
- `docs/poa-chain-guide.md`

Flow rút gọn:

```sh
bash docker/poa-chain/scripts/init.sh
bash docker/poa-chain/scripts/start.sh
```

RPC:

- node1: `http://127.0.0.1:9545`
- node2: `http://127.0.0.1:9547`
- node3: `http://127.0.0.1:9549`

Lab `docker/three-node` cũ vẫn còn hữu ích nếu bạn chỉ muốn test P2P execution nodes mà không cần block production.

## Dừng và reset

```sh
docker compose -f docker/private-chain/docker-compose.yml down
```

```sh
rm -rf docker/private-chain/data
docker compose -f docker/private-chain/docker-compose.yml run --rm init
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```
