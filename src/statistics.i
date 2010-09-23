// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func covariance(x, y) {
/* DOCUMENT covariance(x, y)
   Returns the covariance of the two variables.
*/
   x -= x(avg);
   y -= y(avg);
   return (x*y)(sum)/numberof(x);
}

func quartiles(ary) {
/* DOCUMENT quartiles(ary)
   Returns the first, second, and third quartiles for the array.
   SEE ALSO: median
*/
   ary = ary(sort(ary));
   q1 = median(ary(:numberof(ary)/2));
   q2 = median(ary);
   q3 = median(ary(::-1)(:numberof(ary)/2));
   return [q1, q2, q3];
}

func mode(x, binsize=) {
/* DOCUMENT mode(x, binsize=)
   Returns the mode of the given distribution. Option BINSIZE specifies the
   width of the bins to be used when calculating the distribution's histogram.
   By default, binsize=1 (which is appropriate for integer input).
*/
   default, binsize, 1;
   offset = x(min) - 1;
   X = long((x-offset)/double(binsize)+0.5);
   hist = histogram(X);
   idx = hist(mxx);
   return binsize * idx + offset;
}

func pearson_skew_1(x, binsize=) {
/* DOCUMENT person_skew_1(x, binsize=)
   Returns Person's first skewness coefficient for the given distribution. If
   binsize= is given, it is passed to the mode function.
   SEE ALSO: pearson_skew_2
*/
   xrms = x(rms);
   if(xrms)
      return (x(avg) - mode(x, binsize=binsize)) / xrms;
}

func pearson_skew_2(x) {
/* DOCUMENT pearson_skew_2(x)
   Returns Pearson's second skewness coefficient for the given distribution.
   SEE ALSO: pearson_skew_1
*/
   xrms = x(rms);
   if(xrms)
      return 3 * (x(avg) - median(x)) / xrms;
}

func pearson_correlation(x, y) {
/* DOCUMENT pearson_correlation(x, y)
   Returns Perason's product-moment correlation coefficient for the two
   variables given. Also known as "Pearson's r".
*/
   xrms = x(rms);
   yrms = y(rms);
   if(xrms && yrms)
      return covariance(x,y) / (xrms * yrms);
}
