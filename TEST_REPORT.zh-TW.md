# 測試報告

**日期：** 2026-01-17
**Sui CLI 版本：** 1.63.2
**結果：** 全部測試通過

## 摘要

| 指標 | 數值 |
|------|------|
| 測試總數 | 21 |
| 通過 | 21 |
| 失敗 | 0 |
| 通過率 | 100% |

## 各模組測試結果

### asc_u64_sorted_list（3 個測試）

| 測試名稱 | 狀態 |
|----------|------|
| `insert_test` | 通過 |
| `remove_test` | 通過 |
| `upper_bound_test` | 通過 |

### sorted_list_test（2 個測試）

| 測試名稱 | 狀態 |
|----------|------|
| `test_find` | 通過 |
| `test_insert` | 通過 |

### referral_tiers_test（10 個測試）

| 測試名稱 | 狀態 | 說明 |
|----------|------|------|
| `referral_tiers_test` | 通過 | 基本層級查詢功能 |
| `test_remove_tier` | 通過 | 移除層級並驗證回退行為 |
| `test_exact_tier_boundaries` | 通過 | 邊界值測試 |
| `test_single_tier` | 通過 | 單一層級配置 |
| `test_different_discounts_per_tier` | 通過 | 不同的折扣率 |
| `test_add_tiers_in_random_order` | 通過 | 非順序新增層級 |
| `test_add_duplicate_tier_should_fail` | 通過 | 重複層級錯誤處理 |
| `test_remove_nonexistent_tier_should_fail` | 通過 | 不存在層級錯誤處理 |
| `test_remove_and_readd_tier` | 通過 | 層級移除與重新新增 |

### referral_bindings_test（7 個測試）

| 測試名稱 | 狀態 | 說明 |
|----------|------|------|
| `test_bind_and_get_binding` | 通過 | 基本綁定與查詢功能 |
| `test_unbind` | 通過 | 解除綁定功能 |
| `test_is_binded_to_the_given_referrer_ve_sca` | 通過 | 特定推薦人綁定檢查 |
| `test_multiple_referees` | 通過 | 多個受薦人與不同推薦人 |
| `test_rebind_after_unbind` | 通過 | 解綁後重新綁定至不同推薦人 |
| `test_bind_already_binded_should_fail` | 通過 | 重複綁定錯誤（錯誤碼 405） |
| `test_unbind_not_binded_should_fail` | 通過 | 未綁定時解綁錯誤（錯誤碼 406） |

## 測試覆蓋率

| 模組 | 已覆蓋 | 備註 |
|------|--------|------|
| `asc_u64_sorted_list` | 是 | 插入、移除、查找操作 |
| `referral_tiers` | 是 | 新增、移除、查找層級操作 |
| `referral_bindings` | 是 | 綁定、解綁、查詢操作 |
| `referral_revenue_pool` | 部分 | 完整測試需要主網依賴 |
| `scallop_referral_program` | 部分 | 完整測試需要主網依賴 |
| `admin` | 否 | 管理功能需要整合測試 |

## 備註

- 測試設計為單元測試，繞過外部主網依賴
- `referral_bindings_test` 使用 `bind_for_test` 輔助函數以避免 VeScaTable 驗證
- 錯誤處理測試驗證正確的中止碼（405、406、601、602）
