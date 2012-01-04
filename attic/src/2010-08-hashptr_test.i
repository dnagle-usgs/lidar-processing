/******************************************************************************\
* This file was moved to the attic on 2010-08-23. This is the test suite for   *
* hashptr.i, which was also moved to the attic.                                *
\******************************************************************************/

#include "hashptr.i"
#include "unittest.i"

func test_hashptr_new_accept_empty {
/* DOCUMENT p_new() works with no arguments */
   ignore = p_new();
}

func test_hashptr_new_accept_str_single {
/* DOCUMENT p_new() works with a single key/val pair, string key */
   ignore = p_new("key", "value");
}

func test_hashptr_new_accept_str_many {
/* DOCUMENT p_new() works with multiple key/val pairs, string keys */
   ignore = p_new("a","b","c","d","e","f","g","h","i","j","k","l","m","n");
}

func test_hashptr_new_accept_key_single {
/* DOCUMENT p_new() works with a single key/val pair, option key */
   ignore = p_new(key="value");
}

func test_hashptr_new_accept_key_many {
/* DOCUMENT p_new() works with multiple key/val pairs, option keys */
   ignore = p_new(a="b", c="d", e="f", g="h", i="j", k="l", m="n");
}

func test_hashptr_new_accept_str_and_key {
/* DOCUMENT p_new() works when given string and option keys at same time */
   ignore = p_new("positional", 1, key=2);
}

func test_hashptr_new_fail_odd {
/* DOCUMENT p_new() fails when given an odd number of arguments */
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
/* DOCUMENT p_new() returns a pointer */
   tc_assert, is_pointer(p_new());
}

func test_hashptr_new_result_scalar {
/* DOCUMENT p_new() returns a scalar */
   tc_assert, is_scalar(p_new());
}

func test_hashptr_new_last_applies {
/* DOCUMENT when p_new() is given duplicate key/val pairs, the last instance
 * takes precedence */
   p = p_new(a=5, a=1, a=3);
   tc_assert_equal, p_get(p, a=), 3;
}

func test_hashptr_keys_empty {
/* DOCUMENT p_keys() returns [] for empty hash p_new() */
   p = p_new();
   keys = p_keys(p);
   tc_assert_equal, 0, numberof(keys), "key count match";
}

func test_hashptr_keys_single {
/* DOCUMENT p_keys() returns correct result on hash with one key */
   p = p_new("a", 1);
   keys = p_keys(p);
   tc_assert_equal, 1, numberof(keys), "key count match";
   tc_assert_equal, "a", keys(1), "key name match";
}

func test_hashptr_keys_triple {
/* DOCUMENT p_keys() returns correct result on hash with three keys */
   p = p_new("a", 1, "b", 2, c=3);
   keys = p_keys(p);
   tc_assert_equal, 3, numberof(keys), "key count match";
   keys = keys(sort(keys));
   tc_assert_equal, "a", keys(1), "key name match, a";
   tc_assert_equal, "b", keys(2), "key name match, b";
   tc_assert_equal, "c", keys(3), "key name match, c";
}

func test_hashptr_keys_match_values {
/* DOCUMENT p_keys() and p_values() return results in same order */
   p = p_new("b", "b", "c", "c", "foo", "foo", a="a", d="d", bar="bar");
   keys = p_keys(p);
   vals = p_values(p);
   tc_assert_equal, numberof(keys), numberof(vals), "key count == value count";
   for(i = 1; i <= numberof(keys); i++)
      tc_assert_equal, keys(i), *vals(i), swrite(format="key %d == val %d", i, i);
}

func test_hashptr_get_missing {
/* DOCUMENT p_get() returns [] for missing key */
   p = p_new(a=1);
   tc_assert, is_void(p_get(p, "missing")), "missing key -> []";
}

func test_hashptr_get_positional {
/* DOCUMENT p_get() works with positional argument */
   p = p_new(a=5);
   tc_assert_equal, 5, p_get(p, "a");
}

func test_hashptr_get_keyword {
/* DOCUMENT p_get() works with keyword argument */
   p = p_new(a=5);
   tc_assert_equal, 5, p_get(p, a=);
}

func test_hashptr_get_match_multiple {
/* DOCUMENT p_get() works on hash with multiple keys */
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert_equal, p_get(p, "a"), 1, "key a";
   tc_assert_equal, p_get(p, b=), 20, "key b";
   tc_assert_equal, p_get(p, "c"), "sea", "key c";
   tc_assert_equal, p_get(p, d=), -5, "key d";
   tc_assert_equal, p_get(p, "e"), "mc2", "key e";
}

func test_hashptr_get_fail_nokey {
/* DOCUMENT p_get() fails if no key is specified */
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_get_fail_nokey";
}
func __test_hashptr_get_fail_nokey {
   ignore = p_get(p);
}

func test_hashptr_get_fail_multipos {
/* DOCUMENT p_get() fails if more than one positional key is specified */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_multipos";
}
func __test_hashptr_get_fail_multipos {
   ignore = p_get(p, "a", "b");
}

func test_hashptr_get_fail_multikey {
/* DOCUMENT p_get() fails if more than one keyword key is specified */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_multikey";
}
func __test_hashptr_get_fail_multikey {
   ignore = p_get(p, a=, b=);
}

func test_hashptr_get_fail_pos_and_keyword {
/* DOCUMENT p_get() fails if both a positional and keyword key are provided */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_get_fail_pos_and_keyword";
}
func __test_hashptr_get_fail_pos_and_keyword {
   ignore = p_get(p, "a", b=);
}

func test_hashptr_has_yes {
/* DOCUMENT p_has() reports true correctly */
   p = p_new(a=1);
   tc_assert, p_has(p, "a");
}

func test_hashptr_has_no {
/* DOCUMENT p_has() reports false correctly */
   p = p_new(a=1);
   tc_assert_false, p_has(p, "b");
}

func test_hashptr_has_positional {
/* DOCUMENT p_has() accepts positional key */
   p = p_new(a=5);
   tc_assert, p_has(p, "a");
}

func test_hashptr_has_keyword {
/* DOCUMENT p_has() accepts keyword key */
   p = p_new(a=5);
   tc_assert, p_has(p, a=);
}

func test_hashptr_has_multiple {
/* DOCUMENT p_has() works on hash with multiple key/val pairs */
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert, p_has(p, "a"), "key a";
   tc_assert, p_has(p, "b"), "key b";
   tc_assert, p_has(p, "c"), "key c";
   tc_assert, p_has(p, "d"), "key d";
   tc_assert, p_has(p, "e"), "key e";
}

func test_hashptr_has_fail_nokey {
/* DOCUMENT p_has() fails if no key provided */
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_has_fail_nokey";
}
func __test_hashptr_has_fail_nokey {
   ignore = p_has(p);
}

func test_hashptr_has_fail_multipos {
/* DOCUMENT p_has() fails with multiple positional keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_multipos";
}
func __test_hashptr_has_fail_multipos {
   ignore = p_has(p, "a", "b");
}

func test_hashptr_has_fail_multikey {
/* DOCUMENT p_has() fails with multiple keyword keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_multikey";
}
func __test_hashptr_has_fail_multikey {
   ignore = p_has(p, a=, b=);
}

func test_hashptr_has_fail_pos_and_keyword {
/* DOCUMENT p_has() fails with mixed (positional plus keyword) keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_has_fail_pos_and_keyword";
}
func __test_hashptr_has_fail_pos_and_keyword {
   ignore = p_has(p, "a", b=);
}

func test_hashptr_pop_missing {
/* DOCUMENT p_pop() returns [] for missing key */
   p = p_new(a=1);
   tc_assert, is_void(p_pop(p, "missing")), "missing key -> []";
}

func test_hashptr_pop_positional {
/* DOCUMENT p_pop() accepts positional key */
   p = p_new(a=5);
   tc_assert_equal, 5, p_pop(p, "a");
}

func test_hashptr_pop_keyword {
/* DOCUMENT p_pop() accepts keyword key */
   p = p_new(a=5);
   tc_assert_equal, 5, p_pop(p, a=);
}

func test_hashptr_pop_match_multiple {
/* DOCUMENT p_pop() yields correct result on hash with multiple keys */
   p = p_new("a", 1, "b", 20, "c", "sea", d=-5, e="mc2");
   tc_assert_equal, p_pop(p, "a"), 1, "key a";
   tc_assert_equal, p_pop(p, b=), 20, "key b";
   tc_assert_equal, p_pop(p, "c"), "sea", "key c";
   tc_assert_equal, p_pop(p, d=), -5, "key d";
   tc_assert_equal, p_pop(p, "e"), "mc2", "key e";
}

func test_hashptr_pop_present_removes_sub {
/* DOCUMENT p_pop() removes key in subroutine form */
   p = p_new(a=1);
   p_pop, p, a=;
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_pop_present_removes_fnc {
/* DOCUMENT p_pop() removes key in functional form */
   p = p_new(a=1);
   ignore = p_pop(p, a=);
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_pop_present_leaves_rest_sub {
/* DOCUMENT p_pop() leaves rest of hash alone in subroutine form when removing
 * a key that exists */
   p = p_new(a=1, b=2);
   p_pop, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_present_leaves_rest_fnc {
/* DOCUMENT p_pop() leaves rest of hash alone in functional form when removing
 * a key that exists */
   p = p_new(a=1, b=2);
   ignore = p_pop(p, a=);
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_missing_leaves_rest_sub {
/* DOCUMENT p_pop() leaves rest of hash alone in subroutine form when removing
 * a key that does not exist */
   p = p_new(b=2);
   p_pop, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_missing_leaves_rest_fnc {
/* DOCUMENT p_pop() leaves rest of hash alone in functoinal form when removing
 * a key that does not exist */
   p = p_new(b=2);
   ignore = p_pop(p, a=);
   tc_assert, p_has(p, b=);
}

func test_hashptr_pop_fail_nokey {
/* DOCUMENT p_pop() fails if not given key */
   p = p_new(a=1);
   tc_assert_error, "__test_hashptr_pop_fail_nokey";
}
func __test_hashptr_pop_fail_nokey {
   ignore = p_pop(p);
}

func test_hashptr_pop_fail_multipos {
/* DOCUMENT p_pop() with multiple positional keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_multipos";
}
func __test_hashptr_pop_fail_multipos {
   ignore = p_pop(p, "a", "b");
}

func test_hashptr_pop_fail_multikey {
/* DOCUMENT p_pop() with multiple keyword keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_multikey";
}
func __test_hashptr_pop_fail_multikey {
   ignore = p_pop(p, a=, b=);
}

func test_hashptr_pop_fail_pos_and_keyword {
/* DOCUMENT p_pop() with mixed positional and keyword keys */
   p = p_new(a=1, b=2);
   tc_assert_error, "__test_hashptr_pop_fail_pos_and_keyword";
}
func __test_hashptr_pop_fail_pos_and_keyword {
   ignore = p_pop(p, "a", b=);
}

func test_hashptr_set_accept_empty {
/* DOCUMENT p_set() accepts lack of key/val pairs */
   p = p_new();
   p_set, p;
}

func test_hashptr_set_accept_str_single {
/* DOCUMENT p_set() accepts single key/val pair in positional form */
   p = p_new();
   p_set, p, "key", "value";
}

func test_hashptr_set_accept_str_many {
/* DOCUMENT p_set() accepts multiple key/val pairs in positional form */
   p = p_new();
   p_set, p, "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n";
}

func test_hashptr_set_accept_key_single {
/* DOCUMENT p_set() accepts a single key/val pair in keyword format */
   p = p_new();
   p_set, p, key="value";
}

func test_hashptr_set_accept_key_many {
/* DOCUMENT p_set() accepts multiple key/val pairs in keyword format */
   p = p_new();
   p_set, p, a="b", c="d", e="f", g="h", i="j", k="l", m="n";
}

func test_hashptr_set_accept_str_and_key {
/* DOCUMENT p_set() accepts mixed positional and keyword formats */
   p = p_new();
   p_set, p, "positional", 1, key=2;
}

func test_hashptr_set_accept_to_empty {
/* DOCUMENT p_set() accepts key/val for key that does not already exist */
   p = p_new();
   p_set, p, key="value";
}

func test_hashptr_set_accept_to_nonempty {
/* DOCUMENT p_set() accepts key/val for key that does already exist */
   p = p_new(a=1, b=2);
   p_set, p, key="value";
}

func test_hashptr_set_fail_odd {
/* DOCUMENT p_set() fails with odd number of positional arguments */
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
/* DOCUMENT p_set() returns pointer */
   p = p_new();
   tc_assert, is_pointer(p_set(p));
}

func test_hashptr_set_result_scalar {
/* DOCUMENT p_set() returns scalar */
   p = p_new();
   tc_assert, is_scalar(p_set(p));
}

func test_hashptr_set_no_loss {
/* DOCUMENT p_set() leaves other keys alone */
   p = p_new(a=1);
   p_set, p, b=2;
   tc_assert, p_has(p, a=);
}

func test_hashptr_set_clobber {
/* DOCUMENT p_set() replaces specified key if it exists */
   p = p_new(a=10);
   p_set, p, a=20;
   tc_assert_equal, 20, p_get(p, a=);
}

func test_hashptr_set_last_applies {
/* DOCUMENT when provided multiple key/val pairs with the same key, p_set will
 * apply the last instance */
   p = p_new(a=2);
   p_set, p, a=5, a=1, a=3;
   tc_assert_equal, p_get(p, a=), 3;
}

func test_hashptr_delete_accept_null {
/* DOCUMENT p_delete() accepts lack of keys */
   p = p_new();
   p_delete, p;
}

func test_hashptr_delete_accept_scalar_single {
/* DOCUMENT p_delete() accepts single scalar positional key */
   p = p_new();
   p_delete, p, "a";
}

func test_hashptr_delete_accept_scalar_multiple {
/* DOCUMENT p_delete() accepts multiple scalar positional keys */
   p = p_new();
   p_delete, p, "a", "b", "c";
}

func test_hashptr_delete_accept_array_single {
/* DOCUMENT p_delete() accepts single positional array of keys */
   p = p_new();
   p_delete, p, ["a", "b", "c"];
}

func test_hashptr_delete_accept_array_multiple {
/* DOCUMENT p_delete() accepts multiple positional arrays of keys */
   p = p_new();
   p_delete, p, ["a", "b", "c"], ["d", "e", "f"];
}

func test_hashptr_delete_accept_key_single {
/* DOCUMENT p_delete() accepts single keyword key */
   p = p_new();
   p_delete, p, a=;
}

func test_hashptr_delete_accept_key_multiple {
/* DOCUMENT p_delete() accepts multiple keyword keys */
   p = p_new();
   p_delete, p, a=, b=, c=;
}

func test_hashptr_delete_accept_mixed {
/* DOCUMENT p_delete() accepts mix of positional scalar keys, positional arrays
 * of keys, and keyword keys */
   p = p_new();
   p_delete, p, "a", ["b", "c"], "d", "e", ["f", "g", "h"], i=, j=;
}

func test_hashptr_delete_accept_array_mismatched {
/* DOCUMENT p_delete() accepts mix of positional arays of keys even when they
 * do not conform to one another */
   p = p_new();
   p_delete, p, array("a", 3, 4), array("b", 2, 5);
}

func test_hashptr_delete_confirm_removal_single {
/* DOCUMENT p_delete() successfully removes single key */
   p = p_new(a=1);
   p_delete, p, a=;
   tc_assert_false, p_has(p, a=);
}

func test_hashptr_delete_confirm_removal_multiple {
/* DOCUMENT p_delete() successfully removes multiple keys */
   p = p_new(a=1, b=2, c=3);
   p_delete, p, a=, b=, c=;
   tc_assert_false, p_has(p, a=), "key a";
   tc_assert_false, p_has(p, b=), "key b";
   tc_assert_false, p_has(p, c=), "key c";
}

func test_hashptr_delete_leaves_others {
/* DOCUMENT p_delete() leaves other keys alone */
   p = p_new(a=1, b=2);
   p_delete, p, a=;
   tc_assert, p_has(p, b=);
}

func test_hashptr_merge_accept_null {
/* DOCUMENT p_merge() accepts lack of arguments */
   ignore = p_merge();
}

func test_hashptr_merge_accept_single {
/* DOCUMENT p_merge() accepts single argument */
   p = p_new();
   ignore = p_merge(p);
}

func test_hashptr_merge_accept_multiple {
/* DOCUMENT p_merge() accepts multiple arguments */
   p1 = p_new();
   p2 = p_new();
   p3 = p_new();
   ignore = p_merge(p1, p2, p3);
}

func test_hashptr_number_zero {
/* DOCUMENT p_number() gives right result for empty hash pointer */
   p = p_new();
   tc_assert_equal, 0, p_number(p);
}

func test_hashptr_number_one {
/* DOCUMENT p_number() gives right result for single element hash pointer */
   p = p_new(a=1);
   tc_assert_equal, 1, p_number(p);
}

func test_hashptr_number_five {
/* DOCUMENT p_number() gives right result for five element hash pointer */
   p = p_new(a=1, b=2, c=3, d=4, e=5);
   tc_assert_equal, 5, p_number(p);
}

func test_hashptr_p_hash_accept_empty {
/* DOCUMENT p_hash() accepts empty hash pointer */
   p = p_new();
   ignore = p_hash(p);
}

func test_hashptr_p_hash_accept_nonempty {
/* DOCUMENT p_hash() accepts non-empty hash pointer */
   p = p_new(a=1, b=2);
   ignore = p_hash(p);
}

func test_hashptr_h_hashptr_accept_empty {
/* DOCUMENT h_hashptr() accepts empty hash */
   h = h_new();
   ignore = h_hashptr(h);
}

func test_hashptr_h_hashptr_accept_nonempty {
/* DOCUMENT h_hashptr() accepts non-empty hash */
   h = h_new(a=1, b=2);
   ignore = h_hashptr(h);
}

func test_hashptr_p_hash_h_hashptr_roundtrip {
/* DOCUMENT sending a set of key/val pairs round-trip through p_hash and
 * h_hashptr results in the same set of key/val pairs */
   p1 = p_new(a=1, b=2, c=3);
   p2 = h_hashptr(p_hash(p1));
   tc_assert_equal, p_number(p1), p_number(p2), "count match";
   tc_assert_equal, p_get(p1, a=), p_get(p2, a=), "key a";
   tc_assert_equal, p_get(p1, b=), p_get(p2, b=), "key b";
   tc_assert_equal, p_get(p1, c=), p_get(p2, c=), "key c";
}

func test_hashptr_copy_accept_empty {
/* DOCUMENT p_copy() accepts empty pointer hash */
   p1 = p_new();
   p2 = p_copy(p1);
}

func test_hashptr_copy_accept_nonempty {
/* DOCUMENT p_copy() accepts non-empty pointer hash */
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
}

func test_hashptr_copy_confirm_count {
/* DOCUMENT p_copy() returns result with same count */
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   tc_assert_equal, p_number(p1), p_number(p2);
}

func test_hashptr_copy_confirm_same_keys {
/* DOCUMENT p_copy() returns result with same keys */
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   p2keys = p_keys(p2);
   p2keys = p2keys(sort(p2keys));
   tc_assert, allof(p2keys == ["a", "b", "c"]);
}

func test_hashptr_copy_confirm_same_values {
/* DOCUMENT p_copy() returns result with same values */
   p1 = p_new(a=1, b=2, c=3);
   p2 = p_copy(p1);
   tc_assert_equal, p_get(p1, a=), p_get(p2, a=), "key a";
   tc_assert_equal, p_get(p1, b=), p_get(p2, b=), "key b";
   tc_assert_equal, p_get(p1, c=), p_get(p2, c=), "key c";
}

func test_hashptr_copy_confirm_distinct_copies {
/* DOCUMENT p_copy() returns distinct copy */
   p1 = p_new(a=0);
   p2 = p_copy(p1);
   p_set, p1, a=1;
   p_set, p2, a=2;
   tc_assert_not_equal, p_get(p1, a=), p_get(p2, a=);
}

func test_hashptr_is_hashptr_invalid_basic {
/* DOCUMENT is_hashptr() returns false for basic expected false cases */
   tc_assert_false, is_hashptr([]), "[]"
   tc_assert_false, is_hashptr(_lst()), "_lst()"
   tc_assert_false, is_hashptr(100), "100";
   tc_assert_false, is_hashptr(-3.14), "-3.14";
   tc_assert_false, is_hashptr(char(25)), "char(25)";
   tc_assert_false, is_hashptr(indgen(10)), "array of integers";
   tc_assert_false, is_hashptr(span(1,10,25)), "array of doubles";
   tc_assert_false, is_hashptr("foo"), "string";
   tc_assert_false, is_hashptr(["foo", "bar", "baz"]), "array of strings";
   tc_assert_false, is_hashptr(strchar("foo bar baz")), "array of char";
   tc_assert_false, is_hashptr(h_new()), "h_new()";
}

func test_hashptr_is_hashptr_invalid_from_symbols {
/* DOCUMENT is_hashptr() returns false for arbitrarily chosen values derived
 * using symbol_names() */
   // symbol_names(1) is the only case that could yield a valid hash pointer;
   // all other must fail
   for(i = 2; i <= 2048; i *= 2) {
      names = symbol_names(i);
      if(!numberof(names))
         continue;
      tc_assert_false, is_hashptr(symbol_def(names(1))), swrite(format="flag %d", i);
   }
}

func test_hashptr_is_hashptr_valid_empty {
/* DOCUMENT is_hashptr() returns true for empty hash pointer */
   tc_assert, is_hashptr(&array(pointer, 2));
}

func test_hashptr_is_hashptr_valid_nonempty {
/* DOCUMENT is_hashptr() returns true for non-empty hash pointer */
   keys = strchar(["a","b","c"]);
   vals = array(pointer, 3);
   tc_assert, is_hashptr(&[&keys, &vals]);
}

func test_hashptr_subkey_wrapper_accept_4args {
/* DOCUMENT p_subkey_wrapper() accepts four arguments */
   p_subkey_wrapper, p_new(), "key", 0, 0;
}

func test_hashptr_subkey_wrapper_accept_5args {
/* DOCUMENT p_subkey_wrapper() accepts five arguments */
   p_subkey_wrapper, p_new(), "key", 0, 0, 0;
}

func test_hashptr_subkey_wrapper_fnc_default_nonexist {
/* DOCUMENT p_subkey_wrapper() returns hash pointer if requested key does not
 * exist, when not provided a default value */
   obj = p_new();
   tmp = p_subkey_wrapper(obj, "test", 0, 0);
   tc_assert, is_hashptr(tmp);
}

func test_hashptr_subkey_wrapper_fnc_default_exist {
/* DOCUMENT p_subkey_wrapper() returns correct value if requested key exists,
 * when not provided a default value */
   obj = p_new(test=5);
   tmp = p_subkey_wrapper(obj, "test", 0, 0);
   tc_assert_equal, tmp, 5;
}

func test_hashptr_subkey_wrapper_fnc_nondefault_nonexist {
/* DOCUMENT p_subkey_wrapper() returns correct default value if requested key
 * does not exist, when provided a default value */
   obj = p_new();
   tmp = p_subkey_wrapper(obj, "test", 0, 0, []);
   tc_assert, is_void(tmp);
}

func test_hashptr_subkey_wrapper_fnc_nondefault_exist {
/* DOCUMENT p_subkey_wrapper() returns correct value if requested key exists,
 * when provided a default value */
   obj = p_new(test=1);
   tmp = p_subkey_wrapper(obj, "test", 0, 0, []);
   tc_assert_false, is_void(tmp);
   tc_assert_equal, tmp, 1;
}

func test_hashptr_subkey_wrapper_sub_set_nonexist {
/* DOCUMENT p_subkey_wrapper() accepts subroutine form with non-existant key */
   obj = p_new();
   p_subkey_wrapper, obj, "test", 1, p_new();
}

func test_hashptr_subkey_wrapper_sub_set_exist {
/* DOCUMENT p_subkey_wrapper() accepts subroutine form with existing key */
   obj = p_new(test=1);
   p_subkey_wrapper, obj, "test", 1, p_new();
}

func test_hashptr_subkey_wrapper_sub_set_verify_store {
/* DOCUMENT p_subkey_wrapper() stores given value when key does not already
 * exist */
   obj = p_new();
   p_subkey_wrapper, obj, "test", 1, p_new(a=1);
   tc_assert, p_has(obj, test=);
   tc_assert, p_has(p_get(obj, test=), a=);
}

func test_hashptr_subkey_wrapper_sub_set_verify_replace {
/* DOCUMENT p_subkey_wrapper() replaces key with given value when key exists */
   obj = p_new(test=p_new(a=1));
   p_subkey_wrapper, obj, "test", 1, p_new(b=1);
   tc_assert, p_has(p_get(obj, test=), b=);
   tc_assert_false, p_has(p_get(obj, test=), a=);
}

func test_hashptr_subkey_wrapper_fnc_return_exist_val {
/* DOCUMENT p_subkey_wrapper() returns the correct value, when working with
 * non-pointer values */
   obj = p_new(test=25);
   result = p_subkey_wrapper(obj, "test", 0, []);
   tc_assert_equal, 25, result;
}

func test_hashptr_subkey_wrapper_fnc_return_exist_ptr {
/* DOCUMENT p_subkey_wrapper() returns the correct value, when working with
 * pointer values */
   obj = p_new(test=p_new());
   result = p_subkey_wrapper(obj, "test", 0, []);
   tc_assert_equal, p_get(obj, test=), result;
}
