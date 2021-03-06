// vim: set ts=2 sts=2 sw=2 ai sr et:

local VEG_CONF;
/* DOCUMENT VEG_CONF
  Struct used for configuring veg processing.

  struct VEG_CONF {
    float thresh;     // Threshold
    int max_sat(3);   // Maximum number of sat dig pixels before switching
  };
*/
struct VEG_CONF {
  float thresh;
  int max_sat(3);
  short noiseadj;
};

local VEGPIX;
/* DOCUMENT VEGPIX
  Struct used for holding the result of ex_veg.

  struct VEGPIX {
    int rastpix;   // raster + pulse << 24
    short sa;      // scan angle
    float mx1;     // first pulse index
    short mv1;     // first pulse peak value
    float mx0;     // last pulse index
    short mv0;     // last pulse peak value
    char nx;       // number of return pulses found
  };
*/
struct VEGPIX {
  int rastpix;
  short sa;
  float mx1;
  short mv1;
  float mx0;
  short mv0;
  char nx;
};

local VEGPIXS;
/* DOCUMENT VEGPIXS
  Struct used for holding the result of ex_veg_all.

  struct VEGPIXS {
    int rastpix;   // raster + pulse << 24
    short sa;      // scan angle
    float mx(10);  // range in ns of all return peaks from irange
    short mr(10);  // range in ns of all return peaks from irange
    short mv(10);  // intensities of all return peaks (max 10)
    char nx;       // number of return pulses found
  };
*/
struct VEGPIXS {
  int rastpix;
  short sa;
  float mx(10);
  short mr(10), mv(10);
  char nx;
};

func define_veg_conf {
/* DOCUMENT define_veg_conf;
  If extern veg_conf is not already initialized, this will define it.
*/
  extern veg_conf, ops_conf;
  if(is_void(veg_conf)) {
    veg_conf = VEG_CONF(thresh=4.0, noiseadj=0);
    if(!is_void(ops_conf))
      veg_conf.max_sat(*) = ops_conf.max_sfc_sat;
  }
}

func veg_winpix(m) {
  extern _depth_display_units, rn;
  window, 3;
  idx = int(mouse()(1:2));
  idx;
  // IMPORTANT! The *2 below is there because we usually only look at every
  // other raster.
  rn = m(idx(1), idx(2)*2).rastpix; // get the *real* raster number.
  rn;
  local raster, pulse;
  parse_rn, rn, raster, pulse;
  window, 1;
  fma;
  aa = ndrast(raster, units=_depth_display_units);
  pulse;
  raster;
}

func run_vegx(rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=,
use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=, multi_peaks=,
forcechannel=, msg=) {
/* DOCUMENT depths = run_vegx(rn=, len=, start=, stop=, center=, delta=, last=,
  graph=, pse=, use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=,
  multi_peaks=, forcechannel=, msg=)

  This returns an array of VEGPIX or VEGPIXS.

  One of the following pairs of options must provided to specify which data to
  process:
    rn, len
    center, delta
    start, stop

  Options:
    rn = Raster number
    len = Number of rasters to process, starting from rn.
	start = Raster number to start with.
    stop = Ending raster number.
    center = Center raster when doing before and after.
    delta = Number of rasters to process before and after.
    pse = If specified, this is the length of time in milleseconds to pause
      between calls to ex_veg. (Default: pse=0)
    multi_peaks = return only first and last peaks (default), or return first 10 peaks.
      Deault: 0 (first and last)
    msg = message to display in status bar.

  Options passed to ex_veg (see help, ex_veg for details):
    graph = (Default: graph=0)
    last = (Default: last=250)
    use_be_centroid =
    use_be_peak =
    hard_surface =

  SEE ALSO: first_surface, ex_veg, ex_veg_all
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering run_vegx";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  rn="+pr1(rn);
    logger, debug, log_id+"  len="+pr1(len);
    logger, debug, log_id+"  start="+pr1(start);
    logger, debug, log_id+"  stop="+pr1(stop);
    logger, debug, log_id+"  center="+pr1(center);
    logger, debug, log_id+"  delta="+pr1(delta);
    logger, debug, log_id+"  last="+pr1(last);
    logger, debug, log_id+"  graph="+pr1(graph);
    logger, debug, log_id+"  pse="+pr1(pse);
    logger, debug, log_id+"  use_be_centroid="+pr1(use_be_centroid);
    logger, debug, log_id+"  use_be_peak="+pr1(use_be_peak);
    logger, debug, log_id+"  hard_surface="+pr1(hard_surface);
    logger, debug, log_id+"  alg_mode="+pr1(alg_mode);
    logger, debug, log_id+"  multi_peaks="+pr1(multi_peaks);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
    logger, debug, log_id+"  msg="+pr1(msg);
  }
  extern ops_conf, veg_conf;
  default, graph, 0;
  default, last, 250;
  default, pse, 0;
  default, multi_peaks, 0;
  default, msg, "Processing vegetation...";

  ops_conf_validate, ops_conf;
  define_veg_conf;

  if (is_void(rn) || is_void(len)) {
    if (!is_void(center) && !is_void(delta)) {
      rn = center - delta;
      len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
      rn = start - 1;
      len = stop - start + 1;
    } else {
      write, "Input parameters not correctly defined. See help, run_vegx. Please start again.";
      if(logger(warn))
        logger, warn, "Input parameters not correctly defined. See help, run_vegx. Please start again.";
      if(logger(debug)) logger, debug, log_id+"Aborting run_vegx";
      return 0;
    }
  }

  if (multi_peaks) {
    depths = array(VEGPIXS, 120, len);
  } else {
    depths = array(VEGPIX, 120, len );
    depths.mv0 = -10	// initialize result for non-existant pulses
    depths.nx = -1;	// temporary, will be removed later
  }

  if (msg != 0)
    status, start, msg=msg;
  if (graph) animate, 1;
  for (j = 1; j <= len; j++) {
    raw = get_erast(rn=rn+j);
    header = eaarl_decode_header(raw);
    if (!eaarl_header_valid(header)) continue;
    for (i = 1; i <= header.number_of_pulses; i++) {
      if (multi_peaks) {
        depths(i,j) = ex_veg_all(rn+j, i, last=last, graph=graph, header=header);
      } else {
        depths(i,j) = ex_veg(rn+j, i, last=last, graph=graph, 
        use_be_centroid=use_be_centroid, use_be_peak=use_be_peak,
        hard_surface=hard_surface, alg_mode=alg_mode,
        forcechannel=forcechannel, header=header);
      }
      if (pse) pause, pse;
    }
    if (msg != 0) status, progress, j, len;
  }
  if (graph) animate, 0;
  if (msg != 0) status, finished;
  if(logger(debug)) logger, debug, log_id+"Leaving run_vegx";
  return depths;
}

func make_fs_veg(d, rrr) {
/* DOCUMENT make_fs_veg (d, rrr)
 This function makes a veg data array using the georectification of the
 first surface return.  The parameters are as follows:

 d Array of structure VEGPIX  containing veg information.
      This is the return value of function run_vegx.

 rrr    Array of structure R containing first surface information.
      This the is the return value of function first_surface.

 The return value geoveg is an array of VEG_ALL_ structures.

  SEE ALSO: first_surface, run_vegx, make_fs_veg_all
  DEPRECATED: use make_fs_veg_all along with type conversion
    functions vegpix2vegpixs and cveg_all2veg_all_ instead.
*/

  if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else {
    len = numberof(rrr);}

  geoveg = array(VEG_ALL_, len);

  has_channel = has_member(geoveg, "channel") && has_member(rrr, "channel");

  for (i=1; i<=len; i=i+1) {
    if(has_channel)
      geoveg(i).channel = rrr(i).channel;
    geoveg(i).rn = rrr(i).rn;
    geoveg(i).north = rrr(i).north;
    geoveg(i).east = rrr(i).east;
    geoveg(i).elevation = rrr(i).elevation;
    geoveg(i).mnorth = rrr(i).mnorth;
    geoveg(i).meast = rrr(i).meast;
    geoveg(i).melevation = rrr(i).melevation;
    geoveg(i).soe = rrr(i).soe;
    geoveg(i).fint = rrr(i).intensity;
    // find actual ground surface elevation using simple trig (similar triangles)
    elvdiff = rrr(i).melevation - rrr(i).elevation;
    // check where the first surface algo assigned the first return elevation to the mirror elevation. The values may not exactly be the same because of the range bias -- we will check for where the melevation is within 10 m of the elevation
    edidx = where((abs(rrr(i).melevation - rrr(i).elevation) < 1000));
    ndiff = rrr(i).mnorth - rrr(i).north;
    ediff = rrr(i).meast - rrr(i).east;

    geo_raster = geoveg(i).rn(1) & 0xffffff;
    eindx = where(d(,i).mx1 > 0 & d(,i).mx0 > 0);
    if (is_array(eindx)) {
      eratio = float(d(,i).mx0(eindx))/float(d(,i).mx1(eindx));
      geoveg(i).lelv(eindx) = int(rrr(i).melevation(eindx) - eratio * elvdiff(eindx));
      geoveg(i).lnorth(eindx) = int(rrr(i).mnorth(eindx) - eratio * ndiff(eindx));
      geoveg(i).least(eindx) = int(rrr(i).meast(eindx) - eratio * ediff(eindx));
      // assign east,north values from rrr for those array elements within the raster that did not have a valid mx0 value;
      cf0idx = where(geoveg(i).lnorth == 0);
      /*
        geoveg(i).lnorth(cf0idx) = rrr(i).north(cf0idx);
        geoveg(i).least(cf0idx) = rrr(i).east(cf0idx);
        geoveg(i).lelv(cf0idx) = rrr(i).elevation(cf0idx);
      */
      geoveg(i).lnorth(cf0idx) = 0;
      geoveg(i).least(cf0idx) = 0;
      geoveg(i).lelv(cf0idx) = 0;
      geoveg(i).north(cf0idx) = 0;
      geoveg(i).east(cf0idx) = 0;
      geoveg(i).elevation(cf0idx) = 0;
    } else {
      geoveg(i).lnorth = geoveg(i).north;
      geoveg(i).least  = geoveg(i).east;
      // assign mirror elevation values to lelv to clearly indicate that the last elevation values are incorrect
      geoveg(i).lelv = rrr(i).melevation;
    }

    // now go back to the edidx which contains the elements that have first return elevations assigned to the mirror elevation
    if (is_array(edidx)) {
      geoveg(i).lnorth(edidx) = rrr(i).north(edidx);
      geoveg(i).least(edidx) = rrr(i).east(edidx);
      geoveg(i).lelv(edidx) = rrr(i).elevation(edidx);
    }

    geoveg(i).lint = d(,i).mv0;
    geoveg(i).nx = d(,i).nx;

  } /* end for loop */

  //write,format="Processing complete. %d rasters drawn. %s", len, "\n"
  return geoveg;
}

func make_veg(latutm=, q=, ext_bad_att=, use_centroid=, use_highelv_echo=,
multi_peaks=, alg_mode=, forcechannel=) {
/* DOCUMENT make_veg(latutm=, q=, ext_bad_att=, use_centroid=, use_highelv_echo=, multi_peaks=, alg_mode=, forcechannel=)
 This function allows a user to define a region on the gga plot of
 flightlines (usually window 6) to  process data using the vegetation
 algorithm.

Inputs are:

 ext_bad_att   Eliminate points within ext_bad_att meters of mirror.

Returns:
 veg_all       This function returns the array veg_all of type VEG_ALL_
  or CVEG_ALL depending on whether multi_peaks is set.

    SEE ALSO: first_surface, run_vegx, make_fs_veg_all
*/
  extern edb, soe_day_start, tans, pnav, n_all3sat;
  veg_all = [];
/************
  Currently, we are setting the following as defaults for last_surface determination algorithm:
  hard_surface = 1; all returns with only 1 inflection will be treated as first surface returns and will use the same fs algorithm using centroid to determine the range to the last surface.
  use_peak = 1; this is used for all waveforms with more than 1 inflection... the bare earth is determined by the peak of the trailing edge of the last inflection in the waveform.
*********/
  if (use_centroid == 1) {
    use_be_centroid = 0;
    use_be_peak = 1;
    hard_surface=1;
  } else {
    use_be_centroid = 0;
    use_be_peak = 0;
    hard_surface = 0;
  }

  if (use_be_peak) write, "Using peak of last return to find bare earth...";

  if (is_void(ops_conf))
    error, "ops_conf is not set";
  if (is_void(tans))
    error, "tans is not set";
  if (is_void(pnav))
    error, "pnav is not set";

  //select a region using function pnav_sel_rgn in rbgga.i
  if (is_void(q))
    q = pnav_sel_rgn(latutm=latutm, llarr=llarr);

  //find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q);

  if (is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  no_t = numberof(rn_arr(1,));

  // initialize counter variables
  tot_count = 0;
  ba_count = 0;
  bd_count = 0;
  n_all3sat = 0;

  for (i=1;i<=no_t;i++) {
    if ((rn_arr(1,i) != 0)) {
      msg = "Processing for first_surface...";
      write, msg;
      pause, 1; // make sure Yorick shows output
      status, start, msg=msg;
      rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i),
        usecentroid=use_centroid, use_highelv_echo=use_highelv_echo,
        ext_bad_att=ext_bad_att, forcechannel=forcechannel, msg=msg);
      msg = swrite(format="Processing segment %d of %d for vegetation", i, no_t);
      write, msg;
      pause, 1; // make sure Yorick shows output
      status, start, msg=msg;
      if (multi_peaks) {
        d = run_vegx(start=rn_arr(1,i), stop=rn_arr(2,i), multi_peaks=1, msg=msg);
        write, "Using make_fs_veg_all (multi_peaks=1) for vegetation...";
        veg = make_fs_veg_all(d, rrr);
      } else {
        d = run_vegx(start=rn_arr(1,i), stop=rn_arr(2,i),
          use_be_centroid=use_be_centroid, use_be_peak=use_be_peak,
          hard_surface=hard_surface, alg_mode=alg_mode,
          forcechannel=forcechannel, msg=msg);
        write, "Using make_fs_veg_all (multi_peaks=0) for vegetation...";
        dm = vegpix2vegpixs(d);
        cveg = make_fs_veg_all(dm, rrr, multi_peaks=0);
        veg = cveg_all2veg_all_(cveg, d, rrr);
      }
      grow, veg_all, veg;
      tot_count += numberof(veg.elevation);
      pause, 1; // make sure Yorick shows output
    }
  }

  write, "\nStatistics: \r";
  write, format="Total records processed = %d\n",tot_count;
  write, format="Total records with all 3 channels saturated = %d\n", n_all3sat;
  write, format="Total records with inconclusive first surface range = %d\n", ba_count;
  write, format="Total records with inconclusive last surface range = %d\n", bd_count;

  if (tot_count != 0) {
    pba = float(ba_count)*100.0/tot_count;
    write, format = "%5.2f%% of the total records had "+
      "inconclusive first return range\n",pba;
  } else
    write, "No good returns found";

  if (ba_count > 0) {
    if (tot_count != ba_count) {
      pbd = float(bd_count)*100.0/(tot_count-ba_count);
      write, format = "%5.2f%% of total records with good "+
        "first return had inconclusive last return range \n",pbd;
    }
  } else
    write, "No records processed for Topo under veg";

  status, finished;
  return veg_all;
}

func test_veg(veg_all,  fname=, pse=, graph=) {
  // this function can be used to process for vegetation for only those pulses that are in data array veg_all or  those that are in file fname.

  if (fname)
    veg_all = edf_import(fname);

  rasternos = veg_all.rn;

  rasters = rasternos & 0xffffff;
  pulses = rasternos >> 24;
  tot_count = 0;

  for (i = 1; i <= numberof(rasters); i++) {
    depth = ex_veg(rasters(i), pulses(i),last=250, graph=graph, use_be_peak=1, pse=pse);
    if (veg_all(i).rn == depth.rastpix) {
      if (depth.mx1 == -10) {
        veg_all(i).felv = -10;
        write, format="yo! rn=%d; i=%d\n",rasters(i), pulses(i);
      } else {
        veg_all(i).felv = depth.mx1*NS2MAIR*100;
      }
      veg_all(i).fint = depth.mv1;
      if (depth.mx0 == -10) {
        veg_all(i).lelv = -10;
        //write, format="lyo! rn=%d; i=%d\n",rasters(i), pulses(i);
      } else {
        veg_all(i).lelv = depth.mx0*NS2MAIR*100;
      }
      veg_all(i).lint = depth.mv0;
      veg_all(i).nx = depth.nx;
    } else {
      write, "ooooooooops!!!"
    }
  }
  return veg_all;
}

func ex_veg_all(rn, pulse_number, last=, graph=, pse=, thresh=, win=, verbose=,header=) {
/* DOCUMENT ex_veg_all(rn, pulse_number, last=, graph=, pse=, thresh=, win=, verbose=, header=)

 This function returns an array of VEGPIXS structures containing the
 elevation and timing of each surface intercepted by the pulse.

 Inputs:
   rn = Raster number
   pulse_number = pulse number
   graph = plot each waveform and the critical points.
   pse = time (in ms) to pause between each plot.
   header = decoded header of raster rn
   thresh = gradient threshold needed for a significant return (Default = 4)
   win =  window to plot waveforms in if graph = 1
   last = The last point in the waveform to consider.
   wf = The return waveform with the computed exponentials substracted
*/
  extern irg_a;
  default, win, 4;
  default, graph, 0;
  default, verbose, graph;
  default, thresh, 4.0;

  // check if global variable irg_a contains the current raster number (rn)
  if (is_void(irg_a) || !is_array(where(irg_a.raster(1,) == rn))) {
    irg_a = irg(rn,rn, usecentroid=1, msg=0);
  }
  this_irg = irg_a(where(rn==irg_a.raster));
  irange = this_irg.irange(pulse_number);

  // setup the return struct
  rv = VEGPIXS();
  rv.rastpix = rn + (pulse_number<<24);
  if (irange < 1) return rv;

  raw = get_erast(rn=rn);
  pulse = eaarl_decode_pulse(raw, pulse_number, header=header, wfs=1);

  rv.sa = pulse.shaft_angle;
  if (pulse.channel1_length == 0)
    return rv;

  ctx = cent(pulse.transmit_wf);
  if (ctx(1) == 0 || ctx(1) == 10000)
    return rv;

  wf = wf_filter_bias(short(~pulse.channel1_wf), method="first");
  dd = wf(dif);
  wflen = numberof(wf);

  /******************************************
    xr(1) will be the first pulse edge
    and xr(0) will be the last
  *******************************************/

  if (verbose)
    write, format="rn=%d; pulse_number = %d\n",rn, pulse_number;

  // this is the idx for start time for each 'layer'.
  xr = where(((dd >= thresh)(dif)) == 1);
  if (!is_array(xr))
    return rv;

  xr++;
  if (xr(1) < numberof(dd)) {
    pr = where(((dd(xr(1):) >= thresh)(dif)) == -1);
  } else {
    return rv;
  }

  // this is the idx for peak time for each 'layer'.
  if (!is_array(pr))
    return rv;

  pr += xr(1);
  if (numberof(pr) < numberof(xr))
    xr = xr(1:numberof(pr));


  // for the idx for the end of the 'layer' (stop time) we consider the following:
  // 1) first look for the next start point.  Mark the point before as the stop time.
  // 2) look for the time when the trailing edge crosses the threshold.

  if (numberof(xr) >= 2) {
    er = grow(xr(2:), wflen);
  } else {
    er = [wflen];
  }

  // see if user specified the max veg
  if(!is_void(last))
    wflen = min(wflen, last);

  rv.nx = nxr = numberof(xr);

  // maximum number of peaks is limited to 10
  nxr = min(nxr, 10);
  noise = 0;

  if (numberof(pr) != numberof(er))
    return rv;

  for (j = 1; j <= nxr; j++) {
    pta = wf(pr(j):er(j));
    idx = where(pta <= thresh);
    if (is_array(idx)) {
      er(j) = pr(j) + idx(1);
      if (pr(j) + idx(1) > wflen)
        er(j) -= 1;
    }

    if ((er(j) - xr(j)) < 4) {
      // the layer in the waveform is less than 4 ns and is therefore
      // not a significant layer.
      if (j != nxr && er(j) == xr(j+1)) {
        xr(j+1) = xr(j);
      }
      noise++;
      continue; // noise spike
    }

    // the peak position should be the max wf between xr and er
    pr(j) = xr(j) + wf(xr(j):er(j))(mxx) -1;

    if (((er(j) - pr(j)) < 2) || (wf(pr(j))-wf(er(j)) <= thresh)) {
      if (j != nxr && er(j) == xr(j+1)) {
        xr(j+1) = xr(j);
      }
      noise++;
      continue; // no real trailing edge
    }
    if (((pr(j) - xr(j)) < 2) || (wf(pr(j))-wf(xr(j)) <= thresh)) {
      if (j != 1 && xr(j) == er(j-1)) {
        er(j-1) = er(j);
        pta = wf(pr(j-1):er(j-1)-1);
        idx = where(pta <= thresh);
        if (is_array(idx))
          er(j-1) = pr(j-1)+idx(1);
        noise++;
        continue; // no real leading edge
      }
    }

    rv.mr(j) = xr(j)-1+wf(xr(j):er(j)-1)(mxx);
    rv.mx(j) = irange + rv.mr(j) - ctx(1);
    rv.mv(j) = wf(rv.mr(j));

    if (verbose)
      write, format= "xr = %d, pr = %d, er = %d\n",xr(j),pr(j),er(j);
  }

  if (graph)
    plot_veg_wf, wf, mx=rv.mr, mv=rv.mv, diff=1;
  if (pse) pause, pse;

  rv.nx = nxr - noise;
  return rv;
}

func make_fs_veg_all (d, rrr, multi_peaks=) {
/* DOCUMENT make_fs_veg_all (d, rrr, multi_peaks=)
  This function makes a veg data array using the georectification of the
  first surface return. The parameters are as follows:

  d    Array of structure VEGPIXS containing veg information.
       This is the return value of function run_vegx.

  rrr  Array of structure R containing first surface information.
       This the is the return value of function first_surface.

  multi_peaks Set to 1 for data with first 10 returs per pulse, set
           to 0 for data with only first and last returns. default=1. 

  The return value geoveg is an array of CVEG_ALL structures.

  SEE ALSO: first_surface, run_vegx
*/
  default, multi_peaks, 1;

  if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else {
    len = numberof(rrr);}

  geoveg = array(CVEG_ALL, 10,120,len);

  for (i=1; i<=len; i++) {
    elvdiff = rrr(i).melevation - rrr(i).elevation;
    ndiff = rrr(i).mnorth - rrr(i).north;
    ediff = rrr(i).meast - rrr(i).east;
    for (j=1; j<=120; j++) {
      geoveg.rn(,j,i) = rrr(i).rn(j);
      geoveg.mnorth(,j,i) = rrr(i).mnorth(j);
      geoveg.meast(,j,i) = rrr(i).meast(j);
      geoveg.melevation(,j,i) = rrr(i).melevation(j);
      geoveg.soe(,j,i) = rrr(i).soe(j);

      mindx = where(d(j,i).mx > 0);
      if (is_array(mindx)) {
	k=indgen(numberof(mindx));
	geoveg.nx(k,j,i) = char(k);
        // find actual ground surface elevation using simple trig (similar triangles)
        if ((d(j,i).mx(1) > 0) && (rrr(i).melevation(j) > 0)) {
	  eratio = float(d(j,i).mx(mindx))/float(d(j,i).mx(1));
          geoveg.elevation(k,j,i) = int(rrr(i).melevation(j) - eratio * elvdiff(j));
          geoveg.north(k,j,i) = int(rrr(i).mnorth(j) - eratio * ndiff(j));
          geoveg.east(k,j,i) = int(rrr(i).meast(j) - eratio * ediff(j));
          geoveg.intensity(k,j,i) = d(j,i).mv(mindx);
        }
      }
    }
  } /* end for loop */

  if (multi_peaks)
    geoveg = geoveg(where(geoveg.nx !=0));

  return geoveg;
}

func clean_cveg_all(vegall, rcf_width=) {
/* DOCUMENT clean_cveg_all(vegall)
  This function cleans the multi-peak veg data.
  Input: vegall:  data array (with structure CVEG_ALL)
  Output: cleaned data array (with structure CVEG_ALL)
*/
  new_vegall = vegall;

  indx = where(new_vegall.north != 0);

  if (is_array(indx))
    new_vegall = new_vegall(indx);

  indx = where(new_vegall.elevation < 0.75*new_vegall.melevation);
  if (is_array(indx))
    new_vegall = new_vegall(indx);

  indx = where(new_vegall.elevation > -100000); // assuming that no elevation will be lower than 1000m

  if (is_array(indx))
    new_vegall = new_vegall(indx);

  if (rcf_width) {
    ptr = rcf(new_vegall.elevation, rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
      new_vegall = new_vegall(*ptr(1));
    } else {
      new_vegall = 0;
    }
  }

  return new_vegall;
}

func ex_veg(rn, pulse_number, last=, graph=, win=, use_be_centroid=,
use_be_peak=, hard_surface=, alg_mode=, pse=, verbose=, add_peak=,
forcechannel=, header=) {
/* DOCUMENT rv = ex_veg(rn, pulse_number, last=, graph=, win=,
 use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=, pse=, verbose=,
 forcechannel=, header=)

  This function returns an instance of VEGPIX.

  Parameters:
    rn: Raster number
    pulse_number: Pulse number

  Options:
    last= Max veg
    graph= If enabled (graph=1), plots a graph showing results. (Default:
      graph=0, disabled)
    verbose= If enabled (verbose=1), displays some information to stdout.
      (Default: verbose=graph)
    win= Window number where graph will be plotted. (Default: win=4)
    use_be_centroid= Set to 1 to determine the range to the last surface
      using the "centroid" algorithm. This algorithm finds the centroid of
      the trailing edge of the last return in the waveform. The range
      determined using this method will be the "lowest". This method is rarely
      used and should be used with caution.
      (Default: use_be_centroid=0, disabled)
    use_be_peak= This is the "trailing edge" algorithm.
      Set to 1 to determine the range to the peak of the trailing
      edge of the last inflection. This algorithm is used by default and is
      the most optimal algorithm to use in a place of mixed "hard" and
      "soft" targets. "Soft" targets include bare earth under grass/herb.
      veg., marshlands, etc. This method is used most often (ALPS v1) along
      with hard_surface=1.
      (Default: use_be_peak=0, disabled)
    hard_surface= Set to 1 if the data are mostly coming from hard surfaces
      such as runways, roads, parking lots, etc. This algorithm will treat
      all waveforms with only 1 inflection as a "first surface" return, and
      will not apply any "trailing edge" algorithm to the data with only 1
      inflection.  For more than 1 inflection, the algorithm defined by
      use_be_peak (default) or use_be_centroid are used.
      Use this option with use_be_peak=1 for most optimal results (ALPS v1).
      (Default: hard_suface=0, disabled)
    alg_mode = This code is written to prepare for ALPS v2.
      it defines which algorithm mode to use.  This options works alongside
      the other options (use_be-centroid, use_be_peak, hard_surface), so that if any
      old code uses those options, they will still work.
      "cent" : use centroid algorithm, see func wf_centroid
      "peak" : use peak algorithm, see func xpeak
      "gauss": use gaussian decomposition algorithm, see func xgauss
    pse= Time (in milliseconds) to pause between each waveform plot.
*/
  extern veg_conf, ops_conf, n_all3sat;
  define_veg_conf;

  default, win, 4;
  default, graph, 0;
  default, verbose, graph;
  local retdist, idx1;

  if (rn == 0 && pulse_number == 0) {
    write, format="Are you clicking in window %d? No data was found.\n", win;
    return;
  }

  raw = get_erast(rn=rn);
  pulse = eaarl_decode_pulse(raw, pulse_number, header=header, wfs=1);
  raw = [];
  irange = pulse.raw_irange;

  // setup the return struct
  rv = VEGPIX();
  rv.rastpix = rn + (pulse_number<<24);
  rv.sa = pulse.shaft_angle;
  rv.mx0 = -1;
  rv.mv0 = -10;
  rv.mx1 = -1;
  rv.mv1 = -11;
  rv.nx = -1;
  if (irange < 0)
    return rv;

  // If transmit or return pulse is missing, return
  if (pulse.flag_irange_bit14 || pulse.flag_irange_bit15 ||
   pulse.transmit_length == 0 || pulse.channel1_length < 2) {
    return rv;
  }

 // This is the transmit pulse... use algorithm for transmit pulse based on algo used for return pulse.
   tx_wf = wf_filter_bias(short(~pulse.transmit_wf), method="first");

  if (alg_mode=="cent") {
    ctx = wf_centroid(tx_wf);
  } else if (alg_mode=="peak") {
    ctx = xpeak(tx_wf);
  } else if (alg_mode=="gauss") {
    ctx = xgauss(tx_wf);
  } else if (is_void(alg_mode)) {
    ctx = wf_centroid(tx_wf, lim=12);
  }
  tx_wf = [];

  // if out-of-range centroid, return
  if ((ctx(1) == 0)  || (ctx(1) == FLT_MAX))
    return rv;

  if(!is_void(forcechannel)) {
    channel = forcechannel;
    wf = pulse(swrite(format="channel%d_wf", channel));
    wf = wf_filter_bias(short(~wf), method="first");
  } else {
    // Try 1st channel
    channel = 1;
    np = min(pulse.channel1_length, 12);		// use no more than 12
    wf = wf_filter_bias(short(~pulse.channel1_wf), method="first");
    saturated = where(pulse.channel1_wf(1:np) < 5);  // Create a list of saturated samples
    numsat = numberof(saturated);     // Count how many are saturated

    if (numsat > veg_conf.max_sat(channel)) {
      // Try 2nd channel
      channel = 2;
      wf = wf_filter_bias(short(~pulse.channel2_wf), method="first");
      saturated = where(pulse.channel2_wf(1:np) < 5);
      numsat = numberof(saturated);

      if (numsat > veg_conf.max_sat(channel)) {
        // Try 3rd channel
        channel = 3;
        wf = wf_filter_bias(short(~pulse.channel3_wf), method="first");
        saturated = where(pulse.channel3_wf == 0);
        numsat = numberof(saturated);

        if (numsat > veg_conf.max_sat(channel)) {
          // All 3 channels saturated
          n_all3sat++;
          return rv;
        }
      }
    }
  }

  pulse = [];

  wflen = numberof(wf);
  dd = wf(dif);

  // xr(1) will be the first pulse edge and xr(0) will be the last
  xr = where((dd >= veg_conf.thresh)(dif) == 1);

  if (numberof(xr) == 0) {
    rv.mv0 = rv.mv1 = wf(max);
    rv.nx = 0;
    return rv;
  }

  // see if user specified the max veg
  if(!is_void(last))
    wflen = min(wflen, last);

  // Find the length of the section of the waveform that represents the last
  // return (starting from xr(0)). Assume 18ns to be the longest duration for
  // a complete bottom return.
  retdist = 18;

  // If 18 is too long, then cut it short based on the length of the waveform.
  retdist = min(retdist, wflen - xr(0) - 1);

  if (retdist < 5) { // this eliminates possible noise pulses.
    return rv;
  }
  if (pse) pause, pse;

  // set range_bias to that of the first unsaturated channel
  range_bias = get_member(ops_conf, swrite(format="chn%d_range_bias", channel));

  // stuff below is for mx1 (first surface in veg).
  local crx, mv1;
  wf_centroid, wf, crx, mv1, lim=12;
  if (use_be_centroid || use_be_peak || !is_void(alg_mode)) {
    // set mx1 to range walk corrected fs range
    mx1 = (crx == FLT_MAX) ? -10 : irange + crx - ctx(1) + range_bias;
    mv1 = (mv1 == FLT_MAX) ? -10 : mv1 + (channel-1) * 300;
  } else {
    // find surface peak now
    mx1 = wf(xr(1):xr(1)+5)(mxx) + xr(1) - 1;
    mv1 = wf(mx1);
  }

  // This is enabled when make_veg is called with use_centroid=1
  if (hard_surface) {
    // check to see if there is only 1 inflection
    if (numberof(xr) == 1) {
      //use first surface algorithm data to define range
      rv.mx0 = rv.mx1 = mx1;
      rv.mv0 = rv.mv1 = mv1;
      rv.nx = 1;
      return rv;
    }
  }

  // initialize return to discard pulse
  mx0 = mv0 = -10;

  // now process the trailing edge of the last inflection in the waveform
  if (!is_void(alg_mode)) {
    ex_veg_alg, mx0, mv0, wf, xr, irange, channel, wflen, retdist, alg_mode;
  } else if (!use_be_centroid && use_be_peak) {
    // This is used when make_veg is called with use_centroid=1 (which used
    // to be used by batch_process)
    ex_veg_noalg_peak, mx0, mv0, wf, xr, irange, channel, wflen, retdist;
  } else if(use_be_centroid && !use_be_peak) {
    ex_veg_noalg_cent, mx0, mv0, wf, xr, irange, channel, wflen, retdist;
  } else if(!use_be_centroid && !use_be_peak) {
    // This is used when make_veg is called with use_centroid=0
    ex_veg_noalg_none, mx0, mv0, wf, xr, irange;
  }

  rv.mx0 = mx0;
  rv.mv0 = mv0;
  rv.mx1 = mx1;
  rv.mv1 = mv1;
  rv.nx = numberof(xr);

  if (graph) {
    plot_veg_wf, wf, channel, (irange-ctx(1)), mx=[mx0,mx1], mv=[mv0,mv1];
  }
  if (verbose) {
    write, format="Range between first and last return %d = %4.2f ns\n", rv.rastpix, (rv.mx0-rv.mx1);
  }
  return rv;
}

// unused
func ex_veg_alg(&mx0, &mv0, wf, xr, irange, channel, wflen, retdist, alg_mode) {
  // find where the bottom return pulse changes direction after its trailing edge
  trailing_edge, wf, retdist, idx1;

  //now check to see if it it passes intensity test
  mxmint = wf(xr(0)+1:xr(0)+retdist)(max);
  if (abs(wf(xr(0)+1) - wf(xr(0)+retdist)) < 0.8*mxmint) {
    // This return is good to compute range. compute range
    // Create array wf_tail for retdist returns beyond the last
    // peak leading edge.
    wf_tail = wf(int(xr(0)+1):int(xr(0)+retdist));
    if ((min(wf_tail) > 240) && (max(wf_tail) < veg_conf.thresh)) {
      return rv;
    }
    if (wf_tail(sum) != 0) {
      if (alg_mode=="cent") {
        wf_tail_peak = wf_centroid(wf_tail);
      } else if (alg_mode=="peak") {
        wf_tail_peak = xpeak(wf_tail);
      } else if (alg_mode=="gauss") {
        wf_tail_peak = xgauss(wf_tail, add_peak=0);
      }
      if (wf_tail_peak(1) <= 0) return rv;
      if (int(xr(0)+wf_tail_peak(1)) <= wflen) {
        mx0 = irange + xr(0) - ctx(1) + range_bias + wf_tail_peak(1);
        mv0 = wf(int(xr(0)+wf_tail_peak(1))) + (channel-1)*300;
      }
    }
  }
}

// make_veg with use_centroid=1 (batch_process used this - is it still needed?)
func ex_veg_noalg_peak(&mx0, &mv0, wf, xr, irange, channel, wflen, retdist) {
  // this is the algorithm used most commonly in ALPS v1.
  // if within 3 ns from xr(0) we find a peak, we can assume this to be noise
  // related and try again using xr(0) from the first positive difference after
  // the last negative difference.
  nidx = where(dd(xr(0):xr(0)+3) < 0);
  if (is_array(nidx)) {
    xr(0) = xr(0) + nidx(1);
    if (xr(0)+retdist+1 > wflen) retdist = wflen - xr(0)-1;
  }
  // using trailing edge algorithm for bottom return
  trailing_edge, wf, retdist, idx1, xr=xr;

  if (is_array(idx1)) {
    mx0 = irange+xr(0)+idx1(1)-ctx(1)+range_bias;  // in ns
    mv0 = wf(int(xr(0)+idx1(1))) + (channel-1)*300;
  }
}

// unused
func ex_veg_noalg_cent(&mx0, &mv0, wf, xr, irange, channel, wflen, retdist) {
  // this is less used in ALPS v1
  // find where the bottom return pulse changes direction after its
  // trailing edge
  local idx1;
  trailing_edge, wf, retdist, idx1;

  //now check to see if it it passes intensity test
  mxmint = wf(xr(0)+1:xr(0)+retdist)(max);
  if (abs(wf(xr(0)+1) - wf(xr(0)+retdist)) < 0.2*mxmint) {
    // This return is good to compute centroid.
    // Create array wf_tail for retdist returns beyond the last peak leading edge.
    wf_tail = wf(int(xr(0)+1):int(xr(0)+retdist));

    // compute centroid
    if (wf_tail(sum) != 0) {
      wf_tail_peak = wf_centroid(wf_tail);
      if (wf_tail_peak <= 0) return rv;
      if (int(xr(0)+wf_tail_peak) <= wflen) {
        mx0 = irange + xr(0) + wf_tail_peak - ctx(1) + range_bias;
        mv0 = wf(int(xr(0)+wf_tail_peak)) + (channel-1)*300;
      }
    }
  }
}

// make_veg when use_centroid=0
func ex_veg_noalg_none(&mx0, &mv0, wf, xr, irange) {
  // no bare earth algorithm selected.
  //do not use centroid or trailing edge
  mvx = wf(xr(0):xr(0)+5)(mxx);
  // find bottom peak now
  mx0 = irange + mvx + xr(0) - 1;
  mv0 = wf(mvx);
}

func xcent(a) {
/* DOCUMENT cent(a)
  Compute the centroid of "a" of the inflection in the waveform.
*/
  n = numberof(a);	// determine number of points in waveform
  if ( n < 2 )
  return [ 0,0,0];
  r = 1:n;		// set the range we will consider
  mv = a (max);		// find the maximum value
  mx = a (mxx);		// find the index of the maximum
  s =  a(r)(sum);	// compute the sum of all the samples
  if ( s != 0.0 ) {
   c = float(  (a(r) * indgen(r)) (sum) ) / s;
  } else {
   //write,"********* xcent()  Reject: Sum was zero"
   return [0,0,0]
  }

//      centroid peak     average
//        range  range    power
  return [ c, mx, mv ];
}

func xpeak(a) {
/* DOCUMENT xpeak(a)
  Compute the peak of "a" of the inflection in the waveform.
*/
  n = numberof(a);	// determine number of points in waveform
  if ( n < 2 )
  return [ 0,0,0];
  r = 1:n;		// set the range we will consider
  mv = a (max);		// find the maximum value
  mx = a (mxx);		// find the index of the maximum

  return [mx,mx,mv];
}

func xgauss(w1, add_peak=, graph=, xaxis=,logmode=) {
/* DOCUMENT xgauss
  Computer the gaussian decomposition of the waveform
  w1 = waveform to use
  add_peak = set to number of peaks to add for the gaussian fitting
  logmode = do log transformation of waveform (on y-axis) before computing gaussian decomposition
*/
  n = numberof(w1);      // determine number of points in waveform
  if ( n < 8 )
      return [ 0,0,0];
  //r = 1:n;              // set the range we will consider
  mv = w1(max);         // find the maximum value
  mx = w1(mxx);         // find the index of the maximum

  x=indgen(numberof(w1));
  n_peaks = 1;
  a = array(float, n_peaks*3);

  a(1) = mx
  a(2)= 1.0
  a(3)= mv

  a_init = a;

  //if (mv <= veg_conf.thresh) return [0,0,0];
  if (is_array(where(w1 < 0))) return [0,0,0];

  w1_0 = where(w1==0);
  n0 = numberof(w1_0);
  n_non0 = n-n0;
  if (n0 > n_non0) return [0,0,0];

  if (logmode) {
  // ensure that all values are non-zero
  if (is_array(w1_0)) w1(w1_0) += 0.000000001 // need to fix later
  lw1 = log(w1);
  a(1) = lw1(mxx);
  a(2) = 1.0;
  a(3) = lw1(max);
  a_init = a;
  }

  r = lmfit(lmfitfun,x,a,w1,1.0,itmax=200);
  if (catch(-1)) return;
  chi2_0 = r.chi2_last;

  if (abs(a_init(1)-a(1)) > 10)
  return [0,0,0];
  a_noaddpeak = [];
  a_noaddpeak = a;
  if (is_void(add_peak)) add_peak=0;
  if (add_peak) {
   new_peaks=lclxtrem(w1, thresh=3);
   if (is_array(new_peaks)) {
    new_fit = array(float, 2, numberof(new_peaks))
    for (j=1; j<=numberof(new_peaks); j++) {
  a1=grow(a,new_peaks(j),1,w1(new_peaks(j)))
  r1 = lmfit(lmfitfun,x,a1,w1,1.0, itmax=200);
  if ((r1.niter == 200) && (verbose))
    write, format="%f failed to converge\n", a1(-2);
  if (abs(a1(-2)-a1(1)) > 10) {
    a1=a;
    continue;
  }
  new_fit(j*2-1:j*2) = [a1(-2), r1.chi2_last]
  if (a1(0) < 0) new_fit(j*2) = chi2_0+1		// eliminate -ve peaks
  }
    if (verbose) print,new_fit

    p_count=1
    idx=array(1,numberof(new_peaks))
    while (p_count <= add_peak) {
  if (!is_void(lims)) {
    if (add_peak != (dimsof(lims)(3))) {
        write, "Not the correct # of limits. Exiting..";
        return;
      }
  idx=((new_fit(1,) >= lims(1,p_count)) * (new_fit(1,) <= lims(2,p_count)))
  }

  if (noneof(idx)) min_chi2 = chi2_0+1
  else min_chi2 = min(new_fit(2,where(idx)));
  min_chi2_idx = where(new_fit(2,) == min_chi2)

  if (min_chi2 < chi2_0) {
    new_fit(2,min_chi2_idx) = chi2_0+1
    min_chi2_idx=min_chi2_idx(1)
    a=grow(a,new_peaks(min_chi2_idx),1,w1(new_peaks(min_chi2_idx)))
    n_peaks = n_peaks+1
  }
  else print, "No useful peaks found within limits";

  r1 = lmfit(lmfitfun,x,a,w1,1.0, itmax=200);
  if ((r1.niter == 200) && (verbose))
  write, format="%f failed to converge\n", a(-2);

  p_count++
  if (verbose) print, chi2_0, r1.chi2_last
   }
  }
  }
  if (abs(a_noaddpeak(1)-a(1)) > 10)
  a = a_noaddpeak;
  yfit =  lmfitfun(x,a);

  if (graph)
      {
    winbkp = current_window();
    window, win;
        for (j=1; j<=numberof(a)/3; j++)
           plg, gauss3(x,[a(j*3-2),a(j*3-1),a(j*3)]),xaxis, color="blue"
        plg, yfit,xaxis, color="magenta"
    window_select, winbkp;
      }

  fwhm = sqrt(8*log(2)) * a(2::3)
  ret = array(float, 4, numberof(fwhm))
  a = reform(a, [2,3,numberof(a)/3])
  ret(1:3,) = a(1:3,)
  ret(4,) = fwhm
  if (numberof(a) > 3) a = a(,sort(a(1,)))

  return [ret(1,1), ret(3,1)];
}

func trailing_edge(wf, &retdist, &idx1, xr=) {
/* DOCUMENT trailing_edge(wf, retdist, idx, xr=)
  Find where the bottom return pulse changes direction after its
  trailing edge.

  Input:
    wf = input waveform
    retdist = length of the section of the wf that represents the 
      last return (starting from xr(0).
    idx1 = array of points from xr(0) with negative gradients.
    xr = array of pulse edges. The function calculates xr unless it
      is modified to search further along the tail, in which case
      it should be supplied as a parameter.

  SEE ALSO: ex_veg
*/
  dd = wf(dif);
  if (is_void(xr))
    xr = where((dd >= veg_conf.thresh)(dif) == 1);

  idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
  idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
  if (is_array(idx1) && is_array(idx)) {
    if (idx(0) > idx1(1)) {
      // take length of return at this point
      retdist = idx(0);
    }
  }
  return retdist;
}

func vegpix2vegpixs (d) {
/* DOCUMENT vegpix2vegpixs(d)
   Transforms data in a VEGPIX structure which only stores first and 
     last returns to VEGPIXS structure which stores up to 10 returns.

   Input:
    d = array of structure VEGPIX.
      This is the return value of func ex_veg.
    rrr = array of structure R containing first surface information.
      This is the return value of func first_surface.

   SEE ALSO: VEGPIX, VEGPIXS, first_survace, ex_veg
*/
  dm = array(VEGPIXS, dimsof(d));

  dm.rastpix = d.rastpix;
  dm.sa = d.sa;
  dm.nx = d.nx;
  dm.mx(1,) = d.mx1;
  dm.mx(2,) = d.mx0;
  dm.mv(1,) = d.mv1;
  dm.mv(2,) = d.mv0;

  return dm;
}

func cveg_all2veg_all_ (cveg, d, rrr) {
/*DOCUMENT cveg_all2veg_all_ (cveg, d, rrr)
  Transforms data in a CVEG_ALL structure to a VEG_ALL_ structure.

  Input:
    cveg = array of structure CVEG_ALL.
      This is the return value of func make_fs_veg_all.
    d = array of structure VEGPIX.
      This is the return value of func ex_veg.
    rrr = array of structure R containing first surface information.
      This is the return value of func first_surface.

  SEE ALSO: CVEG_ALL, VEGPIX, R, VEG_ALL_, first_surface, ex_veg, make_fs_veg_all
*/
  len = numberof(rrr);
  geoveg = array(VEG_ALL_, len);
  np = dimsof(geoveg.rn)(2);		// number of pulses

  geoveg.rn = rrr.rn;
  geoveg.north = rrr.north;
  geoveg.east = rrr.east;
  geoveg.elevation = rrr.elevation;
  geoveg.mnorth = rrr.mnorth;
  geoveg.meast = rrr.meast;
  geoveg.melevation = rrr.melevation;
  geoveg.soe = rrr.soe;
  geoveg.fint = d.mv1;
  geoveg.lint = d.mv0;
  geoveg.nx = d.nx;
  geoveg.lnorth = cveg(2,,).north;
  geoveg.least = cveg(2,,).east;
  geoveg.lelv = cveg(2,,).elevation;

// Assign 0 to east, north, elev for those array elements within the 
// raster that did not have valid mx0/1 values
  tzero = array(1,np,len);
  tzero(where(d.mx0 <= 0 | d.mx1 <= 0)) = 0;
  geoveg.north *= tzero;
  geoveg.east *= tzero;
  geoveg.elevation *= tzero;

/* Check where the first surface algo assigned the first return elevation
   to the mirror elevation. The values may not be exactly the same becuase
   of the range bias - we will check for where the melevation is within 
   10m of the elevation.
*/
  edidx = where((abs(rrr.melevation - rrr.elevation) < 1000));
  tzero(*,) = 1;
  tzero(edidx) = 0;
  geoveg.lnorth = geoveg.lnorth*tzero + rrr.north*(!tzero);
  geoveg.least = geoveg.least*tzero + rrr.east*(!tzero);
  geoveg.lelv = geoveg.lelv*tzero + rrr.elevation*(!tzero);

  return geoveg;
}

func plot_veg_wf(wf, channel, mx00, mx=, mv=, diff=) {
/* DOCUMENT: plot_veg_wf(wf, channel, mx00, mx=, mv=, diff=)
  Plots the waveform supplied in wf.

  Input:
    wf = the intensity waveform to be plotted.
    channel = which channel it came from.
    mx00 = starting (adjusted) range. If 0 or ommitted, x-axis = 1,2,3..
    mx = x-coordinates of points to plot on the graph.
    mv = y-coordinates of points to plot on the graph.
    diff = flag indicating gradient of graph should be plotted.
           Default = 0 (do not plot gradient).
*/
  default, channel, 1;
  default, mx00, 0;
  default, diff, 0;
  default, win, 4;

  winbkp = current_window();
  window, win;
  fma;
  xaxis = span(mx00, mx00+numberof(wf)-1, numberof(wf));
  limits, xaxis(1), xaxis(0), 0, 250;

  if (diff) {		// plot gradients
    dd = wf(dif)-100;
    range, min(dd), 250;
    plg, dd, xaxis(2:), color="red";
  } 

  plmk, wf, xaxis, msize=.2, marker=1, color="black";
  plg, wf, xaxis, color="black";
  if (!is_void(mx)) {
    if (channel == 2 || channel == 3)
      mv -= (channel-1)*300;
    plmk, mv, mx, msize=.4, marker=7, color="red", width=10;
  }
  pltitle, swrite(format="Channel ID = %d", channel);
  window_select, winbkp;
}
