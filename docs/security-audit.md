# Security Audit Report: Scallop Referral Contract

[繁體中文](security-audit.zh-TW.md)

**Contract**: `ScallopReferralProgram`
**Repository**: `scallop-io/scallop-referral-contract`
**Audit Date**: 2026-03-10
**Basis**: Source tree review, `sui move test`, `sui move test --coverage`

## Executive Summary

This audit identified two code-level issues, both of which have been fixed. The contract uses standard Move safety primitives (abort-on-overflow arithmetic, capability-gated admin functions, version control). Remaining gaps are limited to the absence of full end-to-end integration tests using real `VeScaTable` / `VeScaKey` state.

## Scope

Modules reviewed:

- `sources/scallop_referral_program.move` — Referral ticket claim/burn lifecycle
- `sources/referral_bindings.move` — Referee-to-referrer mapping
- `sources/referral_tiers.move` — Tier configuration and lookup
- `sources/referral_revenue_pool.move` — Revenue distribution and claiming
- `sources/admin.move` — Administrative operations
- `sources/version.move` — Version guard enforcement
- `sources/sorted_list.move` — Sorted list utility

## Findings

### [M-01] Percentage configuration accepted values above 100 (Fixed)

- **Module**: `sources/referral_tiers.move`
- **Severity**: Medium
- **Status**: Fixed

`referral_share` and `borrow_fee_discount` parameters in `add_tier` accepted arbitrary `u64` values with no upper bound. Values above 100 conflict with the intended percentage semantics.

**Resolution**:

- Added `MAX_PERCENTAGE = 100` constant
- Added `ERROR_INVALID_REFERRAL_SHARE = 603` and `ERROR_INVALID_BORROW_FEE_DISCOUNT = 604`
- Enforced validation in `add_tier`
- Regression tests added in tier tests and admin entrypoint tests

### [L-01] Missing-coin claim path for existing referrer (Fixed)

- **Module**: `sources/referral_revenue_pool.move`
- **Severity**: Low
- **Status**: Fixed

When a referrer existed in `ve_sca_revenue_data` but had no revenue recorded for the requested `CoinType`, the claim logic could proceed into an unexpected code path instead of returning a zero balance.

**Resolution**:

- Refactored to a shared internal claim path
- Returns zero balance when requested revenue amount is zero
- Added defensive assertion for inconsistent state (non-zero tracked revenue without initialized pool)
- Regression tests cover: successful claim, repeated claim returning zero, and missing coin type returning zero

## Design Observations

### Stale referral bindings (Informational)

- **Module**: `sources/referral_bindings.move`

Bindings are persistent while veSCA state is time-dependent. A referrer whose veSCA expires remains bound. This is a known product behavior, not a code defect, but may produce confusing user outcomes.

### Integration test coverage (Informational)

- **Module**: `sources/scallop_referral_program.move`

The main referral-ticket flow is tested via test-only wrappers that supply veSCA amount and binding inputs directly. Full end-to-end tests through real `VeScaTable` and `VeScaKey` state are not exercised within this package. Module coverage stands at 61.78%.

## Test Summary

| Metric | Value |
|--------|-------|
| Tests | 129 / 129 passing |
| Overall Coverage | 84.08% |

See [Test Report](test-report.md) for per-module coverage breakdown.

## Conclusion

All identified code-level issues have been resolved. The contract benefits from Move's abort-on-overflow arithmetic, which prevents silent integer wrapping. The primary remaining gap is the lack of end-to-end integration tests using production `VeScaTable` / `VeScaKey` objects.
