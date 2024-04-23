module scallop_referral_program::referral_bindings {
  use std::option::{Self, Option};
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::clock::Clock;

  use sui::transfer;
  use ve_sca::ve_sca::{Self, VeScaTable};

  const ERefereeAlreadyBinded: u64 = 405;
  const EReferrerVeScaAmountIsZero: u64 = 406;

  // This stores the bindings between the referrer and the referee's address.
  // There're 2 kinds of bindings:
  // 1. The referrer's veSCA id and the referee's address.
  // 2. The referrer's address and the referee's address.
  struct ReferralBindings has key {
    id: UID,
    ve_sca_binding: Table<address, ID>,
    address_binding: Table<address, address>,
  }

  fun init(ctx: &mut TxContext) {
    let bindings = ReferralBindings {
      id: object::new(ctx),
      ve_sca_binding: table::new(ctx),
      address_binding: table::new(ctx),
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
    assert!(has_binding(referral_bindings, sender) == false, ERefereeAlreadyBinded);

    // Make sure referrer's veSCA amount is not zero.
    let ve_sca_amount = ve_sca::ve_sca_amount(ve_sca_key_id, ve_sca_table, clock);
    assert!(ve_sca_amount > 0, EReferrerVeScaAmountIsZero);

    // Insert the binding.
    table::add(&mut referral_bindings.ve_sca_binding, sender, ve_sca_key_id);
  }

  /// @notice This function bind the referee's address to a specific address of the referrer, abort if the referee's address has been binded.
  /// @dev This function is meant to be called by the referee to accept the referral.
  /// @param referral_bindings The referral bindings object.
  /// @param referrer_address The referrer's address.
  /// @param ctx The transaction context.
  public fun bind_address_referrer(
    referral_bindings: &mut ReferralBindings,
    referrer_address: address,
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    // Make sure the referee's address has not been binded.
    assert!(has_binding(referral_bindings, sender) == false, ERefereeAlreadyBinded);
    // Insert the binding.
    table::add(&mut referral_bindings.address_binding, sender, referrer_address);
  }

  /// @notice Check if the referee's address has been binded to a referrer.
  /// @param referral_bindings The referral bindings object.
  /// @param referee_address The referee's address.
  /// @return True if the referee's address has been binded to a referrer.
  public fun has_binding(
    referral_bindings: &ReferralBindings,
    referee_address: address
  ): bool {
    table::contains(&referral_bindings.ve_sca_binding, referee_address) ||
      table::contains(&referral_bindings.address_binding, referee_address)
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

  /// @notice Check if the referee's address is binded to the given referrer's address.
  /// @param This is used within the contract to make sure the referee can only use the binded address to issue the referral ticket.
  /// @param referral_bindings The referral bindings object.
  /// @param referrer_address The referrer's address.
  /// @param referee_address The referee's address.
  /// @return True if the referee's address is binded to the given referrer's address.
  public fun is_binded_to_the_given_referrer_address(
    referral_bindings: &ReferralBindings,
    referrer_address: address,
    referee_address: address
  ): bool {
    if (table::contains(&referral_bindings.address_binding, referee_address)) {
      let binded_address = *table::borrow(&referral_bindings.address_binding, referee_address);
      binded_address == referrer_address
    } else {
      return false
    }
  }


  /// @notice Get the binding of the referee's address.
  /// @dev This is used on client side to check the binding of the referee's address.
  /// @param referral_bindings The referral bindings object.
  /// @param referee_address The referee's address.
  /// @return The veSCA id and the referrer's address. At most one of them is not none. If both are none, the referee's address is not binded.
  public fun get_binding(
    referral_bindings: &ReferralBindings,
    referee_address: address
  ): (Option<ID>, Option<address>) {
    let binded_ve_sca = if (table::contains(&referral_bindings.ve_sca_binding, referee_address)) {
      let ve_sca_key_id = *table::borrow(&referral_bindings.ve_sca_binding, referee_address);
      option::some(ve_sca_key_id)
    } else {
      option::none()
    };
    let binded_address = if (table::contains(&referral_bindings.address_binding, referee_address)) {
      let referrer_address = *table::borrow(&referral_bindings.address_binding, referee_address);
      option::some(referrer_address)
    } else {
      option::none()
    };
    (binded_ve_sca, binded_address)
  }
}
