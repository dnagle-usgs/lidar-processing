// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_tile(text, dtlength=, qqprefix=) {
/* DOCUMENT extract_tile(text, dtlength=, qqprefix=)
   Attempts to extract a tile name from each string in the given array of text.

   Options:
      dtlength= Dictates which kind of data tile name is returned when a data
         tile is detected. (Note: This has no effect on index tile names.)
         Valid values:
            dtlength="short"  Returns short form (default)
            dtlength="long"   Returns long form

      qqprefix= Dictates whether quarter quad tiles should be prefixed with
         "qq". Useful if they're going to be used as variable names. Valid
         values:
            qqprefix=0      No prefix added (default)
            qqprefix=1      Prefix added

   If a tile has an ambiguous name, then index tile names take priority over
   data tile names and data tile names take priority over quarter quad names.
   If a tile does not contain a parseable name, then a nil string is yielded.
*/
// Original David Nagle 2009-12-09
   default, dtlength, "short";
   default, qqprefix, 0;
   qq = extract_qq(text);
   dt = (dtlength == "short") ? dt_short(text) : dt_long(text);
   it = "i_" == strpart(text, 1:2);

   result = array(string, dimsof(text));

   w = where(strlen(dt) > 0 & it);
   if(numberof(w))
      result(w) = get_dt_itcodes(dt(w));

   w = where(strlen(dt) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = dt(w);

   w = where(strlen(qq) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = (qqprefix ? "qq" : "") + qq(w);

   return result;
}

func guess_tile(text, dtlength=, qqprefix=) {
/* DOCUMENT guess_tile(text, dtlength=, qqprefix=)
   Calls extract_tile and returns its result if it finds a valid tile name.
   Otherwise, attempts to guess a 2km tile name from the string. This
   currently will catch 2km tile names that do not have a zone identifier in
   the string.
*/
   local e, n, z;
   extern curzone;

   tile = extract_tile(text);
   w = where(!tile);
   if(numberof(w)) {
      regmatch, "e([1-9][0-9]{2}).*n([1-9][0-9]{3})", text(w), , e, n;
      wen = where(!(!e) & !(!n));
      if(numberof(wen))
         tile(w(wen)) = swrite(format="e%s_n%s_%d", e(wen), n(wen), curzone);
   }
   return tile;
}

func tile_type(text) {
/* DOCUMENT tile_type(text)
   Returns string indicating the type of tile used.

   The return result (scalar or array, depending on the input) will have
   strings that mean the following:

      "dt" - Two-kilometer data tile
      "it" - Ten-kilometer index tile
      "qq" - Quarter quad tile
      (nil) - Unparseable
*/
   qq = extract_qq(text);
   dt = dt_short(text);
   it = "i_" == strpart(text, 1:2);

   result = array(string, dimsof(text));

   w = where(strlen(dt) > 0 & it);
   if(numberof(w))
      result(w) = "it";

   w = where(strlen(dt) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = "dt";

   w = where(strlen(qq) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = "qq";

   return result;
}

func tile2uz(tile) {
/* DOCUMENT tile2uz(tile)
   Attempts to return a UTM zone for each tile in the array given. This is a
   wrapper around dt2uz and qq2uz. If both yield a result, then dt2uz wins
   out. 0 indicates that neither yielded a result.
*/
   tile = extract_tile(tile);

   dt = dt2uz(tile);
   qq = qq2uz(tile);

   result = dt;
   w = where(result == 0 & qq != 0);
   if(numberof(w)) {
      if(dimsof(result)(1))
         result(w) = qq(w);
      else
         result = qq;
   }

   return result;
}

func tile2bbox(tile) {
/* DOCUMENT bbox = tile2bbox(tile)
   Returns the bounding box for a tile: [south,east,north,west].
*/
   tile = extract_tile(tile, dtlength="long", qqprefix=1);
   key = strpart(tile, 1:1);

   if(key == "q") {
      zone = qq2uz(tile);
      ll = qq2ll(tile, bbox=1); // [south, east, north, west]
      lats = ll([1,3,1,3]);
      lons = ll([2,4,4,2]);
      norths = easts = [];
      fll2utm, lats, lons, norths, easts, force_zone=zone;
      return [norths(min), easts(max), norths(max), easts(min)];
   } else if(key == "t") {
      return dt2utm(tile, bbox=1);
   } else if(key == "i") {
      return it2utm(tile, bbox=1);
   } else {
      return [];
   }
}

func extract_qq(text) {
/* DOCUMENT extract_qq(text)

   Extract the quarter quad string from a text string. The text string will
   probably be a filename or similar. The expected rules it will follow:

   - The QQ name may be optionally preceeded by other text, but must be
     separated by an underscore if so.
   - The QQ name may be optionally followed by other text, but must be
     separated by either an underscore or a period if so.
   - The QQ name must be exactly 8 characters in length, and must use lowercase
     alpha instead of uppercase alpha where relevant.

   This function will work on scalars or arrays. The returned result will be
   the quarter quad name(s). If there is no quarter quad to extract, it will
   be string(0).
*/
//  Original David Nagle 2008-07-17
   regmatch, "(^|_|qq)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   return qq;
}

func dt_short(dtcodes) {
/* DOCUMENT shortnames = dt_short(dtcodes)
   Returns abbreviated names for an array of data tile codes. Strings that
   aren't data tile codes become string(0).

   Example:

      > dt_short("t_e466000_n3354000_16")
      "e466_n3354_16"
*/
//  Original David Nagle 2008-07-21
   e = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
   w = where( !(!e) & !(!n) & !(!z) );
   result = array(string(0), dimsof(dtcodes));
   if(numberof(w))
      result(w) = swrite(format="e%s_n%s_%s", e(w), n(w), z(w));
   return result;
}

func dt_long(dtcodes) {
/* DOCUMENT longnames = dt_long(dtcodes)
   Returns full names for an array of data tile codes. Strings that aren't
   data tile codes become string(0).

   Example:

      > dt_long("e466_n3354_16")
      "t_e466000_n3354000_16"
*/
//  Original David Nagle 2008-08-07
   e = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
   w = where( !(!e) & !(!n) & !(!z) );
   result = array(string(0), dimsof(dtcodes));
   if(numberof(w))
      result(w) = swrite(format="t_e%s000_n%s000_%s", e(w), n(w), z(w));
   return result;
}

func dt2uz(dtcodes) {
/* DOCUMENT dt2uz(dtcodes)
   Returns the UTM zone(s) for the given dtcode(s).
*/
// Original David Nagle 2009-07-06
   zone = [];
   dt2utm, dtcodes, , , zone;
   return zone;
}

func dt2utm(dtcodes, &north, &east, &zone, bbox=, centroid=) {
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
//  Original David Nagle 2008-07-21
   e = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
   w = where( ! (!(!e) & !(!n) & !(!z)) );
   if(numberof(w)) {
      e(w) = "0";
      n(w) = "0";
      z(w) = "0";
   }
   e = atoi(e + "000");
   n = atoi(n + "000");
   z = atoi(z);

   if(am_subroutine()) {
      north = n;
      east = e;
      zone = z;
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
//  Original David Nagle 2008-07-21
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

func get_utm_dtcodes(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcodes(north, east, zone)
   For a set of UTM northings, eastings, and zones, this will calculate each
   coordinate's data tile name and return an array of strings that correspond
   to them.
*/
//  Original David Nagle 2008-07-21
   return swrite(format="t_e%.0f000_n%.0f000_%d",
      floor(east /2000.0)*2,
      ceil (north/2000.0)*2,
      int(zone));
}

func get_utm_dt_quadcell(north, east, &quad, &cell) {
/* DOCUMENT get_utm_dt_quadcell, north, east, &quad, &cell
   Sets the quad and cell for the given northing/easting values within their
   data tile.

   A 2km-square data tile has four quads, each 1km-square. They are laid out
   as:
      +---+---+
      | A | B |
      +---+---+
      | C | D |
      +---+---+

   A 1km-square quad has sixteen cells, each 250m-square. They are laid out
   as:
      +----+----+----+----+
      |  1 |  2 |  3 |  4 |
      +----+----+----+----+
      |  5 |  6 |  7 |  8 |
      +----+----+----+----+
      |  9 | 10 | 11 | 12 |
      +----+----+----+----+
      | 12 | 13 | 14 | 16 |
      +----+----+----+----+
*/
   quad_map = [["C","D"],["A","B"]];
   cell_map = [indgen(13:16),indgen(9:12),indgen(5:8),indgen(1:4)];

   tn = floor(north/2000.)*2000;
   qn = long(north - tn)/1000 + 1;
   cn = long(north - tn - (qn*1000 - 1000)) / 250 + 1;

   te = floor(east/2000.)*2000;
   qe = long(east - te)/1000 + 1;
   ce = long(east - te - (qe*1000 - 1000)) / 250 + 1;

   quad = quad_map(qe, qn);
   cell = cell_map(ce, cn);
}

func get_dt_itcodes(dtcodes) {
/* DOCUMENT it = get_dt_itcodes(dtcodes)
   For an array of data tile codes, this will return the corresponding index
   tile codes.

   Original David Nagle 2008-07-21
*/
   north = east = zone = [];
   dt2utm, dtcodes, north, east, zone;
   north = int(ceil(north/10000.)*10000.);
   east = int(floor(east/10000.)*10000.);
   return swrite(format="i_e%i_n%i_%i", east, north, zone);
}

func qq2uz(qq, centroid=) {
/* DOCUMENT qq2uz(qq, centroid=)

   Returns the UTM zone that the given quarter quad is expected to fall in.
   Since UTM zones are exactly six degrees longitude in width and have
   boundaries that coincide with full degrees of longitude, and since the
   quarter quad scheme is based on fractions of degrees longitude, any given
   quarter quad is guaranteed to fall in exactly one UTM zone.

   In practical terms, however, numbers sometimes do not computer properly.
   Occasionally a few points along the border will get placed wrong. Also,
   it is possible that the UTM coordinates may have been forcibly projected
   in an alternate UTM zone. So proceed with caution.

   If set to 1, the centroid= option will return the UTM coordinates of the
   center of the quarter quad rather than just the zone. This may be useful
   if trying to determine whether the expected zone corresponds to the data
   on hand.

   Original David Nagle 2008-07-15
*/
   default, centroid, 0;
   bbox = qq2ll(qq, bbox=1);
   invalid = where((bbox == 0)(..,sum) == 4);
   u = array(double, 3, dimsof(qq));
   u(*) = fll2utm( bbox(..,[1,3])(..,avg), bbox(..,[2,4])(..,avg) )(*);
   if(numberof(invalid))
      u(,invalid) = 0;
   if(centroid)
      return u;
   else
      return long(u(3,));
}

func qq2ll(qq, bbox=) {
/* DOCUMENT ll = qq2ll(qq, bbox=)

   Returns the latitude and longitude of the SE corner of the 24k Quarter-Quad
   represented by the give code (or array of codes).

   Return value is [lat, lon].

   If bbox=1, then return value is [south, east, north, west].

   See calc24qq for documentation on the 24k Quarter-Quad format.
*/
   default, bbox, 0;
   qq = extract_qq(qq);

   lat = array(double(0.), dimsof(qq));
   lon = array(double(0.), dimsof(qq));

   valid = where(qq);
   if(numberof(valid)) {
      qq = qq(valid);

      AA    = atoi(strpart(qq, 1:2));
      OOO   = atoi(strpart(qq, 3:5));
      a     =      strpart(qq, 6:6);
      o     = atoi(strpart(qq, 7:7));
      q     =      strpart(qq, 8:8);

      lat(valid) = AA;
      lon(valid) = OOO;

      // The following line converts a-h to 0-7
      a = int(atoc(strcase(0,a))) - int(atoc("a"));
      a *= 0.125;
      lat(valid) += a;

      o = o - 1;
      o = o * 0.125;
      lon(valid) += o;

      // The following line converts a-d to 1-4
      q = int(atoc(strcase(0,q))) - int(atoc("a")) + 1;
      qa = (q == 2 | q == 3);
      qo = (q >= 3);

      qa = qa * 0.0625;
      qo = qo * 0.0625;

      lat(valid) += qa;
      lon(valid) += qo;
   }

   if(bbox) {
      north = lat;
      west = lon;
      if(numberof(valid)) {
         north(valid) += 0.0625;
         west(valid) += 0.0625;
      }
      return [lat, -1 * lon, north, -1 * west];
   } else {
      return [lat, -1 * lon];
   }
}

func draw_grid(w) {
/* DOCUMENT draw_grid, w
   Draws a 10k/2k grid in window W using the window's current limits. The grid
   will contain one or more of the following kinds of grid lines:
      10km tile: violet
      2km tile: red
      1km quad: dark grey
      250m cell: light grey
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
         width=0.1;
      plgrid, indgen(y0:y1:1000), indgen(x0:x1:1000), color=[120,120,120],
         width=0.1;
   }

   // Always show 2km tile, though with a smaller width when zoomed out
   width = (y1 - y0 >= 8000) ? 3 : 5;
   plgrid, indgen(y0:y1:2000), indgen(x0:x1:2000), color=[250,140,140],
      width=width;

   // Only show 1km tiles if range is >= 8km
   if(y1 - y0 >= 8000) {
      plgrid, indgen(y0:y1:10000), indgen(x0:x1:10000), color=[170,120,170],
         width=7;
   }

   window_select, old_w;
}

func show_grid_location(m) {
/* DOCUMENT show_grid_location, win
   -or- show_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the index tile,
   data tile, quad name, and cell name.
   SEE ALSO: draw_grid show_qq_grid_location
*/
   extern curzone;
   local quad, cell;
   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }
   write, format="10km index tile : %s\n", get_utm_itcodes(m(2), m(1), curzone);
   get_utm_dt_quadcell, m(2), m(1), quad, cell;
   write, format="2km data tile   : %s   quad %s cell %d\n",
      get_utm_dtcodes(m(2), m(1), curzone), quad, cell;
}

func draw_qq_grid(win, pts=) {
/* DOCUMENT draw_qq_grid, win, pts=
   Draws a quarter quad grid for the given window. This will draw all quads and
   quarter quads that fall within the visible region in the given window. Quads
   are in red, quarter quads in grey.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   If the current plot crosses UTM zone boundaries, please set fixedzone.

   SEE ALSO: show_qq_grid_location draw_grid
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   extern curzone;
   if(!curzone) {
      write, "Please define curzone. draw_qq_grid aborting";
      return;
   }

   old_win = window();
   window, win;
   lims = limits();

   // Pull utm into directional variables
   w = lims(1);
   e = lims(2);
   s = lims(3);
   n = lims(4);

   // Make the limits sticky to avoid repeated redraw performance hit
   limits, w, e, s, n;

   // Get lat/lon coords for each corner
   ne = utm2ll(n, e, curzone);
   nw = utm2ll(n, w, curzone);
   se = utm2ll(s, e, curzone);
   sw = utm2ll(s, w, curzone);

   // Re-assign the directional variables to lat/lon extremes
   w = min(nw(1), sw(1));
   e = max(ne(1), se(1));
   s = min(sw(2), se(2));
   n = max(nw(2), ne(2));

   ew = 0.125 * indgen(int(floor(w*8.0)):int(ceil(e*8.0)));
   ns = 0.125 * indgen(int(floor(s*8.0)):int(ceil(n*8.0)));

   llgrid = [ew(-,), ns(,-)];
   qq = calc24qq(llgrid(*,2), llgrid(*,1));

   draw_q, qq, win, pts=pts;
   window, old_win;
}

func draw_qq(qq, win, pts=) {
/* DOCUMENT draw_qq, qq, win, pts=
   Draws a grey box for the given quarter quad(s) in the given window.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   for(i = 1; i <= numberof(qq); i++) {
      bbox = qq2ll(qq(i), bbox=1);
      draw_ll_box, bbox, win, pts=pts, color=[120,120,120];
   }
}

func draw_q(qq, win, pts=) {
/* DOCUMENT draw_qq, qq, win, pts=
   For the given quarter quad(s), red boxes will be drawn for the quads and
   grey boxes will be drawn inside for the quarter quads, in the given window.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   q = set_remove_duplicates(strpart(qq, 1:-1));
   for(i = 1; i <= numberof(q); i++) {
      draw_qq, q(i) + ["a","b","c","d"], win, pts=pts;
      q_a = qq2ll(q(i)+"a", bbox=1);
      q_c = qq2ll(q(i)+"c", bbox=1);
      bbox = [q_a(1), q_a(2), q_c(3), q_c(4)];
      draw_ll_box, bbox, win, pts=pts*2+1, color=[250,20,20];
   }
}

func draw_ll_box(bbox, win, pts=, color=) {
/* DOCUMENT draw_ll_box, bbox, win, pts=, color=
   Given a lat/lon bounding box (as [south, east, north, west]), this will
   draw it in utm in the given window.

   If given pts= specifies how many points to drop along each side of the
   box between corners. Default is pts=3. Minimum is pts=1.

   If given color= specifies the color to draw with. Default is black.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   default, color, "black";
   ll_x = grow(
      array(bbox(2), pts+1), span(bbox(2), bbox(4), pts+2),
      array(bbox(4), pts), span(bbox(4), bbox(2), pts+2) );
   ll_y = grow(
      span(bbox(1), bbox(3), pts+2), array(bbox(3), pts),
      span(bbox(3), bbox(1), pts+2), array(bbox(1), pts+1) );
   utm = fll2utm(ll_y, ll_x);
   u_x = utm(2,);
   u_y = utm(1,);

   old_win = window();
   window, win;
   plg, u_y, u_x, color=color;
   window, old_win;
}

func show_qq_grid_location(m) {
/* DOCUMENT show_qq_grid_location, win
   -or- show_qq_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the quarter quad
   tile name.
   SEE ALSO: draw_qq_grid show_grid_location
*/
   extern curzone;
   if(!curzone) {
      write, "Aborting. Please define curzone.";
      return;
   }
   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }
   qq = get_utm_qqcodes(m(2), m(1), curzone);
   write, format="Quarter Quad: %s\n", qq(1);
}

func get_utm_dtcode_coverage(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcode_coverage(north, east, zone)
   For a set of UTM northings, eastings, and zones, this will calculate the
   set of data tiles that encompass all the points.

   This is equivalent to
      dt = set_remove_duplicates(get_utm_dtcodes(north,east,zone))
   but works much more efficiently (and faster).
*/
// Original David Nagle 2009-07-09
   east = long(floor(unref(east)/2000.0));
   north = long(ceil(unref(north)/2000.0));
   code = long(unref(zone)) * 1000 * 10000 + unref(east) * 10000 + unref(north);
   code = set_remove_duplicates(unref(code));
   north = code % 10000;
   code /= 10000;
   east = code % 1000;
   zone = code / 1000;
   return swrite(format="t_e%d000_n%d000_%d", east*2, north*2, zone);
}

func get_utm_itcodes(north, east, zone) {
/* DOCUMENT it = get_utm_itcodes(north, east, zone)
   For a set of UTM northings, eastings, and zones, this will calculate each
   coordinate's index tile name and return an array of strings that correspond
   to them.
*/
//  Original David Nagle 2009-07-09
   return swrite(format="i_e%.0f000_n%.0f000_%d",
      floor(east /10000.0)*10,
      ceil (north/10000.0)*10,
      int(zone));
}

func get_utm_itcode_coverage(north, east, zone) {
/* DOCUMENT it = get_utm_itcode_coverage(north, east, zone)
   For a set of UTM northings, eastings, and zones, this will calculate the
   set of index tiles that encompass all the points.

   This is equivalent to
      it = set_remove_duplicates(get_utm_itcodes(north,east,zone))
   but works much more efficiently (and faster).
*/
// Original David Nagle 2009-07-09
   east = long(floor(unref(east)/10000.0));
   north = long(ceil(unref(north)/10000.0));
   code = long(unref(zone)) * 10000000 + unref(east) * 10000 + unref(north);
   code = set_remove_duplicates(unref(code));
   north = code % 10000;
   code /= 10000;
   east = code % 1000;
   zone = code / 1000;
   return swrite(format="i_e%d0000_n%d0000_%d", east, north, zone);
}

func calc24qq(lat, lon) {
/* DOCUMENT qq = calc24qq(lat, lon)

   Provides the 24k Quarter-Quad code as per the system used by CLICK. The lat
   and lon values should be the southeast corner of the tile. Quarter-quads are
   each 1/16 of a degree in width and height. They are referenced on the NAD83
   Datum.

   These codes have the following structure:

      AAOOOaoq

   Where

      AA is the positive whole number component of the latitude.

      OOO is the positive whole number component of the longitude (zero-padded
         to a width of 3).

      a is an alpha character a-h designating which quad in the degree of
         latitude, where a is closest to 0 minutes and h is closest to the next
         full degree. Each represents 1/8 of a degree.

      o is a numeral 1-8 designating which quad in the degree of longitude,
         where 1 is closest to 0 minutes and 8 is closest to the next full
         degree. Each represents 1/8 of a degree.

      q is an alpha character a-d designating which quarter in the quad, where
         a is SE, b is NE, c is NW, and d is SW. Each quarter-quad is 1/16 of
         a degree in latitude and 1/16 of a degree in longitude.

   For example, 47104h2c means:

      47 - 47 degrees latitude
      104 - 104 degrees longitude

      The section is in the degree range starting 47N 104W.

      h - h is the 8th in sequence, so it's the last section and would start at
         7/8 of a degree, or 0.875
      2 - 2 is the 2nd in sequence, so it's the 2nd section and would start at
         1/8 of a degree, or 0.125

      The quad's SE corner is 47.875N, 104.125W.

      c - c is the NW corner, which means we must add 1/16 degree to both N and
         W, or 0.0625 to each.

      The quarter-quad's SE corner is 47.9375N, 104.1875W.

   Correspondingly, calc24qq(47.9375, -104.1875) results in "47104h2c".

   These codes are only valid for locations with positive latitude and negative
      longitude.

   Parameters:

      lat, lon: Must be in decimal degree format. May be a single value each or
         an array of values each. Must be in the NAD83 projection, or
         equivalent.

   Returns:

      A string or array of strings containing the codes.

   See also: get_utm_qqcodes get_conusqq_data qq_segment_pbd
*/
   if(numberof(where(lat < 0)))
      error, "Latitude values must be positive.";
   if(numberof(where(lon > 0)))
      error, "Longitude values must be negative.";
   dlat = int(abs(lat));
   dlon = int(abs(lon));

   flat = abs(lat) - dlat;
   flon = abs(lon) - dlon;

   qlat = int(flat * 8.0) + 1;
   qlon = int(flon * 8.0) + 1;

   qq = int(2 * (flat * 16 % 2) + (flon * 16 % 2) + 1);

   alat = ["a", "b", "c", "d", "e", "f", "g", "h"];
   aqq = ["a", "d", "b", "c"];

   return swrite(format="%02d%03d%s%d%s", dlat, dlon, alat(qlat), qlon, aqq(qq));
}

func get_utm_qqcodes(north, east, zone) {
/* DOCUMENT qq = get_utm_qqcodes(north, east, zone)

   For a set of UTM northings, eastings, and zones, this will calculate
   each coordinate's quarter-quad code name and return an array of strings
   that correspond to them.

   See also: calc24qq qq_segment_pbd
*/
   // Convert the coordinates to lat/lon, coercing them into their quarter-quad
   // corner points
   ll = int(utm2ll(north, east, zone)/0.0625) * 0.0625;
   // Then feed to calc24qq
   return calc24qq(ll(*,2), ll(*,1));
}

func get_utm_qqcode_coverage(north, east, zone) {
/* DOCUMENT qq = get_utm_qqcode_coverage(north, east, zone)
    For a set of UTM northings, eastings, and zones, this will calculate the
    set of quarter-quad tiles that encompass all the points.

    This is equivalent to
        qq = set_remove_duplicates(get_utm_qqcodes(north,east,zone))
    but works much more efficiently (and faster).
*/
// Original David Nagle 2009-07-09
   ll = utm2ll(north,east,zone);
   lat = long(ll(*,2)/0.0625);
   lon = long(ll(*,1)/0.0625);
   ll = [];
   lat += 3000;
   lon += 3000;
   code = long(unref(lat) * 10000 + unref(lon));
   code = set_remove_duplicates(unref(code));
   lat = code / 10000;
   lon = unref(code) % 10000;
   lat -= 3000;
   lon -= 3000;
   lat *= 0.0625;
   lon *= 0.0625;
   return calc24qq(lat, lon);
}

func get_utm_dtcode_candidates(north, east, zone, buffer) {
/* DOCUMENT dtcodes = get_utm_dtcode_candidates(north, east, zone, buffer)

   Quickly generates a list of data tiles that might be contained within the
   given northings, eastings, and zones using the given buffer.

   The returned dtcodes are NOT guaranteed to all exist within the data.
   However, it is guaranteed that the array of dtcodes will contain all dtcodes
   that are covered in the data.

   Original David Nagle 2008-07-21
*/
   e_min = floor((east (min)-buffer)/2000.0)*2000;
   e_max = ceil ((east (max)+buffer)/2000.0)*2000;
   n_min = floor((north(min)-buffer)/2000.0)*2000;
   n_max = ceil ((north(max)+buffer)/2000.0)*2000;
   es = indgen(int(e_min):int(e_max):2000);
   ns = indgen(int(n_min):int(n_max):2000);
   coords = [es(*,),ns(,*)];
   return swrite(format="t_e%d_n%d_%d", coords(*,1), coords(*,2), int(zone));
}

func extract_for_tile(north, east, zone, tile, buffer=) {
/* DOCUMENT idx = extract_for_tile(north, east, zone, tile, buffer=);
   Wrapper around extract_for_qq, extract_for_dt, and extract_for_it.
   Automatically uses the right one.
*/
   tile = extract_tile(tile);
   type = tile_type(tile);

   if(type == "dt" || type == "it") {
      if(is_scalar(zone)) {
         if(zone != dt2uz(tile))
            return [];
      } else {
         w = where(zone == dt2uz(tile));
         if(!numberof(w))
            return [];
         north = north(w);
         east = east(w);
      }
      if(type == "dt")
         return extract_for_dt(north, east, tile, buffer=buffer);
      else
         return extract_for_it(north, east, tile, buffer=buffer);
   } else if(type == "qq") {
      return extract_for_qq(north, east, zone, tile, buffer=buffer);
   } else {
      error, "Unknown tiling type";
   }
}

func extract_for_qq(north, east, zone, qq, buffer=) {
/* DOCUMENT extract_for_qq(north, east, zone, qq, buffer=)

   This will return an index into north/east of all coordinates that fall
   within the bounds of the given quarter quad, which should be the string name
   of the quarter quad.

   The buffer= option specifies a buffer (in meters) to extend the quarter
   quad's boundaries by. By default, it is 100 meters.
*/
   // Original David Nagle 2008-07-17
   default, buffer, 100;
   bbox = qq2ll(qq, bbox=1);

   // ll(,1) is lon, ll(,2) is lat
   ll = utm2ll(north, east, zone);

   comp_lon = bound(ll(,1), bbox(4), bbox(2));
   comp_lat = bound(ll(,2), bbox(1), bbox(3));

   // comp_utm(1,) is north, (2,) is east
   comp_utm = fll2utm(unref(comp_lat), unref(comp_lon), force_zone=zone);

   dist = ppdist([unref(east), unref(north)], [comp_utm(2,), comp_utm(1,)], tp=1);
   // Adding 1mm to buffer to accommodate floating point error
   return where(dist <= buffer + 0.001);
}

func extract_for_dt(north, east, dt, buffer=) {
/* DOCUMENT extract_for_dt(north, east, dt, buffer=)

   This will return an index into north/east of all coordinates that fall
   within the bounds of the given 2k data tile dt, which should be the string
   name of the data tile.

   The buffer= option specifies a buffer in meters to extend the tile's
   boundaries by. By default, it is 100 meters. Setting buffer=0 will constrain
   the data to the exact tile boundaries.
*/
   // Original David Nagle 2008-07-21
   default, buffer, 100;
   bbox = dt2utm(dt, bbox=1);
   return extract_for_bbox(unref(north), unref(east), bbox, buffer);
}

func extract_for_it(north, east, it, buffer=) {
/* DOCUMENT extract_for_it(north, east, it, buffer=)

   This will return an index into north/east of all coordinates that fall
   within the bounds of the given 10k index tile it, which should be the string
   name of the index tile.

   The buffer= option specifies a buffer in meters to extend the tile's
   boundaries by. By default, it is 100 meters. Setting buffer=0 will constrain
   the data to the exact tile boundaries.
*/
   default, buffer, 100;
   bbox = it2utm(it, bbox=1);
   return extract_for_bbox(unref(north), unref(east), bbox, buffer);
}

func extract_for_bbox(north, east, bbox, buffer) {
/* DOCUMENT extract_for_bbox(north, east, bbox, buffer)

   This will return an index into north/east of all coordinates that fall
   within the bounds of the given bounding box bbox.

   The buffer argument specifies a buffer in meters to extend the bbox's
   boundaries by.
*/
   min_n = bbox(1) - buffer;
   max_n = bbox(3) + buffer;
   min_e = bbox(4) - buffer;
   max_e = bbox(2) + buffer;
   return where(
      min_n <= north & north <= max_n &
      min_e <= east  & east  <= max_e
   );
}

func calculate_qq_extents(qqdir, mode=, glob=, remove_buffers=) {
/* DOCUMENT calculate_qq_extents(qqdir, mode=, glob=, remove_buffers=)
   Calculates the lat/lon extents for a each quarter quad using the given
   directory of qq pbd files. Returns a Yeti hash with the results.
*/
   local n, e;
   fix_dir, qqdir;
   default, glob, "*.pbd";
   default, remove_buffers, 1;

   // Source files
   files = find(qqdir, glob=glob);

   qqs = h_new();

   // Iterate over the source files to determine the 2k tiles
   stamp = 0;
   timer_init, tstamp;
   write, "Scanning quarter quad data to determine extents...";
   for(i = 1; i<= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files);
      basefile = file_tail(files(i));
      qq = extract_qq(basefile);
      z = qq2uz(qq);
      
      // Load data
      data = pbd_load(files(i));
      if(!numberof(data))
         continue;
      data2xyz, unref(data), e, n, mode=mode;

      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         qq_list = get_utm_qqcodes(n, e, z);
         w = where(qq == qq_list);
         if(!numberof(w)) {
            write, "  Problem: No data found after buffers removed.";
            continue;
         }
         n = n(w);
         e = e(w);
      }

      // Convert data to lat/lon
      ll = utm2ll(n, e, z);

      // Find extents
      h_set, qqs, qq, h_new(
         "n", ll(max,2),
         "s", ll(min,2),
         "e", ll(max,1),
         "w", ll(min,1)
      );
   }
   return qqs;
}

func restrict_data_extent(data, tilename, buffer=, mode=) {
/* DOCUMENT data = restrict_data_extent(data, tilename, buffer=, mode=)
   Restricts the extent of the data based on its tile.

   Parameters:
      data: An array of EAARL data (VEG__, GEO, etc.).
      tilename: The name of the tile. Works for both 2k, 10k, and qq tiles.
         This can be the exact tile name (ie. "t_e123_n4567_12") or the tile
         name can be embedded (ie. "t_e123_n3456_12_n88.pbd").

   Options:
      buffer= A buffer in meters to apply around the tile. Default is 0, which
         constrains to the exact tile boundaries. A larger buffer will include
         more data.
      mode= The mode of the data. Can be any setting valid for data2xyz.
         "fs": First surface
         "be": Bare earth (default)
         "ba": Bathy
*/
// Original David Nagle 2009-11-23
   local e, n, idx;
   default, buffer, 0;
   default, mode, "be";

   data2xyz, data, e, n, mode=mode;
   tile = dt_short(tilename);
   if(tile) {
      if(strpart(tilename, 1:2) == "i_")
         idx = extract_for_it(unref(n), unref(e), tile, buffer=buffer);
      else
         idx = extract_for_dt(unref(n), unref(e), tile, buffer=buffer);
   } else {
      tile = extract_qq(tilename);
      if(tile)
         idx = extract_for_qq(unref(n), unref(e), qq2uz(tile), tile, buffer=buffer);
   }
   if(numberof(idx)) {
      data = data(unref(idx));
   } else {
      data = [];
   }
   return data;
}

func partition_into_2k(north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_into_2k(north, east, zone, buffer=, shorten=, verbose=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into 2km data tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      shorten= If set to 1, the tile names will be in the short form
         (e466_n3354_16). Default is long form (t_e466000_n3354000_16).
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;
   default, verbose, 0;

   if(verbose)
      write, "- Calculating 2km tile names...";
   dtcodes = get_utm_dtcode_coverage(north, east, zone);
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      dtcodes = dt_short(unref(dtcodes));
   }

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(dtcodes);
   for(i = 1; i <= numberof(dtcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(dtcodes), dtcodes(i);
      this_zone = dt2uz(dtcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_dt(data(1,), data(2,), dtcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, dtcodes(i), idx;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_into_10k(north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_into_10k(north, east, zone, buffer=, shorten=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into 10km index tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      shorten= If set to 1, the tile names will be in the short form
         (e460_n3350_16). Default is long form (i_e460000_n3350000_16).
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;
   default, verbose, 0;

   if(verbose)
      write, "- Calculating 10km tile names...";
   itcodes = get_utm_itcode_coverage(north, east, zone);
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      itcodes = dt_short(unref(itcodes));
   }

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(itcodes);
   for(i = 1; i <= numberof(itcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(itcodes), itcodes(i);
      this_zone = dt2uz(itcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_it(data(1,), data(2,), itcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, itcodes(i), idx;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_into_qq(north, east, zone, buffer=, verbose=) {
/* DOCUMENT partition_into_qq(north, east, zone, buffer=, verbose=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into quarter quad tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, verbose, 0;
   if(verbose)
      write, "- Calculating quarter-quad tile names...";
   qqcodes = get_utm_qqcode_coverage(north, east, zone);

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(qqcodes);
   for(i = 1; i <= numberof(qqcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(qqcodes), qqcodes(i);
      w = extract_for_qq(north, east, zone, qqcodes(i), buffer=buffer);
      if(numberof(w))
         h_set, tiles, qqcodes(i), w;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_by_tile_type(type, north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_by_tile_type(type, north, east, zone, buffer=, shorten=, verbose=)
   This is a wrapper around other partition types that allows the user to call
   the right one based on a type parameter.

   There are three legal values for type. They are listed below along with the
   functions each maps to.
      qq --> partition_into_qq
      2k --> partition_into_2k
      10k --> partition_into_10k

   Also:
      dt --> Alias for 2k
      it --> Alias for 10k

   Arguments and options are passed to the functions as is, as appropriate.
*/
// Original David B. Nagle 2009-04-01
   if(type == "qq") {
      return partition_into_qq(north, east, zone, buffer=buffer, verbose=verbose);
   } else if(type == "2k" || type == "dt") {
      return partition_into_2k(north, east, zone, buffer=buffer, verbose=verbose,
         shorten=shorten);
   } else if(type == "10k" || type == "it") {
      return partition_into_10k(north, east, zone, buffer=buffer, verbose=verbose,
         shorten=shorten);
   } else {
      error, "Invalid type";
   }
}

func partition_type_summary(north, east, zone, buffer=) {
/* DOCUMENT partition_type_summary, north, east, zone, buffer=
   Displays a summary of what the results would be for each of the
   partitioning schemes.
*/
// Original David B. Nagle 2009-04-07
   schemes = ["10k", "qq", "2k"];
   for(i = 1; i <= numberof(schemes); i++) {
      tiles = partition_by_tile_type(schemes(i), north, east, zone,
         buffer=buffer);
      write, format="Summary for: %s\n", schemes(i);
      tile_names = h_keys(tiles);
      write, format="  Number of tiles: %d\n", numberof(tile_names);
      counts = array(long, numberof(tile_names));
      for(j = 1; j <= numberof(tile_names); j++) {
         counts(j) = numberof(tiles(tile_names(j)));
      }
      qs = long(quartiles(counts));
      write, format="  Images per tile:%s", "\n";
      write, format="            Minimum: %d\n", counts(min);
      write, format="    25th percentile: %d\n", qs(1);
      write, format="    50th percentile: %d\n", qs(2);
      write, format="    75th percentile: %d\n", qs(3);
      write, format="            Maximum: %d\n", counts(max);
      write, format="               Mean: %d\n", long(counts(avg));
      write, format="                RMS: %.2f\n", counts(rms);
      write, format="%s", "\n";
   }
}

func save_data_to_tiles(data, zone, dest_dir, scheme=, mode=, suffix=, buffer=,
shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=, split_days=,
day_shift=) {
/* DOCUMENT save_data_to_tiles, data, zone, dest_dir, scheme=, mode=, suffix=,
   buffer=, shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=,
   split_days=, day_shift=

   Given an array of data (which must be in an ALPS data structure such as
   VEG__) and a scalar or array of zone corresponding to it, this will create
   PBD files in dest_dir partitioned using the given scheme.

   Parameters:
      data: Array of data in ALPS data struct
      zone: Scalar or array of UTM zone of data
      dest_dir: Destination directory for output pbd files

   Options:
      scheme= Should be one of the following; defaults to "10k2k".
         "qq" - Quarter quad tiles
         "2k" - 2-km data tiles
         "10k" - 10-km index tiles
         "10k2k" - Two-tiered index tile/data tile
      mode= Specifies the data mode to use. Can be any value valid for
         data2xyz.
            mode="fs"   First surface
            mode="ba"   Bathymetry
            mode="be"   Bare earth
      suffix= Specifies the suffix to use when naming the files. By default,
         files are named (tile-name).pbd. If suffix is provided, they will be
         named (tile-name)_(suffix).pbd. (Without the parentheses.)
      buffer= Specifies a buffer to include around each tile, in meters.
         Defaults to 100.
      shorten= By default (shorten=0), the long form of 2k, 10k, and 10k2k tile
         names will be used. If shorten=1, the short forms will be used.
      flat= If set to 1, then no directory structure will be created. Instead,
         all files will be created directly into dest_dir.
      uniq= With the default value of uniq=1, only unique data points
         (determined by soe) will be stored in the output pbd files; duplicates
         will be removed. Set uniq=0 to keep duplicate data points.
      overwrite= By default, data will be appended to any existing pbd files.
         Set overwrite=1 to clobber them instead.
      verbose= By default, progress information will be provided. Set verbose=0
         to silence it.
      split_zones= This can be set to one of the following three values:
            split_zones=0  Never split data out by zone. This is the default
                           for most schemes.
            split_zones=1  Split data out by zone if there are multiple zones
                           present. This is the default for the qq scheme.
            split_zones=2  Always split data out by zone, even if only one zone
                           is present.
         Note: If flat=1, split_zones is ignored.
      split_days= Enables splitting the data by day. If enabled, the per-day
         files for each tile will be kept together and will be differentiated
         by date in the filename.
            split_days=0      Do not split by day. (default)
            split_days=1      Split by days, adding _YYYYMMDD to filename.
      day_shift= Specifies an offset in seconds to apply to the soes when
         determining their YYYYMMDD value for split_days. This can be used to
         shift time periods into the previous/next day when surveys are flown
         close to UTC midnight. The value is added to soe only for determining
         the date; the actual soe values remain unchanged.
            day_shift=0          No shift; UTC time (default)
            day_shift=-14400     -4 hours; EDT time
            day_shift=-18000     -5 hours; EST and CDT time
            day_shift=-21600     -6 hours; CST and MDT time
            day_shift=-25200     -7 hours; MST and PDT time
            day_shift=-28800     -8 hours; PST and AKDT time
            day_shift=-32400     -9 hours; AKST time

   SEE ALSO: batch_tile
*/
// Original David Nagle 2009-07-06
   local n, e;
   default, scheme, "10k2k";
   default, mode, "fs";
   default, suffix, string(0);
   default, buffer, 100;
   default, shorten, 0;
   default, flat, 0;
   default, uniq, 1;
   default, overwrite, 0;
   default, verbose, 1;
   default, split_zones, scheme == "qq";
   default, split_days, 0;
   default, day_shift, 0;

   bilevel = scheme == "10k2k";
   if(bilevel) scheme = "2k";

   data2xyz, data, e, n, mode=mode;

   if(numberof(zone) == 1)
      zone = array(zone, dimsof(data));

   if(verbose)
      write, "Partitioning data...";
   tiles = partition_by_tile_type(scheme, n, e, zone, buffer=buffer,
      shorten=shorten, verbose=verbose);

   tile_names = h_keys(tiles);
   tile_names = tile_names(sort(tile_names));

   if(verbose)
      write, format=" Creating files for %d tiles...\n", numberof(tile_names);

   tile_zones = long(tile2uz(tile_names));
   uniq_zones = numberof(set_remove_duplicates(tile_zones));
   if(uniq_zones == 1 && split_zones == 1)
      split_zones = 0;
   for(i = 1; i <= numberof(tile_names); i++) {
      curtile = tile_names(i);
      idx = tiles(curtile);
      if(bilevel) {
         if(shorten)
            tiledir = file_join(
               swrite(format="i_%s", dt_short(get_dt_itcodes(curtile))),
               swrite(format="t_%s", curtile)
            );
         else
            tiledir = file_join(get_dt_itcodes(curtile), curtile);
      } else {
         tiledir = curtile;
      }
      vdata = data(idx);
      vzone = zone(idx);
      vname = (scheme == "qq") ? curtile : dt_short(curtile);
      tzone = tile_zones(i);

      // Coerce zones
      rezone_data_utm, vdata, vzone, tzone;

      outpath = dest_dir;
      if(!flat && split_zones)
         outpath = file_join(outpath, swrite(format="zone_%d", tzone));
      if(!flat && tiledir)
         outpath = file_join(outpath, tiledir);
      mkdirp, outpath;

      if(split_days) {
         dates = soe2date(vdata.soe + day_shift);
         date_uniq = set_remove_duplicates(dates);
         for(j = 1; j <= numberof(date_uniq); j++) {
            date_suffix = "_" + regsub("-", date_uniq(j), "", all=1);
            outfile = curtile + date_suffix;
            if(suffix) outfile += "_" + suffix;
            if(strpart(outfile, -3:) != ".pbd")
               outfile += ".pbd";

            outdest = file_join(outpath, outfile);

            if(overwrite && file_exists(outdest))
               remove, outdest;

            dname = vname + date_suffix;
            dw = where(dates == date_uniq(j));

            pbd_append, outdest, dname, vdata(dw), uniq=uniq;

            if(verbose)
               write, format=" %d: %s\n", i, outfile;
         }
      } else {
         outfile = curtile;
         if(suffix) outfile += "_" + suffix;
         if(strpart(outfile, -3:) != ".pbd")
            outfile += ".pbd";

         outdest = file_join(outpath, outfile);

         if(overwrite && file_exists(outdest))
            remove, outdest;

         pbd_append, outdest, vname, vdata, uniq=uniq;

         if(verbose)
            write, format=" %d: %s\n", i, outfile;
      }
   }
}

func batch_tile(srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
split_zones=, split_days=, day_shift=) {
/* DOCUMENT batch_tile, srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
   remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
   split_zones=, split_days=, day_shift=

   Loads the data in srcdir that matches searchstr= and partitions it into
   tiles, which are created in dstdir.

   Note: This operates in an "append" mode. If there are already files that
   have the same names as the files you are trying to create, they will be
   appended to. If you do not want that... delete them first!

   Parameters:
      srcdir: Directory of PBD data you want to tile.
      dstdir: Directory where your tiled data should go.

   Options:
      scheme= Partioning scheme to use. Valid values:
            scheme="10k2k"    Tiered 10km/2km structure (default)
            scheme="2k"       2km structure
            scheme="dt"       2km structure
            scheme="10k"      10km structure
            scheme="it"       10km structure
            scheme="qq"       Quarter quad structure
      mode= Mode of data. Valid values include:
            mode="fs"         First surface (default)
            mode="be"         Bare earth
            mode="ba"         Bathy
      searchstr= Search string to use when locating input data. Example:
            searchstr="*.pbd"    (default)
      suffix= Suffix to append to file names when creating them. If your suffix
         does not end in .pbd, it will be auto-appended. Examples:
            suffix=".pbd"        (default)
            suffix="w84_fs"
            suffix="n88_g09_merged_be.pbd"
      remove_buffers= By default, it is assumed that your input data are
         already tiled and that any buffer regions on those tiles is
         redundant--and probably not well manually filtered. Thus, by default
         the buffers around the input tiles are removed. If your file names
         cannot be parsed as tile names, you'll get a warning message but
         they'll still be tiled (without removing anything). Valid settings:
            remove_buffers=1     Attempt to remove source data buffers
                                 (default)
            remove_buffers=0     Use source data as is
      buffer= By default, output tiles will have a 100m buffer added to them.
         You can change that with this setting. Examples:
            buffer=100     Include 100m buffer (default)
            buffer=250     Include 250m buffer
            buffer=0       Do not include a buffer
      uniq= Specifies whether to discard points with matching soe values.
            uniq=1   Discard points with matching soe values (default)
            uniq=0   Keep all points, even duplicates
      verbose= Specifies how much output should go to the screen.
            verbose=2   Keeps you extremely well-informed
            verbose=1   Provides estimated time to completion (default)
            verbose=0   No screen output at all
      zone= By default, the zone will be determined on a file-by-file basis
         based on the file's name. If no parseable tile name can be determined,
         the file will be ignored. You can specify a zone to use for all files
         with this option.
            zone=[]     No zone provided, autodetect (default)
            zone=17     Force all input data to be treated as being in zone 17
            zone=-1     After loading the data, use data.zone (useful for ATM)
      shorten= By default, the longer form of the 2km data tile names will be
         used. This setting allows you to change that. Ignored if your scheme
         does not involve 2km data tiles.
            shorten=0   Use long form, t_e123000_n4567000_12 (default)
            shorten=1   Use short form, e123_n4567_12
      flat= By default, files will be created in a directory structure. This
         settings lets you force them all into a single directory.
            flat=0   Put files in tired directory structure. (default)
            flat=1   Put files all directly into dstdir.
      split_zones= Specifies how to handle multiple-zone data. This is ignored
         if flat=1. Valid settings:
            split_zones=0     Never split data by zone. (default for most
                              schemes)
            split_zones=1     Split by zone if multiple zones found (default
                              for qq)
            split_zones=2     Always split by zone, even if only one found
      split_days= Enables splitting the data by day. If enabled, the per-day
         files for each tile will be kept together and will be differentiated
         by date in the filename.
            split_days=0      Do not split by day. (default)
            split_days=1      Split by days, adding _YYYYMMDD to filename.
      day_shift= Specifies an offset in seconds to apply to the soes when
         determining their YYYYMMDD value for split_days. This can be used to
         shift time periods into the previous/next day when surveys are flown
         close to UTC midnight. The value is added to soe only for determining
         the date; the actual soe values remain unchanged.
            day_shift=0          No shift; UTC time (default)
            day_shift=-14400     -4 hours; EDT time
            day_shift=-18000     -5 hours; EST and CDT time
            day_shift=-21600     -6 hours; CST and MDT time
            day_shift=-25200     -7 hours; MST and PDT time
            day_shift=-28800     -8 hours; PST and AKDT time
            day_shift=-32400     -9 hours; AKST time

   SEE ALSO: save_data_to_tiles
*/
   default, mode, "fs";
   default, scheme, "10k2k";
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, verbose, 1;

   // Locate files
   files = find(srcdir, glob=searchstr);

   // Get zones
   zones = tile2uz(file_tail(files));
   if(!is_void(zone))
      zones(*) = zone;

   // Check for missing zones
   if(noneof(zones)) {
      write, "None of the file names contained a parseable zone. Please use the zone= option.";
      return;
   } if(nallof(zones)) {
      w = where(zones == 0)
      write, "The following file names did not contain a parseable zone and will be skipped.\n (Consider using zone= to avoid this.)";
      write, format=" - %s\n", file_tail(files(w));
      write, "";

      files = files(w);
      zones = zones(w);
   }

   srt = msort(zones, files);
   zones = zones(srt);
   files = files(srt);

   // Check for missing tiles, if we need them.
   tiles = extract_tile(file_tail(files));
   if(remove_buffers && nallof(tiles)) {
      w = where(!tiles);
      write, "The following file names did not contain a parseable tile name. They will be\n retiled, but they cannot have any buffers removed; remove_buffers=1 will be\n ignored for these files."
      write, format=" - %s\n", file_tail(files(w));
      write, "";
   }

   count = numberof(files);
   sizes = double(file_size(files));
   if(count > 1)
      sizes = sizes(cum)(2:);

   t0 = tp = array(double, 3);
   timer, t0;
   passverbose = max(0, verbose-1);
   for(i = 1; i <= count; i++) {
      if(verbose > 1)
         write, format="\n----------\nRetiling %d/%d: %s\n", i, count,
            file_tail(files(i));

      data = pbd_load(files(i));

      if(remove_buffers && tiles(i) && numberof(data)) {
         filezone = zones(i);
         if(filezone < 0) {
            filezone = data.zone;
         }
         e = n = [];
         data2xyz, data, e, n, mode=mode;
         idx = extract_for_tile(unref(n), unref(e), filezone, tiles(i), buffer=0);
         if(numberof(idx))
            data = data(idx);
         else
            data = [];
      }

      if(!numberof(data)) {
         if(verbose > 1)
            write, " - Skipping, no data found for tile";
         continue;
      }

      filezone = zones(i);
      if(filezone < 0) {
         filezone = data.zone;
      }
      save_data_to_tiles, unref(data), unref(filezone), dstdir, scheme=scheme,
         suffix=suffix, buffer=buffer, shorten=shorten, flat=flat, uniq=uniq,
         verbose=passverbose, split_zones=split_zones, split_days=split_days,
         day_shift=day_shift;

      if(verbose)
         timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
   }

   if(verbose)
      timer_finished, t0;
}
