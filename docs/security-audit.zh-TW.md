# 安全審計報告：Scallop Referral Contract

**合約**：`ScallopReferralProgram`  
**Repository**：`scallop-io/scallop-referral-contract`  
**審查日期**：2026-03-10  
**依據**：目前本地原始碼、`sui move test`、`sui move test --coverage`

## 執行摘要

先前的審計文件對目前版本的專案並不準確，尤其在測試覆蓋率與 finding 判斷上都有明顯失真。

這次審查確認的兩個實際問題是：

1. Tier 設定允許大於 `100` 的百分比，會造成管理員配置錯誤。
2. 已存在的 referrer 若對某個 `CoinType` 沒有收入，claim path 可能走到不合理分支，而不是乾淨地回傳 `0`。

以上兩點都已在程式中修正。

## 更正後的判斷

### 先前報告中不成立或誇大的部分

- `H-01 increase_revenue_data 算術溢位`: **不成立**
  - 先前報告把 Move 整數運算當成會靜默 wrap。
  - 這個前提在目前環境下是錯的：Move 的整數溢位會 abort，不會默默回繞。
  - 因此不應被列為高風險鎖倉漏洞。

- “Formal verification”、“fuzz testing” 與完整整合保證：**缺乏依據**
  - 專案裡有單元測試，但沒有 formal verification artifact。
  - 舊版本確實缺少 `scallop_referral_program` 的直接測試，但這點在本次審查後已不再成立。
  - 即便如此，因為沒有 formal artifact，而且目前測試仍屬部分整合測試而非完整 end-to-end，所以先前文件仍然高估了整體保證程度。

### 這次確認為有效的問題

#### 已修正：百分比配置缺乏驗證

- 模組：`sources/referral_tiers.move`
- 嚴重度：Medium
- 狀態：Fixed

原本 `referral_share` 與 `borrow_fee_discount` 是任意 `u64`，管理員可寫入超過 `100` 的數值，與註解中的百分比語意不一致。

修正內容：

- 新增 `MAX_PERCENTAGE = 100`
- 新增 `ERROR_INVALID_REFERRAL_SHARE = 603`
- 新增 `ERROR_INVALID_BORROW_FEE_DISCOUNT = 604`
- 在 `add_tier` 中強制檢查
- 新增直接 tier 測試與 admin entry 測試

#### 已修正：既有 referrer 的缺失 coin claim path

- 模組：`sources/referral_revenue_pool.move`
- 嚴重度：Low
- 狀態：Fixed

如果某個 referrer 已存在於 `ve_sca_revenue_data`，但對被 claim 的 `CoinType` 並沒有收入，claim 邏輯不該繼續往 pool split 的路徑走。

修正內容：

- 抽出共用 claim 內部邏輯
- 請求的收入為 `0` 時直接回傳 zero balance
- 若帳上記錄為非零，但 pool 沒有對應 coin bucket，加入防禦性 assert
- 新增回歸測試：
  - 正常 claim
  - 重複 claim 會回傳 0
  - claim 不存在的 coin type 會回傳 0

## 剩餘風險 / 測試缺口

### 主整合模組已有測試，但仍不是完整整合驗證

- 模組：`sources/scallop_referral_program.move`
- 嚴重度：Informational

主 referral ticket 流程現在已經有直接測試，coverage 提升到 `61.78%`。不過目前測試是透過 test-only wrapper 餵入 veSCA amount / binding 狀態，還不是使用真實 `VeScaTable` / `VeScaKey` 的完整 end-to-end 路徑。

因此，若審計結論聲稱 borrow referral 的整合行為已被完整驗證，仍然會過度樂觀。

### 綁定資料過期仍屬產品行為風險

- 模組：`sources/referral_bindings.move`
- 嚴重度：Informational

binding 是持久的，但 veSCA 狀態是隨時間變化的。這不一定是安全漏洞，但仍可能造成使用者體驗上的混淆。

## 目前測試現況

- `129 / 129` 測試通過
- 整體 Move coverage：`84.08%`
- `referral_revenue_pool`：`67.70%`
- `referral_tiers`：`87.72%`
- `scallop_referral_program`：`61.78%`

## 結論

目前合約的實際狀態和先前報告描述並不一致。舊報告錯誤地列出高風險算術問題，也錯誤描述了整合測試現況。這次修正後，本地可確認的程式問題已處理完成；剩下最重要的風險不再是 `scallop_referral_program` 完全沒測，而是缺少真實 veSCA 狀態驅動的完整 end-to-end 測試。
