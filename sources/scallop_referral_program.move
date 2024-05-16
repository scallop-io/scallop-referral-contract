/// @title Referral program for Scallop.
/// @author Scallop Labs
/// @notice Referral with veSCA will enjoy a higher reward according to the veSCA's amount.
module scallop_referral_program::scallop_referral_program {

  use std::option;
  use std::type_name::{Self, TypeName};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::object::ID;
  use sui::balance;
  use sui::event;

  use protocol::borrow_referral::{Self, AuthorizedWitnessList, BorrowReferral};
  use ve_sca::ve_sca::{Self, VeScaTable};

  use scallop_referral_program::referral_bindings::{Self, ReferralBindings};
  use scallop_referral_program::referral_revenue_pool::{Self, ReferralRevenuePool};
  use scallop_referral_program::referral_tiers::{Self, ReferralTiers};
  use scallop_referral_program::version::{Self, Version};


  const ENotReferralBinding: u64 = 503;

  // This is the witness for the Scallop referral program.
  // It should be authorized by the Scallop protocol contract.
  struct REFERRAL_WITNESS has drop {}

  struct VeScaReferralCfg has store, drop {
    ve_sca_key_id: ID,
  }

  // ================== Events ==================
  struct BorrowReferralEvent has copy, drop {
    coin_type: TypeName,
    borrower: address,
    referrer_ve_sca_key_id: ID,
    borrowed: u64,
    borrow_fee_discount: u64,
    referral_share: u64,
    referral_fee: u64,
    timestamp: u64,
  }

  // ================== For veSCA referral ==================

  /// @notice Claim a referral ticket for a borrower based on the the referrer's veSCA.
  /// @dev This function will abort if the borrower has no referral information.
  /// @param version The version of the protocol contract.
  /// @param authorized_witness_list The authorized witness list from the protocol contract.
  /// @param clock The clock.
  /// @param ctx The transaction context.
  /// @return The referral ticket, which should be passed to the borrow function of the protocol contract.
  public fun claim_ve_sca_referral_ticket<CoinType>(
    version: &Version,
    ve_sca_table: &VeScaTable,
    referral_bindings: &ReferralBindings,
    authorized_witness_list: &AuthorizedWitnessList,
    referral_tiers: &ReferralTiers,
    clock: &Clock,
    ctx: &mut TxContext
  ): BorrowReferral<CoinType, REFERRAL_WITNESS> {
    // Make sure the version is correct.
    version::assert_verion(version);

    let sender = tx_context::sender(ctx);

    // Make sure there is a binded ve sca key
    let optional_ve_sca_key_id = referral_bindings::get_binding(referral_bindings, sender);
    assert!(option::is_some(&optional_ve_sca_key_id), ENotReferralBinding);

    // Calculate the borrow fee discount and referral share based on the veSCA.
    let ve_sca_key_id = option::destroy_some(optional_ve_sca_key_id);
    let (borrow_fee_discount, referral_share) = calc_borrow_fee_discount_and_referral_share_based_on_ve_sca(
      ve_sca_key_id,
      ve_sca_table,
      referral_tiers,
      clock
    );

    // Create the borrow referral ticket.
    let referral_ticket = borrow_referral::create_borrow_referral<CoinType, REFERRAL_WITNESS>(
      REFERRAL_WITNESS {},
      authorized_witness_list,
      borrow_fee_discount,
      referral_share,
      ctx
    );

    // Attach the veSCA information to the referral ticket.
    borrow_referral::add_referral_cfg(
      &mut referral_ticket,
      VeScaReferralCfg { ve_sca_key_id }
    );

    // Return the referral ticket.
    referral_ticket
  }

  /// @notice Burn a veSCA referral ticket after the borrower has finished borrowing,
  ///         put the referral revenue into the reward pool, and increase the reward amount for the referrer.
  /// @param version The version of the protocol contract.
  /// @param referral_ticket The referral ticket to burn.
  /// @param ctx The transaction context.
  public fun burn_ve_sca_referral_ticket<CoinType>(
    version: &Version,
    referral_ticket: BorrowReferral<CoinType, REFERRAL_WITNESS>,
    referral_revenue_pool: &mut ReferralRevenuePool,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    // Make sure the version is correct.
    version::assert_verion(version);

    // Get the information from the referral ticket.
    let ve_sca_cfg = borrow_referral::get_referral_cfg<CoinType, REFERRAL_WITNESS, VeScaReferralCfg>(&referral_ticket);
    let ve_sca_key_id = ve_sca_cfg.ve_sca_key_id;
    let coin_type = type_name::get<CoinType>();
    let borrowed = borrow_referral::borrowed(&referral_ticket);
    let borrow_fee_discount = borrow_referral::borrow_fee_discount(&referral_ticket);
    let referral_share = borrow_referral::referral_share(&referral_ticket);

    // Destroy the referral ticket, and get the referral revenue.
    let referral_revenue = borrow_referral::destroy_borrow_referral<CoinType, REFERRAL_WITNESS>(
      REFERRAL_WITNESS {},
      referral_ticket,
    );

    // Emit the BorrowReferralEvent.
    event::emit(BorrowReferralEvent {
      coin_type,
      borrower: tx_context::sender(ctx),
      referrer_ve_sca_key_id: ve_sca_key_id,
      borrowed,
      borrow_fee_discount,
      referral_share,
      referral_fee: balance::value(&referral_revenue),
      timestamp: clock::timestamp_ms(clock) / 1000
    });

    // Add the referral revenue to the referrer.
    referral_revenue_pool::add_revenue_to_ve_sca_referrer(
      referral_revenue_pool,
      ve_sca_key_id,
      referral_revenue,
      ctx
    );
  }

  /// @notice Calculate the borrow fee discount & revenue share for referrer
  /// @ve_sca_key_id The object id for referrer's veSCA key
  /// @ve_sca_table The table that contains the veSCA info for all veSCA holders
  /// @referral_tiers The referral tiers
  /// @clock The system clock object
  /// @return The (BorrowFee discount, Referrer's revenue share)
  public fun calc_borrow_fee_discount_and_referral_share_based_on_ve_sca(
    ve_sca_key_id: ID,
    ve_sca_table: &VeScaTable,
    referral_tiers: &ReferralTiers,
    clock: &Clock
  ): (u64, u64) {
    let ve_sca_amount = ve_sca::ve_sca_amount(ve_sca_key_id, ve_sca_table, clock);
    let (referral_share, borrow_fee_discount) = referral_tiers::find_tier(referral_tiers, ve_sca_amount);
    (borrow_fee_discount, referral_share)
  }
}
