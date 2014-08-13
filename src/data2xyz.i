// vim: set ts=2 sts=2 sw=2 ai sr et:

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
      z = .intensity OR .fint OR .first_peak (whichever is available)

    mode="fs" (First return)
      x = .east
      y = .north
      z = .elevation

    mode="lint" (Last return intensity)
      x = .least OR .east
      y = .lnorth OR .north
      z = .lint OR .bottom_peak (whichever is available)

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
  if(mode == "fint") {
    if(has_member(data, "intensity")) return "intensity";
    if(has_member(data, "first_peak")) return "first_peak";
  }
  if(mode == "lint" && has_member(data, "bottom_peak"))
    return "bottom_peak";
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
  return am_subroutine() ? [] : [x,y,z];
}

func data2xyz_legacy_xy_fields(data, &xfield, &yfield, mode=) {
  xfield = yfield = [];

  if(
    anyof(["ba","be","ch","de","fint","fs"] == mode) ||
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
  return am_subroutine() ? [] : [x,y,z];
}
