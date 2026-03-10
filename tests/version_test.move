/// @title Comprehensive tests for Version module
/// @notice Covers version assertion, downgrade prevention, increment logic, mismatch detection
#[test_only]
module scallop_referral_program::version_test {

  use sui::test_utils;
  use sui::test_scenario;
  use scallop_referral_program::version;

  const SENDER: address = @0xAD;

  // ==================== Version Assertion Tests ====================

  #[test]
  public fun test_assert_version_with_current_version_succeeds() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_for_test(ctx);

    // Should not abort - version matches CURRENT_VERSION (4)
    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 702)]
  public fun test_assert_version_with_old_version_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    // Create version with value 1 (old version)
    let ver = version::create_with_value_for_test(ctx, 1);

    // Should abort with ERROR_VERSION_MISMATCH (702)
    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 702)]
  public fun test_assert_version_with_future_version_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    // Create version with value 999 (future version)
    let ver = version::create_with_value_for_test(ctx, 999);

    // Should abort with ERROR_VERSION_MISMATCH (702)
    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 702)]
  public fun test_assert_version_with_zero_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 0);

    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== Set Version Tests ====================

  #[test]
  public fun test_set_version_increment_by_one() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 1);

    // Increment from 1 to 2
    version::set_version_for_test(&mut ver, 2);

    // Now assert_version should fail since CURRENT_VERSION is 4
    // But the internal value should be 2 now

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_set_version_increment_by_large_jump() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 1);

    // Jump from 1 to 1000
    version::set_version_for_test(&mut ver, 1000);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_set_version_multiple_increments() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 1);

    version::set_version_for_test(&mut ver, 2);
    version::set_version_for_test(&mut ver, 3);
    version::set_version_for_test(&mut ver, 4);

    // Now it should match CURRENT_VERSION (4)
    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== Downgrade Prevention Tests ====================

  #[test]
  #[expected_failure(abort_code = 701)]
  public fun test_set_version_downgrade_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 5);

    // Try to set version to 3 (downgrade) - should fail with ERROR_VERSION_CAN_ONLY_INCREASE (701)
    version::set_version_for_test(&mut ver, 3);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 701)]
  public fun test_set_version_same_value_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 5);

    // Setting to the same value should fail (not strictly greater)
    version::set_version_for_test(&mut ver, 5);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 701)]
  public fun test_set_version_to_zero_from_nonzero_should_fail() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 3);

    version::set_version_for_test(&mut ver, 0);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== u64 Boundary Tests ====================

  #[test]
  public fun test_set_version_to_u64_max() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 1);

    version::set_version_for_test(&mut ver, 18446744073709551615);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 701)]
  public fun test_set_version_at_u64_max_cannot_increment_further() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 18446744073709551615);

    // At max, any set_version call should fail since no value is > u64::MAX
    version::set_version_for_test(&mut ver, 18446744073709551615);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_set_version_from_u64_max_minus_one_to_max() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_with_value_for_test(ctx, 18446744073709551614);

    version::set_version_for_test(&mut ver, 18446744073709551615);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }

  // ==================== Version Created at CURRENT_VERSION ====================

  #[test]
  public fun test_default_version_matches_current() {
    let scenario = test_scenario::begin(SENDER);
    let ctx = test_scenario::ctx(&mut scenario);
    let ver = version::create_for_test(ctx);

    // create_for_test should produce a Version with CURRENT_VERSION
    version::assert_version(&ver);

    test_utils::destroy(ver);
    test_scenario::end(scenario);
  }
}
