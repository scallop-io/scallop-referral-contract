# Test Report

[繁體中文](test-report.zh-TW.md)

**Date**: 2026-03-10
**Sui CLI Version**: 1.63.2
**Commands**: `sui move test`, `sui move test --coverage`

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 129 |
| Passed | 129 |
| Failed | 0 |
| Pass Rate | 100% |
| Overall Move Coverage | 84.08% |

## Per-Module Coverage

| Module | Coverage |
|--------|----------|
| `referral_tiers` | 87.72% |
| `asc_u64_sorted_list` | 87.71% |
| `version` | 83.33% |
| `admin` | 78.72% |
| `referral_bindings` | 69.12% |
| `referral_revenue_pool` | 67.70% |
| `scallop_referral_program` | 61.78% |

## Test Categories

Tests cover the following areas:

- **Tier configuration and lookup** — boundary values, percentage validation (`MAX_PERCENTAGE = 100`), tier ordering by veSCA amount
- **Referral binding lifecycle** — bind, unbind, rebind, duplicate binding prevention, expired veSCA handling
- **Revenue pool** — accumulation, claiming, zero-balance paths, missing coin type paths
- **Referral ticket flow** — claim and burn lifecycle, discount application, failure cases
- **Admin operations** — tier management via admin capability, version control updates
- **Sorted list** — insertion, removal, ordering invariants, edge cases (empty list, single element, duplicates)
- **Version guard** — version mismatch enforcement across modules

## Known Limitations

- `scallop_referral_program` tests use test-only wrappers to supply veSCA state. Full end-to-end integration with real `VeScaTable` / `VeScaKey` objects is not exercised within this package.
- Coverage reporting via `sui move coverage source` is unstable in Sui CLI 1.63.2 for some modules. The per-module summary uses `sui move coverage summary --test -q`.
