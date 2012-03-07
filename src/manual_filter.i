// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func select_region_tile(data, win=, plot=, mode=) {
/* DOCUMENT select_region(data, win=, plot=, mode=)
  This function allows the user to select a region tile by dragging a box with
  the mouse. The smallest size tile (data, 2km; letter, 1km; or number, 250m)
  that contains that box will be selected, and the data within that region
  will be returned. If the user selects an invalid box (one that crosses two
  data tiles), no filtering will occur.

  win= specifies which window to use (default win=5)
  plot= specifies whether to draw the selected tile's boundary (default plot=1)
  mode= specifies the data mode to use when selecting the data (default mode="fs")
*/
// Original amar nayegandhi 11/21/03.
// Overhauled David Nagle 2010-02-05
  local etile, ntile, x, y;
  default, win, 5;
  default, plot, 1;

  wbkp = current_window();
  window, win;

  a = mouse(1,1,"Hold the left mouse button down and select a region:");

  emin = a([1,3])(min);
  emax = a([1,3])(max);
  nmin = a([2,4])(min);
  nmax = a([2,4])(max);

  factors = [250., 1000., 2000.];

  // Try to find the smallest factor that yields a tile
  i = 0;
  do {
    i++;
    f = factors(i);
    etile = long(floor([emin,emax]/f)*f);
    ntile = long(ceil([nmin,nmax]/f)*f);
    difs = etile(dif)(1) + ntile(dif)(1);
  } while(i < 3 && difs > 1);

  if(difs > 1) {
    write, "Bad region selected! Please try again...";
    return data;
  }

  etile = etile(1);
  ntile = ntile(1);

  write, format=" Congratulations! You have selected a %s tile.\n",
    ["250m by 250m cell", "1km by 1km quad", "2km by 2km data"](i);

  bbox = [etile, ntile-f, etile+f, ntile];

  if(plot) {
    tx = etile + [0, f, f, 0, 0];
    ty = ntile - [f, f, 0, 0, f];
    plg, ty, tx, color="yellow", width=1.5;
  }
  window_select, wbkp;

  data2xyz, data, x, y, mode=mode;
  idx = data_box(unref(x), unref(y), etile, etile+f, ntile-f, ntile);

  return data(idx);
}

func test_and_clean(&data, verbose=, force=, mirror=, zeronorth=, zerodepth=,
negch=) {
/* DOCUMENT test_and_clean, data, verbose=, force=, mirror=, zeronorth=,
    zerodepth=, negch=
  cleaned = test_and_clean(data, verbose=, force=, mirror=, zeronorth=,
    zerodepth=, negch=)

  Tests the data in various ways and cleans it as necessary.

  The tests and cleaning that occurs corresponds to various options as
  detailed below.

  The first test is to see if the data is in a raster format (GEOALL,
  VEG_ALL_, VEG_ALL, or R). If it is, the data is coerced into the
  corresponding point format (GEO, VEG__, VEG__, and FS respectively).

  At this point, force= comes into play.

  force= Specifies whether data should be cleaned when the structure is
    already "right".
      force=0        Default. If the structure was not GEOALL, VEG_ALL_,
                VEG_ALL, or R, then nothing further happens and the
                function is effectively a noop.
      force=1        Further cleaning will always happen.

  If further cleaning occurs, then the following options come into play.

  mirror= Removes points by performing two checks using the mirror
    coordinates. If the data has .elevation, .lelv, and .melevation fields,
    then points where both .elevation and .lelv equal .melevation are
    discarded.  If the data has .elevation and .melevation but not .depth or
    .lelv, then points where .elevation equals .melevation are discarded.
      mirror=1       Default. Perform this filtering.
      mirror=0       Skip this filter.

  zeronorth= Removes points with zero values for .north or .lnorth.
      zeronorth=1    Default. Perform this filtering.
      zeronorth=0    Skip this filter.

  zerodepth= Removes points with zero .depth values.
      zerodepth=1    Default. Perform this filtering.
      zerodepth=0    Skip this filter.

  negch= Detects points with a negative canopy height; that is, where the
    first return .elevation is lower than the last return .lelv. The actual
    action taken depends on the setting's value.
      negch=2        Default. Set .elevation to .lelv.
      negch=1        Remove the points.
      negch=0        Skip this filter.

  By default, it runs silently. Use verbose=1 to get some info.

  This function utilizes memory better when run as a subroutine rather than a
  function. If you don't need to keep the original, unclean data, then use the
  subroutine form.
*/
  default, verbose, 0;
  default, force, 0;
  default, mirror, 1;
  default, zeronorth, 1;
  default, zerodepth, 1;
  default, negch, 2;

  if(is_void(data)) {
    if(verbose)
      write, "No data found in variable provided.";
    return [];
  }

  // If we're not forcing, and if the struct isn't a known raster type, do
  // nothing.
  if(!force && !structeqany(structof(data), GEOALL, VEG_ALL_, VEG_ALL, R))
    return data;

  // If we're running as subroutine, we can be more memory efficient.
  if(am_subroutine()) {
    eq_nocopy, result, data;
    data = [];
  } else {
    result = data;
  }

  // Convert from raster type to point type
  struct_cast, result, verbose=verbose;

  if(verbose)
    write, "Cleaning data...";

  if(mirror) {
    // Only applies to veg types.
    // Removes points where both of elevation and lelv equal the mirror.
    if(
      has_member(result, "elevation") && has_member(result, "lelv") &&
      has_member(result, "melevation")
    ) {
      w = where(
        (result.lelv != result.melevation) |
        (result.elevation != result.melevation)
      );
      result = numberof(w) ? result(w) : [];
    }

    // Only applies to fs types. (Explicitly avoiding veg and bathy.)
    // Removes points where the elevation equals the mirror.
    if(
      has_member(result, "elevation") && has_member(result, "melevation") &&
      !has_member(result, "depth") && !has_member(result, "lelv")
    ) {
      w = where(result.elevation != result.melevation);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(zeronorth) {
    // Applies to all types.
    // Removes points with zero fs northings.
    if(has_member(result, "north")) {
      w = where(result.north);
      result = numberof(w) ? result(w) : [];
    }

    // Only applies to veg types.
    // Removes points with zero be northings.
    if(has_member(result, "lnorth")) {
      w = where(result.lnorth);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(zerodepth) {
    // Only applies to bathy types.
    // Removes points with zero depths.
    if(has_member(result, "depth")) {
      w = where(result.depth);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(negch == 2) {
    // Only applies to veg types.
    // Ensures that first return is not lower than last return.
    // For negch=2, coerce to match
    if(has_member(result, "elevation") && has_member(result, "lelv")) {
      w = where(result.lelv > result.elevation);
      if(numberof(w)) {
        result.north(w) = result.lnorth(w);
        result.east(w) = result.least(w);
        result.elevation(w) = result.lelv(w);
      }
    }
  } else if(negch) {
    // Only applies to veg types.
    // Ensures that first return is not lower than last return.
    // For negch=1, discard
    if(has_member(result, "elevation") && has_member(result, "lelv")) {
      w = where(result.lelv <= result.elevation);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(am_subroutine())
    eq_nocopy, data, result;
  else
    return result;
}

func select_points(celldata, exclude=, win=) {
// amar nayegandhi 11/21/03
  extern croppeddata, edb;
  default, win, 4;
  default, exclude, 0;

  celldata = test_and_clean(celldata);

  if(exclude)
    write,"Left: Examine pixel, Center: Remove Pixel, Right: Quit"
  else
    write,"Left: Examine pixel, Center: Save Pixel, Right: Quit"

  window, win;
  left_mouse = 1;
  center_mouse = 2;
  right_mouse = 3;
  buf = 1000;  // 10 meters

  rtn_data = [];
  clicks = selclicks = 0;

  if (!is_array(edb)) {
    write, "No EDB data present.  Use left OR middle mouse to select point, right mouse to quit."
    new_point_selected = 1;
  }


  do {
    spot = mouse(1,1,"");
    mouse_button = spot(10);
    if (mouse_button == right_mouse)
      break;

    if ( (mouse_button == center_mouse)  ) {
      if (is_array(edb)) {
        if ( new_point_selected ) {
          new_point_selected = 0;
          selclicks++;
          if(exclude)
            write, format="Point removed from workdata. Total points removed:%d. Right:Quit.\n", selclicks;
          else
            write, format="Point saved to workdata. Total points selected:%d, Right:Quit.\n", selclicks;
          plmk, mindata.north/100., mindata.east/100., marker=6, color="red", msize=0.4, width=5;
          rtn_data = grow(rtn_data, mindata);
          continue;
        } else {
          write, "Use the left button to select a new point first.";
        }
      }
    }

    q = where(((celldata.east >= spot(1)*100-buf) &
      (celldata.east <= spot(1)*100+buf)) );

    if (is_array(q)) {
      indx = where(((celldata.north(q) >= spot(2)*100-buf) &
        (celldata.north(q) <= spot(2)*100+buf)));
      indx = q(indx);
    }
    if (is_array(indx)) {
      rn = celldata(indx(1)).rn;
      mindist = buf*sqrt(2);
      for (i = 1; i <= numberof(indx); i++) {
        x1 = (celldata(indx(i)).east)/100.0;
        y1 = (celldata(indx(i)).north)/100.0;
        dist = sqrt((spot(1)-x1)^2 + (spot(2)-y1)^2);
        if (dist <= mindist) {
          mindist = dist;
          mindata = celldata(indx(i));
          minindx = indx(i);
        }
      }
      blockindx = minindx / 120;
      rasterno = mindata.rn&0xffffff;
      pulseno  = mindata.rn>>24;

      if (mouse_button == left_mouse) {
        if (is_array(edb)) {
          new_point_selected = 1;
          a = [];
          clicks++;
          ex_bath, rasterno, pulseno, win=0, graph=1, xfma=1;
          window, win;
        }
      }
      if (!is_array(edb)) {
        if ((mouse_button == left_mouse) || (mouse_button == center_mouse)) {
          selclicks++;
          write, format="Point saved to (or removed from) workdata. Total points selected:%d\n", selclicks;
          rtn_data = grow(rtn_data, mindata);
        }
      }
    }
  } while ( mouse_button != right_mouse );

  write, format="Total waveforms examined = %d; Total points selected = %d\n",clicks, selclicks;

  if (exclude) {
    croppeddata = rtn_data;
    idx = set_difference(celldata.rn, rtn_data.rn);
    rtn_data = celldata(idx);
  }

  return rtn_data;
}

func pipthresh(data, maxthresh=, minthresh=, mode=, idx=) {
/* DOCUMENT pipthresh(data, maxthresh=, minthresh=, mode=, idx=)
  This function prompts the user to select data using the points-in-polygon
  (PIP) technique. Points within this region that are within the min and max
  threshold are removed and the data is returned.

  Parameter:
    data: An array of ALPS data.

  Options:
    minthresh= Minimum threshold in meters. Points below this elevation are
      always kept.
    maxthresh= Maximum threshold in meters. Points above this elevation are
      always kept.
    mode= Type of data. Can be any mode valid for data2xyz.
        mode="fs"   First surface
        mode="ba"   Bathymetry
        mode="be"   Bare earth
      For backwards compatibility, it can also be one of the following:
        mode=1      First surface
        mode=2      Bathymetry
        mode=3      Bare earth
      If not specified, then the mode is set based on the data's structure:
        FS -> mode="fs"
        GEO -> mode="ba"
        VEG__ -> mode="be"
    idx= By default, the filtered data is returned. Using idx=1 gives an
      index list instead.
        idx=0    Return filtered data (default)
        idx=1    Return an index into data
*/
  local x, y, z;
  default, idx, 0;

  //Automatically get mode if not set
  if (is_void(mode)) {
    a = structof(data);
    if (structeq(a, FS)) mode = 1;
    if (structeq(a, GEO)) mode = 2;
    if (structeq(a, VEG__)) mode = 3;
  }
  if(is_integer(mode))
    mode = ["fs", "ba", "be"](mode);
  data2xyz, data, x, y, z, mode=mode;

  // Make the user give us a polygon
  ply = getPoly();

  // Find the points that are within the polygon.
  poly_pts = testPoly(ply, x, y);
  if(!numberof(poly_pts))
    return idx ? indgen(numberof(data)) : data;

  // Among the points in the polygon, find the ones that are within the
  // threshold.
  thresh_pts = filter_bounded_elv(data(poly_pts), lbound=minthresh,
    ubound=maxthresh, mode=mode, idx=1);

  // Good points are those that don't match thresh_pts.
  good = array(short(1), dimsof(data));
  good(poly_pts(thresh_pts)) = 0;
  good = where(good);

  write, format="%d of %d points within selected region removed.\n",
    numberof(thresh_pts), numberof(poly_pts);
  return idx ? good : data(good);
}

func filter_bounded_elv(eaarl, lbound=, ubound=, mode=, idx=) {
/* DOCUMENT filter_bounded_elv(eaarl, lbound=, ubound=, mode=, idx=)
  Filters eaarl data by restricting it to the given elevation bounds.

  Parameters:
    eaarl: The data to filter, must be an ALPS data structure.

  Options:
    lbound= The lower bound to apply, in meters. By default, no bound is
      applied.
    ubound= The upper bound to apply, in meters. By default, no bound is
      applied.
    mode= The data mode to use. Can be any setting valid for data2xyz.
        mode="fs"      First surface (default)
        mode="be"      Bare earth
        mode="ba"      Bathy
    idx= By default, the function returns the filtered data. Using idx=1 will
      force it to return the index list into the data instead.
        idx=0    Return filtered data (default)
        idx=1    Return index into data

  Note that if both lbound= and ubound= are omitted, then this function is
  effectively a no-op.
*/
  local z;
  default, idx, 0;

  if(is_vector(eaarl) && is_numerical(eaarl))
    z = eaarl;
  else
    data2xyz, eaarl, , , z, mode=mode;
  keep = indgen(numberof(z));

  if(!is_void(lbound))
    keep = keep(where(z(keep) >= lbound));

  if(is_void(keep))
    return [];

  if(!is_void(ubound))
    keep = keep(where(z(keep) <= ubound));

  if(is_void(keep))
    return [];

  return idx ? keep : eaarl(keep,..);
}

func batch_extract_corresponding_data(src_searchstr, ref_searchstr, maindir,
srcdir=, refdir=, outdir=, fn_append=, vname_append=, method=, soefudge=,
fudge=, mode=, native=, verbose=) {
/* DOCUMENT batch_extract_corresponding_data, src_searchstr, ref_searchstr,
  maindir, srcdir=, refdir=, outdir=, fn_append=, vname_append=, method=,
  soefudge=, fudge=, mode=, native=, verbose=

  This copies data from source (src) to output (out). It uses a given
  reference data (ref) to determine which points get copied.

  There are three data sets involved:
    source (src): This is the data you'd like to copy from.
    reference (ref): This is used as a reference to determine which points
      from source get copied. This data is NOT copied. Instead, the raster
      numbers and soe values are used to identify which points in source
      should get copied.
    output (out): This is where the data gets copied to.

  The source and reference data must both be EAARL data with valid soe values
  and raster numbers.

  Example scenario:
    You have a dataset that you've processed and manually filtered. After
    completing the manual editing, you discover that there was a problem with
    the processing. The problem is significant enough that you need to
    re-process the data; however, it isn't so significant that the manual
    edits you performed wouldn't apply to the re-processed data. You can use
    batch_extract_corresponding_data to apply your manual edits to the
    re-processed data. In this case, the three data sets involved are:
      source: The re-processed data.
      reference: The manually edited data that had a problem in the
        processing.
      output: Points from re-processed data that correspond to points in the
        manually eedited data.

  Required arguments:
    src_searchstr: A search string that locates the source data.
    ref_searchstr: A search string that locates the reference data.

  Optional argument:
    maindir: The directory where the data can be found. This serves as a
      default for srcdir=, refdir=, and outdir=.

  Options:
    srcdir= The directory where the source data is located.
    refdir= The directory where the reference data is located.
    outdir= The directory where the output data should go.
    fn_append= A string to include in the output filename to differentiate it
      from the source filename.
        fn_append="extracted"   (default)
    vname_append= A string to include in the output vname to indicate that
      it's extracted data.
        vname_append="ext"      (default)
    method= Extraction method.
        method="data"     Use extract_corresponding_data (default)
        method="xyz"      Use extract_corresponding_xyz
    soefudge= Passed through to extract_corresponding_data.
    fudge= Passed through to extract_corresponding_xyz.
    mode= Passed through to extract_corresponding_xyz.
    native= Passed through to extract_corresponding_xyz.
    verbose= Allows user to set verbosity level.
      verbose=0   Silent.
      verbose=1   Progress (default)
      verbose=2   Debug, very chatty

  Note on directory arguments/options:
    If you provide all three of srcdir=, refdir=, and outdir=, then you do
    NOT need to provide maindir. However, if you omit any of those three
    options, then you DO need to provide maindir.

    Supplying maindir is a shortcut that is equivalent to supplying that same
    path for any of the srcdir=, refdir=, and outdir= options that you did
    not explicitly provide.

  Note on output:
    Output files will be created using the same relative paths as the source
    data. Unlike many other functions in ALPS, specifying outdir= will *not*
    result in all files getting created directly in the specified directory.
    If the source files are organized in a 10km/2km structure, then the
    output files will also be organized in a 10km/2km structure.

  Note on reference data:
    It is assumed that the reference data is in the same UTM zone as the
    source data. It is also assumed that the source and reference data are
    located in similar x,y locations. If the easting and northing of a given
    point are more than 10m different between source and reference, the
    algorithm may fail to identify the point as one that should be copied.

  Usage example:
    Suppose you originally processed and manually edited data using rapid
    trajectories. Now you have precision trajectories and want to reprocess
    the data. You could do something like this:
      batch_extract_corresponding_data,
        "*w84_v_merged.pbd",
        "*w84_v_merged_fs_b600_w500_nc_grcf_mf.pbd",
        "/data/0/EAARL/processed/EXAMPLE/Index_Tiles/",
        refdir="/data/0/EAARL/processed/EXAMPLE/Index_Tiles_rapid/"
    That will look in EXAMPLE/Index_Tiles for files that match
    *w84_v_merged.pbd. Each point in that data will be checked to see if it
    exists in EXAMPLE/Index_Tiles_rapid in files that match
    *w84_v_merged_fs_b600_w500_nc_grcf_mf.pbd. Any points that match are then
    copied to EXAMPLE/Index_Tiles in files named *w84_v_merged_extracted.pbd.

  SEE ALSO: extract_corresponding_data
*/
  local ref, data;
  default, srcdir, maindir;
  default, refdir, maindir;
  default, outdir, maindir;
  default, fn_append, "extracted";
  default, vname_append, "ext";
  default, method, "data";
  default, verbose, 1;
  if(strpart(fn_append, 1:1) != "_")
    fn_append = "_" + fn_append;
  if(strlen(vname_append) && strpart(vname_append, 1:1) != "_")
    vname_append = "_" + vname_append;

  files = find(srcdir, glob=src_searchstr);

  if(numberof(files) > 1)
    sizes = file_size(files)(cum)(2:);
  else if(numberof(files))
    sizes = file_size(files);
  else
    error, "No files found.";

  local t0, data, vname, x, y;
  timer_init, t0;
  tp = t0;
  for(i = 1; i <= numberof(files); i++) {
    if(verbose >= 2)
      write, format="%d: %s\n", i, file_tail(files(i));
    data = pbd_load(files(i), , vname);

    if(!numberof(data)) {
      if(verbose >= 2)
        write, " No data found.";
      continue;
    }

    data2xyz, data, x, y;
    // Include a 10m buffer, in case the points are located slightly
    // differently
    bbox = [x(min), y(min), x(max), y(max)] + [-10, -10, 10, 10];
    x = y = [];
    ref = dirload(refdir, searchstr=ref_searchstr, verbose=0,
      filter=dlfilter_bbox(bbox, mode=mode));

    if(!numberof(ref)) {
      if(verbose >= 2)
        write, " No reference data found.";
      continue;
    }

    if(method == "xyz")
      data = extract_corresponding_xyz(data, ref, fudge=fudge, mode=mode,
        native=native);
    else
      data = extract_corresponding_data(data, ref, soefudge=soefudge);
    ref = [];

    if(!numberof(data)) {
      if(verbose >= 2)
        write, " Extraction eliminated all points.";
      continue;
    }

    outfile = file_join(outdir, file_relative(srcdir, files(i)));
    outfile = file_rootname(outfile) + fn_append + ".pbd";
    vname += vname_append;
    mkdirp, file_dirname(outfile);
    pbd_append, outfile, vname, data, uniq=1;
    if(verbose >= 2)
      write, format="  -> %s\n", file_tail(outfile);
    data = [];

    if(verbose)
      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
  }
  if(verbose)
    timer_finished, t0;
}

func extract_corresponding_data(data, ref, soefudge=) {
/* DOCUMENT extracted = extract_corresponding_data(data, ref, soefudge=)

  This extracts points from "data" that exist in "ref".

  An example use of this function:

    We have a variable named "old_mf" that contains manually filtered VEG__
    data that had been processed using rapid trajectory pnav files. We have
    another variable "new" that contains data for the same region that was
    processed using precision trajectory pnav files, but has not yet been
    filtered. If we do this:

      new_mf = extract_corresponding_data(new, old_mf);

    Then new_mf will contain point data from new, but will only contain those
    points that were present in old_mf.

  Another example:

    We have a variable "fs" that contains first surface data and a variable
    "be" that contains bare earth data. If we do this:

      be = extract_corresponding_data(be, fs);
      fs = extract_corresponding_data(fs, be);

    Both variables are now restricted to those points that existed in both
    original point clouds.

  Parameters:
    data: The source data. The return result will contain points from this
      variable.
    ref: The reference data. Points in "data" will only be kept if they are
      found in "ref".

  Options:
    soe_fudge= This is the amount of "fudge" allowed for soe timestamps. The
      default value is 0.001 seconds. Thus, two timestamps are considered the
      same if they are within 0.001 seconds of one another. Changing this
      might be helpful if one of your variables was recreated from XYZ or
      LAS data and seems to have lost some timestamp resolution.

  SEE ALSO: extract_unique_data, batch_extract_corresponding_data
*/
  default, soefudge, 0.001;
  data = data(msort(data.rn, data.soe));
  ref = ref(msort(ref.rn, ref.soe));
  keep = array(char(0), numberof(data));

  i = j = 1;
  ndata = numberof(data);
  nref = numberof(ref);
  while(i <= ndata && j <= nref) {
    if(data(i).rn < ref(j).rn) {
      i++;
    } else if(data(i).rn > ref(j).rn) {
      j++;
    } else if(data(i).soe < ref(j).soe - soefudge) {
      i++;
    } else if(data(i).soe > ref(j).soe + soefudge) {
      j++;
    } else {
      keep(i) = 1;
      i++;
      j++;
    }
  }

  return data(where(keep));
}

func extract_corresponding_xyz(data, ref, fudge=, mode=, native=) {
/* DOCUMENT extracted = extract_corresponding_xyz(data, ref, fudge=, mode=,
  native=)

  This extracts points from "data" that exist in "ref".

  Unlike extract_corresponding_data, which uses soe and rn, this function uses
  the x, y, and z coordinates.

  An example use of this function:

    We have a variable named "old_mf" that contains manually filtered VEG__
    data that had been processed using rapid trajectory pnav files. We have
    another variable "new" that contains data for the same region that was
    processed using precision trajectory pnav files, but has not yet been
    filtered. If we do this:

      new_mf = extract_corresponding_data(new, old_mf);

    Then new_mf will contain point data from new, but will only contain those
    points that were present in old_mf.

  Another example:

    We have a variable "fs" that contains first surface data and a variable
    "be" that contains bare earth data. If we do this:

      be = extract_corresponding_data(be, fs);
      fs = extract_corresponding_data(fs, be);

    Both variables are now restricted to those points that existed in both
    original point clouds.

  Parameters:
    data: The source data. The return result will contain points from this
      variable.
    ref: The reference data. Points in "data" will only be kept if they are
      found in "ref".

  Options:
    fudge= This is the amount of "fudge" allowed for xyz coordinates, in cm. The
      default value is 0 cm. Changing this might be helpful if one of your
      variables was recreated from XYZ or LAS data and seems to have lost
      some coordinate resolution.
        fudge=0        0cm, default
    mode= The data mode to use for performing comparisons. Only the XYZ
      coordinates from this mode will be used for matching up points.
        mode="fs"      First surface, default
    native= Specifies whether to use the "native" values from the structure
      or not. Default is to use native values, which means integer
      comparisons.
        native=1       Attempt integer comparisons, default
        native=0       Do not attempt integer comparisons

  SEE ALSO: extract_corresponding_data, batch_extract_corresponding_data
*/
  default, fudge, 0;
  default, mode, "fs";
  default, native, 1;
  local dx, dy, dz, rx, ry, rz;

  data2xyz, data, dx, dy, dz, mode=mode, native=native;
  data = data(msort(dx, dy, dz));
  data2xyz, ref, rx, ry, rz, mode=mode, native=native;
  ref = ref(msort(rx, ry, rz));

  data2xyz, data, dx, dy, dz, mode=mode, native=native;
  data2xyz, ref, rx, ry, rz, mode=mode, native=native;

  keep = array(char(0), numberof(data));

  i = j = 1;
  ndata = numberof(data);
  nref = numberof(ref);
  while(i <= ndata && j <= nref) {
    if(dx(i) < rx(j) - fudge) {
      i++;
    } else if(dx(i) > rx(j) + fudge) {
      j++;
    } else if(dy(i) < ry(j) - fudge) {
      i++;
    } else if(dy(i) > ry(j) + fudge) {
      j++;
    } else if(dz(i) < rz(j) - fudge) {
      i++;
    } else if(dz(i) > rz(j) + fudge) {
      j++;
    } else {
      keep(i) = 1;
      i++;
      j++;
    }
  }

  return data(where(keep));
}

func extract_unique_data(data, ref, soefudge=) {
/* DOCUMENT extracted = extract_unique_data(data, ref, soefudge=)
  Extracts data that doesn't exist in ref. This is the opposite of
  extract_corresponding_data: it will extract every point that
  extract_corresponding wouldn't.

  SEE ALSO: extract_corresponding_data
*/
  default, soefudge, 0.001;
  data = data(msort(data.rn, data.soe));
  ref = ref(msort(ref.rn, ref.soe));
  keep = array(char(1), numberof(data));

  i = j = 1;
  ndata = numberof(data);
  nref = numberof(ref);
  while(i <= ndata && j <= nref) {
    if(data(i).rn < ref(j).rn) {
      i++;
    } else if(data(i).rn > ref(j).rn) {
      j++;
    } else if(data(i).soe < ref(j).soe - soefudge) {
      i++;
    } else if(data(i).soe > ref(j).soe + soefudge) {
      j++;
    } else {
      keep(i) = 0;
      i++;
      j++;
    }
  }

  return data(where(keep));
}

func scale_be_to_bathy(fs, be) {
/* DOCUMENT scale_be_to_bathy(fs, be)
  -or- scale_be_to_bathy(data)

  This performs a simple scaling to recast bare earth data as bathy data. The
  first return coordinate is treated as the water surface; the distance from
  first surface to bare earth is then scaled using the speed of light through
  water instead of through air. The modified data is returned.

  Accepts data in one of two forms. In two argument form, fs and be must each
  be arrays of [x,y,z]. In one argument form, data must be an array in an ALPS
  structure that contains be and fs data.
*/
  if(is_void(be)) {
    data = fs;
    fs = data2xyz(data, mode="fs");
    be = data2xyz(data, mode="be");
    ba = scale_be_to_bathy(fs, be);
    return xyz2data(ba, data, mode="be");
  }

  delta = be - fs;
  delta *= (CNSH2O2X/NS2MAIR);
  ba = fs + delta;
  return ba;
}

func batch_scale_be_to_bathy(srcdir, outdir=, searchstr=) {
/* DOCUMENT batch_scale_be_to_bathy, srcdir, outdir=, searchstr=
  Runs scale_be_to_bathy in batch mode. Created files will end with _spol.pbd.
  Variable names will have _spol appended. (spol stands for SPeed Of Light
  correction.)
*/
  local vname;
  default, searchstr, "*.pbd";
  srcfiles = find(srcdir, glob=searchstr);
  dstfiles = file_rootname(srcfiles) + "_spol.pbd";
  if(!is_void(outdir))
    dstfiles = file_join(outdir, file_tail(dstfiles));

  count = numberof(srcfiles);
  for(i = 1; i <= count; i++) {
    data = pbd_load(srcfiles(i), , vname);
    data = scale_be_to_bathy(data);
    pbd_save, dstfiles(i), vname+"_spol", data;
  }
}

func snell_be_to_bathy(fs, be) {
/* DOCUMENT snell_be_to_bathy(fs, be)
  -or- snell_be_to_bathy(data)

  This recasts bare earth data as bathy data by scaling for the speed of light
  and by adjusting the angle of refraction per Snell's law.  The first return
  coordinate is treated as the water surface.

  Accepts data in one of two forms. In two argument form, fs and be must each
  be arrays of [x,y,z]. In one argument form, data must be an array in an ALPS
  structure that contains be and fs data.
*/
  if(is_void(be)) {
    data = fs;
    fs = data2xyz(data, mode="fs");
    be = data2xyz(data, mode="be");
    ba = snell_be_to_bathy(fs, be);
    return xyz2data(ba, data, mode="be");
  }

  // Special handling in case input is [1,2,3] instead of [[1],[2],[3]]
  vector = 0;
  if(dimsof(fs)(1) == 1 && dimsof(fs)(2) == 3) {
    fs = transpose([fs]);
  }
  if(dimsof(be)(1) == 1 && dimsof(be)(2) == 3) {
    vector = 1;
    be = transpose([be]);
  }

  delta = be - fs;

  // Determine angle for x and y components of horizontal displacement
  horiz = sqrt((delta(,1:2)^2)(,sum));
  x = delta(,1);
  y = delta(,2);
  w = where(!y);
  if(numberof(w))
    y(w) = 1e-100;
  theta = atan(y, x);
  x = y = w = [];

  // Calculate triangle components
  dist = sqrt((delta^2)(,sum));
  height = delta(,3);
  hsign = sign(height);

  // Avoid possible divide-by-zero below
  w = where(dist == 0);
  if(numberof(w))
    dist(w) = 1e-10;
  w = [];

  // Calculate angle of incidence for laser intercepting water surface
  phi_air = acos(height/dist);
  // Use Snell's law to determine angle in water
  phi_water = asin(sin(phi_air)/KH2O);

  // Adjust distance for the speed of light in water
  dist *= (CNSH2O2X/NS2MAIR);
  // Calculate adjusted height and horizontal displacement
  height = cos(phi_water) * dist;
  horiz = sin(phi_water) * dist;

  // Calculate new deltas
  delta_x = horiz * cos(theta);
  delta_y = horiz * sin(theta);
  delta_z = height * hsign;
  delta = [delta_x, delta_y, delta_z];

  ba = fs + delta;
  if(vector && numberof(ba) == 3)
    ba = ba(*);
  return ba;
}

func batch_snell_be_to_bathy(srcdir, outdir=, searchstr=) {
/* DOCUMENT batch_snell_be_to_bathy, srcdir, outdir=, searchstr=
  Runs snell_be_to_bathy in batch mode. Created files will end with _snell.pbd.
  Variable names will have _snell appended.
*/
  local vname;
  default, searchstr, "*.pbd";
  srcfiles = find(srcdir, glob=searchstr);
  dstfiles = file_rootname(srcfiles) + "_snell.pbd";
  if(!is_void(outdir))
    dstfiles = file_join(outdir, file_tail(dstfiles));

  count = numberof(srcfiles);
  for(i = 1; i <= count; i++) {
    data = pbd_load(srcfiles(i), , vname);
    data = snell_be_to_bathy(data);
    pbd_save, dstfiles(i), vname+"_snell", data;
  }
}

func strip_flightline_edges(data, startpulse=, endpulse=) {
/* DOCUMENT func strip_flightline(data, startpulse=, endpulse=)
   amar nayegandhi 08/01/2005
   This function remove the edges of the flightlines based on pulse number.
   INPUT:
	data: Input data array
	startpulse = remove all pulses before this number.  Default = 10
	endpulse = remove all pulses after this number.  Default = 110.
 	There are 120 laser pulses per raster.  Therefore,
	1 < firstpulse < endpulse < 120.
   OUTPUT:
	returns the indices to the data after the edges are removed.
*/

  if (is_void(startpulse)) startpulse = 10;
  if (is_void(endpulse)) endpulse = 110;

  idx = where(((data.rn>>24) > startpulse) & ((data.rn>>24) < endpulse));
  return idx
}
