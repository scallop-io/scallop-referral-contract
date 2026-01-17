# Scallop 推薦計畫

這是一個在 Sui 區塊鏈上實現的智能合約，為 Scallop Protocol 提供推薦系統，使用戶能夠根據其 veSCA（投票鎖定的 SCA）持有量獲得推薦獎勵。

## 概述

Scallop 推薦計畫激勵用戶將其他人推薦到 Scallop 借貸協議。擁有 veSCA 的推薦人可以分享他們的推薦連結，當被推薦用戶（受薦人）通過協議借款時，雙方都能獲益：

- **受薦人**可獲得借款手續費折扣
- **推薦人**可獲得借款手續費的收益分成

獎勵比例由推薦人的 veSCA 數量決定的等級層級來確定。

## 架構

```
┌─────────────────────────────────────────────────────────────────┐
│                      Scallop 推薦計畫                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │ ReferralBindings│    │  ReferralTiers  │    │ RevenuePool │ │
│  │   推薦綁定關係   │    │     等級層級     │    │   收益池    │ │
│  │                 │    │                 │    │             │ │
│  │ 受薦人 → veSCA  │    │  veSCA 數量 →   │    │ veSCA ID →  │ │
│  │     映射        │    │ (分成, 折扣)     │    │    獎勵     │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │     Admin       │    │    Version      │                    │
│  │     管理員      │    │    版本控制      │                    │
│  │                 │    │                 │                    │
│  │   等級管理      │    │   合約版本       │                    │
│  └─────────────────┘    └─────────────────┘                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 模組

### `scallop_referral_program`

處理推薦票據生命週期的主模組：

- `claim_ve_sca_referral_ticket`：創建帶有折扣費用的借款推薦票據
- `burn_ve_sca_referral_ticket`：借款後銷毀票據並將收益分配給推薦人

### `referral_bindings`

管理受薦人與推薦人之間的映射關係：

- `bind_ve_sca_referrer`：將受薦人地址綁定到推薦人的 veSCA
- `unbind_ve_sca_referrer`：解除受薦人與其推薦人之間的綁定
- `get_binding`：獲取某地址當前的綁定關係

### `referral_tiers`

根據 veSCA 持有量定義獎勵等級：

- `add_tier`：添加新等級（僅限管理員）
- `remove_tier`：移除現有等級（僅限管理員）
- `find_tier`：根據給定的 veSCA 數量找到適用的等級

### `referral_revenue_pool`

管理收益分配：

- `claim_revenue_with_ve_sca_key`：允許推薦人領取累積的獎勵
- `add_revenue_to_ve_sca_referrer`：內部函數，用於為推薦人添加收益

### `admin`

管理功能：

- `add_referral_tier`：添加新的等級配置
- `remove_referral_tier`：移除等級配置
- `set_contract_version`：升級後更新合約版本

## 使用方式

### 給受薦人（借款人）

1. **綁定推薦人**
   ```move
   referral_bindings::bind_ve_sca_referrer(
       referral_bindings,
       ve_sca_key_id,      // 推薦人的 veSCA key ID
       ve_sca_table,
       clock,
       ctx
   );
   ```

2. **使用推薦折扣借款**
   ```move
   // 領取推薦票據
   let ticket = scallop_referral_program::claim_ve_sca_referral_ticket<CoinType>(
       version,
       ve_sca_table,
       referral_bindings,
       authorized_witness_list,
       referral_tiers,
       clock,
       ctx
   );

   // 使用票據配合 Scallop 借款函數
   // ...

   // 借款後銷毀票據
   scallop_referral_program::burn_ve_sca_referral_ticket<CoinType>(
       version,
       ticket,
       referral_revenue_pool,
       clock,
       ctx
   );
   ```

3. **解除推薦人綁定**（可選）
   ```move
   referral_bindings::unbind_ve_sca_referrer(
       referral_bindings,
       ctx
   );
   ```

### 給推薦人

1. **分享您的 veSCA key ID** 給潛在的受薦人

2. **領取累積的獎勵**
   ```move
   let reward = referral_revenue_pool::claim_revenue_with_ve_sca_key<CoinType>(
       version,
       referral_revenue_pool,
       ve_sca_key,
       clock,
       ctx
   );
   ```

## 部署

### 前置需求

- [Sui CLI](https://docs.sui.io/build/install)
- Node.js >= 16

### 建置

```bash
sui move build
```

### 測試

```bash
sui move test
```

### 發布

```bash
sui client publish --gas-budget 100000000
```

## 合約地址

### 主網

- 套件：`0x5658d4bf5ddcba27e4337b4262108b3ad1716643cac8c2054ac341538adc72ec`

## 相依套件

- [Sui Framework](https://github.com/MystenLabs/sui)
- [Scallop Protocol](https://github.com/scallop-io/sui-lending-protocol)
- [VeSCA](https://github.com/scallop-io/ve-sca-interface)

## 安全性

本合約實現了多項安全措施：

- 版本控制以確保升級後的相容性
- 管理員權限模式用於特權操作
- 綁定前驗證 veSCA 所有權

## 授權

本專案為 Scallop Labs 所有的專有軟體。
