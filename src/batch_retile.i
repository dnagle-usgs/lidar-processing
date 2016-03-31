/* batch_retile has three phases:
      1. Scan the source data to derive tile/coverage information
      2. Collate the tile/coverage information
      3. Generate tiled output files
*/

/* Shared helper functions ****************************************************/

func _batch_retile_defaults(args) {
  // Scan to retrieve fields that are refered to in calculating values.
  ref = save();
  wanted = ["srcdir", "suffix", "zone", "scandir"];
  optsidx = schemeidx = 0;
  for(i = 1; i <= args(0); i++) {
    if(anyof(args(-,i) == wanted)) save, ref, args(-,i), args(i);
    if(args(-,i) == "opts") optsidx = i;
    if(args(-,i) == "scheme") schemeidx = i;
  }

  opts = [];
  if(optsidx) opts = args(optsidx);
  if(is_void(opts)) opts = save();
  obj_delete_voids, opts;

  // Scheme gets special handling since it's an object. Pull it out, give it a
  // default, then update it to reflect anything provided in opts.
  scheme = [];
  if(schemeidx) scheme = args(schemeidx);
  if(is_void(scheme)) scheme = "it/dt long prefix";
  tile_scheme, scheme, opts=opts.scheme;
  save, opts, scheme;

  // Derive defaults
  defaults = save(
    // srcdir
    outdir=ref.srcdir,
    // scheme
    mode="fs",
    searchstr="*.pbd",
    update=0,
    file_suffix=ref.suffix,
    vname_suffix=ref.suffix,
    // suffix
    remove_buffers=0,
    buffer=100,
    uniq=1,
    // zone
    flat=0,
    split_zones=(ref.scheme == "qq"),
    split_days=0,
    day_shift=0,
    // scandir
    scanresume=0,
    scanonly=0);

  // Populate opts with defaults for whatever is missing or void
  for(i = 1; i <= defaults(*); i++) {
    key = defaults(*,i);
    if(opts(*,key)) continue;
    save, opts, noop(key), defaults(noop(key));
  }

  // Update opts to reflect values passed directly
  for(i = 1; i <= args(0); i++) {
    if(is_void(args(i)) || anyof(args(-,i) == ["opts","scheme"])) continue;
    save, opts, args(-,i), args(i);
  }

  // Special case: apply flat to scheme.path
  if(flat) save, opts.scheme, path="-";

  // Apply values from opts back to parameters
  for(i = 1; i <= args(0); i++) {
    key = args(-,i);
    if(opts(*,key)) args, i, opts(noop(key));
  }

  // If opts was in the parameter list, apply that as well
  if(optsidx) args, optsidx, opts;
}
wrap_args, _batch_retile_defaults;

/* STEP ONE: Scan the source data *********************************************/

func _batch_retile_scan_file(infile, outfile, opts=, remove_buffers=, zone=,
mode=, force_zone=, split_days=, day_shift=) {
  _batch_retile_defaults, opts, remove_buffers, zone, mode, force_zone,
    split_days, day_shift;

  if(!infile || !outfile) error, "Must provide infile and outfile";

  data = pbd_load(infile);
  tile = extract_tile(file_tail(infile));

  scan = _batch_retile_scan(data, tile=tile, opts=opts);
  save, scan, fn=infile;

  obj2pbd, scan, outfile;
}

func _batch_retile_scan(data, tile=, opts=, remove_buffers=, zone=, mode=,
force_zone=, split_days=, day_shift=) {
/* DOCUMENT _batch_retile_scan
  Worker function for batch_retile. This scans a single PBD file and creates a
  counts grid for its coverage. If split_days is enabled, then additional
  counts grids are generated for each flight.
*/
  local e, n;

  _batch_retile_defaults, opts, remove_buffers, zone, mode, force_zone,
    split_days, day_shift;

  result = save();
  if(!numberof(data)) return result;

  // Determine zone of data
  array_zone = 0;
  if(!zone) {
    datazone = long(tile2uz(tile));
  } else if(zone < 0) {
    array_zone = 1;
    datazone = data.zone;
  } else {
    datazone = zone;
  }

  // If we could parse a tile name and remove_buffers is enabled, throw away
  // buffer points
  if(remove_buffers && tile) {
    data = data_extract_match_tile(data, tile, zone=zone, mode=mode);
    if(!numberof(data)) return result;
    if(array_zone) datazone = data.zone;
  }

  // Extract coordinates
  data2xyz, data, e, n, mode=mode;

  // Rezone if needed
  if(force_zone) {
    rezone_utm, n, e, datazone, force_zone;
    datazone = force_zone;
  }
  save, result, zone=datazone;

  // Store coverage information. Dummy the z value with n, since coverage does
  // not pay any attention to it.
  save, result, coverage=cell_grid(e, n, n, method="counts", cell=25,
    xsnap="w", ysnap="n");

  if(split_days) {
    point_dates = soe2date(data.soe + day_shift);
    dates = set_remove_duplicates(point_dates);
    save, result, dates;
    for(i = 1; i <= numberof(dates); i++) {
      key = swrite(format="date_coverage_%d", i);
      w = where(point_dates == dates(i));
      save, result, noop(key),
        cell_grid(e(w), n(w), n(w), method="counts", cell=25, xsnap="w",
          ysnap="n");
    }
  }

  return result;
}

func batch_retile_scan(srcdir, scandir, searchstr=, remove_buffers=, mode=,
scheme=, dtlength=, dtprefix=, qqprefix=, buffer=, zone=, force_zone=,
split_days=, day_shift=, opts=) {
  _batch_retile_defaults, srcdir, scandir, searchstr, remove_buffers, mode,
    scheme, dtlength, dtprefix, qqprefix, buffer, zone, force_zone, split_days,
    day_shift, opts;

  files = find(srcdir, searchstr=searchstr);
  nfiles = numberof(files);
  if(!nfiles) error, "no files found";

  if(is_void(zone)) {
    zones = tile2uz(file_tail(files));
    if(noneof(zones)) {
      write, "None of the file names contained a parseable zone. Please use the zone= option.";
      return;
    } else if(nallof(zones)) {
      w = where(zones == 0)
      write, "The following file names did not contain a parseable zone and will be skipped.\n (Consider using zone= to avoid this.)";
      write, format=" - %s\n", file_tail(files(w));
      write, "";
      files = files(w);
    }
    zones = [];
  }

  if(remove_buffers) {
    file_tiles = extract_tile(file_tail(files));
    w = where(!file_tiles);
    if(numberof(w)) {
      write, "The following file names did not contain a parseable tile name. They will be\n retiled, but they cannot have any buffers removed; remove_buffers=1 will be\n ignored for these files.";
      write, format=" - %s\n", file_tail(files(w));
      write, "";
    }
    file_tiles = [];
  }

  makeflow_fn = file_join(scandir, "retile_scan.makeflow");

  options = save(string(0), [], remove_buffers, mode, scheme, dtlength,
    dtprefix, qqprefix, buffer);
  if(zone) save, options, zone;
  if(force_zone) save, options, force_zone;
  if(split_days) save, options, split_days, day_shift;

  scans = file_join(scandir, swrite(format="scan_%04d.pbd", indgen(nfiles)));

  conf = save();
  for(i = 1; i <= nfiles; i++) {
    save, conf, string(0), save(
      input=files(i),
      output=scans(i),
      command="job_retile_scan",
      options=obj_merge(options, save(
        "infile", files(i),
        "outfile", scans(i)
      ))
    );
  }

  write, "Scanning input to determine output...";
  makeflow_run, conf, makeflow_fn;
}

/* STEP TWO: Collate scan data ************************************************/

func _batch_retile_collate_wanted(wanted, x, y, zone, scheme) {
/* DOCUMENT _batch_retile_collate_wanted
  Helper function. For each tile, sets:
    wanted(tile) = 1
*/
  tiles = utm2tile_names(x, y, zone, scheme.type, dtlength=scheme.dtlength,
    dtprefix=scheme.dtprefix, qqprefix=scheme.qqprefix);
  ntiles = numberof(tiles);
  for(i = 1; i <= ntiles; i++) save, wanted, tiles(i), 1;
}

func _batch_retile_collate_coverage_helper(coverage, fn, x, y, zone, scheme) {
/* DOCUMENT _batch_retile_collate_coverage_helper
  Helper function. For each file+tile for a given buffer shift, sets:
    coverage(tile, fn) = 1
*/
  tiles = utm2tile_names(x, y, zone, scheme.type, dtlength=scheme.dtlength,
    dtprefix=scheme.dtprefix, qqprefix=scheme.qqprefix);
  ntiles = numberof(tiles);
  for(i = 1; i <= ntiles; i++) obj_hier_save, coverage, tiles(i), fn, 1;
}

func _batch_retile_collate_coverage(coverage, fn, x, y, counts, zone, scheme, buffer) {
/* DOCUMENT _batch_retile_collate_coverage
  Helper function. For each file+tile, sets:
    coverage(tile, fn) = counts
*/
  if(buffer) {
    tiles = array(pointer, 3, 3);
    for(dx = -1; dx <= 1; dx++) {
      for(dy = -1; dy <= 1; dy++) {
        tiles(dx+2,dy+2) = &utm2tile_names(x + dx * buffer, y + dy * buffer,
          zone, scheme.type, dtlength=scheme.dtlength,
          dtprefix=scheme.dtprefix, qqprefix=scheme.qqprefix);
      }
    }
    tiles = merge_pointers(tiles(*));
  } else {
    tiles = utm2tile_names(x, y, zone, scheme.type, dtlength=scheme.dtlength,
      dtprefix=scheme.dtprefix, qqprefix=scheme.qqprefix);
  }
  tiles = set_remove_duplicates(tiles);

  ntiles = numberof(tiles);
  for(i = 1; i <= ntiles; i++) {
    idx = extract_for_tile(x, y, zone, tiles(i), buffer=buffer)
    obj_hier_save, coverage, tiles(i), fn, counts(idx)(sum);
  }
}

func batch_retile_collate(&wanted, &coverage, scandir=, split_days=, scheme=, opts=) {
  _batch_retile_defaults, scandir, split_days, scheme, opts;
  local x, y, counts;

  wanted = save();
  coverage = save();

  scans = find(scandir, searchstr="scan_*.pbd");
  nscans = numberof(scans);

  for(i = 1; i <= nscans; i++) {
    scan = pbd2obj(scans(i));

    if(split_days) {
      for(j = 1; j <= numberof(scan.dates); j++) {
        date = scan.dates(j);
        key = swrite(format="date_coverage_%d", j);
        data2xyz, scan(noop(key)), x, y, counts;

        if(!wanted(*,date)) save, wanted, noop(date), save();
        _batch_retile_collate_wanted, wanted(noop(date)), x, y, scan.zone,
          scheme;

        if(!coverage(*,date)) save, coverage, noop(date), save();
        _batch_retile_collate_coverage, coverage(noop(date)), scan.fn, x, y,
          counts, scan.zone, scheme, opts.buffer;
      }
    } else {
      data2xyz, scan.coverage, x, y, counts;
      _batch_retile_collate_wanted, wanted, x, y, scan.zone, scheme;
      _batch_retile_collate_coverage, coverage, scan.fn, x, y, counts,
        scan.zone, scheme, opts.buffer;
    }
  }
}

/* STEP THREE: Generate tiled output ******************************************/

func _batch_retile_assemble(opts=, infiles=, outfile=, vname=, tile=, mode=,
remove_buffers=, buffer=, zone=, force_zone=, uniq=, date=, day_shift=,
prealloc=) {
/* DOCUMENT _batch_retile_assemble
  Worker function for batch_retile. This generates the output file for a single
  tile and is called by the job command.

  Parameters:
    infiles= The PBD files to load for input.
    outfile= The PBD file to create with output.
    vname= The variable name to use for output.
    tile= The tile name for this output.
  Other parameters are as defined for batch_retile.
*/
  restore_if_exists, opts, infiles, outfile, vname, tile, mode, remove_buffers,
    buffer, zone, force_zone, uniq, date, day_shift, prealloc;

  filter = dlfilter_tile(tile, mode=mode, buffer=buffer, zone=zone, dataonly=1);

  if(date) {
    filter = dlfilter_date(date, day_shift=day_shift, prev=filter);
  }

  dirload, files=infiles, outfile=outfile, outvname=vname, skip=1, soesort=1,
    remove_buffers=remove_buffers, force_zone=force_zone, uniq=uniq, verbose=0,
    filter=filter, prealloc=prealloc;
}

func _batch_retile_assemble_build_jobs(conf, wanted, coverage, options, opts, date) {
/* DOCUMENT _batch_retile_assemble_build_jobs
  Helper function for batch_retile_assemble. This adds jobs to conf for the
  given data.

  Parameters:
    conf: The conf object to store jobs to.
    wanted: Array of tiles to create files for.
    coverage: Coverage data.
    options: A core set of options to use for each job.
    opts: The options passed to the parent function.
    date: The date to generate files for; optional.
*/
  scheme = opts.scheme;

  if(date) {
    options = obj_merge(options, save(date));
    date = regsub("-", date, "", all=1);
  }

  nwanted = numberof(wanted);
  for(i = 1; i <= nwanted; i++) {
    tile = wanted(i);
    tile_zone = long(tile2uz(tile));

    vname = (scheme.type == "qq") ? tile : extract_dt(tile);

    outpath = opts.outdir;
    if(opts.split_zones)
      outpath = file_join(outpath, swrite(format="zone_%d", tile_zone));
    if(scheme.path != "-")
      outpath = file_join(outpath, tile_tiered_path(tile, scheme));

    infiles = coverage(noop(tile), *, );
    prealloc = 0;
    for(j = 1; j <= numberof(infiles); j++) {
      prealloc += coverage(noop(tile), infiles(j));
    }

    outfile = file_join(outpath, tile);
    if(date) outfile += "_" + date;
    if(opts.file_suffix) outfile += opts.file_suffix;
    append_if_needed, outfile, ".pbd";

    if(date) vname += "_" + date;
    if(opts.vname_suffix) vname += opts.vname_suffix;

    if(opts.update) {
      if(file_exists(outfile)) continue;
    } else {
      remove, outfile;
    }

    save, conf, string(0), save(
      input=infiles,
      output=outfile,
      command="job_retile_assemble",
      options=obj_merge(options, save(
        tile,
        infiles,
        outfile,
        vname,
        prealloc
      ))
    );
  }
}

func batch_retile_assemble(wanted, coverage, outdir=, scheme=, flat=,
remove_buffers=, mode=, buffer=, uniq=, zone=, force_zone=, split_zones=,
split_days=, day_shift=, dtlength=, dtprefix=, file_suffix=, vname_suffix=,
update=, opts=) {
  _batch_retile_defaults, outdir, scheme, flat, remove_buffers, mode, buffer,
    uniq, zone, force_zone, split_zones, split_days, day_shift, dtlength,
    dtprefix, file_suffix, vname_suffix, update, opts;

  options = save(string(0), [], remove_buffers, mode, buffer, uniq);
  if(!is_void(zone)) save, options, zone;
  if(force_zone) save, options, force_zone;
  if(split_days) save, options, day_shift;

  prepend_if_needed, file_suffix, "_";
  prepend_if_needed, vname_suffix, "_";

  conf = save();

  if(split_days) {
    for(i = 1; i <= wanted(*); i++) {
      date = wanted(*,i);
      _batch_retile_assemble_build_jobs, conf, wanted(noop(i), *,),
        coverage(noop(date)), options, opts, wanted(*,i);
    }
  } else {
    _batch_retile_assemble_build_jobs, conf, wanted(*,), coverage, options, opts;
  }

  write, "Generating output...";
  makeflow_run, conf;
}

/* Public entry point: batch_retile *******************************************/

func batch_retile(srcdir, outdir=, scheme=, mode=, searchstr=, update=,
file_suffix=, vname_suffix=, suffix=, remove_buffers=, buffer=, uniq=, zone=,
flat=, split_zones=, split_days=, day_shift=, scandir=, scanonly=, scanresume=)
{
/* DOCUMENT batch_retile, srcdir, outdir=, scheme=, mode=, searchstr=, update=,
  file_suffix=, vname_suffix=, suffix=, remove_buffers=, buffer=, uniq=, zone=,
   flat=, split_zones=, split_days=, day_shift=, scandir=, scanonly=,
  scanresume=

  Loads the data in srcdir and (re)partitions it into tiles, which are created
  in outdir.

  Parameter:
    srcdir: The directory where the source data is located.

  Options:
    outdir= Output directory. If omitted, output will go in srcdir.
    scheme= Tiling scheme. See tile_scheme for details.
        scheme="it/dt long prefix"    Tiered 10km/2km structure (default)
    mode= Mode of data. Valid values include:
        mode="fs"         First surface (default)
        mode="be"         Bare earth
        mode="ba"         Bathy
    searchstr= Search string to use when locating input data. Example:
        searchstr="*.pbd"    (default)
    update= Turns on update mode, which skips existing files.
        update=0          Existing files are deleted and re-created
        update=1          Existing files are skipped
    file_suffix= Suffix to append to file names when creating them. If your
      suffix does not end in .pbd, it will be auto-appended. If it does not
      start with an underscore, it will be added. Examples:
        file_suffix=[]          Default is no suffix
        file_suffix="w84_fs"
        file_suffix="n88_g09_merged_be.pbd"
    vname_suffix= Suffix to append to tile name when creating the merged
      variable name. f it does not start with an underscore, it will be added.
      Examples:
        vname_suffix=[]         Default is no suffix
        vname_suffix="_merged"
        vname_suffix="_v_merged"
    suffix= Shortcut to specify the same value for both file_suffix and
      vname_suffix. For example:
        suffix="_merged"  ==  file_suffix="_merged", vname_suffix="_merged"
      If you also specify vname_suffix or file_suffix, then those will take
      priority over suffix.
    remove_buffers= Specifies whether buffers should be removed from
      already-tiled data. Removing the buffers is important when data has been
      manually editted; otherwise, removed points will be re-added from
      adjacent tiles' buffers.
        remove_buffers=0    Default: use all data
        remove_buffers=1    Remove buffers
    buffer= Buffer region to extent tile by.
        buffer=100          Add 100m buffer (default)
        buffer=0            No buffer
    uniq= Specifies whether to restrict to unique points. This can be a
      boolean, or it can be a string to pass through to uniq_data's optstr=.
        uniq=1              Discard points with matching soe values (default)
        uniq=0              Keep all points, even duplicates
        uniq="forcexy=1"    Use uniq_data with forcexy=1.
    zone= By default, the zone will be determined from the file's name. If no
      parseable tile can be determined, the file will be ignored. You can
      specify a zone to use for all files with this option.
        zone=[]             Auto-detect, default
        zone=17             All data assumed to be in zone 17
        zone=-1             After loading, use data.zone (for ATM data)
    flat= By default, files will be created in a directory structure. This
      allows you to collapse them into a single directory.
        flat=0      Create files in per-tile directories. (default)
        flat=1      Put files all directly into outdir.
    split_zones= Specifies whether an extra directory level should be created
      for each zone. This is primarly useful with multizone data, and is
      especially helpful with quarter-quad data.
        split_zones=0       Do not split by zone (default for most schemes)
        split_zones=1       Split by zone (default for qq scheme)
    split_days= Enables splitting the data by day. If enabled, all per-day
      files for a tile will be kept in the same tile directory but will be
      differentiated by date in the filename.
        split_days=0        Do not split by day, default
        split_days=1        Split by day, adding _YYYYMMDD to filename.
    day_shift= Specifies an offset in seconds to apply to the soes when
      determining YYYYMMDD values for split_days. This can be used to shift
      time periods into the previous or next day when surveys are flown close
      to UTC midnight. The value is added to oe only for determining the date;
      the actual soe values in the data remain unchanged.
        day_shift=0         No shift; UTC time (default)
        day_shift=-14400    -4 hours; EDT time
        day_shift=-18000    -5 hours; EST and CDT time
        day_shift=-21600    -6 hours; CST and MDT time
        day_shift=-25200    -7 hours; MST and PDT time
        day_shift=-28800    -8 hours; PST and AKDT time
        day_shift=-32400    -9 hours; AKST time
    scandir= This function uses a two-step process: first it scans the data to
      determine what tiles need to be created; then it actually goes through
      and creates those tiles (loading the relevant data for each tile).
      Normally, the files generated for the scan are removed after their data
      has been read. However, if you specify a path for scandir=, these files
      will be kept and the other scan options (scanonly= and scanresume=) can
      be used.
    scanonly= If scanonly=1, then ONLY the first step (scanning) is performed.
      No tiles are created. This is incompatible with scanresume=1.
    scanresume= If scanresume=1, then the scanning step is skipped and the scan
      data is read from scandir. This is incompatible with scanonly=1. Also,
      you must be sure to use the same values for the following options as you
      did when you generated the scan data: scheme=, mode=, searchstr=,
      remove_buffers=, buffer=, zone=, split_days=, day_shift=,
      dtlength=, dtprefix=, qqprefix=.
*/
  local opts;
  _batch_retile_defaults, opts, srcdir, outdir, scheme, mode, searchstr,
    update, file_suffix, vname_suffix, suffix, remove_buffers, buffer, uniq,
    zone, flat, split_zones, split_days, day_shift, scandir, scanonly,
    scanresume;

  scankeep = !is_void(scandir);
  if(scanonly && scanresume) {
    error, "can't use scanonly= and scanresume= together";
  }
  if(!scandir) {
    if(scanonly) error, "need to provide scandir= with scanonly=";
    if(scanresume) error, "need to provide scandir= with scanresume=";
  }

  if(scandir) {
    if(!scanresume) mkdirp, scandir;
  } else {
    scandir = mktempdir("batch_retile_scan");
  }
  save, opts, scandir;

  if(!scanresume) {
    batch_retile_scan, opts=opts;
    if(scanonly) return;
  }

  wanted = coverage = [];
  batch_retile_collate, wanted, coverage, opts=opts, scheme=scheme;
  if(!scankeep) remove_recursive, scandir;

  batch_retile_assemble, wanted, coverage, opts=opts;
}
