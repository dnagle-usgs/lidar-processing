require, "makeflow.i";

func mf_automerge_tiles(path, searchstr=, update=, makeflow_fn=, forcelocal=,
norun=) {
/* DOCUMENT mf_automerge_tiles, path, makeflow_fn, searchstr=, update=,
   makeflow_fn=, forcelocal=, norun=

  Specialized batch merging function for the initial merge of processed data.

  By default, it will find all files matching *_v.pbd and *_b.pbd. It will
  then merge everything it can. It makes distinctions between _v and _b, and
  it also makes distinctions between w84, n88, n88_g03, n88_g09, etc. Thus,
  it's safe to run on a directory containing both veg and bathy or both w84
  and n88; they won't all get mixed together inappropriately.

  If called as a subroutine, the jobs will be run with Makeflow. If called as a
  function, the configuration that would have been passed to Makeflow is
  returned instead.

  Parameters:
    path: The path to the directory.

  Options:
    searchstr= You can override the default search string if you're only
      interested in merging some of the available files. However, if your
      search string matches things that this function isn't designed to
      handle, it won't handle them. Examples:
        searchstr=["*_v.pbd", "*_b.pbd"]    Find all _v and _b files (default)
        searchstr="*_b.pbd"                 Find only _b files
        searchstr="*w84*_v.pbd"             Find only w84 _v files
      Note that searchstr= can be an array for this function, if need be.

    update= By default, existing files are overwritten. Using update=1 will
      skip them instead.
        update=0    Overwrite files if they exist
        update=1    Skip files if they exist

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    forcelocal= Forces local execution.
        forcelocal=0    Default

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow

  Output:
    This will create the merged files in the directory specified, alongside
    the input files.

    An example output filename is:
      t_e352000_n3006000_17_w84_b_merged.pbd
    The tile name, datum (w84, etc.), and type (v, b) will vary based on the
    files merged.

    An example vname is:
      e352_n3006_w84_b
    Again, the information will vary based on the files merged.
*/
  default, searchstr, ["*_v.pbd", "*_b.pbd"];
  default, update, 0;
  default, forcelocal, 0;

  // Locate files and split into dirs/tails
  files = find(path, glob=searchstr);
  dirs = file_dirname(files);
  tails = file_tail(files);

  // Extract tile names
  tiles = extract_tile(tails, dtlength="long", qqprefix=0);

  // Break up into _v/_b
  types = array(string, numberof(files));
  w = where(strglob("*_v.pbd", tails));
  if(numberof(w))
    types(w) = "v";
  w = where(strglob("*_b.pbd", tails));
  if(numberof(w))
    types(w) = "b";

  // Break up into w84, n88, etc.
  parsed = parse_datum(tails);
  datums = parsed(..,1);
  geoids = parsed(..,2);
  parsed = [];

  // Check for problems
  problem = strlen(tiles) == 0 | strlen(types) == 0 | strlen(datums) == 0;
  if(anyof(problem)) {
    w = where(problem);
    if(allof(problem)) {
      return;
    } else {
      w = where(!problem);
      files = files(w);
      tails = tails(w);
      tiles = tiles(w);
      datums = datums(w);
      geoids = geoids(w);
    }
  }

  // Calculate filename suffix
  suffixes = swrite(format="%s_%s_%s_merged.pbd", datums, geoids, types);
  suffixes = regsub("__*", suffixes, "_", all=1);

  // Calculate output filenames
  tokens = swrite(format="%s_%s", tiles, suffixes);
  tokens = regsub("__*", tokens, "_", all=1);
  outfiles = file_join(dirs, tokens);
  dirs = [];

  // Check for files that already exist
  exists = file_exists(outfiles);
  if(anyof(exists)) {
    w = where(exists);
    existout = set_remove_duplicates(outfiles(w));
    if(update) {
      if(allof(exists)) {
        return;
      } else {
        w = where(!exists);
        outfiles = outfiles(w);
        files = files(w);
        tiles = tiles(w);
        types = types(w);
        datums = datums(w);
        geoids = geoids(w);
        suffixes = suffixes(w);
      }
    } else {
      w = where(exists);
      for(i = 1; i <= numberof(w); i++)
        remove, outfiles(w(i));
    }
  }

  // Calculate variable names
  tiles = extract_tile(tiles, dtlength="short", qqprefix=1);
  // Lop off zone for 2k/10k tiles
  tiles = regsub("_[0-9]+$", tiles, "");
  vnames = swrite(format="%s_%s_%s", tiles, datums, types);
  tiles = datums = types = geoids = [];

  // Sort by output file name
  srt = sort(outfiles);
  files = files(srt);
  suffixes = suffixes(srt);
  outfiles = outfiles(srt);
  vnames = vnames(srt);
  srt = [];

  count = numberof(files);

  suffixes = set_remove_duplicates(suffixes);
  nsuf = numberof(suffixes);
  outuniq = numberof(set_remove_duplicates(outfiles));

  // Iterate through and load each file, saving whenever we're on the input
  // file for a given output file.
  conf = save();
  i = j = k = 1;
  while(i <= count) {
    while(j < count && outfiles(j+1) == outfiles(i))
      j++;
    save, conf, string(0), save(
      forcelocal=forcelocal,
      input=files(i:j),
      output=outfiles(i),
      command="job_dirload",
      options=save(
        string(0), [],
        "file-in", files(i:j),
        "file-out", outfiles(i),
        vname=vnames(i),
        uniq="0",
        skip="1"
      )
    );
    i = j = j + 1;
    k++;
  }

  if(!am_subroutine())
    return conf;

  makeflow, conf, makeflow_fn, interval=10, norun=norun;
}

func mf_batch_rcf(dir, searchstr=, merge=, files=, update=, mode=,
clean=, prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, meta=,
makeflow_fn=, forcelocal=, norun=) {
/* DOCUMENT new_batch_rcf, dir, searchstr=, merge=, files=, update=, mode=,
   clean=, prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, meta=,
   makeflow_fn=, forcelocal=, norun=

  This iterates over each file in a set of files and applies an RCF filter to
  its data.

  If called as a subroutine, the jobs will be run with Makeflow. If called as a
  function, the configuration that would have been passed to Makeflow is
  returned instead.

  Parameters:
    dir: The directory containing the files you wish to filter.

  Options:
    searchstr= The search string to use to locate the files you with to
      filter. Examples:
        searchstr="*.pbd"    (default)
        searchstr="*_v.pbd"
        searchstr="*n88*_v.pbd"

    merge= This is a special-case convenience setting that includes a call to
      batch_automerge_tiles. It can only be run if your search string ends
      with _v.pbd or _b.pbd. After running the merge, the search string will
      get updated to replace _v.pbd with _v_merged.pbd and _b.pbd with
      _b_merged.pbd. (So "*_v.pbd" becomes "*_v_merged.pbd", whereas
      "*w84*_v.pbd" becomes "*w84*_v_merged.pbd".) It is an error to use
      this setting with a search string that does not fit these
      requirements. Note that you CAN NOT "skip" the writing of merged files
      if you want to filter merged data. Settings:
        merge=0     Do not perform an automerge. (default)
        merge=1     Merge tiles together before filtering.

    files= Manually provides a list of files to filter. This will result in
      searchstr= being ignored and is not compatible with merge=1.

    update= Specifies that this is an update run and that existing files
      should be skipped. Settings:
        update=0    Overwrite output files if they exist.
        update=1    Skip output files if they exist.

    mode= Specifies which data mode to use for the data. Can be any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    clean= Specifies whether the data should be cleaned first using
      test_and_clean. Settings:
        clean=0     Do not clean the data.
        clean=1     Clean the data. (default)

    prefilter_min= Specifies a minimum value for the elevation values, in
      meters. Points below this value are discarded prior to filtering.

    prefilter_max= Specifies a maximum value for the elevation values, in
      meters. Points above this value are discarded prior to filtering.

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 700cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 200cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    meta= Specifies whether the filter parameters should be included in the
      output filename. Settings:
        meta=0   Do not include the filter parameters in the file name.
        meta=1   Include the filter parameters in the file name. (default)

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    forcelocal= Forces local execution.
        forcelocal=0    Default

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
*/
  default, searchstr, "*.pbd";
  default, update, 0;
  default, merge, 0;
  default, buf, 700;
  default, w, 200;
  default, n, 3;
  default, clean, 1;
  default, meta, 1;
  default, mode, "fs";
  default, rcfmode, "grcf";
  default, forcelocal, 0;

  t0 = array(double, 3);
  timer, t0;

  conf = save();

  if(merge) {
    if(!is_void(files))
      error, "You cannot use merge=1 if you are specifying files=."
    // We can ONLY merge if our searchstr ends with *_v.pbd or *_b.pbd.
    // If it does... then merge, and update our search string.
    if(strlen(searchstr) < 7)
      error, "Incompatible setting for searchstr= with merge=1. See \
        documentation.";
    sstail = strpart(searchstr, -6:);
    if(sstail == "*_v.pbd") {
      conf = mf_automerge_tiles(dir, searchstr=searchstr, update=update);
    } else if(sstail == "*_b.pbd") {
      conf = mf_automerge_tiles(dir, searchstr=searchstr, update=update);
    } else {
      error, "Invalid setting for searchstr= with merge=1. See \
        documentation."
    }

    files = array(string, conf(*));
    for(i = 1; i <= conf(*); i++)
      files(i) = conf(noop(i)).output;
  }

  if(is_void(files))
    files = find(dir, glob=searchstr);
  count = numberof(files);

  if(!count) {
    return;
  }

  // Variable name -- same as input, but add _rcf (or _grcf, etc.)
  // File name -- same as input, but lop off extension and add rcf settings
  vname = [];
  for(i = 1; i <= count; i++) {
    file_in = files(i);
    file_out = file_rootname(file_in);
    // _fs, _be, _ba
    file_out += "_" + mode;
    // _b700_w50_n3
    if(meta)
      file_out += swrite(format="_b%d_w%d_n%d", buf, w, n);
    // _grcf, _ircf, _rcf
    file_out += "_" + rcfmode;
    // _mf
    // .pbd
    file_out += ".pbd";

    if(file_exists(file_out)) {
      if(update) {
        continue;
      } else {
        remove, file_out;
      }
    }

    options=save(
      string(0), [],
      "file-in", file_in,
      "file-out", file_out,
      mode=mode,
      clean=swrite(format="%d", clean),
      rcfmode=rcfmode,
      buf=swrite(format="%d", buf),
      w=swrite(format="%d", w),
      n=swrite(format="%d", n)
    );
    if(!is_void(prefilter_min))
      save, options, "prefilter-min", prefilter_min;
    if(!is_void(prefilter_max))
      save, options, "prefilter-max", prefilter_max;

    save, conf, string(0), save(
      forcelocal=forcelocal,
      input=file_in,
      output=file_out,
      command="job_rcf_eaarl",
      options=options
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow, conf, makeflow_fn, interval=15, norun=norun;

  timer_finished, t0;
}
