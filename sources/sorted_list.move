/// @title This module provides a sorted list of u64 values in ascending order.
/// @author Scallop Labs
module scallop_referral_program::asc_u64_sorted_list {

  use std::vector;
  use sui::vec_set::{Self, VecSet};

  struct AscU64SortedList has copy, store, drop {
    list: vector<u64>,
    set: VecSet<u64>
  }

  /// @notice Creates an empty sorted list.
  /// @return An empty sorted list.
  public fun empty(): AscU64SortedList {
    AscU64SortedList { list: vector::empty(), set: vec_set::empty() }
  }

  /// @notice Inserts a value into the sorted list.
  /// @dev If the value is already in the sorted list, do nothing.
  /// @param sorted_list The sorted list to insert the value into.
  /// @param value The value to insert.
  public fun insert(sorted_list: &mut AscU64SortedList, value: u64) {
    // Make sure the value is not in the set before inserting it into the list.
    if (vec_set::contains(&sorted_list.set, &value)) {
      return
    } else {
      vec_set::insert(&mut sorted_list.set, value);
    };
    // Find the position to insert the value.
    let i = 0;
    let list_len = vector::length(&sorted_list.list);
    while (i < list_len) {
      let elment = *vector::borrow(&sorted_list.list, i);
      if (value < elment) {
        break
      };
      i = i + 1;
    };
    // Insert the value into the list.
    vector::insert(&mut sorted_list.list, value, i);
  }

  /// @notice Removes a value from the sorted list.
  /// @dev If the value is not in the sorted list, do nothing.
  /// @param sorted_list The sorted list to remove the value from.
  /// @param value The value to remove.
  public fun remove(sorted_list: &mut AscU64SortedList, value: u64) {
    // Make sure the value is in the set before removing it from the list.
    if (!vec_set::contains(&sorted_list.set, &value)) {
      return
    } else {
      vec_set::remove(&mut sorted_list.set, &value)
    };
    // Find the position to remove the value.
    let i = 0;
    let list_len = vector::length(&sorted_list.list);
    while (i < list_len) {
      let elment = *vector::borrow(&sorted_list.list, i);
      if (value == elment) {
        break
      };
      i = i + 1;
    };
    // Remove the value from the list.
    if (i < list_len) {
      vector::remove(&mut sorted_list.list, i);
    };
  }

  /// @notice Find the nearest smaller or value in the sorted list compared to the target value.
  /// @dev If the target value is smaller than the smallest value in the sorted list, return 0.
  /// @param sorted_list The sorted list to search.
  /// @param target_value The target value to search for.
  /// @return The nearest smaller or equal value in the sorted list compared to the target value.
  public fun find_nearest_smaller_or_equal_value(sorted_list: &AscU64SortedList, target_value: u64): u64 {
    let i = 0;
    let list_len = vector::length(&sorted_list.list);
    while (i < list_len) {
      let elment = *vector::borrow(&sorted_list.list, i);
      if (target_value < elment) {
        break
      };
      i = i + 1;
    };
    if (i == 0) {
      0
    } else {
      *vector::borrow(&sorted_list.list, i - 1)
    }
  }
}
