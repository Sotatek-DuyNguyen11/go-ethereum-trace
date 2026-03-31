#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
COMPOSE_FILE="$POA_DIR/docker-compose.yml"

if [[ -f "$POA_DIR/.env" ]]; then
  docker compose --env-file "$POA_DIR/.env" -f "$COMPOSE_FILE" down
else
  docker compose -f "$COMPOSE_FILE" down
fi

if [[ "${1:-}" == "--clean" ]]; then
  rm -rf "$POA_DIR/data"
  rm -f "$POA_DIR/genesis.json" "$POA_DIR/.env" "$POA_DIR/enodes.txt" "$POA_DIR/password.txt"
  echo "removed generated PoA chain artifacts"
fi
