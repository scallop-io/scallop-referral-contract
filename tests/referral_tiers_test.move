#[test_only]
module scallop_referral_program::referral_tiers_test {

  use sui::test_utils;
  use sui::test_scenario;
  use scallop_referral_program::referral_tiers;

  #[test]
  public fun referral_tiers_test() {
    let sender = @0xAD;
    let senario = test_scenario::begin(sender);
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
}

