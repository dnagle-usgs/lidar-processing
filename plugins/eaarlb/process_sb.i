// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(sbconf)) sbconf = sbconfobj();

func process_sb(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_sb(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for shallow bathy.

  Parameters:
    start: Raster number to start at. This may also be an array.
    stop: Raster number to stop at. This may also be an array and must match
      the size of START. If omitted, STOP is set to START.

  Options:
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options.

  Returns:
    An oxy group object containing these fields:
      from eaarl_decode_fast: digitizer, dropout, pulse, irange, scan_angle,
        raster, soe, tx, rx
      from process_fs: ftx, channel, frx, fint, fchannel, fbias,
        fs_slant_range, mx, my, mz, fx, fy, fz
      added by process_sb: ltx, lrx, lint, lbias, lchannel, lx, ly, lz
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel;

  default, channel, 1;

  sample_interval = 1.0;
  sb_tx = eaarl_sb_tx_copy;
  sb_rx = eaarl_sb_rx_channel;

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_sb_funcs", save(sb_tx, sb_rx));

  // Start out by processing for first surface
  pulses = process_fs(start, stop, ext_bad_att=ext_bad_att, channel=channel);
  if(is_void(pulses)) return;

  // Throw away any pulses that are equal to or above the mirror
  w = where(pulses.fz < pulses.mz);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ltx
  sb_tx, pulses;

  // Determine rx offsets; adds lrx, lint, lbias, lchannel; updates fint
  sb_rx, pulses;

  // Throw away lchannel == 0
  w = where(pulses.lchannel);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Throw away where last return not found
  w = where(pulses.lrx > 0);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Adjusted offset in sample counts to surface
  fscnt = pulses.frx - pulses.ftx + pulses.fbias;
  // Adjusted offset in sample counts to bottom
  sbcnt = pulses.lrx - pulses.ltx + pulses.lbias;

  // Distance from surface to bottom
  dist = (sbcnt - fscnt) * sample_interval * NS2MAIR;
  fscnt = sbcnt = [];

  // Throw away bottoms that are above surface
  w = where(dist >= 0);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);
  dist = dist(w);

  ref = [pulses.mx, pulses.my, pulses.mz];
  fs = [pulses.fx, pulses.fy, pulses.fz];

  // Edge case: Coerce into two-dimensional arrays
  if(is_scalar(pulses.mx)) {
    ref = reform(ref, [2, 1, 3]);
  }
  if(is_scalar(pulses.fx)) {
    fs = reform(fs, [2, 1, 3]);
  }

  // Project and correct for refraction and speed of light in water
  be = point_project(ref, fs, dist, tp=1);
  sb = snell_be_to_bathy(fs, be);
  be = [];

  // Edge case: Coerce back to one-dimensional, if needed
  if(is_scalar(pulses.fx)) {
    sb = reform(sb, [1, 3]);
  }

  save, pulses, lx=sb(..,1), ly=sb(..,2), lz=sb(..,3);
  return pulses;
}

func eaarl_sb_tx_copy(pulses) {
/* DOCUMENT eaarl_sb_tx_copy, pulses
  Updates the given pulses oxy group with the last return transmit location.
  This function simply copies the first return transmit, since the transmit
  should be the same for both. This adds the following field to pulses:
    ltx - Location of peak in transmit
*/
  save, pulses, ltx=pulses.ftx;
}

func eaarl_sb_rx_channel(pulses) {
/* DOCUMENT eaarl_sb_rx_channel, pulses
  Updates the given pulses oxy group object with shallow bathy last return
  info. This uses the same channel that was used for the first return. The
  following fields are added to pulses:
    lrx - Location in waveform of bottom
    lint - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fint - Intensity at location deemed as surface by veg algorithm
*/
  local conf;
  extern ops_conf;

  sb_rx_wf = eaarl_sb_rx_wf;

  biases = [ops_conf.chn1_range_bias, ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias, ops_conf.chn4_range_bias];

  npulses = numberof(pulses.tx);

  lrx = fint = lint = lbias = array(float, npulses);
  rets = array(char, npulses);
  lchannel = pulses.channel;

  for(i = 1; i <= npulses; i++) {
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;

    conf = sbconf(settings, lchannel(i));
    lbias(i) = biases(lchannel(i));

    tmp = sb_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lint(i) = tmp.lint;
    lrx(i) = tmp.lrx;
    rets(i) = tmp.rets;
  }

  save, pulses, lrx, lint, lbias, lchannel, rets;
}

func eaarl_sb_plot(raster, pulse, channel=, win=, xfma=) {
/* DOCUMENT eaarl_sb_plot, raster, pulse, channel=, win=, xfma=
  Executes the shallow bathy algorithm for a single pulse and plots the result.

  The plot will consist of the following elements:
    - The waveform will be plotted in black; the portion examined will be
      solid, the rest will be dotted
    - The first derivitive will be plotted in red
    - The location of each leading edge will be marked with a hollow red
      triangle
    - The location of the last leading edge (the one used for the last return)
      will be marked with a solid red triangle
    - The section of the waveform that will be examined for a peak will be
      highlighted in blue
    - The peak found will be marked with a solid blue square

  Additionally, three values will be displayed to the console:
    - lrx, which is where the peak was found (sample number in wf)
    - lint, which is the intensity at the peak
    - rets, which is how many leading edges (and thus candidate returns) were
      detected; this number will match how many triangles are plotted

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
  Options:
    channel= Channel to force use of. Default is 1.
    win= Window to plot in. Defaults to 26.
    xfma= Whether to clear plot first. Defaults to 1.
*/
  default, channel, 1;
  default, win, 26;
  default, xfma, 1;

  local conf;

  sb_rx_wf = eaarl_sb_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_sb_rx_funcs", save(sb_rx_wf));

  wbkp = current_window();
  window, win;

  tkcmd, swrite(format=
    "::eaarl::sbconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
    win, raster, pulse, channel, sbconf(settings_group, channel));

  pulses = decode_rasters(raster, raster);
  w = where(pulses.pulse == pulse);
  if(!numberof(w)) {
    write, format=" raster %d does not contain pulse %d\n",
      raster, pulse;
    window_select, wbkp;
    return;
  }
  pulses = obj_index(pulses, w(1));
  conf = sbconf(settings, channel);

  write, format=" shallow bathy analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(channel);

  if(xfma) fma;

  result = sb_rx_wf(*pulses.rx(channel), conf, plot=1);

  pltitle, swrite(format="shallow - rn:%d pulse:%d chan:%d",
    raster, pulse, channel);
  xytitles, "Sample Number", "Sample Counts (Relative Intensity)";

  window_select, wbkp;

  write, format="   lrx: %.2f\n   lint: %.2f\n   rets: %d\n",
    double(result.lrx), double(result.lint), long(result.rets);

  if(!result.lrx) {
    write, format="   %s\n", "No return found.";
  }
}

func eaarl_sb_rx_wf(rx, conf, &msg, plot=) {
/* DOCUMENT result = eaarl_sb_rx_wf(rx, conf, &msg, plot=)
  Determines the shallow bathy result for the given waveform.

  Parameters:
    rx - Raw waveform, an array of char
    conf - Conf object (from bathconf)
    msg - Output parameter that specifies a status message
  Options:
    plot= Set to 1 to enable plotting; disabled by default

  Returns:
    An oxy group object with these members:
      lrx - location of last surface in waveform
      lint - intensity at last surface
      rets - number of returns found

    rv:
      sa = scan angle
      mx1 = first pulse index         -> frx - dropped
      mv1 = first pulse peak value    -> fint - dropped
      mx0 = last pulse index          -> lrx
      mv0 = last pulse peak value     -> lint
      nx = number of returns          -> rets
*/
  conf = obj_copy(conf);
  sample_interval = 1.0;

  result = save(lrx=0, lint=0, rets=0);

  // Retrieve the waveform, figure out the max intensity value, and remove
  // bias
  wf = float(~(rx));
  bias = wf(1:min(15,numberof(wf)))(min);
  maxint = 255 - long(bias);
  wf -= bias;

  // Constant: how many samples into the wf to look
  max_samples = 20;

  if(plot && numberof(wf) > max_samples) {
    // Plot original waveform prior to truncation
    xaxis = indgen(max_samples:numberof(wf));
    plg, wf(max_samples:), xaxis, color="black", type="dot";
  }
  if(numberof(wf) > max_samples) wf = wf(:max_samples);

  wflen = numberof(wf);

  // dd -> wfd1
  // First derivative of waveform
  wfd1 = wf(dif);

  // xr -> edges
  // Find the starting points where the first derivitive exceeds the threshold.
  // These are the locations of the pulse edges.
  edges = where((wfd1 >= conf.thresh)(dif) == 1);

  save, result, rets = numberof(edges);

  if(plot) {
    xaxis = indgen(numberof(wf));
    plg, wfd1, xaxis(:-1)+.5, color="red";
    plmk, wf, xaxis, color="black", msize=.2, marker=1;
    plg, wf, xaxis, color="black";
  }

  if(!numberof(edges)) {
    save, result, fint=wf(max), lint=wf(max);
    return result;
  }

  if(plot) {
    // Use an equilateral triangle as a marker, but moved up a smidge
    marker = [[0,-.5,.5],[0,.866,.866]+.25];
    plmk, wf(edges+1), xaxis(edges+1), marker=marker, msize=.01, color="red",
      width=1;
  }

  // Determine the length of the section of the waveform that represents the
  // last return (starting from the last edge). Assume 18ns to be longest
  // duration for a complete last return. But truncate based on length of
  // waveform.
  max_ret_len = min(18, wflen - edges(0) - 1);

  // Noise pulses
  if(max_ret_len < 5) return result;

  // Find where the bottom return pulse changes direction after its trailing
  // edge.
  rng = edges(0)+1:edges(0)+max_ret_len;
  wneg = where(wfd1(rng) < 0);

  if(plot) {
    plg, wf(rng), xaxis(rng), color="blue";
    plmk, wf(edges(0)+1), xaxis(edges(0)+1), marker=marker, msize=.01,
      color="red", width=10;
  }

  if(numberof(wneg)) {
    save, result, lrx = edges(0) + wneg(1);
    save, result, lint = wf(result.lrx);

    if(plot) {
      plmk, result.lint, result.lrx, color="blue", marker=1, msize=.5,
        width=10;
    }
  }

  return result;
}
