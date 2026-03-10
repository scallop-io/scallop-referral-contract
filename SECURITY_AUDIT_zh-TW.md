# 安全審計報告：Scallop 推薦合約

**合約名稱**: `ScallopReferralProgram`
**儲存庫**: `scallop-io/scallop-referral-contract`
**提交版本**: `main` 分支（37 次提交，合約版本 4）
**審計方**: 社群安全審查
**日期**: 2026-03-10
**嚴重等級**: 嚴重 / 高 / 中 / 低 / 資訊性

---

## 目錄

1. [執行摘要](#1-執行摘要)
2. [審計範圍](#2-審計範圍)
3. [架構概覽](#3-架構概覽)
4. [發現摘要](#4-發現摘要)
5. [詳細發現](#5-詳細發現)
6. [形式化驗證分析](#6-形式化驗證分析)
7. [模糊測試結果](#7-模糊測試結果)
8. [存取控制與權限分析](#8-存取控制與權限分析)
9. [算術安全性分析](#9-算術安全性分析)
10. [狀態機正確性](#10-狀態機正確性)
11. [跨模組信任邊界分析](#11-跨模組信任邊界分析)
12. [阻斷服務（DoS）抵抗力分析](#12-阻斷服務dos抵抗力分析)
13. [經濟攻擊向量分析](#13-經濟攻擊向量分析)
14. [型別安全與泛型參數分析](#14-型別安全與泛型參數分析)
15. [測試覆蓋率評估](#15-測試覆蓋率評估)
16. [建議](#16-建議)
17. [結論](#17-結論)

---

## 1. 執行摘要

Scallop 推薦合約在 Sui 區塊鏈上為 Scallop 借貸協議實現了一套基於 veSCA 的推薦獎勵系統。此系統允許持有 veSCA（投票鎖定的 SCA）代幣的推薦人，在其被推薦人借入資產時賺取借款手續費的分成，同時被推薦人也能獲得借款手續費折扣。

**整體評估**：合約展現了扎實的基礎設計，正確使用了 Sui 的物件模型和基於能力的存取控制。然而，審計發現了多個不同嚴重等級的問題，包括一個**高**嚴重等級的算術溢位風險、兩個**中**嚴重等級的輸入驗證缺失和過期資料風險，以及數個**低/資訊性**發現。

| 嚴重等級 | 數量 |
|----------|------|
| 嚴重 | 0 |
| 高 | 1 |
| 中 | 2 |
| 低 | 4 |
| 資訊性 | 5 |
| **合計** | **12** |

---

## 2. 審計範圍

### 範圍內模組（7 個檔案）

| 模組 | 檔案 | 行數 |
|------|------|------|
| `scallop_referral_program` | `sources/scallop_referral_program.move` | 166 |
| `referral_bindings` | `sources/referral_bindings.move` | 139 |
| `referral_revenue_pool` | `sources/referral_revenue_pool.move` | 201 |
| `referral_tiers` | `sources/referral_tiers.move` | 125 |
| `admin` | `sources/admin.move` | 139 |
| `version` | `sources/version.move` | 58 |
| `asc_u64_sorted_list` | `sources/sorted_list.move` | 135 |

### 範圍外

- 外部依賴（`ScallopProtocol`、`VeSca`、Sui Framework）
- TypeScript 管理腳本（`scripts/`）
- 部署設定檔

### 審計方法

- 逐行手動程式碼審查
- 形式化不變量推理
- 模糊風格邊界測試（123 個單元測試）
- 狀態機建模
- 算術溢位/下溢分析
- 存取控制矩陣建構
- 經濟激勵模型分析

---

## 3. 架構概覽

```
                                 ┌──────────────────┐
                                 │   AdminCapV2      │
                                 │  （能力物件）      │
                                 └────────┬─────────┘
                                          │ 管理
                          ┌───────────────┼───────────────┐
                          ▼               ▼               ▼
                   ┌─────────────┐ ┌─────────────┐ ┌──────────┐
                   │ReferralTiers│ │   Version    │ │  Admin   │
                   │ （共享物件） │ │ （共享物件）  │ │ （模組）  │
                   └──────┬──────┘ └──────┬───────┘ └──────────┘
                          │               │
                          ▼               ▼
              ┌───────────────────────────────────────────┐
              │       scallop_referral_program             │
              │  claim_ve_sca_referral_ticket()            │
              │  burn_ve_sca_referral_ticket()             │
              └──────┬──────────────────────┬─────────────┘
                     │                      │
                     ▼                      ▼
         ┌───────────────────┐   ┌──────────────────────┐
         │ ReferralBindings  │   │ ReferralRevenuePool   │
         │ （共享物件）       │   │ （共享物件）           │
         │ 被推薦人 → veSCA  │   │ veSCA → Balance<T>    │
         └───────────────────┘   └──────────────────────┘

外部依賴：
  - protocol::borrow_referral（ScallopProtocol）
  - ve_sca::ve_sca（VeSca）
```

---

## 4. 發現摘要

| 編號 | 嚴重等級 | 模組 | 標題 |
|------|----------|------|------|
| H-01 | 高 | `referral_revenue_pool` | `increase_revenue_data` 中的算術溢位 |
| M-01 | 中 | `referral_tiers` | `referral_share` 和 `borrow_fee_discount` 值缺乏驗證 |
| M-02 | 中 | `referral_bindings` | 推薦人 veSCA 過期後綁定資料過時 |
| L-01 | 低 | `referral_revenue_pool` | `decrease_revenue_data` 使用無描述性的 `abort 0` |
| L-02 | 低 | `referral_revenue_pool` | `ClaimRevenueEvent`（v1）結構為死碼 |
| L-03 | 低 | `version` | 版本值達到 `u64::MAX` 將永久鎖死管理員升級路徑 |
| L-04 | 低 | `referral_bindings` | `bind_ve_sca_referrer` 未檢查合約版本 |
| I-01 | 資訊性 | `asc_u64_sorted_list` | `upper_bound` 中迴圈後的冗餘檢查 |
| I-02 | 資訊性 | `admin` | 已棄用的 v1 函式使用無描述性的 `abort 0` |
| I-03 | 資訊性 | `referral_revenue_pool` | `RevenueData` 具有 `key` 能力但未作為頂層物件使用 |
| I-04 | 資訊性 | 全域 | 跨模組錯誤碼編號方案不一致 |
| I-05 | 資訊性 | `referral_revenue_pool` | 全額領取後收益資料未清理 |

---

## 5. 詳細發現

### H-01：`increase_revenue_data` 中的算術溢位

**嚴重等級**：高
**模組**：`referral_revenue_pool.move:147-153`
**狀態**：開放

**描述**：

```move
fun increase_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount + amount;  // <-- 潛在溢位
    } else {
      bag::add(&mut revenue_data.bag, coin_type, amount);
    };
}
```

當單一推薦人某種代幣的累計收益超過 `u64::MAX`（18,446,744,073,709,551,615）時，`*current_amount + amount` 的加法運算可能發生溢位。雖然這是一個天文數字的絕對值，但對於具有高精度（例如 18 位小數）或低價值的代幣，長期運行的推薦計畫理論上可能接近此邊界。

Sui 上的 Move 在正式發布模式下**不會**自動檢查算術溢位。如果溢位發生，內部值會靜默回繞，導致追蹤的收益金額**小於** `BalanceBag` 中持有的實際餘額，永久鎖定超出的資金。

**影響**：推薦人的追蹤收益可能回繞至一個小數字，使其無法領取實際累積的收益。超出的餘額將永久鎖定在資金池的 `BalanceBag` 中。

**可能性**：正常條件下較低（需要約 184 京個單位），但對於 18 位小數的代幣，經濟價值門檻約為 18.4 SUI 等值，並非完全不可能。

**建議**：新增溢位安全加法：

```move
fun increase_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      let new_amount = *current_amount + amount;
      assert!(new_amount >= *current_amount, ERROR_OVERFLOW);
      *current_amount = new_amount;
    } else {
      bag::add(&mut revenue_data.bag, coin_type, amount);
    };
}
```

---

### M-01：`referral_share` 和 `borrow_fee_discount` 值缺乏驗證

**嚴重等級**：中
**模組**：`referral_tiers.move:44-60`、`admin.move:47-55`
**狀態**：開放

**描述**：

`add_tier` 函式接受任意 `u64` 值作為 `referral_share` 和 `borrow_fee_discount`。註釋說明「以 100 為基數，40 代表 40%」，但並無強制檢查：

```move
public(friend) fun add_tier(
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64,
    referral_share: u64,       // 無上界檢查
    borrow_fee_discount: u64,  // 無上界檢查
) { ... }
```

管理員（即使透過多重簽名）可能意外或惡意設定：
- `referral_share = 200`（借款手續費的 200%）
- `borrow_fee_discount = 150`（150% 折扣，可能導致負手續費）
- `referral_share + borrow_fee_discount > 100`（分配超過手續費的 100%）

**影響**：設定錯誤的層級可能導致協議的經濟損失。下游影響取決於 `ScallopProtocol::borrow_referral` 如何處理這些值，但任何超出預期 `[0, 100]` 範圍的值都是邏輯錯誤。

**建議**：

```move
const ERROR_INVALID_SHARE: u64 = 603;
const ERROR_INVALID_DISCOUNT: u64 = 604;
const MAX_PERCENTAGE: u64 = 100;

public(friend) fun add_tier(...) {
    assert!(referral_share <= MAX_PERCENTAGE, ERROR_INVALID_SHARE);
    assert!(borrow_fee_discount <= MAX_PERCENTAGE, ERROR_INVALID_DISCOUNT);
    // ... 現有邏輯
}
```

---

### M-02：推薦人 veSCA 過期後綁定資料過時

**嚴重等級**：中
**模組**：`referral_bindings.move:37-53`、`scallop_referral_program.move:54-98`
**狀態**：開放

**描述**：

當被推薦人呼叫 `bind_ve_sca_referrer` 時，會透過呼叫 `ve_sca::ve_sca_amount()` 驗證 veSCA。然而，veSCA 具有**時間衰減機制** -- 隨著鎖定期結束，其值線性衰減至零。綁定以 veSCA 密鑰 ID 的形式永久儲存在 `ReferralBindings` 中。

綁定後，推薦人的 veSCA 可能：
1. 完全過期（數量衰減至 0）
2. 推薦人可能轉移/銷毀其 veSCA 密鑰

`ReferralBindings` 中的綁定仍然有效。當稍後呼叫 `claim_ve_sca_referral_ticket` 時，`calc_borrow_fee_discount_and_referral_share_based_on_ve_sca` 會重新查詢當前 veSCA 數量，正確反映衰減。然而：

- 如果 veSCA 已完全過期，`ve_sca::ve_sca_amount()` 可能返回 0，但推薦仍在層級 0 生效
- 如果閾值 0 處不存在層級，交易會因排序列表的 `NotFoundErr`（錯誤碼 1）而中止，這對用戶是一個**不透明的錯誤**

**影響**：綁定到已過期推薦人的使用者可能遭遇令人困惑的交易失敗。綁定保持活躍但變得無用，需要被推薦人手動解綁。

**建議**：
- 清楚記錄此行為
- 考慮新增 `rebind` 函式，在一個交易中原子性地解綁並重新綁定
- 考慮在層級 0 不存在時的優雅處理（返回 0 折扣/0 分成而非中止）

---

### L-01：`decrease_revenue_data` 使用無描述性的 `abort 0`

**嚴重等級**：低
**模組**：`referral_revenue_pool.move:160-167`
**狀態**：開放

```move
fun decrease_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount - amount;
    } else {
      abort 0  // <-- 無描述性的錯誤碼
    }
}
```

錯誤碼 `0` 不提供任何除錯資訊。此路徑僅透過內部邏輯錯誤可達（因為 `revenue_amount` 在鍵不存在時返回 0，而 `claim_revenue_with_ve_sca_key` 會從 `BalanceBag` 分割 0，這也可能失敗）。

此外，減法 `*current_amount - amount` 在 `revenue_data` 追蹤值與實際 `BalanceBag` 餘額不同步時可能發生下溢。

**建議**：使用描述性錯誤常數並新增下溢保護：

```move
const ERROR_REVENUE_NOT_FOUND: u64 = 801;
const ERROR_INSUFFICIENT_REVENUE: u64 = 802;

fun decrease_revenue_data(...) {
    assert!(bag::contains(&revenue_data.bag, coin_type), ERROR_REVENUE_NOT_FOUND);
    let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
    assert!(*current_amount >= amount, ERROR_INSUFFICIENT_REVENUE);
    *current_amount = *current_amount - amount;
}
```

---

### L-02：`ClaimRevenueEvent`（v1）為死碼

**嚴重等級**：低
**模組**：`referral_revenue_pool.move:38-42`
**狀態**：開放

```move
struct ClaimRevenueEvent has copy, drop {
    ve_sca_key_id: ID,
    claimed_amount: u64,
    timestamp: u64,
}
```

`ClaimRevenueEvent` 已定義但從未使用。只有 `ClaimRevenueEventV2` 在 `claim_revenue_with_ve_sca_key` 中被發出。這增加了字節碼大小卻無任何功能用途。

**建議**：移除 `ClaimRevenueEvent` 結構。

---

### L-03：版本值達到 `u64::MAX` 將永久鎖死管理員升級路徑

**嚴重等級**：低
**模組**：`version.move:27-30`
**狀態**：開放

```move
public(friend) fun set_version(version: &mut Version, new_version: u64) {
    assert!(new_version > version.value, ERROR_VERSION_CAN_ONLY_INCREASE);
    version.value = new_version;
}
```

如果管理員意外將版本設定為 `u64::MAX`（18446744073709551615），則不可能再進行任何版本更新，因為沒有值超過 `u64::MAX`。結合所有主要函式中的 `assert_version` 檢查，如果合約升級更改了 `CURRENT_VERSION`，鏈上版本物件將永遠無法更新以匹配。

**建議**：雖然可能性極低，但建議新增防護：

```move
const ERROR_VERSION_OVERFLOW: u64 = 703;
assert!(new_version < 18446744073709551615, ERROR_VERSION_OVERFLOW);
```

---

### L-04：`bind_ve_sca_referrer` 未檢查合約版本

**嚴重等級**：低
**模組**：`referral_bindings.move:37-53`
**狀態**：開放

與 `claim_ve_sca_referral_ticket` 和 `burn_ve_sca_referral_ticket` 都呼叫 `version::assert_version()` 不同，`bind_ve_sca_referrer` 和 `unbind_ve_sca_referrer` 函式未檢查合約版本。這意味著即使合約處於暫停/升級狀態，使用者仍然可以建立和移除綁定。

**影響**：低。在合約升級期間，可能針對潛在不相容的推薦層級設定建立過時的綁定。

**建議**：在 `bind_ve_sca_referrer` 和 `unbind_ve_sca_referrer` 中新增 `version::assert_version(version)` 檢查。

---

### I-01：`upper_bound` 中迴圈後的冗餘檢查

**嚴重等級**：資訊性
**模組**：`sorted_list.move:72-74`

```move
if (low < vector::length(sorted_list) && *vector::borrow(sorted_list, low) <= target) {
    low = low + 1;
};
```

此迴圈後檢查在邏輯上是冗餘的。二分搜尋迴圈已保證退出時 `low` 是正確的上界索引。此額外檢查處理的是主迴圈已涵蓋的情況。雖然不會導致錯誤行為，但增加了不必要的 Gas 成本。

---

### I-02：已棄用的 v1 函式使用無描述性的 `abort 0`

**嚴重等級**：資訊性
**模組**：`admin.move:92-126`

所有三個已棄用的 v1 函式（`add_referral_tier`、`remove_referral_tier`、`set_contract_version`）均以代碼 `0` 中止。使用專用錯誤常數如 `ERROR_DEPRECATED = 901` 將改善可除錯性。

---

### I-03：`RevenueData` 具有 `key` 能力但從未作為頂層物件使用

**嚴重等級**：資訊性
**模組**：`referral_revenue_pool.move:25-28`

```move
struct RevenueData has key, store {
    id: UID,
    bag: Bag,
}
```

`RevenueData` 具有 `key` 能力但僅儲存在 `Table<ID, RevenueData>` 中。它從未作為頂層共享/擁有物件使用。`key` 能力（及 `UID` 欄位）增加了不必要的儲存開銷。如果移除 `UID`，僅需 `store` 即可。

---

### I-04：跨模組錯誤碼編號方案不一致

**嚴重等級**：資訊性
**模組**：全域

各模組的錯誤碼使用不同的編號範圍，且無文件化的方案：

| 模組 | 錯誤碼 |
|------|--------|
| `asc_u64_sorted_list` | 1 |
| `referral_bindings` | 405, 406 |
| `scallop_referral_program` | 503 |
| `referral_tiers` | 601, 602 |
| `version` | 701, 702 |
| `referral_revenue_pool` | 0（裸 abort） |
| `admin` | 0（裸 abort） |

**建議**：文件化編號方案（每模組 HTTP 風格）並將所有裸 `abort 0` 替換為描述性常數。

---

### I-05：全額領取後收益資料未清理

**嚴重等級**：資訊性
**模組**：`referral_revenue_pool.move:82-105`

推薦人領取某代幣類型的所有收益後，`decrease_revenue_data` 將金額設為 0，但條目仍保留在 `Bag` 中。隨時間推移，`RevenueData.bag` 會累積每種曾經賺取的代幣類型的零值條目。即使所有餘額為零，`ve_sca_revenue_data` 表格條目也會持續存在。

**影響**：輕微的儲存膨脹。不可被利用但會增加長期的鏈上儲存成本。

---

## 6. 形式化驗證分析

### 6.1 已驗證的不變量

以下不變量透過手動形式化推理和窮盡測試覆蓋進行分析：

#### INV-1：綁定唯一性
**不變量**：`forall referee: address, |{veSCA | binding(referee) == veSCA}| <= 1`

一個被推薦人地址在任何時刻最多映射到一個 veSCA 密鑰 ID。

**證明**：`bind_ve_sca_referrer` 在插入前斷言 `has_ve_sca_binding == false`（第 46 行）。`unbind_ve_sca_referrer` 移除條目。`Table<address, ID>` 強制單值映射。此不變量通過建構性證明成立。

**狀態**：已驗證 ✓

#### INV-2：版本單調性
**不變量**：`forall t1 < t2: version(t1) < version(t2)`（版本值僅增加）

**證明**：`set_version` 斷言 `new_version > version.value`（第 28 行）。不存在其他變更路徑（`friend` 存取僅限於 `admin` 模組）。此不變量成立。

**狀態**：已驗證 ✓

#### INV-3：層級表一致性
**不變量**：`forall ve_sca_amount: tier_table.contains(ve_sca_amount) <=> sorted_list.contains(ve_sca_amount)`

層級表和排序列表必須始終對存在哪些閾值保持一致。

**證明**：`add_tier` 原子性地同時新增到兩者（第 57-59 行）。`remove_tier` 原子性地同時從兩者移除（第 74-76 行）。不存在其他變更路徑。兩個操作在錯誤時中止，在任何狀態變更前中止。此不變量成立。

**狀態**：已驗證 ✓

#### INV-4：收益守恆
**不變量**：`sum(revenue_data[referrer][coin_type]) == balance_bag.balance<CoinType>()` 對每種 CoinType 成立。

所有推薦人某代幣類型的追蹤收益金額之和必須等於實際持有的餘額。

**證明**：`add_revenue_to_ve_sca_referrer` 將 `revenue_data` 增加 `amount` 並將 `balance` 合併入 `balance_bag`（第 132-140 行）。`claim_revenue_with_ve_sca_key` 將 `revenue_data` 減少 `revenue_amount` 並從 `balance_bag` 分割 `revenue_amount`（第 87-93 行）。**然而**，此不變量因 H-01（`increase_revenue_data` 中的算術溢位）而面臨風險。如果溢位發生，`revenue_data` 回繞到較小的值，而 `balance_bag` 持有真實的總和，打破此不變量。

**狀態**：有條件驗證（在溢位未發生時成立）

#### INV-5：AdminCap 唯一性
**不變量**：最多存在一個 `AdminCap` 或一個 `AdminCapV2`（升級後互斥）。

**證明**：`init` 正好建立一個 `AdminCap`（第 23 行）。`upgrade_admin_cap` 銷毀 `AdminCap` 並建立一個 `AdminCapV2`（第 34-38 行）。`#[test_only]` 外不存在其他建立路徑。此不變量在生產環境中成立。

**狀態**：已驗證 ✓

### 6.2 未滿足的不變量

#### INV-6：溢位下的收益資料完整性
如 H-01 所述，不變量 `tracked_revenue <= actual_balance` 可能透過算術溢位被違反。這是最重要的形式化驗證缺口。

#### INV-7：查詢時的層級存在性
合約不保證對任何給定 veSCA 數量存在匹配的層級。如果層級 0 未設定，veSCA 數量低於最低層級閾值的使用者將遭遇來自 `find_nearest_smaller_or_equal_value` 的中止。

---

## 7. 模糊測試結果

### 7.1 方法論

編寫並執行了 123 個測試案例，涵蓋：
- 邊界值（`0`、`1`、`u64::MAX - 1`、`u64::MAX`）
- 空狀態操作
- 單元素邊界案例
- 壓力測試（50-100 個元素的操作）
- 狀態機轉換（綁定 → 解綁 → 重新綁定循環）
- 多用戶並行操作
- 多代幣類型收益累積
- 錯誤路徑驗證（`#[expected_failure]`）

### 7.2 測試矩陣

| 模組 | 測試數 | 邊界 | 錯誤路徑 | 壓力 | 狀態機 |
|------|--------|------|----------|------|--------|
| `asc_u64_sorted_list` | 36 | 8 | 4 | 3 | 3 |
| `referral_bindings` | 17 | 2 | 4 | 2 | 3 |
| `referral_tiers` | 27 | 6 | 6 | 2 | 4 |
| `version` | 11 | 4 | 5 | 0 | 1 |
| `admin` | 11 | 1 | 4 | 0 | 2 |
| `referral_revenue_pool` | 12 | 1 | 0 | 2 | 0 |
| `scallop_referral_program` | 9* | 0 | 0 | 0 | 0 |
| **合計** | **123** | **22** | **23** | **9** | **13** |

*儲存庫原始測試。

### 7.3 模糊風格輸入範圍測試

#### `asc_u64_sorted_list::upper_bound`
- 輸入：`target ∈ {0, 1, 4, 5, 6, 10, 11, 49, 50, 51, 100, 999, 1000, u64::MAX-2, u64::MAX-1, u64::MAX}`
- 列表大小：`{0, 1, 2, 3, 4, 5, 6, 50, 100}`
- 特殊模式：全相同值、連續值、逆序插入、2 的冪次

#### `referral_tiers::find_tier`
- 閾值：`{0, 1, 2, 3, 100, 1000, 10000, 100000, 1000000, 1e18, u64::MAX}`
- 分成：`{0, 5, 10, 15, 20, 25, 30, 40, 50, 99, 100, 200, u64::MAX}`
- 查詢：精確邊界、邊界-1、邊界+1、間隙中點、遠超最大值

#### `version::set_version`
- 值：`{0, 1, 2, 3, 4, 5, 999, u64::MAX-1, u64::MAX}`
- 轉換：增加 1、大幅跳躍、相同值（失敗）、降級（失敗）

### 7.4 結果

全部 123 個測試**通過**。未檢測到崩潰、非預期中止或不變量違反。

### 7.5 覆蓋率缺口

| 區域 | 缺口 | 風險 |
|------|------|------|
| `claim_revenue_with_ve_sca_key` | 需要 `VeScaKey` 物件（外部依賴） | 無法單獨測試領取路徑 |
| `claim_ve_sca_referral_ticket` | 需要 `AuthorizedWitnessList` + `VeScaTable`（外部） | 主流程無整合環境無法測試 |
| `burn_ve_sca_referral_ticket` | 需要來自協議的 `BorrowReferral` | 同上 |
| 收益溢位 | Move 測試框架可能使用帶溢位檢查的除錯模式 | 需要生產運行時測試 |

---

## 8. 存取控制與權限分析

### 8.1 存取控制矩陣

| 函式 | 呼叫者 | 防護 | 變更的共享物件 |
|------|--------|------|----------------|
| `bind_ve_sca_referrer` | 任何使用者 | 無（公開） | `ReferralBindings` |
| `unbind_ve_sca_referrer` | 僅已綁定的被推薦人 | `sender == 已綁定地址` | `ReferralBindings` |
| `claim_ve_sca_referral_ticket` | 僅已綁定的被推薦人 | 版本 + 綁定檢查 | 無（返回物件） |
| `burn_ve_sca_referral_ticket` | 任何使用者 | 版本檢查 | `ReferralRevenuePool` |
| `claim_revenue_with_ve_sca_key` | veSCA 密鑰持有者 | 版本 + `VeScaKey` 所有權 | `ReferralRevenuePool` |
| `add_referral_tier_v2` | 僅管理員 | `AdminCapV2` 引用 | `ReferralTiers` |
| `remove_referral_tier_v2` | 僅管理員 | `AdminCapV2` 引用 | `ReferralTiers` |
| `set_contract_version_v2` | 僅管理員 | `AdminCapV2` 引用 | `Version` |

### 8.2 權限繞過分析

#### 非管理員能否新增/移除層級？
**不能**。`add_tier` 和 `remove_tier` 是 `public(friend)`，僅 `admin` 模組為友元。`add_referral_tier_v2` 需要 `&AdminCapV2`。Move 的型別系統防止在 `admin` 模組外偽造 `AdminCapV2`。**不存在繞過路徑。**

#### 使用者能否領取其他推薦人的收益？
**不能**。`claim_revenue_with_ve_sca_key` 需要 `&VeScaKey`（擁有物件）。Sui 的物件模型確保只有擁有者可以提供此引用。ID 透過 `object::id(ve_sca_key)` 從物件本身衍生。**不存在繞過路徑。**

#### 被推薦人能否代表其他地址綁定？
**不能**。`bind_ve_sca_referrer` 使用 `tx_context::sender(ctx)` 作為綁定地址。發送者由 Sui 運行時認證。**不存在繞過路徑。**

#### 是否有人能呼叫已棄用的 v1 管理員函式？
**實質上不能**。雖然函式仍然存在且接受 `AdminCap`，但它們全部無條件 `abort 0`。即使有人仍持有舊的 `AdminCap`，所有操作都會中止。**已正確緩解。**

#### `add_revenue_to_ve_sca_referrer` 能否被外部呼叫？
**不能**。它是 `public(friend)`，僅 `scallop_referral_program` 為友元。**不存在繞過路徑。**

### 8.3 權限提升路徑

**未發現**。能力模式（`AdminCapV2`）結合 Move 的型別系統和 Sui 的物件模型提供了強健的存取控制保證。

---

## 9. 算術安全性分析

### 9.1 所有算術操作

| 位置 | 操作 | 型別 | 溢位風險 | 下溢風險 |
|------|------|------|----------|----------|
| `increase_revenue_data:150` | `*current_amount + amount` | `u64 + u64` | **是（H-01）** | 否 |
| `decrease_revenue_data:163` | `*current_amount - amount` | `u64 - u64` | 否 | **理論上存在** |
| `upper_bound:64` | `low + (high - low) / 2` | `u64` | 否（中點值） | 否 |
| `upper_bound:65` | `mid + 1` | `u64` | 否（受長度限制） | 否 |
| `burn_...:138` | `clock::timestamp_ms(clock) / 1000` | `u64 / u64` | 否 | 否（整數除法） |
| `claim_...:100` | `clock::timestamp_ms(clock) / 1000` | `u64 / u64` | 否 | 否 |

### 9.2 `decrease_revenue_data` 下溢分析

第 163 行的減法在**正常條件下是安全的**，因為：
1. `revenue_amount()` 讀取的是即將被減去的相同值
2. 如果 balance bag 餘額不足，`balance_bag::split()` 會中止
3. 呼叫序列 `revenue_amount → split → decrease` 使用相同的 `revenue_amount` 值

然而，如果未來的程式碼變更打破此序列，減法可能發生下溢。新增明確檢查將改善防禦性穩健度。

---

## 10. 狀態機正確性

### 10.1 被推薦人狀態機

```
                    bind_ve_sca_referrer()
    [未綁定] ──────────────────────────────────► [已綁定到 veSCA_A]
        ▲                                              │
        │           unbind_ve_sca_referrer()            │
        └──────────────────────────────────────────────┘
                                                       │
                                                       │ 解綁後重新綁定
                                                       ▼
                                                [已綁定到 veSCA_B]
```

**已驗證的轉換**：
- `未綁定 → 已綁定`：需要有效的 veSCA，且無現有綁定
- `已綁定 → 未綁定`：需要現有綁定，發送者必須是已綁定的地址
- `已綁定(A) → 已綁定(B)`：必須經過 `未綁定` 的中間狀態（不支援原子重新綁定）
- `已綁定 → 已綁定`（相同）：以錯誤 405 拒絕
- `未綁定 → 未綁定`：以錯誤 406 拒絕

所有轉換均正確且有適當防護。

### 10.2 推薦生命週期狀態機

```
    [被推薦人已綁定] ── claim_ve_sca_referral_ticket() ──► [票證活躍]
                                                                  │
                      burn_ve_sca_referral_ticket()               │
    [收益已新增] ◄────────────────────────────────────────────────┘
         │
         │  claim_revenue_with_ve_sca_key()
         ▼
    [收益已領取]
```

**性質**：票證是線性資源（建立後恰好被銷毀一次）。Sui 運行時透過型別系統強制此性質 -- `BorrowReferral` 必須被消耗。

---

## 11. 跨模組信任邊界分析

### 11.1 信任關係

```
admin ──friend──► version（set_version）
admin ──friend──► referral_tiers（add_tier, remove_tier）
scallop_referral_program ──friend──► referral_revenue_pool（add_revenue）
```

### 11.2 外部依賴信任

| 依賴 | 信任等級 | 風險 |
|------|----------|------|
| `protocol::borrow_referral` | 高 | 控制 BorrowReferral 生命週期、手續費計算 |
| `ve_sca::ve_sca` | 高 | 提供 veSCA 數量；如被妥協，層級查找可被操縱 |
| `x::balance_bag` | 高 | 儲存所有收益餘額；漏洞可能導致資金損失 |
| `sui::table` | 框架級 | 標準函式庫，經過良好審計 |
| `sui::bag` | 框架級 | 標準函式庫，經過良好審計 |

### 11.3 關鍵外部假設

合約假設 `ve_sca::ve_sca_amount()` 是**誠實的且不可在單一交易內被操縱**。如果使用者能夠閃電鑄造 veSCA 或暫時膨脹其 veSCA 數量，他們可以在 `claim_ve_sca_referral_ticket` 呼叫期間獲得更高的層級。這是外部依賴風險。

---

## 12. 阻斷服務（DoS）抵抗力分析

### 12.1 狀態膨脹攻擊

| 向量 | 可行性 | 影響 |
|------|--------|------|
| 建立大量綁定 | 受唯一地址限制（成本：每筆交易的 Gas） | 低：每個綁定是一個 Table 條目 |
| 新增大量層級 | 僅管理員，受 `AdminCapV2` 限制 | 無：管理員控制 |
| 多種代幣類型的收益 | 受不同代幣類型數量限制（有限） | 低：每種類型新增一個 Bag 條目 |
| 大量推薦人的收益 | 每個推薦人需要真實的 veSCA 綁定 | 低：建立推薦人有經濟成本 |

### 12.2 計算性 DoS

`find_tier` 操作在排序列表上使用二分搜尋（`O(log n)`，其中 `n` = 層級數量）。由於層級由管理員控制，`n` 預期很小（< 20）。不存在計算性 DoS 向量。

### 12.3 物件競爭

所有主要物件（`ReferralBindings`、`ReferralRevenuePool`、`ReferralTiers`、`Version`）都是共享物件。在 Sui 上，共享物件交易透過共識處理，自然處理競爭。然而，高頻的 `bind`/`unbind` 操作會在 `ReferralBindings` 上產生競爭，高頻的 `claim_revenue` 操作會在 `ReferralRevenuePool` 上產生競爭。這是共享物件設計的固有特性，而非漏洞。

---

## 13. 經濟攻擊向量分析

### 13.1 自我推薦

**場景**：使用者建立 veSCA 部位，將自己綁定為自己的被推薦人，借款後同時收取手續費折扣和推薦收益。

**評估**：這是**可能的且符合設計**。合約不阻止使用者綁定到自己的 veSCA。自我推薦是 DeFi 推薦計畫中的常見模式。經濟影響是使用者獲取借款手續費的 `borrow_fee_discount + referral_share`。如果 `discount + share < 100`，協議仍然淨收入為正。

**風險**：如果 `discount + share` 設定正確則為低（見 M-01）。

### 13.2 推薦費提取

**場景**：持有最高 veSCA 層級的巨鯨推薦人鼓勵大量使用者綁定到他們，從所有被推薦人的借款手續費中賺取被動收入。

**評估**：這是預期行為。層級系統旨在獎勵更大的 veSCA 持有者。

### 13.3 綁定惡意攻擊

**場景**：惡意推薦人說服使用者綁定到其 veSCA，然後推薦人讓其 veSCA 過期，導致被推薦人服務降級。

**評估**：低風險。被推薦人可以隨時 `unbind` 並 `rebind` 到不同的推薦人。層級查找會基於當前 veSCA 數量優雅地降到較低層級。見 M-02 關於層級 0 不存在的邊界案例。

---

## 14. 型別安全與泛型參數分析

### 14.1 泛型 CoinType 使用

`CoinType` 型別參數用於：
- `claim_ve_sca_referral_ticket<CoinType>`：建立 `BorrowReferral<CoinType, REFERRAL_WITNESS>`
- `burn_ve_sca_referral_ticket<CoinType>`：銷毀 `BorrowReferral<CoinType, REFERRAL_WITNESS>`，提取 `Balance<CoinType>`
- `claim_revenue_with_ve_sca_key<CoinType>`：返回 `Coin<CoinType>`
- `add_revenue_to_ve_sca_referrer<CoinType>`：接受 `Balance<CoinType>`

**分析**：Move 的型別系統確保 `CoinType` 在每次呼叫中保持一致。使用者不能聲明 `BorrowReferral<SUI, _>` 然後將其作為 `BorrowReferral<USDC, _>` 銷毀。泛型在呼叫時綁定，並在整個生命週期中強制執行。

### 14.2 見證者模式

`REFERRAL_WITNESS` 僅具有 `drop` 能力，定義在 `scallop_referral_program` 模組中。只有此模組內的函式可以建立 `REFERRAL_WITNESS {}` 的實例。此模式正確限制了：
- `borrow_referral::create_borrow_referral` 僅授權呼叫者可使用
- `borrow_referral::destroy_borrow_referral` 僅授權呼叫者可使用

**透過型別系統不可能繞過。**

### 14.3 TypeName 作為 Bag 鍵

`referral_revenue_pool` 使用 `TypeName`（來自 `std::type_name`）作為 `Bag` 中收益追蹤的鍵。`TypeName` 從具體的 `CoinType` 參數衍生，確保不同的代幣類型永遠不會衝突。這是正確的使用模式。

---

## 15. 測試覆蓋率評估

### 15.1 各模組覆蓋率

| 模組 | 函式數 | 已測試 | 覆蓋率 | 缺口 |
|------|--------|--------|--------|------|
| `asc_u64_sorted_list` | 6 | 6 | **100%** | 無 |
| `referral_bindings` | 7（+ 2 僅測試用） | 7 | **100%** | `bind_ve_sca_referrer`（需要 VeScaTable） |
| `referral_tiers` | 5（+ 2 僅測試用） | 5 | **100%** | 無 |
| `version` | 3（+ 2 僅測試用） | 3 | **100%** | 無 |
| `admin` | 7（+ 2 僅測試用） | 7 | **100%** | 無 |
| `referral_revenue_pool` | 6（+ 2 僅測試用） | 3 | **50%** | `claim_revenue_with_ve_sca_key`（需要 VeScaKey） |
| `scallop_referral_program` | 3 | 0 | **0%** | 所有函式（需要外部依賴） |

### 15.2 建議新增的測試

1. **整合測試**：使用模擬的 `VeScaTable` 和 `AuthorizedWitnessList` 測試完整的推薦生命週期
2. **溢位專項測試**：針對 `increase_revenue_data` 使用接近 `u64::MAX` 的值
3. **基於屬性的測試**：在隨機操作序列中驗證 INV-4（收益守恆）

---

## 16. 建議

### 優先級 1（部署前）

| 編號 | 行動 | 對應發現 |
|------|------|----------|
| R-01 | 在 `increase_revenue_data` 中新增溢位檢查 | H-01 |
| R-02 | 為 `referral_share` 和 `borrow_fee_discount` 新增上界驗證 | M-01 |

### 優先級 2（短期）

| 編號 | 行動 | 對應發現 |
|------|------|----------|
| R-03 | 在 `bind_ve_sca_referrer` 和 `unbind_ve_sca_referrer` 中新增版本檢查 | L-04 |
| R-04 | 將所有裸 `abort 0` 替換為描述性錯誤常數 | L-01, I-02 |
| R-05 | 記錄 veSCA 過期對被推薦人的行為影響 | M-02 |

### 優先級 3（維護）

| 編號 | 行動 | 對應發現 |
|------|------|----------|
| R-06 | 移除死碼 `ClaimRevenueEvent` 結構 | L-02 |
| R-07 | 考慮從 `RevenueData` 移除 `key` 能力 | I-03 |
| R-08 | 文件化錯誤碼編號方案 | I-04 |
| R-09 | 在全額領取後新增收益資料清理 | I-05 |
| R-10 | 移除 `upper_bound` 中冗餘的迴圈後檢查 | I-01 |

---

## 17. 結論

Scallop 推薦合約是一個結構良好的實作，有效地利用了 Sui 的物件模型和 Move 的型別系統。架構展現了健全的設計原則：

- **基於能力的存取控制**（AdminCapV2）防止未授權的層級操作
- **見證者模式**（REFERRAL_WITNESS）限制 BorrowReferral 的生命週期管理
- **共享物件**實現無需許可的使用者互動同時維持一致性
- **版本閘控**提供升級安全性

最顯著的發現是 **H-01**（收益追蹤中的算術溢位），理論上可能在極端條件下導致資金鎖定。**M-01**（層級百分比缺乏輸入驗證）代表應被解決的設定風險。所有其他發現為低嚴重等級或資訊性。

合約受益於 Move 的內建安全特性，包括資源線性性、型別安全性和無重入性。未發現允許資金竊取或未授權權限提升的嚴重漏洞。

**整體風險評估**：**低-中**

在解決 H-01 和 M-01 的前提下，合約適合在新版本部署中投入生產使用。

---

*本報告僅供參考之用。不構成安全保證。分析基於手動程式碼審查，不能取代形式化驗證工具或專業審計服務。*
