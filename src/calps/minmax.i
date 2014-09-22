// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_minmax(ary, &mn, &mx) {
/* DOCUMENT
  idxs = minmax(ary);
  minmax, ary, minidx, maxidx;

  Returns the min and max indices in the given array. This is a fall-back
  function for when CALPS is unavailable; the compiled version is much faster
  than the native min and max operators when working over a full array.
*/
  mn = min(ary);
  mx = max(ary);
  return [mn, mx];
}
if(!is_func(minmax)) minmax = nocalps_minmax;
