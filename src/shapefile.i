// vim: set ts=2 sts=2 sw=2 ai sr et:

func read_ascii_shapefile(filename, &meta) {
/* DOCUMENT read_ascii_shapefile(filename, &meta)
  Reads an ASCII shapefile as created by Global Mapper (using export Simple
  ASCII Shapefile) or by Yorick (using write_ascii_shapefile).

  The shapefile will be returned as an array of pointers. Each pointer points
  to an array of x,y points. (*shp(i))(1,) are the x-coordinates for the i-th
  segment. (*shp(i))(2,) are the y-coordinates for the i-th segment.

  == File Format ==

  The shapefile consists of one or more segments, which are separated in the
  file by one or more blank lines.

  Each segment is comprised of a series of point coordinates. The coordinates
  should be comma-delimited x,y or x,y,z values, one per line, in sequence.

  Each segment may optionally be preceeded by attribute information. Each
  attribute must be written as "KEY=VALUE". There may be any arbitrary number
  of attributes.

  The blank lines between segments may be omitted if the segments are
  separated by attribute information.
*/
// Original David Nagle 2008-10-06
  f = open(filename, "r");
  shp = array(pointer, 8);
  shp_idx = 0;
  state = "TOP";
  ary = [];
  meta = save();
  while(1) {
    line = rdline(f);
    if(strglob("*=*", line)) {
      if(state == "COORD") {
        shp_idx++;
        if(shp_idx > numberof(shp)) {
          grow, shp, shp;
        }
        shp(shp_idx) = &ary;
        ary = [];
        state = "TOP";
      }
      if(state == "TOP" || state == "ATTR") {
        // do nothing with the data
        state = "ATTR";
        parts = strtok(line, "=");
        while(meta(*) <= shp_idx)
          save, meta, string(0), save();
        save, meta(shp_idx+1), parts(1), strtrim(parts(2), blank=" \t\r\n");
      } else {
        // invalid
        error, "Unexpected attribution in " + state;
      }
    } else if(regmatch("^ *(-?[0-9]+\.?[0-9]*)(, *|  *)(-?[0-9]+\.?[0-9]*)(,| |$)",
      line, , x, , y)) {
      if(state == "TOP" || state == "ATTR" || state == "COORD") {
        // grow coordinates
        x = atod(x);
        y = atod(y);
        grow, ary, [[x,y]];
        state = "COORD";
      } else {
        // invalid
        error, "Unexpected coordinate in " + state;
      }
    } else if(!line || regmatch("^[ \t\n\r]*?$", line)) {
      if(state == "COORD") {
        shp_idx++;
        if(shp_idx > numberof(shp)) {
          grow, shp, shp;
        }
        shp(shp_idx) = &ary;
        ary = [];
        if(!line) {
          break;
        } else {
          state = "TOP";
        }
      } else if(state == "TOP") {
        if(!line) {
          break;
        }
      } else {
        if(!line) {
          error, "Unexpected EOF in " + state;
        } else {
          error, "Unexpected blank line in " + state;
        }
      }
    } else {
      // Invalid
      error, "Unexpected unknown in " + state;
    }
  }
  close, f;
  shp = shp(:shp_idx);
  while(meta(*) < shp_idx)
    save, meta, string(0), save();
  return shp;
}

func write_ascii_shapefile(shp, filename, meta=, geo=, utm=) {
/* DOCUMENT write_ascii_shapefile, shp, filename, meta=, geo=, utm=
  Creates an ASCII shapefile using the given data.

  See read_ascii_shapefile for details on the format of the data array and file.

  If meta= is provided, it should be an array of strings. Each string must be
  terminated with a newline. They will be written as-is preceeding each
  segment. Alternately, they may be an oxy group as returned by
  read_ascii_shapefile.

  If geo=1 is provided, the shape is written out as geographic coordinates. If
  utm=1 is provided, the shape is written out as UTM coordinates. If neither
  are provided, it is written out as is. (If conversions are done, it uses
  curzone for the UTM zone.)
*/
  if(geo && utm) error, "cannot provide both geo=1 and utm=1";

  // Check if conversion is necessary
  if(utm) {
    if((*shp(1))(1,)(max) <= 360) {
      if(!curzone) error, "curzone is not set";
      shp = shape_cs2cs(shp, cs_wgs84(), cs_wgs84(zone=curzone));
    }
  } else if(geo) {
    if((*shp(1))(1,)(max) > 360) {
      if(!curzone) error, "curzone is not set";
      shp = shape_cs2cs(shp, cs_wgs84(zone=curzone), cs_wgs84());
    }
  }

  // Check to determine decimal precision
  if((*shp(1))(1,)(max) <= 360)
    fmt = "%.10f,%.10f";
  else
    fmt = "%.3f,%.3f";

  f = open(filename, "w");
  for(i = 1; i <= numberof(shp); i++) {
    if(is_string(meta)) {
      write, f, format="%s", meta(i);
    } else if(is_obj(meta)) {
      tmp = meta(noop(i));
      for(j = 1; j <= tmp(*); j++)
        write, f, format="%s=%s\n", tmp(*,j), tmp(noop(j));
    }
    ply = *shp(i);
    if(dimsof(ply)(2) > 2) {
      write, f, format=fmt+",%.3f\n", ply(1,), ply(2,), ply(3,);
    } else {
      write, f, format=fmt+"\n", ply(1,), ply(2,);
    }
    write, f, format="%s", "\n";
  }
  close, f;
}

func plot_shape(shp, color=, width=) {
/* DOCUMENT plot_shape, shp, color=, width=
  Plots a shapefile. See read_ascii_shapefile for details on the format of
  shp.

  If extern utm is defined, then this does some autodetection work for UTM
  versus geographic coordinates. When utm=1, any shapefiles in geographic
  coordinates get converted to UTM coordinates on the fly. When utm=0, any
  shapefiles in UTM coordinates get converted to geographic coordinates on the
  fly. For best results, curzone should be set (even if you're using
  geographic coordinates).
*/
// Original David Nagle 2008-10-06
  extern utm, curzone;
  for(i = 1; i <= numberof(shp); i++) {
    ply = *shp(i);

    if(numberof(ply(1,)) < 1) {
      write, "Skipping polygon with zero points."
      continue;
    }

    // If utm is defined, then correct the coordinates for the current mode.
    if(!is_void(utm)) {
      // If the coordinates are less than 1000, then they're lat/lon. If
      // they're larger, then they're UTM. This covers the majority of cases
      // safely.
      if(abs(ply(1,1)) < 1000) {
        if(utm) {
          u = fll2utm(ply(2,), ply(1,), force_zone=curzone);
          ply(1,) = u(2,);
          ply(2,) = u(1,);
        }
      } else {
        if(!utm) {
          zone = curzone;
          if(is_void(zone)) {
            // Attempt to guess the zone based on the window's limits and
            // hope for the best...
            lims = limits();
            u = fll2utm(lims(3:4)(avg), lims(1:2)(avg));
            zone = long(u(3));
            write, format="Guessing that zone is currently %d... for best results, set curzone!\n", zone;
          }
          ll = utm2ll(ply(2,), ply(1,), zone);
          ply(1,) = ll(,1);
          ply(2,) = ll(,2);
        }
      }
    }

    if(numberof(ply(1,)) > 1) {
      plg, ply(2,), ply(1,), marks=0, color=color, width=width;
    } else if(numberof(ply(1,)) == 1) {
      plmk, ply(2,), ply(1,), marker=1, color=color, msize=0.1;
    }
  }
}

func shape_cs2cs(&shp, src, dst) {
/* DOCUMENT shape_cs2cs, shp, src, dst
  -or- shp = shape_cs2cs(shp, src, dst)
  Converts all polygons in the given shapefile array from one coordinate system
  to another.

  To convert from UTM to lat/lon:
    shape_cs2cs, shp, cs_wgs84(zone=16), cs_wgs84()

  To convert from lat/lon to UTM:
    shape_cs2cs, shp, cs_wgs84(), cs_wgs84(zone=16)

  If a polygon lacks a Z dimension, 0 is temporarily used (and then
  discarded).
*/
  local x, y, z;
  out = array(pointer, dimsof(shp));
  for(i = 1; i <= numberof(shp); i++) {
    has_z = (dimsof(*shp(i))(2) == 3);
    x = (*shp(i))(1,);
    y = (*shp(i))(2,);
    z = has_z ? (*shp(i))(3,) : (x * 0);
    cs2cs, src, dst, x, y, z;
    if(has_z)
      out(i) = &transpose([x,y,z]);
    else
      out(i) = &transpose([x,y]);
  }
  if(am_subroutine()) shp = out;
  return out;
}

func shape_stats(shp) {
/* DOCUMENT shape_stats, shp
  Displays basic statistics for the shapefile: number of polygons and number
  of points.

  See read_ascii_shapefile for details on the format of shp.
*/
// Original David Nagle 2008-10-06
  write, format="Number of polys: %d\n", numberof(shp);
  points = 0;
  for(i = 1; i <= numberof(shp); i++) {
    write, format="  %d: %d points\n", i, numberof((*shp(i))(1,));
    points += numberof((*shp(i))(1,));
  }
  write, format="Number of total points: %d\n", points;
}

func print_shape(shp, idx) {
/* DOCUMENT print_shape, shp
        print_shape, shp, idx
  Displays the contents of the shapefile (on stdout). If idx is specified,
  then only that polygon in the shapefile will be displayed.

  See read_ascii_shapefile for details on the format of shp.
*/
// Original David Nagle 2008-10-06
  if(idx) {
    write, format="%.2f, %.2f\n", (*shp(idx))(1,), (*shp(idx))(2,);
  } else {
    for(i = 1; i <= numberof(shp); i++) {
      write, format="Poly %i\n", i;
      print_shape, shp, i;
      write, " ";
    }
  }
}

func add_shapefile(filename) {
/* DOCUMENT add_shapefile, filename
  Loads the specified ASCII shapefile and stores in private variables for
  later use.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
// Original David Nagle 2008-10-06
  extern _shp_polys;
  extern _shp_files;

  shp = read_ascii_shapefile(filename);
  if(is_void(_shp_polys)) {
    _shp_polys = array(pointer, 1);
    _shp_files = array(string, 1);
    _shp_polys(1) = &shp;
    _shp_files(1) = filename;
  } else {
    grow, _shp_polys, &shp;
    grow, _shp_files, filename;
  }
}

func plot_shapefiles(void, color=, random_colors=, win=) {
/* DOCUMENT plot_shapefiles
  Plots the shapefiles stored in private variables.

  Primarily intended for transparent use from the Plotting Tool GUI.

  Options:
    color= Specifies a color to pass to plot_shape.
    random_colors= If set to 1, this randomizes the color used per line.
      (Overrides color= if present.)
    win= Specifies the window to plot in.
*/
  extern _shp_polys;
  color_list = ["black", "red", "blue", "yellow", "cyan", "green", "magenta", "white"];

  if(is_void(_shp_polys))
    return;
  wbkp = current_window();
  window, win;
  for(i = 1; i <= numberof(_shp_polys); i++) {
    if(random_colors)
      color = color_list(i % numberof(color_list));
    plot_shape, *_shp_polys(i), color=color;
  }
  window_select, win;
}

func remove_shapefile(filename) {
/* DOCUMENT remove_shapefile, filename
  Removes the shapefile specified from the data stored in private variables.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
// Original David Nagle 2008-10-06
  extern _shp_polys;
  extern _shp_files;

  if(is_void(_shp_polys) || is_void(_shp_files)) {
    _shp_files = _shp_files = [];
    return;
  }

  w = where(_shp_files != filename);
  if(numberof(w)) {
    _shp_polys = _shp_polys(w);
    _shp_files = _shp_files(w);
  } else {
    _shp_polys = _shp_files = [];
  }
}

func shapefile_limits(void) {
/* DOCUMENT shapefile_limits
  Sets the limits of the window to match the extent of the loaded shapefiles.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
  extern _shp_polys, utm, curzone;
  minx = miny =  1e+100;
  maxx = maxy = -1e+100;

  for(i = 1; i <= numberof(_shp_polys); i++) {
    shp = *_shp_polys(i);
    for(j = 1; j <= numberof(shp); j++) {
      ply = *shp(j);
      x = ply(1,);
      y = ply(2,);

      // Make sure coordinates match what's currently plotted
      if(!is_void(utm)) {
        if(utm) {
          if(x(max) <= 360) ll2utm, y, x, y, x, force_zone=curzone;
        } else {
          if(x(max) > 360) utm2ll, y, x, curzone, x, y;
        }
      }

      minx = min(minx, x(min));
      maxx = max(maxx, x(max));
      miny = min(miny, y(min));
      maxy = max(maxy, y(max));
    }
  }

  // Expand by 1% in each direction
  xdif = (maxx - minx)/100.;
  ydif = (maxy - miny)/100.;
  minx -= xdif;
  maxx += xdif;
  miny -= ydif;
  maxy += ydif;

  data_aspect = (maxx-minx)/(maxy-miny);

  temp = viewport()(dif)(1:3:2);
  plot_aspect = temp(1)/temp(2);

  limits, square=1;

  if (data_aspect < plot_aspect) {
    x = [minx,maxx](avg) - (maxy-miny)*plot_aspect/2;
    limits, x, "e", miny, maxy;
  } else {
    y = [miny,maxy](avg) - (maxx-minx)/plot_aspect/2;
    limits, minx, maxx, y, "e";
  }
}

func polygon_check_llutm(ref, ply) {
/* DOCUMENT polygon_check_llutm, ref, ply
  Makes sure PLY is in the same coordinate system (UTM or GEO) as REF. If it's
  not, it converts it. This check is only done is curzone is set and non-zero,
  so be sure to define curzone.

  Intended for use by polygon_add.
*/
  extern curzone;
  if(curzone) {
    if(ref(1,1) < 1000) {
      if(ply(1,1) > 1000) {
        ll = utm2ll(ply(2,), ply(1,), curzone);
        ply(1,) = ll(,1);
        ply(2,) = ll(,2);
      }
    } else {
      if(ply(1,1) < 1000) {
        u = ll2utm(ply(2,), ply(1,), force_zone=curzone);
        ply(1,) = u(2,);
        ply(2,) = u(1,);
      }
    }
  }
}

func polygon_add(ply, name) {
/* DOCUMENT polygon_add, ply, name
  Adds the specified polygon to private variables for later use.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
// Original David Nagle 2008-10-06
  extern _poly_polys;
  extern _poly_names;

  if(is_void(ply))
    return;

  if(is_void(_poly_polys)) {
    _poly_polys = array(pointer, 1);
    _poly_names = array(string, 1);
    _poly_polys(1) = &ply;
    _poly_names(1) = name;
  } else {
    polygon_check_llutm, *_poly_polys(1), ply;
    grow, _poly_polys, &ply;
    grow, _poly_names, name;
  }

  tkcmd, swrite(format="::plot::poly_add_callback {%s}", name);
}

func polygon_remove(name) {
/* DOCUMENT polygon_remove, name
  Removes the specified polygon from private variables.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
// Original David Nagle 2008-10-06
  extern _poly_polys;
  extern _poly_names;

  if(is_void(_poly_polys) || is_void(_poly_names)) {
    _poly_files = _poly_files = [];
    return;
  }

  w = where(_poly_names != name);
  if(numberof(w)) {
    _poly_polys = _poly_polys(w);
    _poly_names = _poly_names(w);
  } else {
    _poly_polys = _poly_names = [];
  }
}

func polygon_rename(old, new) {
  extern _poly_names;
  w = where(_poly_names == old);
  if(numberof(w))
    _poly_names(w) = new;
  polygon_refresh_tcl;
}

func polygon_refresh_tcl(void) {
  extern _poly_names;
  tkcmd, "$::plot::g::polyListBox clear";
  for(i = 1; i <= numberof(_poly_names); i++) {
    tkcmd, "$::plot::g::polyListBox insert end {" + _poly_names(i) + "}";
  }
}

func polygon_sort(void) {
  extern _poly_names;
  extern _poly_polys;

  base = num = [];
  regmatch, "^(.*[^0-9]|)([0-9]*)$", _poly_names, , base, num;
  num = atoi(num);

  srt = msort(base, num);
  _poly_names = _poly_names(srt);
  _poly_polys = _poly_polys(srt);

  polygon_refresh_tcl;
}

func polygon_sanitize(void, recursed=) {
  extern _poly_names;
  default, recursed, 0;
  names = set_remove_duplicates(_poly_names);
  recurse = 0;
  if(numberof(names) != numberof(_poly_names)) {
    for(i = 1; i <= numberof(names); i++) {
      name = names(i);
      w = where(_poly_names == name);
      if(numberof(w) > 1) {
        for(j = 1; j <= numberof(w); j++) {
          _poly_names(w(j)) += swrite(format="_%d", j);
          recurse = 1;
        }
      }
    }
  }
  if(recurse)
    polygon_sanitize;
  if(recurse && !recursed)
    polygon_refresh_tcl;
}

func polygon_plot(void) {
/* DOCUMENT polygon_plot
  Plots the polygons currently defined in private variables.

  Primarily intended for transparent use from the Plotting Tool GUI.
*/
// Original David Nagle 2008-10-06
  extern _poly_polys;
  if(is_void(_poly_polys))
    return;
  plot_shape, _poly_polys;
}

func polygon_highlight(name) {
  extern _poly_names;
  extern _poly_polys;
  w = where(_poly_names == name);
  plot_shape, _poly_polys(w), color="red";
}

func polygon_write(filename, sox=, color=, width=, geo=, utm=) {
/* DOCUMENT polygon_write, filename, sox=, color=, width=, geo=, utm=
  Saves the currently defined polygons to a file as an ASCII shapefile. See
  write_ascii_shapefile and read_ascii_shapefile for details.

  Primarily intended for transparent use from the Plotting Tool GUI. However,
  it also supports some options for command-line use.

  By default, coordinates are used as they are in memory. To force to UTM or
  Lat/Lon, use utm=1 or geo=1.

  By default, meta information is added with the name of each poly. To add a
  color, use color="RGB(255,0,0)". To add a line width, use width=3.

  Use sox=1 to flip on the options commonly used for sox map, use sox=1. This
  is equivalent to color="RGB(255,0,0)", width=3, geo=1.
*/
  extern _poly_polys, _poly_names, curzone;
  if(sox) {
    default, color, "RGB(255,0,0)";
    default, width, 3;
    default, utm, 0;
    default, geo, !utm;
  }
  if(geo && utm) error, "cannot provide both geo=1 and utm=1";

  meta = "NAME=" + _poly_names + "\n";
  if(width)
    meta += swrite(format="LINE_WIDTH=%d\n", long(width));
  if(color)
    meta += "LINE_COLOR="+color+"\n";

  write_ascii_shapefile, _poly_polys, filename, meta=meta, geo=geo, utm=utm;
}

func polygon_read(filename) {
  extern _poly_polys;
  extern _poly_names;
  new_polys = read_ascii_shapefile(filename, meta);
  new_names = array(string, dimsof(new_polys));
  base = file_rootname(file_tail(filename));
  for(i = 1; i <= numberof(new_polys); i++) {
    if(meta(noop(i))(*,"NAME"))
      new_names(i) = meta(noop(i))("NAME");
    else if(meta(noop(i))(*,"TILE_NAME"))
      new_names(i) = swrite(format="%s_%s", base, meta(noop(i))("TILE_NAME"));
    else
      new_names(i) = swrite(format="%s_%d", base, i);
  }
  grow, _poly_polys, new_polys;
  grow, _poly_names, new_names;

  polygon_sanitize;
  polygon_refresh_tcl;
}

func polygon_cs2cs(src, dst) {
/* DOCUMENT polygon_cs2cs, src, dst
  Converts all defined polygons from one coordinate system to another.

  To convert from UTM to lat/lon:
    polygon_cs2cs, cs_wgs84(zone=16), cs_wgs84()

  To convert from lat/lon to UTM:
    polygon_cs2cs, cs_wgs84(), cs_wgs84(zone=16)

  If a polygon lacks a Z dimension, 0 is temporarily used (and then
  discarded).
*/
  extern _poly_polys;
  shape_cs2cs, _poly_polys, src, dst;
}

func polygon_summarize {
/* DOCUMENT polygon_summarize
  Quick summary of defined polygons, including coordinate system, number of
  points, and name.
*/
  extern _poly_polys, _poly_names;
  sizes = array(string, numberof(_poly_names));
  css = array(string, numberof(_poly_names));
  for(i = 1; i <= numberof(_poly_polys); i++) {
    ply = *_poly_polys(i);
    sizes(i) = swrite(format="%d", numberof(ply(1,)));
    css(i) = ply(1,1) < 1000 ? "geo" : "utm";
  }
  fmtlen = max(3, strlen(sizes)(max));
  fmt = swrite(format="%%s %%%ds %%s\n", fmtlen);
  write, format=fmt, "cs ", "pts", "name";
  write, format=fmt, "---", array("-", fmtlen)(sum), array("-", strlen(_poly_names)(max))(sum);
  write, format=fmt, css, sizes, _poly_names;
}
