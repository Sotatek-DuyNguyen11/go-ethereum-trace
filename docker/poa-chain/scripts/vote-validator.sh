#!/usr/bin/env bash
# Vote new validators (node4, node5) into the Clique signer set.
# Must be run AFTER the new nodes are started and synced.
# Requires: >50% of current signers to approve each new address.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
DATA_DIR="$POA_DIR/data"

# RPC ports of the initial 3 validators
INITIAL_VOTER_PORTS=(9545 9547 9549)

rpc_call() {
  local port="$1"
  local method="$2"
  local params="$3"
  curl -s -X POST "http://127.0.0.1:$port" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}"
}

# clique_propose returns null on success — check for absence of "error" field
propose_vote() {
  local port="$1"
  local addr="$2"
  local resp
  resp="$(rpc_call "$port" clique_propose "[\"$addr\", true]")"
  if echo "$resp" | grep -q '"error"'; then
    echo "  port $port: FAILED — $(echo "$resp" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')"
    return 1
  fi
  echo "  port $port: vote submitted"
}

wait_for_snapshot() {
  local port="$1"
  local address="$2"
  local address_lower
  address_lower="$(echo "$address" | tr '[:upper:]' '[:lower:]')"
  echo "  waiting for $address to appear in clique snapshot..."
  for _ in $(seq 1 60); do
    snapshot="$(rpc_call "$port" clique_getSnapshot '[]')"
    if echo "$snapshot" | grep -qi "${address_lower#0x}"; then
      echo "  confirmed: $address is now a signer"
      return 0
    fi
    sleep 3
  done
  echo "  timeout: $address not found in snapshot"
  return 1
}

get_signer_address() {
  local node_num="$1"
  sed -n 's/.*"address":"\([^"]*\)".*/0x\1/p' \
    "$DATA_DIR/node${node_num}/keystore/keyfile.json" 2>/dev/null || echo ""
}

ADDR4="$(get_signer_address 4)"
ADDR5="$(get_signer_address 5)"

if [[ -z "$ADDR4" || -z "$ADDR5" ]]; then
  echo "cannot read node4/node5 addresses — run add-nodes.sh first"
  exit 1
fi

echo "voting to add new validators:"
echo "  node4: $ADDR4"
echo "  node5: $ADDR5"
echo ""

# --- Vote node4 using initial 3 voters ---
echo "proposing $ADDR4 on ${#INITIAL_VOTER_PORTS[@]} existing validators..."
for port in "${INITIAL_VOTER_PORTS[@]}"; do
  propose_vote "$port" "$ADDR4" || true
done

wait_for_snapshot "${INITIAL_VOTER_PORTS[0]}" "$ADDR4"
echo ""

# --- Vote node5 using all 4 voters (node4 is now a signer, its vote counts) ---
# With 4 signers we need >50% = 3 votes; include node4 (port 9551) to be safe
ALL_VOTER_PORTS=("${INITIAL_VOTER_PORTS[@]}" 9551)
echo "proposing $ADDR5 on ${#ALL_VOTER_PORTS[@]} validators (including node4)..."
for port in "${ALL_VOTER_PORTS[@]}"; do
  propose_vote "$port" "$ADDR5" || true
done

wait_for_snapshot "${INITIAL_VOTER_PORTS[0]}" "$ADDR5"
echo ""

echo "current signer set:"
rpc_call "${INITIAL_VOTER_PORTS[0]}" clique_getSnapshot '[]' \
  | grep -o '"0x[a-f0-9]\{40\}"' \
  | tr -d '"' \
  | sort -u \
  | while read -r addr; do echo "  $addr"; done
