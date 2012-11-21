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
// Original David Nagle 2009-01-25
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
// Original David Nagle 2010-02-03
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
  if(anyof(["ba","ch","de","fint","fs"] == mode)) {
    has = has && has_member(data, "east");
    has = has && has_member(data, "north");
  } else if(anyof(["be","lint"] == mode)) {
    has = has && has_member(data, "least");
    has = has && has_member(data, "lnorth");
  } else if("mir" == mode) {
    has = has && has_member(data, "meast");
    has = has && has_member(data, "mnorth");
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

func data2xyz(data, &x, &y, &z, mode=, native=) {
/* DOCUMENT data2xyz, data, x, y, z, mode=, native=
  result = data2xyz(data, mode=, native=)

  Extracts the x, y, and z coordinates from data for the given mode. The mode
  must be compatible with the data, and defaults to "fs".

  Arguments x, y, and z are output arguments. Alternately, the function can
  also return result=[x, y, z]; be sure to index this as result(..,1),
  result(..,2) and result(..,3) on the off chance that the input data is
  multidimensional.

  Any values stored in data as centimeters will normally be returned in
  meters. If you would like them returned in their native form (as
  centimeters) use native=1.

  Valid values for mode, and their corresponding meanings:

    mode="ba" (Bathymetry)
      x = .east
      y = .north
      z = .elevation + .depth

    mode="be" (Bare earth)
      x = .least
      y = .lnorth
      z = .lelv

    mode="ch" (Canopy height)
      x = .east
      y = .north
      z = .elevation - .lelv

    mode="de" (Water depth)
      x = .east
      y = .north
      z = .depth

    mode="fint" (First return intensity)
      x = .east
      y = .north
      z = .intensity OR .fint (whichever is available)

    mode="fs" (First return)
      x = .east
      y = .north
      z = .elevation

    mode="lint" (Last return intensity)
      x = .least
      y = .lnorth
      z = .lint

    mode="mir" (Mirror)
      x = .meast
      y = .mnorth
      z = .melevation

  This function can also handle a number of special cases for input:

  - Multi-dimensional numerical arrays. The data must be an array with two or
    more dimensions, and either the first, second, or last dimension must have
    a size of three. The first of those dimensions with size three will be used
    to break the array up into x, y, z components.

  - Gridded data in ZGRID structure. This data will be converted into a
    multi-dimensional numerical array and then handled as described above.

  - Objects of the pcobj class. Only "be", "ba", and "fs" modes are supported.
    The points returned will be those corresponding to the "bare_earth",
    "submerged_topo", and "first_surface" classes respectively.

  - Data in the POINTCLOUD_2PT structure. This data is handled similarly to the
    tranditional structures, except that "native=" has no effect since the data
    is natively in floating point format.
*/
// Original David Nagle 2009-01-25
  default, mode, "fs";
  default, native, 0;
  x = y = z = [];

  // Special case to allow XYZ pass through
  if(is_numerical(data))
    return splitary(unref(data), 3, x, y, z);

  // Special case for gridded data
  if(structeq(structof(data), ZGRID)) {
    if(numberof(data) > 1) {
      ptrs = array(pointer, numberof(data));
      for(i = 1; i <= numberof(data); i++)
        ptrs(i) = &transpose(data2xyz(data(i)));
      merged = merge_pointers(unref(ptrs));
      merged = reform(merged, [2, 3, numberof(merged)/3]);
      return splitary(unref(merged), 3, x, y, z);
    } else {
      z = *(data.zgrid);
      x = y = array(double, dimsof(z));
      xmax = data.xmin + dimsof(x)(2) * data.cell;
      ymax = data.ymin + dimsof(y)(3) * data.cell;
      hc = 0.5 * data.cell;
      x(,) = span(data.xmin+hc, xmax-hc, dimsof(x)(2))(,-);
      y(,) = span(data.ymin+hc, ymax-hc, dimsof(y)(3))(-,);
      w = where(z != data.nodata);
      if(numberof(w)) {
        x = x(w);
        y = y(w);
        z = z(w);
      } else {
        x = y = z = [];
      }
      return am_subroutine() ? [] : [x, y, z];
    }
  }

  // Special case for pcobj
  if(is_obj(data) && data(*,"class")) {
    class = where(["be","ba","fs"] == mode);
    if(!numberof(class))
      return [];
    class = ["bare_earth", "submerged_topo", "first_surface"](class)(1);
    return splitary(data(xyz, class), 3, x, y, z);
  }

  // Special handling for POINTCLOUD_2PT
  if(structeq(structof(data), POINTCLOUD_2PT)) {
    if(anyof(["ba","be","ch","de","lint"] == mode)) {
      x = data.lx;
      y = data.ly;
    } else if(anyof(["fint","fs"] == mode)) {
      x = data.fx;
      y = data.fy;
    } else if(mode == "mir") {
      x = data.mx;
      y = data.my;
    } else {
      error, "Unknown mode.";
    }

    if(anyof(["ba","be"] == mode)) {
      z = data.lz;
    } else if(mode == "ch") {
      z = data.fz - data.lz;
    } else if(mode == "de") {
      z = data.lz - data.fz;
    } else if(mode == "fint") {
      z = data.fint;
    } else if(mode == "fs") {
      z = data.fz;
    } else if(mode == "lint") {
      z = data.lint;
    } else if(mode == "mir") {
      z = data.mz;
    }

    if(am_subroutine()) return;
    return [x, y, z];
  }

  // Most data modes use east/north for x/y. Only bare earth and be intensity
  // use least/lnorth.
  if(anyof(["ba","ch","de","fint","fs"] == mode)) {
    x = data.east;
    y = data.north;
  } else if(anyof(["be","lint"] == mode)) {
    x = data.least;
    y = data.lnorth;
  } else if("mir" == mode) {
    x = data.meast;
    y = data.mnorth;
  } else {
    error, "Unknown mode.";
  }

  // Each mode works differently for z.
  if("ba" == mode) {
    z = data.elevation + data.depth;
  } else if("be" == mode) {
    z = data.lelv;
  } else if("ch" == mode) {
    z = data.elevation - data.lelv;
  } else if("de" == mode) {
    z = data.depth;
  } else if("fint" == mode) {
    if(has_member(data, "intensity"))
      z = data.intensity;
    else
      z = data.fint;
  } else if("fs" == mode) {
    z = data.elevation;
  } else if("lint" == mode) {
    z = data.lint;
  } else if("mir" == mode) {
    z = data.melevation;
  }

  if(!native) {
    x = unref(x) * 0.01;
    y = unref(y) * 0.01;
    if(anyof(["ba","be","ch","de","fs","mir"] == mode))
      z = unref(z) * 0.01;
  }

  // Only want to do this if it's not a subroutine, to avoid the memory
  // overhead of creating an unnecessary array.
  if(!am_subroutine())
    return [x, y, z];
}

func xyz2data(_x, &_y, _z, &data, mode=, native=) {
/* DOCUMENT xyz2data, x, y, z, data, mode=, native=
  result = xyz2data(x, y, z, mode=, native=)
  result = xyz2data(x, y, z, data, mode=, native=)
  result = xyz2data(x, y, z, struct, mode=, native=)
  xyz2data, xyz, data, mode=, native=
  result = xyz2data(xyz, mode=, native=)
  result = xyz2data(xyz, data, mode=, native=)
  result = xyz2data(xyz, struct, mode=, native=)

  Converts x, y, z coordinates into ALPS data. This can be called in many
  ways.

  xyz2data, x, y, z, data, mode=, native=
    In the subroutine case, data will be updated to contain the given x, y, z
    data. If it is already an array of ALPS data, it will be updated in
    place. If it's void, then a new array will be created based on the given
    mode.

  result = xyz2data(x, y, z, mode=, native=)
    Creates a new array of ALPS data based on mode, populates it with x, y,
    z, and returns it.

  result = xyz2data(x, y, z, data, mode=, native=)
    If given an array data, then it will be used instead of creating an empty
    array. The data will NOT be updated in place. Instead a copy will be
    made, and the copy will be updated with the x, y, z data.

  result = xyz2data(x, y, z, struct, mode=, native=)
    You can also specify the structure you want to use (FS, VEG__, etc.), if
    you want to force it to use something other the mode's default.

  Additionally, in any of the four above cases, the x, y, and z arguments can
  be consolidated into a single argument. That single argument must be an
  array with two or more dimensions where either the first, second, or last
  dimension is three dimensional. The first such dimension will be used to
  split out x, y, and z.

  In all cases, mode= defaults to "fs".

  When storing coordinates to fields defined as centimeters, the values will
  be converted from meters to centimeters. If you're actually passing the
  native centimeter values, use native=1 to store them directly.

  Valid values for mode are as follows. See data2xyz for more details.
    mode="ba"   Bathymetry
    mode="be"   Bare earth"
    mode="ch"  Canopy height
    mode="de"   Water depth
    mode="fint" First intensity
    mode="fs"   First surface (default)
    mode="lint" Last intensity
    mode="mir"  Mirror location

  Some modes have values based on composite fields. In these cases, a decision
  must be made on how to store the input. This function behaves as follows.

    mode="ch" (Canopy height)
      If none of .north are nonzero,
        then .east=x, .north=y
      If none of .lnorth are nonzero,
        then .least=x, .lnorth=y
      If any of .elevation are nonzero,
        then .lelv = .elevation - z
        otherwise .elevation = .lelv + z

    mode="ba" (Bathymetry)
      .depth = z - .elevation

*/
// Original David Nagle 2009-01-26
  local x, y, z, working;
  default, mode, "fs";
  default, native, 0;

  // Extract arguments
  if(is_void(_z)) {
    splitary, unref(_x), 3, x, y, z;
    working = (_y);
  } else {
    x = unref(_x);
    y = (_y);
    z = unref(_z);
    working = (data);
  }

  if(am_subroutine() && is_struct(data)) {
    // Safeguarding so that nobody accidentally clobbers VEG__, FS, etc.
    error, "When using xyz2data as a subroutine, data cannot be a struct reference.";
  }

  if(is_void(working)) {
    if(anyof(["ba","de"] == mode)) {
      working = array(GEO, numberof(x));
    } else if(anyof(["be","ch","lint"] == mode)) {
      working = array(VEG__, numberof(x));
    } else if(anyof(["fs","fint","mir"] == mode)) {
      working = array(FS, numberof(x));
    }
  } else {
    if(is_struct(working))
      working = array(working, numberof(x));
    else
      working = (working);
  }

  // POINTCLOUD_2PT gets special handling
  if(structeq(structof(working), POINTCLOUD_2PT)) {
    if(anyof(["ba","be","de","lint"] == mode)) {
      working.lx = x;
      working.ly = y;
    } else if("ch" == mode) {
      if(noneof(working.fy)) {
        working.fx = x;
        working.fy = y;
      }
      if(noneof(working.ly)) {
        working.lx = x;
        working.ly = y;
      }
    } else if(anyof(["fint","fs"] == mode)) {
      working.fx = x;
      working.fy = y;
    } else if("mir" == mode) {
      working.mx = x;
      working.my = y;
    }

    if(anyof(["ba","be"] == mode)) {
      working.lz = z;
    } else if(mode == "ch") {
      if(anyof(working.fz))
        working.lz = working.fz - z;
      else
        working.fz = working.lz + z;
    } else if(mode == "de") {
      working.lz = working.fz + z;
    } else if(mode == "fint") {
      working.fint = z;
    } else if(mode == "fs") {
      working.fz = z;
    } else if(mode == "lint") {
      working.lint = z;
    } else if(mode == "mir") {
      working.mz = z;
    }

    if(am_subroutine()) {
      if(is_void(_z))
        eq_nocopy, _y, working;
      else
        eq_nocopy, data, working;
      return;
    } else {
      return working;
    }
  }

  if(!native) {
    x = long(unref(x) * 100);
    y = long(unref(y) * 100);
    if(anyof(["ba","be","ch","de","fs","mir"] == mode))
      z = long(unref(z) * 100);
  }

  // Most data modes use east/north for x/y. Only bare earth and be intensity
  // use least/lnorth.
  if(anyof(["ba","de","fint","fs"] == mode)) {
    working.east = x;
    working.north = y;
  } else if(anyof(["be","lint"] == mode)) {
    working.least = x;
    working.lnorth = y;
  } else if("ch" == mode) {
    if(noneof(working.north)) {
      working.east = x;
      working.north = y;
    }
    if(noneof(working.lnorth)) {
      working.least = x;
      working.lnorth = y;
    }
  } else if("mir" == mode) {
    working.meast = x;
    working.mnorth = y;
  } else {
    error, "Unknown mode.";
  }

  // Each mode works differently for z.
  if("ba" == mode) {
    working.depth = z - working.elevation;
  } else if("be" == mode) {
    working.lelv = z;
  } else if("ch" == mode) {
    if(anyof(working.elevation))
      working.lelv = working.elevation - z;
    else
      working.elevation = working.lelv + z;
  } else if("de" == mode) {
    working.depth = z;
  } else if("fint" == mode) {
    if(has_member(working, "intensity"))
      working.intensity = z;
    else
      working.fint = z;
  } else if("fs" == mode) {
    working.elevation = z;
  } else if("lint" == mode) {
    working.lint = z;
  } else if("mir" == mode) {
    working.melevation = z;
  }

  if(am_subroutine()) {
    if(is_void(_z))
      eq_nocopy, _y, working;
    else
      eq_nocopy, data, working;
  } else {
    return working;
  }
}

func display_data(data, mode=, axes=, cmin=, cmax=, marker=, msize=, win=, dofma=, skip=, square=, restore_win=, showcbar=, triag=, triagedges=) {
/* DOCUMENT display_data, data, mode=, axes=, cmin=, cmax=, marker=, msize=,
  win=, dofma=, skip=, square=, restore_win=, showcbar=, triag=

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
*/
// Original David Nagle 2009-01-25
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
    data2xyz, unref(data), x, y, z, mode=mode;

    // Extract points of interest (apply w and skip)
    X = unref(x)(::skip);
    Y = unref(y)(::skip);
    Z = unref(z)(::skip);

    // xyz -> xzy
    if(anyof(axes == ["xzy", "yzx"]))
      swap, Z, Y;
    // xzy -> yzx
    if(axes == "yzx")
      swap, Z, X;

    if(triag) {
      v = triangulate(X, Y);
      plot_triag_mesh, [X,Y,Z], v, cmin=cmin, cmax=cmax, dofma=0, edges=triagedges;
    } else {
      plcm, unref(Z), unref(Y), unref(X), msize=msize, marker=marker,
        cmin=cmin, cmax=cmax;
    }
  }

  limits, square=square;
  if(showcbar)
    colorbar, cmin, cmax;

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
    GEOALL, VEG_ALL, VEG_ALL_, R, ZGRID -> POINTCLOUD_2PT
      These are handled as a two-step process. Specifically:
        GEOALL -> GEO -> POINTCLOUD_2PT
        VEG_ALL -> VEG_ -> POINTCLOUD_2PT
        VEG_ALL_ -> VEG__ -> POINTCLOUD_2PT
        R -> FS -> POINTCLOUD_2PT
        ZGRID -> FS -> POINTCLOUD_2PT
    POINTCLOUD_2PT -> GEOALL, VEG_ALL, VEG_ALL_, R
      These are handled as a two-step process. Specifically:
        POINTCLOUD_2PT -> GEO -> GEOALL
        POINTCLOUD_2PT -> VEG_ -> VEG_ALL
        POINTCLOUD_2PT -> VEG__ -> VEG_ALL_
        POINTCLOUD_2PT -> FS -> R
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

  By default, this function is silent. Use verbose=1 to make it chatty.
*/
// Original David Nagle 2010-02-05
  local x, y, z;

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

    if(structeqany(src, GEOALL, VEG_ALL, VEG_ALL_, R) && structeq(dst, POINTCLOUD_2PT)) {
      struct_cast, data, verbose=verbose;
      src = structof(data);
    }

    if(structeq(src, ZGRID) && structeq(dst, POINTCLOUD_2PT)) {
      struct_cast, data, FS, verbose=verbose;
      src = structof(data);
    }

    if(structeq(src, POINTCLOUD_2PT)) {
      if(structeq(dst, GEOALL)) {
        struct_cast, data, GEO, verbose=verbose;
      } else if(structeq(dst, VEG_ALL)) {
        struct_cast, data, VEG_, verbose=verbose;
      } else if(structeq(dst, VEG_ALL_)) {
        struct_cast, data, VEG__, verbose=verbose;
      } else if(structeq(dst, R)) {
        struct_cast, data, FS, verbose=verbose;
      }
      src = structof(data);
    }

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

    if(structeq(src, POINTCLOUD_2PT)) {
      if(has_member(result, "meast"))
        result.meast = data.mx * 100;
      if(has_member(result, "mnorth"))
        result.mnorth = data.my * 100;
      if(has_member(result, "melevation"))
        result.melevation = data.mz * 100;
      if(has_member(result, "east"))
        result.east = data.fx * 100;
      if(has_member(result, "north"))
        result.north = data.fy * 100;
      if(has_member(result, "elevation"))
        result.elevation = data.fz * 100;
      if(has_member(result, "least"))
        result.least = data.lx * 100;
      if(has_member(result, "lnorth"))
        result.lnorth = data.ly * 100;
      if(has_member(result, "lelv"))
        result.lelv = data.lz * 100;
      if(has_member(result, "intensity"))
        result.intensity = data.fint;
        // This only applied to EAARL-A
        //result.intensity = data.fint + 300 * (data.channel-1);
      if(has_member(result, "first_peak"))
        result.first_peak = data.fint;
      if(has_member(result, "bottom_peak"))
        result.bottom_peak = data.lint;

      if(structeq(dst, GEO)) {
        result.east = data.lx * 100;
        result.north = data.ly * 100;
        result.depth = (data.lz - data.fz) * 100;
      }
    }

    if(structeq(dst, POINTCLOUD_2PT)) {
      if(has_member(data, "meast"))
        result.mx = data.meast * 0.01;
      if(has_member(data, "mnorth"))
        result.my = data.mnorth * 0.01;
      if(has_member(data, "melevation"))
        result.mz = data.melevation * 0.01;
      if(has_member(data, "east"))
        result.fx = data.east * 0.01;
      if(has_member(data, "north"))
        result.fy = data.north * 0.01;
      if(has_member(data, "elevation"))
        result.fz = data.elevation * 0.01;
      if(has_member(data, "least"))
        result.lx = data.least * 0.01;
      if(has_member(data, "lnorth"))
        result.ly = data.lnorth * 0.01;
      if(has_member(data, "lelv"))
        result.lz = data.lelv * 0.01;
      if(has_member(data, "intensity"))
        result.fint = data.intensity;
      if(has_member(data, "first_peak"))
        result.fint = data.first_peak;
      if(has_member(data, "bottom_peak"))
        result.lint = data.bottom_peak;
      if(has_member(data, "rn"))
        result.pulse = parse_rn(data.rn)(,2);

      if(structeq(src, FS)) {
        result.lx = result.fx;
        result.ly = result.fy;
        result.lz = result.fz;
        result.nx = 1;
      }
      if(structeq(src, GEO)) {
        result.lx = result.fx;
        result.ly = result.fy;
        result.lz = (data.elevation + data.depth) * 0.01;
        result.nx = 2;
      }
    }
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

func uniq_data(data, idx=, bool=, mode=, forcesoe=, forcexy=, enablez=) {
/* DOCUMENT uniq_data(data, idx=, bool=, mode=, forcesoe=, forcexy=, enablez=)
  Returns the unique data in the given array.

  By default, uniqueness is determined based on the .soe field. When using the
  .soe field, points with the same soe value are considered duplicates. If the
  .channel field is present, then uniqueness is determined based on the
  combination of [.soe, .channel].

  If the .soe field is not present, if all soe values are the same, or if
  forcexy=1, then the x and y coordinates of the data are used instead. In
  this case, points located at the same x,y coordinate are considered
  duplicates. If enablez=1, then points located at the same x,y,z coordinate
  are instead considered duplicates.

  This allows the function to work on almost any kind of data:
    * data generated within ALPS
    * data imported from XYZ, LAS, etc. and stored in an ALPS array, but
      missing some or all auxiliary fields
    * XYZ data that is not in an ALPS data structure

  Options that change what gets returned:
    idx= Returns index into data.
    bool= Returns boolean array corresponding to data.

    These are all equivalent:
      result = uniq_data(data);
      result = data(uniq_data(data, idx=1));
      result = data(where(uniq_data(data, bool=1)));

  Options that change how uniqueness is determined:
    forcesoe= Forces the use of soe values, even if it's determined to be
      inappropriate.
        forcesoe=0  Do not force use of soe (default)
        forcesoe=1  Force use of soe
    forcexy= Forces the use of x/y values.
        forcexy=0   Do not force use of x/y values (default)
        forcexy=1   Force use of x/y values.
    enablez= Enables the use of z values. If the soe values get used, this
      has no effect. If the x/y values get used, then causes z to get used
      as well.
        enablez=0   Ignore z values (default)
        enablez=1   Include z values in uniqueness check
    mode= Specifies which data mode to use to extract x/y/z points when using
      them to determine uniqueness.
        mode="fs"   Default
*/
  local w, x, y, z, keep, srt, dupe;
  default, idx, 0;
  default, forcesoe, 0;
  default, forcexy, 0;
  default, enablez, 0;

  // Edge case
  if(is_void(data))
    return [];
  // Edge case
  if(numberof(data) == 1)
    return (bool || idx) ? [1] : data;

  // First, we assume that we want to keep everything.
  keep = array(char(1), dimsof(data));

  if(forcesoe && !has_member(data, "soe"))
    error, "You cannot use forcesoe=1 when the data does not have an soe field.";

  if(forcesoe && forcexy)
    error, "You cannot use both of forcesoe=1 and forcexy=1 together."

  // Determine how to determine uniqueness. Start by assuming soe.
  usesoe = 1;
  // If they have forcexy=1, then we don't want soe.
  if(usesoe && forcexy)
    usesoe = 0;
  // If there is no .soe member, then we can't use soe.
  if(usesoe && !has_member(data, "soe"))
    usesoe = 0;
  // Unless we're forcing use of soe, there has to be some variation in the
  // .soe values. Otherwise, we can't use them.
  if(usesoe && !forcesoe && allof(data.soe == data.soe(1)))
    usesoe = 0;

  if(usesoe) {
    // Determine whether to use the channel to help determine uniqueness. Start
    // by assuming yes.
    usechannel = 1;
    // If there's no channel field, then channel can't be used.
    if(usechannel && !has_member(data, "channel"))
      usechannel = 0;
    // If there's no variation in channel, then there's no point in using it.
    if(usechannel && allof(data.channel == data.channel(1)))
      usechannel = 0;

    if(usechannel) {
      // Use using soe + channel to determine uniqueness, duplicate points are
      // determined by points where soe and channel both match.
      srt = msort(data.soe, data.channel);
      dupe = where(!data.soe(srt)(dif) & !data.channel(srt)(dif));
    } else {
      // When using soe to determine uniqueness, duplicate points are
      // determined by points where the soe value matches.
      srt = sort(data.soe);
      dupe = where(!data.soe(srt)(dif));
    }
    if(numberof(dupe))
      keep(srt(dupe)) = 0;
  } else {
    data2xyz, data, x, y, z, native=1, mode=mode;

    // Redefine keep based on x. If they passed an XYZ array instead of EAARL
    // data, this will prevent errors.
    keep = array(char(1), dimsof(x));

    // Now, do we use just x/y to determine uniqueness... or z as well?
    // Assume just xyz by default

    srt = enablez ? msort(x, y, z) : msort(x, y);
    dupex = where(x(srt(:-1)) == x(srt(2:)));
    if(numberof(dupex)) {
      dupey = where(y(srt(dupex)) == y(srt(dupex+1)));
      if(numberof(dupey)) {
        if(enablez) {
          dupez = where(z(srt(dupex(dupey))) == z(srt(dupex(dupey+1))));
          if(numberof(dupez))
            keep(srt(dupex(dupey(dupez)))) = 0;
        } else {
          keep(srt(dupex(dupey))) = 0;
        }
      }
    }
  }

  if(bool)
    return keep;
  w = where(unref(keep));
  if(idx)
    return w;
  else if(is_numerical(data)) // Special case for XYZ input.
    return [x(w), y(w), z(w)];
  else
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
// Original David Nagle 2010-04-23
  default, method, "y";
  default, desc, 0;
  local tmp, idx;

  if(method == "soe") {
    idx = sort(data.soe);
  } else if(method == "x") {
    data2xyz, data, tmp, mode=mode;
    idx = sort(unref(tmp));
  } else if(method == "y") {
    data2xyz, data, , tmp, mode=mode;
    idx = sort(unref(tmp));
  } else if(method == "z") {
    data2xyz, data, , , tmp, mode=mode;
    idx = sort(unref(tmp));
  } else if(method == "random") {
    data2xyz, data, tmp;
    idx = sort(random(numberof(unref(tmp))));
  }
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
