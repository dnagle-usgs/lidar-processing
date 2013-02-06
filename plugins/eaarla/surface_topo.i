// vim: set ts=2 sts=2 sw=2 ai sr et:

func first_surface(nil, start=, stop=, center=, delta=, usecentroid=,
use_highelv_echo=, forcechannel=, verbose=, msg=, ext_bad_att=) {
/* DOCUMENT first_surface(start=, stop=, center=, delta=, usecentroid=,
   use_highelv_echo=, forcechannel=, verbose=, ext_bad_att=)

  Project the EAARL threshold trigger point to the surface.

  Inputs:
    start= Raster number to start with.
    stop= Ending raster number.
    center= Center raster when doing before and after.
    delta= Number of rasters to process before and after.
    usecentroid= Set to 1 to use the centroid of the waveform.
    use_highelv_echo= Set to 1 to exclude waveforms that tripped above the
        range gate.
    verbose= By default, progress/info output is enabled (verbose=1). Set
        verbose=0 to silence it.
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are excluded by setting their north and east values to 0.

  This returns an array of type "R" which will contain the xyz of the mirror
  "track point" and the xyz of the "first surface threshold trigger point" or
  "fsttp." The "fsttp" is derived here by using the "irange" (integer range)
  value from the raw data. While the fsttp is certainly not the best range
  measurement, it does establish highly accurate vector information which will
  greatly simplify additional subaerial waveform processing.

    0 = center, delta
    1 = start,  stop
    2 = start,  delta
*/
  log_id = logger_id();
  if(logger(debug)) {
    logger, debug, log_id+"Entering first_surface";
    logger, debug, log_id+"Parameters:";
    logger, debug, log_id+"  start="+pr1(start);
    logger, debug, log_id+"  stop="+pr1(stop);
    logger, debug, log_id+"  center="+pr1(center);
    logger, debug, log_id+"  delta="+pr1(delta);
    logger, debug, log_id+"  usecentroid="+pr1(usecentroid);
    logger, debug, log_id+"  use_highelv_echo="+pr1(use_highelv_echo);
    logger, debug, log_id+"  forcechannel="+pr1(forcechannel);
    logger, debug, log_id+"  verbose="+pr1(verbose);
    logger, debug, log_id+"  msg="+pr1(msg);
    logger, debug, log_id+"  ext_bad_att="+pr1(ext_bad_att);
  }
  default, verbose, 1;
  sample_interval = 1.0;

  if(is_void(ops_conf))
    error, "ops_conf is not set";

  i = j = [];
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

  // This is to prevent overrunning available memory
  maxcount = 25000;
  if(stop - start >= maxcount) {
    if(logger(debug))
      logger, debug, log_id+"More than "+pr1(maxcount)+" rasters, recursing";
    count = stop - start + 1;
    intervals = long(ceil(count/double(maxcount)));
    parts = array(pointer, intervals);
    for(i = start, interval = 1; interval <= intervals; i+=maxcount, interval++) {
      i = min(stop, i);
      j = min(stop, i + maxcount - 1);
      parts(interval) = &first_surface(start=i, stop=j,
        usecentroid=usecentroid, use_highelv_echo=use_highelv_echo,
        forcechannel=forcechannel, ext_bad_att=ext_bad_att, verbose=verbose,
        msg=msg);
    }
    if(logger(debug)) logger, debug, log_id+"Leaving first_surface";
    return merge_pointers(parts);
  }
  extern rtrs;
  if(verbose)
    write, "\n Retrieving irange values...";
  rtrs = irg(start, stop, usecentroid=usecentroid, use_highelv_echo=use_highelv_echo, forcechannel=forcechannel, msg=msg);
  if (msg)
    status, start, msg=msg;
  irg_a = rtrs;

  atime = rtrs.soe - soe_day_start;

  if(verbose)
    write, "Projecting trajectory to UTM...";
  local gps_north, gps_east;
  if(has_member(ops_conf, "use_ins_for_gps") && ops_conf.use_ins_for_gps) {
    use_ins_for_gps = 1;
  } else {
    use_ins_for_gps = 0;
  }

  // Store tans in ins, reduced down to just the range we need
  bounds = digitize([atime(*)(min), atime(*)(max)], tans.somd);
  bound1 = max(bounds(1) - 1, 1);
  bound0 = bounds(0);
  ins = tans(bound1:bound0);
  bound0 = bound1 = bounds = [];

  if(use_ins_for_gps) {
    if(logger(debug)) logger, debug, log_id+"Using INS for GPS";
    gps = ins;
    gps_sod = gps.somd;
    gps_alt = gps.alt;
  } else {
    if(logger(debug)) logger, debug, log_id+"Using GPS for GPS";
    gps = pnav;
    gps_sod = gps.sod;
    gps_alt = gps.alt;
  }
  if(logger(debug)) logger, debug, log_id+"Projecting trajectory to UTM";
  ll2utm, gps.lat, gps.lon, gps_north, gps_east;

  if(logger(debug)) logger, debug, log_id+"Interpolating";
  if(verbose)
    write, format="%s", " Interpolating: roll...";
  roll = interp(ins.roll, ins.somd, atime);

  if(verbose)
    write, format="%s", " pitch...";
  pitch = interp(ins.pitch, ins.somd, atime);

  if(verbose)
    write, format="%s", " heading...";
  heading = interp_angles(ins.heading, ins.somd, atime);

  if(verbose)
    write, format="%s", " altitude...";
  palt = interp(gps_alt, gps_sod, atime);
  gps_alt = [];

  if(verbose)
    write, format="%s", " northing/easting...\n";
  northing = interp(gps_north, gps_sod, atime);
  easting = interp(gps_east, gps_sod, atime);
  gps_sod = gps_north = gps_east = [];

  count = stop - start + 1;

  // mirror offsets
  dx = ops_conf.x_offset; // perpendicular to fuselage
  dy = ops_conf.y_offset; // along fuselage
  dz = ops_conf.z_offset; // vertical

  // Constants for mirror angle and laser angle
  mirang = -22.5;
  lasang = 45.0 - .4;
  cyaw = 0.;

  if(verbose) write, "Projecting to the surface...";
  if(logger(debug)) logger, debug, log_id+"Projecting to the surface";

  // Check to see if scan angles must be fixed. If not, use ops_conf bias.
  scan_bias = array(ops_conf.scan_bias, count);
  fix = [];
  if(is_array(fix_sa1) && is_array(fix_sa2)) {
    if(logger(debug)) logger, debug, log_id+"Using scan angle fixes";
    write, "Using scan angle fixes...";

    if(rtrs.sa(1,1) > rtrs.sa(118,1))
      fix=fix_sa1(start:stop);
    else
      fix=fix_sa2(start:stop);

    for(i = 1; i <= count; i++)
      scan_bias(i) = rtrs.sa(1,i) - fix(i);
  }

  // Calculate scan angles
  scan_angles = SAD * (rtrs.sa + scan_bias(-,));
  scan_bias = [];

  // Calculate magnitude of vectors from mirror to ground
  mag = rtrs.irange * NS2MAIR * sample_interval - ops_conf.range_biasM;

  // Edit out tx/rx dropouts and points with out-of-range centroid values
  w = where(rtrs.dropout != 0 | rtrs.fs_rtn_centroid == 10000);
  if(!is_void(w))
    mag(w) = 0;

  pitch += ops_conf.pitch_bias;
  roll += ops_conf.roll_bias;
  yaw = -heading + ops_conf.yaw_bias;

  // Calculate angles for channel spacing if applicable
  // Temporarily including verbosity level 2 to show channel spacing angles
  if(forcechannel && has_member(ops_conf, "delta_ht")) {
    if(verbose > 1)
      write, format=" Calculating channel spacing for channel %d...\n", forcechannel;
    if(logger(debug)) logger, debug, log_id+"Calculating channel spacing for channel "+pr1(forcechannel);
    chandx = get_member(ops_conf, swrite(format="chn%d_dx", forcechannel));
    chandy = get_member(ops_conf, swrite(format="chn%d_dy", forcechannel));
    chandz = ops_conf.delta_ht;
    if(chandx && chandz) {
      chantx = atan(chandx, chandz) * RAD2DEG;
      if(verbose > 1)
        write, format="   x theta: %.4f\n", chantx;
      scan_angles -= chantx;
      if(logger(debug)) logger, debug, log_id+"Adjusting scan angles for channel by "+pr1(chantx);
    }
    if(chandy && chandz) {
      chanty = atan(chandy, chandz) * RAD2DEG;
      if(verbose > 1)
        write, format="   y theta: %.4f\n", chanty;
      lasang -= chanty;
      if(logger(debug)) logger, debug, log_id+"Adjusting laser angles for channel by "+pr1(chantx);
    }
  }

  local mx, my, mz, px, py, pz;
  eaarl_direct_vector,
    yaw, pitch, roll,
    easting, northing, palt,
    dx, dy, dz,
    cyaw,
    lasang,
    mirang, scan_angles, mag,
    mx, my, mz, px, py, pz;

  if(ext_bad_att) {
    bad = where(mz - pz < ext_bad_att);
    if(numberof(bad)) {
      px(bad) = py(bad) = 0;
    }
  }

  if(logger(debug)) logger, debug, log_id+"Populating R structure";
  surface = array(R, count);
  surface.meast  =     mx * 100.0;
  surface.mnorth =     my * 100.0;
  surface.melevation=  mz * 100.0;
  surface.east   =     px * 100.0;
  surface.north  =     py * 100.0;
  surface.elevation =  pz * 100.0;
  surface.rn = (rtrs.raster&0xffffff);
  surface.intensity = rtrs.intensity;
  surface.fs_rtn_centroid = rtrs.fs_rtn_centroid;
  surface.rn += (indgen(120)*2^24)(,-);
  surface.soe = rtrs.soe;
  if(forcechannel)
    surface.channel = forcechannel;

  if(count >= 100 && (verbose || logger(debug))) {
    sample = swrite(format="%5d %8.1f %6.2f %6.2f %6.2f\n",
      indgen(100:count:100),
      rtrs.soe(60,100:count:100)%86400,
      palt(60,100:count:100),
      roll(60,100:count:100),
      pitch(60,100:count:100));
    if(verbose) write, format="%s", sample;
    if(logger(debug)) logger, debug, (log_id+sample)(sum);
  }

  if(verbose)
    pause, 1; // make sure Yorick shows output

  if(msg)
    status, finished;
  if(logger(debug)) logger, debug, log_id+"Leaving first_surface";
  return surface;
}

func open_seg_process_status_bar {
  if(_ytk) {
    tkcmd, "destroy .seg; toplevel .seg; set progress 0"
    tkcmd, "wm title .seg \"Flight Segment Progress Bar\"";
    tkcmd, "ProgressBar .seg.pb -fg cyan -troughcolor blue -relief raised \
        -maximum 100 -variable progress -height 30 -width 400"
    tkcmd, "pack .seg.pb; update";
    tkcmd, "center_win .seg";
  }
}

func make_fs(latutm=, q=, ext_bad_att=, usecentroid=, forcechannel=, verbose=) {
/* DOCUMENT make_fs(latutm=, q=, ext_bad_att=, usecentroid=, forcechannel=, verbose=)
  This function prepares data to write/plot first surface topography for a
  selected region of flightlines.

  ext_bad_att is a value in meters. Points within that distance from the mirror
  are eliminated. Set to 0 to disable this filtering.
*/
// Original amar nayegandhi 09/18/02
  extern ops_conf, tans, pnav;
  default, verbose, 1;

  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "tans is not set";
  if(is_void(pnav))
    error, "pnav is not set";

  if(is_void(q))
    q = pnav_sel_rgn(region=llarr);

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q, verbose=verbose);

  if(is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  no_t = numberof(rn_arr(1,));

  // initialize counter variables
  tot_count = 0;
  ba_count = 0;
  fcount = 0;

  fs_all = array(pointer, no_t);
  for(i = 1; i <= no_t; i++) {
    if(rn_arr(1,i) != 0) {
      fcount++;
      msg = swrite(format="Line %d/%d: Processing first surface...", i, no_t);
      if(verbose) write, msg;
      pause, 1; // make sure Yorick shows output
      status, start, msg=msg;
      rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i),
          usecentroid=usecentroid, forcechannel=forcechannel, msg=msg,
          verbose=verbose, ext_bad_att=ext_bad_att);
      // Must call again since first_surface will clear it:
      status, start, msg=msg;
      fs_all(i) = &rrr;
      tot_count += numberof(rrr.elevation);
    }
  }
  status, finished;
  fs_all = merge_pointers(fs_all);

  if(verbose) {
    write, "\nStatistics: \r";
    write, format="Total records processed = %d\n", tot_count;
    write, format="Total records with inconclusive first surface" +
        "return range = %d\n", ba_count;

    if(tot_count != 0) {
      pba = float(ba_count)*100.0/tot_count;
      write, format = "%5.2f%% of the total records had "+
          "inconclusive first surface return ranges \n", pba;
    } else {
      write, "No first surface returns found";
    }
  }

  return fs_all;
}
