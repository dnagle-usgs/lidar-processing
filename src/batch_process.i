// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "logger.i";

// a simple routine to display a list of file names for debugging.
func show_files(files=, str=) {
  n = numberof(files);
  for ( i=1; i<=n; ++i ) {
   write, format="FILES(%s): %2d/%2d: %s\n", str, i, n, files(i);
  }
}

func batch_test_rcf(dir, mode, datum=, testpbd=, testedf=, buf=, w=, no_rcf=, re_rcf=) {
/* DOCUMENT batch_test_rcf
  Goes through dir and determines if all the RCF files have been created.
  If not, it writes a  list of the missing tiles into batch_rcf_missin.txt.
  Set keywords to narrow the test to RCF'd files of certain datum, buf, w,
  or no_rcf.
  Specify wheather to search for pbd or edf with testpbd=/testedf=.
  If neither are set testpbd is the default
*/

  missingdirs=[];
//generate list of *.pbd files and data tile directories
  if ((!testpbd) && (!testedf)) testpbd=1;
  s = array(string, 100000);
  ss = ["*.pbd"];
  scmd = swrite(format = "find %s -name '%s'",dir, ss);
  fp = 1; lp = 0;
  for (i=1; i<=numberof(scmd); i++) {
    f=popen(scmd(i), 0);
    n = read(f,format="%s", s );
    close, f;
    lp = lp + n;
    if (n) fn_all = s(fp:lp);
    fp = fp + n;
  }
  t=*pointer(fn_all(1));
  nn=where(t=='_');
  dtiles = set_remove_duplicates(strpart(fn_all, 1:nn(-5)-2));
  dbool = array(short, numberof(dtiles),2);

//go through each directory and determine if the rcf file exists
  if ((mode == 1) || (mode == 3)) mchar = "v";
  if (mode == 2) mchar = "b";
  if (buf) sbuf = swrite(format="%d",buf);
  if (!buf) sbuf="";
  if (w) sw = swrite(format="%d",w);
  if (!w) sw ="";
  if (no_rcf) sno_rcf = swrite(format="%d",no_rcf);
  if (!no_rcf) sno_rcf="";
  if (!datum) datum="";
  if (testpbd) {
    for (j=1;j<=numberof(dtiles);j++) {
      fn_all = [];
      s = array(string, 100000);
      scmd = swrite(format = "find %s -name '*%s*%s*%s*%s*%s*rcf.pbd'", dtiles(j), datum, mchar, sbuf, sw, sno_rcf);
      fp = 1; lp=0;
      for (i=1; i<=numberof(scmd); i++) {
        f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) fn_all = s(fp:lp);
        fp = fp + n;
      }
      if (!is_void(fn_all)) dbool(j,1) = 1;
    }
  }
  if (testedf) {
    for (j=1;j<=numberof(dtiles);j++) {
      fn_all = [];
      s = array(string, 100000);
      scmd = swrite(format = "find %s -name '*%s*%s*%s*%s*%s*rcf.edf'", dtiles(j), datum, mchar, sbuf, sw, sno_rcf);
      fp = 1; lp=0;
      for (i=1; i<=numberof(scmd); i++) {
        f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) fn_all = s(fp:lp);
        fp = fp + n;
      }
      if (!is_void(fn_all)) dbool(j,2) = 1;
    }
  }
  if (testpbd) missingpbd = where(dbool(,1) == 0);
  if (testedf) missingedf = where(dbool(,2) == 0);
  if ((!is_array(missingpbd)) && (!is_array(missingedf))) {write, "No missing files!"; return;}
  if (is_array(missingpbd)) {
    write, "PBD files missing from directory:"
    for (i=1;i<=numberof(missingpbd);i++) {
      write, dtiles(missingpbd(i));
      grow, missingdirs, dtiles(missingpbd(i));
    }
  }
  if (is_array(missingedf)) {
    write, "EDF files missing from directory:"
    for (i=1;i<=numberof(missingedf);i++) {
      write, dtiles(missingedf(i))
    }
  }
  write, "Some PBD or EDF files were not created! Check above!!";
  if (re_rcf) {
    write, "re-filtering missing directories...";
    if (!buf || !w || !mode) {write, "You must specify buf, w, and mode in order to re-filter"; return missingdirs;}
    if ((buf=="") || (w=="") || !mode) {write, "You must specify buf, w, and mode in order to re-filter"; return missingdirs;}
    fmode = mode;
    if (mode == 1) fmode = 3;
    if (!no_rcf) (no_rcf=3);
    for (i=1;i<=numberof(missingdirs);i++) {
      batch_rcf, missingdirs(i), buf=buf, w=w, no_rcf=no_rcf, mode=fmode, meta=1, merge=1, readpbd=1, writeedf=1, writepbd=1, dorcf=1, datum="w84", fsmode=(mode == 1) || (mode == 3);
    }
  }

  return missingdirs;
}

func batch_ddf(eaarl, cell=, minnum=) {
// Data density filter
  if (!minnum) minnum = 3;
  if (!cell) cell = 5;
  finaldata = [];
  mine = floor(eaarl.east(min)/5)*5/100.0;
  maxe =  ceil(eaarl.east(max)/5)*5/100.0;
  minn = floor(eaarl.north(min)/5)*5/100.0;
  maxn =  ceil(eaarl.north(max)/5)*5/100.0;
  for (i=mine;i<=maxe-cell;i+=cell) {
    swrite(format="Starting column: %i", int(i));
    coldata = data_box(eaarl.east/100.0, eaarl.north/100., i, i+cell, minn, maxn);
    if (numberof(coldata) <= minnum) {
      write, "No data in column!";
      continue;
    }
    for (j=minn;j<=maxn-cell;j+=cell) {
      boxdata = data_box(eaarl.east(coldata)/100.0, eaarl.north(coldata)/100., i, i+cell, j, j+cell);
      if (numberof(boxdata) <= 3) continue;
      grow, finaldata, coldata(boxdata);
    }
  }
  return finaldata;
  end
}

func batch_automerge_tiles(path, searchstr=, verbose=, update=, uniq=) {
/* DOCUMENT batch_automerge_tiles(path, searchstr=, verbose=, update=, uniq=)
  Specialized batch merging function for the initial merge of processed data.
  By default, it will find all files matching *_v.pbd, *_b.pbd, and *_f.pbd. It
  will then merge everything it can. It makes distinctions between _v, _b, and
  _b, and it also makes distinctions between w84, n88, n88_g03, n88_g09, etc.
  Thus, it's safe to run on a directory containing both veg and bathy or both
  w84 and n88; they won't all get mixed together inappropriately.

  Parameters:
    path: The path to the directory.

  Options:
    searchstr= You can override the default search string if you're only
      interested in merging some of the available files. However, if your
      search string matches things that this function isn't designed to
      handle, it won't handle them. Examples:
        searchstr=["*_v.pbd", "*_b.pbd", "*_f.pbd"]
                                            Find all _v/_b/_f files (default)
        searchstr="*_b.pbd"                 Find only _b files
        searchstr="*w84*_v.pbd"             Find only w84 _v files
      Note that searchstr= can be an array for this function.

    verbose= Specifies how chatty the function should be. Settings:
        verbose=0      Be silent
        verbose=1      Provide progress and information to the screen

    update= By default, existing files are overwritten. Using update=1 will
      skip them instead.
        update=0    Overwrite files if they exist
        update=1    Skip files if they exist

    uniq= Specifies whether only unique points are used, or whether duplicates
      are kept.
        uniq=0      Use all points, including duplicates (default)
        uniq=1      Use unique points, discard duplicates

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
  default, searchstr, ["*_v.pbd", "*_b.pbd", "*_f.pbd"];
  default, verbose, 1;
  default, update, 0;
  default, uniq, 0;

  // Locate files and split into dirs/tails
  files = find(path, searchstr=searchstr);
  dirs = file_dirname(files);
  tails = file_tail(files);

  // Extract tile names
  tiles = extract_tile(tails, dtlength="long", qqprefix=0);

  // Break up into _v/_b/_f
  types = array(string, numberof(files));
  w = where(strglob("*_v.pbd", tails));
  if(numberof(w))
    types(w) = "v";
  w = where(strglob("*_b.pbd", tails));
  if(numberof(w))
    types(w) = "b";
  w = where(strglob("*_f.pbd", tails));
  if(numberof(w))
    types(w) = "f";

  // Break up into w84, n88, etc.
  parsed = parse_datum(tails);
  datums = parsed(..,1);
  geoids = parsed(..,2);
  parsed = [];

  // Check for problems
  problem = strlen(tiles) == 0 | strlen(types) == 0 | strlen(datums) == 0;
  if(anyof(problem)) {
    w = where(problem);
    if(verbose) {
      write, format="\nFound %d problem files that were non-parseable and will \
        be skipped:\n", numberof(w);
      write, format=" - %s\n", tails(w);
    }
    if(allof(problem)) {
      if(verbose)
        write, format="All files were skipped. Aborting.%s", "\n";
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
    if(verbose) {
      write, format="\nFound %d output files that already exist. %s\n",
        numberof(existout), (update ? "Skipping." : "Overwriting.");
      write, format=" - %s\n", file_tail(existout);
    }
    if(update) {
      if(allof(exists)) {
        if(verbose)
          write, format="All files were skipped. Aborting.%s", "\n";
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
  if(verbose) {
    write, format="\nCreating %d set%s of merged files:\n", nsuf,
      (nsuf > 1 ? "s" : "");
    write, format=" - *%s\n", suffixes;
    write, format="\nMerging %d input files into %d output files...\n",
      count, outuniq;
  }

  // Iterate through and load each file, saving whenever we're on the input
  // file for a given output file.
  tstamp = [];
  timer_init, tstamp;
  i = j = k = 1;
  while(i <= count) {
    if(verbose)
      timer_tick, tstamp, k, outuniq;
    while(j < count && outfiles(j+1) == outfiles(i))
      j++;
    dirload, files=files(i:j), outfile=outfiles(i), outvname=vnames(i),
      uniq=uniq, soesort=1, skip=1, verbose=0;
    i = j = j + 1;
    k++;
  }
}

func batch_merge_tiles(path, searchstr=, file_suffix=, vname_suffix=,
verbose=, update=, uniq=) {
/* DOCUMENT batch_merge_tiles, path, searchstr=, file_suffix=, vname_suffix=,
  verbose=, update=, uniq=

  Performs a batch merge over data that has been stored in a tiled format.

  This will work for data stored in data tiles, index tiles, or quarter quads.
  All files found for each tile will be merged together. If a file does not
  have a parseable tile in its filename, it will be skipped.

  All input files for a given tile must contain data in the same structure,
  otherwise errors will ensue.

  Parameters:
    path: The path to the data.

  Options:
    searchstr= The search string to use to find your data. Examples:
        searchstr="*.pbd"    All pbd data (default)
        searchstr="*_v.pbd"  All veg data

    file_suffix= The suffix to append to the tile names when creating the
      merged output filename. Be sure to include the extension. Examples:
        file_suffix="_merged.pbd"        (default)
        file_suffix="_w84_v_merged.pbd"

    vname_suffix= The suffix to append to the tile names when creating the
      merged vname for the output file. Examples:
        vname_suffix="_merged"     (default)
        vname_suffix="_v_merged"

    verbose= Specifies whether output information should be given as its
      processes. Possible settings:
        verbose=0      Be silent.
        verbose=1      Give progress. (default)

    update= Turns on update mode, which skips existing files. Possible
      settings:
        update=0    Existing files are overwritten
        update=1    Existing files are skipped

    uniq= Turns on or off uniqueness. Points are considered duplicate if they
      share the same timestamp, raster, pulse, and channel.
        uniq=1      Throw away duplicate points (default)
        uniq=0      Keep duplicate points.

  Each of the three kinds of tiles has a different set of conventions that
  governs how their filenames and vnames are constructed, as follows.

  Data tiles (2km):
    The file name will start with the long form of the tile name. The vname
    will start with the short form of the tile name. Using the default
    settings, a merged tile might get this for its output:
      output filename = t_e652000_n4504000_18_merged.pbd
      output vname = e652_n4504_18_merged

  Index tiles (10km):
    Index tile names only have one form, which is what gets used. Using
    default settings, a merged tile might get this as its output:
      output filename = i_e640000_n4510000_18_merged.pbd
      output vname = i_e640000_n4510000_18_merged

  Quarter quads:
    The file name will start with the normal form of the tile name. The vname
    will start with the qq-prefixed form. Using the default settings, a
    merged tile might result in this:
      output filename = 29085h4b_merged.pbd
      output vname = qq29085h4b_merged
*/
  default, searchstr, "*.pbd";
  default, file_suffix, "_merged.pbd";
  default, vname_suffix, "_merged";
  default, verbose, 1;
  default, update, 0;
  default, uniq, 1;

  files_in = find(path, searchstr=searchstr);
  if(is_void(files_in)) {
    if(verbose)
      write, "No files found. Giving up!";
    return;
  }

  tiles = extract_tile(file_tail(files_in), dtlength="long", qqprefix=0);

  w = where(!tiles);
  if(numberof(w)) {
    if(verbose) {
      write, format=" Couldn't parse tile information for %d files:\n", numberof(w);
      write, format="  %s\n", file_tail(files_in(w));
    }
  }
  w = where(tiles);
  if(is_void(w)) {
    if(verbose)
      write, "Couldn't parse tile information for any files. Giving up!";
    return;
  }
  files_in = files_in(w);
  tiles = tiles(w);

  files_out = file_join(file_dirname(files_in), tiles + file_suffix);

  uniq_out = set_remove_duplicates(files_out);
  numout = numberof(uniq_out);

  tstamp = 0;
  timer_init, tstamp;
  for(i = 1; i <= numout; i++) {
    if(verbose)
      timer_tick, tstamp, i, numout;

    cur_out = uniq_out(i);

    if(update && file_exists(cur_out))
      continue;

    w = where(files_out == cur_out);

    vname = extract_tile(file_tail(cur_out), dtlength="short", qqprefix=1);
    vname += vname_suffix;

    dirload, files=files_in(w), outfile=cur_out, outvname=vname, uniq=uniq,
      skip=1, verbose=0;
  }
}

func batch_merge_veg_bathy(path, veg_ss=, bathy_ss=, file_suffix=, progress=,
ignore_none_found=) {
/* DOCUMENT batch_merge_veg_bathy, path, veg_ss=, bathy_ss=, file_suffix=,
  progress=, ignore_none_found=

  Performs a batch merge on the veg and bathy files found in path, creating
  seamless files.

  For tiles that have both a veg and a bathy file, the data from each file
  will be merged and a seamless file will be created. If only veg is present,
  it is copied to the seamless file. If only bathy is present, it is converted
  to VEG__ a seamless file will be created.

  Parameters:
    path: The path to the directory containing the veg and bathy files.
      (Normally an Index_Tiles directory.)

  Options:
    veg_ss= The search string to use for the veg files. Defaults to
      "*n88*mf_str.pbd".
    bathy_ss= The search string to use for the bathy files. Defaults to
      "*n88*_b_*mf.pbd"
    file_suffix= Specifies how the files will be named. This is appended to
      the tile's name to create a filename. Defaults to
      "n88_merged_seamless.pbd".
    progress= By default, progress is shown using a simple counter. Set
      progress=0 to silence that output.
    ignore_none_found= By default, the function will abort if it doesn't find
      some of both kinds of files (veg and bathy). Setting
      ignore_none_found=1 will force it to generate seamless files even if
      only one kind is present.
*/
  default, veg_ss, "*n88*mf_str.pbd";
  default, bathy_ss, "*n88*_b_*mf.pbd";
  default, file_suffix, "n88_merged_seamless.pbd";
  default, ignore_none_found, 0;
  default, progress, 1;

  v_files = find(path, searchstr=veg_ss);
  b_files = find(path, searchstr=bathy_ss);

  if(!numberof(v_files) && !numberof(b_files)) {
    write, "No veg or bathy files found. Aborting.";
    return;
  } else if(!numberof(v_files) && !ignore_none_found) {
    write, "No veg files found. Aborting.";
    write, "Use ignore_none_found=1 to force.";
    return;
  } else if(!numberof(b_files) && !ignore_none_found) {
    write, "No bathy files found. Aborting.";
    write, "Use ignore_none_found=1 to force.";
    return;
  }

  v_dt = numberof(v_files) ? extract_dt(file_tail(v_files), dtlength="long") : [];
  b_dt = numberof(b_files) ? extract_dt(file_tail(b_files), dtlength="long") : [];
  s_dt = set_union(v_dt, b_dt);

  tstamp = 0;
  timer_init, tstamp;
  for(i = 1; i <= numberof(s_dt); i++) {
    if(progress)
      timer_tick, tstamp, i, numberof(s_dt);
    this_tile = s_dt(i);

    seamless_file = string(0);

    vw = where(v_dt == this_tile);
    if(numberof(vw) == 1) {
      vw = vw(1);
      f = openb(v_files(vw));
      v_data = get_member(f, f.vname);
      close, f;

      seamless_file = file_join(
        file_dirname(v_files(vw)),
        this_tile + "_" + file_suffix
      );
    } else if(numberof(vw) > 1) {
      error, "Found multiple veg files for tile " + this_tile;
    } else {
      v_data = [];
    }

    bw = where(b_dt == this_tile);
    if(numberof(bw) == 1) {
      bw = bw(1);
      f = openb(b_files(bw));
      b_data = get_member(f, f.vname);
      close, f;

      if(!seamless_file)
        seamless_file = file_join(
          file_dirname(b_files(bw)),
          this_tile + "_" + file_suffix
        );
    } else if(numberof(bw) > 1) {
      error, "Found multiple bathy files for tile " + this_tile;
    } else {
      b_data = [];
    }

    seamless_data = merge_veg_bathy(v_data, b_data);
    vname = "smls_" + extract_dt(this_tile);

    f = createb(seamless_file);
    save, f, vname;
    add_variable, f, -1, vname, structof(seamless_data), dimsof(seamless_data);
    get_member(f, vname) = seamless_data;
    close, f;
  }
}
