/// @title Comprehensive edge case tests for ReferralBindings
/// @notice Covers many referees, same veSCA binding, rebind cycles, concurrent users, address boundaries
#[test_only]
module scallop_referral_program::referral_bindings_edge_test {

  use std::option;
  use sui::test_utils;
  use sui::test_scenario;
  use sui::object;
  use scallop_referral_program::referral_bindings;

  const REFEREE_1: address = @0xA1;
  const REFEREE_2: address = @0xA2;
  const REFEREE_3: address = @0xA3;
  const REFEREE_4: address = @0xA4;
  const REFEREE_5: address = @0xA5;

  // ==================== Same veSCA Key Binding Tests ====================

  #[test]
  public fun test_multiple_referees_bind_to_same_ve_sca() {
    // Multiple referees should be able to bind to the same referrer's veSCA
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let ve_sca_key_id = object::id_from_address(@0x1001);
    let bindings = referral_bindings::create_for_test(ctx);

    // REFEREE_1 binds
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);

    // REFEREE_2 binds to the same veSCA
    test_scenario::next_tx(&mut scenario, REFEREE_2);
    let ctx2 = test_scenario::ctx(&mut scenario);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx2);

    // REFEREE_3 binds to the same veSCA
    test_scenario::next_tx(&mut scenario, REFEREE_3);
    let ctx3 = test_scenario::ctx(&mut scenario);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx3);

    // All three should be bound to the same veSCA
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id, REFEREE_1), 0);
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id, REFEREE_2), 1);
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id, REFEREE_3), 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Rebind Cycle Tests ====================

  #[test]
  public fun test_rebind_cycle_through_multiple_referrers() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_a = object::id_from_address(@0x1001);
    let ve_sca_b = object::id_from_address(@0x1002);
    let ve_sca_c = object::id_from_address(@0x1003);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind to A
    referral_bindings::bind_for_test(&mut bindings, ve_sca_a, ctx);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_1)) == ve_sca_a, 0);

    // Unbind from A, bind to B
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_b, ctx);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_1)) == ve_sca_b, 1);

    // Unbind from B, bind to C
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_c, ctx);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_1)) == ve_sca_c, 2);

    // Unbind from C, bind back to A (full cycle)
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_a, ctx);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_1)) == ve_sca_a, 3);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Bind to Same veSCA After Unbind ====================

  #[test]
  public fun test_rebind_to_same_ve_sca() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let ve_sca_key_id = object::id_from_address(@0x1001);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE_1), 0);

    // Unbind
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    assert!(!referral_bindings::has_ve_sca_binding(&bindings, REFEREE_1), 1);

    // Rebind to the SAME veSCA
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id, REFEREE_1), 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Double Bind Same veSCA Should Fail ====================

  #[test]
  #[expected_failure(abort_code = 405)]
  public fun test_bind_same_ve_sca_twice_should_fail() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let ve_sca_key_id = object::id_from_address(@0x1001);
    let bindings = referral_bindings::create_for_test(ctx);

    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);
    // Binding again to the same veSCA should also fail
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Many Users Concurrent Tests ====================

  #[test]
  public fun test_five_referees_different_referrers() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_1 = object::id_from_address(@0x2001);
    let ve_sca_2 = object::id_from_address(@0x2002);
    let ve_sca_3 = object::id_from_address(@0x2003);
    let ve_sca_4 = object::id_from_address(@0x2004);
    let ve_sca_5 = object::id_from_address(@0x2005);

    let bindings = referral_bindings::create_for_test(ctx);

    // Each referee binds to a different referrer
    referral_bindings::bind_for_test(&mut bindings, ve_sca_1, ctx);

    test_scenario::next_tx(&mut scenario, REFEREE_2);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_2, test_scenario::ctx(&mut scenario));

    test_scenario::next_tx(&mut scenario, REFEREE_3);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_3, test_scenario::ctx(&mut scenario));

    test_scenario::next_tx(&mut scenario, REFEREE_4);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_4, test_scenario::ctx(&mut scenario));

    test_scenario::next_tx(&mut scenario, REFEREE_5);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_5, test_scenario::ctx(&mut scenario));

    // Verify all bindings are correct and independent
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_1)) == ve_sca_1, 0);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_2)) == ve_sca_2, 1);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_3)) == ve_sca_3, 2);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_4)) == ve_sca_4, 3);
    assert!(option::destroy_some(referral_bindings::get_binding(&bindings, REFEREE_5)) == ve_sca_5, 4);

    // Cross-verify: REFEREE_1 is NOT bound to ve_sca_2
    assert!(!referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_2, REFEREE_1), 5);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Unbind One Doesn't Affect Others ====================

  #[test]
  public fun test_unbind_one_referee_does_not_affect_others() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_shared = object::id_from_address(@0x3001);
    let bindings = referral_bindings::create_for_test(ctx);

    // Both referees bind to the same veSCA
    referral_bindings::bind_for_test(&mut bindings, ve_sca_shared, ctx);

    test_scenario::next_tx(&mut scenario, REFEREE_2);
    referral_bindings::bind_for_test(&mut bindings, ve_sca_shared, test_scenario::ctx(&mut scenario));

    // REFEREE_1 unbinds
    test_scenario::next_tx(&mut scenario, REFEREE_1);
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, test_scenario::ctx(&mut scenario));

    // REFEREE_1 should be unbound
    assert!(!referral_bindings::has_ve_sca_binding(&bindings, REFEREE_1), 0);
    // REFEREE_2 should still be bound
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE_2), 1);
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_shared, REFEREE_2), 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Address Boundary Tests ====================

  #[test]
  public fun test_bind_with_zero_address_ve_sca() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let ve_sca_zero = object::id_from_address(@0x0);
    let bindings = referral_bindings::create_for_test(ctx);

    referral_bindings::bind_for_test(&mut bindings, ve_sca_zero, ctx);
    assert!(referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_zero, REFEREE_1), 0);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Query Nonexistent Binding ====================

  #[test]
  public fun test_get_binding_for_unbound_address() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let bindings = referral_bindings::create_for_test(ctx);

    // Query binding for an address that was never bound
    let binding = referral_bindings::get_binding(&bindings, REFEREE_2);
    assert!(option::is_none(&binding), 0);

    // has_ve_sca_binding should also return false
    assert!(!referral_bindings::has_ve_sca_binding(&bindings, REFEREE_2), 1);

    // is_binded_to_the_given_referrer_ve_sca should return false
    let ve_sca = object::id_from_address(@0x9999);
    assert!(!referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca, REFEREE_2), 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Double Unbind Should Fail ====================

  #[test]
  #[expected_failure(abort_code = 406)]
  public fun test_double_unbind_should_fail() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let ve_sca_key_id = object::id_from_address(@0x1001);
    let bindings = referral_bindings::create_for_test(ctx);

    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    // Second unbind should fail
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  // ==================== Multiple Bind Attempts After Unbind ====================

  #[test]
  public fun test_rapid_bind_unbind_cycles() {
    let scenario = test_scenario::begin(REFEREE_1);
    let ctx = test_scenario::ctx(&mut scenario);
    let bindings = referral_bindings::create_for_test(ctx);

    let i = 0u64;
    while (i < 10) {
      let ve_sca = object::id_from_address(sui::address::from_u256((i as u256) + 1));
      referral_bindings::bind_for_test(&mut bindings, ve_sca, ctx);
      assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE_1), i);
      referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
      assert!(!referral_bindings::has_ve_sca_binding(&bindings, REFEREE_1), i);
      i = i + 1;
    };

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }
}
