#!/usr/bin/env bash
# Start node4 and node5 containers.
# Run AFTER add-nodes.sh has initialized their data directories.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
COMPOSE_FILE="$POA_DIR/docker-compose.yml"
ENV_FILE="$POA_DIR/.env"

if [[ ! -d "$POA_DIR/data/node4" || ! -d "$POA_DIR/data/node5" ]]; then
  echo "node4/node5 data not found — run add-nodes.sh first"
  exit 1
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d node4 node5

rpc_call() {
  local port="$1"
  local method="$2"
  curl -s -X POST "http://127.0.0.1:$port" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":[],\"id\":1}"
}

extract_hex() {
  sed -n 's/.*"result":"\(0x[^"]*\)".*/\1/p'
}

echo "waiting for node4 and node5 to sync..."
for _ in $(seq 1 30); do
  block4="$(rpc_call 9551 eth_blockNumber | extract_hex)"
  block5="$(rpc_call 9553 eth_blockNumber | extract_hex)"
  block1="$(rpc_call 9545 eth_blockNumber | extract_hex)"
  if [[ -n "$block4" && -n "$block5" && "$block4" == "$block1" ]]; then
    echo "node4 rpc: http://127.0.0.1:9551"
    echo "node5 rpc: http://127.0.0.1:9553"
    echo "block height: $block4"
    echo ""
    echo "nodes synced — now run: bash docker/poa-chain/scripts/vote-validator.sh"
    exit 0
  fi
  sleep 3
done

echo "nodes started but sync timed out — check container logs:"
echo "  docker logs poa-tracing-node-4"
echo "  docker logs poa-tracing-node-5"
exit 1
