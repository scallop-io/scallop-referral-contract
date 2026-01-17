#[test_only]
module scallop_referral_program::referral_bindings_test {

  use std::option;
  use sui::test_utils;
  use sui::test_scenario;
  use sui::object;
  use scallop_referral_program::referral_bindings;

  const REFEREE: address = @0xA1;
  const REFEREE_2: address = @0xA2;

  #[test]
  public fun test_bind_and_get_binding() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    // Create a mock veSCA key ID
    let ve_sca_key_id = object::id_from_address(@0x1001);

    // Create referral bindings
    let bindings = referral_bindings::create_for_test(ctx);

    // Initially should have no binding
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == false, 0);
    let binding = referral_bindings::get_binding(&bindings, REFEREE);
    assert!(option::is_none(&binding), 1);

    // Bind to referrer
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);

    // Should now have binding
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == true, 2);
    let binding = referral_bindings::get_binding(&bindings, REFEREE);
    assert!(option::is_some(&binding), 3);
    assert!(option::destroy_some(binding) == ve_sca_key_id, 4);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_unbind() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_key_id = object::id_from_address(@0x1001);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind first
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id, ctx);
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == true, 0);

    // Unbind
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);

    // Should no longer have binding
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == false, 1);
    let binding = referral_bindings::get_binding(&bindings, REFEREE);
    assert!(option::is_none(&binding), 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_is_binded_to_the_given_referrer_ve_sca() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_key_id_1 = object::id_from_address(@0x1001);
    let ve_sca_key_id_2 = object::id_from_address(@0x1002);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind to ve_sca_key_id_1
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_1, ctx);

    // Check binding to correct referrer
    assert!(
      referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id_1, REFEREE) == true,
      0
    );

    // Check binding to wrong referrer
    assert!(
      referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id_2, REFEREE) == false,
      1
    );

    // Check non-existent binding
    assert!(
      referral_bindings::is_binded_to_the_given_referrer_ve_sca(&bindings, ve_sca_key_id_1, REFEREE_2) == false,
      2
    );

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_multiple_referees() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_key_id_1 = object::id_from_address(@0x1001);
    let ve_sca_key_id_2 = object::id_from_address(@0x1002);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind REFEREE to ve_sca_key_id_1
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_1, ctx);

    // Switch to REFEREE_2
    test_scenario::next_tx(&mut scenario, REFEREE_2);
    let ctx2 = test_scenario::ctx(&mut scenario);

    // Bind REFEREE_2 to ve_sca_key_id_2
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_2, ctx2);

    // Verify both bindings exist independently
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == true, 0);
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE_2) == true, 1);

    let binding_1 = referral_bindings::get_binding(&bindings, REFEREE);
    let binding_2 = referral_bindings::get_binding(&bindings, REFEREE_2);

    assert!(option::destroy_some(binding_1) == ve_sca_key_id_1, 2);
    assert!(option::destroy_some(binding_2) == ve_sca_key_id_2, 3);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  public fun test_rebind_after_unbind() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_key_id_1 = object::id_from_address(@0x1001);
    let ve_sca_key_id_2 = object::id_from_address(@0x1002);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind to first referrer
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_1, ctx);
    let binding = referral_bindings::get_binding(&bindings, REFEREE);
    assert!(option::destroy_some(binding) == ve_sca_key_id_1, 0);

    // Unbind
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);
    assert!(referral_bindings::has_ve_sca_binding(&bindings, REFEREE) == false, 1);

    // Rebind to different referrer
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_2, ctx);
    let binding = referral_bindings::get_binding(&bindings, REFEREE);
    assert!(option::destroy_some(binding) == ve_sca_key_id_2, 2);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 405)]
  public fun test_bind_already_binded_should_fail() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let ve_sca_key_id_1 = object::id_from_address(@0x1001);
    let ve_sca_key_id_2 = object::id_from_address(@0x1002);
    let bindings = referral_bindings::create_for_test(ctx);

    // Bind first time
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_1, ctx);

    // Try to bind again - should fail with ERefereeAlreadyBinded (405)
    referral_bindings::bind_for_test(&mut bindings, ve_sca_key_id_2, ctx);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = 406)]
  public fun test_unbind_not_binded_should_fail() {
    let scenario = test_scenario::begin(REFEREE);
    let ctx = test_scenario::ctx(&mut scenario);

    let bindings = referral_bindings::create_for_test(ctx);

    // Try to unbind without binding first - should fail with ERefereeNotBinded (406)
    referral_bindings::unbind_ve_sca_referrer(&mut bindings, ctx);

    test_utils::destroy(bindings);
    test_scenario::end(scenario);
  }
}
