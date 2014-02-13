// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "alps_data.i";
require, "dir.i";

func dirload(dir, searchstr=, files=, outfile=, outvname=, mode=,
remove_buffers=, bbox=, ply=, tile=, buffer=, force_zone=, uniq=, soesort=,
skip=, filter=, verbose=) {
/* DOCUMENT data = dirload(dir, searchstr=, files=, outfile=, outvname=, mode=,
   remove_buffers=, bbox=, ply=, tile=, buffer=, force_zone=, uniq=, soesort=,
   skip=, filter=, verbose=)

  Loads and merges the data found in the specified directory.

  Parameter:

    dir: The directory containing files to load.

  Options:

    searchstr= A search string to use for locating files to load and marge.
      Examples:
        searchstr="*.pbd"       All pbd files (default)
        searchstr="*fs*.pbd"    All first surface files
        searchstr="*.edf"       All edf files
        searchstr="*.las"       All las files

    files= Specifies an array of file names to load and merge. If provided,
      then the dir parameter and the searchstr option are ignored.

    outfile= If specified, the merged data will be written to this filename.
      By default, no file is created.

    outvname= If outfile= is specified, then this specifies the vname to use.
      Otherwise has no effect. The default vname varies based on the
      structure of the data:
        FS       ->  outvname="fst_merged"
        GEO      ->  outvname="bat_merged"
        VEG__    ->  outvname="bet_merged"
        CVEG_ALL ->  outvname="mvt_merged"
        (other)  ->  outvname="merged"

    mode= Specifies what mode to treate the data as. This is used by many of
      the filtering methods (remove_buffers, bbox, ply, tile).
        mode="fs"   Default

    remove_buffers= Specifies whether buffers should be removed from each tile
      prior to merging.
        remove_buffers=0    No, don't remove buffers (default)
        remove_buffers=1    Yes, remove buffers

    bbox= Specifies a bounding box to restrict data loading to.

    ply= Specifies a polygon to restrict data loading to.

    tile= Specifies a tile name to restrict data loading to.

    buffer= If tile= is used, this specifies a buffer to add around the tile.

    force_zone= Specifies a zone to force the data into.

    uniq= Specifies whether the merged data should be restricted to unique
      points using the soe values. Possible settings:
        uniq=0   Use all data points, even duplicates (default)
        uniq=1   Restrict to unique points

    skip= Specifies the "skip factor". One out of this many points will be
      kept. This must be an integer greater than or equal to one. Examples:
        skip=1   Use all points (default)
        skip=2   Use half of the points (1 of every 2)
        skip=10  Use 10% of the points (1 of every 10)
        skip=25  Use 4% of the points (1 of every 25)
      The subsampling occurs on a file-by-file basis as they are loaded.

    soesort= Specifies whether the data should be sorted by soe.
        soesort=0   Don't sort (default)
        soesort=1   Sort

    filter= Advanced option. Used for specifying a filter configuration. See
      source code for details.

    verbose= Specifies how chatty the function should be. Possible options:
        verbose=0   Complete silence, unless errors encountered
        verbose=1   Provide basic progress information (default)
*/
  // no defaults for: outfile, files; default for outvname established later
  default, searchstr, "*.pbd";
  default, mode, "fs";
  default, remove_buffers, 0;
  default, buffer, 0;
  default, uniq, 0;
  default, soesort, 0;
  default, skip, 1;
  default, verbose, 1;
  default, filter, save();

  // Set up filter
  if(remove_buffers)
    filter = dlfilter_remove_buffers(mode=mode, prev=filter);
  if(!is_void(bbox))
    filter = dlfilter_bbox(bbox, mode=mode, prev=filter);
  if(!is_void(ply))
    filter = dlfilter_poly(ply, mode=mode, prev=filter);
  if(tile)
    filter = dlfilter_tile(tile, mode=mode, buffer=buffer, prev=filter);
  if(skip > 1)
    filter = dlfilter_skip(skip, prev=filter);
  if(force_zone)
    filter = dlfilter_rezone(force_zone, prev=filter);

  // Necessary to avoid clobbering external variables for some reason.
  local idx;

  // Generate list of input files
  if(is_void(files))
    files = find(dir, searchstr=searchstr);

  // filter file list ...
  __dirload_apply_filter, files, save(), filter, "files";

  if(is_void(files)) {
    if(verbose)
      write, "No files found.";
    return [];
  }

  // Sort files by size, descending, so that largest files get loaded first.
  // This is safer when pushing up against the limits of memory.
  files = files(sort(-file_size(files)));

  // Determine data structure; user's responsibility to ensure all files have
  // the same one.
  eaarl_struct = [];
  for(i = 1; i <= numberof(files); i++) {
    ext = strlower(file_extension(files(i)));
    if(anyof(ext == [".bin", ".edf"])) {
      require, "edf.i";
      temp = edf_import(files(i));
    } else if(ext == ".las") {
      require, "las.i";
      temp = las_to_alps(files(i));
    } else {
      require, "util_container.i";
      temp = pbd_load(files(i));
    }
    if(!is_void(temp)) {
      eaarl_struct = structof(temp);
      break;
    }
  }
  temp = [];

  if(!is_struct(eaarl_struct)) {
    if(verbose)
      write, "Unable to determine struct for data. Aborting.";
    return [];
  }

  // data - the output data, as we build it up
  // start with an array of size 10MB
  sz = long(10485760 / sizeof(eaarl_struct)) + 1;
  data = array(eaarl_struct, sz);
  sz = [];
  // end - last valid index for the data
  end = 0;

  tstamp = err = [];
  if(verbose) {
    timer_init, tstamp;
    write, format=" Loading data from %d files:\n", numberof(files);
  }
  for(i = 1; i <= numberof(files); i++) {
    if(verbose)
      timer_tick, tstamp, i, numberof(files);

    ext = strlower(file_extension(files(i)));
    err = "";
    if(anyof(ext == [".bin", ".edf"])) {
      require, "edf.i";
      temp = edf_import(files(i));
    } else if(ext == ".las") {
      require, "las.i";
      temp = las_to_alps(files(i));
    } else {
      require, "util_container.i";
      temp = pbd_load(files(i), err);
    }

    if(is_void(temp)) {
      if(verbose)
        write, format=" !! %s: Skipping, %s\n", file_tail(files(i)), err;
      continue;
    }

    // filter data ...
    state = save(fn=files(i), cur=i, cnt=numberof(files));
    __dirload_apply_filter, temp, state, filter, "data";

    // The filter is allowed to eliminate all data for a file
    if(!numberof(temp))
      continue;

    new_end = end + numberof(temp);

    // Make sure the data variable has enough space allocated
    array_allocate, data, new_end;

    data(end+1:new_end) = unref(temp);
    end = new_end;
  }

  if(end == 0) {
    if(verbose)
      write, "No data found in files.";
    return [];
  }

  data = unref(data)(:end);

  if(uniq) {
    if(verbose)
      write, "Removing duplicates...";
    data = uniq_data(data);
  }
  if(soesort && numberof(data)) {
    data = sortdata(data, method="soe");
  }

  __dirload_apply_filter, data, save(), filter, "merged";

  if(!is_void(outfile))
    __dirload_write, outfile, outvname, &data;

  return data;
}

func dircopy(dir, outdir, searchstr=, files=, filter=, verbose=) {
/* DOCUMENT dircopy, dir, outdir, searchstr=, files=, filter=, verbose=
  Copies data from one directory to another, maintaining the directory and
  file structure.

  This function accepts the same kinds of filter= arguments as dirload.

  Parameters:
    dir: Source directory, to copy from.
    outdir: Destination directory, to copy to.

  Options:
    searchstr= A search string to use for locating files to copy. Examples:
        searchstr="*.pbd"       All pbd files (default)
        searchstr="*fs*.pbd"    All first surface files
    files= Specifies an array of file names to copy. If provided, then the
      dir parameter and the searchstr option are ignored.
    filter= Advanced option. Used for specifying a filter configuration. See
      source code for details.
    verbose= Specifies how chatty the function should be. Possible options:
        verbose=0   Complete silence, unless errors encountered
        verbose=1   Provide basic progress information (default)

  Note: Files are copied in append mode, to allow building up a copy over
  several passes. Duplicate points are eliminated.
*/
  // no defaults for: outfile, files; default for outvname established later
  default, searchstr, "*.pbd";
  default, verbose, 1;
  default, filter, save();

  // Generate list of input files
  if(is_void(files))
    files = find(dir, searchstr=searchstr);

  // filter file list ...
  __dirload_apply_filter, files, save(), filter, "files";

  if(is_void(files)) {
    if(verbose)
      write, "No files found.";
    return [];
  }

  local tstamp, data, vname;
  timer_init, tstamp;
  for(i = 1; i <= numberof(files); i++) {
    if(verbose)
      timer_tick, tstamp, i, numberof(files);

    data = pbd_load(files(i), , vname);

    if(!numberof(data))
      continue;

    // filter data ...
    state = save(fn=files(i), cur=i, cnt=numberof(files));
    __dirload_apply_filter, data, state, filter, "data";

    // The filter is allowed to eliminate all data for a file
    if(!numberof(data))
      continue;

    outfile = file_join(outdir, file_relative(dir, files(i)));
    mkdirp, file_dirname(outfile);
    pbd_append, outfile, vname, data, uniq=1;
  }
}

func dircopydiff(src, ref, dest, searchstr=, files=, verbose=) {
/* DOCUMENT dircopy, src, ref, dest, searchstr=, files=, verbose=
  Copies data from src that doesn't exist in ref to dest.

  This is intended to be used after a "dircopy". Suppose you're working with
  data that covers North Carolina and Virgina. You want to split it into
  sections for each state. First, you might decide to use dircopy to copy over
  the data for North Carolina with a command similar to this:

  dircopy, "/data/EAARL/processed/ExampleMission/Index_Tiles",
    "/data/EAARL/processed/ExampleMission/NC/Index_Tiles",
    searchstr="*.pbd", filter=dlfilter_poly(.....);

  Then you would use dircopydiff to get everything that /wasn't/ copied to
  NC/Index_Tiles so that you can work with that data without overlaps.

  dircopydiff, "/data/EAARL/processed/ExampleMission/Index_Tiles",
    "/data/EAARL/processed/ExampleMission/NC/Index_Tiles",
    "/data/EAARL/processed/ExampleMission/VA/Index_Tiles",
    searchstr="*.pbd"

  In some cases, you might need to use a more complicated series of commands
  involving temporary directories. For example, if your data covered SC, NC,
  and VA, you might need to do:
    dircopy to extract NC from Index_Tiles
    dircopydiff to extract Not_NC from Index_Tiles using NC
    dircopy to extract SC from Not_NC
    dircopydiff to extract VA from Not_NC using SC
    delete Not_NC

  Parameters:
    src: The directory that you want to copy from.
    ref: The directory to compare to. Anything that isn't in this directory
      will get copied.
    dest: The directory to copy to.

  Options:
    searchstr= A search string to use for locating files to copy. Examples:
        searchstr="*.pbd"       All pbd files (default)
        searchstr="*fs*.pbd"    All first surface files
    files= Specifies an array of file names to copy. If provided, then the
      dir parameter and the searchstr option are ignored.
    verbose= Specifies how chatty the function should be. Possible options:
        verbose=0   Complete silence, unless errors encountered
        verbose=1   Provide basic progress information (default)

  Note: Files are copied in append mode, to allow building up over several
  passes. Duplicate points are eliminated.
*/
// Original David Nagle 2010-04-28
  default, searchstr, "*.pbd";
  default, verbose, 1;

  // Generate list of input files
  if(is_void(files))
    files = find(src, searchstr=searchstr);

  if(is_void(files)) {
    if(verbose)
      write, "No files found.";
    return [];
  }

  local tstamp, data, vname;
  timer_init, tstamp;
  for(i = 1; i <= numberof(files); i++) {
    if(verbose)
      timer_tick, tstamp, i, numberof(files);

    data = pbd_load(files(i), , vname);

    if(!numberof(data))
      continue;

    reffile = file_join(ref, file_relative(src, files(i)));
    if(file_exists(reffile)) {
      refdata = pbd_load(reffile);
      if(numberof(refdata))
        data = extract_unique_data(data, refdata);
      refdata = [];
    }

    if(!numberof(data))
      continue;

    outfile = file_join(dest, file_relative(src, files(i)));
    mkdirp, file_dirname(outfile);
    pbd_append, outfile, vname, data, uniq=1;
  }
}

/*** PRIVATE FUNCTIONS FOR dirload ***/
func __dirload_apply_filter(&input, state, filters, name) {
  if(filters(*,name)) {
    filter = filters(noop(name));
    while(!is_void(filter) && !is_void(input)) {
      void = filter.function(input, filter, state);
      filter = filter.next;
    }
  }
}

func __dirload_write(outfile, outvname, ptr) {
/* DOCUMENT __dirload_write, outfile, outvname, ptr;
  Used internally by dirload. Writes the merged data to a pbd file.
*/
  if(is_void(outvname)) {
    if(structeq(eaarl_struct, FS)) outvname = "fst_merged";
    else if(structeq(eaarl_struct, GEO)) outvname = "bat_merged";
    else if(structeq(eaarl_struct, VEG__)) outvname = "bet_merged";
    else if(structeq(eaarl_struct, CVEG_ALL)) outvname = "mvt_merged";
    else outvname = "merged";
  }

  pbd_save, outfile, outvname, *ptr;
}

/* FILTERS */

func dlfilter_merge_filters(filter, prev=, next=) {
/* DOCUMENT filter = dlfilter_merge_filters(filter, prev=, next=)
  Merges filters intended for dirload.

  Parameters:
    filter: Should be a filter suitable for dirload.

  Options:
    prev= If provided, should be a filter suitable for dirload. This will be
      merged with the filter parameter such that everything in prev will
      occur first.
    next= If provided, should be a filter suitable for dirload. This will be
      merged with the filter parameter such that everything in next will
      occur last.

  Returns:
    The merged filter.
*/
  if(!is_void(prev))
    filter = dlfilter_merge_filters(prev, next=filter);
  if(!is_void(next)) {
    keys = next(*,);
    kcount = numberof(keys);
    for(i = 1; i <= kcount; i++) {
      if(filter(*,keys(i))) {
        temp = filter(keys(i));
        while(temp(*,"next")) temp = temp.next;
        save, temp, next=next(keys(i));
      } else {
        save, filter, keys(i), next(keys(i));
      }
    }
  }
  return filter;
}

func __dlfilter_data_skip(&data, filter, state) {
/* DOCUMENT __dlfilter_data_skip, data, filter, state;
  Support function for dlfilter_skip.
*/
  if(filter.skip > 1 && numberof(data))
    data = data(1::filter.skip);
}

func dlfilter_skip(skip, prev=, next=) {
/* DOCUMENT filter = dlfilter_skip(skip, prev=, next=)
  Creates a filter for dirload that will subsample data by a skip factor.
*/
  filter = save(
    data=save(function=__dlfilter_data_skip, skip)
  );
  return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func __dlfilter_data_rezone(&data, filter, state) {
/* DOCUMENT __dlfilter_data_rezone, data, filter, state;
  Support function for dlfilter_rezone.
*/
  zone = tile2uz(file_tail(state.fn));
  if(zone == 0)
    data = [];
  else if(zone != filter.zone)
    rezone_data_utm, data, zone, filter.zone;
}

func dlfilter_rezone(zone, prev=, next=) {
/* DOCUMENT filter = dlfilter_rezone(zone, prev=, next=)
  Creates a filter for dirload that will rezone the data.
*/
  filter = save(
    data=save(function=__dlfilter_data_rezone, zone)
  );
  return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func __dlfilter_files_poly(&files, filter, state) {
/* DOCUMENT __dlfilter_files_poly, files, filter, state;
  Support function for dlfilter_poly.
*/
  poly = filter.poly;
  fbbox = [poly(1,min), poly(1,max), poly(2,min), poly(2,max)];
  keep = array(short(1), numberof(files));
  for(i = 1; i <= numberof(files); i++) {
    bbox = tile2bbox(file_tail(files(i)));
    if(is_void(bbox)) continue;
    dbbox = bbox([4,2,1,3]);
    keep(i) = dbbox(1) <= fbbox(2) && fbbox(1) <= dbbox(2) &&
      dbbox(3) <= fbbox(4) && fbbox(3) <= dbbox(4);
  }
  w = where(keep);
  if(numberof(w))
    files = files(w);
  else
    files = [];
}

func __dlfilter_data_poly(&data, filter, state) {
/* DOCUMENT __dlfilter_data_poly, data, filter, state;
  Support function for dlfilter_poly.
*/
  data2xyz, data, x, y, mode=filter.mode;
  idx = testPoly(filter.poly, unref(x), unref(y));
  if(numberof(idx))
    data = data(idx);
  else
    data = [];
}

func dlfilter_poly(poly, prev=, next=, mode=) {
/* DOCUMENT filter = dlfilter_poly(poly, prev=, next=, mode=)
  Creates a filter for dirload that will filter using the given polygon.
*/
  default, mode, "fs";
  if(dimsof(poly)(2) != 2)
    poly = transpose(poly);
  filter = save(
    files=save(function=__dlfilter_files_poly, poly),
    data=save(function=__dlfilter_data_poly, poly, mode)
  );
  return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func dlfilter_bbox(bbox, prev=, next=, mode=) {
/* DOCUMENT filter = dlfilter_bbox(bbox, prev=, next=, mode=)
  Creates a filter for dirload that will filter using the given bounding box.
  bbox should be [x1, y1, x2, y2].
*/
  poly = [bbox([1,3,3,1,1]), bbox([2,2,4,4,2])];
  return dlfilter_poly(poly, prev=prev, next=next, mode=mode);
}

func __dlfilter_files_tile(&files, filter, state) {
/* DOCUMENT __dlfilter_files_tile, files, filter, state;
  Support function for dlfilter_tile.
*/
  target = tile2bbox(filter.tile);
  nmin = target(1);
  emax = target(2);
  nmax = target(3);
  emin = target(4);
  tzone = target(5);

  fcount = numberof(files);
  keep = array(short(1), fcount);
  for(i = 1; i <= fcount; i++) {
    bbox = tile2bbox(file_tail(files(i)));
    if(is_void(bbox)) continue;

    // Get coordinates for each corner; then nudge a bit in every direction to
    // hit adjacent tiles.
    n = bbox([1,1,3,3])(-,) + [-1,-1,-1, 0,0,0, 1,1,1];
    e = bbox([2,4,2,4])(-,) + [-1, 0, 1,-1,0,1,-1,0,1];
    z = filter.zone ? filter.zone : long(bbox(5));

    if(z != tzone) rezone_utm, n, e, z, tzone;

    keep(i) = is_array(data_box(e, n, emin, emax, nmin, nmax));
  }

  files = files(where(keep));
}

func __dlfilter_data_tile(&data, filter, state) {
/* DOCUMENT __dlfilter_data_tile, data, filter, state;
  Support function for dlfilter_tile.
*/
  if(filter.zone == 0) {
    zone = tile2uz(file_tail(state.fn));
    if(!zone) {
      data = [];
      return;
    }
  } else if(filter.zone < 0) {
    zone = data.zone;
  } else {
    zone = filter.zone;
  }

  data2xyz, data, x, y, mode=filter.mode;

  tile_zone = long(tile2uz(filter.tile));
  // Coerce zone if needed
  if(anyof(tile_zone != zone))
    rezone_data_utm, data, zone, tile_zone;

  w = extract_for_tile(x, y, zone, filter.tile, buffer=filter.buffer);
  if(numberof(w))
    data = data(w);
  else
    data = [];
}

func dlfilter_tile(tile, prev=, next=, mode=, buffer=, zone=, dataonly=) {
/* DOCUMENT filter = dlfilter_tile(tile, prev=, next=, mode=, buffer=, zone=,
   dataonly=)
  Creates a filter for dirload that will filter using the given tile.

  Options:
    mode= Data's mode
    buffer= Buffer to include around the tile.
    zone= The zone that the data is in. By default (zone=0), zone is detected
      from the file name. If zone=-1, then data.zone is used (for ATM).
      Otherwise, zone specifies the zone to assume for all data.
    dataonly= Only filters the data. This omits the step where files are
      filtered (which is useful if you are specifying files and want all of
      them considered).

  Note: If the zone of a file's data does not match the zone of the specified
  tile, the data will be re-zoned to the tile's zone. This allows this filter
  to operate intelligently at zone boundaries.
*/
  default, mode, "fs";
  default, buffer, 0;
  default, zone, 0;
  filter = save(
    data = save(function=__dlfilter_data_tile, tile, mode, buffer, zone)
  );
  if(zone >= 0 && !dataonly) {
    save, filter, files=save(function=__dlfilter_files_tile, tile, zone);
  }

  return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func __dlfilter_data_remove_buffers(&data, filter, state) {
/* DOCUMENT __dlfilter_data_remove_buffers, data, filter, state;
  Support function for dlfilter_remove_buffers.
*/
  data2xyz, data, x, y, mode=filter.mode;
  tile = extract_tile(file_tail(state.fn));
  zone = long(tile2uz(tile));
  w = extract_for_tile(x, y, zone, tile, buffer=0);
  if(numberof(w))
    data = data(w);
  else
    data = [];
}

func dlfilter_remove_buffers(prev=, next=, mode=) {
/* DOCUMENT filter = dlfilter_remove_buffers(prev=, next=, mode=)
  Creates a filter for dirload that will remove buffers from files that have
  parseable tile names.
*/
  default, mode, "fs";
  filter = save(
    data = save(function=__dlfilter_data_remove_buffers, mode)
  );
  return dlfilter_merge_filters(filter, prev=prev, next=next);
}

// *** ALPS INTEGRATION ***

func dirload_l1pro_selpoly {
/* DOCUMENT dirload_l1pro_selpoly;
  Intergration function for YTK. Used by l1pro::dirload.
*/
  ply = get_poly();
  dirload_l1pro_send, ply, "Polygon";
}

func dirload_l1pro_selbbox {
/* DOCUMENT dirload_l1pro_selbbox;
  Intergration function for YTK. Used by l1pro::dirload.
*/
  win = window();
  msg = swrite(format="Draw a box in window %d to select the region.", win);
  rgn = mouse(1, 1, msg);
  ply = transpose([rgn([1,3,3,1,1]), rgn([2,2,4,4,2])]);
  dirload_l1pro_send, ply, "Rubberband box";
}

func dirload_l1pro_sellims {
  win = window();
  lims = limits();
  ply = lims([[1,3],[1,4],[2,4],[2,3],[1,3]]);
  dirload_l1pro_send, ply, swrite(format="Window %d limits", win);
}

func dirload_l1pro_send(ply, kind) {
/* DOCUMENT dirload_l1pro_send, ply, kind;
  Intergration function for YTK. Used for l1pro::dirload.
*/
  area = poly_area(ply);
  if(area < 1e6)
    area = swrite(format="%.0f square meters", area);
  else
    area = swrite(format="%.3f square kilometers", area/1e6);
  tkcmd, swrite(format="set ::l1pro::dirload::v::region_desc {%s with area %s}",
    kind, area);

  ply = swrite(format="%.3f", ply);
  ply = "[" + ply(1,) + "," + ply(2,) + "]";
  ply(:-1) += ","
  ply = "[" + ply(sum) + "]";
  tkcmd, swrite(format="set ::l1pro::dirload::v::region_data {%s}", ply);
}
