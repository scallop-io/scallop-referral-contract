#[test_only]
module scallop_referral_program::referral_tiers_test {

  use sui::test_utils;
  use sui::test_scenario;
  use scallop_referral_program::referral_tiers;

  const SENDER: address = @0xAD;

  #[test]
  public fun referral_tiers_test() {
    let senario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut senario);
    let tiers = referral_tiers::create_for_test(ctx);
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 15, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 10000, 30, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 100000, 40, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 1000000, 50, 10);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 10, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 99);
    assert!(referral_share == 10, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 101);
    assert!(referral_share == 15, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 2000);
    assert!(referral_share == 20, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 20000);
    assert!(referral_share == 30, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 255555);
    assert!(referral_share == 40, 0);
    assert!(fee_discount == 10, 0);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 1255555);
    assert!(referral_share == 50, 0);
    assert!(fee_discount == 10, 0);

    test_utils::destroy(tiers);
    test_scenario::end(senario);
  }

  #[test]
  public fun test_remove_tier() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Add tiers
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 30, 15);

    // Verify middle tier
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(referral_share == 20, 0);
    assert!(fee_discount == 10, 1);

    // Remove middle tier and verify returned values
    let (removed_share, removed_discount) = referral_tiers::remove_tier_for_test(&mut tiers, 100);
    assert!(removed_share == 20, 2);
    assert!(removed_discount == 10, 3);

    // After removal, 500 should fall back to tier 0
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(referral_share == 10, 4);
    assert!(fee_discount == 5, 5);

    // Tier 1000 should still work
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 1000);
    assert!(referral_share == 30, 6);
    assert!(fee_discount == 15, 7);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_exact_tier_boundaries() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);

    // Exactly at boundary
    let (referral_share, _) = referral_tiers::find_tier(&tiers, 100);
    assert!(referral_share == 20, 0);

    // One below boundary
    let (referral_share, _) = referral_tiers::find_tier(&tiers, 99);
    assert!(referral_share == 10, 1);

    // One above boundary
    let (referral_share, _) = referral_tiers::find_tier(&tiers, 101);
    assert!(referral_share == 20, 2);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_single_tier() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Only one tier at 0
    referral_tiers::add_tier_for_test(&mut tiers, 0, 15, 8);

    // Any amount should match tier 0
    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(referral_share == 15, 0);
    assert!(fee_discount == 8, 1);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 999999);
    assert!(referral_share == 15, 2);
    assert!(fee_discount == 8, 3);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_different_discounts_per_tier() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Different discount rates for each tier
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 20, 10);
    referral_tiers::add_tier_for_test(&mut tiers, 10000, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 100000, 40, 20);

    let (_, fee_discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(fee_discount == 5, 0);

    let (_, fee_discount) = referral_tiers::find_tier(&tiers, 5000);
    assert!(fee_discount == 10, 1);

    let (_, fee_discount) = referral_tiers::find_tier(&tiers, 50000);
    assert!(fee_discount == 15, 2);

    let (_, fee_discount) = referral_tiers::find_tier(&tiers, 500000);
    assert!(fee_discount == 20, 3);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_add_tiers_in_random_order() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    // Add tiers in non-ascending order
    referral_tiers::add_tier_for_test(&mut tiers, 1000, 30, 15);
    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);

    // Should still find correct tiers
    let (referral_share, _) = referral_tiers::find_tier(&tiers, 50);
    assert!(referral_share == 10, 0);

    let (referral_share, _) = referral_tiers::find_tier(&tiers, 500);
    assert!(referral_share == 20, 1);

    let (referral_share, _) = referral_tiers::find_tier(&tiers, 5000);
    assert!(referral_share == 30, 2);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 601)]
  public fun test_add_duplicate_tier_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    // Adding same tier again should fail with ERROR_TIER_EXISTS (601)
    referral_tiers::add_tier_for_test(&mut tiers, 100, 25, 12);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 602)]
  public fun test_remove_nonexistent_tier_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);
    // Removing non-existent tier should fail with ERROR_TIER_NOT_EXISTS (602)
    referral_tiers::remove_tier_for_test(&mut tiers, 200);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_remove_and_readd_tier() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let tiers = referral_tiers::create_for_test(ctx);

    referral_tiers::add_tier_for_test(&mut tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut tiers, 100, 20, 10);

    // Remove tier
    referral_tiers::remove_tier_for_test(&mut tiers, 100);

    // Re-add with different values
    referral_tiers::add_tier_for_test(&mut tiers, 100, 25, 12);

    let (referral_share, fee_discount) = referral_tiers::find_tier(&tiers, 100);
    assert!(referral_share == 25, 0);
    assert!(fee_discount == 12, 1);

    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }
}

