# RPC Test Scripts

File này gom các lệnh test nhanh cho `poa-chain`.

## Endpoint hiện tại

- direct LAN HTTP: `http://172.16.198.47:9545`
- direct LAN WS: `ws://172.16.198.47:9546`
- server localhost HTTP: `http://127.0.0.1:9545`
- server localhost WS: `ws://127.0.0.1:9546`
- domain HTTP: `https://rpc.poa-tracing.sotatek.works`
- domain WS: `wss://ws.poa-tracing.sotatek.works`

## 1. Test chain id

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Expected:

```json
{"jsonrpc":"2.0","id":1,"result":"0x7a69"}
```

## 2. Test latest block

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## 3. Test peer count

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

Expected healthy cluster:

```json
{"jsonrpc":"2.0","id":1,"result":"0x2"}
```

## 4. Test client version

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
```

## 5. Test signer set qua Clique API

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"clique_getSigners","params":["latest"],"id":1}'
```

Expected signer set:

```json
[
  "0xb51f552feb2969514c5842ba8b631734df3ab20e",
  "0x07a0975e4bc9707edbcb21ed035ccf97c4e51ad2",
  "0x6a160560ec3b81de4a46897aac5f9413c8086066"
]
```

## 6. Test block detail

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}'
```

## 7. Test code tại một contract address

Ví dụ contract ERC20 đã deploy trước đó:

```sh
curl -sS http://172.16.198.47:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["0x71513584f5985B49cc629f876C2dfB96e2aD5Ae1","latest"],"id":1}'
```

## 8. Test domain HTTP

Nếu reverse proxy đã cấu hình đúng:

```sh
curl -skS https://rpc.poa-tracing.sotatek.works \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```

Nếu vẫn thấy `502 Bad Gateway` thì lỗi nằm ở OpenResty/Nginx upstream, không phải ở geth RPC.

## 9. Test WebSocket bằng Node.js

```js
const WebSocket = require("ws");

const ws = new WebSocket("ws://172.16.198.47:9546");

ws.on("open", () => {
  ws.send(JSON.stringify({
    jsonrpc: "2.0",
    method: "eth_chainId",
    params: [],
    id: 1,
  }));
});

ws.on("message", (data) => {
  console.log(data.toString());
  ws.close();
});

ws.on("error", (err) => {
  console.error(err);
});
```

## 10. Bash helper

```sh
#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${RPC_URL:-http://172.16.198.47:9545}"

rpc() {
  local method="$1"
  local params="${2:-[]}"
  curl -sS "$RPC_URL" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}"
}

rpc eth_chainId
echo
rpc eth_blockNumber
echo
rpc net_peerCount
echo
rpc web3_clientVersion
echo
rpc clique_getSigners '["latest"]'
echo
```

## 11. Test từ chính server

```sh
curl -sS http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## 12. Test qua SSH tunnel

Từ máy local:

```sh
ssh -L 9545:127.0.0.1:9545 -L 9546:127.0.0.1:9546 sotatek@172.16.198.47
```

Rồi gọi:

```sh
curl -sS http://127.0.0.1:9545 \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
```
