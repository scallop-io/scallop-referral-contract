/// @title This module provides a sorted list of u64 values in ascending order.
/// @author Scallop Labs
module scallop_referral_program::asc_u64_sorted_list {

  use std::vector;

  const NotFoundErr: u64 = 1;

  struct AscU64SortedList has copy, store, drop {
    list: vector<u64>,
  }

  public fun to_vector(sorted_list: &AscU64SortedList): vector<u64> { sorted_list.list }

  /// @notice Creates an empty sorted list.
  /// @return An empty sorted list.
  public fun empty(): AscU64SortedList {
    AscU64SortedList { list: vector::empty() }
  }

  /// @notice Inserts a value into the sorted list.
  /// @dev If the value is already in the sorted list, do nothing.
  /// @param sorted_list The sorted list to insert the value into.
  /// @param value The value to insert.
  public fun insert(sorted_list: &mut AscU64SortedList, value: u64) {
    let upper_bound_index = upper_bound(&sorted_list.list, value);
    // don't insert if duplicated
    if (upper_bound_index > 0 && *vector::borrow(&sorted_list.list, upper_bound_index - 1) == value) {
      return
    };

    vector::insert(&mut sorted_list.list, value, upper_bound_index);
  }

  /// @notice Removes a value from the sorted list.
  /// @dev If the value is not in the sorted list, do nothing.
  /// @param sorted_list The sorted list to remove the value from.
  /// @param value The value to remove.
  public fun remove(sorted_list: &mut AscU64SortedList, value: u64) {
    let upper_bound_index = upper_bound(&sorted_list.list, value);
    // only remove if the value is equal
    if (upper_bound_index > 0 && *vector::borrow(&sorted_list.list, upper_bound_index - 1) == value) {
      vector::remove(&mut sorted_list.list, upper_bound_index - 1);
    };
  }

  public fun find_nearest_smaller_or_equal_value(sorted_list: &AscU64SortedList, value: u64): u64 {
    let upper_bound_index = upper_bound(&sorted_list.list, value);
    assert!(upper_bound_index > 0, NotFoundErr);
    *vector::borrow(&sorted_list.list, upper_bound_index - 1)
  }

  /// @notice find an upper bound of a value in a list
  /// @dev the list need to be sorted
  /// @param sorted_list The sorted list.
  /// @param target The value in search.
  /// @return an index of the upper_bound
  public fun upper_bound(sorted_list: &vector<u64>, target: u64): u64 {
    let low = (0 as u64);
    let high = (vector::length(sorted_list) as u64);

    // binary search
    while (low < high) {
      let mid = low + (high - low) / 2;
      if (target >= *vector::borrow(sorted_list, mid)) {
        low = mid + 1;
      } else {
        high = mid;
      };
    };

    if (low < vector::length(sorted_list) && *vector::borrow(sorted_list, low) <= target) {
      low = low + 1;
    };

    low
  }

  #[test]
  fun upper_bound_test() {
    let vect = vector<u64>[1, 1, 5, 5, 10, 100];
    assert!(upper_bound(&vect, 1000) == 6, 1);
    assert!(upper_bound(&vect, 101) == 6, 1);
    assert!(upper_bound(&vect, 100) == 6, 1);
    assert!(upper_bound(&vect, 11) == 5, 1);
    assert!(upper_bound(&vect, 10) == 5, 1);
    assert!(upper_bound(&vect, 6) == 4, 1);
    assert!(upper_bound(&vect, 5) == 4, 1);
    assert!(upper_bound(&vect, 3) == 2, 1);
    assert!(upper_bound(&vect, 2) == 2, 1);
    assert!(upper_bound(&vect, 1) == 2, 1);
    assert!(upper_bound(&vect, 0) == 0, 1);
  }

  #[test]
  fun insert_test() {
    let sorted_list = empty();
    insert(&mut sorted_list, 1);
    assert!(sorted_list.list == vector<u64> [1], 1);
    
    insert(&mut sorted_list, 1); // duplicate should be ignored
    assert!(sorted_list.list == vector<u64> [1], 1);

    insert(&mut sorted_list, 0); // insert before the smallest value
    assert!(sorted_list.list == vector<u64> [0, 1], 1);

    insert(&mut sorted_list, 10); // insert after the largest value
    assert!(sorted_list.list == vector<u64> [0, 1, 10], 1);

    insert(&mut sorted_list, 5);
    assert!(sorted_list.list == vector<u64> [0, 1, 5, 10], 1);

    insert(&mut sorted_list, 5); // duplicate should be ignored
    assert!(sorted_list.list == vector<u64> [0, 1, 5, 10], 1);
  }

  #[test]
  fun remove_test() {
    let sorted_list = empty();
    insert(&mut sorted_list, 1);
    insert(&mut sorted_list, 0);
    insert(&mut sorted_list, 5);
    insert(&mut sorted_list, 10);
    assert!(sorted_list.list == vector<u64> [0, 1, 5, 10], 1);

    remove(&mut sorted_list, 1);
    assert!(sorted_list.list == vector<u64> [0, 5, 10], 1);
    remove(&mut sorted_list, 10);
    assert!(sorted_list.list == vector<u64> [0, 5], 1);
    remove(&mut sorted_list, 0);
    assert!(sorted_list.list == vector<u64> [5], 1);
    remove(&mut sorted_list, 5);
    assert!(sorted_list.list == vector<u64> [], 1);
  }
}
