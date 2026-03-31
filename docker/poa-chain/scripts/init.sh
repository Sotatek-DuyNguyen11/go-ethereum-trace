#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
POA_DIR="$ROOT_DIR/docker/poa-chain"
COMPOSE_FILE="$POA_DIR/docker-compose.yml"
PASSWORD_FILE="$POA_DIR/password.txt"
ENV_FILE="$POA_DIR/.env"
GENESIS_FILE="$POA_DIR/genesis.json"
DATA_DIR="$POA_DIR/data"

if [[ -d "$DATA_DIR" && "${1:-}" != "--force" ]]; then
  echo "data directory already exists: $DATA_DIR"
  echo "rerun with --force to recreate the PoA chain artifacts"
  exit 1
fi

rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR"
: > "$PASSWORD_FILE"

docker compose -f "$COMPOSE_FILE" build tools

run_tool() {
  docker compose -f "$COMPOSE_FILE" run --rm tools "$@"
}

zero_hex() {
  local count="$1"
  printf '%0*s' "$count" '' | tr ' ' '0'
}

declare -a FIXED_SIGNER_KEYS=(
  "0f342169c1275ae4655c9b9370018760ad208e28cd1b9079ce9ed3162008b984"
  "e9996d7af82585097e5c4a682ca56b81c4e6f05f23820dfc2999b7ddc56f614e"
  "f64e0e9551d40b2478fee94c659d91e8c73e7a5f2604967559da3349cecf04a0"
)
declare -a FIXED_NODE_KEYS=(
  "444afe8dab83e363092b98f4c10984d43dedaf930b8f5190ab96739b1146201e"
  "35a083e671328631db872e6909fff1583205837d1ebdb05ab40f309bfd1e74d4"
  "2806fb4a0659dc8990a9cdd07563dc8e34e886305898e5fbf325ed0a3abd3a0f"
)
declare -a SIGNERS
declare -a ENODES
declare -a IPS=("172.32.0.11" "172.32.0.12" "172.32.0.13")

for i in 1 2 3; do
  NODE_DIR="$DATA_DIR/node$i"
  mkdir -p "$NODE_DIR/geth" "$NODE_DIR/keystore"

  printf '%s\n' "${FIXED_SIGNER_KEYS[$((i-1))]}" > "$NODE_DIR/signerkey"

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
  SIGNERS+=("${ADDRESS#0x}")

  printf '%s\n' "${FIXED_NODE_KEYS[$((i-1))]}" > "$NODE_DIR/geth/nodekey"
  ENODE="$(run_tool devp2p key to-enode --ip "${IPS[$((i-1))]}" --tcp 30303 --udp 30303 "docker/poa-chain/data/node$i/geth/nodekey")"
  ENODES+=("$ENODE")
done

EXTRADATA="0x$(zero_hex 64)${SIGNERS[0]}${SIGNERS[1]}${SIGNERS[2]}$(zero_hex 130)"
BOOTNODES="$(IFS=,; echo "${ENODES[*]}")"

cat > "$GENESIS_FILE" <<EOF
{
  "config": {
    "chainId": 31337,
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
    "terminalTotalDifficulty": 9223372036854775807,
    "clique": {
      "period": 5,
      "epoch": 30000
    }
  },
  "nonce": "0x0",
  "timestamp": "0x0",
  "extraData": "$EXTRADATA",
  "gasLimit": "0x1c9c380",
  "difficulty": "0x1",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": {
    "0x${SIGNERS[0]}": { "balance": "0x52B7D2DCC80CD2E4000000" },
    "0x${SIGNERS[1]}": { "balance": "0x52B7D2DCC80CD2E4000000" },
    "0x${SIGNERS[2]}": { "balance": "0x52B7D2DCC80CD2E4000000" }
  },
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "baseFeePerGas": "0x3b9aca00"
}
EOF

cat > "$ENV_FILE" <<EOF
BOOTNODES=$BOOTNODES
EOF

printf '%s\n' "${ENODES[@]}" > "$POA_DIR/enodes.txt"

for i in 1 2 3; do
  run_tool geth init --datadir "docker/poa-chain/data/node$i" "docker/poa-chain/genesis.json" >/dev/null
done

echo "initialized Clique PoA chain assets in $POA_DIR"
echo "signers:"
for signer in "${SIGNERS[@]}"; do
  echo "  0x$signer"
done
