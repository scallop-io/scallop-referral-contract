/// @title Admin module for Scallop Referral Program
/// @author Scallop Labs
/// @notice Config referral tiers, manage contract versioning
module scallop_referral_program::admin {

  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use scallop_referral_program::referral_tiers::{Self, ReferralTiers};
  use scallop_referral_program::version::{Self, Version};

  struct AdminCap has key {
    id: UID
  }

  fun init(ctx: &mut TxContext) {
    let admin = AdminCap { id: object::new(ctx) };
    transfer::transfer(admin, tx_context::sender(ctx));
  }

  /// @notice Add a new referral tier
  /// @param admin: Admin object
  /// @param referral_tiers: Referral tiers object
  /// @param ve_sca_amount: Minimum amount of VE_SCA to be eligible for this tier
  /// @param referral_share: Percentage of the borrow fee to be shared with the referrer, base 100
  /// @param borrow_fee_discount: Percentage of the borrow fee to be discounted for the borrower, base 100
  public entry fun add_referral_tier(
    _: &AdminCap,
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64,
    referral_share: u64, // base 100
    borrow_fee_discount: u64, // base 100
  ) {
    referral_tiers::add_tier(referral_tiers, ve_sca_amount, referral_share, borrow_fee_discount)
  }

  /// @notice Remove a referral tier
  /// @param admin: Admin object
  /// @param referral_tiers: Referral tiers object
  /// @param ve_sca_amount: Minimum amount of VE_SCA to be eligible for this tier
  /// @return (u64, u64): (referral_share, borrow_fee_discount) of the removed tier
  public entry fun remove_referral_tier(
    _: &AdminCap,
    referral_tiers: &mut ReferralTiers,
    ve_sca_amount: u64
  ) {
    referral_tiers::remove_tier(referral_tiers, ve_sca_amount);
  }

  /// @notice Set the contract version after an upgrade
  /// @param admin: Admin object
  /// @param version: Version object
  /// @param new_contract_version: New contract version
  public entry fun set_contract_version(
    _: &AdminCap,
    version: &mut Version,
    new_contract_version: u64
  ) {
    version::set_version(version, new_contract_version);
  }
}
