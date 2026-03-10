/// @title Comprehensive edge case tests for AscU64SortedList
/// @notice Covers u64 boundaries, empty list, single element, duplicates, large lists, removal edge cases
#[test_only]
module scallop_referral_program::sorted_list_edge_test {

  use std::vector;
  use scallop_referral_program::asc_u64_sorted_list;

  // ==================== u64 Boundary Tests ====================

  #[test]
  public fun test_insert_u64_max() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 18446744073709551615); // u64::MAX
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 1, 0);
    assert!(*vector::borrow(&vec, 0) == 18446744073709551615, 1);
  }

  #[test]
  public fun test_insert_zero_and_u64_max() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 18446744073709551615);
    asc_u64_sorted_list::insert(&mut list, 0);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 0) == 0, 1);
    assert!(*vector::borrow(&vec, 1) == 18446744073709551615, 2);
  }

  #[test]
  public fun test_find_nearest_at_u64_max() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 0);
    asc_u64_sorted_list::insert(&mut list, 1000);
    asc_u64_sorted_list::insert(&mut list, 18446744073709551615);

    // Search for u64::MAX should find u64::MAX
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 18446744073709551615);
    assert!(val == 18446744073709551615, 0);

    // Search for u64::MAX - 1 should find 1000
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 18446744073709551614);
    assert!(val == 1000, 1);
  }

  #[test]
  public fun test_consecutive_u64_values_near_max() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 18446744073709551613); // MAX - 2
    asc_u64_sorted_list::insert(&mut list, 18446744073709551614); // MAX - 1
    asc_u64_sorted_list::insert(&mut list, 18446744073709551615); // MAX
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 3, 0);
    assert!(*vector::borrow(&vec, 0) == 18446744073709551613, 1);
    assert!(*vector::borrow(&vec, 1) == 18446744073709551614, 2);
    assert!(*vector::borrow(&vec, 2) == 18446744073709551615, 3);
  }

  // ==================== Empty List Tests ====================

  #[test]
  #[expected_failure(abort_code = 1)]
  public fun test_find_nearest_on_empty_list_should_abort() {
    let list = asc_u64_sorted_list::empty();
    // Should abort with NotFoundErr (1) because no elements exist
    asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 0);
  }

  #[test]
  #[expected_failure(abort_code = 1)]
  public fun test_find_nearest_on_empty_list_with_max_value_should_abort() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 18446744073709551615);
  }

  #[test]
  public fun test_remove_from_empty_list_is_noop() {
    let list = asc_u64_sorted_list::empty();
    // Remove on empty list should silently do nothing
    asc_u64_sorted_list::remove(&mut list, 42);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 0, 0);
  }

  #[test]
  public fun test_empty_list_to_vector() {
    let list = asc_u64_sorted_list::empty();
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 0, 0);
  }

  // ==================== Single Element Tests ====================

  #[test]
  public fun test_single_element_find_exact() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 500);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 500);
    assert!(val == 500, 0);
  }

  #[test]
  public fun test_single_element_find_above() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 500);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 999);
    assert!(val == 500, 0);
  }

  #[test]
  #[expected_failure(abort_code = 1)]
  public fun test_single_element_find_below_should_abort() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 500);
    // 499 < 500, no smaller or equal element exists
    asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 499);
  }

  #[test]
  public fun test_single_element_zero_find_zero() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 0);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 0);
    assert!(val == 0, 0);
  }

  #[test]
  public fun test_insert_and_remove_single_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 42);
    assert!(vector::length(&asc_u64_sorted_list::to_vector(&list)) == 1, 0);
    asc_u64_sorted_list::remove(&mut list, 42);
    assert!(vector::length(&asc_u64_sorted_list::to_vector(&list)) == 0, 1);
  }

  // ==================== Duplicate Handling Tests ====================

  #[test]
  public fun test_insert_duplicate_multiple_times() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 100);
    asc_u64_sorted_list::insert(&mut list, 100);
    asc_u64_sorted_list::insert(&mut list, 100);
    asc_u64_sorted_list::insert(&mut list, 100);
    let vec = asc_u64_sorted_list::to_vector(&list);
    // Should only have one entry despite 4 insertions
    assert!(vector::length(&vec) == 1, 0);
    assert!(*vector::borrow(&vec, 0) == 100, 1);
  }

  #[test]
  public fun test_insert_duplicate_interspersed_with_other_values() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 5);
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 5); // duplicate
    asc_u64_sorted_list::insert(&mut list, 15);
    asc_u64_sorted_list::insert(&mut list, 10); // duplicate
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 3, 0);
    assert!(*vector::borrow(&vec, 0) == 5, 1);
    assert!(*vector::borrow(&vec, 1) == 10, 2);
    assert!(*vector::borrow(&vec, 2) == 15, 3);
  }

  // ==================== Remove Edge Cases ====================

  #[test]
  public fun test_remove_nonexistent_value_is_noop() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::insert(&mut list, 30);
    // Remove value that doesn't exist
    asc_u64_sorted_list::remove(&mut list, 15);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 3, 0);
  }

  #[test]
  public fun test_remove_first_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 2);
    asc_u64_sorted_list::insert(&mut list, 3);
    asc_u64_sorted_list::remove(&mut list, 1);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 0) == 2, 1);
  }

  #[test]
  public fun test_remove_last_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 2);
    asc_u64_sorted_list::insert(&mut list, 3);
    asc_u64_sorted_list::remove(&mut list, 3);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 1) == 2, 1);
  }

  #[test]
  public fun test_remove_middle_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 2);
    asc_u64_sorted_list::insert(&mut list, 3);
    asc_u64_sorted_list::remove(&mut list, 2);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 0) == 1, 1);
    assert!(*vector::borrow(&vec, 1) == 3, 2);
  }

  #[test]
  public fun test_remove_all_elements_one_by_one() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::insert(&mut list, 30);
    asc_u64_sorted_list::remove(&mut list, 20);
    asc_u64_sorted_list::remove(&mut list, 10);
    asc_u64_sorted_list::remove(&mut list, 30);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 0, 0);
  }

  #[test]
  public fun test_remove_then_reinsert() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::remove(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 10);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 0) == 10, 1);
    assert!(*vector::borrow(&vec, 1) == 20, 2);
  }

  #[test]
  public fun test_double_remove_same_value_is_noop() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::remove(&mut list, 10);
    // Second remove should be a noop
    asc_u64_sorted_list::remove(&mut list, 10);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 0, 0);
  }

  // ==================== Large List / Stress Tests ====================

  #[test]
  public fun test_insert_many_elements_in_reverse_order() {
    let list = asc_u64_sorted_list::empty();
    // Insert 50 elements in reverse: 50, 49, 48, ..., 1
    let i = 50u64;
    while (i > 0) {
      asc_u64_sorted_list::insert(&mut list, i);
      i = i - 1;
    };
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 50, 0);
    // Verify sorted order
    let j = 0u64;
    while (j < 50) {
      assert!(*vector::borrow(&vec, j) == j + 1, j + 1);
      j = j + 1;
    };
  }

  #[test]
  public fun test_find_nearest_with_many_elements() {
    let list = asc_u64_sorted_list::empty();
    // Insert elements: 0, 100, 200, ..., 9900
    let i = 0u64;
    while (i < 100) {
      asc_u64_sorted_list::insert(&mut list, i * 100);
      i = i + 1;
    };

    // Find nearest for values between elements
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 150);
    assert!(val == 100, 0);

    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 9950);
    assert!(val == 9900, 1);

    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 50);
    assert!(val == 0, 2);

    // Exact match
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 5000);
    assert!(val == 5000, 3);
  }

  // ==================== upper_bound Edge Cases ====================

  #[test]
  public fun test_upper_bound_empty_vector() {
    let v = vector::empty<u64>();
    assert!(asc_u64_sorted_list::upper_bound(&v, 0) == 0, 0);
    assert!(asc_u64_sorted_list::upper_bound(&v, 100) == 0, 1);
    assert!(asc_u64_sorted_list::upper_bound(&v, 18446744073709551615) == 0, 2);
  }

  #[test]
  public fun test_upper_bound_single_element() {
    let v = vector<u64>[50];
    assert!(asc_u64_sorted_list::upper_bound(&v, 0) == 0, 0);
    assert!(asc_u64_sorted_list::upper_bound(&v, 49) == 0, 1);
    assert!(asc_u64_sorted_list::upper_bound(&v, 50) == 1, 2);
    assert!(asc_u64_sorted_list::upper_bound(&v, 51) == 1, 3);
  }

  #[test]
  public fun test_upper_bound_all_same_values() {
    let v = vector<u64>[5, 5, 5, 5, 5];
    assert!(asc_u64_sorted_list::upper_bound(&v, 4) == 0, 0);
    assert!(asc_u64_sorted_list::upper_bound(&v, 5) == 5, 1);
    assert!(asc_u64_sorted_list::upper_bound(&v, 6) == 5, 2);
  }

  #[test]
  public fun test_upper_bound_consecutive_values() {
    let v = vector<u64>[0, 1, 2, 3, 4];
    assert!(asc_u64_sorted_list::upper_bound(&v, 0) == 1, 0);
    assert!(asc_u64_sorted_list::upper_bound(&v, 1) == 2, 1);
    assert!(asc_u64_sorted_list::upper_bound(&v, 2) == 3, 2);
    assert!(asc_u64_sorted_list::upper_bound(&v, 3) == 4, 3);
    assert!(asc_u64_sorted_list::upper_bound(&v, 4) == 5, 4);
  }

  // ==================== Find Nearest Boundary Tests ====================

  #[test]
  #[expected_failure(abort_code = 1)]
  public fun test_find_nearest_all_values_greater_than_target() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 100);
    asc_u64_sorted_list::insert(&mut list, 200);
    asc_u64_sorted_list::insert(&mut list, 300);
    // All values > 50, so no smaller or equal value exists
    asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 50);
  }

  #[test]
  public fun test_find_nearest_exact_match_first_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::insert(&mut list, 30);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 10);
    assert!(val == 10, 0);
  }

  #[test]
  public fun test_find_nearest_exact_match_last_element() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::insert(&mut list, 30);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 30);
    assert!(val == 30, 0);
  }

  #[test]
  public fun test_find_nearest_value_far_above_max() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 2);
    let val = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, 18446744073709551615);
    assert!(val == 2, 0);
  }

  // ==================== Insert/Remove Ordering Stress ====================

  #[test]
  public fun test_alternating_insert_remove() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 20);
    asc_u64_sorted_list::remove(&mut list, 10);
    asc_u64_sorted_list::insert(&mut list, 5);
    asc_u64_sorted_list::remove(&mut list, 20);
    asc_u64_sorted_list::insert(&mut list, 15);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(vector::length(&vec) == 2, 0);
    assert!(*vector::borrow(&vec, 0) == 5, 1);
    assert!(*vector::borrow(&vec, 1) == 15, 2);
  }

  #[test]
  public fun test_insert_powers_of_two() {
    let list = asc_u64_sorted_list::empty();
    // Insert powers of 2 in random order
    asc_u64_sorted_list::insert(&mut list, 256);
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 64);
    asc_u64_sorted_list::insert(&mut list, 4);
    asc_u64_sorted_list::insert(&mut list, 16);
    asc_u64_sorted_list::insert(&mut list, 1024);
    let vec = asc_u64_sorted_list::to_vector(&list);
    assert!(*vector::borrow(&vec, 0) == 1, 0);
    assert!(*vector::borrow(&vec, 1) == 4, 1);
    assert!(*vector::borrow(&vec, 2) == 16, 2);
    assert!(*vector::borrow(&vec, 3) == 64, 3);
    assert!(*vector::borrow(&vec, 4) == 256, 4);
    assert!(*vector::borrow(&vec, 5) == 1024, 5);
  }
}
