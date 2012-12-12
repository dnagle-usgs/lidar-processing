// vim: set ts=2 sts=2 sw=2 ai sr et:
/*
   For processing bathymetry data using the topographic georectification.
*/

func make_fs_bath(d, rrr, avg_surf=, sample_interval=, verbose=) {
/* DOCUMENT make_fs_bath (d, rrr, avg_surf=, sample_interval=, verbose=)

  This function makes a depth or bathymetric image using the georectification
  of the first surface return. The parameters are as follows:

    d: Array of structure BATHPIX containing depth information. This is the
      return value of function run_bath.

    rrr: Array of structure R containing first surface information. This the is
      the return value of function first_surface.

    avg_surf= Set to 1 if the surface returns should be averaged to the first
      surface returns at the center of the swath.

   The return value depth is an array of structure GEOALL.

   SEE ALSO: first_surface, run_bath
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering make_fs_bath";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  d="+pr1(d);
    logger, debug, log_id+"  info(d)="+info(d)(sum);
    logger, debug, log_id+"  rrr="+pr1(rrr);
    logger, debug, log_id+"  info(rrr)="+info(rrr)(sum);
    logger, debug, log_id+"  avg_surf="+pr1(avg_surf);
    logger, debug, log_id+"  sample_interval="+pr1(sample_interval);
  }

  // d is the depth array from bathy.i
  // rrr is the topo array from surface_topo.i
  default, avg_surf, 0;
  default, verbose, 1;

  if(dimsof(d)(3) < numberof(rrr))
    rrr = rrr(:dimsof(d)(3));
  if(numberof(rrr) < dimsof(d)(3))
    d = d(,:numberof(rrr));

  len = numberof(rrr);
  geodepth = array(GEOALL, len);

  offset = array(double, 120);

  local raster, pulse;
  parse_rn, rrr.rn, raster, pulse;

  surface_window = 100;
  altitude_thresh = 5000;
  pulse_window = 25;

  if(logger(debug)) logger, debug, log_id+"Total rasters to process: "+pr1(len);
  for (i=1; i<=len; i++) {
    if(logger(trace)) logger, trace, log_id+"Raster #"+pr1(i)+": "+pr1(raster(1,i));
    offset(*) = 0.;
    // code added by AN (12/03/04) to make all surface returns across a raster
    // to be the average of the fresnel reflections.  the surface return is
    // determined from the reflections that have the first channel saturated
    // and come from close to the center of the swath.
    if(avg_surf) {
      if(logger(trace)) logger, trace, log_id+"  avg_surf enabled";
      iidx = where((rrr(i).intensity > 220) & (abs(60 - pulse(,i)) < pulse_window));
      if(!is_array(iidx)) {
        if(logger(trace)) logger, trace, log_id+"  -- no fresnel";
        if(verbose)
          write, format= "No water surface Fresnel reflection in raster rn = %d\n", raster(1,i);
      } else {
        elvs = median(rrr(i).elevation(iidx));
        if(logger(trace)) logger, trace, log_id+"  -- elvs="+pr1(elvs);
        elvsidx = where(abs(rrr(i).elevation(iidx)-elvs) <= surface_window);
        elvs = avg(rrr(i).elevation(iidx(elvsidx)));
        if(logger(trace)) logger, trace, log_id+"  -- elvs="+pr1(elvs);
        old_elvs = rrr(i).elevation;
        indx = where(rrr(i).melevation - rrr(i).elevation > altitude_thresh);
        if(logger(trace)) logger, trace, log_id+"  -- indx="+pr1(indx);
        if (is_array(indx)) rrr(i).elevation(indx) = int(elvs);
        // now rrr.fs_rtn_centroid will change depending on where in time the
        // surface occurs for each laser pulse with respect to where its
        // current surface elevation is. this change is defined by the array
        // offset
        offset = ((old_elvs - elvs)/(CNSH2O2X*sample_interval*100.));
      }
    }
    if(logger(trace)) logger, trace, log_id+"  d(,i).idx="+pr1(d(,i).idx);
    if(logger(trace)) logger, trace, log_id+"  info(d(,i).idx)="+info(d(,i).idx)(sum);
    if(logger(trace)) logger, trace, log_id+"  offset="+pr1(offset);
    if(logger(trace)) logger, trace, log_id+"  info(offset)="+info(offset)(sum);
    indx = where((d(,i).idx > 0) & (abs(offset) < 100));
    if(logger(trace)) logger, trace, log_id+"  indx="+pr1(indx);
    if (is_array(indx)) {
      fs_rtn_cent = rrr(i).fs_rtn_centroid(indx)+offset(indx);
      // NOTE: This depth value will be ignored and clobbered by compute_depth
      // if it is used.
      geodepth(i).depth(indx) = int((-d(,i).idx(indx) + fs_rtn_cent) * CNSH2O2X *100.-0.5);
      geodepth(i).sr2(indx) =int((d(,i).idx(indx) - fs_rtn_cent)*10);
    }
  }

  if(logger(debug)) logger, debug, log_id+"Storing remaining results to geodepth";
  if(has_member(rrr, "channel") && has_member(geodepth, "channel"))
    geodepth.channel = rrr.channel;

  geodepth.rn = rrr.rn;
  geodepth.north = rrr.north;
  geodepth.east = rrr.east;
  geodepth.elevation = rrr.elevation;
  geodepth.mnorth = rrr.mnorth;
  geodepth.meast = rrr.meast;
  geodepth.melevation = rrr.melevation;
  geodepth.soe = rrr.soe;
  geodepth.bottom_peak = d.bottom_peak;
  geodepth.first_peak = d.first_peak;

  if(logger(debug)) logger, debug, log_id+"Leaving make_fs_bath";
  return geodepth;
}

func compute_depth(data, sample_interval=) {
/* DOCUMENT compute_depth(data, sample_interval=)
  This function computes the depth in water using the mirror position and the
  angle of refraction in water. The input parameters defined are as follows:

  data= Data array of structure GEOALL.

  This function returns the data array with computed depth.

  SEE ALSO: make_fs_bath, make_bathy
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering compute_depth";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  data="+pr1(data);
    logger, debug, log_id+"  info(data)="+info(data)(sum);
    logger, debug, log_id+"  sample_interval="+pr1(sample_interval);
  }

  // Force copy so that original isn't modified in place.
  data = noop(data);

  dist = data.sr2/10. * NS2MAIR * sample_interval;

  ref = [data.meast/100., data.mnorth/100., data.melevation/100.];
  fs = [data.east/100., data.north/100., data.elevation/100.];

  dims = dimsof(ref);
  ref = reform(ref, [2, numberof(ref)/3, 3]);
  fs = reform(fs, [2, numberof(fs)/3, 3]);
  dist = dist(*);

  ba = array(double, dimsof(fs));

  notequal =
    (fs(..,1) != ref(..,1)) &
    (fs(..,2) != ref(..,2)) &
    (fs(..,3) != ref(..,3));

  w = where((fs(..,3) <= ref(..,3)) & notequal);
  if(numberof(w)) {
    if(logger(debug)) logger, debug, log_id+"Projecting points";
    be = point_project(ref(w,), fs(w,), dist(w), tp=1);
    ba(w,) = snell_be_to_bathy(fs(w,), be);
    be = [];
  }
  w = where((fs(..,3) > ref(..,3)) & notequal);
  if(numberof(w)) {
    if(logger(debug)) logger, debug, log_id+"Projecting points with FS above mirror";
    be = point_project(ref(w,), fs(w,), -dist(w), tp=1);
    ba(w,) = snell_be_to_bathy(fs(w,), be);
    be = [];
  }
  w = where(!notequal);
  if(numberof(w)) {
    if(logger(debug)) logger, debug, log_id+"Handling points with FS at mirror";
    ba(w,) = fs(w,);
  }

  fs = reform(fs, dims);
  ba = reform(ba, dims);

  data.east = ba(..,1)*100;
  data.north = ba(..,2)*100;
  data.depth = (ba(..,3) - fs(..,3))*100;

  if(logger(debug)) logger, debug, log_id+"Leaving compute_depth";
  return data;
}

func make_bathy(latutm=, q=, avg_surf=, ext_bad_att=, forcechannel=, verbose=) {
/* DOCUMENT make_bathy(latutm=, q=, avg_surf=, forcechannel=, verbose=)
  This function allows a user to define a region on the gga plot of flightlines
  (usually window 6) to write out a 'level 1' file and plot a depth image
  defined in that region.

    latutm= Passed to pnav_sel_rgn, if q is void.
    q= Indices into extern pnav where data should be processed.
    avg_surf= Set to 1 if the surface returns should be averaged to the first
      surface returns at the center of the swath.

  Returns an array depth_all of GEOALL.

  Please ensure that the tans and pnav data have been loaded before executing
  make_bathy. See rbpnav() and rbtans() for details. The structure BATH_CTL
  must be initialized as well. See define_bath_ctl().

  SEE ALSO: first_surface, run_bath, make_fs_bath, rbpnav, rbtans,
    define_bath_ctl
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering make_bathy";
    logger, debug, log_id+"Flight loaded: "+mission.data.loaded;
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  latutm="+pr1(latum);
    logger, debug, log_id+"  q="+pr1(q);
    logger, debug, log_id+"  info(q)="+info(q)(sum);
    logger, debug, log_id+"  ext_bad_att="+pr1(ext_bad_att);
    logger, debug, log_id+"  avg_surf="+pr1(avg_surf);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
  }
  if(logger(trace)) {
    logger, trace, log_id+"  Full contents of q:";
    logger, trace, log_id+"    "+print(q);
    logger, trace, log_id+"ops_conf="+print(ops_conf)(sum);
    logger, trace, log_id+"bath_ctl="+print(bath_ctl)(sum);
    logger, trace, log_id+"bath_ctl_chn4="+print(bath_ctl_chn4)(sum);
  }

  default, verbose, 1;

  extern tans, pnav;
  depth_all = [];
  sample_interval = 1.0;

  if(is_void(tans)) {
    if(logger(debug)) logger, debug, log_id+"Aborting make_bathy (no tans)";
    error, "TANS/INS data not loaded";
  }
  if(is_void(pnav)) {
    if(logger(debug)) logger, debug, log_id+"Aborting make_bathy (no pnav)";
    error, "PNAV data not loaded";
  }

  if (!is_array(q)) {
    q = pnav_sel_rgn(region=llarr);
  }

  // find start and stop raster numbers for all flightlines
  status, start, msg="Scanning flightlines for rasters...";
  raster_ranges = sel_region(q);

  if(is_void(raster_ranges)) {
    write, "No Data in selected flightline. Good Bye!";
    status, finished;
    if(logger(debug)) logger, debug, log_id+"Aborting make_bathy (no selection)";
    return [];
  }
  raster_starts = raster_ranges(1,);
  raster_stops = raster_ranges(2,);
  raster_ranges = [];

  count = numberof(raster_starts);

  if(logger(debug)) logger, debug, log_id+"Total lines: "+pr1(count);
  for(i = 1; i <= count; i++) {
    if(logger(debug)) logger, debug, log_id+"Processing line "+pr1(i);
    if((raster_starts(i) != 0)) {
      msg_prefix = swrite(format="Line %d/%d; ", i, count);
      msg = msg_prefix + "Step 1/3: Processing bathymetry...";
      write, format="Processing segment %d of %d for bathymetry\n", i, count;
      pause, 1; // make sure Yorick shows output
      status, start, msg=msg;
      depth = run_bath(start=raster_starts(i), stop=raster_stops(i),
        forcechannel=forcechannel, msg=msg, verbose=verbose);
      if(depth == 0) {
        status, finished;
        if(logger(debug)) logger, debug, log_id+"Aborting make_bathy (run_bath failed)";
        return 0;
      }

      msg = msg_prefix + "Step 2/3: Processing surface...";
      if(verbose) {
        write, "Processing for first_surface...";
        pause, 1; // make sure Yorick shows output
      }
      status, start, msg=msg;
      surface = first_surface(start=raster_starts(i), stop=raster_stops(i),
        usecentroid=1, ext_bad_att=ext_bad_att, forcechannel=forcechannel,
        msg=msg, verbose=verbose);

      msg = msg_prefix + "Step 3/3: Merging and correcting depths...";
      status, start, msg=msg;
      if(verbose) {
        write, "Using make_fs_bath for submerged topography...";
        pause, 1; // make sure Yorick shows output
      }
      depth = make_fs_bath(depth, surface, avg_surf=avg_surf, verbose=verbose,
        sample_interval=sample_interval);

      // make depth correction using compute_depth
      if(verbose) {
        write, "Correcting water depths for Snells law...";
        pause, 1; // make sure Yorick shows output
      }
      grow, depth_all, compute_depth(depth, sample_interval=sample_interval);
    }
  }
  status, finished;

  write, "\nStatistics:";
  write, format="Total number of records processed = %d\n",
      numberof(depth_all.elevation);

  if(logger(debug)) logger, debug, log_id+"Leaving make_bathy";
  return depth_all;
}
