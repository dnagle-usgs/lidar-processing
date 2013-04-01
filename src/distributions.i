// vim: set ts=2 sts=2 sw=2 ai sr et:

func log_normal(x, mean, stdev, xshift=, xscale=, yshift=, yscale=, peakx=,
peaky=) {
/* DOCUMENT y = log_normal(x, mean, stdev)
  -OR- y = log_normal(x, mean, stdev, xshift=, xscale=, yshift=, yscale=)
  -OR- y = log_normal(x, mean, stdev, xscale=, yshift=, peakx=, peaky=)

  In the first form, returns the log-normal distribution of X using the given
  mean and standard deviation values. X must be a standard normal variable
  (that is, it should have mean 0 and standard deviation 1).

  In the second form, returns y such that the following equations hold:
    xp = (x + xshift) / xscale
    yp = (y + yshift) / yscale
    yp = log_normal(xp, mean, stdev)
  In other words, the four optional parameters define how to transform your X
  and Y values into corresponding standard normal variable values.

  In the third form, xshift= and/or yscale= are automatically calculated. If
  peakx= is provided, then xshift is calculated such that the peak of the
  distribution will occur at x=peakx. If peaky= is provided, then yscale is
  calculated such that the peak of the distribution will have value y=peaky.

  Not illustrated above, but you can also use the following two combinations of
  options as a mix of the second and third forms:
    xshift=, xscale=, yshift=, peaky=
    xscale=, yshift=, yscale=, peakx=
  If you supply xshift= and peakx= together, your xshift= value will be ignored
  without warning/error. Similarly, if you supply yscale= and peaky= together,
  your yscale= value will be ignored without warning/error.
*/
  default, xshift, 0.;
  default, xscale, 1.;
  default, yshift, 0.;
  default, yscale, 1.;
  // no defaults for peakx or peaky

  if(!xscale) error, "xscale= must not be zero";

  // Convenience variable so that we don't repeatedly square stdev
  variance = stdev^2;

  // If peakx or peaky are provided, calculate xshift and/or yscale.
  if(!is_void(peakx) || !is_void(peaky)) {
    // Formula for the point of global maximum:
    pkx = exp(mean - variance);

    if(!is_void(peakx)) {
      xshift = (pkx*xscale) - peakx;
    }
    if(!is_void(peaky)) {
      pky = log_normal(pkx, mean, stdev);
      yscale = peaky / pky;
    }

    pkx = pky = [];
  }

  if(!yscale) error, "yscale= must not be zero";

  // Convert X into standard normal values
  xp = (x + xshift) / double(xscale);

  // The exp function will not work on values <= 0, so force them to 0 and only
  // calculate where values are positive.
  yp = array(0., dimsof(xp));
  w = where(xp > 0);
  if(numberof(w)) {
    xpw = xp(w);
    yp(w) = exp(-(log(xpw)-mean)^2/(2*variance)) / (xpw*sqrt(2*pi*variance));
    xpw = [];
  }

  // Convert YP back into Y
  return (yp * yscale) - yshift;
}
