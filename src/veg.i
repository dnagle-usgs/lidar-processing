// vim: set ts=2 sts=2 sw=2 ai sr et:

require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "eaarl_constants.i"
require, "colorbar.i"

struct VEG_CONF {    // Veg configuration parameters
  float thresh;     // threshold
  int max_sat(3);   // Maximum number of sat dig pixels before switching
};

struct VEGPIX {
  int rastpix;   // raster + pulse << 24
  short sa;      // scan angle
  float mx1;     // first pulse index
  short mv1;     // first pulse peak value
  float mx0;     // last pulse index
  short mv0;     // last pulse peak value
  char nx;       // number of return pulses found
};

struct VEGPIXS {
  int rastpix;   // raster + pulse << 24
  short sa;      // scan angle
  float mx(10);  // range in ns of all return peaks from irange
  short mr(10);  // range in ns of all return peaks from irange
  short mv(10);  // intensities of all return peaks (max 10)
  char nx;       // number of return pulses found
};

func define_veg_conf {
/* DOCUMENT define_veg_conf;
  If extern veg_conf is not already initialized, this will define it.
*/
  extern veg_conf, ops_conf;
  if(is_void(veg_conf)) {
    veg_conf = VEG_CONF(thresh=4.0);
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
  pix = rn / 2^24;
  rn &= 0xffffff;
  r = get_erast(rn=rn);
  rp = decode_raster(r);
  window, 1;
  fma;
  aa = ndrast(rp, units=_depth_display_units);
  pix;
  rn;
}

func run_vegx(rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=, 
  use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=, multi_peaks=, msg=) {
/* DOCUMENT depths = run_vegx(rn=, len=, start=, stop=, center=, delta=, last=, graph=,
     pse=, use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=, multi_peaks=, msg=)

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
    header = eaarla_decode_header(raw);
    for (i = 1; i <= header.number_of_pulses; i++) {
      if (multi_peaks) {
        depths(i,j) = ex_veg_all(rn+j, i, last=last, graph=graph, 
        use_be_centroid=use_be_centroid, use_be_peak=use_be_peak, header=header);
      } else {
        depths(i,j) = ex_veg(rn+j, i, last=last, graph=graph, 
        use_be_centroid=use_be_centroid, use_be_peak=use_be_peak,
        hard_surface=hard_surface, alg_mode=alg_mode, header=header);
      }
      if (pse) pause, pse;
    }
    if (msg != 0) status, progress, j, len;
  }
  if (graph) animate, 0;
  if (msg != 0) status, finished;
  return depths;
}

func run_veg(rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=,
use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=) {
/* DOCUMENT depths = run_veg(rn=, len=, start=, stop=, center=, delta=, last=, 
     graph=, pse=, use_be_centroid=, use_be_peak=, hard_surface=, alg_mode=)

  Original function run_veg converted to a wrapper for run_vegx.
    All parameters are being passed through to run_vegx.
    (see help, run_vegx for details).

  SEE ALSO: run_vegx, run_veg_all, make_veg, ex_veg
*/

  d = run_vegx(rn=rn, len=len, start=start, stop=stop, center=center, delta=delta, 
    last=last, graph=graph, pse=pse, use_be_centroid=use_be_centroid, 
    use_be_peak=use_be_peak, hard_surface=hard_surface, alg_mode=alg_mode);

  return d;
}


func make_fs_veg(d, rrr) {
/* DOCUMENT make_fs_veg (d, rrr)

 This function makes a veg data array using the
 georectification of the first surface return.  The parameters are as
 follows:

 d Array of structure VEGPIX  containing veg information.
      This is the return value of function run_bath.

 rrr    Array of structure R containing first surface information.
      This the is the return value of function first_surface.


 The return value veg is an array of structure VEGALL.

  SEE ALSO: first_surface, run_veg
*/

  // d is the veg array from veg.i
  // rrr is the topo array from surface_topo.i

  if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else {
    len = numberof(rrr);}

  geoveg = array(VEG_ALL_, len);

  for (i=1; i<=len; i=i+1) {
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

func make_veg(latutm=, q=, ext_bad_att=, ext_bad_veg=, use_centroid=, use_highelv_echo=, multi_peaks=, alg_mode=) {
/* DOCUMENT make_veg(opath=,ofname=,ext_bad_att=, ext_bad_veg=)

 This function allows a user to define a region on the gga plot
of flightlines (usually window 6) to  process data using the
Vegetation algorithm.

Inputs are:

 ext_bad_att   Extract bad first return points (those points that
           were termed 'bad' in the first surface return function)
           and writes it out to an array.

 ext_bad_veg    Extract the points that failed to show any veg using
           the run_veg function and write these points to an array

Returns:
 veg_arr        This function returns the array veg_arr.

**Note:
 Check to see if the tans and pnav data have been loaded before
 executing make_veg.  See rbpnav() and rbtans() for details.

    SEE ALSO: first_surface, run_veg, make_fs_veg
*/
  extern edb, soe_day_start, tans, pnav, utm, rn_arr, rn_arr_idx, ba_veg, bd_veg, n_all3sat;
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
  }

  if (use_be_peak) write, "Using peak of last return to find bare earth...";

  /* check to see if required parameters have been initialized */

  if (!is_array(tans)) {
    write, "TANS information not loaded.  Running function rbtans() ... \n";
    tans = rbtans();
    write, "\n";
  }
  write, "TANS information LOADED. \n";
  if (!is_array(pnav)) {
    write, "Precision Navigation (PNAV) data not loaded."+
      "Running function rbpnav() ... \n";
    pnav = rbpnav();
  }
  write, "PNAV information LOADED. \n";
  write, "\n";

  if (!is_array(q)) {
    /* select a region using function gga_win_sel in rbgga.i */
    q = gga_win_sel(latutm=latutm, llarr=llarr);
  }

  /* find start and stop raster numbers for all flightlines */
  rn_arr = sel_region(q);


  if (is_array(rn_arr)) {
    no_t = numberof(rn_arr(1,));

    /* initialize counter variables */
    tot_count = 0;
    ba_count = 0;
    bd_count = 0;
    n_all3sat = 0;

    for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
        msg = "Processing for first_surface...";
        write, msg;
        status, start, msg=msg;
        rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=use_centroid, use_highelv_echo=use_highelv_echo, msg=msg);
        msg = swrite(format="Processing segment %d of %d for vegetation", i, no_t);
        write, msg;
        status, start, msg=msg;
        if (!multi_peaks) {
          d = run_vegx(start=rn_arr(1,i), stop=rn_arr(2,i),use_be_centroid=use_be_centroid, 
            use_be_peak=use_be_peak, hard_surface=hard_surface, alg_mode=alg_mode,msg=msg);
          write, "Using make_fs_veg_all (multi_peaks=0) for vegetation...";
	  dm = vegpix2vegpixs(d);
	  cveg = make_fs_veg_all(dm, rrr, multi_peaks=0);
	  veg = cveg_all2veg_all_(cveg, d, rrr);
          grow, veg_all, veg;
          tot_count += numberof(veg.elevation);
        } else {
          d = run_vegx(start=rn_arr(1,i), stop=rn_arr(2,i),use_be_centroid=use_be_centroid, 
            use_be_peak=use_be_peak,last=255,multi_peaks=1,msg=msg);
          write, "Using make_fs_veg_all (multi_peaks=1) for vegetation...";
          veg = make_fs_veg_all(d, rrr);
          grow, veg_all, veg;
          tot_count += numberof(veg.elevation);
        }
      }
    }

    // if ext_bad_att is set, eliminate all points within 20m of mirror
    if ((ext_bad_att==1) && (is_array(veg_all))) {
      msg = "Extracting and writing false first points";
      write, msg;
      status, start, msg=msg;
      // compare veg.elevation within 20m of veg.melevation
      elv_thresh = (veg_all.melevation-2000);
      ba_indx = where(veg_all.elevation > elv_thresh);
      ba_count += numberof(ba_indx);
      ba_veg = veg_all;
      deast = veg_all.east;
      dleast = veg_all.least;
      if ((is_array(ba_indx))) {
        deast(ba_indx) = 0;
        dleast(ba_indx) = 0;
      }
      dnorth = veg_all.north;
      dlnorth = veg_all.lnorth;
      if ((is_array(ba_indx))) {
        dnorth(ba_indx) = 0;
        dlnorth(ba_indx) = 0;
      }
      veg_all.east = deast;
      veg_all.north = dnorth;
      veg_all.least = dleast;
      veg_all.lnorth = dlnorth;

      /* compute array for bad attitude (ba_veg) to write to a file */
      ba_indx_r = where(ba_veg.elevation < elv_thresh);
      bdeast = ba_veg.east;
      if ((is_array(ba_indx_r))) {
        bdeast(ba_indx_r) = 0;
      }
      bdnorth = ba_veg.north;
      if ((is_array(ba_indx_r))) {
        bdnorth(ba_indx_r) = 0;
      }
      ba_veg.east = bdeast;
      ba_veg.north = bdnorth;
      status, finished;
    }

    /* if ext_bad_veg is set, find all points having veg = 0 */
    if ((ext_bad_veg==1) && (is_array(veg_all)))  {
      msg = "Extracting false last surface returns ";
      write, msg;
      status, start, msg=msg;
      /* compare veg_all.lelv with 0 */
      bd_indx = where((veg_all.lelv == 0));
      bd_count += numberof(bd_indx);
      bd_veg = veg_all;
      deast = veg_all.east;
      deast(bd_indx) = 0;
      dnorth = veg_all.north;
      dnorth(bd_indx) = 0;
      bd_indx = where(veg_all.lelv == veg_all.melevation);
      bd_count += numberof(bd_indx);

      /* compute array for bad veg (bd_veg) */
      bd_indx_r = where(bd_veg.lelv != 0);
      if (is_array(bd_indx_r)) {
        bdeast = bd_veg.east;
        bdeast(bd_indx_r) = 0;
        bdnorth = bd_veg.north;
        bdnorth(bd_indx_r) = 0;
        bd_veg.east = bdeast;
        bd_veg.north = bdnorth;
      }
      status, finished;
    }
    write, "\nStatistics: \r";
    write, format="Total records processed = %d\n",tot_count;
    write, format = "Total records with all 3 channels saturated = %d\n", n_all3sat;
    write, format="Total records with inconclusive first surface range = %d\n", ba_count;
    write, format = "Total records with inconclusive last surface range = %d\n",
      bd_count;

    if ( tot_count != 0 ) {
      pba = float(ba_count)*100.0/tot_count;
      write, format = "%5.2f%% of the total records had "+
        "inconclusive first return range\n",pba;
    } else
      write, "No good returns found";

    if ( ba_count > 0 ) {
      diff_count = (tot_count-ba_count);
      if (diff_count) {
        pbd = float(bd_count)*100.0/diff_count;
        write, format = "%5.2f%% of total records with good "+
          "first return had inconclusive last return range \n",pbd;
      }
    } else
      write, "No records processed for Topo under veg";
    no_append = 0;
    if (numberof(rn_arr)>2) {
      rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);
    }
    status, finished;
    return veg_all;
  } else write, "No record numbers found for selected flightline.";
}

func test_veg(veg_all,  fname=, pse=, graph=) {
  // this function can be used to process for vegetation for only those pulses that are in data array veg_all or  those that are in file fname.
  // amar nayegandhi 11/27/02.

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

func ex_veg_all(rn, i, last=, graph=, use_be_centroid=, use_be_peak=, pse=, thresh=, win=, verbose=,header=) {
/* DOCUMENT ex_veg_all(rn, i,  last=, graph=, use_be_centroid=, use_be_peak=, pse=, header= ) {

 This function returns an array of VEGPIXS structures.

  [ rp.sa(i), mx, a(mx,i,1) ];

*/

/*
 Check waveform samples to see how many samples are
 saturated.
 The function checks the following conditions so far:
  1) Saturated surface return - locates last saturated sample
  2) Non-saturated surface with saturated bottom signal
  3) Non saturated surface with non-saturated bottom
  4) Bottom signal above specified threshold
 We'll used this infomation to develope the threshold
 array for this waveform.
 We come out of this with the last_surface_sat set to the last
 saturated value of surface return.
 The 12 represents the last place a surface can be found
 Variables:
   last       The last point in the waveform to consider.
   nsat       A list of saturated pixels in this waveform
   numsat     Number of saturated pixels in this waveform
   last_surface_sat  The last pixel saturated in the surface region of the
               Waveform.
   da         The return waveform with the computed exponentials substracted
*/
  extern irg_a, _errno, pr;
  default, win, 4;
  default, graph, 0;
  default, verbose, graph;
  default, thresh, 4.0;
  aa = array(float, 256, 120, 4);

  // check if global variable irg_a contains the current raster number (rn)
  if (is_void(irg_a) || !is_array(where(irg_a.raster == rn))) {
    irg_a = irg(rn,rn, usecentroid=1);
  }
  this_irg = irg_a(where(rn==irg_a.raster));
  irange = this_irg.irange(i);
  intensity = this_irg.intensity(i);
  //irange=0;
  //intensity = a(where(rn==a.raster)).intensity(i);

  raw = get_erast(rn=rn);
  if (is_void(header)) {
    pulse = eaarla_decode_pulse(raw, i, wfs=1);
  } else {
    pulse = eaarla_decode_pulse(raw, i, header=header, wfs=1);
  }

  // setup the return struct
  rv = VEGPIXS();
  rv.rastpix = rn + (i<<24);
  if (irange < 1) return rv;
  rv.sa = pulse.shaft_angle;

  ctx = cent(pulse.transmit_wf);

  n = pulse.channel1_length;
  if (n == 0)
    return rv;

  w = pulse.channel1_wf;
  aa(1:n,i) = float((~w+1) - (~w(1)+1));

  if (!(use_be_centroid) && !(use_be_peak)) {
    nsat = where(w == 0);               // Create a list of saturated samples
    numsat = numberof(nsat);            // Count how many are saturated
    // allowing 3 saturated samples per inflection
    if ((numsat > 3) && (nsat(1) <= 12)) {
      if (nsat(dif)(max) == 1) {       // only surface saturated
        last_surface_sat = nsat(0);   // so use last one
        escale = 255;
      } else {                         // bottom must be saturated too
        // allowing 3 saturated samples per inflection
        last_surface_sat = nsat(where(nsat(dif) > 3))(1);
        escale = 255;
      }
    } else {                            // surface not saturated
      wflen = numberof(w);
      if (wflen > 12) wflen = 12;
      last_surface_sat = w(1:wflen)(mnx);
      escale = 255 - w(1:wflen)(min);
    }

  }

  da = aa(1:n,i,1);
  dd = da(dif);

  /******************************************
    xr(1) will be the first pulse edge
    and xr(0) will be the last
  *******************************************/

  if (graph) {
    winbkp = current_window();
    window, win;
    fma;
    plmk, aa(1:n,i,1), msize=.2, marker=1, color="black";
    plg, aa(1:n,i,1);
    plmk, da, msize=.2, marker=1, color="black";
    plg, da;
    plg, dd-100, color="red";
    window_select, winbkp;
  }
  if (verbose)
    write, format="rn=%d; i = %d\n",rn,i;

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
  if (is_array(pr))
    pr += xr(1);

  if (numberof(pr) < numberof(xr))
    xr = xr(1:numberof(pr));


  // for the idx for the end of the 'layer' (stop time) we consider the following:
  // 1) first look for the next start point.  Mark the point before as the stop time.
  // 2) look for the time when the trailing edge crosses the threshold.

  if (numberof(xr) >= 2) {
    er = grow(xr(2:),n);
  } else {
    er = [n];
  }

  nxr = numberof(xr);

  // see if user specified the max veg
  if(!is_void(last))
    n = min(n, last);

  rv.nx = nxr;
  //maximum number of peaks is limited to 10
  nxr = min(nxr, 10);
  noise = 0;

  if (numberof(pr) == 0)
    return rv;
  if (numberof(pr) != numberof(er))
    return rv;

  for (j = 1; j <= nxr; j++) {
    pta = da(pr(j):er(j));
    idx = where(pta <= thresh);
    if (is_array(idx)) {
      if (pr(j) + idx(1) <= n) {
        er(j) = pr(j) + idx(1);
      } else {
        er(j) = pr(j) + idx(1) - 1;
      }
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

    // the peak position should be the max da between xr and er
    pr(j) = xr(j) + da(xr(j):er(j))(mxx) -1;

    if (((er(j) - pr(j)) < 2) || (da(pr(j))-da(er(j)) <= thresh)) {
      if (j != nxr && er(j) == xr(j+1)) {
        xr(j+1) = xr(j);
      }
      noise++;
      continue; // no real trailing edge
    }
    if (((pr(j) - xr(j)) < 2) || (da(pr(j))-da(xr(j)) <= thresh)) {
      if (j != 1 && xr(j) == er(j-1)) {
        er(j-1) = er(j);
        pta = da(pr(j-1):er(j-1)-1);
        idx = where(pta <= thresh);
        if (is_array(idx))
          er(j-1) = pr(j-1)+idx(1);
        noise++;
        continue; // no real leading edge
      }
    }
    ai = 1; //channel number

    rv.mx(j) = irange-1+xr(j)+da(xr(j):er(j)-1)(mxx)-ctx(1);
    rv.mr(j) = xr(j)-1+da(xr(j):er(j)-1)(mxx);
    rv.mv(j) = aa(int(xr(j)-1+da(xr(j):er(j)-1)(mxx)),i,ai);

    if (graph) {
      winbkp = current_window();
      window, win;
      plmk, rv.mv(j), xr(j)-1+da(xr(j):er(j)-1)(mxx), msize=.5, marker=7, color="blue", width=1;
      window_select, winbkp;
    }
    if (verbose)
      write, format= "xr = %d, pr = %d, er = %d\n",xr(j),pr(j),er(j);
    if (pse) pause, pse;
  }

  nxr = nxr - noise;
  rv.nx = nxr;

  return rv;
}

func run_veg_all( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=, use_be_centroid=,use_be_peak=) {
/* DOCUMENT depths = run_veg_all( rn=, len=, start=, stop=, center=, delta=, 
     last=, graph=, pse=, use_be_centroid=, use_be_peak=) {

  Original function run_veg_all converted to a wrapper for run_vegx.
    All parameters are being passed through to run_vegx, along with 
    multi_peaks, which determines whether only first and last peaks are 
    returned or the first 10.
    (see help, run_vegx for details).

  SEE ALSO: run_vegx, run_veg, make_veg, ex_veg_all
*/
  default, last, 255;

  d = run_vegx(rn=rn, len=len, start=start, stop=stop, center=center, 
    delta=delta, last=last, graph=graph, pse=pse, multi_peaks=1, 
    use_be_centroid=use_be_centroid, use_be_peak=use_be_peak);

  return d;
}

func make_fs_veg_all (d, rrr, multi_peaks=) {
/* DOCUMENT make_fs_veg_all (d, rrr, multi_peaks=)

  This function makes a veg data array using the
  georectification of the first surface return.  The parameters are as
  follows:

 d    Array of structure VEGPIX  containing veg information.
           This is the return value of function run_bath.

 rrr  Array of structure R containing first surface information.
           This the is the return value of function first_surface.

 multi_peaks Set to 1 for data with first 10 returs per pulse, set 
           to 0 for data with only first and last returns. default=1. 

  The return value veg is an array of structure VEG_ALL_.

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

  //write,format="Processing complete. %d rasters drawn. %s", len, "\n"
  return geoveg;
}

func clean_cveg_all(vegall, rcf_width=) {
/* DOCUMENT clean_cveg_all(vegall)
  This function cleans the multi-peak veg data.
  Input: vegall:  data array (with structure CVEG_ALL)
  Output: cleaned data array (with structure CVEG_ALL)
  Original Author: amar nayegandhi 02/12/03.
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


func ex_veg(rn, pulse_number, last=, graph=, win=, use_be_centroid=, use_be_peak=, 
  hard_surface=, alg_mode=, pse=, verbose=, add_peak=, header=) {
/* DOCUMENT rv = ex_veg(rn, pulse_number, last=, graph=, win=, use_be_centroid=,
  use_be_peak=, hard_surface=, alg_mode=, pse=, verbose=, header=)

  This function returns an array of VEGPIX structures.

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
      "cent" : use centroid algorithm, see func xcent
      "peak" : use peak algorithm, see func xpeak
      "gauss": use gaussian decomposition algorithm, see func xgauss
    pse= Time (in milliseconds) to pause between each waveform plot.
*/
  extern veg_conf, ops_conf, n_all3sat, irg_a, _errno;
  define_veg_conf;

  default, win, 4;
  default, graph, 0;
  default, verbose, graph;
  local retdist, idx1;

  _errno = 0; // If not specifically set, preset to assume no errors.

  if (rn == 0 && pulse_number == 0) {
    write, format="Are you clicking in window %d? No data was found.\n", win;
    _errno = -1;
    return;
  }

  // check if global variable irg_a contains the current raster number (rn)
  if (is_void(irg_a) || !is_array(where(irg_a.raster == rn))) {
    irg_a = irg(rn, rn, usecentroid=1, msg=0);
  }
  this_irg = irg_a(where(rn == irg_a.raster));
  irange = this_irg.irange(pulse_number);

  raw = get_erast(rn=rn);
  if (is_void(header)) {
    pulse = eaarla_decode_pulse(raw, pulse_number, wfs=1);
  } else {
    pulse = eaarla_decode_pulse(raw, pulse_number, header=header, wfs=1);
  }

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
  if (pulse.transmit_length == 0 || pulse.channel1_length < 2) {
    _errno = -1;
    return rv;
  }

 // This is the transmit pulse... use algorithm for transmit pulse based on algo used for return pulse.
   tx_wf = -short(pulse.transmit_wf);	// flip it over and convert to signed short
   tx_wf -= tx_wf(1);			// remove bias using first point of wf

  if (alg_mode=="cent") {
    ctx = xcent(tx_wf);
  } else if (alg_mode=="peak") {
    ctx = xpeak(tx_wf);
  } else if (alg_mode=="gauss") {
    ctx = xgauss(tx_wf);
  } else if (is_void(alg_mode)) {
    ctx = cent(pulse.transmit_wf);
  }

  // if transmit pulse does not exist, return
  if ((ctx(1) == 0)  || (ctx(1) == 1e1000)) {
    return rv;
  }

  // Try 1st channel
  channel = 1;
  raw_wf = pulse.channel1_wf;
  wf = float(~raw_wf) - ~raw_wf(1);
  saturated = where(raw_wf < 5);    // Create a list of saturated samples
  numsat = numberof(saturated);     // Count how many are saturated

  if (numsat > veg_conf.max_sat(channel)) {
    // Try 2nd channel
    channel = 2;
    raw_wf = pulse.channel2_wf;
    wf = float(~raw_wf) - ~raw_wf(1);
    saturated = where(raw_wf == 0);
    numsat = numberof(saturated);

    if (numsat > veg_conf.max_sat(channel)) {
      // Try 3rd channel
      channel = 3;
      raw_wf = pulse.channel3_wf;
      wf = float(~raw_wf) - ~raw_wf(1);
      saturated = where(raw_wf == 0);
      numsat = numberof(saturated);

      if (numsat > veg_conf.max_sat(channel)) {
        // All 3 channels saturated
        n_all3sat++;
        return rv;
      }
    }
  }

  wflen = numberof(wf);
  dd = wf(dif);

  // xr(1) will be the first pulse edge and xr(0) will be the last
  xr = where((dd >= veg_conf.thresh)(dif) == 1);

  if (numberof(xr) == 0) {
    rv.mv0 = rv.mv1 = wf(max);
    rv.nx = 0;
    _errno = 0;
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
    _errno = 0;
    return rv;
  }
  if (pse) pause, pse;

  // set range_bias to that of the first unsaturated channel
  if (channel == 1)
    range_bias = ops_conf.chn1_range_bias;
  else if (channel == 2)
    range_bias = ops_conf.chn2_range_bias;
  else if (channel == 3)
    range_bias = ops_conf.chn3_range_bias;

  // stuff below is for mx1 (first surface in veg).
  if (use_be_centroid || use_be_peak || !is_void(alg_mode)) {
    np = min(pulse.channel1_length, 12); // use no more than 12
    if (numberof(where((pulse.channel1_wf(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
      crx = cent(pulse.channel1_wf);
      crx(1) += ops_conf.chn1_range_bias;
    } else if (numberof(where((pulse.channel2_wf(1:np)) < 5)) <= ops_conf.max_sfc_sat) {
      crx = cent(pulse.channel2_wf);
      crx(1) += ops_conf.chn2_range_bias;
      crx(3) += 300;
    } else {
      crx = cent(pulse.channel3_wf);
      crx(1) += ops_conf.chn3_range_bias;
      crx(3) += 600;
    }
    mx1 = (crx(1) >= 10000) ? -10 : irange + crx(1) - ctx(1);
    mv1 = crx(3);
  } else {
    // find surface peak now; note wf is reset to channel 1.
    raw_wf = pulse.channel1_wf;
    wf = float(~raw_wf) - ~raw_wf(1);
    mx1 = wf(xr(1):xr(1)+5)(mxx) + xr(1) - 1;
    mv1 = wf(mx1);
  }

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
          wf_tail_peak = xcent(wf_tail);
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
  else if (!use_be_centroid && use_be_peak && is_void(alg_mode)) {
    // this is the algorithm used most commonly in ALPS v1.
    // if within 3 ns from xr(0) we find a peak, we can assume this to be noise related and try again using xr(0) from the first positive difference after the last negative difference.
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
  else if (use_be_centroid && !use_be_peak && is_void(alg_mode)) {
    // this is less used in ALPS v1
    // find where the bottom return pulse changes direction after its
    // trailing edge
    trailing_edge, wf, retdist, idx1;

    //now check to see if it it passes intensity test
    mxmint = wf(xr(0)+1:xr(0)+retdist)(max);
    if (abs(wf(xr(0)+1) - wf(xr(0)+retdist)) < 0.2*mxmint) {
      // This return is good to compute centroid.
      // Create array wf_tail for retdist returns beyond the last peak leading edge.
      wf_tail = wf(int(xr(0)+1):int(xr(0)+retdist));

      // compute centroid
      if (wf_tail(sum) != 0) {
        wf_tail_peak = xcent(wf_tail)(1);
        if (wf_tail_peak <= 0) return rv;
        if (int(xr(0)+wf_tail_peak) <= wflen) {
          mx0 = irange + xr(0) + wf_tail_peak - ctx(1) + range_bias;
          mv0 = wf(int(xr(0)+wf_tail_peak)) + (channel-1)*300;
        }
      }
    }
  } 
  else if (!use_be_centroid && !use_be_peak && is_void(alg_mode)) {
    // no bare earth algorithm selected.
    //do not use centroid or trailing edge
    mvx = wf(xr(0):xr(0)+5)(mxx);
    // find bottom peak now
    mx0 = irange+wf(xr(0):xr(0)+5)(mxx) + xr(0) - 1;
    mv0 = wf(mvx);
  }

  rv.mx0 = mx0;
  rv.mv0 = mv0;
  rv.mx1 = mx1;
  rv.mv1 = mv1;
  rv.nx = numberof(xr);
  _errno = 0;

  if (graph) {
    cval = [mx0, mv0, mx1, mv1];
    plot_veg_wf, channel, wf, (irange-ctx(1)), cval;
  }
  if (verbose) {
    write, format="Range between first and last return %d = %4.2f ns\n", rv.rastpix, (rv.mx0-rv.mx1);
  }
  return rv;
}


func xcent( a ) {
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


func xpeak( a ) {
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
  dm.mx(1,)=d.mx1
  dm.mx(2,)=d.mx0
  dm.mv(1,)=d.mv1
  dm.mv(2,)=d.mv0

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
  geoveg.fint = rrr.intensity;
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

func plot_veg_wf(channel, wf, mx00, cval) {
  default, channel, 1;
  default, win, 4;
  winbkp = current_window();
  window, win;
  fma;
  xaxis = span(mx00+1,mx00+numberof(wf), numberof(wf));
  limits, xaxis(1), xaxis(0), 0, 250;
  // cval contains [mx0, mv0, mx1, mv1]
  if (channel == 2 || channel == 3) {
    cval(2) -= (channel-1)*300;
    cval(4) -= (channel-1)*300;
  }
  plmk, wf, xaxis, msize=.2, marker=1, color="black";
  plg, wf, xaxis, color="black";
  plmk, cval(4), cval(3), msize=.5, marker=4, color="blue", width=10;
  plmk, cval(2), cval(1), msize=.5, marker=7, color="red", width=10;
  pltitle, swrite(format="Channel ID = %d", channel);
  window_select, winbkp;
}
