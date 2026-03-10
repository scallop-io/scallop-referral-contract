/// @title Comprehensive tests for Admin module
/// @notice Covers AdminCapV2 operations, deprecated v1 abort behavior, upgrade flow, tier management via admin
#[test_only]
module scallop_referral_program::admin_test {

  use sui::test_utils;
  use sui::test_scenario;
  use scallop_referral_program::admin;
  use scallop_referral_program::referral_tiers;
  use scallop_referral_program::version;

  const ADMIN_ADDR: address = @0xAD;
  const NON_ADMIN: address = @0xBE;

  // ==================== AdminCapV2 Tier Management Tests ====================

  #[test]
  public fun test_add_tier_with_admin_cap_v2() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 0, 10, 5);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 1000, 20, 10);

    let (share, discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(share == 10 && discount == 5, 0);

    let (share, discount) = referral_tiers::find_tier(&tiers, 2000);
    assert!(share == 20 && discount == 10, 1);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_remove_tier_with_admin_cap_v2() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 0, 10, 5);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 1000, 20, 10);

    admin::remove_referral_tier_v2(&admin_cap, &mut tiers, 1000);

    // After removing tier 1000, values >= 1000 should fall back to tier 0
    let (share, discount) = referral_tiers::find_tier(&tiers, 5000);
    assert!(share == 10 && discount == 5, 0);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_set_version_with_admin_cap_v2() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let ver = version::create_with_value_for_test(ctx, 1);

    admin::set_contract_version_v2(&admin_cap, &mut ver, 2);
    admin::set_contract_version_v2(&admin_cap, &mut ver, 3);
    admin::set_contract_version_v2(&admin_cap, &mut ver, 4);

    // Should match CURRENT_VERSION now
    version::assert_version(&ver);

    test_utils::destroy(admin_cap);
    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== Deprecated AdminCap v1 Abort Tests ====================

  #[test]
  #[expected_failure(abort_code = 0)]
  public fun test_deprecated_add_referral_tier_v1_aborts() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    // Deprecated v1 function should abort with code 0
    admin::add_referral_tier(&admin_cap, &mut tiers, 0, 10, 5);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 0)]
  public fun test_deprecated_remove_referral_tier_v1_aborts() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    // Deprecated v1 function should abort with code 0
    admin::remove_referral_tier(&admin_cap, &mut tiers, 100);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 0)]
  public fun test_deprecated_set_contract_version_v1_aborts() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_for_test(ctx);
    let ver = version::create_with_value_for_test(ctx, 1);

    // Deprecated v1 function should abort with code 0
    admin::set_contract_version(&admin_cap, &mut ver, 2);

    test_utils::destroy(admin_cap);
    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== AdminCap Upgrade Flow Tests ====================

  #[test]
  public fun test_upgrade_admin_cap_v1_to_v2() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_v1 = admin::create_admin_cap_for_test(ctx);

    // Upgrade v1 to v2 (v1 is destroyed in the process)
    let admin_v2 = admin::upgrade_admin_cap(admin_v1, ctx);

    // V2 should work for tier management
    let tiers = referral_tiers::create_for_test(ctx);
    admin::add_referral_tier_v2(&admin_v2, &mut tiers, 0, 10, 5);

    let (share, discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(share == 10 && discount == 5, 0);

    test_utils::destroy(admin_v2);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Admin Tier Error Propagation Tests ====================

  #[test]
  #[expected_failure(abort_code = 601)]
  public fun test_admin_add_duplicate_tier_fails() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 100, 20, 10);
    // Duplicate tier should propagate ERROR_TIER_EXISTS (601)
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 100, 25, 12);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 602)]
  public fun test_admin_remove_nonexistent_tier_fails() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    // Remove tier that doesn't exist should propagate ERROR_TIER_NOT_EXISTS (602)
    admin::remove_referral_tier_v2(&admin_cap, &mut tiers, 999);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 701)]
  public fun test_admin_set_version_downgrade_fails() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let ver = version::create_with_value_for_test(ctx, 5);

    // Downgrade should propagate ERROR_VERSION_CAN_ONLY_INCREASE (701)
    admin::set_contract_version_v2(&admin_cap, &mut ver, 3);

    test_utils::destroy(admin_cap);
    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== Admin Multi-Operation Sequence Tests ====================

  #[test]
  public fun test_admin_complex_tier_management_sequence() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    // Add multiple tiers
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 0, 10, 5);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 100, 15, 8);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 1000, 25, 12);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 10000, 40, 20);

    // Remove one from the middle
    admin::remove_referral_tier_v2(&admin_cap, &mut tiers, 100);

    // Add it back with different values
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 100, 18, 9);

    // Verify the new tier values
    let (share, discount) = referral_tiers::find_tier(&tiers, 500);
    assert!(share == 18 && discount == 9, 0);

    // Remove the top tier
    admin::remove_referral_tier_v2(&admin_cap, &mut tiers, 10000);

    // Large values should now fall to tier 1000
    let (share, discount) = referral_tiers::find_tier(&tiers, 99999);
    assert!(share == 25 && discount == 12, 1);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }

  // ==================== Edge: AdminCapV2 with u64 max tier values ====================

  #[test]
  public fun test_admin_add_tier_with_extreme_values() {
    let scenario = test_scenario::begin(ADMIN_ADDR);
    let ctx = test_scenario::ctx(&mut scenario);

    let admin_cap = admin::create_admin_cap_v2_for_test(ctx);
    let tiers = referral_tiers::create_for_test(ctx);

    // Test extreme but valid values
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 0, 0, 0);
    admin::add_referral_tier_v2(&admin_cap, &mut tiers, 18446744073709551615, 100, 100);

    let (share, discount) = referral_tiers::find_tier(&tiers, 0);
    assert!(share == 0 && discount == 0, 0);

    let (share, discount) = referral_tiers::find_tier(&tiers, 18446744073709551615);
    assert!(share == 100 && discount == 100, 1);

    test_utils::destroy(admin_cap);
    test_utils::destroy(tiers);
    test_scenario::end(scenario);
  }
}
