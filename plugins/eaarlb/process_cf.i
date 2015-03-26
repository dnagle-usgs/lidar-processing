// vim: set ts=2 sts=2 sw=2 ai sr et:

func process_cf(start, stop, ext_bad_att=, channel=, opts=) {
/* DOCUMENT result = process_ba(start, stop, ext_bad_att=, channel=, opts=)

  Processes the given raster ranges for "bare earth" (topo under veg)
  using curve fitting.

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
      added by process_cf: ltx, lrx, lintensity, lbias, lchannel, lx, ly, lz
*/
  restore_if_exists, opts, start, stop, ext_bad_att, channel;

  default, channel, 0;

  sample_interval = 1.0;
  cf_tx = eaarl_cf_tx_copy;
  cf_rx = eaarl_cf_rx_channel;    // Not doing EAARL-A

  // Allow core functions to be overridden via hook
  restore, hook_invoke("process_cf_funcs", save(cf_tx, cf_rx));

  // Start out by processing for first surface
  pulses = process_fs(start, stop, ext_bad_att=ext_bad_att, channel=channel);
  if(is_void(pulses)) return;

  // Throw away any pulses that are equal to or above the mirror
  w = where(pulses.fz < pulses.mz);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Determine tx offsets; adds ltx
  cf_tx, pulses;

  // Determine rx offsets; adds lrx, lintensity, lbias, lchannel; updates
  // fintensity
  cf_rx, pulses;

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

func eaarl_cf_tx_copy(pulses) {
/* DOCUMENT eaarl_cf_tx_copy, pulses
  Updates the given pulses oxy group with the last return transmit location.
  This function simply copies the first return transmit, since the transmit
  should be the same for both. This adds the following field to pulses:
    ltx - Location of peak in transmit
*/
  save, pulses, ltx=pulses.ftx;
}

func eaarl_cf_rx_channel(pulses) {
/* DOCUMENT eaarl_cf_rx_channel, pulses
  Updates the given pulses oxy group object with curve fitted last return info. This
  uses the same channel that was used for the first return. The following
  fields are added to pulses:
    lrx - Location in waveform of bottom
    lintensity - Intensity at bottom
    lbias - The channel range bias (ops_conf.chn%d_range_bias)
    lchannel - Channel used for bottom
  Additionally, this field is overwritten:
    fintensity - Intensity at location deemed as surface by curve fitting algorithm
*/
  local conf;
  extern ops_conf;

  cf_rx_wf = eaarl_cf_rx_wf;

  biases = get_range_biases(ops_conf);

  npulses = numberof(pulses.tx);

  // lrx = fintensity = lintensity = lbias = array(float, npulses);
  lrx = array(long, npulses);
  lintensity = lbias = array(double, npulses);
  rets = array(char, npulses);
  lchannel = pulses.channel;

  for(i = 1; i <= npulses; i++) {
    if(!lchannel(i)) continue;
    if(!pulses.rx(lchannel(i),i)) continue;

    conf = cfconf(settings, lchannel(i));
    lbias(i) = biases(lchannel(i));

    tmp = cf_rx_wf(*pulses.rx(lchannel(i),i), conf);
    lintensity(i) = tmp.lintensity;
    lrx(i) = tmp.lrx;
    rets(i) = tmp.num_rets;
  }

  save, pulses, lrx, lintensity, lbias, lchannel, rets;
}

func eaarl_cf_plot(raster, pulse, channel=, win=, xfma=) {
/* DOCUMENT eaarl_cf_plot, raster, pulse, channel=, win=, xfma=
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
    - The curve fitted peak will be marked with a solid green triangle

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

  cf_rx_channel = [];     // eaarl_cf_rx_channel;
  cf_rx_wf = eaarl_cf_rx_wf;

  // Allow functions to be overridden via hook
  restore, hook_invoke("eaarl_cf_rx_funcs", save(cf_rx_channel, cf_rx_wf));

  wbkp = current_window();
  window, win;

  tkcmd, swrite(format=
    "::eaarl::cfconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
    win, raster, pulse, channel, cfconf(settings_group, max(channel, 1)));

  pulses = decode_rasters(raster, raster);
  w = where(pulses.pulse == pulse);
  if(!numberof(w)) {
    write, format=" raster %d does not contain pulse %d\n",
      raster, pulse;
    window_select, wbkp;
    return;
  }
  pulses = obj_index(pulses, w(1));
  conf = cfconf(settings, channel);

  write, format=" vegetation analysis for raster %d, pulse %d, channel %d\n",
    long(raster), long(pulse), long(channel);

  if(xfma) fma;

  result = cf_rx_wf(*pulses.rx(channel), conf, plot=1);

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

func eaarl_cf_rx_wf(rx, conf, &msg, plot=) {
/* DOCUMENT result = eaarl_cf_rx_wf(rx, conf, &msg, plot=)
  Determines the veg result for the given waveform.

  Parameters:
    rx - Raw waveform, an array of char
    conf - Conf object (from cfconf)
    msg - Output parameter that specifies a status message
  Options:
    plot= Set to 1 to enable plotting; disabled by default

  Returns:
    An oxy group object with these members:
      lrx - location of last surface in waveform
      lintensity - intensity at last surface
      num_rets - number of returns found

    rv:
      sa = scan angle
      mx1 = first pulse index         -> frx - dropped
      mv1 = first pulse peak value    -> fintensity - dropped
      mx0 = last pulse index          -> lrx
      mv0 = last pulse peak value     -> lintensity
      nx = number of returns          -> num_rets
*/
  local peaks, edges;

  conf = obj_copy(conf);

  result = save(lrx=0, lintensity=0, num_rets=0);

  // Retrieve waveform, determine max intensity value, and remove bias
  wf = float(~(rx));
  wf -= wf(1);

  wflen = numberof(wf);
  xaxis = indgen(wflen);

  // Plot original waveform prior to truncation, etc.
  if(plot)
    plg, wf, xaxis, color="black", type="dot";

  if(conf.smoothwf > 0)
    wf = moving_average(wf, bin=(conf.smoothwf*2+1), taper=1);

  tmp = eaarl_cf_peak_finder(wf, conf.thresh);
  restore, tmp, peaks, edges;
  tmp = [];

  npeaks = numberof(peaks);
  save, result, num_rets=npeaks;

  if(!npeaks)
    return result;

  // First derivative of waveform
  wfd1 = wf(dif);

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

  // compute standard deviation and select those within initsd distance
  // get stdev from peak values
  cf_avg = wf(peaks)(avg);
  cf_rms = wf(peaks)(rms) * conf.initsd;

  if ( plot )
    write, format="Avg: %lf RMS: %lf\n", cf_avg, cf_rms;

  if ( ! cf_rms ) return result;

  a = array(float, npeaks*3);
  a(1::3) = wf(peaks);     // 1: height of curve's peak
  a(2::3) = peaks;         // 2: position of center of peak
  a(3::3) = conf.initsd;   // 3: standard deviation

  if (catch(-1)) return result;
  // compute new peaks in by fitting a gauss curve to each peak.
  r = lmfit(eaarl_cf_lmfit_gauss, xaxis, a, wf, 1.0, itmax=200, stdev=conf.initsd, tol=0.001);
  if(r.niter == 200) return result;

  // fit a new curve to the adjusted peaks.
  yfit = eaarl_cf_lmfit_gauss(xaxis, a);

  if(conf.initsd) {
    if(plot) {
      // Show points falling within selected std deviation.
      wfstd = where(wf > cf_avg - (conf.initsd*cf_rms)
          & wf < cf_avg + (conf.initsd*cf_rms));
      if(numberof(wfstd))
        plmk, wf(wfstd), wfstd, marker=marker, msize=.01,
          color="green", width=1;
    }

    if(edges(0) + max_ret_len + 1 > wflen)
      max_ret_len = wflen - edges(0) - 1;

    if(plot)
      plmk, wf(edges(0)+1), xaxis(edges(0)+1), marker=marker, msize=.01,
        color="red", width=1;

    tmp = eaarl_cf_peak_finder( yfit, conf.thresh);
    if (plot) {
      // plot the entire computed curve
      plg, yfit, color="green", width=5;
      // show first return in a bold hollow triangle
      plmk, yfit(tmp.peaks(1)), tmp.peaks(1), marker=marker, msize=.01,
        color="green", width=5;
      // show last return as a solid triangle
      plmk, yfit(tmp.peaks(0)), tmp.peaks(0), marker=marker, msize=.01,
        color="green", width=10;
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
    // CF results
    save, result, lrx=tmp.peaks(0);
    save, result, lintensity=yfit(tmp.peaks(0));

    if(plot) {
      plmk, result.lintensity, result.lrx, color="blue", marker=1, msize=.5,
        width=10;

      write, format="BE: %ld %lf\n", edges(0)+wneg(1),  wf(edges(0)+wneg(1));
      write, format="CF: %ld %lf\n", tmp.peaks(0), yfit(tmp.peaks(0));

    }
  }

  return result;
}

func eaarl_cf_lmfit_gauss(x, a, f=) {
/* DOCUMENT eaarl_cf_lmfit_guass(x, a, f=)
  Wrapper function that gets everything in the right format for LM_fit
  function to perform optimization.
*/
  if(is_void(f)) f=0;
  for (i=1; i < numberof(a); i+=3)
    f += gauss(x,a(i:i+2));
  return f;
}

func eaarl_cf_peak_finder(wf, thresh) {
  wf_pe = save(peaks, edges);    // Create new wf_pe object;
  nwf = numberof(wf);
  edges = peaks = array(0, nwf);
  i = 1;
  while(++i <= nwf) {
    // Find a leading edge that exceeds the threshold
    if(wf(i) - wf(i-1) >= thresh) {
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
  }
  edges = where(edges);
  peaks = where(peaks);
  save, wf_pe, peaks=peaks, edges=edges;
  return wf_pe;
}
