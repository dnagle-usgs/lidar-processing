// vim: set ts=2 sts=2 sw=2 ai sr et:

func pcr(rast, pulse, forcechannel=) {
/* DOCUMENT pcr(rast, pulse, forcechannel=)

  Computes the centroid of the transmit and return pulses, then derives a
  range value that corrects for signal level range walk. The most sensitive
  return that is not saturated will be used.

  Parameters:
    rast: A raster array of type RAST.
    pulse: The pulse number within the raster to use.

  **Important** The centroid calculations do not include corrections for
  range_bias. They do however include corrections for chn1_range_bias,
  chn2_range_bias, and chn3_range_bias as necessary.

  Return result is array(double, 3) where:
    result(1) = Centroid corrected range
    result(2) = Return's peak power
    result(3) = Centroid range for rx waveform

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

  // compute transmit centroid
  tx_centroid = cent(*rast.tx(pulse));

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
      if(nsat1 > 1) rx_centroid(1) = rx_centroid(1) - (nsat1 -1 ) * .1;
    This would go in the first "if" statement below.
  */

  channel = 0;
  if(!is_void(forcechannel)) {
    channel = (forcechannel == 4 ? 2 : forcechannel);
    rx = *rast.rx(pulse,channel);
    if(!numberof(rx)) return;
    rx_centroid = cent(rx);
    rx_centroid(1:2) += get_member(ops_conf,
        swrite(format="chn%d_range_bias", channel));
    nsat = numberof(where(rx(1:np) <= 1));
    // This ensures we get contrast even on waveforms where the peak is
    // saturated.
    rx_centroid(3) += (20 * nsat);
  } else {
    rx = rast.rx(pulse,);
    if((numberof(where((*rx(1))(1:np) < 5))) <= ops_conf.max_sfc_sat) {
      channel = 1;
      rx_centroid = cent(*rx(1));
      // Must be water column only return.
      if(rx_centroid(3) < -90) {
        slope = 0.029625;
        x = rx_centroid(3) - 90;
        y = slope * x;
        rx_centroid(1) += y;
      }
      rx_centroid(1:2) += ops_conf.chn1_range_bias;
    } else if(numberof(where((*rx(2))(1:np) < 5)) <= ops_conf.max_sfc_sat) {
      channel = 2;
      rx_centroid = cent(*rx(2));
      rx_centroid(1:2) += ops_conf.chn2_range_bias;
      rx_centroid(3) += 300;
    } else {
      channel = 3;
      rx_centroid = cent(*rx(3));
      rx_centroid(1:2) += ops_conf.chn3_range_bias;
      rx_centroid(3) += 600;
    }
  }

  restore, hook_invoke("pcr_centroids",
    save(rx_centroid, tx_centroid, rast, pulse, channel));

  // Now compute the actual range value in sample counts
  result(1) = float(rast.irange(pulse)) - tx_centroid(1) + rx_centroid(1);
  result(2) = rx_centroid(3);

  // This will be needed to compute true depth
  result(3) = rx_centroid(1);
  return result;
}
