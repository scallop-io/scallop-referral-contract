# 安全審計報告：Scallop Referral Contract

[English](security-audit.md)

**合約**：`ScallopReferralProgram`
**Repository**：`scallop-io/scallop-referral-contract`
**審計日期**：2026-03-10
**依據**：原始碼審查、`sui move test`、`sui move test --coverage`

## 執行摘要

本次審計發現兩個程式層級問題，均已修正。合約採用 Move 標準安全機制（溢位中止算術運算、capability 管控的管理員函數、版本控制）。目前剩餘的缺口僅限於缺少使用真實 `VeScaTable` / `VeScaKey` 狀態的完整端對端整合測試。

## 審計範圍

審查模組：

- `sources/scallop_referral_program.move` — 推薦票據 claim/burn 生命週期
- `sources/referral_bindings.move` — 受薦人與推薦人映射
- `sources/referral_tiers.move` — 等級配置與查詢
- `sources/referral_revenue_pool.move` — 收益分配與領取
- `sources/admin.move` — 管理操作
- `sources/version.move` — 版本守衛
- `sources/sorted_list.move` — 排序清單工具

## 發現

### [M-01] 百分比配置允許超過 100 的數值（已修正）

- **模組**：`sources/referral_tiers.move`
- **嚴重度**：Medium
- **狀態**：Fixed

`add_tier` 中的 `referral_share` 與 `borrow_fee_discount` 參數接受任意 `u64` 值，無上限驗證。超過 100 的數值與預期的百分比語意不符。

**修正方式**：

- 新增 `MAX_PERCENTAGE = 100` 常數
- 新增 `ERROR_INVALID_REFERRAL_SHARE = 603` 與 `ERROR_INVALID_BORROW_FEE_DISCOUNT = 604`
- 在 `add_tier` 中強制驗證
- 在 tier 測試與 admin 入口點測試中新增回歸測試

### [L-01] 既有 referrer 的缺失 coin claim 路徑（已修正）

- **模組**：`sources/referral_revenue_pool.move`
- **嚴重度**：Low
- **狀態**：Fixed

當 referrer 存在於 `ve_sca_revenue_data` 但對被請求的 `CoinType` 沒有收入記錄時，claim 邏輯可能進入非預期的程式路徑，而非回傳零餘額。

**修正方式**：

- 重構為共用的內部 claim 路徑
- 請求收入為零時直接回傳零餘額
- 新增防禦性斷言處理不一致狀態（帳上記錄非零但 pool 未初始化對應幣種）
- 回歸測試涵蓋：正常 claim、重複 claim 回傳零、claim 不存在的幣種回傳零

## 設計觀察

### 綁定資料可能過期（資訊性）

- **模組**：`sources/referral_bindings.move`

綁定關係為持久性，但 veSCA 狀態會隨時間變化。推薦人的 veSCA 到期後綁定仍然存在。此為已知的產品行為，非程式缺陷，但可能造成使用者困惑。

### 整合測試覆蓋（資訊性）

- **模組**：`sources/scallop_referral_program.move`

主推薦票據流程透過 test-only wrapper 直接提供 veSCA 數量與綁定狀態進行測試。本 package 未執行經由真實 `VeScaTable` 與 `VeScaKey` 狀態的完整端對端測試。模組覆蓋率為 61.78%。

## 測試摘要

| 指標 | 數值 |
|------|------|
| 測試 | 129 / 129 通過 |
| 整體覆蓋率 | 84.08% |

各模組覆蓋率詳見[測試報告](test-report.zh-TW.md)。

## 結論

所有已發現的程式層級問題均已修正。合約受益於 Move 的溢位中止算術運算機制，可防止靜默整數回繞。目前主要剩餘缺口為缺少使用正式環境 `VeScaTable` / `VeScaKey` 物件的端對端整合測試。
