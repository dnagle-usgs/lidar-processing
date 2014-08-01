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
    ply = double(*shp(i));
    if(dimsof(ply)(2) > 2) {
      write, f, format=fmt+",%.3f\n", ply(1,), ply(2,), ply(3,);
    } else {
      write, f, format=fmt+"\n", ply(1,), ply(2,);
    }
    write, f, format="%s", "\n";
  }
  close, f;
}

func plot_poly(ply, color=, width=, vertices=) {
  extern utm;

  if(numberof(ply(1,)) < 1) return;

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
    if(vertices)
      plmk, ply(2,), ply(1,), marker=4, msize=.2+.1*width, width=10*width, color=color;
  } else if(numberof(ply(1,)) == 1) {
    plmk, ply(2,), ply(1,), marker=1, color=color, msize=0.1;
  }
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
  extern utm, curzone;
  for(i = 1; i <= numberof(shp); i++) {
    ply = *shp(i);

    if(numberof(ply(1,)) < 1) {
      write, "Skipping polygon with zero points."
      continue;
    }

    plot_poly, ply, color=color, width=width;
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

func region_to_shp(region, utm=, ll=) {
/* DOCUMENT shp = region_to_shp(region, utm=, ll=)
  Returns a shapefile array for the area(s) defined by REGION.

  The return result is an array of pointers. Each pointee is a poly array.

  REGION can be any of the following:

    - A scalar string that matches an existing file is treated as a shapefile.
    - A scalar string that does not match an existing file and does not contain
      a / is parsed as a tile name (such as "e234_n5234_15").
    - A two-element string array is interpreted as a group,name pair for
      polyplot(get,) (to reference a poly defined in the plotting tool). For
      example, if you imported "MyRegion.xyz" and it contains polys named
      "aoi1" and "aoi2", you could use ["MyRegion.xyz","aoi1"] to use the aoi1
      poly or you could use ["MyRegion.xyz",""] to use all polys from the
      MyRegion.xyz group.
    - A four-element numerical vector is interpreted as an array of [xmin,
      xmax, ymin, ymax].
    - A five-element numerical vector is interpreted as the output of limits()
      (which is [xmin, xmax, ymin, ymax, flags]; flags is ignored).
    - A two-dimensional numerical array is interpreted as a single poly.
    - An array of pointers is interpreted as a shapefile array.

  If REGION does not match any of the above, an error will be triggered.

  By default, the polys in the output array will be in their native coordinate
  systems (and may not be consistent from one poly to the next). Use utm=1 to
  coerce all of them to UTM or use ll=1 to coerce all of them to lat/lon. Using
  one of these options is strongly recommended since you otherwise cannot be
  sure what coordiante system your polys are in (or if they are even
  consistent).
*/
  extern curzone;

  if(utm && ll) error, "cannot use both utm=1 and ll=1 at the same time";

  if(is_string(region)) {
    if(is_scalar(region)) {
      if(file_exists(region)) {
        shp = read_ascii_shapefile(region);
      } else if(!strmatch(region, "/")) {
        tile = extract_tile(region);
        if(strlen(tile))
          region = tile2bbox(tile)([2,4,1,3]);
      }
    } else if(is_vector(region) && numberof(region) == 2) {
      shp = polyplot(get, region);
      if(is_numerical(shp)) shp = [&shp];
    }
  }

  if(is_numerical(region)) {
    if(is_vector(region)) {
      // for normal bounds or for the result of limits()
      if(numberof(region) == 4 || numberof(region) == 5) {
        shp = [&region([[1,3],[1,4],[2,4],[2,3],[1,3]])];
      }
    } else if(is_matrix(region)) {
      shp = [&region];
    }
  }

  if(is_pointer(region) && is_vector(region)) {
    // (*) forces a copy so that utm/ll do not alter the original
    shp = region(*);
  }

  n = numberof(shp);
  if(!n) error, "unable to handle region provided";

  if(utm) {
    for(i = 1; i <= n; i++) {
      ply = *shp(i);
      if(ply(1,1) <= 360) {
        shp(i) = &(ll2utm(ply(2,), ply(1,), force_zone=curzone)([2,1],));
      }
    }
  }
  if(ll) {
    for(i = 1; i <= n; i++) {
      ply = *shp(i);
      if(ply(1,1) > 360) {
        shp(i) = &transpose(utm2ll(ply(2,), ply(1,), curzone));
      }
    }
  }

  return shp;
}

func region_to_string(region) {
/* DOCUMENT region_to_string(region)
  Given a region (as accepted by region_to_shp), this returns a string that
  describes the region. See region_to_shp for details on what is accepted.
*/
  if(is_string(region)) {
    if(is_scalar(region)) {
      if(file_exists(region)) {
        result = "shapefile: "+region;
      } else if(!strmatch(region, "/")) {
        tile = extract_tile(region);
        if(strlen(tile))
          result = "tile: "+region;
      }
    } else if(is_vector(region) && numberof(region) == 2) {
      result = "polyplot selection: "+print(region)(sum);
      // Hacky little trick to also include poly coordinates
      result += strpart(region_to_string(region_to_shp(region)), 17:);
    }
  }

  if(is_numerical(region)) {
    if(is_vector(region)) {
      // for normal bounds or for the result of limits()
      if(numberof(region) == 4 || numberof(region) == 5) {
        result = "bounding box: "+print(region(:4))(sum);
      }
    } else if(is_matrix(region)) {
      result = "polygon:\n";
      result += strjoin(print(region), "\n");
    }
  }

  if(is_pointer(region)) {
    result = "shapefile array:";
    n = numberof(region);
    for(i = 1; i <= n; i++) {
      result += swrite(format="\nshp(%d) =\n", i);
      result += strjoin(print(*region(i)), "\n");
    }
  }

  if(is_void(result))
    error, "unable to handle region provided";
  return result;
}

func region_to_bbox(region, geo=) {
/* DOCUMENT bbox = region_to_bbox(region, geo=)
  Returns the bounding box for the specified region.

  Options:
    geo= By default, UTM coordinates are assumed. Use geo=1 to force lat/lon
      coordinates.
*/
  default, geo, 0;

  shp = region_to_shp(region, utm=!geo, ll=geo);

  xmin = ymin =  1e+100;
  xmax = ymax = -1e+100;

  for(i = 1; i <= numberof(shp); i++) {
    x = (*shp(i))(1,);
    y = (*shp(i))(2,);

    xmin = min(xmin, x(min));
    xmax = max(xmax, x(max));
    ymin = min(ymin, y(min));
    ymax = max(ymax, y(max));
  }

  return [xmin, xmax, ymin, ymax];
}

func region_limits(region, win=, geo=, expand=, square=) {
/* DOCUMENT region_limits, region, win=, geo=, expand=, square=
  Resets the window's limits to the specified region. REGION should be any
  region accepted by region_to_shp.

  Options:
    win= The window to apply the limits to. Uses the current window by default.
    geo= By default, UTM coordinates are assumed. Use geo=1 to force lat/lon
      coordinates.
    expand= This specifies a factor by which to expand the limits, leaving a
      bit of extra space around the plot.
        expand=0      By default, no expansion
        expand=0.02   Expand by 2%, which is 1% on each side
    square= By default, the plot will be squared (the x and y scales will be
      forced to be equal). If you do not want that, use square=0.
*/
  default, geo, 0;
  default, expand, 0;
  default, square, 1;

  local xmin, xmax, ymin, ymax;
  assign, region_to_bbox(region, geo=geo), xmin, xmax, ymin, ymax;

  if(expand > 0) {
    // Cut expand in half so that it can be applied on each side.
    expand /= 2;

    xdif = (xmax - xmin) * expand;
    ydif = (ymax - ymin) * expand;
    xmin -= xdif;
    xmax += xdif;
    ymin -= ydif;
    ymax += ydif;
  } else if(expand < 0) {
    write, "WARNING: region_limits: expand= is less than 0; ignoring"
  }

  if(square) {
    win_square, [xmin, xmax, ymin, ymax], win=win;
  } else {
    default, win, current_window();
    wbkp = current_window();
    window, win;
    limits, xmin, xmax, ymin, ymax, square=0;
    window_select, wbkp;
  }
}
