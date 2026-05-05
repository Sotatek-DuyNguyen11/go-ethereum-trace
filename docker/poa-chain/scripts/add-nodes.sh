#!/usr/bin/env bash
# Initialize data directories for node4 and node5.
# Run this BEFORE starting the new nodes.
# After running, use vote-validator.sh to vote the new nodes into the signer set.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
COMPOSE_FILE="$POA_DIR/docker-compose.yml"
PASSWORD_FILE="$POA_DIR/password.txt"
ENV_FILE="$POA_DIR/.env"
DATA_DIR="$POA_DIR/data"
ENODES_FILE="$POA_DIR/enodes.txt"

if [[ ! -f "$POA_DIR/genesis.json" || ! -f "$ENV_FILE" ]]; then
  echo "missing chain artifacts — run init.sh first"
  exit 1
fi

run_tool() {
  docker compose -f "$COMPOSE_FILE" run --rm tools "$@"
}

declare -a NEW_NODES=(4 5)
declare -a IPS=("172.32.0.14" "172.32.0.15")
declare -a NEW_ADDRESSES
declare -a NEW_ENODES

for idx in 0 1; do
  i="${NEW_NODES[$idx]}"
  ip="${IPS[$idx]}"
  NODE_DIR="$DATA_DIR/node$i"

  if [[ -d "$NODE_DIR" && "${1:-}" != "--force" ]]; then
    echo "node$i data already exists — skip (use --force to reinitialize)"
    # Still read existing address for output
    ADDRESS="$(sed -n 's/.*"address":"\([^"]*\)".*/0x\1/p' "$NODE_DIR/keystore/keyfile.json" 2>/dev/null || echo '')"
    ENODE="$(run_tool devp2p key to-enode --ip "$ip" --tcp 30303 --udp 30303 "docker/poa-chain/data/node$i/geth/nodekey")"
    NEW_ADDRESSES+=("$ADDRESS")
    NEW_ENODES+=("$ENODE")
    continue
  fi

  mkdir -p "$NODE_DIR/geth" "$NODE_DIR/keystore"

  run_tool devp2p key generate "docker/poa-chain/data/node$i/signerkey" >/dev/null

  run_tool ethkey generate \
    --privatekey "docker/poa-chain/data/node$i/signerkey" \
    --passwordfile "docker/poa-chain/password.txt" \
    --json \
    "docker/poa-chain/data/node$i/keystore/keyfile.json" >/dev/null

  ADDRESS="$(sed -n 's/.*"address":"\([^"]*\)".*/0x\1/p' "$NODE_DIR/keystore/keyfile.json")"
  if [[ -z "$ADDRESS" ]]; then
    echo "failed to derive signer address for node$i"
    exit 1
  fi
  NEW_ADDRESSES+=("$ADDRESS")

  run_tool devp2p key generate "docker/poa-chain/data/node$i/geth/nodekey" >/dev/null
  ENODE="$(run_tool devp2p key to-enode --ip "$ip" --tcp 30303 --udp 30303 "docker/poa-chain/data/node$i/geth/nodekey")"
  NEW_ENODES+=("$ENODE")

  run_tool geth init --datadir "docker/poa-chain/data/node$i" "docker/poa-chain/genesis.json" >/dev/null

  echo "initialized node$i  address=$ADDRESS"
done

# Append new enodes to enodes.txt (avoid duplicates)
for enode in "${NEW_ENODES[@]}"; do
  if ! grep -qF "$enode" "$ENODES_FILE" 2>/dev/null; then
    echo "$enode" >> "$ENODES_FILE"
  fi
done

# Update BOOTNODES in .env to include new enodes
ALL_ENODES="$(paste -sd ',' "$ENODES_FILE")"
sed -i "s|^BOOTNODES=.*|BOOTNODES=$ALL_ENODES|" "$ENV_FILE"

echo ""
echo "done — node4 and node5 are ready"
echo ""
echo "new validator addresses (vote these in via vote-validator.sh):"
for addr in "${NEW_ADDRESSES[@]}"; do
  echo "  $addr"
done
echo ""
echo "next steps:"
echo "  1. start new nodes:    bash docker/poa-chain/scripts/start-extra-nodes.sh"
echo "  2. vote validators in: bash docker/poa-chain/scripts/vote-validator.sh"
