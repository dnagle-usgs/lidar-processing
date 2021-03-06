// vim: set ts=2 sts=2 sw=2 ai sr et:

func be_struct_from_obj(pulses) {
/* DOCUMENT result = be_struct_from_obj(pulses)
  Converts the return result from process_ba (which is an oxy group) into the
  VEG__ struct.
*/
  if(!is_obj(pulses) || !numberof(pulses.fx)) return [];

  result = array(VEG__, numberof(pulses.fx));
  result.rn = (long(pulses.raster) & 0xffffff) | (long(pulses.pulse) << 24);
  result.raster = pulses.raster;
  result.pulse = pulses.pulse;
  result.north = long(pulses.fy * 100);
  result.east = long(pulses.fx * 100);
  result.elevation = long(pulses.fz * 100);
  result.mnorth = long(pulses.my * 100);
  result.meast = long(pulses.mx * 100);
  result.melevation = long(pulses.mz * 100);
  result.lnorth = long(pulses.ly * 100);
  result.least = long(pulses.lx * 100);
  result.lelv = long(pulses.lz * 100);
  result.fint = pulses.fintensity;
  result.lint = pulses.lintensity;
  result.nx = pulses.rets;
  result.channel = pulses.lchannel;
  result.soe = pulses.soe;

  return result;
}

func process_be(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_ba(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for "bare earth" (topo under veg).

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
      from process_fs: ftx, channel, frx, fintensity, fchannel, fbias,
        fs_slant_range, mx, my, mz, fx, fy, fz
      added by process_be: ltx, lrx, lintensity, lbias, lchannel, lx, ly, lz
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel;

  default, channel, 0;

  sample_interval = 1.0;
  be_tx = eaarl_be_tx_copy;
  if(channel(1)) {
    be_rx = eaarl_be_rx_channel;
  } else {
    be_rx = eaarl_be_rx_eaarla;
  }

  pro_f = eaarl_processing_modes.f.process;

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_be_funcs", save(pro_f, be_tx, be_rx));

  if(is_string(pro_f)) pro_f = symbol_def(pro_f);

  // Start out by processing for first surface
  pulses = pro_f(start, stop, ext_bad_att=ext_bad_att, channel=channel);
  if(is_void(pulses)) return;

  // Throw away any pulses that are equal to or above the mirror
  w = where(pulses.fz < pulses.mz);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ltx
  be_tx, pulses;

  // Determine rx offsets; adds lrx, lintensity, lbias, lchannel; updates
  // fintensity
  be_rx, pulses;

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
  becnt = pulses.lrx - pulses.ltx + pulses.lbias;

  // Distance from surface to bottom
  dist = (becnt - fscnt) * sample_interval * NS2MAIR;
  fscnt = becnt = [];

  ref = [pulses.mx, pulses.my, pulses.mz];
  fs = [pulses.fx, pulses.fy, pulses.fz];

  // Edge case: Coerce into two-dimensional arrays
  if(is_scalar(pulses.mx)) {
    ref = reform(ref, [2, 1, 3]);
  }
  if(is_scalar(pulses.fx)) {
    fs = reform(fs, [2, 1, 3]);
  }

  // Project
  be = point_project(ref, fs, dist, tp=1);

  // Edge case: Coerce back to one-dimensional, if needed
  if(is_scalar(pulses.fx)) {
    be = reform(be, [1, 3]);
  }

  save, pulses, lx=be(..,1), ly=be(..,2), lz=be(..,3);
  return pulses;
}

func eaarl_be_tx_copy(pulses) {
/* DOCUMENT eaarl_be_tx_copy, pulses
  Updates the given pulses oxy group with the last return transmit location.
  This function simply copies the first return transmit, since the transmit
  should be the same for both. This adds the following field to pulses:
    ltx - Location of peak in transmit
*/
  save, pulses, ltx=pulses.ftx;
}

func eaarl_be_rx_channel(pulses) {
/* DOCUMENT eaarl_be_rx_channel, pulses
  Updates the given pulses oxy group object with veg last return info. This
  uses the same channel that was used for the first return. The following
  fields are added to pulses:
    lrx - Location in waveform of bottom
    lintensity - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fintensity - Intensity at location deemed as surface by veg algorithm
*/
  local conf;
  extern ops_conf;

  be_rx_wf = eaarl_be_rx_wf;

  biases = get_range_biases(ops_conf);

  npulses = numberof(pulses.tx);

  lrx = fintensity = lintensity = lbias = array(float, npulses);
  rets = array(char, npulses);
  lchannel = pulses.channel;

  for(i = 1; i <= npulses; i++) {
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;

    conf = vegconf(settings, lchannel(i));
    lbias(i) = biases(lchannel(i));

    tmp = be_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lintensity(i) = tmp.lintensity;
    lrx(i) = tmp.lrx;
    rets(i) = tmp.rets;
  }

  save, pulses, lrx, lintensity, lbias, lchannel, rets;
}

func eaarl_be_rx_eaarla(pulses) {
/* DOCUMENT eaarl_be_rx_eaarla, pulses
  Updates the given pulses oxy group object with veg last return info. The
  most sensitive channel that is not saturated will be used. The following
  fields are added to pulses:
    lrx - Location in waveform of bottom
    lintensity - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fintensity - Intensity at location deemed as surface by bathy algorithm
*/
  local conf;
  extern ops_conf;

  be_rx_channel = eaarl_be_rx_eaarla_channel;
  be_rx_wf = eaarl_be_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_be_rx_funcs", save(be_rx_channel, be_rx_wf));

  biases = get_range_biases(ops_conf);

  npulses = numberof(pulses.tx);

  lrx = lintensity = lbias = array(float, npulses);
  lchannel = rets = array(char, npulses);

  for(i = 1; i <= npulses; i++) {
    lchannel(i) = be_rx_channel(pulses.rx(,i), conf);
    if(!lchannel(i)) continue;
    lbias(i) = biases(lchannel(i));

    tmp = be_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lintensity(i) = tmp.lintensity;
    lrx(i) = tmp.lrx;
    rets(i) = tmp.rets;
  }

  save, pulses, lrx, lintensity, lbias, lchannel, rets;
}

func eaarl_be_rx_eaarla_channel(rx, &conf) {
/* DOCUMENT channel = eaarl_be_rx_eaarla_channel(rx, &conf)
  Determines which channel to use for veg. The channel number is returned,
  and &conf is updated to the veg conf for that channel.
*/
  extern ops_conf;

  for(i = 1; i <= 3; i++) {
    conf = vegconf(settings, i);
    wf = *rx(i);
    if(!numberof(wf)) return 0;
    // Channels 1 and 2 define saturation as < 5, whereas channel 3 defines
    // saturation as == 0.
    sat_thresh=(i == 3 ? 0 : 4)

    np = min(numberof(wf), 12);
    saturated = where(wf(1:np) <= sat_thresh);
    numsat = numberof(saturated);
    if(numsat <= ops_conf.max_sfc_sat) return i;
  }
  return 0;
}

func eaarl_be_plot(raster, pulse, channel=, win=, xfma=) {
/* DOCUMENT eaarl_be_plot, raster, pulse, channel=, win=, xfma=
  Executes the veg algorithm for a single pulse and plots the result.

  The plot will consist of the following elements:
    - The waveform will be plotted in black
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
    - lintensity, which is the intensity at the peak
    - rets, which is how many leading edges (and thus candidate returns) were
      detected; this number will match how many triangles are plotted

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
  Options:
    channel= Channel to force use of. Default is 0, which means to auto-select.
    win= Window to plot in. Defaults to 24.
    xfma= Whether to clear plot first. Defaults to 1.
*/
  default, channel, 0;
  default, win, 24;
  default, xfma, 1;

  local conf;

  be_rx_channel = eaarl_be_rx_eaarla_channel;
  be_rx_wf = eaarl_be_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_be_rx_funcs", save(be_rx_channel, be_rx_wf));

  wbkp = current_window();
  window, win;

  tkcmd, swrite(format=
    "::eaarl::vegconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
    win, raster, pulse, channel, vegconf(settings_group, max(channel, 1)));

  pulses = decode_rasters(raster, raster);
  w = where(pulses.pulse == pulse);
  if(!numberof(w)) {
    write, format=" raster %d does not contain pulse %d\n",
      raster, pulse;
    window_select, wbkp;
    return;
  }
  pulses = obj_index(pulses, w(1));
  if(channel) {
    conf = vegconf(settings, channel);
  } else {
    channel = be_rx_channel(pulses.rx, conf);

    tkcmd, swrite(format=
      "::eaarl::vegconf::config %d -channel %d -group {%s}",
      win, channel, vegconf(settings_group, channel));
  }

  write, format=" vegetation analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(channel);

  if(xfma) fma;

  result = be_rx_wf(*pulses.rx(channel), conf, plot=1);
  plhline, conf.thresh, color="red", type="dot";

  pltitle, swrite(format="veg - rn:%d pulse:%d chan:%d",
    raster, pulse, channel);
  xytitles, "Sample Number", "Sample Counts (Relative Intensity)";

  window_select, wbkp;

  write, format="   lrx: %.2f\n   lintensity: %.2f\n   rets: %d\n",
    double(result.lrx), double(result.lintensity), long(result.rets);

  if(!result.lrx) {
    write, format="   %s\n", "No return found.";
  }
}

func eaarl_be_rx_wf(rx, conf, &msg, plot=) {
/* DOCUMENT result = eaarl_be_rx_wf(rx, conf, &msg, plot=)
  Determines the veg result for the given waveform.

  Parameters:
    rx - Raw waveform, an array of char
    conf - Conf object (from bathconf)
    msg - Output parameter that specifies a status message
  Options:
    plot= Set to 1 to enable plotting; disabled by default

  Returns:
    An oxy group object with these members:
      lrx - location of last surface in waveform
      lintensity - intensity at last surface
      rets - number of returns found

    rv:
      sa = scan angle
      mx1 = first pulse index         -> frx - dropped
      mv1 = first pulse peak value    -> fintensity - dropped
      mx0 = last pulse index          -> lrx
      mv0 = last pulse peak value     -> lintensity
      nx = number of returns          -> rets
*/
  conf = obj_copy(conf);
  sample_interval = 1.0;

  result = save(lrx=0, lintensity=0, rets=0);

  // Retrieve the waveform, figure out the max intensity value, and remove
  // bias
  wf = float(~(rx));
  maxint = 255 - long(wf(1));
  wf -= wf(1);

  wflen = numberof(wf);
  if(plot) {
    // Plot original waveform prior to truncation, etc.
    xaxis = indgen(wflen);
    plg, wf, xaxis, color="black", type="dot";
  }

  if(conf.max_samples > 0 && wflen > conf.max_samples) {
    wflen = conf.max_samples;
    wf = wf(:wflen);
  }

  if(conf.smoothwf > 0) {
    wf = moving_average(wf, bin=(conf.smoothwf*2+1), taper=1);
  }

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
    save, result, fintensity=wf(max), lintensity=wf(max);
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

  if(conf.noiseadj) {
    noise = where(wfd1(edges(0):edges(0)+3) < 0);
    if(is_array(noise)) {
      if(plot)
        plmk, wf(edges(0)+1), xaxis(edges(0)+1), marker=marker, msize=.01,
          color="magenta", width=1;
      edges(0) = edges(0) + noise(1);
      if(edges(0) + max_ret_len + 1 > wflen) max_ret_len = wflen - edges(0) - 1;
      if(plot)
        plmk, wf(edges(0)+1), xaxis(edges(0)+1), marker=marker, msize=.01,
          color="red", width=1;
    }
  }

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
    save, result, lintensity = wf(result.lrx);

    if(plot) {
      plmk, result.lintensity, result.lrx, color="blue", marker=1, msize=.5,
        width=10;
    }
  }

  return result;
}
