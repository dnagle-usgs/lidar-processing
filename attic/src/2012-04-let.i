/******************************************************************************\
* Function let was moved to the attic from centroid.i on 2012-04-23. The       *
* function is no longer used and is documented as being broken.                *
\******************************************************************************/

func let(rast, n) {
/* DOCUMENT let(rast, n)
  Leading-edge-tracker algorithm.

  NOTE: This function may be broken. Please examine code and ensure it is
  doing what you expect it to be doing prior to use.

  Parameters:
    rast: A raster array of type RAST.
    n: The pixel within the raster to use.

  Return result is array(double, 4):
    result(1) = Centroid corrected range
    result(2) = Return's peak power, in digital counts
    result(3) = Uncorrected irange value
    result(4) = Number of saturated pixels in transmit waveform

  SEE ALSO: RAST, cent
*/
  // Return values
  rv = array(float,4);

  // find out how many waveform points are in the primary (most sensitive)
  // receiver channel.
  np = numberof(*rast.rx(n,1));

  // give up if there are not at least two points
  if(np < 2)
    return;

  // use no more than 12
  if(np > 12)
    np = 12;

  if(numberof(*rast.tx(n)) > 0)
    rv(4) = (*rast.tx(n) == 0)(sum);

  // compute transmit centroid
  ctx = cent(*rast.tx(n));

  cv = array(double, 3);
  a = -float(*rast.rx(n,1));
  if(numberof(a) >= 8) {
    bias = a(1:5)(avg);
    a -= bias;
    cv(1) = 0.0;
    // cv(3) = ((1000.0 * (a(7)*7 + a(8)*8)) / float(a(7) + a(8))) - 6500.;
    // cv(1) = cv(3)/140.;
    cv(3) = a(7) + a(8);
  }

  // Now compute the actual range value in NS
  rv(1) = float(rast.irange(n)) - ctx(1) + cv(1);
  rv(2) = cv(3);
  rv(3) = rast.irange(n);
  return rv;
}
