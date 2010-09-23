// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func quartiles(ary) {
/* DOCUMENT quartiles(ary)
   Returns the first, second, and third quartiles for the array.

   See also: median
*/
// Original David Nagle 2008-03-26
   ary = ary(sort(ary));
   q1 = median(ary(:numberof(ary)/2));
   q2 = median(ary);
   q3 = median(ary(::-1)(:numberof(ary)/2));
   return [q1, q2, q3];
}

func pearson_skew_2(x) {
/* DOCUMENT pearson_skew_2(x)
   Returns Pearson's second skewness coefficient for the given distribution.
*/
   xmean = x(avg);
   xmedian = median(x);
   return 3 * (x(avg) - median(x)) / x(rms);
}
