// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_uniq(A) {
/* DOCUMENT uniq(x)
  Returns an array of longs such that X(sort(X)) is a monotonically increasing
  array of the unique values of X. X can contain integer, real, or string
  values. X may have any dimensions, but the return result will always be
  one-dimensional. If multiple elements have the same value, the index of the
  first value will be used.
*/
  // Trivial/edge cases
  if(! numberof(A))
    return [];
  if(numberof(A) == 1)
    return [1];

  if(typeof(A) == "string") {
    // Hash table is faster than sorting for strings in Yorick.

    // Create a hash table that has a key for each unique item. Set the value
    // to the first index we found it at.
    set = h_new();
    for(i = numberof(A); i; i--) {
      h_set, set, A(i), i;
    }
    A = [];

    // Sort the list.
    keys = h_keys(set);
    keys = keys(sort(keys));

    // Manually extract indexes from the hash.
    idx = array(long, dimsof(keys));
    for(i = 1; i <= numberof(keys); i++) {
      idx(i) = set(keys(i));
    }
    return idx;
  }

  if(is_func(_ymergeuniq_L) && is_integer(A)) {
    count = numberof(A);
    unq = array(long, count);
    _ymergeuniq_L, A, unq, count;
    unq = unq(:count);
    return unq;
  }
  if(is_func(_ymergeuniq_D) && is_real(A)) {
    count = numberof(A);
    unq = array(long, count);
    _ymergeuniq_D, A, unq, count;
    unq = unq(:count);
    return unq;
  }

  // Eliminate any dimensionality
  A = unref(A)(*);
  // Index list
  idx = indgen(numberof(A));

  // Sort them; msort makes sure the first of equal items gets used. This costs
  // a bit but is necessary for compatibility.
  srt = msort(A,idx);

  // Eliminate duplicates in the sorted sequence
  unq = where(grow([1n], A(srt)(:-1) != A(srt)(2:)));

  return idx(srt)(unq);
}

if(!is_func(uniq)) uniq = nocalps_uniq;
