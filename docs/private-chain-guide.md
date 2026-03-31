# Private Chain Guide

Tài liệu này hướng dẫn cách chạy `go-ethereum-trace` như một private chain.

Repo này là execution client theo kiến trúc Ethereum sau Merge, nên có 3 kiểu dùng thực tế:

1. `--dev`: nhanh nhất để chạy một chain cục bộ 1 node cho phát triển và test.
2. `custom genesis`: dùng khi muốn chain riêng với `chainId`, alloc, tham số genesis, và datadir cố định.
3. `docker + genesis`: cách thực dụng nhất để chạy thật trên local bằng image Docker của chính repo.

Nếu bạn muốn chạy nhiều node sau Merge theo đúng mô hình production-like, chỉ `geth` là chưa đủ. Bạn sẽ cần thêm beacon/consensus client hoặc một bộ orchestration như Kurtosis.

## 1. Build

```sh
make geth
```

Binary sẽ nằm tại:

```sh
./build/bin/geth
```

## 2. Cách nhanh nhất: chạy local private chain với `--dev`

`--dev` là cách phù hợp nhất nếu mục tiêu là:

- có chain riêng để test nhanh
- có sẵn tài khoản prefund
- bật RPC để gọi từ script, frontend, hardhat/foundry
- không cần networking giữa nhiều node

### Chạy node

```sh
./build/bin/geth \
  --dev \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool \
  --ws \
  --ws.addr 127.0.0.1 \
  --ws.port 8546 \
  --ws.api eth,net,web3,debug,txpool
```

### Hành vi của `--dev`

- tạo single-node chain cục bộ
- tắt peer discovery và networking
- tạo một developer account được prefund trong genesis
- unlock account đó để dùng local
- seal block khi có transaction pending

### Giữ dữ liệu sau khi restart

Mặc định `--dev` có thể chạy theo kiểu ephemeral. Nếu muốn giữ chain state:

```sh
./build/bin/geth \
  --dev \
  --datadir ./private-chain-data \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool
```

### Tạo block đều theo chu kỳ

Nếu muốn block tự sinh đều đặn:

```sh
./build/bin/geth \
  --dev \
  --dev.period 2 \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool
```

Lệnh trên sẽ cố gắng tạo block mỗi 2 giây.

### Kiểm tra node đã chạy chưa

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Kiểm tra thêm block hiện tại:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## 3. Chạy private chain với `genesis.json` riêng

Cách này phù hợp khi bạn muốn:

- tự chọn `chainId`
- prefund các ví cụ thể
- cố định thông số genesis
- dùng datadir riêng ổn định

### Bước 1: tạo `genesis.json`

Ví dụ tối thiểu:

```json
{
  "config": {
    "chainId": 12345,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "terminalTotalDifficulty": 0,
    "shanghaiTime": 0,
    "cancunTime": 0,
    "blobSchedule": {
      "cancun": {
        "target": 3,
        "max": 6,
        "baseFeeUpdateFraction": 3338477
      }
    }
  },
  "nonce": "0x0",
  "timestamp": "0x0",
  "extraData": "0x00",
  "gasLimit": "0x1c9c380",
  "difficulty": "0x0",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "0x1111111111111111111111111111111111111111": {
      "balance": "0x52B7D2DCC80CD2E4000000"
    }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "baseFeePerGas": "0x3b9aca00"
}
```

Ghi chú:

- `terminalTotalDifficulty: 0` và `difficulty: 0` để chain ở trạng thái post-Merge ngay từ genesis
- `chainId` nên là giá trị riêng của bạn
- `alloc` là nơi prefund tài khoản
- nếu bạn muốn local chain vẫn tự tạo block bằng `--dev`, genesis phải tương thích dev mode, tức là `terminalTotalDifficulty = 0` và `difficulty = 0`

### Bước 2: init datadir

```sh
./build/bin/geth init --datadir ./private-chain-data ./genesis.json
```

### Bước 3: start node

```sh
./build/bin/geth \
  --dev \
  --datadir ./private-chain-data \
  --networkid 12345 \
  --dev.period 2 \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool \
  --ws \
  --ws.addr 127.0.0.1 \
  --ws.port 8546 \
  --ws.api eth,net,web3,debug,txpool
```

### Lưu ý quan trọng

Nếu chỉ chạy `geth` đơn lẻ với một custom genesis post-Merge, bạn có chain state nhưng không có multi-node consensus thật.

Flow chạy local thực tế nhất cho repo này là:

1. `init` datadir bằng `genesis.json`
2. chạy node với `--dev --datadir <datadir>`

Cách này giữ được custom `chainId` và `alloc`, đồng thời vẫn có block production local.

## 4. Chạy thật bằng Docker + genesis

Repo đã có sẵn bộ file mẫu:

- [docker/private-chain/docker-compose.yml](/Users/sotatek/sotatek/traceability/go-ethereum-trace/docker/private-chain/docker-compose.yml)
- [docker/private-chain/genesis.json](/Users/sotatek/sotatek/traceability/go-ethereum-trace/docker/private-chain/genesis.json)
- [docker/private-chain/README.md](/Users/sotatek/sotatek/traceability/go-ethereum-trace/docker/private-chain/README.md)

### Bước 1: build image

```sh
docker compose -f docker/private-chain/docker-compose.yml build
```

### Bước 2: init datadir bằng genesis

```sh
docker compose -f docker/private-chain/docker-compose.yml run --rm init
```

Lệnh này sẽ tạo local chain data trong:

```sh
docker/private-chain/data
```

### Bước 3: chạy node

```sh
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```

Node mẫu này được cấu hình:

- `chainId = 31337`
- HTTP RPC tại `http://127.0.0.1:8545`
- WS RPC tại `ws://127.0.0.1:8546`
- block tự sinh mỗi `2` giây bằng `--dev.period 2`

### Bước 4: kiểm tra node

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

```sh
docker compose -f docker/private-chain/docker-compose.yml logs -f geth
```

### Dừng node

```sh
docker compose -f docker/private-chain/docker-compose.yml down
```

### Reset chain từ đầu

```sh
rm -rf docker/private-chain/data
docker compose -f docker/private-chain/docker-compose.yml run --rm init
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```

## 5. Ví mẫu và private key mẫu

`docker/private-chain/genesis.json` đã prefund các ví local. Ví mẫu nên dùng ngay là:

| Address | Private Key |
| --- | --- |
| `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |

Các key này chỉ nên dùng cho local development chain.

Ví prefund thứ hai hiện có trong genesis để nhận tiền test:

```text
0x70997970c51812dc3a010c7d01b50e0d17dc79c8
```

Kiểm tra balance của ví đầu tiên:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{
    "jsonrpc":"2.0",
    "method":"eth_getBalance",
    "params":["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", "latest"],
    "id":1
  }'
```

## 6. Foundry và cast

### Biến môi trường gợi ý

```sh
export RPC_URL=http://127.0.0.1:8545
export CHAIN_ID=31337
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export FROM=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
export TO=0x70997970c51812dc3a010c7d01b50e0d17dc79c8
```

### Kiểm tra chain bằng cast

```sh
cast chain-id --rpc-url $RPC_URL
cast block-number --rpc-url $RPC_URL
cast balance $FROM --rpc-url $RPC_URL
```

### Gửi ETH bằng cast

```sh
cast send $TO \
  --value 0.1ether \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Deploy contract bằng forge

Ví dụ nếu bạn có contract `src/Counter.sol`:

```sh
forge create src/Counter.sol:Counter \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Gọi contract bằng cast

Đọc giá trị:

```sh
cast call <CONTRACT_ADDRESS> "number()(uint256)" --rpc-url $RPC_URL
```

Gửi transaction:

```sh
cast send <CONTRACT_ADDRESS> "increment()" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

## 7. Hardhat

### `hardhat.config.ts`

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

### Deploy script ví dụ

```ts
import { ethers } from "hardhat";

async function main() {
  const Counter = await ethers.getContractFactory("Counter");
  const counter = await Counter.deploy();
  await counter.waitForDeployment();
  console.log("Counter:", await counter.getAddress());
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
```

### Chạy deploy

```sh
npx hardhat run scripts/deploy.ts --network localgeth
```

### Console nhanh bằng ethers

```ts
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
const wallet = new ethers.Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider,
);

console.log(await provider.getBlockNumber());
console.log(await wallet.getAddress());
```

## 8. RPC gợi ý cho phát triển

Nếu bạn đang test traceability hoặc RPC debug, nhóm API này thường đủ:

```text
eth,net,web3,debug,txpool
```

Nếu cần thêm filter/log queries:

```text
eth,net,web3,debug,txpool,engine
```

Chỉ expose RPC ra ngoài `127.0.0.1` khi bạn hiểu rõ rủi ro bảo mật.

## 9. Trace/debug trên local chain

Ví dụ trace một transaction:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{
    "jsonrpc":"2.0",
    "method":"debug_traceTransaction",
    "params":["0xYOUR_TX_HASH", {}],
    "id":1
  }'
```

Trace cả block:

```sh
curl -s -X POST http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  --data '{
    "jsonrpc":"2.0",
    "method":"debug_traceBlockByNumber",
    "params":["latest", {}],
    "id":1
  }'
```

## 10. Khi nào dùng cách nào

### Dùng `--dev` khi:

- chỉ cần 1 node local
- cần setup nhanh
- cần account prefund ngay
- đang test tracer, RPC, hoặc contract logic

### Dùng custom genesis khi:

- cần chainId cố định
- cần alloc riêng
- cần datadir ổn định
- muốn môi trường gần với private network thật hơn

### Dùng Docker + genesis khi:

- muốn chạy thật ngay bằng Docker
- muốn chia sẻ cùng một flow cho cả team
- muốn reset chain dễ
- muốn hạn chế phụ thuộc vào host environment

## 11. Hạn chế quan trọng

- `--dev` không dành cho multi-node networking
- private network nhiều node sau Merge cần thêm beacon/consensus layer
- nếu cần mô phỏng production multi-node, nên dùng Kurtosis thay vì chỉ chạy `geth`
- private key trong mục ví mẫu là key public cho local dev, không dùng ở bất kỳ môi trường nào khác

## 12. Lệnh mẫu đầy đủ để dùng hằng ngày

### Dev mode nhanh

```sh
./build/bin/geth \
  --dev \
  --datadir ./dev-data \
  --dev.period 2 \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool \
  --ws \
  --ws.addr 127.0.0.1 \
  --ws.port 8546 \
  --ws.api eth,net,web3,debug,txpool
```

### Custom genesis

```sh
./build/bin/geth init --datadir ./private-chain-data ./genesis.json

./build/bin/geth \
  --dev \
  --datadir ./private-chain-data \
  --networkid 12345 \
  --dev.period 2 \
  --http \
  --http.addr 127.0.0.1 \
  --http.port 8545 \
  --http.api eth,net,web3,debug,txpool \
  --ws \
  --ws.addr 127.0.0.1 \
  --ws.port 8546 \
  --ws.api eth,net,web3,debug,txpool
```

### Docker + genesis

```sh
docker compose -f docker/private-chain/docker-compose.yml build
docker compose -f docker/private-chain/docker-compose.yml run --rm init
docker compose -f docker/private-chain/docker-compose.yml up -d geth
```
