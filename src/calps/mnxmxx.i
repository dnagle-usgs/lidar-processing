// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_mnxmxx(ary, &mn, &mx) {
/* DOCUMENT
  idxs = mnxmxx(ary);
  mnxmxx, ary, minidx, maxidx;

  Returns the min and max indices in the given array. This is a fall-back
  function for when CALPS is unavailable; the compiled version is much faster
  than the native mnx and mxx operators when working over a full array.
*/
  mn = ary(*)(mnx);
  mx = ary(*)(mxx);
  return [mn, mx];
}
if(!is_func(mnxmxx)) mnxmxx = nocalps_mnxmxx;
