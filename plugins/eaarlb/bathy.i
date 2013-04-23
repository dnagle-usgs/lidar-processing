// vim: set ts=2 sts=2 sw=2 ai sr et:

local BATHPIX;
/* DOCUMENT BATHPIX
  Struct used for holding result of ex_bath.

  struct BATHPIX {
    long rastpix;       // raster + pulse << 24
    short sa;           // scan angle
    float idx;          // bottom index
    short bottom_peak;  // peak amplitude of bottom signal
    short first_peak;   // peak amplitude of the surface signal
    char channel;       // channel used
  };
*/
struct BATHPIX {
  long rastpix;
  short sa, bottom_peak, first_peak;
  float idx;
  char channel;
};

if(is_void(bathconf)) bathconf = bathconfobj();

func run_bath(nil, start=, stop=, center=, delta=, last=, forcechannel=,
graph=, pse=, msg=, verbose=) {
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering run_bath";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  start="+pr1(start);
    logger, debug, log_id+"  stop="+pr1(stop);
    logger, debug, log_id+"  center="+pr1(center);
    logger, debug, log_id+"  delta="+pr1(delta);
    logger, debug, log_id+"  last="+pr1(last);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
    logger, debug, log_id+"  graph="+pr1(graph);
    logger, debug, log_id+"  pse="+pr1(pse);
    logger, debug, log_id+"  msg="+pr1(msg);
  }
  extern bathconf;
  default, last, 250;
  default, graph, 0;
  default, pse, 0;
  default, msg, "Processing bathymetry...";

  if(!is_void(center)) {
    default, delta, 100;
    start = center - delta;
    stop = center + delta;
  } else {
    if(is_void(start))
      error, "Must provide start= or center=";
    if(!is_void(delta))
      stop = start + delta;
    else if(is_void(stop))
      error, "When using start=, you must provide delta= or stop=";
  }

  count = stop - start + 1;
  depths = array(BATHPIX, 120, count);

  status, start, msg=msg;
  for(j=1, rn=start; rn <= stop; j++, rn++) {
    for(pulse=1; pulse<=120; pulse++) {
      depths(pulse,j) = ex_bath(rn, pulse, last=last, verbose=verbose,
        forcechannel=forcechannel, graph=graph);
      pause, pse;
    }
    status, progress, j, count;
  }
  status, finished;
  if(logger(debug)) logger, debug, log_id+"Leaving run_bath";
  return depths;
}

func show_bath_constants {
  extern mindata;
  if(!is_void(mindata)) {
    rn = mindata(0).rn&0xffffff;
    pulse = mindata(0).rn>>24;
    ex_bath, rn, pulse, win=0, xfma=1, graph=1;
  }
}

func ex_bath(raster_number, pulse_number, &msg, last=, forcechannel=, graph=,
win=, xfma=, verbose=, keeprejected=) {
/* DOCUMENT ex_bath(raster_number, pulse_number)
  See run_bath for details on usage.

  This function returns a BATHPIX structure element

  For the turbid key areas use:
  bath_ctl = BATH_CTL(laser=-1.5,water=-0.4,agc=-0.3,thresh=3)

  For the clear areas:
  bath_ctl = BATH_CTL(laser=-2.5,water=-0.3,agc=-0.3,thresh=3)
*/
/*
  The following developed using 7-14-01 data at raster = 46672 data. (sod=70510)
  Check waveform samples to see how many samples are
  saturated.
  At this time, this function checks only for the following conditions:
    1) Saturated surface return - locates last saturated sample
    2) Non-saturated surface with saturated bottom signal
    3) Non saturated surface with non-saturated bottom
    4) Bottom signal above specified threshold
  We'll used this infomation to develope the threshold
  array for this waveform.
  We come out of this with the surface_sat_end set to the last
  saturated value of surface return.
  The 12 represents the last place a surface can be found

  Controls:

    See bath_ctl structure.

    first          1      1:300     The first ns point to use for detection
    last        160      1:300     The last point in the waveform to consider.
    laser         -3.0   -1:-5.0    The exponent which describes the laser decay rate
    water         -2.0 -0.1:-10.0   The exponent which best describes this water column
     agc         -0.3 -0.1:-10.0   Agc scaling exponent.
   thresh      4.0    1:50      Bottom peak value threshold

 Variables:
   saturated          A list of saturated pixels in this waveform
   numsat        Number of saturated pixels in this waveform
   surface_sat_end  The last pixel saturated in the surface region of the
               Waveform.
   escale        The maximum value of the exponential pulse decay.
   laser_decay         The primary exponential decay array which mostly describes
               the surface return laser event.
   secondary_decay   The exponential decay of the backscatter from within the
               water column.
   agc           An array to equalize returns with depth so near surface
               water column backscatter does't win over a weaker bottom signal.
   bias              A linear tilt which is subtracted from the waveform to
               reduce the likelyhood of triggering on shallow noise.
   da                The return waveform with the computed exponentials substracted
   db                The return waveform equalized by agc and tilted by bias.
*/
  extern bathconf;
  default, win, 4;
  default, graph, 0;
  default, verbose, graph;
  default, keeprejected, 0;

  // hard coded for now
  sample_interval = 1.;

  if(graph) {
    window, win;
    // Embedding in Tk destroys limits, so backup and restore
    lims = limits();
    channel = is_void(forcechannel) ? 0 : forcechannel;
    group = bathconf(settings_group, max(channel, 1));
    tkcmd, swrite(format=
      "::eaarl::bathconf::config %d -raster %d -pulse %d -channel %d -group {%s}",
      win, raster_number, pulse_number, channel, group);
    gridxy, 2, 2;
    if(xfma) fma;
    limits, lims;
  }

  conf = bathconf(settings, (forcechannel ? forcechannel : 1));

  // setup the return struct
  result = BATHPIX();
  // bogus value is -100000, for detecting points we didn't find bottom on
  result.idx = -100000;
  result.rastpix = raster_number + (pulse_number<<24);

  local wf, scan_angle, channel;
  if(raster_number > numberof(edb)) {
    if(graph)
      plot_bath_ctl, channel, wf, raster=raster_number, pulse=pulse_number;
    msg = "No waveform";
    ex_bath_message, graph, verbose, msg;
    return result;
  }

  bathy_lookup_raster_pulse, raster_number, pulse_number, conf.maxsat,
      wf, scan_angle, channel, maxint, forcechannel=forcechannel;

  result.sa = scan_angle;
  wflen = numberof(wf);
  saturated = wf == maxint;
  numsat = numberof(where(saturated));

  restore, hook_invoke("ex_bath_wf",
    save(wf, channel, maxint, saturated, numsat));

  result.channel = channel;

  if(!wflen) {
    if(graph)
      plot_bath_ctl, channel, wf, raster=raster_number, pulse=pulse_number;
    msg = "No waveform";
    ex_bath_message, graph, verbose, msg;
    return result;
  }

  // Dont bother processing returns with more than bathctl.maxsat saturated
  // values.
  if(numsat != 0) {
    if(numsat >= conf.maxsat) {
      msg = swrite(format="%d points saturated", numsat);
      ex_bath_message, graph, verbose, msg;
      if(graph)
        plot_bath_ctl, channel, wf, last=wflen, raster=raster_number, pulse=pulse_number;
      return result;
    }
  }

  local surface_sat_end, surface_intensity, escale;
  bathy_detect_surface, wf, maxint, conf.thresh, conf.sfc_last,
    surface_sat_end, surface_intensity, escale, forcechannel=forcechannel;
  result.first_peak = surface_intensity;

  thresh = conf.thresh;
  if(numsat > 14) {
    thresh = thresh * (numsat-13)*0.65;
  }

  if(graph) {
    plot_bath_ctl, channel, wf, thresh=thresh, raster=raster_number, pulse=pulse_number;
  }

  if(conf.decay == "exponential") {
    wf_decay = bathy_wf_compensate_decay_exp(wf, conf, surface=surface_sat_end,
      max_intensity=escale, sample_interval=sample_interval, graph=graph,
      win=win);
  } else {
    wf_decay = bathy_wf_compensate_decay_lognorm(wf, conf,
      surface=surface_sat_end, max_intensity=escale,
      sample_interval=sample_interval, graph=graph, win=win);
  }

  first = min(wflen, conf.first);
  last = min(wflen, conf.last);

  offset = first - 1;

  local bottom_peak;
  bathy_detect_bottom, wf_decay, first, last, thresh, bottom_peak, msg;

  if(!is_void(msg)) {
    ex_bath_message, graph, verbose, msg;
    return result;
  }

  bathy_compensate_saturation, saturated, bottom_peak;

  bottom_intensity = wf_decay(bottom_peak);
  result.bottom_peak = wf(bottom_peak);

  msg = [];
  bathy_validate_bottom, wf_decay, bottom_peak, first, last, thresh, graph,
    conf.lwing_dist, conf.rwing_dist, conf.lwing_factor, conf.rwing_factor,
    msg;

  if(is_void(msg) || keeprejected) {
    result.idx = bottom_peak + get_member(ops_conf, swrite(format="chn%d_range_bias", channel));
  }

  if(!is_void(msg)) {
    ex_bath_message, graph, verbose, msg;
    return result;
  }

  if(graph) {
    plg, [wf(bottom_peak)+1.5,0], [bottom_peak,bottom_peak],
      marks=0, type=2, color="blue";
    plmk, wf(bottom_peak)+1.5, bottom_peak,
      msize=1.0, marker=7, color="blue", width=10;
    ex_bath_message, graph, 0, swrite(format="%3dns\n%3.0f sfc\n%3.1f cnts(blue)\n%3.1f cnts(black)\n(~%3.1fm)", bottom_peak, double(surface_intensity), bottom_intensity, wf(bottom_peak), (bottom_peak-7)*sample_interval*CNSH2O2X);
  }

  return result;
}

func ex_bath_message(graph, verbose, msg) {
  if(graph) {
    port = viewport();
    plt, strwrap(msg, width=25, paragraph="\n"), port(2), port(4),
      justify="RT", tosys=0, color="red";
  }
  if(verbose) write, "Rejected: "+msg;
}

func bathy_lookup_raster_pulse(raster_number, pulse_number, maxsat, &wf,
&scan_angle, &channel, &maxint, forcechannel=) {
/* DOCUMENT bathy_lookup_raster_pulse(raster_number, pulse_number, maxsat, &wf,
 * &scan_angle, &channel, &maxint, forcechannel=)
  Part of bathy algorithm. Selects the appropriate channel and returns the
  waveform, with bias removed.
*/
  extern ex_bath_rn, ex_bath_rp;
  default, ex_bath_rn, -1;
  // simple cache for raster data
  if(ex_bath_rn != raster_number) {
    raster = decode_raster(rn=raster_number);
    ex_bath_rn = raster_number;
    ex_bath_rp = raster;
  } else {
    raster = ex_bath_rp;
  }
  scan_angle = raster.sa(pulse_number);

  channel = is_void(forcechannel) ? 0 : forcechannel-1;
  do {
    channel++;
    raw_wf = *raster.rx(pulse_number, channel);
    wflen = numberof(raw_wf);
    if(wflen == 0)
      return;
    // list of saturated samples
    saturated = where(raw_wf == 0);
    // saturated sample count
    numsat = numberof(saturated);
  } while(numsat > maxsat && channel < 3 && is_void(forcechannel));

  wf = float(~raw_wf);
  maxint = 255 - long(wf(1));
  wf = wf - wf(1);

  // Apply moving average to smooth wf
  conf = bathconf(settings, channel);
  if(conf.smoothwf > 0 && numberof(wf)) {
    wf = moving_average(wf, bin=(conf.smoothwf*2+1), taper=1);
  }
}

func bathy_detect_surface(wf, maxint, thresh, sfc_last, &surface,
			  &surface_intensity, &escale, forcechannel=) {
/* DOCUMENT bathy_detect_surface(wf, maxint, thresh, &surface,
 * &surface_intensity, &escale)
  Part of bathy algorithm. Detects the surface. However, this is not a -true-
  surface, since for saturated returns the sample of saturation is returned
  instead of a point in the middle of the saturated region.
*/
  wflen = numberof(wf);
  saturated = where(wf == maxint);
  numsat = numberof(saturated);
  // For EAARL, first return saturation should always start in first sfc_last
  // samples (12 for EAARL-A). If a saturated first return is found...
  if((numsat > 1) && (saturated(1) <= sfc_last)) {
    // If all saturated samples are contiguous, only surface is saturated.
    if(saturated(dif)(max) == 1) {
      // Last surface saturated sample is the last in saturated.
      surface = saturated(0);
    // Otherwise, bottom is also saturated.
    } else {
      // Last surface saturated sample is where the first contiguous series
      // ends.
      surface = saturated(where(saturated(dif) > 1))(1);
    }
    escale = maxint - 1;

  // Else if no saturated first return is found...
  } else {
    if(forcechannel == 4) {
      wantlen = 17;
    } else {
      wantlen = 10;
    }

    wfl = numberof(wf);
    if(wfl > wantlen + 8) {
      wfl = wantlen + 8;
      surface = wf(1:min(wantlen,wflen))(mxx);
    } else {
      surface = min(wantlen, wflen);
    }

    wfl = min(wantlen, wfl);

    escale = wf(1:wfl)(max) - 1;
  }

  dd = wf(dif);
  xr = where(((dd >= thresh)(dif)) == 1);
  if(numberof(xr)) {
    // find surface peak now
    surface_peak = wf(xr(1):min(wflen,xr(1)+5))(mxx) + xr(1) - 1;
    surface_intensity = wf(surface_peak);
  } else {
    surface_intensity = 0;
  }
}

func bathy_wf_compensate_decay_exp(wf, conf, surface=, max_intensity=,
sample_interval=, graph=, win=) {
/* DOCUMENT bathy_wf_compensate_decay_exp(wf, conf, surface=, max_intensity=,
 * sample_interval=, graph=, win=)
  Returns an adjusted waveform WF_DECAY that compensates for attenuation of
  light in water.
*/
  default, sample_interval, 1.0;
  wflen = numberof(wf);
  attdepth = indgen(0:wflen-1) * sample_interval * CNSH2O2X;

  laser_decay = exp(conf.laser * attdepth) * max_intensity;
  secondary_decay = exp(conf.water * attdepth) * max_intensity;

  laser_decay(surface:0) = laser_decay(1:0-surface+1) +
    secondary_decay(1:0-surface+1)*.25;
  laser_decay(1:min(wflen,surface+1)) = max_intensity;

  agc = 1.0 - exp(conf.agc * attdepth);
  agc(surface:0) = agc(1:0-surface+1);
  agc(1:surface) = 0.0;

  bias = (1-agc) * -5.0;
  wf_temp = wf - laser_decay;
  wf_decay = wf_temp*agc + bias;

  if(graph) {
    wbkp = current_window();
    window, win;
    plg, laser_decay, color="magenta";
    plg, agc*40, color=[100,100,100];
    plmk, wf_temp, msize=.2, marker=1, color="black";
    plg, wf_temp;
    plmk, wf_decay, msize=.2, marker=1, color="blue";
    plg, wf_decay, color="blue";
    window_select, wbkp;
  }

  return wf_decay;
}

func bathy_wf_compensate_decay_lognorm(cache, wf, conf, surface=,
max_intensity=, sample_interval=, graph=, win=) {
/* DOCUMENT bathy_wf_compensate_decay_lognorm(wf, conf, surface=,
 * max_intensity=, sample_interval=, graph=, win=)
  Returns an adjusted waveform WF_DECAY that compensates for attenuation of
  light in water.
*/
  default, sample_interval, 1.0;

  wflen = numberof(wf);
  opts = [conf.mean, conf.stdev, conf.xshift, conf.xscale];
  if(anyof(opts != cache.opts) || wflen > cache.len) {
    len = max(wflen, 300);
    decay = log_normal(indgen(1:len), conf.mean, conf.stdev,
      xshift=-conf.xshift, xscale=conf.xscale);
    save, cache, opts, len, decay;
  } else {
    decay = cache.decay;
  }

  wflen = numberof(wf);
  if(wflen < conf.tiepoint) {
    // If the waveform is too short, abort and flatten wf
    return wf * 0;
  }
  attdepth = indgen(0:wflen-1) * sample_interval * CNSH2O2X;

  decay = decay(:wflen) * (wf(conf.tiepoint) / decay(conf.tiepoint));

  agc = 1.0 - exp(conf.agc * attdepth);
  agc(surface:0) = agc(1:0-surface+1);
  agc(1:surface) = 0.0;

  bias = (1-agc) * -5.0;
  wf_temp = wf - decay;
  wf_decay = wf_temp*agc + bias;

  if(graph) {
    wbkp = current_window();
    window, win;
    plg, decay, color="magenta";
    plg, agc*40, color=[100,100,100];
    plmk, wf_temp, msize=.2, marker=1, color="black";
    plg, wf_temp;
    plmk, wf_decay, msize=.2, marker=1, color="blue";
    plg, wf_decay, color="blue";
    window_select, wbkp;
  }

  return wf_decay;
}
bathy_wf_compensate_decay_lognorm = closure(bathy_wf_compensate_decay_lognorm,
  save(opts=[0,0,0,0], len=0, decay=[]));

func bathy_detect_bottom(wf, first, last, thresh, &bottom_peak, &msg) {
/* DOCUMENT bathy_detect_bottom(wf, first, last, thresh, &bottom_peak, &msg)
  Detects a bottom return in a waveform.
*/
  bottom_peak = msg = [];
  offset = first - 1;

  last_new = offset + remove_noisy_tail(wf(first:last), thresh=thresh,
      verbose=0, idx=1);
  if(last_new - first < 4) {
    msg = "Waveform too short after removing noisy tail";
    return;
  }
  peaks = extract_peaks_first_deriv(wf(first:last_new), thresh=thresh);

  if(!numberof(peaks)) {
    msg = "No significant inflection in backscattered waveform after decay";
    return;
  }

  bottom_peak = peaks(0) + offset;
}

func bathy_compensate_saturation(saturated, &bottom) {
  is_sat = saturated(bottom);
  // Occasionally, the AGC pushes the peak off the saturated section by one
  // sample
  if(!is_sat && saturated(bottom-1)) {
    is_sat = 1;
    bottom--;
  }
  sat0 = sat1 = bottom;
  while(sat0 > 1 && saturated(sat0-1)) sat0--;
  while(sat1 < numberof(saturated) && saturated(sat1+1)) sat1++;
  bottom = long(0.5*(sat0+sat1));
}

func bathy_validate_bottom(wf, bottom, first, last, thresh, graph, lwing_dist,
rwing_dist, lwing_factor, rwing_factor, &msg) {
/* DOCUMENT bathy_validate_bottom(wf, bottom, first, last, thresh, graph,
   lwing_dist, rwing_dist, lwing_factor, rwing_factor, &msg)
  Performs some analysis on a detected bottom to see if it seems legitimate.
*/
  msg = [];

  // pulse wings
  lwing_idx = bottom - lwing_dist;
  rwing_idx = bottom + rwing_dist;

  // test pw with 9-6-01:17673:50
  // first, just check to see if anything is above thresh
  if((wf(bottom) <= thresh) || (last < rwing_idx)) {
    msg = "Below threshold";
    return;
  }

  if((lwing_idx < first) || (rwing_idx > last)) {
    msg = "Too close to edge gate";
    return;
  }

  // define pulse wings;
  lwing_thresh = lwing_factor * wf(bottom);
  rwing_thresh = rwing_factor * wf(bottom);

  if(graph) {
    plmk, lwing_thresh, lwing_idx, marker=5, color="magenta", msize=0.4, width=10;
    plmk, rwing_thresh, rwing_idx, marker=5, color="magenta", msize=0.4, width=10;
  }

  if((wf(lwing_idx) > lwing_thresh) || (wf(rwing_idx) > rwing_thresh)) {
    msg = "Bad pulse shape";
    if(graph) {
      plmk, wf(bottom)+1.5, bottom+1,
        msize=1.0, marker=6, color="red", width=10;
    }
  }
}

func plot_bath_ctl(channel, wf, thresh=, first=, last=, raster=, pulse=) {
  extern bath_ctl;
  default, channel, 1;
  conf = bathconf(settings, channel);
  default, thresh, conf.thresh;
  default, first, conf.first;
  default, last, conf.last;
  if(!is_void(raster) && !is_void(pulse))
    pltitle, swrite(format="rn:%d pulse:%d chan:%d", raster, pulse, channel);
  else
    pltitle, swrite(format="chan:%d", channel);
  if(!is_void(thresh)) {
    plg, [thresh,thresh], [first,last], marks=0, color="red";
    plg, [0,thresh], [first,first], marks=0, color="green", width=7;
    plg, [0,thresh], [last,last], marks=0, color="red", width=7;
  }
  if(!is_void(wf)) {
    plmk, wf, msize=.275, marker=1, color="black";
    plg, wf, color=black, width=4;
  }
}
