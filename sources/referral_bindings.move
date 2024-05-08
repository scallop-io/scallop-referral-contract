/// @title This module manages the the mapping of referrers and referees
/// @author Scallop Labs
/// @notice Once an user address is binded to a referrer, it cannot be unbind.
module scallop_referral_program::referral_bindings {
  use std::option::{Self, Option};
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::clock::Clock;
  use sui::transfer;

  use ve_sca::ve_sca::{Self, VeScaTable};

  const ERefereeAlreadyBinded: u64 = 405;

  // This stores the bindings between the referrer and the referee's address.
  // The referee's address is binded to a specific veSCA key id
  struct ReferralBindings has key {
    id: UID,
    ve_sca_binding: Table<address, ID>,
  }

  fun init(ctx: &mut TxContext) {
    let bindings = ReferralBindings {
      id: object::new(ctx),
      ve_sca_binding: table::new(ctx),
    };
    transfer::share_object(bindings);
  }

  /// @notice This function bind the referee's address to a specific veSCA of the referrer, abort if the referee's address has been binded.
  /// @dev This function is meant to be called by the referee to accept the referral.
  /// @param ve_sca_key_id The veSCA of the referrer.
  /// @param ve_sca_table The veSCA table from the veSCA contract.
  /// @param ctx The transaction context.
  public fun bind_ve_sca_referrer(
    referral_bindings: &mut ReferralBindings,
    ve_sca_key_id: ID,
    ve_sca_table: &VeScaTable,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    // Make sure the referee's address has not been binded.
    assert!(has_ve_sca_binding(referral_bindings, sender) == false, ERefereeAlreadyBinded);

    // Make sure the veSCA key id is valid by checking the veSCA amount
    ve_sca::ve_sca_amount(ve_sca_key_id, ve_sca_table, clock);

    // Insert the binding.
    table::add(&mut referral_bindings.ve_sca_binding, sender, ve_sca_key_id);
  }

  /// @notice Check if the referee's address has been binded to a referrer.
  /// @param referral_bindings The referral bindings object.
  /// @param referee_address The referee's address.
  /// @return True if the referee's address has been binded to a referrer.
  public fun has_ve_sca_binding(
    referral_bindings: &ReferralBindings,
    referee_address: address
  ): bool {
    table::contains(&referral_bindings.ve_sca_binding, referee_address)
  }

  /// @notice Check if the referee's address is binded to the given veSCA.
  /// @param This is used within the contract to make sure the referee can only use the binded veSCA to issue the referral ticket.
  /// @param referral_bindings The referral bindings object.
  /// @param ve_sca_key_id The veSCA of the referrer.
  /// @param referee_address The referee's address.
  /// @return True if the referee's address is binded to the given veSCA.
  public fun is_binded_to_the_given_referrer_ve_sca(
    referral_bindings: &ReferralBindings,
    ve_sca_key_id: ID,
    referee_address: address
  ): bool {
    if (table::contains(&referral_bindings.ve_sca_binding, referee_address)) {
      let binded_ve_sca_key_id = *table::borrow(&referral_bindings.ve_sca_binding, referee_address);
      binded_ve_sca_key_id == ve_sca_key_id
    } else {
      return false
    }
  }

  /// @notice Get the binding of the referee's address.
  /// @dev This is used to check the binding of the referee's address.
  /// @param referral_bindings The referral bindings object.
  /// @param referee_address The referee's address.
  /// @return The veSCA id if any
  public fun get_binding(
    referral_bindings: &ReferralBindings,
    referee_address: address
  ): Option<ID> {
    let binded_ve_sca = if (table::contains(&referral_bindings.ve_sca_binding, referee_address)) {
      let ve_sca_key_id = *table::borrow(&referral_bindings.ve_sca_binding, referee_address);
      option::some(ve_sca_key_id)
    } else {
      option::none()
    };
    binded_ve_sca
  }
}
