/// @title This module manages the referral revenue pool. Referrer will be able to claim the reward from this pool.
/// @author Scallop Labs
/// @notice Referrer will either claim with their veSCA key or their account address.
module scallop_referral_program::referral_revenue_pool {

  use std::type_name::{Self, TypeName};
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::bag::{Self, Bag};
  use sui::coin::{Self, Coin};
  use sui::transfer;
  use sui::tx_context::TxContext;

  use ve_sca::ve_sca::VeScaKey;

  use x::balance_bag::{Self, BalanceBag};

  friend scallop_referral_program::scallop_referral_program;

  struct RevenueData has key, store {
    id: UID,
    bag: Bag,
  }

  // This struct is used to store the referral revenue & the claimable reward amount for referrer.
  struct ReferralRevenuePool has key {
    id: UID,
    revenue: BalanceBag,
    ve_sca_revenue_data: Table<ID, RevenueData>,
  }

  /// @notice Initialize the referral revenue pool, make sure only one instance of the pool is created.
  /// @param ctx The transaction context.
  fun init(ctx: &mut TxContext) {
    let revenue_pool = ReferralRevenuePool {
      id: object::new(ctx),
      revenue: balance_bag::new(ctx),
      ve_sca_revenue_data: table::new(ctx),
    };
    transfer::share_object(revenue_pool)
  }

  /// @notice Claim the revenue with veSCA key, always claim all the revenue for the CoinType.
  /// @dev This is meant to be called by the referrer with veSCA
  /// @param referral_revenue_pool The referral revenue pool.
  /// @param ve_sca_key The veSCA key of the referrer.
  /// @param ctx The transaction context.
  /// @return The claimed revenue, if the referrer does not exist, it will return 0 balance coin.
  public fun claim_revenue_with_ve_sca_key<CoinType>(
    referral_revenue_pool: &mut ReferralRevenuePool,
    ve_sca_key: &VeScaKey,
    ctx: &mut TxContext
  ): Coin<CoinType> {
    let ve_sca_key_id = object::id(ve_sca_key);
    // If the referrer does not exist, return 0 balance coin.
    if (!table::contains(&referral_revenue_pool.ve_sca_revenue_data, ve_sca_key_id)) {
      coin::zero(ctx)
    } else {
      // Get the available revenue amount for the referrer.
      let coin_type = type_name::get<CoinType>();
      let revenue_data = table::borrow_mut(&mut referral_revenue_pool.ve_sca_revenue_data, ve_sca_key_id);
      let revenue_amount = revenue_amount(revenue_data, coin_type);

      // Take the revenue from the revenue pool.
      let revenue_balance = balance_bag::split<CoinType>(&mut referral_revenue_pool.revenue, revenue_amount);

      // Decrease the revenue amount for the referrer.
      decrease_revenue_data(revenue_data, coin_type, revenue_amount);

      // Return the claimed revenue.
      coin::from_balance(revenue_balance, ctx)
    }
  }

  /// @notice Add revenue to the veSCA referrer
  /// @param referral_revenue_pool The referral revenue pool.
  /// @param ve_sca_key_id The veSCA ID of the referrer.
  /// @param balance The balance to add.
  /// @param ctx The transaction context.
  public(friend) fun add_revenue_to_ve_sca_referrer<CoinType>(
    referral_revenue_pool: &mut ReferralRevenuePool,
    ve_sca_key_id: ID,
    balance: Balance<CoinType>,
    ctx: &mut TxContext
  ) {
    // Create the revenue data if it does not exist.
    if (!table::contains(&referral_revenue_pool.ve_sca_revenue_data, ve_sca_key_id)) {
      let revenue_data = RevenueData {
        id: object::new(ctx),
        bag: bag::new(ctx),
      };
      table::add(&mut referral_revenue_pool.ve_sca_revenue_data, ve_sca_key_id, revenue_data);
    };

    let coin_type = type_name::get<CoinType>();

    // Increase the revenue amount for the referrer.
    let revenue_data = table::borrow_mut(&mut referral_revenue_pool.ve_sca_revenue_data, ve_sca_key_id);
    increase_revenue_data(revenue_data, coin_type, balance::value(&balance));

    // Init the CoinType for the revenue bag if it does not exist.
    if (!balance_bag::contains<CoinType>(&referral_revenue_pool.revenue)) {
      balance_bag::init_balance<CoinType>(&mut referral_revenue_pool.revenue);
    };

    // Put the revenue into the revenue pool.
    balance_bag::join(&mut referral_revenue_pool.revenue, balance);
  }

  /// @notice Increase the revenue amount for a specific referrer's reward amount.
  /// @param revenue_data The revenue data for the referrer.
  /// @param coin_type The coin type of the revenue.
  /// @param amount The amount to increase.
  fun increase_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount + amount;
    } else {
      bag::add(&mut revenue_data.bag, coin_type, amount);
    };
  }

  /// @notice Decrease the revenue amount for a specific referrer's reward amount.
  /// @param revenue_data The revenue data for the referrer.
  /// @param coin_type The coin type of the revenue.
  /// @param amount The amount to decrease.
  fun decrease_revenue_data(revenue_data: &mut RevenueData, coin_type: TypeName, amount: u64) {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      let current_amount = bag::borrow_mut<TypeName, u64>(&mut revenue_data.bag, coin_type);
      *current_amount = *current_amount - amount;
    } else {
      abort 0
    }
  }

  /// @notice Get the revenue amount for a specific referrer's reward amount.
  /// @param revenue_data The revenue data for the referrer.
  /// @param coin_type The coin type of the revenue.
  /// @return The revenue amount.
  fun revenue_amount(revenue_data: &RevenueData, coin_type: TypeName): u64 {
    if (bag::contains(&revenue_data.bag, coin_type)) {
      *bag::borrow<TypeName, u64>(&revenue_data.bag, coin_type)
    } else {
      0
    }
  }
}
