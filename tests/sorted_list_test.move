#[test_only]
module scallop_referral_program::sorted_list_test {
  use std::vector;
  use scallop_referral_program::asc_u64_sorted_list;

  #[test]
  public fun test_insert() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 5);
    asc_u64_sorted_list::insert(&mut list, 1);
    asc_u64_sorted_list::insert(&mut list, 4);
    asc_u64_sorted_list::insert(&mut list, 2);
    asc_u64_sorted_list::insert(&mut list, 3);
    let vec = asc_u64_sorted_list::to_vector(&list);

    let target_vec = vector::empty<u64>();
    vector::push_back(&mut target_vec, 1);
    vector::push_back(&mut target_vec, 2);
    vector::push_back(&mut target_vec, 3);
    vector::push_back(&mut target_vec, 4);
    vector::push_back(&mut target_vec, 5);

    assert!(vec == target_vec, 0);
  }

  #[test]
  public fun test_find() {
    let list = asc_u64_sorted_list::empty();
    asc_u64_sorted_list::insert(&mut list, 100);
    asc_u64_sorted_list::insert(&mut list, 0);
    asc_u64_sorted_list::insert(&mut list, 100000);
    asc_u64_sorted_list::insert(&mut list, 1000);
    asc_u64_sorted_list::insert(&mut list, 10000);

    let target_value = 99;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 0, 0);

    let target_value = 100;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 100, 0);

    let target_value = 101;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 100, 0);

    let target_value = 2000;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 1000, 0);

    let target_value = 90000;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 10000, 0);

    let target_value = 110000;
    let find_value = asc_u64_sorted_list::find_nearest_smaller_or_equal_value(&list, target_value);
    assert!(find_value == 100000, 0);
  }
}
