// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
require, "general.i";

local BATHPIX;
/* DOCUMENT BATHPIX
  Struct used for holding result of ex_bath.

  struct BATHPIX {
    long rastpix;       // raster + pulse << 24
    short sa;           // scan angle
    short idx;          // bottom index
    short bottom_peak;  // peak amplitude of bottom signal
    short first_peak;   // peak amplitude of the surface signal
  };
*/
struct BATHPIX {
  long rastpix;
  short sa, idx, bottom_peak, first_peak;
};

local BATH_CTL;
/* DOCUMENT BATH_CTL
  Struct used for holding configuration settings for bathy algorithms.

  struct BATH_CTL {
    float laser;  // system exponential decay  (-1.5)
    float water;  // water column exponential decay (-0.3)
    float agc;    // exponential equalizer (-5)
    float thresh; // threshold value (3)
    int first;    // first nanosecond to consider (maxdepth in ns)  (150)
    int last;     // last nanosecond to consider (maxdepth in ns)  (150)
    int maxsat;   // Maximum number of saturated points.
  };
*/
struct BATH_CTL {
  float laser, water, agc, thresh;
  int first, last, maxsat;
};

local bath_ctl, bath_ctl_chn4;
/* DOCUMENT
  bath_ctl - settings for channels 1 through 3
  bath_ctl_chn4 - settings for channel 4

  These two variables are instances of BATH_CTL and store the settings for the
  bathy algorithms.
*/
default, bath_ctl, BATH_CTL();
default, bath_ctl_chn4, BATH_CTL();

func bath_ctl_save(filename) {
/* DOCUMENT bath_ctl_save, filename
  Saves the current bathy configuration settings to the given JSON file.

  By convention, these files should be named *-bctl.json
*/
  extern bath_ctl, bath_ctl_ch4n, _hgid;
  data = save(
    bath_ctl, bath_ctl_chn4,
    "save environment", save(
      "path", mission_path(),
      "user", get_user(),
      "host", get_host(),
      "timestamp", soe2iso8601(getsoe()),
      "repository", _hgid
    )
  );
  json = json_encode(data, indent=2);
  f = open(filename, "w");
  write, f, format="%s\n", json;
  close, f;
}

func bath_ctl_load(filename) {
/* DOCUMENT bath_ctl_load, filename
  Loads the bathy configuration settings defined in the given filename.

  Filename should be a *.json file as exported by bath_ctl_save. In this case,
  it will set the variables bath_ctl and bath_ctl_chn4.

  Alternately, the filename can also be a *.bctl file as exported in older
  versions of ALPS. This is legacy support and will only set bath_ctl;
  bath_ctl_chn4 will be given all zero values.
*/
  extern bath_ctl, bath_ctl_chn4;
  bath_ctl = bath_ctl_chn4 = BATH_CTL();

  lines = rdfile(filename);
  // Legacy support for tcl-style .bctl files
  if(file_extension(filename) == ".bctl") {
    key = val = [];
    good = regmatch("set bath_ctl\\((.*)\\) (.*)", lines, , key, val);
    w = where(good);
    for(i = 1; i <= numberof(w); i++) {
      j = w(i);
      if(has_member(bath_ctl, key(j)))
        get_member(bath_ctl, key(j)) = atod(val(j));
    }
  // Support for current format
  } else {
    data = json_decode(lines);
    if(h_has(data, "bath_ctl")) {
      keys = get_members(bath_ctl);
      for(i = 1; i <= numberof(keys); i++) {
        if(h_has(data.bath_ctl, keys(i)))
          get_member(bath_ctl, keys(i)) = data.bath_ctl(keys(i));
      }
    }
    if(h_has(data, "bath_ctl_chn4")) {
      keys = get_members(bath_ctl_chn4);
      for(i = 1; i <= numberof(keys); i++) {
        if(h_has(data.bath_ctl_chn4, keys(i)))
          get_member(bath_ctl_chn4, keys(i)) = data.bath_ctl_chn4(keys(i));
      }
    }
  }
}

func run_bath(nil, start=, stop=, center=, delta=, last=, forcechannel=,
graph=, pse=, msg=) {
  extern bath_ctl;
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

  if(forcechannel == 4) {
    if(bath_ctl.laser == 0) {
      error, "You must first configure bathy settings (bath_ctl).";
    }
  } else {
    if(bath_ctl_chn4.laser == 0) {
      error, "You must first configure bathy settings for channel 4 (bath_ctl_chn4).";
    }
  }

  count = stop - start + 1;
  depths = array(BATHPIX, 120, count);

  status, start, msg=msg;
  for(j=1, rn=start; rn <= stop; j++, rn++) {
    for(pulse=1; pulse<=120; pulse++) {
      depths(pulse,j) = ex_bath(rn, pulse, last=last, forcechannel=, graph=graph);
      pause, pse;
    }
    status, progress, j, count;
  }
  status, finished;
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

func ex_bath(raster_number, pulse_number, last=, forcechannel=, graph=, win=,
xfma=, parent=, verbose=) {
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
  extern bath_ctl, bath_ctl_chn4;
  default, win, 4;
  default, graph, 0;
  default, verbose, graph;

  // hard coded for now
  sample_interval = 1.;

  if(graph) {
    window, win;
    // Embedding in Tk destroys limits, so backup and restore
    lims = limits();
    if(!is_void(parent)) {
      window_embed_tk, win, parent, xfma;
      tkcmd, swrite(format="::eaarl::settings::bath_ctl::launch_win %d %d %d %d",
        win, raster_number, pulse_number, forcechannel);
    }
    gridxy, 2, 2;
    if(xfma) fma;
    limits, lims;
  }

  if(forcechannel == 4) {
    conf = bath_ctl_chn4;
  } else {
    conf = bath_ctl;
  }

  // setup the return struct
  result = BATHPIX();
  result.rastpix = raster_number + (pulse_number<<24);

  local wf, scan_angle, channel;
  bathy_lookup_raster_pulse, raster_number, pulse_number, conf.maxsat,
      wf, scan_angle, channel, maxint, forcechannel=forcechannel;

  result.sa = scan_angle;
  wflen = numberof(wf);
  numsat = numberof(where(wf == maxint));

  if(!wflen)
    return result;

  // Dont bother processing returns with more than bathctl.maxsat saturated
  // values.
  if(numsat != 0) {
    if(numsat >= conf.maxsat) {
      ex_bath_message, graph, verbose, swrite(format="%d points saturated", numsat);
      if(graph)
        plot_bath_ctl, channel, wf, last=wflen;
      return result;
    }
  }

  local surface_sat_end, surface_intensity, escale;
  bathy_detect_surface, wf, maxint, conf.thresh,
      surface_sat_end, surface_intensity, escale;
  result.first_peak = surface_intensity;

  thresh = conf.thresh;
  if(numsat > 14) {
    thresh = thresh * (numsat-13)*0.65;
  }

  if(graph) {
    plot_bath_ctl, channel, wf, thresh=thresh;
  }

  wf_decay = bathy_wf_compensate_decay(wf, surface=surface_sat_end,
      laser_coeff=conf.laser, water_coeff=conf.water,
      agc_coeff=conf.agc, max_intensity=escale,
      sample_interval=sample_interval, graph=graph, win=win);

  first = min(wflen, conf.first);
  last = min(wflen, conf.last);

  offset = first - 1;

  local bottom_peak, msg;
  bathy_detect_bottom, wf_decay, first, last, thresh, bottom_peak, msg;

  if(!is_void(msg)) {
    ex_bath_message, graph, verbose, msg;
    return result;
  }

  bottom_intensity = wf_decay(bottom_peak);
  result.bottom_peak = wf(bottom_peak);

  msg = [];
  bathy_validate_bottom, wf_decay, bottom_peak, first, last, thresh, graph, msg;

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

  result.idx = bottom_peak;
  return result;
}

func ex_bath_message(graph, verbose, msg) {
  if(graph) {
    port = viewport();
    plt, strwrap(msg, width=25, paragraph="\n"), port(2), port(3),
      justify="RB", tosys=0, color="red";
  }
  if(verbose) write, "Rejected: "+msg+"\n";
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
}

func bathy_detect_surface(wf, maxint, thresh, &surface, &surface_intensity,
&escale) {
/* DOCUMENT bathy_detect_surface(wf, maxint, thresh, &surface,
 * &surface_intensity, &escale)
  Part of bathy algorithm. Detects the surface. However, this is not a -true-
  surface, since for saturated returns the sample of saturation is returned
  instead of a point in the middle of the saturated region.
*/
  wflen = numberof(wf);
  saturated = where(wf == maxint);
  numsat = numberof(saturated);
  // For EAARL, first return saturation should always start in first 12 samples.
  // If a saturated first return is found...
  if((numsat > 1) && (saturated(1) <= 12)) {
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
    wfl = numberof(wf);
    if(wfl > 18) {
      wfl = 18;
      surface = wf(1:min(10,wflen))(mxx);
    } else {
      surface = min(10,wflen);
    }
    wfl = min(10, wfl);
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

func bathy_wf_compensate_decay(wf, surface=, laser_coeff=, water_coeff=,
agc_coeff=, max_intensity=, sample_interval=, graph=, win=) {
/* DOCUMENT bathy_wf_compensate_decay(wf, surface=, laser_coeff=, water_coeff=,
 * agc_coeff=, max_intensity=, sample_interval=, graph=, win=)
  Returns an adjusted waveform WF_DECAY that compensates for attenuation of
  light in water.
*/
  default, sample_interval, 1.0;
  wflen = numberof(wf);
  attdepth = indgen(0:wflen-1) * sample_interval * CNSH2O2X;

  laser_decay = exp(laser_coeff * attdepth) * max_intensity;
  secondary_decay = exp(water_coeff * attdepth) * max_intensity;

  laser_decay(surface:0) = laser_decay(1:0-surface+1) +
    secondary_decay(1:0-surface+1)*.25;
  laser_decay(1:min(wflen,surface+1)) = max_intensity;

  agc = 1.0 - exp(agc_coeff * attdepth);
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

func bathy_detect_bottom(wf, first, last, thresh, &bottom_peak, &msg) {
/* DOCUMENT bathy_detect_bottom(wf, first, last, thresh, &bottom_peak, &msg)
  Detects a bottom return in a waveform.
*/
  bottom_peak = msg = [];
  offset = first - 1;

  last_new = offset + remove_noisy_tail(wf(first:last), thresh=thresh,
      verbose=verbose, idx=1);
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

func bathy_validate_bottom(wf, bottom, first, last, thresh, graph, &msg) {
/* DOCUMENT bathy_validate_bottom(wf, bottom, first, last, thresh, graph, &msg)
  Performs some analysis on a detected bottom to see if it seems legitimate.
*/
  msg = [];

  // pulse wings
  lwing_idx = bottom - 1;
  rwing_idx = bottom + 3;

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
  lwing_thresh = 0.9 * wf(bottom);
  rwing_thresh = 0.9 * wf(bottom);

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

func plot_bath_ctl(channel, wf, thresh=, first=, last=) {
  extern bath_ctl;
  default, channel, 1;
  if(channel == 4) {
    conf = bath_ctl_chn4;
  } else {
    conf = bath_ctl;
  }
  default, thresh, conf.thresh;
  default, first, conf.first;
  default, last, conf.last;
  pltitle, swrite(format="Channel %d", channel);
  if(!is_void(thresh)) {
    plg, [thresh,thresh], [first,last], marks=0, color="red";
    plg, [0,thresh], [first,first], marks=0, color="green", width=7;
    plg, [0,thresh], [last,last], marks=0, color="red", width=7;
  }
  plmk, wf, msize=.2, marker=1, color="black";
  plg, wf, color=black, width=4;
}
