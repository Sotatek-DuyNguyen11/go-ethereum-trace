# Phase 3: Start/Stop Scripts

**Priority:** Medium
**Status:** Pending
**Description:** Convenience scripts để start/stop cluster với health checks.

## Related Code Files

**Create:**
- `docker/poa-chain/scripts/start.sh`
- `docker/poa-chain/scripts/stop.sh`

## Implementation Steps

### start.sh

1. Check prerequisites (docker, data dir initialized)
2. `docker compose build` (if needed)
3. `docker compose up -d`
4. Wait loop: check `net_peerCount` trên node1 cho đến khi = 2
5. Check `eth_blockNumber` tăng
6. Print status summary (RPC URLs, signer addresses)

### stop.sh

1. `docker compose down`
2. Optional `--clean` flag: xóa data dirs (reset chain)

## Success Criteria

- [ ] `start.sh` start cluster và verify healthy
- [ ] `stop.sh` stop cluster cleanly
- [ ] `stop.sh --clean` reset chain data
