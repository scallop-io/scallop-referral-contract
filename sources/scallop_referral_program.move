/// @title Referral program for Scallop.
/// @author Scallop Labs
/// @notice There're 2 kinds of referral. Referral with veSCA and referral with address.
///         Referral with veSCA will enjoy a higher reward according to the veSCA's amount.
///         Referral with address get the lowest tier reward.
module scallop_referral_program::scallop_referral_program {

  use std::option;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use sui::clock::Clock;

  use protocol::borrow_referral::{Self, AuthorizedWitnessList, BorrowReferral};
  use ve_sca::ve_sca::{Self, VeScaKey, VeScaTable};

  use scallop_referral_program::referral_bindings::{Self, ReferralBindings};
  use scallop_referral_program::referral_revenue_pool::{Self, ReferralRevenuePool};

  const EWrongVeSca: u64 = 503;
  const ENotBindedToReferrerAddress: u64 = 504;

  // This is the witness for the Scallop referral program.
  // It should be authorized by the Scallop protocol contract.
  struct REFERRAL_WITNESS has drop {}

  struct VeScaReferralCfg has store, drop {
    ve_sca_key_id: ID,
  }

  struct AddressReferralCfg has store, drop {
    referrer_address: address,
  }

  // ================== For veSCA referral ==================

  /// @notice Claim a referral ticket for a borrower based on the the referrer's veSCA.
  /// @dev This function will abort if the borrower has no referral information.
  /// @param ve_sca The veSCA of the referrer.
  /// @param authorized_witness_list The authorized witness list from the protocol contract.
  /// @param clock The clock.
  /// @param ctx The transaction context.
  /// @return The referral ticket, which should be passed to the borrow function of the protocol contract.
  public fun claim_ve_sca_referral_ticket<CoinType>(
    ve_sca_key: &VeScaKey,
    ve_sca_table: &VeScaTable,
    referral_bindings: &ReferralBindings,
    authorized_witness_list: &AuthorizedWitnessList,
    clock: &Clock,
    ctx: &mut TxContext
  ): BorrowReferral<CoinType, REFERRAL_WITNESS> {
    // Make sure the veSCA is the same as the borrower's referral veSCA.
    let sender = tx_context::sender(ctx);
    let is_binded_ve_sca = referral_bindings::is_binded_to_the_given_referrer_ve_sca(
      referral_bindings,
      object::id(ve_sca_key),
      sender
    );
    assert!(is_binded_ve_sca, EWrongVeSca);

    // Calculate the borrow fee discount and referral share based on the veSCA.
    let (borrow_fee_discount, referral_share) = calc_borrow_fee_discount_and_referral_share_based_on_ve_sca(
      object::id(ve_sca_key),
      ve_sca_table,
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
      VeScaReferralCfg { ve_sca_key_id: object::id(ve_sca_key) }
    );

    // Return the referral ticket.
    referral_ticket
  }

  /// @notice Burn a veSCA referral ticket after the borrower has finished borrowing,
  ///         put the referral revenue into the reward pool, and increase the reward amount for the referrer.
  /// @param referral_ticket The referral ticket to burn.
  /// @param ctx The transaction context.
  public fun burn_ve_sca_referral_ticket<CoinType>(
    referral_ticket: BorrowReferral<CoinType, REFERRAL_WITNESS>,
    referral_revenue_pool: &mut ReferralRevenuePool,
    ctx: &mut TxContext
  ) {
    // Get the veSCA information from the referral ticket.
    let ve_sca_cfg = borrow_referral::get_referral_cfg<CoinType, REFERRAL_WITNESS, VeScaReferralCfg>(&referral_ticket);
    let ve_sca_key_id = ve_sca_cfg.ve_sca_key_id;
    // Destroy the referral ticket, and get the referral revenue.
    let referral_revenue = borrow_referral::destroy_borrow_referral<CoinType, REFERRAL_WITNESS>(
      REFERRAL_WITNESS {},
      referral_ticket,
    );

    // Add the referral revenue to the referrer.
    referral_revenue_pool::add_revenue_to_ve_sca_referrer(
      referral_revenue_pool,
      ve_sca_key_id,
      referral_revenue,
      ctx
    );
  }

  /// TODO: Discuss the tier of the veSCA amount.
  public fun calc_borrow_fee_discount_and_referral_share_based_on_ve_sca(
    ve_sca_key_id: ID,
    ve_sca_table: &VeScaTable,
    clock: &Clock
  ): (u64, u64) {
    let ve_sca_amount = ve_sca::ve_sca_amount(ve_sca_key_id, ve_sca_table, clock);
    if (ve_sca_amount >= 1_000_000) {
      return (10, 50)
    } else if (ve_sca_amount >= 100_000) {
      return (10, 35)
    } else if (ve_sca_amount >= 10_000) {
      return (10, 20)
    } else if (ve_sca_amount >= 1000) {
      return (10, 15)
    } else {
      return (10, 10)
    }
  }

  // ================== For address referral ==================

  /// @notice Claim a referral ticket for a borrower based on the the referrer's address.
  /// @dev This function will abort if the borrower has no referral information.
  /// @param referrer The address of the referrer.
  /// @param authorized_witness_list The authorized witness list from the protocol contract.
  /// @param ctx The transaction context.
  /// @return The referral ticket, which should be passed to the borrow function of the protocol contract.
  public fun claim_address_referral_ticket<CoinType>(
    referral_bindings: &ReferralBindings,
    authorized_witness_list: &AuthorizedWitnessList,
    ctx: &mut TxContext
  ): BorrowReferral<CoinType, REFERRAL_WITNESS> {
    // Make sure the the borrower has binded to a referrer address.
    let sender = tx_context::sender(ctx);
    let (_, referrer_address_option) = referral_bindings::get_binding(referral_bindings, sender);
    assert!(option::is_some(&referrer_address_option), ENotBindedToReferrerAddress);

    let referrer_address = option::destroy_some<address>(referrer_address_option);

    // TODO: discuss the borrow_fee_discount and referral_share for the address referral.
    let borrow_fee_discount = 10;
    let referral_share = 10;

    // Create the borrow referral ticket.
    let referral_ticket = borrow_referral::create_borrow_referral<CoinType, REFERRAL_WITNESS>(
      REFERRAL_WITNESS {},
      authorized_witness_list,
      borrow_fee_discount,
      referral_share,
      ctx
    );

    // Attach the address information to the referral ticket.
    borrow_referral::add_referral_cfg(
      &mut referral_ticket,
      AddressReferralCfg { referrer_address }
    );

    // Return the referral ticket.
    referral_ticket
  }

  /// @notice Burn a address referral ticket after the borrower has finished borrowing,
  ///        put the referral revenue into the reward pool, and increase the reward amount for the referrer.
  /// @param referral_ticket The referral ticket to burn.
  /// @param ctx The transaction context.
  /// @return The referral revenue.
  public fun burn_address_referral_ticket<CoinType>(
    referral_ticket: BorrowReferral<CoinType, REFERRAL_WITNESS>,
    referral_revenue_pool: &mut ReferralRevenuePool,
    ctx: &mut TxContext
  ) {
    // Get the address information from the referral ticket.
    let address_cfg = borrow_referral::get_referral_cfg<CoinType, REFERRAL_WITNESS, AddressReferralCfg>(&referral_ticket);
    let referrer_address = address_cfg.referrer_address;
    // Destroy the referral ticket, and get the referral revenue.
    let referral_revenue = borrow_referral::destroy_borrow_referral<CoinType, REFERRAL_WITNESS>(
      REFERRAL_WITNESS {},
      referral_ticket,
    );

    // Add the referral revenue to the referrer.
    referral_revenue_pool::add_revenue_to_address_referrer(
      referral_revenue_pool,
      referrer_address,
      referral_revenue,
      ctx
    );
  }
}
