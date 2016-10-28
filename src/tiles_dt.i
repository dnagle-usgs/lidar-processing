// vim: set ts=2 sts=2 sw=2 ai sr et:

func dt_tile_type(regex, tile) {
  // Anything that has match is a ut tile. The prefix determines the type,
  // unless there is no prefix, in which case it's dt.

  local match;
  regmatch, regex, tile, match;

  // This supports both scalar and array input, so some hoops are jumped
  // through to avoid having to index into arrays (which fails on scalars).

  is_match = bool(match);
  has_prefix = strpart(tile, 2:2) == "_";
  prefix = strpart(tile, 1:1);

  is_dt = (is_match & !has_prefix) | (is_match & has_prefix & prefix == "t");
  dt_type = [string(0),"dt"](1 + is_dt);

  is_ot = is_match & !is_dt;
  // zero and the weird math, once transposed, gives a pair of [0,2] for valid
  // tiles and [0,-1] for invalid tiles. That results in returning the prefix
  // string for valid tiles and string(0) for invalid.
  zero = is_match * 0;
  ot_type = strpart(prefix+"t", transpose([zero, is_ot * 3 - 1]));

  // At most only one of them is non-nil, so concatenating them is safe
  return dt_type + ot_type;
}
dt_tile_type = closure(dt_tile_type, regcomp(
  "(^|_)e([1-9][0-9]{2})(000|)_n([1-9][0-9]{0,3}|10000|0)(\\3)_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)"));

func dt2utm_km(regex, dtcodes, &east, &north, &zone, &quad, &cell) {
/* DOCUMENT dt2utm_km, dtcodes, &east, &north, &zone, &quad, &cell
  Parses the given data or index tile codes and sets the key easting,
  northing, zone, quad, and cell values. Values are in kilometers.
*/
  regmatch, regex, dtcodes, , , east, , north, , zone, , quad, cell;
  east = atoi(east);
  north = atoi(north);
  zone = atoi(zone);
  cell = atoi(cell);
}
dt2utm_km = closure(dt2utm_km, regcomp(
  "(^|_)e([1-9][0-9]{2})(000|)_n([1-9][0-9]{0,3}|10000|0)(\\3)_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_([A-D])(0[1-9]|1[0-6])?)?(_|\\.|$)"));

func extract_dt(text, dtlength=, dtprefix=) {
/* DOCUMENT extract_dt(text, dtlength=, dtprefix=)
  Attempts to extract a data tile name from each string in TEXT.

  Options:
    dtlength= Dictates whether to use the short or long form for data tile
      names. Valid values:
        dtlength="short"     Short form (default)
        dtlength="long"      Long form
    dtprefix= Dictates whether the tile name should be prefixed with "t_".
      Valid values:
        dtprefix=1     Apply prefix (default when dtlength=="long")
        dtprefix=0     Omit prefix (default when dtlength=="short")
*/
  local e, n, z;
  default, dtlength, "short";
  default, dtprefix, (dtlength == "long");
  dt2utm_km, text, e, n, z;
  w = where(bool(e) & bool(z));
  result = array(string(0), dimsof(text));
  fmt = (dtlength == "short") ? "e%d_n%d_%d" : "e%d000_n%d000_%d";
  if(dtprefix) fmt = "t_" + fmt;
  if(numberof(w))
    result(w) = swrite(format=fmt, e(w), n(w), z(w));
  return result;
}

func extract_it(text, dtlength=, dtprefix=) {
/* DOCUMENT extract_it(text, dtlength=, dtprefix=)
  Attempts to extract an index tile name from each string in TEXT.

  Options:
    dtlength= Dictates whether to use the short or long form for index tile
      names. Valid values:
        dtlength="short"     Short form (default)
        dtlength="long"      Long form
    dtprefix= Dictates whether the tile name should be prefixed with "i_".
      Valid values:
        dtprefix=1     Apply prefix (default)
        dtprefix=0     Omit prefix
*/
  default, dtprefix, 1;
  result = extract_dt(text, dtlength=dtlength, dtprefix=0);
  w = where(result);
  if(dtprefix && numberof(w))
    result(w) = "i_" + result(w);
  return result;
}

func utm2dt(east, north, zone, dtlength=, dtprefix=) {
/* DOCUMENT dt = utm2dt(east, north, zone, dtlength=)
  Returns the 2km data tile name for each east, north, and zone coordinate.
*/
  e = floor(east/2000.)*2;
  n = ceil(north/2000.)*2;
  return extract_dt(swrite(format="e%.0f_n%.0f_%d", e, n, long(zone)),
    dtlength=dtlength, dtprefix=dtprefix);
}

func dt2it(dt, dtlength=, dtprefix=) {
/* DOCUMENT dt2it(dt, dtlength=)
  Returns the index tile that corresponds to a given data tile.
*/
  local e, n, z;
  dt2utm, dt, e, n, z;
  return utm2it(e, n, z, dtlength=dtlength, dtprefix=dtprefix);
}

func utm2it(east, north, zone, dtlength=, dtprefix=) {
/* DOCUMENT it = utm2it(east, north, zone, dtlength=)
  Returns the 10km data tile name for each east, north, and zone coordinate.
*/
  e = floor(east/10000.);
  n = ceil(north/10000.);
  return extract_it(swrite(format="e%.0f0_n%.0f0_%d", e, n, long(zone)),
    dtlength=dtlength, dtprefix=dtprefix);
}

func dt2utm_corner(tile, &east, &north, &zone) {
/* DOCUMENT dt2utm_corners(tile)
  -or- dt2utm_corners, tile, &east, &north, &zone
  Wrapper around dt2utm, it2utm, etc. that autodetects the tile type and
  returns the northwest corner of the tile.
*/
  if(!is_scalar(tile)) error, "only works for scalar input";
  east = north = zone = [];
  type = dt_tile_type(tile);
  funcs = save(dt=dt2utm, it=it2utm);
  if(!funcs(*,type)) return;
  if(!am_subroutine()) return funcs(noop(type))(tile);
  splitary, funcs(noop(type))(tile), east, north, zone;
}

func utm2dt_corners(&east, &north, size) {
/* DOCUMENT utm2dt_corners, &east, &north, size
  Finds the northwest corner of the tile (with the given size) each coordinate
  is located in. Coordinates are updated in place.
*/
  size = double(size);
  east = long(floor(east/size) * size);
  north = long(ceil(north/size) * size);
}

local utm2dt_names, utm2it_names;
/* DOCUMENT
  tiles = utm2it_names(east, north, zone, dtlength=, dtprefix=)
  tiles = utm2dt_names(east, north, zone, dtlength=, dtprefix=)

  For a set of UTM eastings, northings, and zones, each of these calculate the
  set of tiles that encompass the given points. This is equivalent to, for
  example,
    dt = set_remove_duplicates(utm2dt(east, north, zone))
  but works much more efficiently and faster.
*/

func __utm2_names(helper, east, north, zone, dtlength=, dtprefix=) {
  utm2dt_corners, east, north, helper.size;
  if(is_scalar(zone)) zone = array(zone, dimsof(east));
  if(numberof(east) > 1) {
    idx = munique(east, north, zone);
    east = east(idx);
    north = north(idx);
    zone = zone(idx);
  }
  return helper.tile(east, north, zone, dtlength=dtlength, dtprefix=dtprefix);
}

utm2dt_names = closure(__utm2_names, save(size=2000, tile=utm2dt));
utm2it_names = closure(__utm2_names, save(size=10000, tile=utm2it));
__utm2_names = [];

func extract_for_dt_tile(x, y, zone, tile, buffer=) {
/* DOCUMENT extract_for_dt_tile(x, y, zone, tile, buffer=)
  This will return an index into x/y of all coordinates that fall within the
  bounds of the given tile.

  The buffer= option specifies a buffer in meters to include about the tile. By
  default, buffer=100.
*/
  local xmin, xmax, ymin, ymax;
  default, buffer, 100;
  bbox = tile2bbox(tile);
  assign, bbox(:4) + [-1,1,1,-1] * buffer, ymin, xmax, ymax, xmin;
  w = data_box(x, y, xmin, xmax, ymin, ymax, keepxmax=0, keepymin=0);
  if(numberof(w)) w = w(where(zone(w) == tile2uz(tile)));
  return numberof(w) ? w : [];
}

func dt2uz(dtcodes) {
/* DOCUMENT dt2uz(dtcodes)
  Returns the UTM zone(s) for the given dtcode(s).
*/
  local zone;
  dt2utm_km, dtcodes, , , zone;
  return zone;
}

func dt2utm(dtcodes, &east, &north, &zone, bbox=, centroid=) {
/* DOCUMENT dt2utm(dtcodes, bbox=, centroid=)
  dt2utm, dtcodes, &north, &east, &zone

  Returns the northwest coordinates for the given dtcodes as an array of
  [north, west, zone].

  If bbox=1, then it instead returns the bounding boxes, as an array of
  [south, east, north, west, zone].

  If centroid=1, then it returns the tile's central point.

  If called as a subroutine, it sets the northwest coordinates of the given
  output variables.
*/
  local e, n, z;
  dt2utm_km, dtcodes, e, n, z;
  e *= 1000;
  n *= 1000;

  if(am_subroutine()) {
    north = n;
    east = e;
    zone = z;
    return;
  }

  if(is_void(z))
    return [];
  else if(bbox)
    return [n - 2000, e + 2000, n, e, z];
  else if(centroid)
    return [n - 1000, e + 1000, z];
  else
    return [n, e, z];
}

func it2utm(itcodes, bbox=, centroid=) {
/* DOCUMENT it2utm(itcodes, bbox=, centroid=)
  Returns the northwest coordinates for the given itcodes as an array of
  [north, west, zone].

  If bbox=1, then it instead returns the bounding boxes, as an array of
  [south, east, north, west, zone].

  If centroid=1, then it returns the tile's central point.
*/
  u = dt2utm(itcodes);

  if(is_void(u))
    return [];
  else if(bbox)
    return [u(..,1) - 10000, u(..,2) + 10000, u(..,1), u(..,2), u(..,3)];
  else if(centroid)
    return [u(..,1) -  5000, u(..,2) +  5000, u(..,3)];
  else
    return u;
}

func draw_grid(win, show_it=, show_dt=, show_kt=, show_ht=) {
/* DOCUMENT draw_grid, win
  Draws UTM tile grid lines in window WIN. Up to four kinds of lines may be
  drawn. By default, lines are shown based on the window's limits, but each
  kind may be forced on or off with the option indicated.

    show_it=    10km index tile     thick violet line
    show_dt=    2km data tile       thick red line
    show_kt=    1km tile            dashed grey line
    show_ht=    500m tile           dotted grey line
  SEE ALSO: show_grid_location draw_qq_grid
*/
  local x0, x1, y0, y1;
  default, win, 5;
  winbkp = current_window();
  window, win;

  lims = limits();
  assign, lims, x0, x1, y0, y1;
  dist = max(x1-x0, y1-y0);

  // Plot moves around if limits aren't fixed, which makes things very slow on
  // big plots. Fix the limits for now, but they'll be restored later.
  limits, x0, x1, y0, y1;

  default, show_it, dist >= 8000;
  default, show_dt, 1;
  default, show_kt, dist <= 5000;
  default, show_ht, dist <= 3000;

  // Snap bounds to largest tile size
  if(show_it) {
    snap = 10000;
  } else if(show_dt) {
    snap = 2000;
  } else if(show_kt) {
    snap = 1000;
  } else {
    snap = 500;
  }
  x0 = long(floor(x0/snap)) * snap;
  x1 = long(ceil(x1/snap)) * snap;
  y0 = long(floor(y0/snap)) * snap;
  y1 = long(ceil(y1/snap)) * snap;

  if(show_ht) {
    plgrid, indgen(y0:y1:500), indgen(x0:x1:500), color=[208,208,208],
      width=0.1, type="dot";
  }
  if(show_kt) {
    plgrid, indgen(y0:y1:1000), indgen(x0:x1:1000), color=[208,208,208],
      width=0.1, type="dash";
  }
  if(show_dt) {
    plgrid, indgen(y0:y1:2000), indgen(x0:x1:2000), color=[250,140,140],
      width=5;
  }
  if(show_it) {
    plgrid, indgen(y0:y1:10000), indgen(x0:x1:10000),
      color=[170,120,170], width=7;
  }

  limits, lims;
  window_select, winbkp;
}
