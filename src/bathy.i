// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
require, "general.i";
/*
  W. Wright

  10/3/02
  WW. Changed the algo. so non saturated surface waveforms
  which contain shallow depths will begin the exponential decay
  at a fixed 9ns point in the waveform. The previous method
  would locate the peak of a shallow bottom signal which was
  within the first 18ns of the waveform and it would improperly
  begin the decay at that point.  It should properly begin
  at the threshold crossing of the surface return.
  which is typically 9ns or so, but it's not certain.

  7-4-02
  WW Added tk based progress bar.

  5-14-02
  WW Added bath_ctl structure
  Changed thresh from fixed for all waveforms to self adjusting
  based on how many surface pixels are saturated.  This is because
  the subsurface noise goes up significantly when the surface is
  driven far into saturation.  The function needs to be carefully
  evaluated to determine the exact relationship between noise level
  changes and the required threshold change.
*/

struct BATHPIX {
  int rastpix;         // raster + pulse << 24
  short sa;            // scan angle
  short idx;           // bottom index
  short bottom_peak;   // peak amplitude of bottom signal
  short first_peak;    // peak amplitude of the surface signal
};

// 94000
func bath_winpix(m) {
  extern _depth_display_units;
  extern rn;
  window, 3;
  idx = int(mouse()(1:2));
  idx;
  // ******* IMPORTANT! The *2 below is there cuz we usually only look at
  // every other raster.
  rn = m(idx(1), idx(2)*2).rastpix;   // get the *real* raster number.
  rn;
  pix = rn / 2^24;
  rn &= 0xffffff;
  r = get_erast(rn= rn);
  rp = decode_raster(r);
  window, 1;
  fma;
  aa = ndrast(rp, units=_depth_display_units);
  pix;
  rn;
}

func run_bath(rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=) {
  extern bath_ctl;
  default, last, 250;
  default, graph, 0;
  default, pse, 0;

  if(is_void(rn) || is_void(len)) {
    if(!is_void(center) && !is_void(delta)) {
      rn = center - delta;
      len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
      rn = start-1;
      len = stop - start;
    } else {
      write, "Input parameters not correctly defined.  "+
        "See help, run_bath.  Please start again.";
      return 0;
    }
  }

  if(is_void(bath_ctl) || bath_ctl.laser == 0.0) {
    define_bath_ctl;
    return 0;
  }

  depths = array(BATHPIX, 120, len);

  // set update interval for progress indicator
  udi = (_ytk ? 10 : 25);

  for(j=1; j<=len; j++) {
    if((!(j % udi)) || ( j==len))
      if(_ytk)
        tkcmd, swrite(format="set progress %d", j*100/len);
      else
        write, format="%5d of %5d rasters completed \r",j,len;
    for(i=1; i<119; i++) {
      depths(i,j) = ex_bath(rn+j, i, last = last, graph=graph);
      pause, pse;
    }
  }
  return depths;
}

struct BATH_CTL{
  // Settings
  float laser;   // system exponential decay  (-1.5)
  float water;   // water column exponential decay (-0.3)
  float agc;     // exponential equalizer (-5)
  float thresh;  // threshold value (3)
  int   first;   // first nanosecond to consider (maxdepth in ns)  (150)
  int   last;    // last nanosecond to consider (maxdepth in ns)  (150)
  int   maxsat;  // Maximum number of saturated points.

  //// Data area
  float a(256);   // array for interim waveform data
};

extern bath_ctl;
/* DOCUMENT extern struct bath_ctl

  laser water agc   thresh
  -2.4       -1.5    -3.0 4.0   tampa and keys laser decay
  -2.4        -0.6    -0.3   4.0   keys
  -2.4       -7.5    -5.0 4.0   wva

  Do this to set the values:

  bath_ctl.laser = -1.5
  bath_ctl.water = -0.6
  bath_ctl.agc   = -5.0
  bath_ctl.thresh=  4.0
*/

default, bath_ctl, BATH_CTL();

func define_bath_ctl {
/* DOCUMENT define_bath_ctl;
  This function defines the structure bath_ctl.
  amar nayegandhi 06/05/2002
*/
  extern bath_ctl;
  default, bath_ctl, BATH_CTL();

  if(bath_ctl.last == 0) {
    tkcmd, "bathctl";
    tk_messageBox("You must first configure "+
        "the system for the water properties",
        "ok");
  }
}

func show_bath_constants {
  extern mindata;
  if(!is_void(mindata)) {
    rn = mindata(0).rn&0xffffff;
    pulse = mindata(0).rn>>24;
    ex_bath, rn, pulse, win=0, xfma=1, graph=1;
  }
}

func ex_bath(raster_number, pulse_number, last=, graph=, win=, xfma=, verbose=) {
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
  We come out of this with the last_surface_sat set to the last
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
   nsat          A list of saturated pixels in this waveform
   numsat        Number of saturated pixels in this waveform
   last_surface_sat  The last pixel saturated in the surface region of the
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
  extern ex_bath_rn, ex_bath_rp, a, db, bath_ctl;
  default, win, 4;
  default, ex_bath_rn, -1;
  default, graph, 0;
  default, verbose, graph;
  default, oldbath, 0;

  result = BATHPIX();       // setup the return struct
  result.rastpix = raster_number + (pulse_number<<24);

  if(ex_bath_rn != raster_number) {  // simple cache for raster data
    raster = decode_raster(get_erast(rn=raster_number));
    ex_bath_rn = raster_number;
    ex_bath_rp = raster;
  } else {
    raster = ex_bath_rp;
  }

  result.sa = raster.sa(pulse_number);
  channel = 0;
  do {
    channel++;
    wf = *raster.rx(pulse_number, channel);
    n = numberof(wf);
    if(n == 0)
      return result;
    // list of saturated samples
    nsat = where(wf == 0);
    // saturated sample count
    numsat = numberof(nsat);
  } while(numsat > bath_ctl.maxsat && channel < 3);

  dbias = int(~wf(1)+1);
  bath_ctl.a(1:n) = float((~wf+1) - dbias);

  // Dont bother processing returns with more than bathctl.maxsat saturated
  // values.
  if(numsat != 0)
    if(numsat >= bath_ctl.maxsat) {
      if(graph) {
        window, win;
        gridxy, 2, 2;
        if(xfma) fma;
        last = n;
        plt, swrite(format="%d points\nsaturated.", numsat),
          (limits()(1:2)(dif)/2)(1),
          (limits()(3:4)(dif)/2)(1),
          tosys=1,color="red";
        plot_bath_ctl, channel, n, pulse_number, last=last;
      }
      if(verbose)
        write, format="Rejected: Saturation. numsat=%d\n", numsat;
      return result;
    }

  // For EAARL, first return saturation should always start in first 12 samples.
  // If a saturated first return is found...
  if((numsat > 1) && (nsat(1) <= 12)) {
    // If all saturated samples are contiguous, only surface is saturated.
    if(nsat(dif)(max) == 1) {
      // Last surface saturated sample is the last in nsat.
      last_surface_sat = nsat(0);
    // Otherwise, bottom is also saturated.
    } else {
      // Last surface saturated sample is where the first contiguous series
      // ends.
      last_surface_sat = nsat(where(nsat(dif) > 1))(1);
    }
    escale = 255 - dbias;
  // Else if no saturated first return is found...
  } else {
    wfl = numberof(wf);
    if(wfl > 18) {
      wfl = 18;
      last_surface_sat = wf(1:10)(mnx);
    } else {
      last_surface_sat = 10;
    }
    wfl = min(10, wfl);
    escale = 255 - dbias - wf(1:wfl)(min);
  }

  // Attenuation depths in water
  attdepth = indgen(0:255) * CNSH2O2X;
  if(oldbath) attdepth *= (256/255.);

  laser_decay     = exp(bath_ctl.laser * attdepth) * escale;
  secondary_decay = exp(bath_ctl.water * attdepth) * escale;

  laser_decay(last_surface_sat:0) = laser_decay(1:0-last_surface_sat+1) +
    secondary_decay(1:0-last_surface_sat+1)*.25;
  laser_decay(1:last_surface_sat+1) = escale;

  agc     = 1.0 - exp( bath_ctl.agc * attdepth);
  agc(last_surface_sat:0) = agc(1:0-last_surface_sat+1);
  agc(1:last_surface_sat) = 0.0;

  bias = (1-agc) * -5.0;

  da = bath_ctl.a - laser_decay;
  db = da*agc + bias;

  //new
  thresh = bath_ctl.thresh;
  dd = bath_ctl.a(1:n)(dif);
  xr = where(((dd >= thresh)(dif)) == 1);
  nxr = numberof(xr);
  if(nxr > 0) {
    mx1 = bath_ctl.a(xr(1):xr(1)+5)(mxx) + xr(1) - 1; // find surface peak now
    mv1 = bath_ctl.a(mx1);
  } else mv1 = 0;

  if(numsat > 14) {
    thresh = thresh * (numsat-13)*0.65;
  }

  if(graph) {
    window, win;
    gridxy, 2, 2;
    if(xfma) fma;
    plot_bath_ctl, channel, n, pulse_number, thresh=thresh, laser_decay=laser_decay, agc=agc;
    plmk, da(1:n), msize=.2, marker=1, color="black";
    plg, da(1:n);
    plmk, db(1:n), msize=.2, marker=1, color="blue";
    plg, db(1:n), color="blue";
  }

  first = bath_ctl.first;
  last = bath_ctl.last;

  n = min(n, last);
  first = min(n, first);

  // Added by AN - May/June 2011 to try and find the last peak of the resultant (db) waveform.  The algorithm used to find only the "max" peak of db.
  db_good = db(first:n);
  db_good = remove_noisy_tail(db_good, thresh=thresh, verbose=verbose);
  if (numberof(db_good) < 5) {
    if (graph) {
        plt, swrite("Waveform too short \n after removing noisy tail.\n Giving up."), mvi, bath_ctl.a(mvi)+2.0, tosys=1, color="red";
    }
    if (verbose) {
        write, "Waveform too short after removing noisy tail.  Giving up.";
    }
    return result;
  }
  xr = extract_peaks_first_deriv(db_good, thresh=thresh);

  nxr = numberof(xr);
  if (nxr == 0) {
    if (graph) plt, swrite("No significant inflection\n in bacscattered waveform\n after decay.  Giving up"), mvi, bath_ctl.a(mvi)+2.0, tosys=1, color="red";
    return result;
  }
  if (nxr >=1) {
    mv = db_good(xr(0));
    mvi = first+xr(0)-1;
  }

  // test pw with 9-6-01:17673:50
  // first, just check to see if anything is above thresh
  lpx = mvi - 1;
  rpx = mvi + 3;
  if((mv > thresh) && (n >= rpx)) {
    if((lpx < first) || (rpx > last)) {
      if(graph) plt, swrite("Too close\nto gate edge."),
        mvi, bath_ctl.a(mvi)+2.0, tosys=1, color="red";
      return result;
    }
    // define pulse wings;
    l_wing = 0.9 * mv;
    r_wing = 0.9 * mv;
    if((db(lpx) <= l_wing) && (db(rpx) <= r_wing)) {
      mx = mvi;
      if(graph) {
        show_pulse_wings, l_wing, r_wing;
        plg,  [bath_ctl.a(mx)+1.5,0], [mx,mx],
          marks=0, type=2, color="blue";
        plmk, bath_ctl.a(mx)+1.5, mx,
          msize=1.0, marker=7, color="blue", width=10;
        plt, swrite(format="    %3dns\n     %3.0f sfc\n    %3.1f cnts(blue)\n   %3.1f cnts(black)\n     (~%3.1fm)", mvi, mv1, mv, bath_ctl.a(mx), (mvi-7)*CNSH2O2X), mx, bath_ctl.a(mx)+3.0, tosys=1, color="blue";
      }
      result.sa = raster.sa(pulse_number);
      result.idx = mx;
      result.bottom_peak = bath_ctl.a(mx);
      //new
      result.first_peak = mv1;
    } else {
      if(graph) {
        show_pulse_wings, l_wing, r_wing;
        plmk, bath_ctl.a(mvi)+1.5, mvi+1,
          msize=1.0, marker=6, color="red", width=10;
        plt, "Bad pulse\n shape",
          mvi+2.0, bath_ctl.a(mvi)+2.0, tosys=1, color="red";
      }
      if(verbose)
        write,"Rejected: Pulse shape. \n";
    }
  } else {
    if(graph)
      plt, "Below\nthreshold", mvi+2.0,
        bath_ctl.a(mvi)+2.0, tosys=1,color="red";
    if(verbose)
      write, "Rejected: below threshold\n";
    result.idx = 0;
    result.bottom_peak = bath_ctl.a(mvi);
    //new
    result.first_peak = mv1;
  }
  return result;
}

func show_pulse_wings(l_wing, r_wing) {
  plmk, l_wing, lpx, marker=5, color="magenta", msize=0.4, width=10;
  plmk, r_wing, rpx, marker=5, color="magenta", msize=0.4, width=10;
}

func plot_bath_ctl(chn, n, i, thresh=, first=, last=, laser_decay=, agc=) {
  extern bath_ctl;
  default, chn, 1;
  default, thresh, bath_ctl.thresh;
  default, first, bath_ctl.first;
  default, last, bath_ctl.last;
  if(chn == 1) pltitle, "Black (90\%) Channel";
  if(chn == 2) pltitle, "Red (9\%) Channel";
  if(chn == 3) pltitle, "Blue (1\%) Channel";
  if(!is_void(thresh)) {
    plg, [thresh,thresh], [first,last], marks=0, color="red";
    plg, [0,thresh], [first,first], marks=0, color="green", width=7;
    plg, [0,thresh], [last,last], marks=0, color="red", width=7;
  }
  plmk, bath_ctl.a(1:n), msize=.2, marker=1, color="black";
  plg, bath_ctl.a(1:n), color=black, width=4;
  if(!is_void(laser_decay)) plg, laser_decay, color="magenta";
  if(!is_void(agc)) plg, agc*40, color=[100,100,100];
}
