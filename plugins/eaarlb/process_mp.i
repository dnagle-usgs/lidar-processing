// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(mpconf)) mpconf = mpconfobj();

func mp_obj2dyn(pulses) {
  data = obj_copy(pulses);
  obj_delete, data, ftx, frx, fx, fy, fz, fintensity, fbias, fchannel,
    fs_slant_range;
  save, data, x=data.lx, y=data.ly, z=data.lz, intensity=data.lintensity,
    tx=data.ltx, rx=float(data.lrx), bias=data.lbias,
    channel=char(data.lchannel);
  save, data, ptime=array(0, numberof(data.x));
  obj_delete, data, lx, ly, lz, lintensity, ltx, lrx, lbias, lchannel;

  fields = ["raster","pulse","channel","ptime","soe",
    "mx","my","mz",
    "x","y","z",
    "tx","rx","bias","int","ret_num","num_rets"];

  // Put the sorted fields first; then append any additional (via merge)
  result = data(data(*,fields));
  obj_merge, result, data;

  return obj2struct(result, name="DYN_PC", ary=1);
}

func process_mp(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_mp(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for multi-peak.

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
      added by process_mp: ltx, lrx, lintensity, lbias, lchannel, lx, ly, lz,
        num_rets, ret_num
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel;

  default, channel, 0;

  sample_interval = 1.0;
  mp_tx = eaarl_mp_tx_copy;
  if(channel(1)) {
    mp_rx = eaarl_mp_rx_channel;
  } else {
    mp_rx = eaarl_mp_rx_eaarla;
  }

  // Allow core functions to mp overridden via hook
  restore, hook_invoke("process_mp_funcs", save(mp_tx, mp_rx));

  // Start out by processing for first surface
  pulses = process_fs(start, stop, ext_bad_att=ext_bad_att, channel=channel);
  if(is_void(pulses)) return;

  // Throw away any pulses that are equal to or above the mirror
  w = where(pulses.fz < pulses.mz);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ltx
  mp_tx, pulses;

  // Determine rx offsets; adds lrx, lintensity, lbias, lchannel; updates fintensity
  mp_rx, pulses;

  // Throw away lchannel == 0
  w = where(pulses.lchannel);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Expand lrx and lintensity from pointer arrays into individual points. This also
  // as a consequence gets rid of anything that had no returns. Also build up
  // the ret_num field.
  idx = histinv(pulses.num_rets);
  lrx = obj_pop(pulses, "lrx");
  lintensity = obj_pop(pulses, "lintensity");
  n = numberof(lrx);
  ret_num = array(pointer, n);
  for(i = 1; i <= n; i++)
    if(pulses.num_rets(i))
      ret_num(i) = &char(indgen(pulses.num_rets(i)));
  pulses = obj_index(pulses, idx);
  save, pulses, lrx=merge_pointers(lrx);
  save, pulses, lintensity=merge_pointers(lintensity);
  save, pulses, ret_num=merge_pointers(ret_num);

  // Adjusted offset in sample counts to surface
  fscnt = pulses.frx - pulses.ftx + pulses.fbias;
  // Adjusted offset in sample counts to bottom
  mpcnt = pulses.lrx - pulses.ltx + pulses.lbias;

  // Distance from surface to bottom
  dist = (mpcnt - fscnt) * sample_interval * NS2MAIR;
  fscnt = mpcnt = [];

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
  mp = point_project(ref, fs, dist, tp=1);

  // Edge case: Coerce back to one-dimensional, if needed
  if(is_scalar(pulses.fx)) {
    mp = reform(mp, [1, 3]);
  }

  save, pulses, lx=mp(..,1), ly=mp(..,2), lz=mp(..,3);
  return pulses;
}

func eaarl_mp_tx_copy(pulses) {
/* DOCUMENT eaarl_mp_tx_copy, pulses
  Updates the given pulses oxy group with the last return transmit location.
  This function simply copies the first return transmit, since the transmit
  should be the same for both. This adds the following field to pulses:
    ltx - Location of peak in transmit
*/
  save, pulses, ltx=pulses.ftx;
}

func eaarl_mp_rx_channel(pulses) {
/* DOCUMENT eaarl_mp_rx_channel, pulses
  Updates the given pulses oxy group object with multi-peak return info. This
  uses the same channel that was used for the first return. The following
  fields are added to pulses:
    lrx - Pointer to array of peak locations
    lintensity - Pointer to array of intensities at peaks
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used
*/
  local conf;
  extern ops_conf;

  mp_rx_wf = eaarl_mp_rx_wf;

  biases = [ops_conf.chn1_range_bias, ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias];

  npulses = numberof(pulses.tx);

  lrx = lintensity = array(pointer, npulses);
  lbias = array(float, npulses);
  num_rets = array(char, npulses);
  lchannel = pulses.channel;

  for(i = 1; i <= npulses; i++) {
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;

    conf = mpconf(settings, lchannel(i));
    lbias(i) = biases(lchannel(i));

    tmp = mp_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lintensity(i) = &tmp.lintensity;
    lrx(i) = &tmp.lrx;
    num_rets(i) = tmp.num_rets;
  }

  save, pulses, lrx, lintensity, lbias, lchannel, num_rets;
}

func eaarl_mp_rx_eaarla(pulses) {
/* DOCUMENT eaarl_mp_rx_eaarla, pulses
  Updates the given pulses oxy group object with multi-peak return info. The
  most sensitive channel that is not saturated will be used. The following
  fields are added to pulses:
    lrx - Pointer to array of peak locations
    lintensity - Pointer to array of intensities at peaks
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used
*/
  local conf;
  extern ops_conf;

  mp_rx_channel = eaarl_mp_rx_eaarla_channel;
  mp_rx_wf = eaarl_mp_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_mp_rx_funcs", save(mp_rx_channel, mp_rx_wf));

  biases = [ops_conf.chn1_range_bias, ops_conf.chn2_range_bias,
    ops_conf.chn3_range_bias];

  npulses = numberof(pulses.tx);

  lrx = lintensity = array(pointer, npulses);
  lbias = array(float, npulses);
  num_rets = array(char, npulses);
  lchannel = array(char, npulses);

  for(i = 1; i <= npulses; i++) {
    lchannel(i) = mp_rx_channel(pulses.rx(,i), conf);
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;
    lbias(i) = biases(lchannel(i));

    tmp = mp_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lintensity(i) = &tmp.lintensity;
    lrx(i) = &tmp.lrx;
    num_rets(i) = tmp.num_rets;
  }

  save, pulses, lrx, lintensity, lbias, lchannel, num_rets;
}

func eaarl_mp_rx_eaarla_channel(rx, &conf) {
/* DOCUMENT channel = eaarl_mp_rx_eaarla_channel(rx, &conf)
  Determines which channel to use for multipeak. The channel number is
  returned, and &conf is updated to the mp conf for that channel.
*/
  extern ops_conf;

  for(i = 1; i <= 3; i++) {
    conf = mpconf(settings, i);
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

func eaarl_mp_plot(raster, pulse, channel=, win=, xfma=) {
/* DOCUMENT eaarl_mp_plot, raster, pulse, channel=, win=, xfma=
  Executes the multipeak algorithm for a single pulse and plots the result.

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
    - num_rets, which is how many leading edges (and thus candidate returns)
      were detected; this number will match how many triangles are plotted

  Parameters:
    raster - Raster number to use.
    pulse - Pulse number to use.
  Options:
    channel= Channel to force use of. Default is 0, which means to auto-select.
    win= Window to plot in. Defaults to 27.
    xfma= Whether to clear plot first. Defaults to 1.
*/
  default, channel, 0;
  default, win, 27;
  default, xfma, 1;

  local conf;

  mp_rx_channel = eaarl_mp_rx_eaarla_channel;
  mp_rx_wf = eaarl_mp_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_mp_rx_funcs", save(mp_rx_channel, mp_rx_wf));

  wbkp = current_window();
  window, win;

  tkcmd, swrite(format=
    "::eaarl::mpconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
    win, raster, pulse, channel, mpconf(settings_group, max(channel, 1)));

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
    conf = mpconf(settings, channel);
  } else {
    channel = mp_rx_channel(pulses.rx, conf);

    tkcmd, swrite(format=
      "::eaarl::mpconf::config %d -channel %d -group {%s}",
      win, channel, mpconf(settings_goup, channel));
  }

  write, format=" multi-peak analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(channel);

  if(xfma) fma;

  result = mp_rx_wf(*pulses.rx(channel), conf, plot=1);

  pltitle, swrite(format="mp - rn:%d pulse:%d chan:%d",
    raster, pulse, channel);
  xytitles, "Sample Number", "Sample Counts (Relative Intensity)";

  window_select, wbkp;

  if(result.num_rets) {
    write, format="  ret %d/%d => lrx: %d  lintensity: %.2f\n",
      indgen(result.num_rets), array(result.num_rets, result.num_rets),
      result.lrx, result.lintensity;
  } else {
    write, format="   %s\n", "No return found.";
  }
}

func eaarl_mp_rx_wf(rx, conf, &msg, plot=) {
/* DOCUMENT result = eaarl_mp_rx_wf(rx, conf, &msg, plot=)
  Determines the multipeak result for the given waveform.

  Parameters:
    rx - Raw waveform, an array of char
    conf - Conf object (from bathconf)
    msg - Output parameter that specifies a status message
  Options:
    plot= Set to 1 to enable plotting; disabled by default

  Returns:
    An oxy group object with these members:
      lrx - array of peak locations in waveform
      lintensity - array of intensities at lrx locations
      num_rets - number of peaks (returns) found
*/
  conf = obj_copy(conf);
  sample_interval = 1.0;

  result = save(lrx=[], lintensity=[], num_rets=0);

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

  if(plot) {
    xaxis = indgen(numberof(wf));
    plg, wf(dif), xaxis(:-1)+.5, color="red";
    plmk, wf, xaxis, color="black", msize=.2, marker=1;
    plg, wf, xaxis, color="black";
  }

  nwf = numberof(wf);
  edges = peaks = array(0, nwf);
  i = 2;
  while(i <= nwf) {
    // Find a leading edge that exceeds the threshold
    if(wf(i) - wf(i-1) >= conf.thresh) {
      edges(i) = 1;
      // Advance to find the peak after this leading edge
      while(i < nwf && wf(i) < wf(i+1)) i++;
      j = i;
      // Advance to find end of peak in case the peak consists of several
      // pulses of the same intensity (common when saturated)
      while(i < nwf && wf(j) == wf(i+1)) i++;
      // Mark the peak at the center of the peak section
      peaks((j+i)/2) = 1;
    }
    i++;
  }

  edges = where(edges);
  peaks = where(peaks);
  save, result, num_rets=numberof(peaks);

  if(!numberof(peaks)) {
    return result;
  }

  save, result, lrx=peaks;
  save, result, lintensity=wf(peaks);

  if(plot) {
    // Use an equilateral triangle as a marker, but moved up a smidge
    marker = [[0,-.5,.5],[0,.866,.866]+.25];
    // Mark edge locations
    plmk, wf(edges), xaxis(edges), marker=marker, msize=.01, color="red",
      width=1;

    // Mark peak locations
    plmk, result.lintensity, result.lrx, color="blue", marker=1, msize=.5,
      width=10;
  }

  return result;
}
