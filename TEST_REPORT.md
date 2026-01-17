# Test Report

**Date:** 2026-01-17
**Sui CLI Version:** 1.63.2
**Result:** All tests passed

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 21 |
| Passed | 21 |
| Failed | 0 |
| Pass Rate | 100% |

## Test Results by Module

### asc_u64_sorted_list (3 tests)

| Test Name | Status |
|-----------|--------|
| `insert_test` | PASS |
| `remove_test` | PASS |
| `upper_bound_test` | PASS |

### sorted_list_test (2 tests)

| Test Name | Status |
|-----------|--------|
| `test_find` | PASS |
| `test_insert` | PASS |

### referral_tiers_test (10 tests)

| Test Name | Status | Description |
|-----------|--------|-------------|
| `referral_tiers_test` | PASS | Basic tier lookup functionality |
| `test_remove_tier` | PASS | Remove tier and verify fallback behavior |
| `test_exact_tier_boundaries` | PASS | Boundary value testing |
| `test_single_tier` | PASS | Single tier configuration |
| `test_different_discounts_per_tier` | PASS | Varying discount rates |
| `test_add_tiers_in_random_order` | PASS | Non-sequential tier addition |
| `test_add_duplicate_tier_should_fail` | PASS | Duplicate tier error handling |
| `test_remove_nonexistent_tier_should_fail` | PASS | Non-existent tier error handling |
| `test_remove_and_readd_tier` | PASS | Tier removal and re-addition |

### referral_bindings_test (7 tests)

| Test Name | Status | Description |
|-----------|--------|-------------|
| `test_bind_and_get_binding` | PASS | Basic bind and query functionality |
| `test_unbind` | PASS | Unbind functionality |
| `test_is_binded_to_the_given_referrer_ve_sca` | PASS | Specific referrer binding check |
| `test_multiple_referees` | PASS | Multiple referees with different referrers |
| `test_rebind_after_unbind` | PASS | Rebind to different referrer after unbind |
| `test_bind_already_binded_should_fail` | PASS | Duplicate binding error (code 405) |
| `test_unbind_not_binded_should_fail` | PASS | Unbind without binding error (code 406) |

## Test Coverage

| Module | Covered | Notes |
|--------|---------|-------|
| `asc_u64_sorted_list` | Yes | Insert, remove, find operations |
| `referral_tiers` | Yes | Add, remove, find tier operations |
| `referral_bindings` | Yes | Bind, unbind, query operations |
| `referral_revenue_pool` | Partial | Requires mainnet dependencies for full testing |
| `scallop_referral_program` | Partial | Requires mainnet dependencies for full testing |
| `admin` | No | Admin functions require integration testing |

## Notes

- Tests are designed as unit tests that bypass external mainnet dependencies
- `referral_bindings_test` uses `bind_for_test` helper to avoid VeScaTable validation
- Error handling tests verify correct abort codes (405, 406, 601, 602)
