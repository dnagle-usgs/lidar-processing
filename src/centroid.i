// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func pcr(rast, n) {
/* DOCUMENT pcr(rast,n)

  Computes the centroid of the transmit and return pulses, then derives a
  range value that corrects for signal level range walk. The most sensitive
  return that is not saturated will be used.

  Parameters:
    rast: A raster array of type RAST.
    n: The pixel within the raster to use.

  **Important** The centroid calculations do not include corrections for
  range_bias.

  Return result is array(double, 4) where:
    result(1) = Centroid corrected range
    result(2) = Return's peak power
    result(3) = Uncorrected irange value
    result(4) = Number of saturated pixels in transmit waveform

  Note: result(2), return power, contains values ranging from 0 to 900 digital
  counts. The values are contained in three discrete ranges and each range
  cooresponds to a return channel.  Values from 0-255 are from channel 1, from
  300-555 are from channel 2, and from 600-855 are from channel 3.  Channel 1
  is the most sensitive and channel 3 the least.

  SEE ALSO: RAST, cent
*/
  extern ops_conf;
  if(n == 0)
    return [];

  // Return values
  rv = array(float,4);

  // find out how many waveform points are in the primary (most sensitive)
  // receiver channel
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

  /*
    Now examine all three receiver waveforms for saturation, and use the one
    that's next to the channel thats offscale.

    First check the most sensitive channel (1), and if it's offscale, then
    check (2), and then (3).  A channel is considered offscale if more than 2
    pixels are equal to zero.  Signals are inverted, which means the base
    line is around 240 counts and signal strength goes toward zero.  An
    offscale pixel value would equal zero.

    Note 1) This attempts to corect range walk for situations where wf0 had
      to be used for range even when saturated.  The 2-16-04 Bombay-hook
      dataset for example.  On that mission, the wf0 was offscale while wf1
      was disconected and did not produce a return.  This line tries to
      correct by examining the number of saturated points, and then
      correcting the centroid range by 0.2ns (3cm) for each saturated point.

    Code for note 1:
      if(nsat1 > 1) cv(1) = cv(1) - (nsat1 -1 ) * .1;
    This would go in the first "if" statement below.
  */

  if((numberof(where(((*rast.rx(n,1))(1:np)) < 5))) <= ops_conf.max_sfc_sat) {
    cv = cent( *rast.rx(n, 1 ) );
    // Must be water column only return.
    if(cv(3) < -90) {
      slope = 0.029625;
      x = cv(3) - 90;
      y = slope * x;
      cv(1) += y;
    }
    cv(1:2) += ops_conf.chn1_range_bias;
  } else if(numberof(where(((*rast.rx(n,2))(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
    cv = cent(*rast.rx(n, 2));
    cv(1:2) += ops_conf.chn2_range_bias;
    cv(3) += 300;
  } else {
    cv = cent(*rast.rx(n, 3));
    cv(1:2) += ops_conf.chn3_range_bias;
    cv(3) += 600;
  }

  // Now compute the actual range value in NS
  rv(1) = float(rast.irange(n)) - ctx(1) + cv(1);
  rv(2) = cv(3);
  rv(3) = rast.irange(n);

  // This will be needed to compute true depth
  rv(4) = cv(1);
  return rv;
}

func cent(a) {
/* DOCUMENT cent(a)
  Compute the centroid of "a" using the no more than the first 12 points.
  This function considers the entire pulse and is probably only good for solid
  first-return targets or bottom pulses.

  Return result is array(double, 3):
    result(1) = centroid range
    result(2) = peak range
    result(3) = peak power
*/
  if(numberof(a) < 2)
    return [0., 0., 0.];

  // flip it over and convert to signed short
  a = -short(a);
  // remove bias using first point of wf
  a -= a(1);

  // Find maximum value & associated index
  mv = a(max);
  mx = a(mxx);

  c = min(wf_centroid(a, lim=12), 10000.);
  return [c, mx, mv];
}

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
