# Review Report: PoA Implementation Feasibility on `go-ethereum-trace`

**Date:** 2026-03-31  
**Scope:** Review khả năng implement 3-node Clique PoA private chain trên fork hiện tại  
**Related Plan:** `plans/260331-1833-poa-chain-setup/`

## Executive Summary

Kết luận ngắn:

- Fork hiện tại **không thể** triển khai một Clique PoA network chạy được chỉ bằng `genesis.json`, Docker Compose, và scripts.
- Lý do chính là repo này **không còn hỗ trợ Clique sealing**.
- Vì vậy, mọi kế hoạch theo hướng:
  - generate Clique genesis
  - start 3 signer nodes
  - `--mine` + `--unlock`
  - mong đợi block được produce
  
  đều sẽ thất bại nếu **không sửa code Go**.

## Core Finding

### 1. Clique vẫn tồn tại trong codebase, nhưng không còn usable để produce block

Repo vẫn có:

- `consensus/clique/`
- `CliqueConfig` trong `params/config.go`
- sample Clique genesis trong `cmd/geth/testdata/clique.json`

Nhưng phần quan trọng nhất là hàm seal của Clique hiện đã bị vô hiệu hóa:

- [consensus/clique/clique.go](/Users/sotatek/sotatek/traceability/go-ethereum-trace/consensus/clique/clique.go#L610)

Tại đây:

```go
func (c *Clique) Seal(...) error {
    panic("clique (poa) sealing not supported any more")
}
```

Điều này có nghĩa:

- node có thể còn parse/verify một số thứ liên quan tới Clique
- nhưng node **không thể tự ký và phát block Clique mới**

Đây là blocker tuyệt đối cho bất kỳ plan nào muốn dựng PoA validator network mà không sửa code.

## Additional Technical Constraints

### 2. Clique không hỗ trợ Shanghai/Cancun trong code hiện tại

Trong verify path của Clique:

- [consensus/clique/clique.go](/Users/sotatek/sotatek/traceability/go-ethereum-trace/consensus/clique/clique.go#L296)
- [consensus/clique/clique.go](/Users/sotatek/sotatek/traceability/go-ethereum-trace/consensus/clique/clique.go#L303)

Code hiện trả lỗi khi chain config kích hoạt:

- `Shanghai`
- `Cancun`

Nên kể cả bỏ qua vấn đề sealing, một genesis theo kiểu post-Merge hiện đại cũng không khớp tốt với Clique path còn sót lại trong repo.

### 3. Plan “genesis + Docker + --mine” là không đủ

Các bước như:

- thêm `clique` vào genesis
- tạo `extraData` chứa signer list
- unlock account
- chạy `--mine`

chỉ đúng với geth/Clique đời cũ còn hỗ trợ sealing.

Trên fork hiện tại, chúng **không** đủ để làm cho node produce block.

## Review of the Existing PoA Plan

Related plan:

- `plans/260331-1833-poa-chain-setup/plan.md`

### Key incorrect assumption

Plan đang dựa trên giả định:

> "Clique engine đã có sẵn trong `consensus/clique/` — KHÔNG cần sửa code Go."

Giả định này **sai**.

Chỉ riêng việc `Seal()` panic đã đủ bác bỏ giả định đó.

### Consequences

Vì giả định nền tảng sai, các phase sau cũng không còn valid:

- `init.sh` generate genesis Clique
- `docker-compose.yml` chạy 3 validator nodes
- `start.sh` chờ `eth_blockNumber` tăng
- docs về signer voting và validator rotation

Tất cả đều dựa trên một network có thể produce block, trong khi consensus path hiện tại không làm được việc đó.

## What Works Today

### A. Single-node local chain with block production

Hiện tại, cách chạy block-producing chain khả thi trên fork này là:

- `--dev`

Setup này đã được verify trong:

- `docker/private-chain/`

Nhưng đây **không phải** Clique PoA thật.

### B. Three execution nodes with peer connectivity

Hiện tại cũng có thể dựng:

- 3 execution nodes
- cùng genesis
- kết nối peer với nhau qua P2P

Điều này đã được verify trong:

- `docker/three-node/`

Nhưng đây **không phải** PoA network có authority-based block production.

## Practical Options Going Forward

### Option 1: Implement real PoA in this repo

Nếu mục tiêu là PoA thật trên chính fork này, cần:

1. Khôi phục hoặc viết lại `Clique.Seal()`
2. Xác định lại chain config tương thích với Clique path hiện tại
3. Kiểm tra toàn bộ flow:
   - block production
   - signer rotation
   - voting
   - header verification
   - genesis compatibility

Đây là một **consensus-engine change**, không còn là task tài liệu/Docker đơn thuần.

### Option 2: Re-scope thành 3-node execution lab

Nếu mục tiêu thực chỉ là:

- nhiều node
- cùng chain
- peer connectivity
- test RPC/traceability/networking

thì nên đổi scope sang:

- execution node lab

thay vì dùng từ `PoA`.

### Option 3: Use another stack for real authority-based private chain

Nếu mục tiêu là:

- private chain thật
- nhiều validator
- authority-based block production

thì nên cân nhắc stack khác phù hợp hơn, ví dụ:

- Besu IBFT/QBFT
- một post-Merge stack đầy đủ với consensus layer

## Recommended Decision

Khuyến nghị:

- **Không triển khai plan Clique PoA hiện tại như đang viết**
- hoặc:
  - đổi plan thành “khôi phục hỗ trợ Clique sealing trong codebase”
- hoặc:
  - đổi scope thành “3-node execution lab”

## Bottom Line

Trên fork `go-ethereum-trace` hiện tại:

- **PoA/Clique implementation is not feasible without Go code changes**
- Docker/scripts/genesis-only approach là **không đủ**
- Repo hiện phù hợp hơn với:
  - single-node `--dev` chain
  - multi-node execution connectivity lab

