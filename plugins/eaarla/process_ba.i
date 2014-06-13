// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(bathconf)) bathconf = bathconfobj();

func ba_struct_from_obj(pulses) {
/* DOCUMENT result = ba_struct_from_obj(pulses)
  Converts the return result from process_ba (which is an oxy group) into the
  GEO struct.
*/
  if(!is_obj(pulses) || !numberof(pulses.fx)) return [];

  result = array(GEO, numberof(pulses.fx));
  result.rn = (long(pulses.raster) & 0xffffff) | (long(pulses.pulse) << 24);
  result.raster = pulses.raster;
  result.pulse = pulses.pulse;
  result.north = long(pulses.ly * 100);
  result.east = long(pulses.lx * 100);
  result.sr2 = (pulses.lrx + pulses.lbias) - (pulses.frx + pulses.fbias);
  result.elevation = long(pulses.fz * 100);
  result.mnorth = long(pulses.my * 100);
  result.meast = long(pulses.mx * 100);
  result.melevation = long(pulses.mz * 100);
  result.bottom_peak = pulses.lint;
  result.first_peak = pulses.fint;
  result.depth = long((pulses.lz-pulses.fz) * 100);
  result.soe = pulses.soe;
  result.channel = pulses.lchannel;

  // Original uses floating point, struct uses integers. This can result in
  // depth values of 0, throw them out.
  w = where(result.depth < 0);
  result = numberof(w) ? result(w) : [];

  return result;
}

func process_ba(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_ba(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for submerged topography (bathy).

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
      added by process_ba: ltx, lrx, lint, lbias, lchannel, lx, ly, lz
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel;

  default, channel, 0;

  sample_interval = 1.0;
  ba_tx = eaarl_ba_tx_copy;
  if(channel(1)) {
    ba_rx = eaarl_ba_rx_channel;
  } else {
    ba_rx = eaarl_ba_rx_eaarla;
  }

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_ba_funcs", save(ba_tx, ba_rx));

  // Start out by processing for first surface
  pulses = process_fs(start, stop, ext_bad_att=ext_bad_att, channel=channel);
  if(is_void(pulses)) return;

  // Throw away any pulses that are equal to or above the mirror
  w = where(pulses.fz < pulses.mz);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ltx
  ba_tx, pulses;

  // Determine rx offsets; adds lrx, lint, lbias, lchannel; updates fint
  ba_rx, pulses;

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
  bacnt = pulses.lrx - pulses.ltx + pulses.lbias;

  // Distance from surface to bottom
  dist = (bacnt - fscnt) * sample_interval * NS2MAIR;
  fscnt = bacnt = [];

  // Throw away bottoms that are above surface
  w = where(dist >= 0);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);
  dist = dist(w);

  ref = [pulses.mx, pulses.my, pulses.mz];
  fs = [pulses.fx, pulses.fy, pulses.fz];

  // Coerce into two-dimensional arrays
  if(is_scalar(pulses.mx)) {
    ref = reform(ref, [2, 1, 3]);
  }
  if(is_scalar(pulses.fx)) {
    fs = reform(fs, [2, 1, 3]);
  }

  // Project and correct for refraction and speed of light in water
  be = point_project(ref, fs, dist, tp=1);
  ba = snell_be_to_bathy(fs, be);
  be = [];

  // Coerce back to one-dimensional, if needed
  if(is_scalar(pulses.fx)) {
    ba = reform(ba, [1, 3]);
  }

  save, pulses, lx=ba(..,1), ly=ba(..,2), lz=ba(..,3);
  return pulses;
}

func eaarl_ba_tx_copy(pulses) {
/* DOCUMENT eaarl_ba_tx_copy, pulses
  Updates the given pulses oxy group with the last return transmit location.
  This function simply copies the first return transmit, since the transmit
  should be the same for both. This adds the following field to pulses:
    ltx - Location of peak in transmit
*/
  save, pulses, ltx=pulses.ftx;
}

func eaarl_ba_rx_channel(pulses) {
/* DOCUMENT eaarl_ba_rx_channel, pulses
  Updates the given pulses oxy group object with bathy last return info. This
  uses the same channel that was used for the first return. The following
  fields are added to pulses:
    lrx - Location in waveform of bottom
    lint - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fint - Intensity at location deemed as surface by bathy algorithm
*/
  local conf;
  extern ops_conf;

  ba_rx_wf = eaarl_ba_rx_wf;

  biases = [ops_conf.chn1_range_bias, ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias];

  npulses = numberof(pulses.tx);

  lrx = fint = lint = lbias = array(float, npulses);
  lchannel = pulses.channel;

  for(i = 1; i <= npulses; i++) {
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;

    conf = bathconf(settings, lchannel(i));
    lbias(i) = biases(lchannel(i));

    tmp = ba_rx_wf(*pulses.rx(lchannel(i),i), conf);
    fint(i) = tmp.fint;
    lint(i) = tmp.lint;
    lrx(i) = tmp.lrx;
  }

  save, pulses, lrx, fint, lint, lbias, lchannel;
}

func eaarl_ba_rx_eaarla(pulses) {
/* DOCUMENT eaarl_ba_rx_eaarla, pulses
  Updates the given pulses oxy group object with bathy last return info. The
  most sensitive channel that is not saturated will be used. The following
  fields are added to pulses:
    lrx - Location in waveform of bottom
    lint - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fint - Intensity at location deemed as surface by bathy algorithm
*/
  local conf;
  extern ops_conf;

  ba_rx_channel = eaarl_ba_rx_eaarla_channel;
  ba_rx_wf = eaarl_ba_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_ba_rx_funcs", save(ba_rx_channel, ba_rx_wf));

  biases = [ops_conf.chn1_range_bias, ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias];

  npulses = numberof(pulses.tx);

  lrx = fint = lint = lbias = array(float, npulses);
  lchannel = array(char, npulses);

  for(i = 1; i <= npulses; i++) {
    lchannel(i) = ba_rx_channel(pulses.rx(,i), conf);
    if(!lchannel(i)) continue;
    lbias(i) = biases(lchannel(i));

    tmp = ba_rx_wf(*pulses.rx(lchannel(i),i), conf);
    fint(i) = tmp.fint;
    lint(i) = tmp.lint;
    lrx(i) = tmp.lrx;
  }

  save, pulses, lrx, fint, lint, lbias, lchannel;
}

func eaarl_ba_rx_eaarla_channel(rx, &conf) {
/* DOCUMENT channel = eaarl_ba_rx_eaarla_channel(rx, &conf)
  Determines which channel to use for bathy. The channel number is returned,
  and &conf is updated to the bathy conf for that channel.
*/
  for(i = 1; i <= 2; i++) {
    conf = bathconf(settings, i);
    wf = *rx(i);
    if(!numberof(wf)) return 0;
    numsat = numberof(where(wf == 0));
    if(numsat <= conf.maxsat) return i;
  }
  conf = bathconf(settings, 3);
  return 3;
}

func eaarl_ba_plot(raster, pulse, channel=, win=, xfma=) {
/* DOCUMENT eaarl_ba_plot, raster, pulse, channel=, win=, xfma=
  Executes the bathy algorithm for a single pulse and plots the result.

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
  Options:
    channel= Channel to force use of. Default is 0, which means to auto-select.
    win= Window to plot in. Defaults to 4.
    xfma= Whether to clear plot first. Defaults to 1.
*/
  default, channel, 0;
  default, win, 4;
  default, xfma, 1;

  wbkp = current_window();
  window, win;
  gridxy, 2, 2;
  if(xfma) fma;

  tkcmd, swrite(format=
    "::eaarl::bathconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
      win, raster, pulse, max(channel, 1),
      bathconf(settings_group, max(channel, 1)));

  msg = chan = [];
  result = ba_analyze_pulse(raster, pulse, msg, chan, channel=channel, plot=1);
  channel = chan;

  if(!is_void(msg)) {
    port = viewport();
    plt, strwrap(msg, width=25, paragraph="\n"), port(2), port(4),
      justify="RT", tosys=0, color="red";
  }

  write, format=" bathymetric analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(channel);

  if(is_void(result)) {
    write, msg;
    window_select, wbkp;
    return;
  }

  tkcmd, swrite(format=
    "::eaarl::bathconf::config %d -channel %d -group {%s}",
    win, channel, bathconf(settings_group, channel));

  pltitle, swrite(format="bathy - rn:%d pulse:%d chan:%d",
    raster, pulse, channel);
  xytitles, "Sample Number", "Sample Counts (Relative Intensity)";

  window_select, wbkp;

  write, format="   lrx: %.2f\n   fint: %.2f\n   lint: %.2f\n",
    double(result.lrx), double(result.fint), double(result.lint);
  if(!is_void(msg)) write, format="   %s\n", msg;
}

func ba_analyze_pulse(raster, pulse, &msg, &chan, channel=, plot=) {
/* DOCUMENT result = ba_analyze_pulse(raster, pulse, msg, &chan, channel=, plot=)
  Executes the bathy algorithm for a single pulse.

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
    msg - Output parameter containing an error/notice message. Will be [] if no
      message applies.
    chan - Output parameter specifying which channel was used. This will equal
      what was passed for channel, unless channel was 0.
  Options:
    channel= Channel to force use of. Default is 0, which means to auto-select.
    plot= Passes through to underlying rx_wf function to enable plotting. (If
      you want to plot bathy, do not use this function directly. Use
      eaarl_ba_plot instead.)
*/
  default, channel, 0;
  default, plot, 0;

  local conf;

  ba_rx_channel = eaarl_ba_rx_eaarla_channel;
  ba_rx_wf = eaarl_ba_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_ba_rx_funcs", save(ba_rx_channel, ba_rx_wf));

  chan = channel;

  pulses = decode_rasters(raster, raster);
  w = where(pulses.pulse == pulse);
  if(!numberof(w)) {
    msg = swrite(format="raster %d does not contain pulse %d",
      raster, pulse);
    return;
  }

  pulses = obj_index(pulses, w(1));
  if(channel) {
    conf = bathconf(settings, channel);
  } else {
    chan = channel = ba_rx_channel(pulses.rx, conf);
  }

  msg = [];
  return ba_rx_wf(*pulses.rx(channel), conf, msg, plot=plot);
}

func eaarl_ba_rx_wf(rx, conf, &msg, plot=) {
/* DOCUMENT result = eaarl_ba_rx_wf(rx, conf, &msg, plot=)
  Determines the bathy result for the given waveform.

  Parameters:
    rx - Raw waveform, an array of char
    conf - Conf object (from bathconf)
    msg - Output parameter that specifies a status message
  Options:
    plot= Set to 1 to enable plotting; disabled by default

  Returns:
    An oxy group object with these members:
      lrx - location of bottom in waveform
      fint - intensity at surface
      lint - intensity at bottom
      candidate_lrx - candidate location of bottom in waveform
*/
  conf = obj_copy(conf);
  sample_interval = 1.0;

  result = save(lrx=0, fint=0, lint=0, candidate_lrx=0);

  if(is_void(rx)) {
    msg = "no waveform";
    return result;
  }

  // Retrieve the waveform, figure out the max intensity value, and remove
  // bias
  wf = float(~(rx));
  bias = wf(1:min(15,numberof(wf)))(min);
  maxint = 255 - long(bias);
  wf -= bias;

  if(plot) {
    plmk, wf, msize=.275, marker=1, color="black";
    plg, wf, color="black", width=4;
  }

  // Apply moving average to smooth wf
  if(conf.smoothwf > 0) {
    wf = moving_average(wf, bin=(conf.smoothwf*2+1), taper=1);
  }

  saturated = wf == maxint;
  numsat = numberof(where(saturated));

  // check saturation
  if(numsat && numsat >= conf.maxsat) {
    if(plot) msg = swrite(format="%d points saturated", numsat);
    return result;
  }

  // detect surface
  local surface_sat_end, surface_intensity, escale;
  bathy_detect_surface, wf, maxint, conf, surface_sat_end, surface_intensity,
    escale;
  save, result, fint=surface_intensity;

  if(numsat > 14) {
    save, conf, thresh=conf.thresh * (numsat-13) * 0.65;
  }

  // compensate for decay
  if(conf.decay == "exponential") {
    wf_decay = bathy_wf_compensate_decay_exp(wf, conf, surface=surface_sat_end,
      max_intensity=escale, sample_interval=sample_interval, graph=plot);
  } else {
    wf_decay = bathy_wf_compensate_decay_lognorm(wf, conf,
      surface=surface_sat_end, max_intensity=escale,
      sample_interval=sample_interval, graph=plot);
  }

  wflen = numberof(wf);
  save, conf, first=min(wflen, conf.first), last=min(wflen, conf.last);

  if(plot) {
    plg, [conf.thresh,conf.thresh], [conf.first,conf.last], marks=0,
      color="red";
    plg, [0,conf.thresh], [conf.first,conf.first], marks=0, color="green",
      width=7;
    plg, [0,conf.thresh], [conf.last,conf.last], marks=0, color="red", width=7;
  }

  // detect bottom
  local bottom_peak;
  msg = [];
  bathy_detect_bottom, wf_decay, conf, bottom_peak, msg;

  if(!is_void(msg)) return result;

  // compensate for saturation
  bathy_compensate_saturation, saturated, bottom_peak;

  bottom_intensity = wf_decay(bottom_peak);
  save, result, candidate_lrx=bottom_peak, lint=wf(bottom_peak);

  // validate bottom
  msg = [];
  bathy_validate_bottom, wf_decay, bottom_peak, conf, msg, graph=plot;

  if(!is_void(msg)) return result;

  if(plot) {
    plg, [wf(bottom_peak)+1.5,0], [bottom_peak,bottom_peak],
      marks=0, type=2, color="blue";
    plmk, wf(bottom_peak)+1.5, bottom_peak,
      msize=1.0, marker=7, color="blue", width=10;
    msg = swrite(format=
      "%3dns\n%3.0f sfc\n%3.1f cnts(blue)\n%3.1f cnts(black)\n(~%3.1fm)",
      bottom_peak, double(surface_intensity), bottom_intensity,
      wf(bottom_peak), (bottom_peak-7)*sample_interval*CNSH2O2X);
  }

  // output
  save, result, lrx=bottom_peak;
  return result;
}

func eaarl_ba_fs_smooth(pulses, surface_window=, pulse_window=,
intensity_thresh=, sample_interval=) {
/* DOCUMENT eaarl_ba_fs_smooth, pulses, surface_window=, pulse_window=,
  intensity_thresh=, sample_interval=
  Attempts to smooth the first surface points.

  This is not well tested yet.
*/
  default, surface_window, 1;
  default, pulse_window, 25;
  default, intensity_thresh, 220;
  default, sample_interval, 1.;

  // Local copies of fields, to be updated and later re-saved to pulses
  local fx, fy, fz, frx;
  restore, pulses, fx, fy, fz, frx;
  save, pulses, frx_real=frx;

  // Force fz to be a copy
  fz = noop(fz);

  // Determine boundary locations for each raster
  idx = where((pulses.raster(dif) != 0) | (pulses.pulse(dif) < 0));
  idx = grow(0, idx, numberof(pulses.raster));
  count = numberof(idx);

  for(i = 1; i < count; i++) {
    cur = indgen(idx(i)+1:idx(i+1));

    w = where(
      (pulses.fint(cur) > intensity_thresh) &
      (abs(60 - pulses.pulse(cur)) < pulse_window)
    );

    write, i, pr1(w);

    if(numberof(w)) {
      good = cur(w);
      z = median(fz(good));

      w = where(abs(fz(good) - z) <= surface_window);
      good = good(w);
      z = avg(fz(good));

      fz(cur) = z;
    }
  }

  // Use similar triangles to calculate changes in x and y
  dmx = pulses.fx - pulses.mx;
  dmy = pulses.fy - pulses.my;
  dmz = pulses.fz - pulses.mz;

  dfz = fz - pulses.fz;
  ratio = dfz / dmz;
  dfx = ratio * dmx;
  dfy = ratio * dmy;

  fx = dfx + pulses.fx;
  fy = dfy + pulses.fy;

  dist = sqrt(dfx^2 + dfy^2 + dfz^2) * sign(dfz);
  samples = dist / (sample_interval * NS2MAIR);

  frx = pulses.frx + samples;

  save, pulses, fx, fy, fz, frx;
}
