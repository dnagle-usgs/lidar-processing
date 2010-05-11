#include "hashptr.i"
#include "unittest.i"

func test_hashptr_new_accept_empty {
   ignore = p_new();
}

func test_hashptr_new_accept_str_single {
   ignore = p_new("key", "value");
}

func test_hashptr_new_accept_str_many {
   ignore = p_new("a","b","c","d","e","f","g","h","i","j","k","l","m","n");
}

func test_hashptr_new_accept_key_single {
   ignore = p_new(key="value");
}

func test_hashptr_new_accept_key_many {
   ignore = p_new(a="b", c="d", e="f", g="h", i="j", k="l", m="n");
}

func test_hashptr_new_accept_str_and_key {
   ignore = p_new("positional", 1, key=2);
}

func test_hashptr_new_fail_odd {
   tc_assert_error, "__test_hashptr_new_fail_odd1";
   tc_assert_error, "__test_hashptr_new_fail_odd2";
}
func __test_hashptr_new_fail_odd1 {
   ignore = p_new("a");
}
func __test_hashptr_new_fail_odd2 {
   ignore = p_new("a","b","c");
}

func test_hashptr_new_result_pointer {
   tc_assert, is_pointer(p_new());
}

func test_hashptr_new_result_scalar {
   tc_assert, is_scalar(p_new());
}

func test_hashptr_new_last_applies {
   p = p_new(a=5, a=1, a=3);
   tc_assert_equal, p_get(p, a=), 3;
}

func test_hashptr_keys_empty {
   p = p_new();
   keys = p_keys(p);
   tc_assert_equal, 0, numberof(keys), "key count match";
}

func test_hashptr_keys_single {
   p = p_new("a", 1);
   keys = p_keys(p);
   tc_assert_equal, 1, numberof(keys), "key count match";
   tc_assert_equal, "a", keys(1), "key name match";
}

func test_hashptr_keys_triple {
   p = p_new("a", 1, "b", 2, c=3);
   keys = p_keys(p);
   tc_assert_equal, 3, numberof(keys), "key count match";
   keys = keys(sort(keys));
   tc_assert_equal, "a", keys(1), "key name match, a";
   tc_assert_equal, "b", keys(2), "key name match, b";
   tc_assert_equal, "c", keys(3), "key name match, c";
}

func test_hashptr_keys_match_values {
   p = p_new("b", "b", "c", "c", "foo", "foo", a="a", d="d", bar="bar");
   keys = p_keys(p);
   vals = p_values(p);
   tc_assert_equal, numberof(keys), numberof(vals), "key count == value count";
   for(i = 1; i <= numberof(keys); i++)
      tc_assert_equal, keys(i), *vals(i), swrite(format="key %d == val %d", i, i);
}

func test_hashptr_get_missing {
   p = p_new(a=1);
   tc_assert, is_void(p_get(p, "missing")), "missing key -> []";
}

func test_hashptr_get_positional {
   p = p_new(a=5);
   tc_assert_equal, 5, p_get(p, "a");
}

func test_hashptr_get_keyword {
   p = p_new(a=5);
   tc_assert_equal, 5, p_get(p, a=);
}

func test_hashptr_get_match_multiple {
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert_equal, p_get(p, "a"), 1, "key a";
   tc_assert_equal, p_get(p, b=), 20, "key b";
   tc_assert_equal, p_get(p, "c"), "sea", "key c";
   tc_assert_equal, p_get(p, d=), -5, "key d";
   tc_assert_equal, p_get(p, "e"), "mc2", "key e";
}

func test_hashptr_get_fail_nokey {
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_get_fail_nokey";
}
func __test_hashptr_get_fail_nokey {
   ignore = p_get(p);
}

func test_hashptr_get_fail_multipos {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_multipos";
}
func __test_hashptr_get_fail_multipos {
   ignore = p_get(p, "a", "b");
}

func test_hashptr_get_fail_multikey {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_multikey";
}
func __test_hashptr_get_fail_multikey {
   ignore = p_get(p, a=, b=);
}

func test_hashptr_get_fail_pos_and_keyword {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_pos_and_keyword";
}
func __test_hashptr_get_fail_pos_and_keyword {
   ignore = p_get(p, "a", b=);
}

func test_hashptr_has_yes {
   p = p_new(a=1);
   tc_assert, p_has(p, "a");
}

func test_hashptr_has_no {
   p = p_new(a=1);
   tc_assert_false, p_has(p, "b");
}

func test_hashptr_has_positional {
   p = p_new(a=5);
   tc_assert, p_has(p, "a");
}

func test_hashptr_has_keyword {
   p = p_new(a=5);
   tc_assert, p_has(p, a=);
}

func test_hashptr_has_multiple {
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert, p_has(p, "a"), "key a";
   tc_assert, p_has(p, "b"), "key b";
   tc_assert, p_has(p, "c"), "key c";
   tc_assert, p_has(p, "d"), "key d";
   tc_assert, p_has(p, "e"), "key e";
}

func test_hashptr_has_fail_nokey {
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_has_fail_nokey";
}
func __test_hashptr_has_fail_nokey {
   ignore = p_has(p);
}

func test_hashptr_has_fail_multipos {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_multipos";
}
func __test_hashptr_has_fail_multipos {
   ignore = p_has(p, "a", "b");
}

func test_hashptr_has_fail_multikey {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_multikey";
}
func __test_hashptr_has_fail_multikey {
   ignore = p_has(p, a=, b=);
}

func test_hashptr_has_fail_pos_and_keyword {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_pos_and_keyword";
}
func __test_hashptr_has_fail_pos_and_keyword {
   ignore = p_has(p, "a", b=);
}

func test_hashptr_pop_missing {
   p = p_new(a=1);
   tc_assert, is_void(p_pop(p, "missing")), "missing key -> []";
}

func test_hashptr_pop_positional {
   p = p_new(a=5);
   tc_assert_equal, 5, p_pop(p, "a");
}

func test_hashptr_pop_keyword {
   p = p_new(a=5);
   tc_assert_equal, 5, p_pop(p, a=);
}

func test_hashptr_pop_match_multiple {
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert_equal, p_pop(p, "a"), 1, "key a";
   tc_assert_equal, p_pop(p, b=), 20, "key b";
   tc_assert_equal, p_pop(p, "c"), "sea", "key c";
   tc_assert_equal, p_pop(p, d=), -5, "key d";
   tc_assert_equal, p_pop(p, "e"), "mc2", "key e";
}

func test_hashptr_pop_present_removes_sub {
   p = p_new(a=1);
   p_pop, p, a=;
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_pop_present_removes_fnc {
   p = p_new(a=1);
   ignore = p_pop(p, a=);
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_pop_present_leaves_rest_sub {
   p = p_new(a=1, b=2);
   p_pop, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_present_leaves_rest_fnc {
   p = p_new(a=1, b=2);
   ignore = p_pop(p, a=);
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_missing_leaves_rest_sub {
   p = p_new(b=2);
   p_pop, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_missing_leaves_rest_fnc {
   p = p_new(b=2);
   ignore = p_pop(p, a=);
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_fail_nokey {
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_pop_fail_nokey";
}
func __test_hashptr_pop_fail_nokey {
   ignore = p_pop(p);
}

func test_hashptr_pop_fail_multipos {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_multipos";
}
func __test_hashptr_pop_fail_multipos {
   ignore = p_pop(p, "a", "b");
}

func test_hashptr_pop_fail_multikey {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_multikey";
}
func __test_hashptr_pop_fail_multikey {
   ignore = p_pop(p, a=, b=);
}

func test_hashptr_pop_fail_pos_and_keyword {
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_pos_and_keyword";
}
func __test_hashptr_pop_fail_pos_and_keyword {
   ignore = p_pop(p, "a", b=);
}

func test_hashptr_set_accept_empty {
   p = p_new();
   p_set, p;
}

func test_hashptr_set_accept_str_single {
   p = p_new();
   p_set, p, "key", "value";
}

func test_hashptr_set_accept_str_many {
   p = p_new();
   p_set, p, "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n";
}

func test_hashptr_set_accept_key_single {
   p = p_new();
   p_set, p, key="value";
}

func test_hashptr_set_accept_key_many {
   p = p_new();
   p_set, p, a="b", c="d", e="f", g="h", i="j", k="l", m="n";
}

func test_hashptr_set_accept_str_and_key {
   p = p_new();
   p_set, p, "positional", 1, key=2;
}

func test_hashptr_set_accept_to_empty {
   p = p_new();
   p_set, p, key="value";
}

func test_hashptr_set_accept_to_nonempty {
   p = p_new(a=1, b=2);
   p_set, p, key="value";
}

func test_hashptr_set_fail_odd {
   p = p_new();
   tc_assert_error, "__test_hashptr_set_fail_odd1";
   p = p_new();
   tc_assert_error, "__test_hashptr_set_fail_odd2";
}
func __test_hashptr_set_fail_odd1 {
   p_set, p, "a";
}
func __test_hashptr_set_fail_odd2 {
   p_set, p, "a", "b", "c";
}

func test_hashptr_set_result_pointer {
   p = p_new();
   tc_assert, is_pointer(p_set(p));
}

func test_hashptr_set_result_scalar {
   p = p_new();
   tc_assert, is_scalar(p_set(p));
}

func test_hashptr_set_no_loss {
   p = p_new(a=1);
   p_set, p, b=2;
   tc_assert, p_has(p, a=);
}

func test_hashptr_set_clobber {
   p = p_new(a=10);
   p_set, p, a=20;
   tc_assert_equal, 20, p_get(p, a=);
}

func test_hashptr_set_last_applies {
   p = p_new(a=2);
   p_set, p, a=5, a=1, a=3;
   tc_assert_equal, p_get(p, a=), 3;
}

func test_hashptr_delete_accept_null {
   p = p_new();
   p_delete, p;
}

func test_hashptr_delete_accept_scalar_single {
   p = p_new();
   p_delete, p, "a";
}

func test_hashptr_delete_accept_scalar_multiple {
   p = p_new();
   p_delete, p, "a", "b", "c";
}

func test_hashptr_delete_accept_array_single {
   p = p_new();
   p_delete, p, ["a", "b", "c"];
}

func test_hashptr_delete_accept_array_multiple {
   p = p_new();
   p_delete, p, ["a", "b", "c"], ["d", "e", "f"];
}

func test_hashptr_delete_accept_key_single {
   p = p_new();
   p_delete, p, a=;
}

func test_hashptr_delete_accept_key_multiple {
   p = p_new();
   p_delete, p, a=, b=, c=;
}

func test_hashptr_delete_accept_mixed {
   p = p_new();
   p_delete, p, "a", ["b", "c"], "d", "e", ["f", "g", "h"], i=, j=;
}

func test_hashptr_delete_accept_array_mismatched {
   p = p_new();
   p_delete, p, array("a", 3, 4), array("b", 2, 5);
}

func test_hashptr_delete_confirm_removal_single {
   p = p_new(a=1);
   p_delete, p, a=;
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_delete_confirm_removal_multiple {
   p = p_new(a=1, b=2, c=3);
   p_delete, p, a=, b=, c=;
   tc_assert_false, p_has(p, a=), "key a";
   tc_assert_false, p_has(p, b=), "key b";
   tc_assert_false, p_has(p, c=), "key c";
}

func test_hashptr_delete_leaves_others {
   p = p_new(a=1, b=2);
   p_delete, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_merge_accept_null {
   ignore = p_merge();
}

func test_hashptr_merge_accept_single {
   p = p_new();
   ignore = p_merge(p);
}

func test_hashptr_merge_accept_multiple {
   p1 = p_new();
   p2 = p_new();
   p3 = p_new();
   ignore = p_merge(p1, p2, p3);
}

func test_hashptr_number_zero {
   p = p_new();
   tc_assert_equal, 0, p_number(p);
}

func test_hashptr_number_one {
   p = p_new(a=1);
   tc_assert_equal, 1, p_number(p);
}

func test_hashptr_number_five {
   p = p_new(a=1, b=2, c=3, d=4, e=5);
   tc_assert_equal, 5, p_number(p);
}

func test_hashptr_p_hash_accept_empty {
   p = p_new();
   ignore = p_hash(p);
}

func test_hashptr_p_hash_accept_nonempty {
   p = p_new(a=1, b=2);
   ignore = p_hash(p);
}

func test_hashptr_h_hashptr_accept_empty {
   h = h_new();
   ignore = h_hashptr(h);
}

func test_hashptr_h_hashptr_accept_nonempty {
   h = h_new(a=1, b=2);
   ignore = h_hashptr(h);
}

func test_hashptr_p_hash_h_hashptr_roundtrip {
   p1 = p_new(a=1, b=2, c=3);
   p2 = h_hashptr(p_hash(p1));
   tc_assert_equal, p_number(p1), p_number(p2), "count match";
   tc_assert_equal, p_get(p1, a=), p_get(p2, a=), "key a";
   tc_assert_equal, p_get(p1, b=), p_get(p2, b=), "key b";
   tc_assert_equal, p_get(p1, c=), p_get(p2, c=), "key c";
}

func test_hashptr_copy_accept_empty {
   p1 = p_new();
   p2 = p_copy(p1);
}

func test_hashptr_copy_accept_nonempty {
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
}

func test_hashptr_copy_confirm_count {
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   tc_assert_equal, p_number(p1), p_number(p2);
}

func test_hashptr_copy_confirm_same_keys {
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   p2keys = p_keys(p2);
   p2keys = p2keys(sort(p2keys));
   tc_assert, allof(p2keys == ["a", "b", "c"]);
}

func test_hashptr_copy_confirm_same_values {
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   tc_assert_equal, p_get(p1, a=), p_get(p2, a=), "key a";
   tc_assert_equal, p_get(p1, b=), p_get(p2, b=), "key b";
   tc_assert_equal, p_get(p1, c=), p_get(p2, c=), "key c";
}

func test_hashptr_copy_confirm_distinct_copies {
   p1 = p_new(a=0);
   p2 = p_copy(p1);
   p_set, p1, a=1;
   p_set, p2, a=2;
   tc_assert_not_equal, p_get(p1, a=), p_get(p2, a=);
}
