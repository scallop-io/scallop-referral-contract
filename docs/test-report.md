# Test Report

**Date:** 2026-03-10
**Sui CLI Version:** `1.63.2`
**Command:** `sui move test` and `sui move test --coverage`

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 129 |
| Passed | 129 |
| Failed | 0 |
| Pass Rate | 100% |
| Overall Move Coverage | 84.08% |

## Coverage Summary

| Module | Coverage |
|--------|----------|
| `version` | 83.33% |
| `asc_u64_sorted_list` | 87.71% |
| `referral_tiers` | 87.72% |
| `admin` | 78.72% |
| `referral_bindings` | 69.12% |
| `referral_revenue_pool` | 67.70% |
| `scallop_referral_program` | 61.78% |

## Notes

- The previous report stating `21` tests was outdated. The package currently contains `129` Move unit tests.
- `referral_revenue_pool` coverage improved from `42.55%` to `67.70%` after adding executable claim-path tests via test-only helpers.
- `scallop_referral_program` coverage improved from `0.00%` to `61.78%` after adding direct module tests for claim/burn paths plus failure cases through test-only wrappers.
- The remaining gap is that full end-to-end integration with real `VeScaTable` / `VeScaKey` state is still not exercised in this package.
- Coverage subcommands in Sui `1.63.2` are unstable for some per-source views; the module summary above is taken from `sui move coverage summary --test -q`, which completed successfully.
