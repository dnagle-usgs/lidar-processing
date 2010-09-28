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
   default, dtprefix, (dtlength == "long");
   dt2utm_km, text, e, n, z, q, c;
   w = where(bool(e) & bool(n) & bool(z) & bool(q) & bool(c));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d" : "e%d000_n%d000_%d";
   fmt += "_%s%02d";
   if(dtprefix) fmt = "t_" + fmt;
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
   default, dtprefix, (dtlength == "long");
   dt2utm_km, text, e, n, z, q;
   w = where(bool(e) & bool(n) & bool(z) & bool(q));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d_%s" : "e%d000_n%d000_%d_%s";
   if(dtprefix) fmt = "t_" + fmt;
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
