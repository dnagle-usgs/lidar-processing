// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "general.i";
require, "yeti.i";

func set_contains(A, b) {
/* DOCUMENT set_contains(A, b)
  Returns an array of boolean values indicating which values in b are
  contained in A.
*/
  common = set_intersection(b, A);
  count = numberof(common);
  if(is_scalar(b)) return count;
  result = array(0, dimsof(b));
  for(i = 1; i <= count; i++)
    result(where(b == common(i))) = 1;
  return result;
}

func set_intersection(A, B, idx=) {
/* DOCUMENT set_intersection(A, B, idx=)

  Returns the intersection of the sets represented by A and B.

  The intersection of A and B is the set of all elements that occur in A that
  also occur in B.

  The elements of set_intersection(a,b) and set_intersection(b,a) will be the
  same, but the arrays will not be ordered the same.

  Options:

    idx= Set to 1 and the index of the intersection set into A will be
      returned instead of the elements.
*/
  default, idx, 0;
  return _set_intersection_master(A, B, 1, idx);
}

func set_difference(A, B, idx=) {
/* DOCUMENT set_difference(A, B, idx=)

  Returns the difference of the sets represented by A and B.

  The difference of A - B is the set of all elements that occur in A that do
  not occur in B.

  The elements of set_difference(a,b) and set_difference(b,a) will usually be
  completely different.

  To obtain a set S's complement when S is a subset of X, use
  set_difference(X,S).

  Options:

    idx= Set to 1 and the index of the difference set into A will be returned
      instead of the elements.
*/
  default, idx, 0;
  return _set_intersection_master(A, B, 0, idx);
}

func _set_intersection_master(A, B, flag, idx) {
/* DOCUMENT _set_intersection_master(A, B, flag, idx)
  Master function for set_intersection and set_difference. See
  set_intersection or set_difference for explanation of parameters.

  FLAG should be 0 for difference and 1 for intersection.

  Depending on input and on available functions, this will call one of the
  following:
    _yset_intersect_double
    _yset_intersect_long
    _set_intersect_generic
*/
  // Trivial cases
  if(! numberof(A))
    return [];
  if(! numberof(B)) {
    if(flag)
      return [];
    else
      return idx ? indgen(numberof(A)) : A;
  }

  if(is_scalar(A)) {
    aw = [1];
    A = [A];
  } else {
    aw = set_remove_duplicates(A, idx=1);
    A = A(aw);
  }
  B = set_remove_duplicates(B);
  an = numberof(aw);
  bn = numberof(B);
  ai = bi = 1;
  C = array(long(!flag), numberof(aw));
  if(
    is_numerical(A) && is_numerical(B) && is_func(_yset_intersect_long) &&
    is_func(_yset_intersect_double)
  ) {
    if(is_real(A) || is_real(B)) {
      // 0. is for delta
      _yset_intersect_double, C, A, an, B, bn, flag, 0.;
    } else {
      _yset_intersect_long, C, A, an, B, bn, flag;
    }
  } else {
    _set_intersect_generic, C, A, an, B, bn, flag;
  }
  index = where(C);
  if(idx)
    return aw(index);
  if(numberof(index))
    return A(index);
  else
    return [];
}

func _set_intersect_generic(C, A, An, B, Bn, flag) {
/* DOCUMENT _set_intersect_generic, C, A, An, B, Bn, flag;
  Helper for _set_intersect_master suitable for using on any input that can be
  compared element-by-element.
*/
  ai = bi = 1;
  while(ai <= an && bi <= bn) {
    if(A(ai) == B(bi)) {
      C(ai) = flag;
      ai++;
      bi++;
    } else {
      if(A(ai) < B(bi))
        ai++;
      else
        bi++;
    }
  }
}

func set_intersect3(A, B) {
/* DOCUMENT result = set_intersect3(A, B)

  Returns the intersection and differences between sets A and B. Return result
  will be a Yorick group object.

    result.left  -or-  result(1)
      Items in A that are not in B. (A - B)
    result.both  -or-  result(2)
      Items in both A and B. (A * B)
    result.right  -or-  result(3)
      Items in B that are not in A. (B - A)

  Unlike other set commands, this does not accept the idx= option.
*/
  C = set_union(A, B);
  state = array(0, numberof(C));
  idx = set_intersection(C, A, idx=1);
  if(numberof(idx))
    state(idx)--;
  idx = set_intersection(C, B, idx=1);
  if(numberof(idx))
    state(idx)++;
  result = save();
  w = where(state == -1);
  save, result, left=(numberof(w) ? C(w) : []);
  w = where(state == 0);
  save, result, both=(numberof(w) ? C(w) : []);
  w = where(state == 1);
  save, result, right=(numberof(w) ? C(w) : []);
  return result;
}

func set_symmetric_difference(A, B) {
/* DOCUMENT set_symmetric_difference(A, B)

  Returns the symmetric difference of the sets represented by A and B.

  The symmetric difference of A and B is all elements that occur in A or that
  occur in B, but that do not occur in both A and B.

  The elements of set_symmetric_difference(a,b) and
  set_symmetric_difference(b,a) will be the same, but the arrays may not be
  ordered the same.
*/
  return grow(set_difference(A, B), set_difference(B, A));
}

func set_union(A, B) {
/* DOCUMENT set_union(A, B)

  Returns the union of the sets represented by A and B.

  The union of A and B is the set of all elements that occur in A or in B.
  (Elements are not duplicated.)

  The elements of set_union(a,b) and set_union(b,a) will be the same, but the
  arrays may not be ordered the same.
*/
  return set_remove_duplicates(grow(A, B));
}

func set_remove_duplicates(A, idx=) {
/* DOCUMENT set_remove_duplicates(A, idx=)

  Returns the set A with its duplicate elements removed. The returned list
  will also be sorted.

  If idx=1, then the indices will be returned rather than the values.

  Usage with idx= is deprecated; use uniq instead.
*/
  default, idx, 0;
  if(idx) return unique(A);
  if(is_void(A)) return [];
  if(numberof(A) == 1) return A(1);
  return A(unique(A));
}

local munique, munique_obj;
/* DOCUMENT idx = munique(x1, x2, x3, ...)
  idx = munique_obj(obj)
  idx = munique_obj(obj, tie)

  Given one or more arrays to be considered in parallel (or an object with
  members to be considered in parallel), returns an index list that specifies
  the unique items, in sorted order.

  If tie is provided to munique_obj, it is used to determine which among a set
  of duplicates should be kept. The duplicates will be sorted by it (via
  msort_obj(tie)) and the first kept.

  SEE ALSO: unique munique_array msort
*/

func munique_obj(obj, tie) {
  srt = tie ? msort_obj(obj_merge(obj, tie)) : msort_obj(obj);
  if(numberof(srt) < 2) return srt;
  idx = indgen(2:numberof(srt));
  for(i = 1; i <= obj(*); i++) {
    work = obj(noop(i));
    if(is_void(work)) continue;
    w = where(work(srt(idx)) == work(srt(idx-1)));
    if(!numberof(w)) return srt;
    idx = idx(w);
  }
  keep = array(1, numberof(srt));
  keep(idx) = 0;
  return srt(where(keep));
}

func munique(x, ..) {
  obj = save(string(0), x);
  while(more_args()) save, obj, string(0), next_arg();
  return munique_obj(obj);
}

func munique_array(x, which) {
/* DOCUMENT munique_array(x, which)
  This is like munique, but instead of operating over multiple arrays, it
  operates over a single array along one of its dimensions (like msort_array).
  The WHICH parameter specifies which dimension to use, defaulting to the
  smallest.

  SEE ALSO: unique munique msort_array
*/
  dims = dimsof(x);
  default, which, dims(2:)(mnx);

  // Juggle dimensions so that we can index into final dimension
  if(which != dims(1))
    x = transpose(x, indgen(dims(1):which:-1));

  count = dims(which+1);
  mxrank = numberof(x(..,1))-1;
  rank = msort_rank(x(..,1));

  norm = 1./(mxrank+1.);
  if(1.+norm == 1.) error, pr1(mxrank+1)+" is too large an array";

  for(i = 2; i <= count && max(rank) != mxrank; i++) {
    rank += msort_rank(x(..,i))*norm;
    rank = msort_rank(rank);
  }

  return unique(rank);
}
