# 測試報告

**日期：** 2026-03-10
**Sui CLI 版本：** `1.63.2`
**執行指令：** `sui move test` 與 `sui move test --coverage`

## 摘要

| 指標 | 數值 |
|------|------|
| 測試總數 | 129 |
| 通過 | 129 |
| 失敗 | 0 |
| 通過率 | 100% |
| 整體 Move Coverage | 84.08% |

## 覆蓋率摘要

| 模組 | 覆蓋率 |
|------|--------|
| `version` | 83.33% |
| `asc_u64_sorted_list` | 87.71% |
| `referral_tiers` | 87.72% |
| `admin` | 78.72% |
| `referral_bindings` | 69.12% |
| `referral_revenue_pool` | 67.70% |
| `scallop_referral_program` | 61.78% |

## 備註

- 先前文件記載的 `21` 個測試已過時；目前實際是 `129` 個 Move 單元測試。
- `referral_revenue_pool` 在補上 claim path 的測試後，coverage 從 `42.55%` 提升到 `67.70%`。
- `scallop_referral_program` 在補上 claim / burn 主流程與失敗案例後，coverage 已從 `0.00%` 提升到 `61.78%`。
- 目前剩下的缺口是：本 package 仍未直接用真實 `VeScaTable` / `VeScaKey` 狀態做完整 end-to-end 測試。
- Sui `1.63.2` 的 coverage source 檢視在部分模組上會不穩定；本報告採用可成功完成的 `sui move coverage summary --test -q` 結果。
