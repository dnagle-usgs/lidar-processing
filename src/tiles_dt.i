// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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

func extract_dtcell(text, dtlength=, dtprefix=) {
/* DOCUMENT extract_dtcell(text, dtlength=, dtprefix=)
   Attempts to extract a data tile cell name from each string in TEXT.
   See extract_dt for info on options.
*/
   local e, n, z, q, c;
   default, dtlength, "short";
   default, dtprefix, 1;
   dt2utm_km, text, e, n, z, q, c;
   w = where(bool(e) & bool(n) & bool(z) & bool(q) & bool(c));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d" : "e%d000_n%d000_%d";
   fmt += "_%s%02d";
   if(dtprefix) fmt = "c_" + fmt;
   if(numberof(w))
      result(w) = swrite(format=fmt, e(w), n(w), z(w), q(w), c(w));
   return result;
}

func extract_dtquad(text, dtlength=, dtprefix=) {
/* DOCUMENT extract_dtquad(text, dtlength=, dtprefix=)
   Attempts to extract a data tile quad name from each string in TEXT.
   See extract_dt for info on options.
*/
   local e, n, z, q;
   default, dtlength, "short";
   default, dtprefix, 1;
   dt2utm_km, text, e, n, z, q;
   w = where(bool(e) & bool(n) & bool(z) & bool(q));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d_%s" : "e%d000_n%d000_%d_%s";
   if(dtprefix) fmt = "q_" + fmt;
   if(numberof(w))
      result(w) = swrite(format=fmt, e(w), n(w), z(w), q(w));
   return result;
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

func utm2dt_names(east, north, zone, dtlength=, dtprefix=) {
/* DOCUMENT dt = utm2dt_names(north, east, zone, dtlength=, dtprefix=)
   For a set of UTM eastings, northings, and zones, this will calculate the
   set of data tiles that encompass all the points. This is equivalent to
      dt = set_remove_duplicates(utm2dt(east, north, zone))
   but works much more efficiently (and faster).
*/
   east = long(floor(unref(east)/2000.));
   north = long(ceil(unref(north)/2000.));
   code = long(unref(zone)) * 1000 * 10000 + unref(east) * 10000 + unref(north);
   code = set_remove_duplicates(unref(code));
   north = code % 10000;
   code /= 10000;
   east = code % 1000;
   zone = code / 1000;
   return extract_dt(swrite(format="e%d_n%d_%d", east*2, north*2, zone),
      dtlength=dtlength, dtprefix=dtprefix);
}

func utm2dtquad(east, north, zone, &quad) {
/* DOCUMENT utm2dtquad, east, north, &quad
   -or-  tile = utm2dtquad(north, east, zone)
   Like utm2dtcell, but only provides quad information. Data tile e123_n4567_15
   quad B has the quad name:
      t_e123000_n4567000_15_B
   SEE ALSO: utm2dtcell
*/
   utm2dtcell, east, north, q;
   if(am_subroutine()) {
      quad = q;
   } else {
      return utm2dt(east, north, zone, dtlength="long") + "_" + q;
   }
}

func utm2dtcell(east, north, zone, &quad, &cell) {
/* DOCUMENT utm2dtcell, north, east, &quad, &cell
   -or-  tile = utm2dtcell(north, east, zone)

   Provides the quad and cell for the given northing/easting values within
   their data tile. -OR- Returns a tile name that incorporates the quad and
   cell. For data tile e123_n4567_15 quad B cell 9, the cell tile name is:
      t_e123000_n4567000_15_B09

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

   if(am_subroutine()) {
      quad = quad_map(qe, qn);
      cell = cell_map(ce, cn);
   } else {
      return utm2dt(east, north, zone, dtlength="long") + \
         swrite(format="_%s%02d", quad, cell);
   }
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

func utm2it_names(east, north, zone, dtlength=, dtprefix=) {
/* DOCUMENT it = utm2it_names(east, north, zone, dtlength=, dtprefix=)
   For a set of UTM eastings, northings, and zones, this will calculate the
   set of index tiles that encompass all the points. This is equivalent to
      it = set_remove_duplicates(utm2it(east, north, zone))
   but works much more efficiently (and faster).
*/
   east = long(floor(unref(east)/10000.0));
   north = long(ceil(unref(north)/10000.0));
   code = long(unref(zone)) * 10000000 + unref(east) * 10000 + unref(north);
   code = set_remove_duplicates(unref(code));
   north = code % 10000;
   code /= 10000;
   east = code % 1000;
   zone = code / 1000;
   return extract_it(swrite(format="e%d0_n%d0_%d", east, north, zone),
      dtlength=dtlength, dtprefix=dtprefix);
}

func dt2uz(dtcodes) {
/* DOCUMENT dt2uz(dtcodes)
   Returns the UTM zone(s) for the given dtcode(s).
*/
// Original David Nagle 2009-07-06
   local zone;
   dt2utm_km, dtcodes, , , zone;
   return zone;
}

func dtcell2utm(dtcodes, &east, &north, &zone, bbox=, centroid=) {
/* DOCUMENT dtcell2utm(dtcodes, &east, &north, &zone, bbox=, centroid=)
   Like dt2utm, but for cells.
*/
   local e, n, z, q, c;
   dt2utm_km, dtcodes, e, n, z, q, c;
   e *= 1000;
   n *= 1000;
   q = where(["A","B","C","D"] == q)(1) - 1;
   c--;

   qeoff = q / 2;
   qnoff = q % 2;
   ceoff = c / 4;
   cnoff = c / 4;

   e += (qeoff * 1000 + ceoff * 250);
   n -= (qnoff * 1000 + cnoff * 250);

   if(am_subroutine()) {
      north = n;
      east = e;
      zone = z;
      return;
   }

   if(is_void(z))
      return [];
   else if(bbox)
      return [n - 250, e + 250, n, e, z];
   else if(centroid)
      return [n - 125, e + 125, z];
   else
      return [n, e, z];
}

func dtquad2utm(dtcodes, &east, &north, &zone, bbox=, centroid=) {
/* DOCUMENT dtquad2utm(dtcodes, &east, &north, &zone, bbox=, centroid=)
   Like dt2utm, but for quads.
*/
   local e, n, z, q;
   dt2utm_km, dtcodes, e, n, z, q;
   e *= 1000;
   n *= 1000;
   q = where(["A","B","C","D"] == q)(1) - 1;

   qeoff = q / 2;
   qnoff = q % 2;

   e += qeoff * 1000;
   n -= qnoff * 1000;

   if(am_subroutine()) {
      north = n;
      east = e;
      zone = z;
      return;
   }

   if(is_void(z))
      return [];
   else if(bbox)
      return [n - 1000, e + 1000, n, e, z];
   else if(centroid)
      return [n - 500, e + 500, z];
   else
      return [n, e, z];
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
//  Original David Nagle 2008-07-21
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
   dtcodes = utm2dt_names(east, north, zone, dtlength="long");
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      dtcodes = extract_dt(unref(dtcodes));
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
   itcodes = utm2it_names(east, north, zone, dtlength="long");
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      itcodes = extract_dt(unref(itcodes));
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

   // Only show 1km tiles if range is >= 8km
   if(y1 - y0 >= 8000) {
      plgrid, indgen(y0:y1:10000), indgen(x0:x1:10000), color=[170,120,170],
         width=7;
   }

   window_select, old_w;
}
