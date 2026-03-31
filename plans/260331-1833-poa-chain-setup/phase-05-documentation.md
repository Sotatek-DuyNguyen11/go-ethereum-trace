# Phase 5: Documentation

**Priority:** Medium
**Status:** Pending
**Description:** Quick start README + detailed guide tiếng Việt.

## Related Code Files

**Create:**
- `docker/poa-chain/README.md` — Quick start (ngắn gọn)
- `docs/poa-chain-guide.md` — Guide chi tiết tiếng Việt

## Implementation Steps

### README.md (Quick Start)

- Prerequisites (Docker, Docker Compose)
- 3 commands: init → start → verify
- Port table
- Link to detailed guide

### poa-chain-guide.md (Detailed Guide)

Nội dung:
1. **Clique PoA là gì** — cách hoạt động, signer rotation, voting
2. **Quick start** — 3 lệnh
3. **Chi tiết setup** — từng bước giải thích
4. **Voting** — thêm/bớt validator qua RPC
   ```js
   clique.propose("0xNewAddr", true)   // thêm
   clique.propose("0xOldAddr", false)  // bỏ
   ```
5. **Kết nối Foundry/Hardhat** — config examples
6. **Troubleshooting** — common issues + fixes
7. **Hạn chế & bảo mật** — private key management, network security

## Success Criteria

- [ ] README có đủ info để start chain trong 2 phút
- [ ] Guide cover voting workflow
- [ ] Guide có troubleshooting section
