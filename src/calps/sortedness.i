// vim: set ts=2 sts=2 sw=2 ai sr et:

local nocalps_sortedness, nocalps_sortedness_obj;
/* DOCUMENT metric = sortedness(A, B, C, ...)
  metric = sortedness_obj(obj)

  Given one or more arrays to be considered in parallel (or an object with
  members to be considered in parallel), returns a value in the range -1 to 1
  that estimates the degree of sortedness present in the data. A value of 1
  means the data is likely sorted ascending. A value of -1 means the data is
  likely sorted descending. A value of 0 means the data is random. And a value
  of something like 0.8 means that the data appears to have a lot of ordering
  to it but isn't entirely sorted.

  Note that the result is only a rough estimate, based on looking at a small
  sub-set of the arrays.
*/

func nocalps_sortedness(args) {
  obj = args2obj(args);
  return sortedness_obj(obj);
}
wrap_args, nocalps_sortedness;

func nocalps_sortedness_obj(obj) {
  sortedness_max_depth = 10;
  sortedness_min_chunk = 16;
  sortedness_min_sample = 32;

  // Get rid of void items
  keep = array(1, obj(*));
  for(i = 1; i <= obj(*); i++) keep(i) = !is_void(obj(noop(i)));
  if(noneof(keep)) return 0.;
  obj = obj(where(keep));

  count = numberof(obj(1));
  gt = lt = eq = 0;

  for(
    depth = 0, chunk = count;
    depth < sortedness_max_depth && chunk >= sortedness_min_chunk;
    depth++, chunk /= 2
  ) {
    n = chunk/3;
    for(i = n; i+n < count; i+= chunk) {
      cmp = 0;
      for(j = 1; j <= obj(*); j++) {
        cur = obj(noop(j));
        if(cur(i) < cur(i+n)) {
          cmp = -1;
          break;
        } else if(cur(i) > cur(i+n)) {
          cmp = 1;
          break;
        }
      }
      if(!cmp) cmp = 1;
      if(cmp > 0) {
        gt++;
      } else if(cmp < 0) {
        lt++;
      } else {
        eq++;
      }
    }
  }
  total = gt + lt + eq;

  if(total < sortedness_min_sample) {
    n = max(1, count / (sortedness_min_sample - total));
    m = max(1, n/2);
    for(i = 0; i < count; i += n) {
      cmp = 0;
      for(j = 1; j <= obj(*); j++) {
        cur = obj(noop(j));
        if(cur(i) < cur(i+m)) {
          cmp = -1;
          break;
        } else if(cur(i) > cur(i+m)) {
          cmp = 1;
          break;
        }
      }
      if(!cmp) cmp = 1;
      if(cmp > 0) {
        gt++;
      } else if(cmp < 0) {
        lt++;
      } else {
        eq++;
      }
    }
    total = gt + lt + eq;
  }

  if(gt > lt) return ((gt + eq) / total - .5) * -2;
  return ((lt + eq) / total - .5) * 2;
}

if(!is_func(sortedness)) sortedness = nocalps_sortedness;
if(!is_func(sortedness_obj)) sortedness_obj = nocalps_sortedness_obj;
