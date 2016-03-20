// vim: set ts=2 sts=2 sw=2 ai sr et:

func dt2utm_km(dtcodes, &east, &north, &zone, &quad, &cell) {
/* DOCUMENT dt2utm_km, dtcodes, &east, &north, &zone, &quad, &cell
  Parses the given data or index tile codes and sets the key easting,
  northing, zone, quad, and cell values. Values are in kilometers.
*/
  regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_([A-D])(0[1-9]|1[0-6])?)?(_|\\.|$)", dtcodes, , , east, , north, , zone, , quad, cell;
  east = atoi(east);
  north = atoi(north);
  zone = atoi(zone);
  cell = atoi(cell);
}

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
  w = where(bool(e) & bool(n) & bool(z));
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
  type = tile_type(tile);
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
  idx = munique(east, north, zone);
  east = east(idx);
  north = north(idx);
  zone = zone(idx);
  return helper.tile(east, north, zone, dtlength=dtlength, dtprefix=dtprefix);
}

utm2dt_names = closure(__utm2_names, save(size=2000, tile=utm2dt));
utm2it_names = closure(__utm2_names, save(size=10000, tile=utm2it));
__utm2_names = [];

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

func draw_grid(w) {
/* DOCUMENT draw_grid, w
  Draws a 10k/2k grid in window W using the window's current limits. The grid
  will contain one or more of the following kinds of grid lines:
    10km tile: violet
    2km tile: red
    1km quad: dark grey (dashed)
    250m cell: light grey (dashed)
  SEE ALSO: show_grid_location draw_qq_grid
*/
  local x0, x1, y0, y1;
  default, w, 5;
  old_w = current_window();
  window, w;
  ll = long(limits()/2000) * 2000;

  // Only show 10km tiles if range is >= 8km; otherwise, 2km
  if(ll(4) - ll(3) >= 8000) {
    ll = long(ll/10000)*10000;
    ll([2,4]) += 10000;
  } else {
    ll([2,4]) += 2000;
  }
  assign, ll, x0, x1, y0, y1;

  // Only show quads and cells when within 4km
  if (y1 - y0 <= 4000) {
    plgrid, indgen(y0:y1:250), indgen(x0:x1:250), color=[200,200,200],
      width=0.1, type="dash";
    plgrid, indgen(y0:y1:1000), indgen(x0:x1:1000), color=[120,120,120],
      width=0.1, type="dash";
  }

  // Always show 2km tile, though with a smaller width when zoomed out
  width = (y1 - y0 >= 8000) ? 3 : 5;
  plgrid, indgen(y0:y1:2000), indgen(x0:x1:2000), color=[250,140,140],
    width=width;

  // Only show 10km tiles if range is >= 8km
  if(y1 - y0 >= 8000) {
    // Adding 9999 combined with the :10000 step makes sure we round up to the
    // next full 10km grid cell when we are in 2km mode.
    plgrid, indgen(y0:y1+9999:10000), indgen(x0:x1+9999:10000),
      color=[170,120,170], width=7;
  }

  window_select, old_w;
}
