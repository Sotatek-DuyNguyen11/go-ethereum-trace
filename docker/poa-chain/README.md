# Docker Clique PoA Chain

Thư mục này dựng một private chain 3 validator dùng Clique PoA trên fork hiện tại.

Quick start:

```sh
bash docker/poa-chain/scripts/init.sh
bash docker/poa-chain/scripts/start.sh
```

`init.sh` dùng bộ signer/node keys cố định cho dev, nên mỗi lần reset sẽ ra đúng cùng addresses và bootnodes.

Nếu bạn muốn hành vi cũ là generate ngẫu nhiên signer keys, node keys, bootnodes và genesis cho mỗi lần init:

```sh
bash docker/poa-chain/scripts/init_generate.sh --force
bash docker/poa-chain/scripts/start.sh
```

Nếu bạn muốn tạm dừng blockchain nhưng giữ nguyên chain data hiện tại:

```sh
bash docker/poa-chain/scripts/stop.sh
```

Sau đó bật lại từ đúng state cũ:

```sh
bash docker/poa-chain/scripts/start.sh
```

RPC endpoints:

- node1: `http://127.0.0.1:9545`
- node2: `http://127.0.0.1:9547`
- node3: `http://127.0.0.1:9549`

Container names:

- `node1`: `poa-tracing-node-1`
- `node2`: `poa-tracing-node-2`
- `node3`: `poa-tracing-node-3`

Published ports:

- `node1`
  - HTTP RPC: `127.0.0.1:9545 -> 8545`
  - WS RPC: `127.0.0.1:9546 -> 8546`
  - P2P TCP: `30413 -> 30303`
  - P2P UDP: `30413 -> 30303`
- `node2`
  - HTTP RPC: `127.0.0.1:9547 -> 8545`
  - WS RPC: `127.0.0.1:9548 -> 8546`
  - P2P TCP: `30414 -> 30303`
  - P2P UDP: `30414 -> 30303`
- `node3`
  - HTTP RPC: `127.0.0.1:9549 -> 8545`
  - WS RPC: `127.0.0.1:9550 -> 8546`
  - P2P TCP: `30415 -> 30303`
  - P2P UDP: `30415 -> 30303`

Signer accounts:

- `node1`
  signer address: `0xb51f552feb2969514c5842ba8b631734df3ab20e`
  private key: `0x0f342169c1275ae4655c9b9370018760ad208e28cd1b9079ce9ed3162008b984`
  files:
  - `docker/poa-chain/data/node1/signerkey`
  - `docker/poa-chain/data/node1/keystore/keyfile.json`
- `node2`
  signer address: `0x07a0975e4bc9707edbcb21ed035ccf97c4e51ad2`
  private key: `0xe9996d7af82585097e5c4a682ca56b81c4e6f05f23820dfc2999b7ddc56f614e`
  files:
  - `docker/poa-chain/data/node2/signerkey`
  - `docker/poa-chain/data/node2/keystore/keyfile.json`
- `node3`
  signer address: `0x6a160560ec3b81de4a46897aac5f9413c8086066`
  private key: `0xf64e0e9551d40b2478fee94c659d91e8c73e7a5f2604967559da3349cecf04a0`
  files:
  - `docker/poa-chain/data/node3/signerkey`
  - `docker/poa-chain/data/node3/keystore/keyfile.json`

Lưu ý:

- Lab này hiện dùng bộ `signerkey` và `nodekey` cố định cho dev.
- Mỗi lần chạy `bash docker/poa-chain/scripts/init.sh --force`, script sẽ recreate lại đúng cùng signer addresses, private keys, bootnodes và `genesis.json`.
- Các giá trị ở trên sẽ chỉ thay đổi nếu bạn sửa trực tiếp `docker/poa-chain/scripts/init.sh`.
- Nếu bạn dùng `bash docker/poa-chain/scripts/init_generate.sh --force` thì toàn bộ signer/private key trong README này sẽ không còn đúng, vì script đó tạo bộ ngẫu nhiên mới.

Dừng cluster:

```sh
bash docker/poa-chain/scripts/stop.sh
```

Reset toàn bộ chain artifacts và khởi tạo lại từ đầu:

```sh
bash docker/poa-chain/scripts/stop.sh --clean
bash docker/poa-chain/scripts/init.sh --force
bash docker/poa-chain/scripts/start.sh
```
