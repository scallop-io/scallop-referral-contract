# Security Audit Report: Scallop Referral Contract

**Contract**: `ScallopReferralProgram`  
**Repository**: `scallop-io/scallop-referral-contract`  
**Review Date**: 2026-03-10  
**Basis**: current local source tree, `sui move test`, `sui move test --coverage`

## Executive Summary

The previous audit document was not accurate for the current codebase. It overstated both test coverage and finding quality.

The two concrete contract issues confirmed during this review were:

1. Tier configuration accepted percentages above `100`, allowing invalid admin configuration.
2. Claiming a coin type with no recorded revenue for an otherwise known referrer could hit an unexpected path instead of returning zero cleanly.

Both issues are now fixed in code.

## Corrected Assessment

### Invalid / overstated findings in the previous report

- `H-01 Arithmetic overflow in increase_revenue_data`: **invalid**
  - The previous report treated Move integer arithmetic as silently wrapping.
  - That assumption is wrong for Move integer ops in this environment: arithmetic overflow aborts instead of silently wrapping.
  - This item should not have been reported as a high-severity locked-funds issue.

- “Formal verification”, “fuzz testing”, and broad integration claims: **unsupported**
  - The repository contains unit tests, but no formal verification artifacts.
  - Earlier versions of this repository had no direct tests for `scallop_referral_program`; that claim is no longer true after this review.
  - The earlier report still overstated assurance because those artifacts are absent and the integration tests are still partial rather than full end-to-end.

### Valid findings

#### Fixed: invalid percentage configuration

- Module: `sources/referral_tiers.move`
- Severity: Medium
- Status: Fixed

`referral_share` and `borrow_fee_discount` were previously unconstrained `u64` values. Admins could store values above `100`, which conflicted with the documented percentage semantics.

Fix:

- Added `MAX_PERCENTAGE = 100`
- Added `ERROR_INVALID_REFERRAL_SHARE = 603`
- Added `ERROR_INVALID_BORROW_FEE_DISCOUNT = 604`
- Enforced both checks in `add_tier`
- Added regression tests through both direct tier tests and admin entrypoint tests

#### Fixed: missing-coin claim path for existing referrer

- Module: `sources/referral_revenue_pool.move`
- Severity: Low
- Status: Fixed

If a referrer existed in `ve_sca_revenue_data` but had no revenue for the requested `CoinType`, claim logic could still proceed into the pool path rather than returning zero cleanly.

Fix:

- Refactored claim logic into a shared internal path
- Return zero balance when requested revenue amount is zero
- Added a defensive assertion if non-zero tracked revenue exists but the pool does not have the coin initialized
- Added regression tests covering:
  - successful claim
  - repeated claim returning zero
  - missing coin type returning zero

## Remaining Risks / Gaps

### Integration coverage is improved but still partial

- Module: `sources/scallop_referral_program.move`
- Severity: Informational

The main referral-ticket flow is now directly exercised by local tests, and module coverage improved to `61.78%`. However, the current tests use test-only wrappers to feed veSCA amount / binding inputs rather than driving a full end-to-end path through real `VeScaTable` and `VeScaKey` state.

Any audit claim implying full integration assurance for borrow referral behavior would still be overstated.

### Stale referral bindings remain a product behavior caveat

- Module: `sources/referral_bindings.move`
- Severity: Informational

Bindings are persistent even though veSCA state is time-dependent. This is not necessarily a vulnerability, but it can still produce confusing user outcomes if a bound referrer later becomes ineffective.

## Current Test Reality

- `129 / 129` tests passing
- Overall Move coverage: `84.08%`
- `referral_revenue_pool`: `67.70%`
- `referral_tiers`: `87.72%`
- `scallop_referral_program`: `61.78%`

## Conclusion

The contract is in better shape than the previous audit claimed in some places, and worse in others. The old report incorrectly included a high-severity arithmetic issue, and it also misrepresented the state of integration testing. After the fixes in this review, the confirmed code issues found locally are addressed. The main remaining concern is not zero coverage anymore, but the lack of a full end-to-end veSCA-backed integration test.
