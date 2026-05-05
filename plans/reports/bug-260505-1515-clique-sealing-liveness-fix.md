# Bug Report: Clique Sealing Liveness Failure on Signer Set Change

**Date:** 2026-05-05  
**Branch:** poa-tracing  
**File affected:** `miner/sealing.go`  
**Severity:** Critical — chain stalls completely, no blocks produced

---

## 1. Triệu chứng

Sau khi vote thêm validator mới (node4) vào signer set đang có 3 validators, chain bị stall — không produce block mới. Tất cả nodes báo một trong hai trạng thái:

- **In-turn node:** `WARN Clique sealing iteration failed err="signed recently, must wait for others"` (lặp mỗi giây)
- **Out-of-turn nodes:** Im lặng hoàn toàn, chỉ log `Looking for peers`

---

## 2. Root Cause

### 2.1 Hạn chế trong `miner/sealing.go`

File `miner/sealing.go` hàm `sealNextBlock()` có đoạn code:

```go
// Only the in-turn signer actively seals the next block.
if work.block.Difficulty().Cmp(big.NewInt(2)) != 0 {
    return miner.waitForHeadChange(stop, headCh, subErr)
}
```

Điều này có nghĩa: **chỉ in-turn signer mới được phép seal block**. Out-of-turn signers bị chặn — chỉ chờ head mới mà không làm gì.

### 2.2 Cơ chế Clique "signed recently"

Trong Clique PoA, một signer bị chặn ký nếu ký quá gần đây:

```
LIMIT = floor(N/2) + 1
Không được ký nếu: last_signed_block > current_block - LIMIT
```

| Số signers (N) | LIMIT |
|---|---|
| 3 | 2 |
| 4 | 3 |
| 5 | 3 |

### 2.3 Chuỗi sự kiện dẫn đến deadlock

**Trạng thái ban đầu:** 3 signers (node1, node2, node3), LIMIT = 2.

Các nodes rotate seal với LIMIT=2, tức mỗi node ký cách nhau ~2 blocks:

```
block 53: node2
block 54: node3  
block 55: node3 (vote node4 vào signer set — coinbase = node4 address)
block 56: node1 (vote node4 — đủ 2/3 votes, node4 confirmed)
```

**Sau block 56:** N = 4, LIMIT = 3. Snapshot `recents` = `{55: node3, 56: node1}`.

Xét block 57 (next block cần mine):
- **In-turn** cho block 57: `57 % 4 = 1` → index 1 trong sorted signers → **node3**
- node3 ký block 55: `55 > 57 - 3 = 54` → **bị chặn bởi "signed recently"**

Kết quả:
- node3 (in-turn): cố seal → thất bại → log WARN mỗi giây
- node2, node1 (out-of-turn): thấy difficulty = 1 (not in-turn) → `waitForHeadChange` → **chờ mãi mãi**
- node4 (out-of-turn, chưa ký lần nào): thấy difficulty = 1 → `waitForHeadChange` → **chờ mãi mãi**

**→ Không ai seal được block 57. Chain deadlock.**

---

## 3. Cách sửa

**File:** `miner/sealing.go`  
**Phương pháp:** Comment out điều kiện giới hạn in-turn only, cho phép out-of-turn signers cũng tham gia seal.

```go
// TRƯỚC (gây liveness bug):
if work.block.Difficulty().Cmp(big.NewInt(2)) != 0 {
    return miner.waitForHeadChange(stop, headCh, subErr)
}

// SAU (comment out, kèm giải thích):
// NOTE: This restriction is intentionally disabled — allowing out-of-turn signers
// to seal prevents liveness failures when the in-turn signer is temporarily
// blocked by "signed recently" after a signer-set change. Clique.Seal() already
// applies wiggle delay for out-of-turn blocks so signers are naturally spread out.
// if work.block.Difficulty().Cmp(big.NewInt(2)) != 0 {
// 	return miner.waitForHeadChange(stop, headCh, subErr)
// }
```

**Đồng thời** xóa import `"math/big"` (không còn dùng sau khi comment) để tránh compile error.

### Tại sao cách này đúng

Clique EIP-225 thiết kế từ đầu cho phép out-of-turn sealing với wiggle delay để tránh race:

```go
// Trong consensus/clique/clique.go — Seal():
delay := time.Unix(int64(header.Time), 0).Sub(time.Now())
if header.Difficulty.Cmp(diffNoTurn) == 0 {
    wiggle := time.Duration(len(snap.Signers)/2+1) * wiggleTime  // max ~1500ms với 4 signers
    delay += time.Duration(rand.Int63n(int64(wiggle)))
}
```

In-turn block (difficulty=2) được seal ngay. Out-of-turn block (difficulty=1) bị delay ngẫu nhiên 0–1500ms. Khi out-of-turn block đang chuẩn bị seal mà nhận được in-turn block qua `headCh` → hủy ngay.

Code gốc của fork đã **tắt** cơ chế này để tránh competing blocks, nhưng vô tình gây liveness failure khi in-turn signer bị blocked.

---

## 4. Hậu quả của việc sửa

### 4.1 Tích cực
| Điểm | Mô tả |
|---|---|
| **Liveness** | Chain không bị deadlock khi signer set thay đổi |
| **Spec compliance** | Đúng với Clique EIP-225 gốc |
| **Tự phục hồi** | Nếu in-turn bị block, out-of-turn tự động seal sau wiggle |

### 4.2 Trade-off cần lưu ý

| Điểm | Mô tả | Mức độ |
|---|---|---|
| **Competing blocks** | Out-of-turn nodes cũng seal → đôi khi có 2 block cùng height. Tự resolve: in-turn (diff=2) thắng out-of-turn (diff=1) | Thấp |
| **Network traffic** | Nhiều block proposals hơn khi in-turn bị delay | Thấp |
| **Temporary micro-forks** | Node nhận out-of-turn block trước, sau đó reorg sang in-turn block | Rất thấp, <1s |

### 4.3 Không ảnh hưởng đến
- Block time (vẫn 5s)
- Tính đúng đắn của txn (không có double-spend)
- Finality của chain
- Clique consensus rules

---

## 5. Khuyến nghị

Fix này là **bắt buộc** nếu muốn thêm validators vào chain đang chạy. Behavior mới hoàn toàn tuân theo EIP-225 — đây là phục hồi behavior đúng, không phải thêm logic mới.

Nếu muốn giảm thiểu competing blocks trong tương lai, có thể tăng `wiggleTime` trong `consensus/clique/clique.go` thay vì tắt out-of-turn sealing.

---

*Unresolved questions: Không có.*
