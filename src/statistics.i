// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func rank(x, method=) {
/* DOCUMENT rank(x, method=)
  Returns an array with the ranking values for X. METHOD specifies what to do
  in the case of a tie. The following examples show the allowed values for
  METHOD as well as how it handles a tie.

    > rank([10,20,20,30], method="ordinal")
    [1,2,3,4]
      All items receive distinct rankings, including items that compare
      equal. Items that compare equal are ranked based on their order in X.

    > rank([10,20,20,30], method="fractional")
    [1,2.5,2.5,4]
      Values with equal rank are assigned the mean of the ranks they would
      have had under ordinal ranking.

    > rank([10,20,20,30], method="competition")
    [1,2,2,4]
      Values with equal rank receive the same ranking number. A gap is left
      afterwards that is equal to one less than the number of equal items.

    > rank([10,20,20,30], method="competition_mod")
    [1,3,3,4]
      Values with equal rank receive the same ranking number. A gap is left
      prior to the set that is equal to one less than the number of equal
      items.

    > rank([10,20,20,30], method="dense")
    [1,2,2,3]
      Values with equal rank receive the same ranking number. No gaps are
      left.

  The default value for METHOD is "fractional". When method="fractional", the
  return result is of type double; otherwise, it is of type long.
*/
  // Variables used:
  //    n - number of samples
  //    rx - rank values for x
  //    s - index list that sorts x
  //    xs - x, sorted as by s
  //    rsx - rx, sorted as by s

  default, method, "fractional";
  methods = ["fractional","ordinal","competition","competition_mod","dense"];
  if(noneof(method == methods))
    error, "Unknown method: "+method;

  n = numberof(x);
  if(method == "fractional")
    rx = array(double, n);
  else
    rx = array(long, n);

  s = msort(x);
  xs = x(s);
  rxs = indgen(n);

  // For method ordinal, no further work is needed.
  if(method == "ordinal") {
    rx(s) = rsx;
    return rx;
  }

  if(method == "fractional")
    rxs *= 1.;

  i = 1;
  j = 2;
  while(i < n) {
    while(xs(i) == xs(j)) j++;
    j--;
    if(i < j) {
      if(method == "fractional") {
        rxs(i:j) = rxs(i:j)(avg);
      } else if(method == "competition") {
        rxs(i:j) = rxs(i);
      } else if(method == "competition_mod") {
        rxs(i:j) = rxs(j);
      } else if(method == "dense") {
        rxs(i:j) = rxs(i);
        if(j < n)
          rxs(j+1:) -= (j - i);
      }
    }
    i = j+1;
    j = i+1;
  }
  rx(s) = rxs;
  return rx;
}

func r_squared(y, x) {
/* DOCUMENT r_squared(y, x)
  Returns the coefficient of determination for X and Y, also called "R
  squared" or "R^2". This is determined using a linear least-squares-fit of Y
  to X.
*/
  c = poly1_fit(y, x, 1);
  yp = poly1(x, c);
  return pearson_correlation(y, yp);
}

func root_mean_square(x) {
/* DOCUMENT root_mean_square(x)
  Returns the root mean square of X. The yorick built-in "rms" actually returns
  standard deviation.
*/
  return sqrt((x*x)(avg));
}

func covariance(x, y) {
/* DOCUMENT covariance(x, y)
  Returns the covariance of the two variables.
*/
  x -= x(avg);
  y -= y(avg);
  return (x*y)(sum)/numberof(x);
}

func quartiles(x) {
/* DOCUMENT quartiles(x)
  Returns the first, second, and third quartiles for X.
  SEE ALSO: median
*/
  x = x(sort(x));
  q1 = median(x(:numberof(x)/2));
  q2 = median(x);
  q3 = median(x(::-1)(:numberof(x)/2));
  return [q1, q2, q3];
}

func midhinge(x) {
/* DOCUMENT midhinge(x)
  Returns the midhinge for X. The midhinge is the average of the first and
  third quartiles.
*/
  q = quartiles(x);
  return q([1,3])(avg);
}

func trimean(x) {
/* DOCUMENT trimean(x)
  Returns the trimean (TM) for X. The trimean is the average of the median and
  midhinge.
*/
  q = quartiles(x);
  return q([1,2,2,3])(avg);
}

func interquartile_mean(x) {
/* DOCUMENT interquartile_mean(x)
  Returns the interquartile mean (IQM) of X. This is the mean of the values in
  the interquartile range. If X cannot be evenly divided into quartiles, then
  the extreme values of the interquartile range are weighted to compensate.
*/
  x = x(sort(x));
  n = numberof(x);
  // Number of observations per quartile
  obs = n/4.;
  low = long(obs + 1);
  high = long(ceil(n - obs));
  // truncate x to the points in the interquartile range
  x = x(low:high);
  n = numberof(x);
  // Fractional observation count requires weighting of first and last
  weight = array(1., n);
  if(obs != long(obs))
    weight([1,n]) = 1 - (numberof(x) - (2*obs))/2.;
  return (x * weight)(sum) / weight(sum);
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

func spearman_correlation(x, y) {
/* DOCUMENT spearman_correlation(x, y)
  Returns Spearman's rank correlation coefficient for the two variables given.
  Also known as "Spearman's rho".
*/
  rx = rank(x);
  ry = rank(y);
  return pearson_correlation(rx, ry);
}

func standard_error_of_mean(x) {
/* DOCUMENT standard_error_of_mean(x)
  Returns the standard error of the mean (SEM) of X. This is estimated by
  estimating the standard deviation and dividing by the square root of the
  sample size.
*/
  return x(rms)/sqrt(numberof(x));
}

func confidence_interval_95(x) {
/* DOCUMENT confidence_interval_95(x)
  Returns the 95% confidence interval for X. This will be a two-element array
  [lo, hi] where LO and HI are the lower and upper bounds of the interval.
*/
  // z is the constant value such that a standard normal variable X has the
  // probability of exactly .975 to fall within the interval (-inf,z]. When
  // used to bound both sides of an interval, this becomes a probability of
  // .95.
  z = 1.96;
  var = z * standard_error_of_mean(x);
  return x(avg) + [-var, var];
}

func skewness(x) {
/* DOCUMENT skewness(x)
  Returns the sample skewness of X.
*/
  xdif = x - x(avg);
  term1 = (xdif^3)(avg);
  term2 = ((xdif^2)(avg))^1.5;
  if(term2)
    return term1 / term2;
}

func kurtosis(x) {
/* DOCUMENT kurtosis(x)
  Returns the sample kurtosis of X.
*/
  xdif = x - x(avg);
  term1 = (xdif^4)(avg);
  term2 = ((xdif^2)(avg))^2;
  if(term2)
    return term1/term2 - 3;
}
