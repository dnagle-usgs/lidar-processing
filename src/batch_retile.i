/* batch_retile has three phases:
      1. Scan the source data to derive tile/coverage information
      2. Collate the tile/coverage information
      3. Generate tiled output files
*/

/* Shared helper functions ****************************************************/

func _batch_retile_defaults(args) {
  // Scan to retrieve fields that are refered to in calculating values.
  ref = save();
  wanted = ["srcdir", "suffix", "zone", "shorten", "scheme", "dtprefix",
    "qqprefix", "scandir"];
  optsidx = 0;
  for(i = 1; i <= args(0); i++) {
    if(anyof(args(-,i) == wanted)) save, ref, args(-,i), args(i);
    if(args(-,i) == "opts") optsidx = i;
  }

  opts = [];
  if(optsidx) opts = args(optsidx);
  if(is_void(opts)) opts = save();

  // Derive defaults
  defaults = save(
    // srcdir
    outdir=ref.srcdir,
    scheme="itdt",
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
    // shorten
    flat=0,
    split_zones=(ref.scheme == "qq"),
    split_days=0,
    day_shift=0,
    dtlength=(ref.shorten ? "short" : "long"),
    // dtprefix
    // qqprefix
    // scandir
    scanresume=0,
    scanonly=0);

  // Populate opts with defaults for whatever is missing or void
  for(i = 1; i <= defaults(*); i++) {
    key = defaults(*,i);
    if(opts(*,key) && !is_void(opts(noop(key)))) continue;
    save, opts, noop(key), defaults(noop(key));
  }

  // Update opts to reflect values passed directly
  for(i = 1; i <= args(0); i++) {
    if(is_void(args(i)) || args(-,i) == "opts") continue;
    save, opts, args(-,i), args(i);
  }

  // Special case: update scheme.
  aliases = save("10k2k", "itdt", "2k", "dt", "10k", "it");
  if(aliases(*,opts.scheme)) save, opts, scheme=aliases(opts.scheme);

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

func _batch_retile_scan(opts=, infile=, outfile=, remove_buffers=, zone=,
mode=, force_zone=, scheme=, dtlength=, dtprefix=, qqprefix=, buffer=,
split_days=, day_shift=) {
/* DOCUMENT _batch_retile_scan
  Worker function for batch_retile. This scans a single PBD file and determines
  what output it contributes to. This information is summarized by three
  variables:
    - wanted, the tiles that would have data within their tile bounds from this
      file
    - coverage, the tiles that would have data within their tile+buffer bounds
      from this file
    - dates, the dates for each of the tiles found in wanted (optional)

  In order to assist with debugging, this function can return the result as an
  oxy group. In normal use though it saves its output to a PBD file.

  Parameters:
    infile= PBD file to scan.
    outfile= PBD file to create with output.
  Other parameters are as defined for batch_retile.
*/
// This function uses "goto END" to avoid having the same cleanup & return code
// redundantly placed multiple times in the function.

  local e, n, testlat, testlon, testz, wanted, dates, coverage;

  _batch_retile_defaults, opts, infile, outfile, remove_buffers, zone, mode,
    force_zone, scheme, dtlength, dtprefix, qqprefix, buffer, split_days,
    day_shift;

  if(scheme == "itdt") scheme = "dt";

  // Load data
  data = pbd_load(infile);
  if(!numberof(data)) goto END;

  filetile = extract_tile(file_tail(infile));

  // Determine zone of data
  if(!zone) {
    datazone = long(tile2uz(filetile));
  } else if(zone < 0) {
    datazone = data.zone;
  } else {
    datazone = zone;
  }

  // If we could parse a tile name and remove_buffers is enabled, throw away
  // buffer points
  if(remove_buffers && filetile) {
    data2xyz, data, e, n, mode=mode;
    w = extract_match_tile(e, n, datazone, filetile);
    if(!numberof(w)) goto END;
    data = data(w);
    if(zone < 0) datazone = data.zone;
  }

  // Extract coordinates
  data2xyz, data, e, n, mode=mode;

  // Rezone if needed
  if(force_zone) {
    rezone_utm, n, e, datazone, force_zone;
    datazone = force_zone;
  }

  // Determine the "wanted" tiles for this data: tiles where these points would
  // fall within the tile extent.
  wanted = utm2tile_names(e, n, datazone, scheme, dtlength=dtlength,
    dtprefix=dtprefix, qqprefix=qqprefix);

  // If split_days is enabled, figure out per-tile dates.
  if(split_days) {
    wcount = numberof(wanted);
    wanted_expand = array(pointer, wcount);
    dates = array(pointer, wcount);
    dates_full = soe2date(data.soe + day_shift);
    for(i = 1; i <= wcount; i++) {
      w = extract_for_tile(e, n, datazone, wanted(i), buffer=buffer);
      dates(i) = &set_remove_duplicates(dates_full(w));
      wanted_expand(i) = &array(wanted(i), numberof(*dates(i)));
    }
    wanted = merge_pointers(wanted_expand);
    wanted_expand = [];
    dates = merge_pointers(dates);
  }
  data = [];

  // Next, determine "coverage" tiles for this data: tiles where this points
  // would fall within the tile+buffer extent.

  // Zones with data
  zones = set_remove_duplicates(datazone);

  // Check to see if we're near a zone boundary. If so, figure out the adjacent
  // zones. This is needed to ensure that tiles at the zone boundary end up
  // fully populated.
  if(!force_zone) {
    // Use 10k meters, which is big enough to accommodate any tiling scheme
    testn = [n(min),n(max)]([1,2,2,1]);
    teste = [e(min),e(max)]([1,1,2,2]);
    buffer_scatter_xy, 10000, teste, testn;
    utm2ll, testn, teste, datazone, testlon, testlat;
    ll2utm, testlat, testlon, testn, teste, testz;

    grow, zones, set_difference(testz, zones);

    testn = teste = testlat = testlon = testz = [];
  }

  if(buffer) {
    buffe = buffn = 0;
    buffer_scatter_xy, buffer, buffe, buffn;
    bcount = 9;
  } else {
    buffe = buffn = [0];
    bcount = 1;
  }

  zcount = numberof(zones);

  coverage = array(pointer, zcount, bcount);

  for(zi = 1; zi <= zcount; zi++) {
    rezone_utm, n, e, datazone, zones(zi);
    datazone = zones(zi);

    for(bi = 1; bi <= bcount; bi++) {
      coverage(zi,bi) = &utm2tile_names(e+buffe(bi), n+buffn(bi), datazone,
        scheme, dtlength=dtlength, dtprefix=dtprefix, qqprefix=qqprefix);
    }
  }
  coverage = set_remove_duplicates(merge_pointers(coverage(*)));

END:
  result = save(wanted, dates, coverage, fn=infile);
  if(outfile) obj2pbd, result, outfile;
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

func batch_retile_collate(&wanted, &coverage, scandir=, split_days=, opts=) {
  _batch_retile_defaults, scandir, split_days, opts;

  wanted = save();
  coverage = save();

  scans = find(scandir, searchstr="scan_*.pbd");

  for(i = 1; i <= numberof(scans); i++) {
    scan = pbd2obj(scans(i));

    for(j = 1; j <= numberof(scan.wanted); j++) {
      if(split_days) {
        obj_hier_save, wanted, scan.wanted(j), scan.dates(j), 1;
      } else {
        save, wanted, scan.wanted(j), 1;
      }
    }

    for(j = 1; j <= numberof(scan.coverage); j++) {
      obj_hier_save, coverage, scan.coverage(j), scan.fn, 1;
    }
  }
}

/* STEP THREE: Generate tiled output ******************************************/

func _batch_retile_assemble(opts=, infiles=, outfile=, vname=, tile=, mode=,
remove_buffers=, buffer=, zone=, force_zone=, uniq=, date=, day_shift=) {
/* DOCUMENT _batch_retile_assemble
  Worker function for batch_retile. This generates the output file for a single
  tile.

  Parameters:
    infiles= The PBD files to load for input.
    outfile= The PBD file to create with output.
    vname= The variable name to use for output.
    tile= The tile name for this output.
  Other parameters are as defined for batch_retile.
*/
  restore_if_exists, opts, infiles, outfile, vname, tile, mode, remove_buffers,
    buffer, zone, force_zone, uniq, date, day_shift;

  filter = dlfilter_tile(tile, mode=mode, buffer=buffer, zone=zone, dataonly=1);

  if(date) {
    filter = dlfilter_date(date, day_shift=day_shift, prev=filter);
  }

  dirload, files=infiles, outfile=outfile, outvname=vname, skip=1, soesort=1,
    remove_buffers=remove_buffers, force_zone=force_zone, uniq=uniq, verbose=0,
    filter=filter;
}

func batch_retile_assemble(wanted, coverage, outpath=, scheme=, flat=,
remove_buffers=, mode=, buffer=, uniq=, zone=, force_zone=, split_zones=,
split_days=, day_shift=, dtlength=, dtprefix=, file_suffix=, vname_suffix=,
update=, opts=) {
  _batch_retile_defaults, outpath, scheme, flat, remove_buffers, mode, buffer,
    uniq, zone, force_zone, split_zones, split_days, day_shift, dtlength,
    dtprefix, file_suffix, vname_suffix, update, opts;

  options = save(string(0), [], remove_buffers, mode, buffer, uniq);
  if(!is_void(zone)) save, options, zone;
  if(force_zone) save, options, force_zone;
  if(split_days) save, options, day_shift;

  bilevel = 0;
  if(scheme == "itdt") {
    scheme = "dt";
    bilevel = 1;
  }

  prepend_if_needed, file_suffix, "_";
  prepend_if_needed, vname_suffix, "_";

  conf = save();
  count = wanted(*);
  for(i = 1; i <= count; i++) {
    tile = wanted(*,i);
    tile_zone = long(tile2uz(tile));

    vname = (scheme == "qq") ? tile : extract_dt(tile);

    outpath = outdir;
    if(split_zones)
      outpath = file_join(outpath, swrite(format="zone_%d", tile_zone));
    if(!flat) {
      if(bilevel)
        outpath = file_join(outpath, dt2it(tile, dtlength=dtlength,
          dtprefix=dtprefix));
      outpath = file_join(outpath, tile);
    }

    infiles = coverage(noop(tile), *, );

    if(split_days) {
      dates = wanted(noop(i), *,);
      cleandates = regsub("-", dates, "", all=1);

      outfiles = file_join(outpath, tile) + "_" + cleandates;
      if(file_suffix) outfiles += file_suffix;
      append_if_needed, outfiles, ".pbd";

      vnames = vname + "_" + cleandates;
      if(vname_suffix) vnames += vname_suffix;

      if(update) {
        w = where(!file_exists(outfiles));
        if(!numberof(w)) continue;
        outfiles = outfiles(w);
        vnames = vnames(w);
        dates = dates(w);
      } else {
        for(j = 1; j <= numberof(outfiles); j++)
          remove, outfiles(j);
      }

      for(j = 1; j <= numberof(dates); j++) {
        save, conf, string(0), save(
            input=infiles,
            output=outfiles(j),
            command="job_retile_assemble",
            options=obj_merge(options, save(
                tile,
                infiles,
                outfile=outfiles(j),
                vname=vnames(j),
                date=dates(j)
                ))
            );
      }
    } else {
      outfile = file_join(outpath, tile);
      if(file_suffix) outfile += file_suffix;
      append_if_needed, outfile, ".pbd";
      if(vname_suffix) vname += vname_suffix;

      if(update) {
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
          vname
        ))
      );
    }
  }

  write, "";
  write, "Generating output...";
  makeflow_run, conf;
}

/* Public entry point: batch_retile *******************************************/

func batch_retile(srcdir, outdir=, scheme=, mode=, searchstr=, update=,
file_suffix=, vname_suffix=, suffix=, remove_buffers=, buffer=, uniq=, zone=,
shorten=, flat=, split_zones=, split_days=, day_shift=, dtlength=, dtprefix=,
qqprefix=, scandir=, scanonly=, scanresume=) {
/* DOCUMENT batch_retile, srcdir, outdir=, scheme=, mode=, searchstr=, update=,
  file_suffix=, vname_suffix=, suffix=, remove_buffers=, buffer=, uniq=, zone=,
  shorten=, flat=, split_zones=, split_days=, day_shift=, dtlength=, dtprefix=,
  qqprefix=, scandir=, scanonly=, scanresume=

  Loads the data in srcdir and (re)partitions it into tiles, which are created
  in outdir.

  Parameter:
    srcdir: The directory where the source data is located.

  Options:
    outdir= Output directory. If omitted, output will go in srcdir.
    scheme= Partioning scheme to use. Valid values:
        scheme="itdt"     Tiered 10km/2km structure (default)
        scheme="dt"       2km structure
        scheme="it"       10km structure
        scheme="qq"       Quarter quad structure
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
    shorten= Shorthand for dtlength option.
        shorten=0   ->  dtlength="long"   (default)
        shorten=1   ->  dtlength="short"
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
    dtlength= Specifies whether to use short or long form for data tile (and
      related) schemes. By default, this is set based on shorten=.
    dtprefix= Specifies whether to include the type prefix for data tile (and
      related) schemes. By default, this is set based on scheme+dtlength.
    qqprefix= Specifies whether to prepend "qq" to quarter quad names. This is
      disabled by default.
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
      remove_buffers=, buffer=, zone=, shorten=, split_days=, day_shift=,
      dtlength=, dtprefix=, qqprefix=.
*/
  local opts;
  _batch_retile_defaults, opts, srcdir, outdir, scheme, mode, searchstr,
    update, file_suffix, vname_suffix, suffix, remove_buffers, buffer, uniq,
    zone, shorten, flat, split_zones, split_days, day_shift, dtlength,
    dtprefix, qqprefix, scandir, scanonly, scanresume;

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
  batch_retile_collate, wanted, coverage, opts=opts;
  if(!scankeep) remove_recursive, scandir;

  batch_retile_assemble, wanted, coverage, opts=opts;
}
