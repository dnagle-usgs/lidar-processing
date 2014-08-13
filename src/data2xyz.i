// vim: set ts=2 sts=2 sw=2 ai sr et:

local alps_data_modes;
/* DOCUMENT alps_data_modes
  Many functions through ALPS take a mode= option that controls how a data
  variable is interpreted as x,y,z values. This documention explains the values
  the option can take and how it interplays with various kinds of data.

  == Overview ==

  There are four different kinds of data that can potentially be handled:
    - a multi-dimensional numerical array with a dimension of size 3
    - gridded data in the ZGRID structure
    - data in dynamic ALPS structures/objects that contain x,y,z (or fx,fy,fz)
      style fields; these are detected based on the presence of an "x" or "fx"
      field
    - data in legacy ALPS structures such as FS, VEG__, etc. that contain east,
      north, elevation style fields; these are detected based on the present of
      an "east" field

  For numerical arrays and gridded data, the mode is ignored. These two kinds
  of data do not have the complexity to support multiple data modes. However,
  functions are engineered to let them pass through where possible to allow the
  functions to be used against the wide possible range of inputs. However, not
  all functions that accept mode= options may accept these two kinds of data.
  In general, functions that just look at the data as-is will be fine, wheres
  functions that take action on the data (such as indexing into it or modifying
  it) may fail. Functions that want access to supplementary fields such as
  soe or raster may also fail.

  But most of the time, data will be in either a legacy ALPS structure or a
  dynamic ALPS structure or object. In these cases, the mode actually means
  something and is interpreted based on the fields present as described below.

  A few functions include a native= option. This option only applies to the
  legacy ALPS structures and is explained in that section below.

  == Dynamic Structs and Objects ==

  The default behavior for dynamic structs and oxy groups/objects is to return
  the field whose name matches mode for z. For x and y, fields "x" and "y" are
  returned if present; otherwise, "fx" and "fy" are returned in present.
  However, there are a bunch of special cases.

  The following modes use "lx" and "ly" if possible:
    "ba" (bathy)
    "be" (bare earth)
    "ch" (canopy height)
    "de" (water depth)
    "lint" (last return intensity)

  The following modes use "fx" and "fy" if possible:
    "fs" (first surface)
    "fint" (first return intensity)

  The following mode uses "mx" and "my" if possible:
    "mir" (mirror)

  For all of the above, if the prefered fields are not present, it will fall
  back to using "x" and "y" if present; then will fall back to "fx" and "fy" if
  present.

  The following modes use the values specified for z, if possible:
    "ba" (bathy) uses "lz" or "z"
    "be" (bare earth) uses "lz" or "z"
    "fs" (first surface) uses "fx" or "z"
    "mir" (mirror) uses "mz"
    "de" (depth) uses "depth"

  There are also a few modes that will attempt to use a derived value for z, if
  other attempts to derive the z value fail:
    "ba" (bathy) uses mode "fs" + mode "depth"
    "ch" (canopy height) uses mode "fs" - mode "be"
    "de" and "depth" (depth) use mode "ba" - mode "fs"

  == Legacy Structs ==

  The default behavior for legacy structs is to return "east" for x, "north"
  for y, and then the field whose name matches mode for z. However, there are a
  bunch of special cases.

  The following modes use "least" for x and "lnorth" for y, if possible:
    "be" (bare earth)
    "lint" (last return intensity)

  The following mode uses "meast" for x and "mnorth" for y, if possible:
    "mir" (mirror)

  The following modes use the values specified for z, if possible:
    "fs" (first surface) uses "elevation"
    "be" (bare earth) uses "lelv"
    "de" (water depth) uses "depth"
    "fint" (first return intensity) uses "intensity", "fint", or "first_peak"
    "lint" (last return intensity) uses "lint" or "bottom_peak"
    "mir" (mirror) uses "melevation"

  There are also a few modes that will attempt to use a derived value for z, if
  other attempts to derive the z value fail:
    "ba" (bathy) uses mode "fs" + mode "depth"
    "ch" (canopy height) uses mode "fs" - mode "be"

  If native=0, then the x and y fields will be returned as integer centimeters
  instead of being converted to double meters. The same will be done for the z
  value for these modes: "ba", "be", "ch", "de", "fs", "mir".
*/

func data2xyz(data, &x, &y, &z, mode=, native=) {
/* DOCUMENT data2xyz, data, x, y, z, mode=, native=
  result = data2xyz(data, mode=, native=)

  Extracts the x, y, and z coordinates from data for the given mode. The mode
  must be compatible with the data, and defaults to "fs".

  Arguments x, y, and z are output arguments. Alternately, the function can
  also return result=[x, y, z]; be sure to index this as result(..,1),
  result(..,2) and result(..,3) on the off chance that the input data is
  multidimensional.

  Please see alps_data_modes for information on the mode= and native= options.
*/
  default, mode, "fs";
  default, native, 0;
  x = y = z = [];

  // Special case to allow XYZ pass through
  if(is_numerical(data))
    return splitary(data, 3, x, y, z);

  // Special case for gridded data
  if(structeq(structof(data), ZGRID)) {
    data2xyz_zgrid, data, x, y, z;
    return am_subroutine() ? [] : [x, y, z];
  }

  // Special handling for POINTCLOUD_2PT and other newer-style structures
  if(
    structeq(structof(data), POINTCLOUD_2PT)
    || has_member(data, "x") || has_member(data, "fx")
  ) {
    data2xyz_dynamic, data, x, y, z, mode=mode;
    return am_subroutine() ? [] : [x, y, z];
  }

  if(has_member(data, "east")) {
    data2xyz_legacy, data, x, y, z, mode=mode, native=native;
    return am_subroutine() ? [] : [x, y, z];
  }

  error, "don't know how to handle data";
}

func data2xyz_zgrid(data, &x, &y, &z) {
  if(numberof(data) > 1) {
    ptrs = array(pointer, numberof(data));
    for(i = 1; i <= numberof(data); i++)
      ptrs(i) = &transpose(data2xyz_zgrid(data(i)));
    merged = merge_pointers(ptrs);
    merged = reform(merged, [2, 3, numberof(merged)/3]);
    splitary, merged, 3, x, y, z;
    return am_subroutine() ? [] : [x,y,z];
  }

  z = *(data.zgrid);
  x = y = array(double, dimsof(z));
  xmax = data.xmin + dimsof(x)(2) * data.cell;
  ymax = data.ymin + dimsof(y)(3) * data.cell;
  hc = 0.5 * data.cell;
  x(,) = span(data.xmin+hc, xmax-hc, dimsof(x)(2))(,-);
  y(,) = span(data.ymin+hc, ymax-hc, dimsof(y)(3))(-,);
  w = where(z != data.nodata);

  if(!numberof(w)) {
    x = y = z = [];
    return;
  }

  x = x(w);
  y = y(w);
  z = z(w);
  return am_subroutine() ? [] : [x,y,z];
}

func data2xyz_dynamic_xy_fields(data, &xfield, &yfield, mode=) {
  xfield = yfield = [];

  if(anyof(["ba","be","ch","de","lint"] == mode)) {
    if(has_member(data, "lx") && has_member(data, "ly")) {
      xfield = "lx";
      yfield = "ly";
      return;
    }
  }
  if(anyof(["fint","fs"] == mode)) {
    if(has_member(data, "fx") && has_member(data, "fy")) {
      xfield = "fx";
      yfield = "fy";
      return;
    }
  }
  if(mode == "mir") {
    if(has_member(data, "mx") && has_member(data, "my")) {
      xfield = "mx";
      yfield = "my";
      return;
    }
  }
  if(has_member(data, "x") && has_member(data, "y")) {
    xfield = "x";
    yfield = "y";
    return;
  }
  if(has_member(data, "fx") && has_member(data, "fy")) {
    xfield = "fx";
    yfield = "fy";
    return;
  }
}

func data2xyz_dynamic_xy(data, &x, &y, mode=) {
  x = y = xfield = yfield = [];
  data2xyz_dynamic_xy_fields, data, xfield, yfield, mode=mode;
  if(xfield && yfield) {
    x = get_member(data, xfield);
    y = get_member(data, yfield);
  }
}

func data2xyz_dynamic_z_field(data, mode) {
  if(anyof(mode == ["ba","be"])) {
    if(has_member(data, "lz")) return "lz";
    if(has_member(data, "z")) return "z";
  }
  if(mode == "fs") {
    if(has_member(data, "fz")) return "fz";
    if(has_member(data, "z")) return "z";
  }
  if(mode == "mir" && has_member(data, "mz"))
    return "mz";
  if(mode == "de" && has_member(data, "depth"))
    return "depth";
  if(has_member(data, mode))
    return mode;
}

func data2xyz_dynamic_z(data, &z, mode=) {
  z = [];

  field = data2xyz_dynamic_z_field(data, mode);
  if(field) {
    z = get_member(data, field);
    return;
  }

  if(mode == "ba") {
    field1 = data2xyz_dynamic_z_field(data, "fs");
    field2 = data2xyz_dynamic_z_field(data, "depth");
    if(field1 && field2) {
      z = get_member(data, field1) + get_member(data, field2);
      return;
    }
  }

  if(mode == "ch") {
    field1 = data2xyz_dynamic_z_field(data, "fs");
    field2 = data2xyz_dynamic_z_field(data, "be");
    return get_member(data, field1) - get_member(data, field2);
  }

  if(mode == "de" || mode == "depth") {
    field1 = data2xyz_dynamic_z_field(data, "fs");
    field2 = data2xyz_dynamic_z_field(data, "ba");
    return get_member(data, field2) - get_member(data, field1);
  }
}

func data2xyz_dynamic(data, &x, &y, &z, mode=) {
  data2xyz_dynamic_xy, data, x, y, mode=mode;
  data2xyz_dynamic_z, data, z, mode=mode;
  if(is_void(x) || is_void(z)) error, "invalid mode";
  return am_subroutine() ? [] : [x,y,z];
}

func data2xyz_legacy_xy_fields(data, &xfield, &yfield, mode=) {
  xfield = yfield = [];

  if(
    anyof(["ba","ch","de","fint","fs"] == mode) ||
    ("lint"==mode && !has_member(data,"least"))
  ) {
    if(has_member(data, "east") && has_member(data, "north")) {
      xfield = "east";
      yfield = "north";
      return;
    }
  }
  if(anyof(["lint","be"] == mode)) {
    if(has_member(data, "least") && has_member(data, "lnorth")) {
      xfield = "least";
      yfield = "lnorth";
      return;
    }
  }
  if(mode == "mir") {
    if(has_member(data, "meast") && has_member(data, "mnorth")) {
      xfield = "meast";
      yfield = "mnorth";
      return;
    }
  }
  if(has_member(data, mode)) {
    if(has_member(data, "east") && has_member(data, "north")) {
      xfield = "east";
      yfield = "north";
      return;
    }
  }
}

func data2xyz_legacy_xy(data, &x, &y, mode=, native=) {
  x = y = xfield = yfield = [];
  data2xyz_legacy_xy_fields, data, xfield, yfield, mode=mode;
  if(xfield && yfield) {
    x = get_member(data, xfield);
    y = get_member(data, yfield);

    if(!native) {
      x *= 0.01;
      y *= 0.01;
    }
  }
}

func data2xyz_legacy_z_field(data, mode) {
  if(mode == "fs" && has_member(data, "elevation"))
    return "elevation";
  if(mode == "be" && has_member(data, "lelv"))
    return "lelv";
  if(mode == "de" && has_member(data, "depth"))
    return "depth";
  if(mode == "fint") {
    if(has_member(data, "intensity"))
      return "intensity";
    if(has_member(data, "first_peak"))
      return "first_peak";
  }
  if(mode == "lint" && has_member(data, "bottom_peak"))
    return "bottom_peak";
  if(mode == "mir" && has_member(data, "melevation"))
    return "melevation";
  if(has_member(data, mode))
    return mode;
}

func data2xyz_legacy_z(data, &z, mode=, native=) {
  z = [];

  field = data2xyz_legacy_z_field(data, mode);
  if(field) {
    z = get_member(data, field);
    if(!native && anyof(["ba","be","ch","de","fs","mir"] == mode))
      z *= 0.01;
    return;
  }

  if(mode == "ba") {
    field1 = data2xyz_legacy_z_field(data, "fs");
    field2 = data2xyz_legacy_z_field(data, "depth");
    if(field1 && field2) {
      z = get_member(data, field1) + get_member(data, field2);
      if(!native) z *= 0.01;
      return;
    }
  }

  if(mode == "ch") {
    field1 = data2xyz_legacy_z_field(data, "fs");
    field2 = data2xyz_legacy_z_field(data, "be");
    if(field1 && field2) {
      z = get_member(data, field1) - get_member(data, field2);
      if(!native) z *= 0.01;
      return;
    }
  }
}

func data2xyz_legacy(data, &x, &y, &z, mode=, native=) {
  data2xyz_legacy_xy, data, x, y, mode=mode, native=native;
  data2xyz_legacy_z, data, z, mode=mode, native=native;
  if(is_void(x) || is_void(z)) error, "invalid mode";
  return am_subroutine() ? [] : [x,y,z];
}
