// vim: set ts=2 sts=2 sw=2 ai sr et:

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
  local etile, ntile, x, y;
  default, win, 5;
  default, plot, 1;

  wbkp = current_window();
  window, win;

  local emin, emax, nmin, nmax;
  mouse_bounds, emin, emax, nmin, nmax;

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
  idx = data_box(x, y, etile, etile+f, ntile-f, ntile);

  return data(idx);
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
  ply = get_poly();

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
fudge=, mode=, native=, verbose=, enableptime=) {
/* DOCUMENT batch_extract_corresponding_data, src_searchstr, ref_searchstr,
  maindir, srcdir=, refdir=, outdir=, fn_append=, vname_append=, method=,
  soefudge=, fudge=, mode=, native=, verbose=, enableptime=

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
    enableptime= Passed through to extract_corresponding_data.
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

  files = find(srcdir, searchstr=src_searchstr);

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
      data = extract_corresponding_data(data, ref, soefudge=soefudge, 
	enableptime=enableptime);
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

scratch = save(scratch, extract_corr_or_uniq_data);
func extract_corr_or_uniq_data(which, data, ref, soefudge=, mode=, enablez=, idx=,
keep=, enableptime=) {
  default, soefudge, 0.001;
  _keep = array(char(!which), numberof(data));

  i = j = 1;
  ndata = numberof(data);
  nref = numberof(ref);

  fields = [];

  if(
    has_member(data, "raster") && has_member(data, "pulse") &&
    has_member(ref, "raster") && has_member(ref, "pulse")
  ) {
    grow, fields, ["raster", "pulse"];
  } else {
    grow, fields, "rn";
  }

  if(has_member(data, "channel") && has_member(ref, "channel")) {
    grow, fields, "channel";
  }

  if((enableptime) && (has_member(data, "ptime") && has_member(ref, "ptime"))) {
    grow, fields, "ptime";
  }

  grow, fields, "soe";

  dataz = refz = [];
  if(enablez) {
    dataz = data2xyz(data, mode=mode, native=1)(..,3);
    refz = data2xyz(ref, mode=mode, native=1)(..,3);
  }

  // Can't apply sort directly to data in case they use keep=1 or idx=1.

  dsrt = msort_struct(data, fields, tiebreak=dataz);

  rsrt = msort_struct(ref, fields, tiebreak=refz);
  if(enablez) refz = refz(rsrt);
  ref = ref(rsrt);
  rsrt = [];

  nfields = numberof(fields);
  fudge = array(0., nfields);
  fudge(0) = soefudge;

  while(i <= ndata && j <= nref) {
    A = data(dsrt(i));
    B = ref(j);
    for(k = 1; k <= nfields; k++) {
      a = get_member(A, fields(k));
      b = get_member(B, fields(k));
      if(fudge(k)) {
        if(a < b - fudge(k)) {
          i++;
          goto next;
        } else if(a > b + fudge(k)) {
          j++;
          goto next;
        }
      } else {
        if(a < b) {
          i++;
          goto next;
        } else if(a > b) {
          j++;
          goto next;
        }
      }
    }

    if(enablez) {
      a = dataz(dsrt(i));
      b = refz(j);
      if(a < b) {
        i++;
        goto next;
      } else if(a > b) {
        j++;
        goto next;
      }
    }

    _keep(dsrt(i)) = which;
    i++;

    next:
  }

  if(keep) return _keep;
  if(idx) return where(_keep);
  return data(dsrt)(where(_keep(dsrt)));
}

local extract_corresponding_data;
extract_corresponding_data = closure(extract_corr_or_uniq_data, 1);
/* DOCUMENT extracted = extract_corresponding_data(data, ref, soefudge=, mode=,
   enablez=, idx=, keep=)

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

  Fields used in comparison:

    Correspondence is determined by looking at a subset of the struct's fields
    as follows:
      - if both data and ref have .raster and .pulse, they are used; otherwise,
        .rn is used
      - if both data and ref have .channel, it is used
      - .soe is always used
      - if enablez=1, then the elevation (per mode=) is used

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
    mode= Specifies the mode to use when retrieving elevation values. Only used
      when enablez=1.
    enablez= When enablez=1, elevation values are used to help determine
      correspondence.
    enableptime= Enables the use of ptime values, if there is a ptime 
      field on the data.
    enableptime=0 Ignore ptime values (default)
    enableptime=1 Include ptime in uniqness check
    idx= If idx=1, an index list into data is returned instead.
    keep= If keep=1, a "keep" list is returned: an array of bools indicating
      which values in data correspond.

  SEE ALSO: extract_unique_data, batch_extract_corresponding_data
*/

local extract_unique_data;
extract_unique_data = closure(extract_corr_or_uniq_data, 0);
/* DOCUMENT extracted = extract_unique_data(data, ref, soefudge=, mode=,
   enablez=, idx=, keep=, enableptime=)
  Extracts data that doesn't exist in ref. This is the opposite of
  extract_corresponding_data: it will extract every point that
  extract_corresponding wouldn't.

  SEE ALSO: extract_corresponding_data
*/

restore, scratch;

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
  srcfiles = find(srcdir, searchstr=searchstr);
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
  srcfiles = find(srcdir, searchstr=searchstr);
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

func strip_flightline_edges(data, startpulse=, endpulse=, idx=) {
/* DOCUMENT strip_flightline_edges(data, startpulse=, endpulse=, idx=)
  Remove the edges of the flightlines based on pulse number. The data without
  the edges will be returned.

  Parameters:
    data: Input data array with ".rn" field.
  Options:
    startpulse= Remove all pulses before and including this number.
        startpulse=10 (default)
    endpulse= Remove all pulses after and including this number.
        endpulse=110 (default)
    idx= Specifies that the indices into data should be returned instead of
      the corresponding data.
        idx=0     return data (default)
        idx=1     return indices

  There are typically 119 laser pulses per raster. Therefore, you should
  usually have 1 <= firstpulse < endpulse <= 119.
*/
  local pulse;
  default, startpulse, 10;
  default, endpulse, 110;
  default, idx, 0;
  parse_rn, data.rn, , pulse;
  w = where((startpulse < pulse) & (pulse < endpulse));
  if(idx) return w;
  return data(w);
}

func batch_strip_flightline_edges(srcdir, outdir=, searchstr=, startpulse=, endpulse=) {
/* DOCUMENT batch_strip_flightline_edges, srcdir, outdir=, searchstr=, startpulse=, endpulse=
  Applies strip_flightline_edges in batch mode.

  Output files will have the startpulse and endpulse appended to the variable
  name. With the default settings of startpulse=10, endpulse=110, files will
  thus have _s10e110 added to their names.

  Variables will have _sfe added to their names.

  Parameter:
    srcdir: The directory to find files in.
  Options:
    outdir= Specifies a directory to put output files in. If omitted, output
      files are created alongside input files.
    searchstr= Search string to use for finding files to strip.
        searchstr="*.pbd"   Default, all pbds
    startpulse= Remove all pulses before and including this number.
        startpulse=10       Default
    endpulse= Remove all pulses after and including this number.
        endpulse=110        Default
*/
  local vname;
  default, searchstr, "*.pbd";
  default, startpulse, 10;
  default, endpulse, 110;
  srcfiles = find(srcdir, searchstr=searchstr);

  sizes = double(file_size(srcfiles));
  srt = sort(sizes);
  srcfiles = srcfiles(srt);
  sizes = sizes(srt);

  if(numberof(sizes) > 1)
    sizes = sizes(cum)(2:);

  dstfiles = swrite(format="%s_s%de%d.pbd",
    file_rootname(srcfiles), startpulse, endpulse);
  if(!is_void(outdir))
    dstfiles = file_join(outdir, file_tail(dstfiles));

  write, "Stripping flightline edges...";
  status, start, msg="Stripping flightline edges...";
  count = numberof(srcfiles);
  for(i = 1; i <= count; i++) {
    data = pbd_load(srcfiles(i), , vname);
    data = strip_flightline_edges(data, startpulse=startpulse, endpulse=endpulse);
    pbd_save, dstfiles(i), vname+"_sfe", data;
    status, progress, sizes(i), sizes(0);
  }
  status, finished;
}
