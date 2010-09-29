// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_qq(text, qqprefix=) {
/* DOCUMENT extract_qq(text, qqprefix=)

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

   If qqprefix=1, then the name will be prefixed by "qq".
*/
//  Original David Nagle 2008-07-17
   regmatch, "(^|_|qq)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   if(qqprefix) qq = "qq" + qq;
   return qq;
}

func qq2uz(qq) {
/* DOCUMENT qq2uz(qq)
   Returns the UTM zone that the given quarter quad is expected to fall in.
   Since UTM zones are exactly six degrees longitude in width and have
   boundaries that coincide with full degrees of longitude, and since the
   quarter quad scheme is based on fractions of degrees longitude, any given
   quarter quad is guaranteed to fall in exactly one UTM zone.

   In practical terms, however, numbers sometimes do not computer properly.
   Occasionally a few points along the border will get placed wrong. Also,
   it is possible that the UTM coordinates may have been forcibly projected
   in an alternate UTM zone. So proceed with caution.
*/
// Original David Nagle 2008-07-15
   center = qq2utm(qq, centroid=1);
   return long(center(..,3));
}

func qq2utm(qq, &north, &east, &zone, bbox=, centroid=) {
/* DOCUMENT qq2utm(qq, bbox=, centroid=)
   -or-  qq2utm, qq, north, east, zone

   Returns the northwest coordinates for the given qq as an array of [north,
   west, zone]. This is the coordinates for the northwest corner; however, it
   may not be the northmost or westmost point.

   If bbox=1, then it instead returns the bounding box as an array of [south,
   east, north, west, zone]. (Note that this does not exactly match the tile's
   boundary since bbox is in UTM but tile is in lat/long.)

   If centroid=1, then it returns the tile's central point.

   If called as subroutine, sets northwest coordinates in given output
   variables
*/
   local lats, lone, latn, lonw, e, n, z;
   splitary, qq2ll(qq, bbox=1), lats, lone, latn, lonw;

   // Calculate central point
   ll2utm, (lats+latn)/2., (lone+lonw)/2., n, e, z;

   if(!am_subroutine() && centroid)
      return [n, e, z];

   if(am_subroutine() || !bbox) {
      ll2utm, latn, lonw, n, e, force_zone=z;
      if(!am_subroutine())
         return [n, e, z];
      north = n;
      east = e;
      zone = z;
      return;
   }

   local xne, xse, xnw, xne, yne, yse, ynw, yne;
   ll2utm, latn, lone, yne, xne, force_zone=z;
   ll2utm, latn, lonw, ynw, xnw, force_zone=z;
   ll2utm, lats, lone, yse, xse, force_zone=z;
   ll2utm, lats, lonw, ysw, xsw, force_zone=z;

   return [min(yse, ysw), max(xne, xse), max(yne, ynw), min(xnw, xsw), z];
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

func calc24qq(lat, lon, qqprefix=) {
/* DOCUMENT qq = calc24qq(lat, lon, qqprefix=)

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
   if(anyof(lat < 0))
      error, "Latitude values must be positive.";
   if(anyof(lon > 0))
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

   fmt = "%02d%03d%s%d%s";
   if(qqprefix) fmt = "qq" + fmt;
   return swrite(format=fmt, dlat, dlon, alat(qlat), qlon, aqq(qq));
}

func utm2qq(east, north, zone, qqprefix=) {
/* DOCUMENT qq = utm2qq(east, north, zone)
   Returns the quarter-quad tile name for each east, north, and zone coordinate.
*/
   ll = int(utm2ll(north, east, zone)/0.0625) * 0.0625;
   return calc24qq(ll(*,2), ll(*,1), qqprefix=qqprefix);
}
func get_utm_qqcodes(north, east, zone) { return utm2qq(east, north, zone); }

func utm2qq_names(east, north, zone, qqprefix=) {
/* DOCUMENT qq = utm2qq_names(east, north, zone, qqprefix=)
   For a set of UTM eastings, northings, and zones, this will calculate the set
   of index tiles that encompass all the points. This is equivalent to
      qq = set_remove_duplicates(utm2qq(east, north, zone))
   but works much more efficiently (and faster).
*/
   local lon, lat;
   utm2ll, north, east, zone, lon, lat;
   lon = long(lon/.0625) + 3000;
   lat = long(lat/.0625) + 3000;
   code = long(unref(lat) * 10000 + unref(lon));
   code = set_remove_duplicates(unref(code));
   lat = code / 10000;
   lon = unref(code) % 10000;
   lat = (unref(lat) - 3000) * .0625;
   lon = (unref(lon) - 3000) * .0625;
   return calc24qq(lat, lon, qqprefix=qqprefix);
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
   qqcodes = utm2qq_names(east, north, zone);

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

func draw_qq_grid(win, pts=) {
/* DOCUMENT draw_qq_grid, win, pts=
   Draws a quarter quad grid for the given window. This will draw all quads and
   quarter quads that fall within the visible region in the given window. Quads
   are in red, quarter quads in grey.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   If the current plot crosses UTM zone boundaries, please set fixedzone.

   SEE ALSO: draw_grid
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
