// vim: set ts=2 sts=2 sw=2 ai sr et:

func datamode2name(mode, which=) {
/* DOCUMENT datamode2name(mode)
  Given a data mode suitable for data2xyz's mode= option, this returns a human
  readable string that describes it. Option which= specifies which label you
  want.
    which="data"   Name for data (default)
    which="z"      Name for z-axis
    which="zunits" Name for z-axis with units (usually meters)
*/
  default, which, "data";
  names = h_new(
    data=h_new(
      ba="Bathymetry",
      be="Bare earth",
      ch="Canopy height",
      de="Water depth",
      fint="Intensity (first return)",
      fs="First surface",
      lint="Intensity (last return)",
      mir="Mirror"
    ),
    z=h_new(
      ba="elevation",
      be="elevation",
      ch="height",
      de="depth",
      fint="intensity",
      fs="elevation",
      lint="intensity",
      mir="elevation"
    ),
    zunits=h_new(
      ba="elevation (meters)",
      be="elevation (meters)",
      ch="height (meters)",
      de="depth (meters)",
      fint="intensity",
      fs="elevation (meters)",
      lint="intensity",
      mir="elevation (meters)"
    )
  );
  if(!h_has(names, which))
    return [];
  if(!h_has(names(which), mode))
    return [];
  return names(which)(mode);
}

func datahasmode(data, mode=, xyzpassthrough=) {
/* DOCUMENT datahasmode(data, mode=, xyzpassthrough=)
  Returns a boolean 0 or 1 indicating whether data has the mode specified.

  Options:
    mode= Any mode valid for data2xyz.
    xyzpassthrough= Specifies whether numerical arrays of xyz data are
      allowed to pass.
        xyzpassthrough=0  Numerical arrays always return 0 (default)
        xyzpassthrough=1  Numerical arrays return 1 if they are valid for
                    passing through data2xyz
*/
  default, mode, "fs";
  default, xyzpassthrough, 0;

  if(is_numerical(data)) {
    if(!xyzpassthrough)
      return 0;
    dims = dimsof(data);
    if(dims(1) < 2)
      return 0;
    w = where(dims(2:) == 3);
    if(!numberof(w))
      return 0;
    has = 0;
    has = has || anyof(w == 1);
    has = has || anyof(w == 2);
    has = has || anyof(w == dims(1));
    return has;
  }

  has = 1;

  // x and y
  if(anyof(["be","lint"] == mode)) {
    has = has && has_member(data, "least");
    has = has && has_member(data, "lnorth");
  } else if("mir" == mode) {
    has = has && has_member(data, "meast");
    has = has && has_member(data, "mnorth");
  } else if(
    anyof(["ba","ch","de","fint","fs"] == mode) ||
    has_member(data, mode)
  ) {
    has = has && has_member(data, "east");
    has = has && has_member(data, "north");
  } else {
    // Unknown mode
    return 0;
  }

  // z
  if("ba" == mode) {
    has = has && has_member(data, "elevation");
    has = has && has_member(data, "depth");
  } else if("be" == mode) {
    has = has && has_member(data, "lelv");
  } else if("ch" == mode) {
    has = has && has_member(data, "elevation");
    has = has && has_member(data, "lelv");
  } else if("de" == mode) {
    has = has && has_member(data, "depth");
  } else if("fint" == mode) {
    has = has && (has_member(data, "intensity") || has_member(data, "fint"));
  } else if("fs" == mode) {
    has = has && has_member(data, "elevation");
  } else if("lint" == mode) {
    has = has && has_member(data, "lint");
  } else if("mir" == mode) {
    has = has && has_member(data, "melevation");
  }

  return has;
}

func display_data(data, mode=, axes=, cmin=, cmax=, marker=, msize=, win=, dofma=, skip=, square=, restore_win=, showcbar=, triag=, triagedges=, title=) {
/* DOCUMENT display_data, data, mode=, axes=, cmin=, cmax=, marker=, msize=,
  win=, dofma=, skip=, square=, restore_win=, showcbar=, triag=, title=

  Plots ALPS data.

  Parameter:
    data: Must be an array in an ALPS structure (such as FS, VEG__, GEO, ...)

  Options:
    mode= The plotting mode to use; can be any value accepted by data2xyz.
      Examples:
        mode="fs" (default)
        mode="be"
        mode="ba"
    axes= Specifies the axes layout for the plot. Possible options:
        axes="xyz" x is east, y is north, colorbar is elev (default)
        axes="xzy" x is east, y is elev, colorbar is north
        axes="yzx" x is north, y is elev, colorbar is east
    cmin= Minimum value for colorbar. Default is minimum value.
    cmax= Maximum value for colorbar. Default is maximum value.
    marker= Marker to use, see plcm. Default is 1.
    msize= Size of marker, see plcm. Default is 1.
    win= Window to plot in. Defaults to current window
    dofma= Specifies whether the plot should get cleared before plotting.
        dofma=0  No clear (default)
        dofma=1  Clear
    skip= Specifies a skip factor to subsample the data by.
        skip=1   Use all data (default)
        skip=2   Use every 2nd point, or 1/2 of data
        skip=10  Use every 10th point, or 1/10 of data
    square= Specifies which kind of limits to use.
        square=1    Units in both axes have same size. (default)
        square=0    Units may vary per axis, resulting in non-square squares.
    restore_win= Specifies whether to leave the active window as win= or
      change it back to what it was before the function was called.
        restore_win=0  Leave window set to the one we plotted in (default)
        restore_win=1  Restore window to whatever it was before we plotted
    showcbar= Allows you to automatically plot the showcbar.
        colorbar=0     Do not show colorbar. (default)
        colorbar=1     Include colorbar.
    title= A title to add to the plot, using pltitle. If omitted, no title is
      added.
*/
  local x, y, z, X, Y, Z;
  default, mode, "fs";
  default, dofma, 0;
  default, axes, "xyz";
  default, square, 1;
  default, restore_win, 0;
  default, showcbar, 0;

  if(is_void(win)) win = window();
  wbkp = current_window();
  window, win;
  if(dofma)
    fma;

  if(structeq(structof(data), ZGRID) && noneof(axes == ["xzy", "yxz"])) {
    display_grid, data, cmin=cmin, cmax=cmax;
  } else {
    data2xyz, data, x, y, z, mode=mode;
    data = [];

    // Extract points of interest (apply w and skip)
    X = x(::skip);
    Y = y(::skip);
    Z = z(::skip);
    x = y = z = [];

    // xyz -> xzy
    if(anyof(axes == ["xzy", "yzx"]))
      swap, Z, Y;
    // xzy -> yzx
    if(axes == "yzx")
      swap, Z, X;

    if(triag) {
      plot_tri_data, [X,Y,Z], cmin=cmin, cmax=cmax, dofma=0, edges=triagedges,
        maxside=50, maxarea=200;
    } else {
      plcm, Z, Y, X, msize=msize, marker=marker, cmin=cmin, cmax=cmax;
    }
  }

  limits, square=square;
  if(showcbar)
    colorbar, cmin, cmax;
  if(!is_void(title)) {
    title = regsub("_", title, "!_", all=1);
    pltitle, title;
  }

  if(restore_win)
    window_select, wbkp;
}

func struct_cast(&data, dest, verbose=, special=) {
/* DOCUMENT result = struct_cast(data, dest)
  result = struct_cast(data)
  struct_cast, data, dest
  struct_cast, data

  Converts an array from one structure to another structure. This will work on
  any arbitrary pair of structures, provided they have fields in common.
  However, it has additional specialized functionality for working with ALPS
  raster and point data structures.

  If dest is provided, it should be a structure you would like the data
  converted to. Any field present in both the source and destination will be
  copied as is.

  If dest is omitted, then the data will be converted based on its current
  structure. The conversion is knows to make are:
    GEOALL   -> GEO
    VEG_ALL  -> VEG_
    VEG_ALL_ -> VEG__
    R        -> FS
  If the data is not in any of those formats, then nothing is done to it and
  it is returned as is. (Thus, it's fairly safe to run this on data of any
  type.)

  If called as a subroutine, data is updated in place. Otherwise, returns a
  new copy.

  This is intended primarily to cast raster formats into point formats.
  However, it's also smart enough to do the reverse.
    > foo = array(FS, 240);
    > bar = struct_cast(foo, R);
    > info, bar;
     array(R,2)
  Please note however that the point format HAS to be conformable with the
  raster format. In other words, numberof(data) must be divisible by 120.

  Certain pairs of structures have specialized functionality. You can disable
  this functionality by specifying special=0. Here are the conversions with
  special functionality:
    LFP_VEG -> FS, VEG__, VEG_, VEG, GEO
      LFP_VEG uses pointers for .elevation; this dereferences them and stores
      to .elevation creating multiple points (which means that
      numberof(output) might be larger than numberof(input)). Also, VEG__,
      VEG_, and VEG will populate .lnorth, .least, and .lelev with .north,
      .east, and .elevation. Also, GEO will populate .depth based the first
      .elevation value for each pointer.
    FS -> LFP_VEG
      Populates the pointers using just the single FS elevation for each
      point.
    VEG__, VEG_, VEG -> LFP_VEG
      Populates the pointers using the first and last return for each point.
    GEO -> LFP_VEG
      Populates the pointers using the surface and depth elevations for each
      point.
    VEG__, VEG_, VEG -> GEO
      Sets .north and .east from .lnorth and .least. Sets .depth based on
      .elevation - .lelv. Sets .first_peak and .bottom_peak from .fint and
      .lint.
    GEO -> VEG__, VEG_, VEG
      Sets .lnorth and .least from .north and .east. Sets .lelv from
      .elevation - .depth. Sets .fint and .lint from .first_peak and
      .bottom_peak.
    FS -> GEO
      Sets .bottom_peak from .intensity
    GEO -> FS
      Sets .elevation from .elevation - .depth. Sets .intensity from
      .bottom_peak.
    ZGRID -> FS, GEO
      Sets .east, .north, and .elevation based on the result of
      data2xyz(input). (For GEO, .depth is left as 0.)
    ZGRID -> VEG__, VEG_, VEG
      Sets .east, .north, and .elevation based on the result of
      data2xyz(input). Sets .least, .lnorth, and .lelv to match .east,
      .north, and .elevation.

  Additionally, fields named "sod" and "somd" are treated as equivalent.

  By default, this function is silent. Use verbose=1 to make it chatty.
*/
  local x, y, z, raster, pulse;

  default, verbose, 0;
  default, special, 1;

  // If dest wasn't provided, try to guess it.
  if(is_void(dest)) {
    src = nameof(structof(data));
    mapping = h_new(
      GEOALL=GEO,
      VEG_ALL=VEG_,
      VEG_ALL_=VEG__,
      R=FS
    );
    if(h_has(mapping, src))
      dest = mapping(src);
    else
      return data;
  }

  if(verbose)
    write, format=" Converting %s to %s\n", nameof(structof(data)), nameof(dest);

  if(special) {
    src = structof(data);
    dst = dest;

    // LFP_VEG requires special treatment since once of its members is a pointer
    if(structeq(src, LFP_VEG) && structeqany(dst, FS, VEG__, VEG_, VEG, GEO)) {
      data = data(where(data.elevation));
      result = array(dst, dimsof(data));
      result.north = data.north;
      result.east = data.east;
      for(i = 1; i <= numberof(data); i++) {
        result.elevation = (*data.elevation(i))(1);
      }

      if(structeqany(dst, VEG__, VEG_, VEG)) {
        result.lnorth = result.north;
        result.least = result.east;
        for(i = 1; i <= numberof(data); i++) {
          result.lelv = (*data.elevation(i))(0);
        }
      }

      if(structeq(dst, GEO)) {
        for(i = 1; i <= numberof(data); i++) {
          result.depth = result.elevation - (*data.elevation(i))(0);
        }
      }

      if(am_subroutine())
        eq_nocopy, data, result;
      return result;
    }

    if(structeqany(src, FS, VEG__, VEG_, VEG, GEO) && structeq(dst, LFP_VEG)) {
      result = array(dst, dimsof(data));
      result.north = data.north;
      result.east = data.east;
      for(i = 1; i <= numberof(data); i++) {
        if(structeqany(src, VEG__, VEG_, VEG)) {
          result.elevation = &[data.elevation, data.lelv];
        } else if(structeq(src, GEO)) {
          result.elevation = &[data.elevation, data.elevation - data.depth];
        } else {
          result.elevation = &[data.elevation];
        }
      }
      if(am_subroutine())
        eq_nocopy, data, result;
      return result;
    }
  }

  // Figure out what kind of dimensions the destination wants
  sample = dest();
  fields = get_members(sample);
  dims = dimsof(get_member(sample, fields(1)));
  sample = fields = [];

  // Get information about our source data
  fields = get_members(data);
  count = numberof(get_member(data, fields(1)));

  // Figure out how we'll have to contort the source to match the dest
  divisor = 1;
  for(i = 2; i <= numberof(dims); i++)
    divisor *= dims(i);
  count /= divisor;
  dims(1)++;
  grow, dims, count;

  // Create the result, filling it as well as we can
  result = array(dest, count);
  for(i = 1; i <= numberof(fields); i++) {
    if(has_member(result, fields(i)))
      get_member(result, fields(i)) = reform(get_member(data, fields(i)), dims);
  }

  // Special cases
  if(special) {
    src = structof(data);
    dst = structof(result);

    if(structeq(dst, GEO) && structeqany(src, VEG__, VEG_, VEG)) {
      result.north = data.lnorth;
      result.east = data.least;
      result.depth = data.lelv - data.elevation;
      result.first_peak = data.fint;
      result.bottom_peak = data.lint;
    }

    if(structeqany(dst, VEG__, VEG_, VEG) && structeq(src, GEO)) {
      result.lnorth = data.north;
      result.least = data.east;
      result.lelv = data.elevation + data.depth;
      result.fint = data.first_peak;
      result.lint = data.bottom_peak;
    }

    if(structeq(dst, GEO) && structeq(src, FS)) {
      result.bottom_peak = data.intensity;
    }

    if(structeq(dst, FS) && structeq(src, GEO)) {
      result.elevation = data.elevation - data.depth;
      result.intensity = data.bottom_peak;
    }

    if(structeqany(dst, FS, VEG__, VEG_, VEG, GEO) && structeq(src, ZGRID)) {
      data2xyz, data, x, y, z;
      result = array(dst, numberof(x));
      result.east = x * 100 + .5;
      result.north = y * 100 + .5;
      result.elevation = z * 100 + .5;

      if(structeqany(dst, VEG__, VEG_, VEG)) {
        result.least = result.east;
        result.lnorth = result.north;
        result.lelv = result.elevation;
      }
    }
  }

  // If result has RN and unpopulated RASTER/PULSE, then populate RASTER/PULSE.
  if(
    has_member(result, "rn") &&
    has_member(result, "raster") && has_member(result, "pulse") &&
    anyof(result.rn) && noneof(result.raster) && noneof(result.pulse)
  ) {
    parse_rn, result.rn, raster, pulse;
    result.raster = raster;
    result.pulse = pulse;
  }

  if(has_member(data, "sod") && has_member(result, "somd")) {
    result.somd = data.sod;
  }
  if(has_member(data, "somd") && has_member(result, "sod")) {
    result.sod = data.somd;
  }

  if(am_subroutine())
    eq_nocopy, data, result;
  else
    return result;
}

func batch_struct_cast(dir, dest_struct, searchstr=, files=, outdir=, special=,
suffix_remove=, suffix=) {
/* DOCUMENT batch_struct_cast, dir, dest_struct, searchstr=, files=, outdir=,
  special=, suffix_remove=, suffix=

  Runs struct_cast in batch mode.

  Parameters:
    dir: The directory containing the files to load.
    dest_struct: Structure to cast the files to. (See struct_cast.)

  Options:
    searchstr= Search string used to find files.
        searchstr= "*.pbd"      (Default)
    files= Array of files to process. If provides, suppresses use of dir and
      searchstr=.
    outdir= Output directory where the converted files should go. Default is
      in the same as the source directory.
    special= Enables special mode (on by default), see struct_cast.
    suffix_remove= A suffix to remove from all files.
        suffix_remove=".pbd"    (Default)
    suffix= A suffix to add to all files
        suffix=".pbd"           (Default)
*/
  default, searchstr, "*.pbd";
  default, suffix_remove, ".pbd";
  default, suffix, ".pbd";
  if(is_void(files)) {
    files = find(dir, searchstr=searchstr);
    if(is_void(files)) {
      write, "No files found.";
      return;
    }
    sizes = double(file_size(files));
    srt = sort(-sizes);
    files = files(srt);
    sizes = sizes(srt);
    srt = [];
  } else {
    sizes = double(file_size(files));
  }
  if(numberof(sizes) > 1)
    sizes = sizes(cum)(2:);

  local err, vname;
  count = numberof(files);
  t0 = tp = array(double, 3);
  timer, t0;
  for(i = 1; i <= count; i++) {
    data = pbd_load(files(i), err, vname);
    if(strlen(err))
      continue;

    outfile = files(i);
    if(!is_void(outdir))
      outfile = file_join(outdir, file_tail(outfile));
    if(strpart(outfile, 1-strlen(suffix_remove):) == suffix_remove)
      outfile = strpart(outfile, :-strlen(suffix_remove));
    outfile += suffix;

    struct_cast, data, dest_struct, special=special;
    pbd_save, outfile, vname, data;
    data = [];

    timer_remaining, t0, sizes(i), sizes(0), tp, interval=5;
  }
  timer_finished, t0;
}

func uniq_data(data, idx=,  mode=, forcesoe=, forcexy=, enableptime=, enablez=,
optstr=) {
/* DOCUMENT uniq_data(data, idx=, mode=, forcesoe=, forcexy=, enablez=,
   enableptime=, optstr=)
  Returns the unique data in the given array.

  By default, uniqueness is determined based on the .soe field. When using the
  .soe field, points with the same soe value are considered duplicates. If the
  .channel field is present, then uniqueness is determined based on the
  combination of [.soe, .channel].

  If the .soe field is not present, if all soe values are the same, or if
  forcexy=1, then the x and y coordinates of the data are used instead. In
  this case, points located at the same x,y coordinate are considered
  duplicates.

  If enablez=1, then elevation is used to help determine uniqueness in addition
  to .soe, [.soe, .channel], or [x, y].

  This allows the function to work on almost any kind of data:
    * data generated within ALPS
    * data imported from XYZ, LAS, etc. and stored in an ALPS array, but
      missing some or all auxiliary fields
    * XYZ data that is not in an ALPS data structure

  Options that change what gets returned:
    idx= Returns index into data.

    These are equivalent:
      result = uniq_data(data);
      result = data(uniq_data(data, idx=1));

  Options that change how uniqueness is determined:
    forcesoe= Forces the use of soe values, even if it's determined to be
      inappropriate.
        forcesoe=0  Do not force use of soe (default)
        forcesoe=1  Force use of soe
    forcexy= Forces the use of x/y values.
        forcexy=0   Do not force use of x/y values (default)
        forcexy=1   Force use of x/y values.
    enablez= Enables the use of z values.
        enablez=0   Ignore z values (default)
        enablez=1   Include z values in uniqueness check
    enableptime= Enables the use of ptime values, if there is a ptime field on
      the data.
        enableptime=0   Ignore ptime values (default)
        enableptime=1   Include ptime values in uniqueness check
    mode= Specifies which data mode to use to extract x/y/z points when using
      them to determine uniqueness.
        mode="fs"   Default

  Option for calling functions to pass through:
    optstr= Provides an option string. This can contain any of the key/value
      pairs accepted by this function, but provided as a string. For example:
        optstr="forcexy=1 enablez=1 mode=fs"
      Unknown key names are ignored. If optstr is not a string, it is ignored.
      This makes it slightly easier for calling functions to juggle the option.
      For example, a calling function may have a uniq= option that normally
      accepts 1 or 0; you can extend it to now accept an option string. Passing
      optstr=uniq will not cause a problem even if uniq=1.
*/
  local w, x, y, z, keep, srt, dupe;
  default, idx, 0;
  default, forcesoe, 0;
  default, forcexy, 0;
  default, enablez, 0;

  if(is_string(optstr)) {
    opt = parse_keyval(optstr);
    if(opt(*,"idx")) idx = atoi(opt.idx);
    if(opt(*,"forcesoe")) forcesoe = atoi(opt.forcesoe);
    if(opt(*,"forcexy")) forcexy = atoi(opt.forcexy);
    if(opt(*,"enablez")) enablez = atoi(opt.enablez);
    if(opt(*,"enableptime")) enableptime = atoi(opt.enableptime);
    if(opt(*,"mode")) mode = opt.mode;
  }

  // Edge case
  if(is_void(data))
    return [];
  // Edge case
  if(numberof(data) == 1)
    return idx ? [1] : data;

  if(forcesoe && !has_member(data, "soe"))
    error, "You cannot use forcesoe=1 when the data does not have an soe field.";

  if(forcesoe && forcexy)
    error, "You cannot use both of forcesoe=1 and forcexy=1 together."

  usesoe = 1;
  if(usesoe && forcexy)
    usesoe = 0;
  if(usesoe && !has_member(data, "soe"))
    usesoe = 0;
  if(usesoe && !forcesoe && allof(data.soe == data.soe(1)))
    usesoe = 0;

  local x, y, z;
  if(enablez || !usesoe)
    data2xyz, data, x, y, z, native=1, mode=mode;

  obj = save();
  if(usesoe) {
    save, obj, string(0), data.soe;
    if(usesoe && has_member(data, "channel"))
      save, obj, string(0), data.channel;
  } else {
    save, obj, x, y;
  }
  if(enablez)
    save, obj, string(0), z;
  if(enableptime && has_member(data, "ptime"))
    save, obj, string(0), data.ptime;

  w = munique_obj(obj);
  if(idx) return w;
  if(is_numerical(data)) return [x(w), y(w), z(w)];
  return data(w);
}

func sortdata(data, mode=, method=, desc=) {
/* DOCUMENT sortdata(data, mode=, method=, desc=)
  Sorts a data array.

  Parameter:
    data: An array of data suitable for data2xyz.

  Options:
    mode= A mode suitable for data2xyz.
    method= The method to use for sorting. Valid values:
        method="soe"      Sort by the .soe field
        method="x"        Sort using x values
        method="y"        Sort using y values
        method="z"        Sort using z values
        method="random"   Randomize sequence
    desc= Indicates that the data should be in descending order.
        desc=0      Sort ascending order (default)
        desc=1      Sort descending order
*/
  default, method, "y";
  default, desc, 0;
  local tmp, idx;

  if(method == "soe") {
    idx = sort(data.soe);
  } else if(method == "x") {
    data2xyz, data, tmp, mode=mode;
    idx = sort(tmp);
  } else if(method == "y") {
    data2xyz, data, , tmp, mode=mode;
    idx = sort(tmp);
  } else if(method == "z") {
    data2xyz, data, , , tmp, mode=mode;
    idx = sort(tmp);
  } else if(method == "random") {
    data2xyz, data, tmp;
    idx = sort(random(numberof(tmp)));
  }
  tmp = [];
  if(is_void(idx))
    error, "Invalid method.";

  if(desc) idx = idx(::-1);

  if(is_numerical(data)) {
    local x, y, z;
    data2xyz, data, x, y, z;
    return [x(idx), y(idx), z(idx)];
  } else {
    return data(idx);
  }
}
