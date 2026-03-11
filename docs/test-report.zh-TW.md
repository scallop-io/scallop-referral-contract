# 測試報告

[English](test-report.md)

**日期**：2026-03-10
**Sui CLI 版本**：1.63.2
**執行指令**：`sui move test`、`sui move test --coverage`

## 摘要

| 指標 | 數值 |
|------|------|
| 測試總數 | 129 |
| 通過 | 129 |
| 失敗 | 0 |
| 通過率 | 100% |
| 整體 Move 覆蓋率 | 84.08% |

## 各模組覆蓋率

| 模組 | 覆蓋率 |
|------|--------|
| `referral_tiers` | 87.72% |
| `asc_u64_sorted_list` | 87.71% |
| `version` | 83.33% |
| `admin` | 78.72% |
| `referral_bindings` | 69.12% |
| `referral_revenue_pool` | 67.70% |
| `scallop_referral_program` | 61.78% |

## 測試分類

測試涵蓋以下範疇：

- **等級配置與查詢** — 邊界值、百分比驗證（`MAX_PERCENTAGE = 100`）、依 veSCA 數量排序
- **推薦綁定生命週期** — 綁定、解綁、重新綁定、重複綁定防護、veSCA 過期處理
- **收益池** — 累積、領取、零餘額路徑、缺失幣種路徑
- **推薦票據流程** — claim 與 burn 生命週期、折扣套用、失敗案例
- **管理操作** — 透過 admin capability 管理等級、版本控制更新
- **排序清單** — 插入、移除、排序不變量、邊界案例（空清單、單一元素、重複值）
- **版本守衛** — 跨模組版本不符的強制檢查

## 已知限制

- `scallop_referral_program` 測試透過 test-only wrapper 提供 veSCA 狀態。本 package 未執行使用真實 `VeScaTable` / `VeScaKey` 物件的完整端對端整合測試。
- Sui CLI 1.63.2 的 `sui move coverage source` 在部分模組上不穩定。各模組覆蓋率採用 `sui move coverage summary --test -q` 的結果。
