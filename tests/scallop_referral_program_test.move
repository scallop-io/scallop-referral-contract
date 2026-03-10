#[test_only]
module scallop_referral_program::scallop_referral_program_test {

  use sui::coin;
  use sui::object;
  use sui::test_scenario;
  use sui::test_utils;

  use protocol::app_t;
  use protocol::borrow_referral::{Self, AuthorizedWitnessList};

  use scallop_referral_program::referral_bindings;
  use scallop_referral_program::referral_revenue_pool;
  use scallop_referral_program::referral_tiers;
  use scallop_referral_program::scallop_referral_program;
  use scallop_referral_program::version;

  const ADMIN: address = @0xAD;
  const BORROWER: address = @0xB0;

  struct SUI has drop {}

  #[test]
  fun test_claim_and_burn_referral_ticket_for_bound_user() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;

    let version = version::create_for_test(test_scenario::ctx(scenario));
    let referral_tiers = referral_tiers::create_for_test(test_scenario::ctx(scenario));
    let referral_bindings = referral_bindings::create_for_test(test_scenario::ctx(scenario));
    let referral_revenue_pool = referral_revenue_pool::create_for_test(test_scenario::ctx(scenario));

    referral_tiers::add_tier_for_test(&mut referral_tiers, 0, 10, 5);
    referral_tiers::add_tier_for_test(&mut referral_tiers, 200, 25, 15);

    let (market, admin_cap) = app_t::app_init(scenario);
    borrow_referral::init_test(test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, ADMIN);
    let authorized_witness_list = test_scenario::take_shared<AuthorizedWitnessList>(scenario);
    scallop_referral_program::authorize_referral_witness_for_test(&admin_cap, &mut authorized_witness_list);

    test_scenario::next_tx(scenario, BORROWER);
    let ctx = test_scenario::ctx(scenario);
    let ve_sca_key_id = object::id_from_address(@0x5001);
    referral_bindings::bind_for_test(&mut referral_bindings, ve_sca_key_id, ctx);

    let (borrow_fee_discount, referral_share) =
      scallop_referral_program::calc_borrow_fee_discount_and_referral_share_for_amount_for_test(
        &referral_tiers,
        250
      );
    assert!(borrow_fee_discount == 15, 0);
    assert!(referral_share == 25, 1);

    let referral_ticket =
      scallop_referral_program::claim_ve_sca_referral_ticket_with_ve_sca_amount_for_test<SUI>(
        &version,
        &referral_bindings,
        &authorized_witness_list,
        &referral_tiers,
        250,
        ctx
      );

    assert!(borrow_referral::borrow_fee_discount(&referral_ticket) == 15, 2);
    assert!(borrow_referral::referral_share(&referral_ticket) == 25, 3);
    assert!(borrow_referral::borrowed(&referral_ticket) == 0, 4);

    scallop_referral_program::burn_ve_sca_referral_ticket_for_test<SUI>(
      &version,
      referral_ticket,
      &mut referral_revenue_pool,
      BORROWER,
      123,
      ctx
    );

    let claimed = referral_revenue_pool::claim_revenue_for_test<SUI>(&mut referral_revenue_pool, ve_sca_key_id, ctx);
    assert!(coin::value(&claimed) == 0, 5);
    coin::burn_for_testing(claimed);

    test_scenario::return_shared(authorized_witness_list);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(ADMIN, admin_cap);
    test_utils::destroy(referral_revenue_pool);
    test_utils::destroy(referral_bindings);
    test_utils::destroy(referral_tiers);
    test_utils::destroy(version);
    test_scenario::end(scenario_value);
  }

  #[test]
  #[expected_failure(abort_code = 503, location = scallop_referral_program::scallop_referral_program)]
  fun test_claim_referral_ticket_without_binding_fails() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;

    let version = version::create_for_test(test_scenario::ctx(scenario));
    let referral_tiers = referral_tiers::create_for_test(test_scenario::ctx(scenario));
    let referral_bindings = referral_bindings::create_for_test(test_scenario::ctx(scenario));

    referral_tiers::add_tier_for_test(&mut referral_tiers, 0, 10, 5);

    let (market, admin_cap) = app_t::app_init(scenario);
    borrow_referral::init_test(test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, ADMIN);
    let authorized_witness_list = test_scenario::take_shared<AuthorizedWitnessList>(scenario);
    scallop_referral_program::authorize_referral_witness_for_test(&admin_cap, &mut authorized_witness_list);

    test_scenario::next_tx(scenario, BORROWER);
    let referral_ticket =
      scallop_referral_program::claim_ve_sca_referral_ticket_with_ve_sca_amount_for_test<SUI>(
      &version,
      &referral_bindings,
      &authorized_witness_list,
      &referral_tiers,
      100,
      test_scenario::ctx(scenario)
      );
    let referral_revenue_pool = referral_revenue_pool::create_for_test(test_scenario::ctx(scenario));
    scallop_referral_program::burn_ve_sca_referral_ticket_for_test<SUI>(
      &version,
      referral_ticket,
      &mut referral_revenue_pool,
      BORROWER,
      0,
      test_scenario::ctx(scenario)
    );

    test_scenario::return_shared(authorized_witness_list);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(ADMIN, admin_cap);
    test_utils::destroy(referral_revenue_pool);
    test_utils::destroy(referral_bindings);
    test_utils::destroy(referral_tiers);
    test_utils::destroy(version);
    test_scenario::end(scenario_value);
  }

  #[test]
  #[expected_failure(abort_code = 711, location = protocol::borrow_referral)]
  fun test_claim_referral_ticket_without_authorized_witness_fails() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;

    let version = version::create_for_test(test_scenario::ctx(scenario));
    let referral_tiers = referral_tiers::create_for_test(test_scenario::ctx(scenario));
    let referral_bindings = referral_bindings::create_for_test(test_scenario::ctx(scenario));

    referral_tiers::add_tier_for_test(&mut referral_tiers, 0, 10, 5);

    let (market, admin_cap) = app_t::app_init(scenario);
    borrow_referral::init_test(test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, ADMIN);
    let authorized_witness_list = test_scenario::take_shared<AuthorizedWitnessList>(scenario);

    test_scenario::next_tx(scenario, BORROWER);
    referral_bindings::bind_for_test(
      &mut referral_bindings,
      object::id_from_address(@0x5002),
      test_scenario::ctx(scenario)
    );

    let referral_ticket =
      scallop_referral_program::claim_ve_sca_referral_ticket_with_ve_sca_amount_for_test<SUI>(
      &version,
      &referral_bindings,
      &authorized_witness_list,
      &referral_tiers,
      100,
      test_scenario::ctx(scenario)
      );
    let referral_revenue_pool = referral_revenue_pool::create_for_test(test_scenario::ctx(scenario));
    scallop_referral_program::burn_ve_sca_referral_ticket_for_test<SUI>(
      &version,
      referral_ticket,
      &mut referral_revenue_pool,
      BORROWER,
      0,
      test_scenario::ctx(scenario)
    );

    test_scenario::return_shared(authorized_witness_list);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(ADMIN, admin_cap);
    test_utils::destroy(referral_revenue_pool);
    test_utils::destroy(referral_bindings);
    test_utils::destroy(referral_tiers);
    test_utils::destroy(version);
    test_scenario::end(scenario_value);
  }
}
