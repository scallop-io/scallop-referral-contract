/// @title Comprehensive edge case tests for ReferralTiers
/// @notice Covers u64 max values, extreme percentages, many tiers, empty tiers, boundary conditions, fuzz-style tests
#[test_only]
module scallop_referral_program::referral_tiers_edge_test {

  use sui::test_utils;
  use sui::test_scenario;
  use scallop_referral_program::referral_tiers;

  const SENDER: address = @0xAD;

  // ==================== u64 Max Value Tests ====================

  #[test]
  public fun test_tier_at_u64_max_threshold() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 18446744073709551615, 99, 50);

    // Value at u64::MAX should match the max tier
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 18446744073709551615);
    assert!(referral_share == 99, 0);
    assert!(fee_discount == 50, 1);

    // Value just below u64::MAX should still be in tier 0
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 18446744073709551614);
    assert!(referral_share == 10, 2);
    assert!(fee_discount == 5, 3);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_tier_with_u64_max_referral_share() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Extreme share/discount values (contract uses base 100, but doesn't enforce limits)
    referral_tiers::add_tier_for_test(&mut tiers, 0, 18446744073709551615, 18446744073709551615);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 18446744073709551615, 0);
    assert!(fee_discount == 18446744073709551615, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Extreme Percentage Tests ====================

  #[test]
  public fun test_tier_with_zero_share_and_discount() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 0, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 100);
    assert!(referral_share == 0, 0);
    assert!(fee_discount == 0, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_tier_with_100_percent_share_and_discount() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // base 100: 100 means 100%
    referral_tiers::add_tier_for_test(&mut tiers, 0, 100, 100);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 100, 0);
    assert!(fee_discount == 100, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_tier_with_above_100_percent() {
    // Contract doesn't enforce percentage limits, test that values >100 are stored correctly
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 200, 150);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 200, 0);
    assert!(fee_discount == 150, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Empty Tiers Tests ====================

  #[test]
  #[expected_failure]
  public fun test_find_tier_on_empty_tiers_should_abort() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // No tiers added, find_tier should abort (underlying sorted list will abort)
    referral_tiers::find_tier(&tiers, 0);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure]
  public fun test_find_tier_below_lowest_tier_should_abort() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Lowest tier starts at 100, querying for 50 should have no match
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);

    referral_tiers::find_tier(&tiers, 50);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Many Tiers Tests ====================

  #[test]
  public fun test_many_tiers_correct_lookup() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Add 20 tiers with different thresholds
    let i = 0u64;
    while (i < 20) {
      referral_tiers::add_tier_for_test(&mut tiers, i * 1000, (i + 1) * 5, (i + 1) * 2);
      i = i + 1;
    };

    // Check tier at threshold 0 (share=5, discount=2)
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 5, 0);
    assert!(fee_discount == 2, 1);

    // Check tier at threshold 5000 (share=30, discount=12)
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 5500);
    assert!(referral_share == 30, 2);
    assert!(fee_discount == 12, 3);

    // Check the highest tier at 19000 (share=100, discount=40)
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 99999);
    assert!(referral_share == 100, 4);
    assert!(fee_discount == 40, 5);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Tier Boundary Precision Tests ====================

  #[test]
  public fun test_consecutive_tier_boundaries() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Consecutive tiers: 0, 1, 2, 3
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 1, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 2, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 3, 40, 20);

    let (share, _) = referral_tiers::find_tier(&tiers, 0);
    assert!(share == 10, 0);

    let (share, _) = referral_tiers::find_tier(&tiers, 1);
    assert!(share == 20, 1);

    let (share, _) = referral_tiers::find_tier(&tiers, 2);
    assert!(share == 30, 2);

    let (share, _) = referral_tiers::find_tier(&tiers, 3);
    assert!(share == 40, 3);

    // 4 should still be in tier 3
    let (share, _) = referral_tiers::find_tier(&tiers, 4);
    assert!(share == 40, 4);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Remove All Tiers Tests ====================

  #[test]
  #[expected_failure]
  public fun test_remove_all_tiers_then_find_should_abort() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);

    referral_tiers::remove_tier_for_test(&mut tiers, 0);
    referral_tiers::remove_tier_for_test(&mut tiers, 100);

    // All tiers removed, find_tier should abort
    referral_tiers::find_tier(&tiers, 50);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Add/Remove Same Tier Repeatedly ====================

  #[test]
  public fun test_add_remove_add_remove_same_tier() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);

    // Add tier 100, remove it, add it again with different values, remove again
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    let (share, discount) = referral_tiers::remove_tier_for_test(&mut tiers, 100);
    assert!(share == 20 && discount == 10, 0);

    referral_tiers::add_tier_for_test(&mut tiers, 100, 30, 15);
    let (share, discount) = referral_tiers::remove_tier_for_test(&mut tiers, 100);
    assert!(share == 30 && discount == 15, 1);

    referral_tiers::add_tier_for_test(&mut tiers, 100, 40, 20);
    let (share, discount) = referral_tiers::find_tier(&tiers, 100);
    assert!(share == 40 && discount == 20, 2);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Duplicate Tier Error Tests ====================

  #[test]
  #[expected_failure(abort_code = 601)]
  public fun test_add_duplicate_tier_at_zero_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 0, 20, 10);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 601)]
  public fun test_add_duplicate_tier_at_u64_max_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 18446744073709551615, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 18446744073709551615, 20, 10);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Remove Nonexistent Tier Error Tests ====================

  #[test]
  #[expected_failure(abort_code = 602)]
  public fun test_remove_tier_from_empty_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::remove_tier_for_test(&mut tiers, 0);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 602)]
  public fun test_remove_already_removed_tier_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    referral_tiers::remove_tier_for_test(&mut tiers, 100);
    referral_tiers::remove_tier_for_test(&mut tiers, 100); // should fail

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Fuzz-Style Tier Ordering Tests ====================

  #[test]
  public fun test_add_tiers_in_descending_order() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Add in descending order
    referral_tiers::add_tier_for_test(&mut tiers, 10000, 50, 25);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);

    // Verify lookup still works correctly
    let (share, _) = referral_tiers::find_tier(&tiers, 0);
    assert!(share == 10, 0);
    let (share, _) = referral_tiers::find_tier(&tiers, 99);
    assert!(share == 10, 1);
    let (share, _) = referral_tiers::find_tier(&tiers, 100);
    assert!(share == 20, 2);
    let (share, _) = referral_tiers::find_tier(&tiers, 999);
    assert!(share == 20, 3);
    let (share, _) = referral_tiers::find_tier(&tiers, 1000);
    assert!(share == 30, 4);
    let (share, _) = referral_tiers::find_tier(&tiers, 10000);
    assert!(share == 50, 5);
    let (share, _) = referral_tiers::find_tier(&tiers, 99999);
    assert!(share == 50, 6);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_tiers_with_interleaved_add_remove() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 200, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 300, 40, 20);

    // Remove middle tiers
    referral_tiers::remove_tier_for_test(&mut tiers, 100);
    referral_tiers::remove_tier_for_test(&mut tiers, 200);

    // Values between 0 and 300 should fall to tier 0
    let (share, _) = referral_tiers::find_tier(&tiers, 150);
    assert!(share == 10, 0);
    let (share, _) = referral_tiers::find_tier(&tiers, 250);
    assert!(share == 10, 1);

    // 300+ should still match tier 300
    let (share, _) = referral_tiers::find_tier(&tiers, 300);
    assert!(share == 40, 2);

    // Re-add a tier at 150
    referral_tiers::add_tier_for_test(&mut tiers, 150, 25, 12);
    let (share, _) = referral_tiers::find_tier(&tiers, 200);
    assert!(share == 25, 3);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Identical Share/Discount Across Tiers ====================

  #[test]
  public fun test_all_tiers_same_share_and_discount() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // All tiers have the same values - valid but potentially misconfigured
    referral_tiers::add_tier_for_test(&mut tiers, 0, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 10000, 20, 10);

    let (share, discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(share == 20 && discount == 10, 0);
    let (share, discount) = referral_tiers::find_tier(&tiers, 5000);
    assert!(share == 20 && discount == 10, 1);
    let (share, discount) = referral_tiers::find_tier(&tiers, 50000);
    assert!(share == 20 && discount == 10, 2);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Non-monotonic Share Values ====================

  #[test]
  public fun test_tiers_with_decreasing_shares() {
    // Contract doesn't enforce that higher tiers have higher shares
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 50, 25);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 10, 5);

    // Verify the decreasing share values are stored and returned correctly
    let (share, _) = referral_tiers::find_tier(&tiers, 50);
    assert!(share == 50, 0);
    let (share, _) = referral_tiers::find_tier(&tiers, 500);
    assert!(share == 30, 1);
    let (share, _) = referral_tiers::find_tier(&tiers, 5000);
    assert!(share == 10, 2);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Large Gap Between Tiers ====================

  #[test]
  public fun test_huge_gap_between_tiers() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 1000000000000000000, 50, 25); // 1e18

    // Anything below 1e18 should be tier 0
    let (share, _) = referral_tiers::find_tier(&tiers, 999999999999999999);
    assert!(share == 10, 0);

    // At 1e18 should be tier 1e18
    let (share, _) = referral_tiers::find_tier(&tiers, 1000000000000000000);
    assert!(share == 50, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }
}
