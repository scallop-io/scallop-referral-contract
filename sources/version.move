module scallop_referral_program::version {

  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer;

  friend scallop_referral_program::admin;

  const CURRENT_VERSION: u64 = 0;

  const ERROR_VERSION_CAN_ONLY_INCREASE: u64 = 701;
  const ERROR_VERSION_MISMATCH: u64 = 702;

  struct Version has key {
    id: UID,
    value: u64,
  }

  fun init(ctx: &mut TxContext) {
    let version = Version {
      id: object::new(ctx),
      value: CURRENT_VERSION,
    };
    transfer::share_object(version);
  }

  public(friend) fun set_version(version: &mut Version, new_version: u64) {
    assert!(new_version > version.value, ERROR_VERSION_CAN_ONLY_INCREASE);
    version.value = new_version;
  }

  public fun assert_verion(version: &Version) {
    assert!(version.value == CURRENT_VERSION, ERROR_VERSION_MISMATCH);
  }
}
