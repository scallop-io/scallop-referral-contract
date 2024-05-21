/// @title Referral tiers based on the amount of VE_SCA of the referrer.
/// @author Scallop Labs
/// @notice This module defines referral tiers based on the amount of VE_SCA of the referrer.
module scallop_referral_program::referral_tiers {

  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer;

  use scallop_referral_program::asc_u64_sorted_list::{Self, AscU64SortedList};

  friend scallop_referral_program::admin;

  const ERROR_TIER_EXISTS: u64 = 601;
  const ERROR_TIER_NOT_EXISTS: u64 = 602;

  struct TierData has copy, store, drop {
    referral_share: u64, // base 100, 40 means 40%
    borrow_fee_discount: u64, // base 100, 10 means 10%
  }

  struct ReferralTiers has key {
    id: UID,
    tier_table: Table<u64, TierData>,
    ve_sca_tiers: AscU64SortedList,
  }

  fun init(ctx: &mut TxContext) {
    let referral_tiers = ReferralTiers {
      id: object::new(ctx),
      tier_table: table::new(ctx),
      ve_sca_tiers: asc_u64_sorted_list::empty(),
    };
    transfer::share_object(referral_tiers);
  }

  /// @notice Add a new tier to the referral program.
  /// @dev If the tier already exists, it will abort. For update, remove the tier and add it again.
  /// @param referral_tiers The referral tiers object.
  /// @param ve_sca_amount The amount of VE_SCA required to reach this tier.
  /// @param referral_share The referral share of this tier.
  /// @param borrow_fee_discount The borrow fee discount of this tier.
  public(friend) fun add_tier(
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64,
    referral_share: u64,
    borrow_fee_discount: u64,
  ) {
    // Make sure the tier does not exist.
    assert!(table::contains(&referral_tiers.tier_table, ve_sca_amount) == false, ERROR_TIER_EXISTS);
    let tier_data = TierData {
      referral_share,
      borrow_fee_discount,
    };
    // Inser the tier data.
    table::add(&mut referral_tiers.tier_table, ve_sca_amount, tier_data);
    // Insert the tier into the sorted tier list.
    asc_u64_sorted_list::insert(&mut referral_tiers.ve_sca_tiers, ve_sca_amount);
  }

  /// @notice Remove a tier from the referral program.
  /// @dev If the tier does not exist, it will abort.
  /// @param referral_tiers The referral tiers object.
  /// @param ve_sca_amount The amount of VE_SCA required to reach this tier.
  /// @return The referral share and borrow fee discount of the removed tier.
  public(friend) fun remove_tier(
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64
  ): (u64, u64) {
    // Make sure the tier exists.
    assert!(table::contains(&referral_tiers.tier_table, ve_sca_amount), ERROR_TIER_NOT_EXISTS);
    // Remove the tier data.
    let tier_data = table::remove(&mut referral_tiers.tier_table, ve_sca_amount);
    // Remove the tier from the sorted tier list.
    asc_u64_sorted_list::remove(&mut referral_tiers.ve_sca_tiers, ve_sca_amount);
    // Return the tier data.
    (tier_data.referral_share, tier_data.borrow_fee_discount)
  }

  /// @notice Find the tier of the referrer based on the amount of VE_SCA.
  /// @dev This will return the tier data that's closest to the given amount of VE_SCA.
  /// @param referral_tiers The referral tiers object.
  /// @param ve_sca_amount The amount of VE_SCA of the referrer.
  /// @return The referral share and borrow fee discount of the tier.
  public fun find_tier(
    referral_tiers: &ReferralTiers,
    ve_sca_amount: u64
  ): (u64, u64) {
    // Find the closest tier.
    let ve_sca_tier = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&referral_tiers.ve_sca_tiers, ve_sca_amount);
    // Get the tier data.
    let tier_data = table::borrow(&referral_tiers.tier_table, ve_sca_tier);
    (tier_data.referral_share, tier_data.borrow_fee_discount)
  }

  // ============== Test Only Functions ==============
  #[test_only]
  public fun create_for_test(ctx: &mut TxContext): ReferralTiers {
    let referral_tiers = ReferralTiers {
      id: object::new(ctx),
      tier_table: table::new(ctx),
      ve_sca_tiers: asc_u64_sorted_list::empty(),
    };
    referral_tiers
  }

  #[test_only]
  public fun add_tier_for_test(
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64,
    referral_share: u64,
    borrow_fee_discount: u64,
  ) {
    add_tier(referral_tiers, ve_sca_amount, referral_share, borrow_fee_discount);
  }
}
