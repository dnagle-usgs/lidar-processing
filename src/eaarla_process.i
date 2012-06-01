// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func eaarla_process(fnc, q=, region=, verbose=, opt=) {
/* DOCUMENT eaarla_process(fnc, q=, region=, verbose=, opt=)
  Processes EAARL-A data.

  Parameter FNC must be a function or function name. The function must have a
  signature that contains, at a minimum:

    func FNC(wf, opt=) { }

  where WF is a waveform object and OPT is a oxy group object containing
  keyword options. The function may optionally accept additional keywords or
  additional arguments, but they will not be used by this function.

  Options:
    q= An array of indices into PNAV specifying the region to process. If not
      specified, REGION= will be used.
    region= This may be a 4-element vector [min_x, max_x, min_y, max_y] -OR- a
      2xN array of verticies representing a polygon, specifying the region to
      process. This is only used if Q= is omitted. If Q= and REGION= are both
      omitted, then the user will be prompted to drag out a box in the current
      window.
    verbose= Specifies whether informational output should be displayed by
      eaarla_process. By default it is, use verbose=0 to disable. This value is
      stored to OPT as well, unless OPT already has a VERBOSE= key.
    opt= An oxy group object containing key-value pairs that will be passed to
      FNC. This allows for arbitrary key-value configuration information to be
      passed through to the function.

  For each call to FNC, this function will set OPT.rn_start to the raster
  number of the first point in WF. This is intended to allow FNC to most
  efficiently calculate raster numbers. If the user supplies a value for
  rn_start in OPT, that value will be clobbered.
*/
  extern edb, soe_day_start, tans, pnav, ops_conf;
  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "INS data not loaded";
  if(is_void(pnav))
    error, "PNAV data not loaded";

  if(is_string(fnc)) {
    if(!symbol_exists(fnc))
      error, "unknown function name: "+fnc;
    if(!is_func(symbol_def(fnc)))
      error, "not a function name: "+fnc;
    fnc = symbol_def(fnc);
  }
  if(!is_func(fnc))
    error, "must provide function or function name as first argument";
  
  default, verbose, 1;
  default, opt, save();
  keydefault, opt, verbose=verbose;

  if(is_void(q))
    q = pnav_sel_rgn(region=region, verbose=verbose);
  if(is_void(q))
    error, "No data in selected region";

  rns = sel_region(q, verbose=verbose);
  if(is_void(rns))
    error, "No data in selected region";

  start = rns(1,);
  stop = rns(2,);

  // Break ranges up into small chunks for better interactive processing and to
  // reduce total memory footprint
  count = numberof(start);
  for(i = 1; i <= count; i++) {
    chunks = (stop(i) - start(i))/50;
    if(chunks) {
      chunks++;
      chunk = long(ceil(double(stop(i) - start(i) + 1)/chunks));
      grow, start, indgen(start(i):stop(i):chunk)(2:);
      grow, stop, indgen(start(i):stop(i):chunk)(2:)-1;
    }
  }
  start = start(sort(start));
  stop = stop(sort(stop));

  progress = (stop - start + 1)(cum)(2:);

  result = array(pointer, numberof(start));
  status, start, count=progress(0), interval=0.1,
    msg="Processing first surface, finished CURRENT rasters of COUNT...";
  for(i = 1; i <= numberof(start); i++) {
    raw = merge_pointers(get_erast(rn=indgen(start(i):stop(i))));
    rasts = eaarla_decode_rasters(raw, wfs=1);
    wf = georef_eaarla(rasts, pnav, tans, ops_conf, soe_day_start);
    raw = rasts = [];
    save, opt, rn_start=start(i);
    // Pass a copy of OPT to guard against any changes FNC might make.
    result(i) = &fnc(wf, opt=obj_copy(opt));
    status, progress, progress(i), progress(0);
  }
  status, finished;

  return merge_pointers(result);
}

func eaarla_init_pointcloud(wf, rn_start=) {
/* DOCUMENT result = eaarla_init_pointcloud(wf, rn_start=)
  Initializes a POINTCLOUD_2PT structure based on WF, which should be a wfobj.
  The fields zone, mx, my, mz, soe, raster_seconds, raster_fseconds, pulse,
  channel, and digitizer will all be populated. If RN_START= is provided, it
  should be the raster number of the first point; the rn field will the be
  populated, with the assumption that the points in WF are in ascending order
  by raster and that the rasters are continuous.

  This is primariliy a utility function for EAARL-A processing functions.
*/
  result = array(POINTCLOUD_2PT, wf.count);

  // Calculate raster numbers
  if(!is_void(rn_start)) {
    r_sec = wf(raster_seconds,);
    r_fsec = wf(raster_fseconds,);
    result.rn = ((r_sec(dif) != 0) | (r_fsec(dif) != 0))(cum) + rn_start;
    r_sec = r_fsec = [];
    result.rn += (long(wf(pulse,)) << 24);
  }

  result.zone = h_has(cs, zone=) ? cs.zone : 0;
  result.mx = wf(raw_xyz0, , 1);
  result.my = wf(raw_xyz0, , 2);
  result.mz = wf(raw_xyz0, , 3);
  result.soe = wf(soe,);
  result.raster_seconds = wf(raster_seconds,);
  result.raster_fseconds = wf(raster_fseconds,);
  result.pulse = wf(pulse,);
  result.channel = wf(channel,);
  result.digitizer = wf(digitizer,);

  return result;
}

func eaarla_fs(wf, opt=, usecentroid=, altitude_thresh=, rn_start=, keepbad=) {
/* DOCUMENT pointcloud = eaarla_fs(wf, opt=, usecentroid=, altitude_thresh=,
    rn_start=, keepbad=)

  Processes waveform data for first surface returns. WF should be a wfobj with
  EAARL-A data.

  Options:
    opt= May be an oxy group or Yeti hash containing any of the other options
      accepted by this function.
    usecentroid= Specifies whether the centroid should be used for locating the
      peaks in TX and RX.
        usecentroid=1     Use the centroid (default)
        usecentroid=0     Do not use the centroid
    altitude_thresh= If specified, the points will be filtered so that any
      points within ALTITUDE_THRESH meters of the mirror coordinate's elevation
      will be discarded. By default, this is set to [] and is not applied.
    rn_start= The raster number of the first point in WF. If provided, the
      points in WF should be in continuous ascending order by raster, with no
      gaps in raster number. The points will have then have rn defined in the
      return result.
    keepbad= By default, certain kinds of bad points are eliminated from the
      resulting point cloud: points with invalid coordinates (inf), points
      within a certain range of the mirror (when altitude_thresh is provided),
      and points flagged as dropouts in the raw data (using the flags in bits
      14 and 15 of the irange field). Using keepbad=1 will mean that these
      points are kept instead of removed, but their xyz fields will all be set
      to 0 to make them easier to remove later.
*/
  default, opt, save();
  if(is_hash(opt)) opt = hash2obj(opt);
  default, usecentroid, 1
  default, altitude_thresh, []
  default, rn_start, 1;
  default, keepbad, 0;
  opt = obj_merge(save(usecentroid, altitude_thresh, rn_start, keepbad), opt);

  sample2m = wf.sample_interval * NS2MAIR;
  cs = cs_parse(wf.cs, output="hash");

  if(opt.usecentroid) {
    // Pick the channel for each triplet
    eaarla_wf_filter_channel, wf, lim=12, max_intensity=251,
      max_saturated=ops_conf.max_sfc_sat;

    working = eaarla_init_pointcloud(wf, rn_start=opt.rn_start);

    for(i = 1; i <= wf.count; i++) {
      tx_pos = [];
      tx = wf_filter_bias_first(short(*wf.tx(i)));
      wf_centroid, tx, tx_pos, lim=12;
      tx = [];

      rx_pos = rx_pow = [];
      rx = wf_filter_bias_first(short(*wf.rx(i)));
      wf_centroid, rx, rx_pos, lim=12;
      wf_peak, rx, , rx_pow;
      rx = [];

      if(abs(rx_pos) < 1e1000 && abs(tx_pos) < 1e1000) {
        dist = (rx_pos - tx_pos) * sample2m;
        xyz = point_project(wf(raw_xyz0,i,), wf(raw_xyz1,i,), dist, tp=1);
      } else {
        xyz = array(1e1000, 3);
      }

      working.fx(i) = working.lx(i) = xyz(1);
      working.fy(i) = working.ly(i) = xyz(2);
      working.fz(i) = working.lz(i) = xyz(3);
      working.fint(i) = working.lint(i) = rx_pow;
      working.ftx(i) = working.ltx(i) = tx_pos;
      working.frx(i) = working.lrx(i) = rx_pos;
    }
  } else {
    // Take first of each triplet
    wf, index, 1:wf.count:3;

    working = eaarla_init_pointcloud(wf, rn_start=opt.rn_start);

    working.fx = working.lx = wf(raw_xyz1, , 1);
    working.fy = working.ly = wf(raw_xyz1, , 2);
    working.fz = working.lz = wf(raw_xyz1, , 3);
    working.fint = working.lint = 0;
    working.ftx = working.ltx = 1;
    working.frx = working.lrx = 1;
  }

  // Blank out invalid points
  w = where(abs(working.fz) == 1e1000);
  if(numberof(w)) {
    working.fx(w) = working.fy(w) = working.fz(w) =
      working.lx(w) = working.ly(w) = working.lz(w) = 0;
  }

  // This provides support equivalent to ext_bad_att=1 when
  // altitude_thresh=20
  if(!is_void(opt.altitude_thresh)) {
    w = where(working.mz - working.fz < opt.altitude_thresh);
    if(numberof(w)) {
      working.fx(w) = working.fy(w) = working.fz(w) =
        working.lx(w) = working.ly(w) = working.lz(w) = 0;
    }
  }

  // Eliminate points flagged as rx/tx dropouts in the raw data
  w = where(wf(flag_irange_bit14,) | wf(flag_irange_bit15,));
  if(numberof(w)) {
    working.fx(w) = working.fy(w) = working.fz(w) =
      working.lx(w) = working.ly(w) = working.lz(w) = 0;
  }

  // Unless we're supposed to keep them, remove the points flagged for removal
  if(!opt.keepbad) {
    w = where(working.fx != 0);
    working = numberof(w) ? working(w) : [];
  }

  return working;
}
