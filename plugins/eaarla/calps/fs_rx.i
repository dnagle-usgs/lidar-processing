// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_eaarl_fs_rx_cent_eaarlb(pulses) {
/* DOCUMENT eaarl_fs_rx_cent_eaarlb, pulses
  Updates the given pulses oxy group object with first return info using the
  centroid from the specified channel. The following fields are added to
  pulses:
    frx - Location in waveform of first return
    fint - Peak intensity value of first return
    fchannel - Channel used (=channel except for chan 4, which uses 2)
    fbias - The channel range bias (ops_conf.chn%d_range_bias)
*/
  extern ops_conf;

  npulses = numberof(pulses.tx);
  // 10000 is the "bad data" value that cent will return, match that
  frx = array(float(10000), npulses);
  fint = array(float, npulses);
  fchannel = pulses.channel;

  w = where(fchannel == 4);
  if(numberof(w))
    fchannel(w) = 2;

  fbias = [
    ops_conf.chn1_range_bias,
    ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias
  ](fchannel);

  for(i = 1; i <= npulses; i++) {
    wf = *pulses.rx(fchannel(i),i);
    np = numberof(wf);

    // Give up if not at least 2 points
    if(np < 2) continue;

    np = min(np, 12);

    rx_cent = cent(wf);
    if(numberof(rx_cent)) {
      frx(i) = rx_cent(1);
      fint(i) = rx_cent(3);

      nsat = numberof(where(wf(1:np) <= 1));
      fint(i) += (20 * nsat);
    }
  }

  save, pulses, frx, fint, fchannel, fbias;
}
if(!is_func(eaarl_fs_rx_cent_eaarlb))
  eaarl_fs_rx_cent_eaarlb = nocalps_eaarl_fs_rx_cent_eaarlb;
