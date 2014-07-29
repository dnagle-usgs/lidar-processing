// vim: set ts=2 sts=2 sw=2 ai sr et:

local eaarl_processing_modes;
/* DOCUMENT eaarl_processing_modes
  This variable defines the routines needed to process EAARL data. New EAARL
  processing modes will get a new entry in this oxy object. This allows the
  processing functions to be generalized and extensible.
*/
if(is_void(eaarl_processing_modes)) eaarl_processing_modes = save();
save, eaarl_processing_modes,
  f=save(
    process="process_fs",
    cast="fs_struct_from_obj"
  ),
  b=save(
    process="process_ba",
    cast="ba_struct_from_obj"
  ),
  v=save(
    process="process_be",
    cast="be_struct_from_obj"
  ),
  sb=save(
    process="process_sb",
    cast="ba_struct_from_obj"
  );

func process_eaarl(start, stop, mode=, ext_bad_att=, channel=, ptime=, opts=) {
/* DOCUMENT process_eaarl(start, stop, mode=, ext_bad_att=, channel=, ptime=,
   opts=)
  Processes EAARL data for the given raster ranges as specified by the given
  mode.

  Parameters:
    start: Raster number to start at. This may also be an array.
    stop: Raster number to stop at. This may also be an array and must match
      the size of START. If omitted, STOP is set to START.

    Alternately:

    start: May be a pulses object as returned by decode_rasters. In this case,
      STOP is ignored.

  Options:
    mode= Processing mode.
        mode="f"    Process for first surface (default)
        mode="b"    Process for bathymetry (submerged topography)
        mode="v"    Process for vegetation (bare earth)
        mode="sb"   Process for shallow bathymetry
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. Required. This can
      be an integer or array of integers for the channels to process.
    ptime= Processing time identifier. By default this will be the current SOE
      value times -1.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by process_eaarl
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  restore_if_exists, opts, start, stop, mode, ext_bad_att, channel, ptime;
  if(is_void(channel)) error, "Must specify channel= option";

  extern eaarl_processing_modes;
  default, mode, "f";
  default, ptime, -getsoe();

  if(!eaarl_processing_modes(*,mode))
    error, "invalid mode";
  local process, cast;
  restore, eaarl_processing_modes(noop(mode)), process, cast;
  if(is_string(process)) process = symbol_def(process);
  if(is_string(cast)) cast = symbol_def(cast);

  passopts = save(start, stop, mode, ext_bad_att, channel);
  if(opts)
    passopts = obj_merge(opts, passopts);

  result = cast(process(opts=passopts));
  if(has_member(result, "ptime")) result.ptime = ptime;
  return result;
}

func make_eaarl(mode=, q=, region=, ply=, ext_bad_att=, channel=, verbose=,
opts=) {
/* DOCUMENT make_eaarl(mode=, q=, region=, ext_bad_att=, channel=, verbose=,
   opts=)
  Processes EAARL data for the given mode in a region specified by the user.

  Options for selection:
    q= An index into pnav for the region to process.
    region= A region to process. See region_to_shp for what can be used as a
      region. If Q is provided, REGION is ignored.
    Note: if neither Q nor REGION are provided, the user will be prompted to
    draw a box to select the region.

  Options for processing:
    mode= Processing mode.
        mode="f"    Process for first surface (default)
        mode="b"    Process for bathymetry (submerged topography)
        mode="v"    Process for vegetation (bare earth)
        mode="sb"   Process for shallow bathymetry
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. Required. This can
      be an integer or array of integers for the channels to process.

  Additional options:
    verbose= Specifies verbosity level.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by make_eaarl
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  t0 = array(double, 3);
  timer, t0;

  restore_if_exists, opts, mode, q, ply, region, ext_bad_att, channel, verbose;
  if(!is_void(ply)) {
    error, "ply= is no longer accepted by make_eaarl; use region= instead";
  }
  if(is_void(channel)) error, "Must specify channel= option";

  extern ops_conf, tans, pnav;

  default, mode, "f";
  default, verbose, 1;

  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "tans is not set";
  if(is_void(pnav))
    error, "pnav is not set";

  if(is_void(q))
    q = pnav_sel_rgn(region=region);

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q, verbose=verbose);

  if(is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  // Break rn_arr up into per-TLD raster ranges instead
  rn_start = rn_stop = [];
  edb_raster_range_files, rn_arr(1,), rn_arr(2,), , rn_start, rn_stop;

  rn_counts = (rn_stop - rn_start + 1)(cum)(2:);

  count = numberof(rn_start);
  data = array(pointer, count);

  ptime = -getsoe();
  passopts = save(mode, channel, ext_bad_att, verbose, ptime);
  if(opts)
    passopts = obj_delete(obj_merge(opts, passopts), start, stop);

  status, start, msg="Processing; finished CURRENT of COUNT rasters",
    count=rn_counts(0);
  if(verbose)
    write, "Processing...";
  for(i = 1; i <= count; i++) {
    if(verbose) {
      write, format=" %d/%d: rasters %d through %d\n",
        i, count, rn_start(i), rn_stop(i);
    }
    data(i) = &process_eaarl(rn_start(i), rn_stop(i), opts=passopts);
    status, progress, rn_counts(i), rn_counts(0);
  }
  status, finished;

  data = merge_pointers(data);

  if(verbose) {
    write, format=" Total points derived: %d\n", numberof(data);
    timer_finished, t0;
  }

  return data;
}

func make_eaarl_from_tld(tldfn, start, stop, rnstart, mode=, channel=,
ext_bad_att=, ptime=, opts=) {
/* DOCUMENT make_eaarl_from_tld(tldfn, start, stop, rnstart, mode=, channel=,
   ext_bad_att=, ptime=, opts=)
  Processes EAARL data. This is a lower-level version of make_eaarl that is
  primarily intended for use in jobs.

  Parameters:
  The parameters specify the raw data to process. They may be scalar or array,
  but must all have the same count.
    tldfn: The full path to a TLD file.
    start: Starting byte offset into the TLD file.
    stop: Stopping byte offset into the TLD file.
    rnstart: Raster number of first raster in selected data.

  Options:
    mode= Processing mode.
        mode="f"    Process for first surface (default)
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. Required. This can
      be an integer or array of integers for the channels to process.
    ptime= Processing time identifier. By default this will be the current SOE
      value times -1.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by this function
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  restore_if_exists, opts, tldfn, start, stop, rnstart, mode, channel,
    ext_bad_att, ptime;
  if(is_void(channel)) error, "Must specify channel= option";

  default, ptime, -getsoe();

  passopts = save(mode, channel, ext_bad_att, ptime);
  if(opts)
    passopts = obj_delete(obj_merge(opts, passopts),
      tldfn, start, stop, rnstart);

  result = array(pointer, numberof(tldfn));
  for(i = 1; i <= numberof(tldfn); i++) {
    pulses = eaarl_decode_fast(tldfn(i), start(i), stop(i),
      rnstart=rnstart(i), wfs=1);
    result(i) = &process_eaarl(pulses, opts=passopts);
  }
  pulses = [];

  return merge_pointers(result);
}

func save_eaarl_for_channels(data, channels, pbdfn, vname, empty=) {
/* DOCUMENT save_eaarl_for_channels, data, channels, pbdfn, vname, empty=
  Utility function for job to create processed EAARL data.

  In the trivial case where channels is a scalar or void, this just writes the
  data to file (using pbd_save) using the pdbfn and vname specified.

  If channels is an array, then pbdfn and vname must be arrays of the same
  size. The data point cloud will be split apart for each channel and a
  separate file created.
*/
  if(numberof(channels) <= 1) {
    mkdirp, file_dirname(pbdfn);
    pbd_save, pbdfn, vname, data, empty=empty;
  } else {
    for(i = 1; i <= numberof(channels); i++) {
      w = where(data.channel == channels(i));
      mkdirp, file_dirname(pbdfn(i));
      pbd_save, pbdfn(i), vname(i), data(w), empty=empty;
    }
  }
}

func mf_make_eaarl(mode=, q=, region=, ply=, ext_bad_att=, channel=, verbose=,
makeflow_fn=, norun=, retconf=, opts=) {
/* DOCUMENT mf_make_eaarl(mode=, q=, region=, ext_bad_att=, channel=, verbose=,
   makeflow_fn=, norun=, retconf=, opts=)
  Processes EAARL data for the given mode in a region specified by the user.
  Unlike make_eaarl, mf_make_eaarl uses Makeflow to run flightlines in
  parallel.

  Options for selection:
    q= An index into pnav for the region to process.
    region= A region to process. See region_to_shp for what can be used as a
      region. If Q is provided, REGION is ignored.
    Note: if neither Q nor REGION are provided, the user will be prompted to
    draw a box to select the region.

  Options for processing:
    mode= Processing mode.
        mode="f"    Process for first surface (default)
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. Required. This can
      be an integer or array of integers for the channels to process.

  Options for makeflow:
    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.
    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
    retconf= Don't actually run makeflow; just return the configuration object.
        retconf=0   Runs makeflow, default
        retconf=1   Returns conf object

  Additional options:
    verbose= Specifies verbosity level.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by mf_make_eaarl
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  t0 = array(double, 3);
  timer, t0;

  restore_if_exists, opts, mode, q, ply, region, ext_bad_att, channel, verbose,
    makeflow_fn, retconf, norun;
  if(!is_void(ply)) {
    error, "ply= is no longer accepted by mf_make_eaarl; use region= instead";
  }
  if(is_void(channel)) error, "Must specify channel= option";

  extern ops_conf, tans, pnav;

  default, mode, "f";
  default, verbose, 1;

  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "tans is not set";
  if(is_void(pnav))
    error, "pnav is not set";

  if(is_void(q))
    q = pnav_sel_rgn(region=region);

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q, verbose=verbose);

  if(is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  // Break rn_arr up into per-TLD raster ranges instead
  rn_start = rn_arr(1,);
  rn_stop = rn_arr(2,);
  rn_arr = [];
  raster_sources, rn_start, rn_stop, tldfn, offset_start, offset_stop;

  tempdir = mktempdir("mf_make_eaarl");
  pbdfn = file_join(tempdir, swrite(format="eaarl_%d.pbd", rn_start));

  if(is_void(makeflow_fn))
    makeflow_fn = file_join(tempdir, "mf_make_eaarl.makeflow");

  count = numberof(rn_start);

  ptime = -getsoe();

  options = save(string(0), [], mode, channel, ext_bad_att, ptime);
  if(opts)
    options = obj_delete(obj_merge(opts, options),
      q, region, makeflow_fn, norun);

  conf = save();
  for(i = 1; i <= count; i++) {
    remove, pbdfn(i);
    save, conf, string(0), save(
      input=tldfn(i),
      output=pbdfn(i),
      command="job_eaarl_process",
      options=obj_merge(options, save(
        "tldfn", tldfn(i),
        "pbdfn", pbdfn(i),
        "start", offset_start(i),
        "stop", offset_stop(i),
        "rnstart", rn_start(i),
        "rnstop", rn_stop(i),
        "vname", swrite(format="%s_%d", mode, i)
      ))
    );
  }

  if(retconf) return conf;

  makeflow_requires_jobenv, "job_eaarl_process";
  hook_add, "makeflow_run", "hook_prep_job_eaarl_process";
  hook_add, "job_run", "hook_run_job_eaarl_process";

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;
  if(norun) {
    if(verbose)
      write, "Aborting, norun=1";
    return;
  }

  if(verbose)
    write, "Collating data from temporary files...";
  data = dirload(files=pbdfn, verbose=0);
  if(verbose)
    write, "Cleaning up...";
  remove_recursive, tempdir;

  if(verbose) {
    write, format=" Total points derived: %d\n", numberof(data);
    timer_finished, t0;
  }

  return data;
}

func mf_batch_eaarl(mode=, outdir=, update=, ftag=, vtag=, date=,
ext_bad_att=, channel=, pick=, plot=, onlyplot=, win=, region=, ply=, q=,
shapefile=, buffer=, force_zone=, log_fn=, makeflow_fn=, norun=, retconf=,
exactsel=, splitchan=, opts=) {
/* DOCUMENT mf_batch_eaarl
  Most common options:
    mf_batch_eaarl, pick=, region=, q=, mode=, channel=, outdir=

  Makeflow batch processes EAARL data for the given mode in a region specified
  by the user.

  Options for selection:
    pick= Specifies which interactive method to use for selecting the
      processing region.
        pick="box"    The will be prompted to drag out a box (default)
        pick="pip"    The user will be prompted to draw a polygon
    region= A region to process. See region_to_shp for what can be used as a
      region. If used, pick= is ignored.
    q= Specifies a selected region to process by sod timestamps, as returned by
      the processing GUI. If used, pick= and region= are ignored.
    exactsel= Toggles the exact selection mode. By default (exactsel=0), the
      selection is used to determine what tiles to process; then, those tiles
      are processed in their entirity even if parts of them are outside of the
      processing selection. Specifying exactsel=1 will cause only the selection
      to be processed, even if it would result in a partial tile.

  Options for processing:
    mode= Processing mode.
        mode="f"    Process for first surface (default)
    channel= Specifies which channel or channels to process. Required. This can
      be an integer or array of integers for the channels to process.
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    force_zone= Specifies a zone to coerce output to. If not provided, then the
      zone is determined automatically. If a dataset crosses zone boundaries,
      the output will contain data from both zones, in the correct zones. This
      should normally be omitted.

  Options for output:
    outdir= Output directory; this often ends in "Index_Tiles". This is a
      required option.
    update= Specifies how to handle existing files.
        update=0    Delete and re-create tiles that already exist, default
        update=1    Skip tiles that already exist
    date= The date of the flight. This should be a string in "YYYYMMDD" format.
      Optionally, it can have additional information after the date. If
      omitted, the date is determined by sanitizing the flight's directory
      name.
    ftag= Specifies the "tag" to use in the filename. Output files are
      formatted as "<tile>_<tag>.pbd" where <tile> is the full tile name
      (t_e###000_n####000_##). The default ftag is:
        w84_YYYYMMDD_chanNN_T -or- w84_YYYYMMDD_T
      Where YYYYMMDD is date= (including anything appended via date=), chanNN
      represents the channels used (channel=[1,2,3] will result in chan123),
      and T is the mode= used. If channel= is not specifies, chanNN is omitted.
    vtag= Specifies the "tag" to use in the variable names. The variable names
      are formated as "<tile>_<tag>" where <tile> is the short tile name
      (e###_n####_##). The default vtag is:
        w84_MMDD_chanNN_T -or- w84_MMDD_T
      Where MMDD is date= with its first four characters removed (YYYY removed)
      and the other values are as described in ftag=.
    splitchan= By default, if multiple channels are specified, they are all
      written out to the same output files merged together. Specify splitchan=1
      to split them into separate per-channel files instead. This option is
      incompatible with ftag and vtag. This option requires channel=.
    log_fn= Specifies where to write the log describing the batch job. If not
      provided, a path will be automatically determeind based on the current
      time and the output parameters and will be stored in a logs subdirectory
      under outdir.

  Miscellaneous options:
    buffer= Specifies the buffer to use around each tile, in meters. This is
      not typically provided as the default is normally sufficient.
        buffer=200.   200 meters, default
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by
      mf_batch_eaarl will be passed through as-is to the underlying processing
      function.

  Options for feedback:
    plot= Specifies whether the region of interest and the tiles to be
      processed are plotted. The region is plotted in red, the tiles in cyan.
        plot=1        Plot regions and tiles, default
        plot=0        No plotting
    onlyplot= Allows you to visually preview which tiles are covered by the
      region of interest. The tiles are plotted in yellow.
        onlyplot=0    Process normally, default
        onlyplot=1    Don't process, just plot the tile lines
    win= Specifies which window to use.
        win=6         Default, window 6

  Options for makeflow:
    makeflow_fn= The filename to use when writing out the makeflow. If not
      provided, this will be given the same base filename as log_fn but will be
      created in a work subdirectory under outdir. Other related makeflow files
      will also be created alongside this.
    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
    retconf= Don't actually run makeflow; just return the configuration object.
        retconf=0   Runs makeflow, default
        retconf=1   Returns conf object
*/
  t0 = array(double, 3);
  timer, t0;

  restore_if_exists, opts, mode, outdir, update, ftag, vtag, date,
    ext_bad_att, channel, pick, plot, onlyplot, win, region, ply, q, shapefile,
    buffer, force_zone, log_fn, makeflow_fn, norun, retconf, exactsel,
    splitchan;
  if(!is_void(ply)) {
    error, "ply= is no longer accepted by mf_batch_eaarl; use region= instead";
  }
  if(!is_void(shapefile)) {
    error, "shapefile= is no longer accepted by mf_batch_eaarl; use region= instead";
  }
  if(is_void(channel)) error, "Must specify channel= option";

  default, mode, "f";
  default, buffer, 200.;
  default, win, 6;
  default, plot, 1;
  now = getsoe();

  if(is_void(outdir)) error, "Must provide outdir=";

  if(splitchan) {
    if(!is_void(ftag) || !is_void(vtag))
      error, "cannot mix splitchan=1 with ftag= or vtag=";
    if(is_void(channel))
      error, "splitchan= requires channel=";
  }

  // Determine the metadata part of the filename, if needed
  // ftag is for files and will look like:
  //    w84_YYYYMMDD_chanNN_T.pbd -or- w84_YYYYMMDD_T.pbd
  // vtag is for variable names and will look like:
  //    w84_MMDD_chanNN_T -or- w84_MMDD_T
  ftagsingle = [];
  if(is_void(ftag) || is_void(vtag)) {
    if(is_void(date)) {
      date = file_tail(mission(get, mission.data.loaded, "data_path dir"));
      date = regsub("[^A-Za-z0-9]", date, "", all=1);
    }

    chantag = string(0);
    if(!is_void(channel)) {
      if(splitchan)
        chantag = swrite(format="chan%d", channel);
      else
        chantag = "chan" + swrite(format="%d", channel)(*)(sum);
    }

    if(is_void(ftag)) {
      ftag = "w84_" + date;
      if(splitchan || chantag) {
        ftagsingle = ftag + "_" + strjoin(chantag, "_") + "_" + mode;
        ftag += "_" + chantag;
      }
      ftag += "_" + mode;
    }

    if(is_void(vtag)) {
      vtag = "w84_" + strpart(date, 5:);
      if(splitchan || chantag) vtag += "_" + chantag;
      vtag += "_" + mode;
    }

    chantag = [];
  }
  if(is_void(ftagsingle)) ftagsingle = ftag;
  // Make sure it's safe for use in a variable name
  for(i = 1; i <= numberof(vtag); i++) {
    vtag(i) = sanitize_vname(vtag(i));
    if(strpart(vtag(i), 1:1) != "_") vtag(i) = "_" + vtag(i);
  }
  for(i = 1; i <= numberof(ftag); i++) {
    if(strpart(ftag(i), 1:1) != "_") ftag(i) = "_" + ftag(i);
    if(file_extension(ftag(i)) != ".pbd") ftag(i) += ".pbd";
  }
  if(strpart(ftagsingle, 1:1) != "_") ftagsingle = "_" + ftagsingle;
  ftagsingle = file_rootname(ftagsingle);

  // Default makeflow_fn is: YYYYMMDD_HHMMSS_w84_YYMMDD_chanNN_T.log
  if(is_void(log_fn)) {
    // Start out with current timestamp as YYYYMMDD_HHMMSS
    ts = regsub(" ", regsub("-|:", soe2iso8601(now), "", all=1), "_");
    // Add ftagsingle, then make into full path with extension .log
    log_fn = file_join(outdir, "logs", ts + ftagsingle + ".log");
    ts = [];
  }

  // Model makeflow_fn after log_fn, but put in work directory for easier
  // deletion
  if(is_void(makeflow_fn)) {
    makeflow_fn = file_join(outdir, "work",
      file_tail(file_rootname(log_fn)) + ".makeflow");
  }

  if(is_void(q))
    q = pnav_sel_rgn(region=region, mode=pick, verbose=0);
  idx = pnav_rgn_to_idx(q);

  if(is_void(idx)) {
    write, "No data found in region selected.";
    return;
  }

  // Determine which tiles to process
  local north, east, zone, n, e;
  ll2utm, pnav(idx).lat, pnav(idx).lon, north, east, zone, force_zone=force_zone;
  zones = zone(unique(zone));
  dtiles = array(pointer, numberof(zones));
  for(i = 1; i <= numberof(zones); i++) {
    w = where(zone == zones(i));
    n = (north(w)(-,) + (buffer*[-1,-1, 1, 1])(,-))(*);
    e = ( east(w)(-,) + (buffer*[-1, 1,-1, 1])(,-))(*);
    dtiles(i) = &utm2dt_names(e, n, zones(i), dtlength="long", dtprefix=1);
  }
  dtiles = merge_pointers(dtiles);
  zone = zones = n = e = [];

  // Construct output filenames and variable names
  itiles = dt2it(dtiles, dtlength="long", dtprefix=1);
  outfiles = file_join(outdir, itiles, dtiles, dtiles + ftag(-,));
  vnames = extract_dt(dtiles, dtlength="short", dtprefix=0) + vtag(-,);

  // Calculate bounding boxes
  minx = maxx = miny = maxy = 0;
  dt2utm, dtiles, minx, maxy, zone;
  miny = maxy - 2000;
  maxx = minx + 2000;
  bminx = minx - buffer;
  bmaxx = maxx + buffer;
  bminy = miny - buffer;
  bmaxy = maxy + buffer;

  if(onlyplot) {
    wbkp = current_window();
    window, win;
    pldj, minx, miny, minx, maxy, color="yellow";
    pldj, maxx, miny, maxx, maxy, color="yellow";
    pldj, minx, miny, maxx, miny, color="yellow";
    pldj, minx, maxy, maxx, maxy, color="yellow";
    window_select, wbkp;
    return;
  }

  // Set base options
  ptime = getsoe();
  options = save(string(0), [], mode, channel, ext_bad_att, ptime);
  if(opts)
    options = obj_delete(obj_merge(opts, options),
      makeflow_fn, norun);

  // Create log file
  mkdirp, file_dirname(log_fn);
  f = open(log_fn, "w");
  write, f, format="Batch processing log file%s", "\n";
  write, f, format="%s\n", soe2iso8601(now);
  write, f, format="Makeflow created on %s by %s\n\n", get_host(), get_user();

  write, f, format="hg id: %s\n", _hgid;
  write, f, format="ptime: %d\n\n", ptime;

  write, f, format="data_path: %s\n", data_path;
  write, f, format="edb_filename: %s\n", edb_filename;
  write, f, format="pnav_filename: %s\n", pnav_filename;
  write, f, format="ins_filename: %s\n\n", ins_filename;

  write, f, format="ops_conf settings:%s", "\n";
  write_ops_conf, f;

  write, f, format="\nbathy settings:%s", "\n";
  bathconf, display, fh=f;

  write, f, format="\nOptions used:%s", "\n";
  write, f, format="%s", obj_show(save(
    mode, outdir, update, ftag, vtag, date, ext_bad_att, channel, pick, plot,
    onlyplot, win, buffer, force_zone, exactsel, splitchan, log_fn,
    makeflow_fn, norun, retconf, opts), maxchild=100, maxary=10);

  if(!is_void(region)) {
    write, f, format="\nProcessing area:%s", "\n";
    write, f, format="%s\n", region_to_string(region);
  } else {
    write, f, format="\nProcessing selection:%s", "\n";
    write, f, format="%s\n", print(q);
  }

  write, f, format="\nOutput files:%s", "\n";
  write, f, format="%s\n", file_tail(outfiles(sort(outfiles)(*)));
  close, f;

  // Build job queue
  local offset_start, offset_stop, tldfn;
  count = dimsof(outfiles)(2);
  conf = save();
  for(i = 1; i <= count; i++) {
    if(update) {
      skip = 1;
      for(j = 1; j <= numberof(outfiles(i,)); j++)
        skip = skip && file_exists(outfiles(i,j));
      if(skip) continue;
    }
    for(j = 1; j <= numberof(outfiles(i,)); j++)
      remove, outfiles(i);

    if(exactsel) {
      w = data_box(east, north, bminx(i), bmaxx(i), bminy(i), bmaxy(i));
      if(is_void(w)) continue;
      q = gga_find_times(idx(w));
    } else {
      q = pnav_sel_rgn(region=[bminx(i), bmaxx(i), bminy(i), bmaxy(i)],
        win=win, _batch=1, verbose=0, plot=plot);
    }
    if(is_void(q)) continue;
    rn_arr = sel_region(q, verbose=0);
    if(is_void(rn_arr)) continue;

    rn_start = rn_arr(1,);
    rn_stop = rn_arr(2,);
    rn_arr = [];

    raster_sources, rn_start, rn_stop, tldfn, offset_start, offset_stop;

    save, conf, string(0), save(
      input=tldfn,
      output=outfiles(i,),
      command="job_eaarl_process",
      options=obj_merge(options, save(
        "tldfn", tldfn,
        "pbdfn", outfiles(i,),
        "start", offset_start,
        "stop", offset_stop,
        "rnstart", rn_start,
        "rnstop", rn_stop,
        "vname", vnames(i,)
      ))
    );
  }

  if(retconf) return conf;

  makeflow_requires_jobenv, "job_eaarl_process";
  hook_add, "makeflow_run", "hook_prep_job_eaarl_process";
  hook_add, "job_run", "hook_run_job_eaarl_process";

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;

  timer_finished, t0;
}

func hook_prep_job_eaarl_process(env) {
/* DOCUMENT env = hook_prep_job_eaarl_process(env)
  This is intended to be used as a hook on "makeflow_run" for the job
  "job_eaarl_process". It saves the mission configuration for the job.
*/
  conf = obj_copy(env.conf, recurse=1);
  path = file_rootname(env.fn);

  needed = 0;
  for(i = 1; i <= conf(*); i++) {
    item = conf(noop(i));
    if(item.command != "job_eaarl_process") continue;
    needed = 1;

    keep = array(0, dimsof(tans));
    for(j = 1; j <= numberof(item.options.rnstart); j++) {
      w = where(
        (edb(item.options.rnstart(j)).seconds - soe_day_start - 1 <= tans.somd) &
        (edb(item.options.rnstop(j)).seconds - soe_day_start + 2 >= tans.somd)
      );
      keep(w) = 1;

    }
    w = where(keep);
    wrapped = mission(wrap, cache_what="everything");
    save, wrapped, tans=tans(w), iex_nav=iex_nav(w);
    if(wrapped(*,"bathconf_data"))
      save, wrapped, bathconf_data=serialize(wrapped.bathconf_data);
    if(wrapped(*,"ops_conf"))
      save, wrapped, ops_conf=serialize(wrapped.ops_conf);
    if(wrapped(*,"vegconf_data"))
      save, wrapped, vegconf_data=serialize(wrapped.vegconf_data);
    if(wrapped(*,"sbconf_data"))
      save, wrapped, sbconf_data=serialize(wrapped.sbconf_data);

    // Temporary hack for veg
    define_veg_conf;
    save, wrapped, veg_conf;

    flight = extract_tile(file_tail(item.options.pbdfn(1)));
    if(!flight) flight = strjoin(file_tail(file_rootname(
      item.options.pbdfn(*))),"_");
    flightfn = file_join(path, flight+".flight");
    mkdirp, path;
    obj2pbd, wrapped, flightfn;
    wrapped = [];

    save, item, input=grow(item.input, flightfn);
    save, item.options, flightfn;
  }

  if(needed) save, env, conf;
  return env;
}

func hook_run_job_eaarl_process(env) {
/* DOCUMENT env = hook_run_job_eaarl_process(env)
  This is intended to be used as a hook on "job_run" for the job
  "job_eaarl_process". It restores the mission configuration for the job.
*/
  if(env.job_func != "job_eaarl_process" || !env.conf(*,"flightfn"))
    return env;

  wrapped = pbd2obj(env.conf.flightfn);

  // Temporary hack for old-style veg
  extern veg_conf;
  if(wrapped(*,"veg_conf"))
    veg_conf = wrapped.veg_conf;

  if(wrapped(*,"bathconf_data"))
    save, wrapped, bathconf_data=deserialize(wrapped.bathconf_data);
  if(wrapped(*,"ops_conf"))
    save, wrapped, ops_conf=deserialize(wrapped.ops_conf);
  if(wrapped(*,"vegconf_data"))
    save, wrapped, vegconf_data=deserialize(wrapped.vegconf_data);
  if(wrapped(*,"sbconf_data"))
    save, wrapped, sbconf_data=deserialize(wrapped.sbconf_data);
  mission, unwrap, wrapped;

  return env;
}
