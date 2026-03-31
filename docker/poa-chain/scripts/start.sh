#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
COMPOSE_FILE="$POA_DIR/docker-compose.yml"

if [[ ! -f "$POA_DIR/genesis.json" || ! -f "$POA_DIR/.env" ]]; then
  echo "missing generated chain artifacts"
  echo "run: bash docker/poa-chain/scripts/init.sh"
  exit 1
fi

docker compose --env-file "$POA_DIR/.env" -f "$COMPOSE_FILE" up -d node1 node2 node3

rpc_call() {
  local port="$1"
  local method="$2"
  local params="$3"
  curl -s -X POST "http://127.0.0.1:$port" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}"
}

extract_result() {
  sed -n 's/.*"result":"\([^"]*\)".*/\1/p'
}

echo "waiting for peers and block production..."
for _ in $(seq 1 30); do
  peers="$(rpc_call 9545 net_peerCount '[]' | extract_result)"
  block_a="$(rpc_call 9545 eth_blockNumber '[]' | extract_result)"
  sleep 2
  block_b="$(rpc_call 9545 eth_blockNumber '[]' | extract_result)"
  if [[ "$peers" == "0x2" && -n "$block_a" && -n "$block_b" && "$block_a" != "$block_b" ]]; then
    echo "node1 rpc: http://127.0.0.1:9545"
    echo "node2 rpc: http://127.0.0.1:9547"
    echo "node3 rpc: http://127.0.0.1:9549"
    echo "peer count node1: $peers"
    echo "block number advanced: $block_a -> $block_b"
    exit 0
  fi
done

echo "cluster started but did not reach healthy state within timeout"
exit 1
