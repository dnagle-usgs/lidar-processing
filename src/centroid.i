// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func pcr(rast, pulse) {
/* DOCUMENT pcr(rast, pulse)

  Computes the centroid of the transmit and return pulses, then derives a
  range value that corrects for signal level range walk. The most sensitive
  return that is not saturated will be used.

  Parameters:
    rast: A raster array of type RAST.
    pulse: The pulse number within the raster to use.

  **Important** The centroid calculations do not include corrections for
  range_bias.

  Return result is array(double, 4) where:
    result(1) = Centroid corrected range
    result(2) = Return's peak power
    result(3) = Number of saturated pixels in transmit waveform

  Note: result(2), return power, contains values ranging from 0 to 900 digital
  counts. The values are contained in three discrete ranges and each range
  cooresponds to a return channel.  Values from 0-255 are from channel 1, from
  300-555 are from channel 2, and from 600-855 are from channel 3.  Channel 1
  is the most sensitive and channel 3 the least.

  SEE ALSO: RAST, cent
*/
  extern ops_conf;
  if(pulse == 0)
    return [];

  // Return values
  result = array(float,3);

  // find out how many waveform points are in the primary (most sensitive)
  // receiver channel
  np = numberof(*rast.rx(pulse,1));

  // give up if there are not at least two points
  if(np < 2) return;

  // use no more than 12
  np = min(np,12);

  if(numberof(*rast.tx(pulse)) > 0)
    result(3) = (*rast.tx(pulse) == 0)(sum);

  // compute transmit centroid
  tx_centroid = cent(*rast.tx(pulse))(1);

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

  if((numberof(where(((*rast.rx(pulse,1))(1:np)) < 5))) <= ops_conf.max_sfc_sat) {
    cv = cent(*rast.rx(pulse,1));
    // Must be water column only return.
    if(cv(3) < -90) {
      slope = 0.029625;
      x = cv(3) - 90;
      y = slope * x;
      cv(1) += y;
    }
    cv(1:2) += ops_conf.chn1_range_bias;
  } else if(numberof(where(((*rast.rx(pulse,2))(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
    cv = cent(*rast.rx(pulse,2));
    cv(1:2) += ops_conf.chn2_range_bias;
    cv(3) += 300;
  } else {
    cv = cent(*rast.rx(pulse,3));
    cv(1:2) += ops_conf.chn3_range_bias;
    cv(3) += 600;
  }

  // Now compute the actual range value in NS
  result(1) = float(rast.irange(pulse)) - tx_centroid + cv(1);
  result(2) = cv(3);

  // This will be needed to compute true depth
  result(3) = cv(1);
  return result;
}

func cent(raw_wf) {
/* DOCUMENT cent(a)
  Compute the centroid of "raw_wf" using the no more than the first 12 points.
  This function considers the entire pulse and is probably only good for solid
  first-return targets or bottom pulses.

  Return result is array(double, 3):
    result(1) = centroid range
    result(2) = peak range
    result(3) = peak power
*/
  if(numberof(raw_wf) < 2)
    return [0., 0., 0.];

  // flip it over and convert to signed short
  wf = -short(raw_wf);
  // remove bias using first point of wf
  wf -= wf(1);

  // Find maximum value & associated index
  max_index = wf(mxx);
  max_intensity = wf(max_index);

  centroid = min(wf_centroid(wf, lim=12), 10000.);
  return [centroid, max_index, max_intensity];
}
