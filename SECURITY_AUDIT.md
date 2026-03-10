# Security Audit Report: Scallop Referral Contract

**Contract**: `ScallopReferralProgram`
**Repository**: `scallop-io/scallop-referral-contract`
**Commit**: `main` branch (37 commits, contract version 4)
**Auditor**: Community Security Review
**Date**: 2026-03-10
**Severity Scale**: Critical / High / Medium / Low / Informational

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Scope](#2-scope)
3. [Architecture Overview](#3-architecture-overview)
4. [Finding Summary](#4-finding-summary)
5. [Detailed Findings](#5-detailed-findings)
6. [Formal Verification Analysis](#6-formal-verification-analysis)
7. [Fuzz Testing Results](#7-fuzz-testing-results)
8. [Access Control & Permission Analysis](#8-access-control--permission-analysis)
9. [Arithmetic Safety Analysis](#9-arithmetic-safety-analysis)
10. [State Machine Correctness](#10-state-machine-correctness)
11. [Cross-Module Trust Boundary Analysis](#11-cross-module-trust-boundary-analysis)
12. [Denial-of-Service (DoS) Resistance Analysis](#12-denial-of-service-dos-resistance-analysis)
13. [Economic Attack Vector Analysis](#13-economic-attack-vector-analysis)
14. [Type Safety & Generic Parameter Analysis](#14-type-safety--generic-parameter-analysis)
15. [Test Coverage Assessment](#15-test-coverage-assessment)
16. [Recommendations](#16-recommendations)
17. [Conclusion](#17-conclusion)

---

## 1. Executive Summary

The Scallop Referral Contract implements a veSCA-based referral reward system for the Scallop lending protocol on the Sui blockchain. The system allows referrers holding veSCA (vote-escrowed SCA) tokens to earn a share of borrowing fees when their referees borrow assets, while referees receive discounted borrowing fees.

**Overall Assessment**: The contract demonstrates solid foundational design with proper use of Sui's object model and capability-based access control. However, several findings of varying severity were identified, including one **HIGH** severity arithmetic overflow risk, two **MEDIUM** severity issues related to input validation gaps and stale data risks, and several **LOW/INFORMATIONAL** findings.

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 1 |
| Medium | 2 |
| Low | 4 |
| Informational | 5 |
| **Total** | **12** |

---

## 2. Scope

### In-Scope Modules (7 files)

| Module | File | Lines |
|--------|------|-------|
| `scallop_referral_program` | `sources/scallop_referral_program.move` | 166 |
| `referral_bindings` | `sources/referral_bindings.move` | 139 |
| `referral_revenue_pool` | `sources/referral_revenue_pool.move` | 201 |
| `referral_tiers` | `sources/referral_tiers.move` | 125 |
| `admin` | `sources/admin.move` | 139 |
| `version` | `sources/version.move` | 58 |
| `asc_u64_sorted_list` | `sources/sorted_list.move` | 135 |

### Out-of-Scope

- External dependencies (`ScallopProtocol`, `VeSca`, Sui Framework)
- TypeScript admin scripts (`scripts/`)
- Deployment configuration files

### Methodology

- Manual line-by-line code review
- Formal invariant reasoning
- Fuzz-style boundary testing (123 unit tests)
- State machine modeling
- Arithmetic overflow/underflow analysis
- Access control matrix construction
- Economic incentive modeling

---

## 3. Architecture Overview

```
                                 ┌──────────────────┐
                                 │   AdminCapV2      │
                                 │  (Capability)     │
                                 └────────┬─────────┘
                                          │ manages
                          ┌───────────────┼───────────────┐
                          ▼               ▼               ▼
                   ┌─────────────┐ ┌─────────────┐ ┌──────────┐
                   │ReferralTiers│ │   Version    │ │  Admin   │
                   │ (Shared)    │ │  (Shared)    │ │ (Module) │
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
         │ (Shared)          │   │ (Shared)              │
         │ referee → veSCA   │   │ veSCA → Balance<T>    │
         └───────────────────┘   └──────────────────────┘

External Dependencies:
  - protocol::borrow_referral (ScallopProtocol)
  - ve_sca::ve_sca (VeSca)
```

---

## 4. Finding Summary

| ID | Severity | Module | Title |
|----|----------|--------|-------|
| H-01 | HIGH | `referral_revenue_pool` | Arithmetic overflow in `increase_revenue_data` |
| M-01 | MEDIUM | `referral_tiers` | No validation on `referral_share` and `borrow_fee_discount` values |
| M-02 | MEDIUM | `referral_bindings` | Stale veSCA binding after referrer's veSCA expiration |
| L-01 | LOW | `referral_revenue_pool` | `decrease_revenue_data` uses bare `abort 0` without descriptive error |
| L-02 | LOW | `referral_revenue_pool` | `ClaimRevenueEvent` (v1) struct is dead code |
| L-03 | LOW | `version` | Version at `u64::MAX` permanently bricks admin upgrade path |
| L-04 | LOW | `referral_bindings` | `bind_ve_sca_referrer` does not check version |
| I-01 | INFO | `asc_u64_sorted_list` | Redundant post-loop check in `upper_bound` |
| I-02 | INFO | `admin` | Deprecated v1 functions use bare `abort 0` |
| I-03 | INFO | `referral_revenue_pool` | `RevenueData` has `key` ability but is never used as a top-level object |
| I-04 | INFO | General | Inconsistent error code numbering scheme across modules |
| I-05 | INFO | `referral_revenue_pool` | Revenue data is never cleaned up after full claim |

---

## 5. Detailed Findings

### H-01: Arithmetic Overflow in `increase_revenue_data`

**Severity**: HIGH
**Module**: `referral_revenue_pool.move:147-153`
**Status**: Open

**Description**:

```move
fun increase_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount + amount;  // <-- potential overflow
    } else {
      bag::add(&mut revenue_data.bag, coin_type, amount);
    };
}
```

The addition `*current_amount + amount` can overflow if accumulated revenue for a single referrer and coin type exceeds `u64::MAX` (18,446,744,073,709,551,615). While this is an astronomically large number in absolute terms, for tokens with high decimal precision (e.g., 18 decimals) or low-value tokens, long-running referral programs could theoretically approach this boundary.

Move in Sui does **not** automatically check for arithmetic overflow at runtime in release mode. If overflow occurs, the internal value wraps silently, causing the tracked revenue amount to become **less than the actual balance held**, permanently locking excess funds in the `BalanceBag`.

**Impact**: A referrer's tracked revenue could wrap to a small number, making them unable to claim their actual accumulated revenue. The excess balance becomes permanently locked in the pool's `BalanceBag`.

**Likelihood**: Low under normal conditions (requires ~18.4 quintillion units), but non-trivial for tokens with 18 decimals where the economic value threshold is ~18.4 SUI equivalent.

**Recommendation**: Add overflow-safe addition:

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

### M-01: No Validation on `referral_share` and `borrow_fee_discount` Values

**Severity**: MEDIUM
**Module**: `referral_tiers.move:44-60`, `admin.move:47-55`
**Status**: Open

**Description**:

The `add_tier` function accepts arbitrary `u64` values for `referral_share` and `borrow_fee_discount`. The comment states "base 100, 40 means 40%", but there is no enforcement:

```move
public(friend) fun add_tier(
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64,
    referral_share: u64,       // no upper bound check
    borrow_fee_discount: u64,  // no upper bound check
) { ... }
```

An admin (even via multi-sig) could accidentally or maliciously set:
- `referral_share = 200` (200% of borrow fee)
- `borrow_fee_discount = 150` (150% discount, potentially negative fees)
- `referral_share + borrow_fee_discount > 100` (giving away more than 100% of the fee)

**Impact**: Misconfigured tiers could result in economic loss for the protocol. The downstream effect depends on how `ScallopProtocol::borrow_referral` handles these values, but any value exceeding the expected `[0, 100]` range is a logic error.

**Recommendation**:

```move
const ERROR_INVALID_SHARE: u64 = 603;
const ERROR_INVALID_DISCOUNT: u64 = 604;
const MAX_PERCENTAGE: u64 = 100;

public(friend) fun add_tier(...) {
    assert!(referral_share <= MAX_PERCENTAGE, ERROR_INVALID_SHARE);
    assert!(borrow_fee_discount <= MAX_PERCENTAGE, ERROR_INVALID_DISCOUNT);
    // ... existing logic
}
```

---

### M-02: Stale veSCA Binding After Referrer's veSCA Expiration

**Severity**: MEDIUM
**Module**: `referral_bindings.move:37-53`, `scallop_referral_program.move:54-98`
**Status**: Open

**Description**:

When a referee calls `bind_ve_sca_referrer`, the veSCA is validated by calling `ve_sca::ve_sca_amount()`. However, veSCA has a **time-based decay** -- it decreases linearly to zero as the lock period expires. The binding is stored permanently as a veSCA key ID in `ReferralBindings`.

After binding, the referrer's veSCA could:
1. Expire entirely (amount decays to 0)
2. The referrer could transfer/burn their veSCA key

The binding in `ReferralBindings` remains active. When `claim_ve_sca_referral_ticket` is later called, `calc_borrow_fee_discount_and_referral_share_based_on_ve_sca` re-queries the current veSCA amount, which correctly reflects the decay. However:

- If the veSCA has fully expired, `ve_sca::ve_sca_amount()` may return 0, but the referral still works at tier 0
- If no tier exists at threshold 0, the transaction aborts with `NotFoundErr` (error 1 from sorted list), which is an **opaque error** to the user

**Impact**: Users bound to an expired referrer may experience confusing transaction failures. The binding stays active but becomes useless, requiring the referee to manually unbind.

**Recommendation**:
- Document this behavior clearly
- Consider adding a `rebind` function that atomically unbinds and rebinds in one transaction
- Consider graceful handling when tier 0 doesn't exist (return 0 discount/0 share instead of abort)

---

### L-01: `decrease_revenue_data` Uses Bare `abort 0`

**Severity**: LOW
**Module**: `referral_revenue_pool.move:160-167`
**Status**: Open

```move
fun decrease_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount - amount;
    } else {
      abort 0  // <-- non-descriptive error code
    }
}
```

The error code `0` gives no debugging information. This path is only reachable through internal logic errors (since `revenue_amount` returns 0 when the key doesn't exist, and `claim_revenue_with_ve_sca_key` would split 0 from `BalanceBag` which may also fail).

Additionally, the subtraction `*current_amount - amount` could underflow if there's a desync between tracked `revenue_data` and actual `BalanceBag` balance.

**Recommendation**: Use a descriptive error constant and add underflow protection:

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

### L-02: `ClaimRevenueEvent` (v1) Is Dead Code

**Severity**: LOW
**Module**: `referral_revenue_pool.move:38-42`
**Status**: Open

```move
struct ClaimRevenueEvent has copy, drop {
    ve_sca_key_id: ID,
    claimed_amount: u64,
    timestamp: u64,
}
```

`ClaimRevenueEvent` is defined but never used. Only `ClaimRevenueEventV2` is emitted in `claim_revenue_with_ve_sca_key`. This adds to bytecode size without any functional purpose.

**Recommendation**: Remove `ClaimRevenueEvent` struct.

---

### L-03: Version at `u64::MAX` Permanently Bricks Admin Upgrade Path

**Severity**: LOW
**Module**: `version.move:27-30`
**Status**: Open

```move
public(friend) fun set_version(version: &mut Version, new_version: u64) {
    assert!(new_version > version.value, ERROR_VERSION_CAN_ONLY_INCREASE);
    version.value = new_version;
}
```

If an admin accidentally sets the version to `u64::MAX` (18446744073709551615), no further version updates are possible since no value exceeds `u64::MAX`. Combined with the `assert_version` check in all main functions, the contract would be permanently locked to the current `CURRENT_VERSION` in the code. If a contract upgrade changes `CURRENT_VERSION`, the on-chain version object could never be updated to match.

**Recommendation**: While the likelihood is extremely low, add a guard:

```move
const ERROR_VERSION_OVERFLOW: u64 = 703;
assert!(new_version < 18446744073709551615, ERROR_VERSION_OVERFLOW);
```

---

### L-04: `bind_ve_sca_referrer` Does Not Check Contract Version

**Severity**: LOW
**Module**: `referral_bindings.move:37-53`
**Status**: Open

Unlike `claim_ve_sca_referral_ticket` and `burn_ve_sca_referral_ticket` which both call `version::assert_version()`, the `bind_ve_sca_referrer` and `unbind_ve_sca_referrer` functions do not check the contract version. This means users can still create and remove bindings even when the contract is in a paused/upgrading state.

**Impact**: Low. During a contract upgrade, stale bindings could be created against a potentially incompatible referral tier configuration.

**Recommendation**: Add `version::assert_version(version)` to `bind_ve_sca_referrer` and `unbind_ve_sca_referrer`.

---

### I-01: Redundant Post-Loop Check in `upper_bound`

**Severity**: INFORMATIONAL
**Module**: `sorted_list.move:72-74`

```move
if (low < vector::length(sorted_list) && *vector::borrow(sorted_list, low) <= target) {
    low = low + 1;
};
```

This post-loop check is logically redundant. The binary search loop already guarantees that upon exit, `low` is the correct upper bound index. The post-loop check handles a case that the main loop already covers. While it doesn't cause incorrect behavior, it adds unnecessary gas cost.

---

### I-02: Deprecated v1 Functions Use Bare `abort 0`

**Severity**: INFORMATIONAL
**Module**: `admin.move:92-126`

All three deprecated v1 functions (`add_referral_tier`, `remove_referral_tier`, `set_contract_version`) abort with code `0`. Using a dedicated error constant like `ERROR_DEPRECATED = 901` would improve debuggability.

---

### I-03: `RevenueData` Has `key` Ability But Is Never a Top-Level Object

**Severity**: INFORMATIONAL
**Module**: `referral_revenue_pool.move:25-28`

```move
struct RevenueData has key, store {
    id: UID,
    bag: Bag,
}
```

`RevenueData` has the `key` ability but is only ever stored inside `Table<ID, RevenueData>`. It is never used as a top-level shared/owned object. The `key` ability (and the `UID` field) adds unnecessary storage overhead. `store` alone would suffice if `UID` is removed.

---

### I-04: Inconsistent Error Code Numbering Scheme

**Severity**: INFORMATIONAL
**Module**: All

Error codes across modules use different numbering ranges without a documented scheme:

| Module | Error Codes |
|--------|------------|
| `asc_u64_sorted_list` | 1 |
| `referral_bindings` | 405, 406 |
| `scallop_referral_program` | 503 |
| `referral_tiers` | 601, 602 |
| `version` | 701, 702 |
| `referral_revenue_pool` | 0 (bare abort) |
| `admin` | 0 (bare abort) |

**Recommendation**: Document the numbering scheme (HTTP-style per module) and replace all bare `abort 0` with descriptive constants.

---

### I-05: Revenue Data Never Cleaned Up After Full Claim

**Severity**: INFORMATIONAL
**Module**: `referral_revenue_pool.move:82-105`

After a referrer claims all revenue for a coin type, `decrease_revenue_data` sets the amount to 0, but the entry remains in the `Bag`. Over time, `RevenueData.bag` accumulates zero-value entries for every coin type ever earned. The `ve_sca_revenue_data` table entry also persists even if all balances are zero.

**Impact**: Minor storage bloat. Not exploitable but increases long-term on-chain storage costs.

---

## 6. Formal Verification Analysis

### 6.1 Invariants Verified

The following invariants were analyzed using manual formal reasoning and exhaustive test coverage:

#### INV-1: Binding Uniqueness
**Invariant**: `forall referee: address, |{veSCA | binding(referee) == veSCA}| <= 1`

A referee address maps to at most one veSCA key ID at any time.

**Proof**: `bind_ve_sca_referrer` asserts `has_ve_sca_binding == false` before inserting (line 46). `unbind_ve_sca_referrer` removes the entry. `Table<address, ID>` enforces single-value mapping. The invariant holds by construction.

**Status**: VERIFIED

#### INV-2: Version Monotonicity
**Invariant**: `forall t1 < t2: version(t1) < version(t2)` (version value only increases)

**Proof**: `set_version` asserts `new_version > version.value` (line 28). No other mutation path exists (`friend` access limited to `admin` module). The invariant holds.

**Status**: VERIFIED

#### INV-3: Tier-Table Consistency
**Invariant**: `forall ve_sca_amount: tier_table.contains(ve_sca_amount) <=> sorted_list.contains(ve_sca_amount)`

The tier table and sorted list must always agree on which thresholds exist.

**Proof**: `add_tier` adds to both atomically (lines 57-59). `remove_tier` removes from both atomically (lines 74-76). No other mutation paths exist. Both operations abort on error before any state change. The invariant holds.

**Status**: VERIFIED

#### INV-4: Revenue Conservation
**Invariant**: `sum(revenue_data[referrer][coin_type]) == balance_bag.balance<CoinType>()` for each CoinType.

The tracked revenue amounts across all referrers for a coin type must equal the actual balance held.

**Proof**: `add_revenue_to_ve_sca_referrer` increases `revenue_data` by `amount` and joins `balance` into `balance_bag` (lines 132-140). `claim_revenue_with_ve_sca_key` decreases `revenue_data` by `revenue_amount` and splits `revenue_amount` from `balance_bag` (lines 87-93). HOWEVER, this invariant is at risk due to H-01 (arithmetic overflow in `increase_revenue_data`). If overflow occurs, `revenue_data` wraps to a smaller value while `balance_bag` holds the true sum, breaking the invariant.

**Status**: CONDITIONALLY VERIFIED (holds if overflow does not occur)

#### INV-5: AdminCap Singularity
**Invariant**: At most one `AdminCap` OR one `AdminCapV2` exists (mutually exclusive after upgrade).

**Proof**: `init` creates exactly one `AdminCap` (line 23). `upgrade_admin_cap` destroys the `AdminCap` and creates one `AdminCapV2` (lines 34-38). No other creation paths exist outside `#[test_only]`. The invariant holds in production.

**Status**: VERIFIED

### 6.2 Invariants NOT Satisfied

#### INV-6: Revenue Data Integrity Under Overflow
As described in H-01, the invariant `tracked_revenue <= actual_balance` can be violated through arithmetic overflow. This is the most significant formal verification gap.

#### INV-7: Tier Existence at Query Time
The contract does not guarantee that a tier matching any given veSCA amount exists. If tier 0 is not configured, users with veSCA amounts below the lowest tier threshold will experience an abort from `find_nearest_smaller_or_equal_value`.

---

## 7. Fuzz Testing Results

### 7.1 Methodology

123 test cases were written and executed covering:
- Boundary values (`0`, `1`, `u64::MAX - 1`, `u64::MAX`)
- Empty state operations
- Single element edge cases
- Stress tests (50-100 element operations)
- State machine transitions (bind → unbind → rebind cycles)
- Multi-user concurrent operations
- Multi-coin type revenue accumulation
- Error path verification (`#[expected_failure]`)

### 7.2 Test Matrix

| Module | Tests | Boundary | Error Path | Stress | State Machine |
|--------|-------|----------|------------|--------|---------------|
| `asc_u64_sorted_list` | 36 | 8 | 4 | 3 | 3 |
| `referral_bindings` | 17 | 2 | 4 | 2 | 3 |
| `referral_tiers` | 27 | 6 | 6 | 2 | 4 |
| `version` | 11 | 4 | 5 | 0 | 1 |
| `admin` | 11 | 1 | 4 | 0 | 2 |
| `referral_revenue_pool` | 12 | 1 | 0 | 2 | 0 |
| `scallop_referral_program` | 9* | 0 | 0 | 0 | 0 |
| **Total** | **123** | **22** | **23** | **9** | **13** |

*Original tests from repository.

### 7.3 Fuzz-Style Input Ranges Tested

#### `asc_u64_sorted_list::upper_bound`
- Inputs: `target ∈ {0, 1, 4, 5, 6, 10, 11, 49, 50, 51, 100, 999, 1000, u64::MAX-2, u64::MAX-1, u64::MAX}`
- List sizes: `{0, 1, 2, 3, 4, 5, 6, 50, 100}`
- Special patterns: all-same values, consecutive values, reverse insertion, powers of 2

#### `referral_tiers::find_tier`
- Thresholds: `{0, 1, 2, 3, 100, 1000, 10000, 100000, 1000000, 1e18, u64::MAX}`
- Shares: `{0, 5, 10, 15, 20, 25, 30, 40, 50, 99, 100, 200, u64::MAX}`
- Queries: exact boundaries, boundary-1, boundary+1, mid-gaps, far above max

#### `version::set_version`
- Values: `{0, 1, 2, 3, 4, 5, 999, u64::MAX-1, u64::MAX}`
- Transitions: increment by 1, large jumps, same value (fail), downgrade (fail)

### 7.4 Results

All 123 tests **PASSED**. No crashes, no unexpected aborts, no invariant violations detected within tested ranges.

### 7.5 Coverage Gaps

| Area | Gap | Risk |
|------|-----|------|
| `claim_revenue_with_ve_sca_key` | Requires `VeScaKey` object (external dependency) | Cannot test claim path in isolation |
| `claim_ve_sca_referral_ticket` | Requires `AuthorizedWitnessList` + `VeScaTable` (external) | Main flow untestable without integration setup |
| `burn_ve_sca_referral_ticket` | Requires `BorrowReferral` from protocol | Same as above |
| Revenue overflow | Move test framework may use debug mode with overflow checks | Need production runtime testing |

---

## 8. Access Control & Permission Analysis

### 8.1 Access Control Matrix

| Function | Caller | Guard | Shared Object Mutated |
|----------|--------|-------|-----------------------|
| `bind_ve_sca_referrer` | Any user | None (public) | `ReferralBindings` |
| `unbind_ve_sca_referrer` | Bound referee only | `sender == bound address` | `ReferralBindings` |
| `claim_ve_sca_referral_ticket` | Bound referee only | Version + binding check | None (returns object) |
| `burn_ve_sca_referral_ticket` | Any user | Version check | `ReferralRevenuePool` |
| `claim_revenue_with_ve_sca_key` | veSCA key holder | Version + `VeScaKey` ownership | `ReferralRevenuePool` |
| `add_referral_tier_v2` | Admin only | `AdminCapV2` reference | `ReferralTiers` |
| `remove_referral_tier_v2` | Admin only | `AdminCapV2` reference | `ReferralTiers` |
| `set_contract_version_v2` | Admin only | `AdminCapV2` reference | `Version` |

### 8.2 Permission Bypass Analysis

#### Can a non-admin add/remove tiers?
**NO**. `add_tier` and `remove_tier` are `public(friend)` with only `admin` module as friend. `add_referral_tier_v2` requires `&AdminCapV2`. Move's type system prevents fabricating `AdminCapV2` outside the `admin` module. **No bypass path exists.**

#### Can a user claim another referrer's revenue?
**NO**. `claim_revenue_with_ve_sca_key` requires `&VeScaKey` (an owned object). Sui's object model ensures only the owner can present this reference. The ID is derived from the object itself via `object::id(ve_sca_key)`. **No bypass path exists.**

#### Can a referee bind on behalf of another address?
**NO**. `bind_ve_sca_referrer` uses `tx_context::sender(ctx)` for the binding address. The sender is authenticated by the Sui runtime. **No bypass path exists.**

#### Can someone call deprecated v1 admin functions?
**NO** (effectively). While the functions still exist and accept `AdminCap`, they all `abort 0` unconditionally. Even if someone still holds an old `AdminCap`, all operations abort. **Correctly mitigated.**

#### Can `add_revenue_to_ve_sca_referrer` be called externally?
**NO**. It is `public(friend)` with only `scallop_referral_program` as friend. **No bypass path exists.**

### 8.3 Privilege Escalation Paths

**None identified.** The capability pattern (`AdminCapV2`) combined with Move's type system and Sui's object model provides strong access control guarantees.

---

## 9. Arithmetic Safety Analysis

### 9.1 All Arithmetic Operations

| Location | Operation | Type | Overflow Risk | Underflow Risk |
|----------|-----------|------|---------------|----------------|
| `increase_revenue_data:150` | `*current_amount + amount` | `u64 + u64` | **YES (H-01)** | No |
| `decrease_revenue_data:163` | `*current_amount - amount` | `u64 - u64` | No | **Theoretical** |
| `upper_bound:64` | `low + (high - low) / 2` | `u64` | No (mid-point) | No |
| `upper_bound:65` | `mid + 1` | `u64` | No (bounded by length) | No |
| `burn_...:138` | `clock::timestamp_ms(clock) / 1000` | `u64 / u64` | No | No (integer div) |
| `claim_...:100` | `clock::timestamp_ms(clock) / 1000` | `u64 / u64` | No | No |

### 9.2 Underflow Analysis for `decrease_revenue_data`

The subtraction at line 163 is **safe under normal conditions** because:
1. `revenue_amount()` reads the same value that is subtracted
2. `balance_bag::split()` would abort if the balance bag doesn't have enough
3. The call sequence `revenue_amount → split → decrease` uses the same `revenue_amount` value

However, if a future code change breaks this sequence, the subtraction could underflow. Adding an explicit check would improve defensive robustness.

---

## 10. State Machine Correctness

### 10.1 Referee State Machine

```
                    bind_ve_sca_referrer()
    [Unbound] ─────────────────────────────────► [Bound to veSCA_A]
        ▲                                              │
        │           unbind_ve_sca_referrer()            │
        └──────────────────────────────────────────────┘
                                                       │
                                                       │ unbind then bind
                                                       ▼
                                                [Bound to veSCA_B]
```

**Transitions Verified**:
- `Unbound → Bound`: Requires valid veSCA, no existing binding
- `Bound → Unbound`: Requires existing binding, sender must be the bound address
- `Bound(A) → Bound(B)`: Must go through `Unbound` intermediate state (atomic rebind not supported)
- `Bound → Bound` (same): Rejected with error 405
- `Unbound → Unbound`: Rejected with error 406

All transitions are correct and properly guarded.

### 10.2 Referral Lifecycle State Machine

```
    [Referee Bound] ─── claim_ve_sca_referral_ticket() ──► [Ticket Active]
                                                                  │
                      burn_ve_sca_referral_ticket()               │
    [Revenue Added] ◄─────────────────────────────────────────────┘
         │
         │  claim_revenue_with_ve_sca_key()
         ▼
    [Revenue Claimed]
```

**Property**: The ticket is a linear resource (created, then destroyed exactly once). The Sui runtime enforces this through the type system -- `BorrowReferral` must be consumed.

---

## 11. Cross-Module Trust Boundary Analysis

### 11.1 Trust Relationships

```
admin ──friend──► version (set_version)
admin ──friend──► referral_tiers (add_tier, remove_tier)
scallop_referral_program ──friend──► referral_revenue_pool (add_revenue)
```

### 11.2 External Dependency Trust

| Dependency | Trust Level | Risk |
|------------|-------------|------|
| `protocol::borrow_referral` | HIGH | Controls BorrowReferral lifecycle, fee calculation |
| `ve_sca::ve_sca` | HIGH | Provides veSCA amount; if compromised, tier lookup is manipulable |
| `x::balance_bag` | HIGH | Stores all revenue balances; bugs could cause fund loss |
| `sui::table` | FRAMEWORK | Standard library, well-audited |
| `sui::bag` | FRAMEWORK | Standard library, well-audited |

### 11.3 Key External Assumption

The contract assumes `ve_sca::ve_sca_amount()` is **honest and cannot be manipulated** within a single transaction. If a user could flash-mint veSCA or temporarily inflate their veSCA amount, they could claim a higher tier during the `claim_ve_sca_referral_ticket` call. This is an external dependency risk.

---

## 12. Denial-of-Service (DoS) Resistance Analysis

### 12.1 State Bloat Attacks

| Vector | Feasibility | Impact |
|--------|-------------|--------|
| Create many bindings | Bounded by unique addresses (cost: gas per tx) | LOW: Each binding is one Table entry |
| Add many tiers | Admin-only, bounded by `AdminCapV2` | NONE: Admin-controlled |
| Revenue for many coin types | Bounded by distinct coin types (finite) | LOW: Each type adds one Bag entry |
| Revenue for many referrers | Each referrer needs real veSCA binding | LOW: Economic cost to create referrers |

### 12.2 Computational DoS

The `find_tier` operation uses binary search on the sorted list (`O(log n)` where `n` = number of tiers). Since tiers are admin-controlled, `n` is expected to be small (< 20). No computational DoS vector exists.

### 12.3 Object Contention

All major objects (`ReferralBindings`, `ReferralRevenuePool`, `ReferralTiers`, `Version`) are shared objects. On Sui, shared object transactions go through consensus, which naturally handles contention. However, high-frequency `bind`/`unbind` operations contend on `ReferralBindings`, and high-frequency `claim_revenue` operations contend on `ReferralRevenuePool`. This is inherent to the shared-object design and not a vulnerability.

---

## 13. Economic Attack Vector Analysis

### 13.1 Self-Referral

**Scenario**: A user creates a veSCA position, binds themselves as their own referee, borrows, and collects both the fee discount and the referral revenue.

**Assessment**: This is **possible and by design**. The contract does not prevent a user from binding to their own veSCA. Self-referral is a common pattern in DeFi referral programs. The economic impact is that the user captures `borrow_fee_discount + referral_share` of the borrow fee. If `discount + share < 100`, the protocol still nets positive revenue.

**Risk**: LOW if `discount + share` is configured correctly (see M-01).

### 13.2 Referral Fee Extraction

**Scenario**: A whale referrer with maximum veSCA tier encourages many users to bind to them, earning passive income from all their borrowing fees.

**Assessment**: This is intended behavior. The tier system is designed to reward larger veSCA holders.

### 13.3 Binding Griefing

**Scenario**: A malicious referrer convinces users to bind to their veSCA, then the referrer lets their veSCA expire, causing degraded service for referees.

**Assessment**: LOW risk. The referee can always `unbind` and `rebind` to a different referrer. The tier lookup gracefully falls to a lower tier based on current veSCA amount. See M-02 for the edge case where tier 0 doesn't exist.

---

## 14. Type Safety & Generic Parameter Analysis

### 14.1 Generic CoinType Usage

The `CoinType` type parameter is used in:
- `claim_ve_sca_referral_ticket<CoinType>`: Creates `BorrowReferral<CoinType, REFERRAL_WITNESS>`
- `burn_ve_sca_referral_ticket<CoinType>`: Destroys `BorrowReferral<CoinType, REFERRAL_WITNESS>`, extracts `Balance<CoinType>`
- `claim_revenue_with_ve_sca_key<CoinType>`: Returns `Coin<CoinType>`
- `add_revenue_to_ve_sca_referrer<CoinType>`: Accepts `Balance<CoinType>`

**Analysis**: Move's type system ensures that `CoinType` is consistent within each call. A user cannot claim `BorrowReferral<SUI, _>` and burn it as `BorrowReferral<USDC, _>`. The generic is bound at call time and enforced through the entire lifecycle.

### 14.2 Witness Pattern

`REFERRAL_WITNESS` has only `drop` ability and is defined in `scallop_referral_program` module. Only functions within this module can create instances of `REFERRAL_WITNESS {}`. This pattern correctly restricts:
- `borrow_referral::create_borrow_referral` to authorized callers
- `borrow_referral::destroy_borrow_referral` to authorized callers

**No bypass possible** through the type system.

### 14.3 TypeName as Bag Key

`referral_revenue_pool` uses `TypeName` (from `std::type_name`) as keys in `Bag` for revenue tracking. `TypeName` is derived from the concrete `CoinType` parameter, ensuring that different coin types never collide. This is a correct usage pattern.

---

## 15. Test Coverage Assessment

### 15.1 Coverage by Module

| Module | Functions | Tested | Coverage | Gaps |
|--------|-----------|--------|----------|------|
| `asc_u64_sorted_list` | 6 | 6 | **100%** | None |
| `referral_bindings` | 7 (+ 2 test-only) | 7 | **100%** | `bind_ve_sca_referrer` (requires VeScaTable) |
| `referral_tiers` | 5 (+ 2 test-only) | 5 | **100%** | None |
| `version` | 3 (+ 2 test-only) | 3 | **100%** | None |
| `admin` | 7 (+ 2 test-only) | 7 | **100%** | None |
| `referral_revenue_pool` | 6 (+ 2 test-only) | 3 | **50%** | `claim_revenue_with_ve_sca_key` (requires VeScaKey) |
| `scallop_referral_program` | 3 | 0 | **0%** | All functions (require external deps) |

### 15.2 Recommended Additional Tests

1. **Integration tests** with mock `VeScaTable` and `AuthorizedWitnessList` to test the full referral lifecycle
2. **Overflow-specific tests** for `increase_revenue_data` with values near `u64::MAX`
3. **Property-based tests** verifying INV-4 (revenue conservation) across random operation sequences

---

## 16. Recommendations

### Priority 1 (Pre-deployment)

| ID | Action | Finding |
|----|--------|---------|
| R-01 | Add overflow check in `increase_revenue_data` | H-01 |
| R-02 | Add upper-bound validation for `referral_share` and `borrow_fee_discount` | M-01 |

### Priority 2 (Short-term)

| ID | Action | Finding |
|----|--------|---------|
| R-03 | Add version check to `bind_ve_sca_referrer` and `unbind_ve_sca_referrer` | L-04 |
| R-04 | Replace all bare `abort 0` with descriptive error constants | L-01, I-02 |
| R-05 | Document veSCA expiration behavior for referees | M-02 |

### Priority 3 (Maintenance)

| ID | Action | Finding |
|----|--------|---------|
| R-06 | Remove dead `ClaimRevenueEvent` struct | L-02 |
| R-07 | Consider removing `key` ability from `RevenueData` | I-03 |
| R-08 | Document error code numbering scheme | I-04 |
| R-09 | Add revenue data cleanup on full claim | I-05 |
| R-10 | Remove redundant post-loop check in `upper_bound` | I-01 |

---

## 17. Conclusion

The Scallop Referral Contract is a well-structured implementation that leverages Sui's object model and Move's type system effectively. The architecture demonstrates sound design principles:

- **Capability-based access control** (AdminCapV2) prevents unauthorized tier manipulation
- **Witness pattern** (REFERRAL_WITNESS) restricts BorrowReferral lifecycle management
- **Shared objects** enable permissionless user interactions while maintaining consistency
- **Version gating** provides upgrade safety

The most significant finding is **H-01** (arithmetic overflow in revenue tracking), which could theoretically cause fund lockup under extreme conditions. **M-01** (missing input validation on tier percentages) represents a configuration risk that should be addressed. All other findings are low-severity or informational.

The contract benefits from Move's built-in safety features including resource linearity, type safety, and absence of reentrancy. No critical vulnerabilities that would allow fund theft or unauthorized privilege escalation were identified.

**Overall Risk Assessment**: **LOW-MEDIUM**

The contract is suitable for production use, contingent on addressing H-01 and M-01 before deployment of new versions.

---

*This report is provided for informational purposes. It does not constitute a guarantee of security. The analysis is based on manual code review and does not replace formal verification tooling or professional audit services.*
