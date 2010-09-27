// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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

func qqtiff_gms_prep(tif_dir, pbd_dir, mode, outfile, tif_glob=, pbd_glob=) {
/* DOCUMENT qqtiff_gms_prep, tif_dir, pbd_dir, mode, outfile, tif_glob=, pdb_glob=
   
   Creates a data tcl file that can be used by gm_tiff2ktoqq.tcl to generate a
   Global Mapper script that can be used to convert 2k data tile geotiffs into
   quarter quad geotiffs.

   Parameters:
   
      tif_dir: The directory containing the 2k tiled geotiffs.

      pbd_dir: The directory containing quarter quad pbds that contain the same
         source data points used to make the 2k data tiles repartitioned.

      mode: The type of EAARL data being used. Can be any value valid for
         data2xyz.
            mode="fs"   First surface
            mode="be"   Bare earth
            mode="ba"   Bathymetry

      outfile: The full path and filename to the output file to generate. This
         will be taken to Windows for use with gm_tiff2ktoqq.tcl.
   
   Options:
   
      tif_glob= A file glob that can be used to more specifically select the
         tiff files from their directory. Default is *.tif.

      pbd_glob= A file glob that can be used to more specifically select the
         pbd files from their directory. Default is *.pbd.
*/
   local e, n;
   fix_dir, tif_dir;
   fix_dir, pbd_dir;

   default, tif_glob, "*.tif";
   default, pbd_glob, "*.pbd";

   // Source files
   files = find(tif_dir, glob=tif_glob);

   // Scan pbds for exents
   extents = calculate_qq_extents(pbd_dir, mode=mode, glob=pbd_glob);

   qqcodes = h_new();

   // Iterate over the source files to determine the qq tiles
   write, "Scanning source files to generate list of QQ tiles...";
   for(i = 1; i<= numberof(files); i++) {
      basefile = file_tail(files(i));
      bbox = dt2utm(basefile, bbox=1);

      // Get four-corner qqcodes
      tile_qqcodes = set_remove_duplicates(
         get_utm_qqcodes(bbox([1,3,1,3]),
            bbox([2,2,4,4]), bbox([5,5,5,5]))
      );

      // Only keep qqcodes that are in extents
      tile_qqcodes = set_intersection(tile_qqcodes, h_keys(extents));

      for(j = 1; j <= numberof(tile_qqcodes); j++) {
         qlist = [];
         if(h_has(qqcodes, tile_qqcodes(j))) {
            qlist = grow(qqcodes(tile_qqcodes(j)), basefile);
         } else {
            qlist = [basefile];
         }
         h_set, qqcodes, tile_qqcodes(j), qlist;
      }
   }

   write, "Creating TCL input...";
   qqkeys = h_keys(qqcodes);
   f = open(outfile, "w");
   write, f, format="%s\n", "set ::qqtiles {";
   for(i = 1; i <= numberof(qqkeys); i++) {
      bbox = h_get(extents, qqkeys(i));
      write, f, format="  { {%s}\n", qqkeys(i);
      write, f, format="    {%.10f,%.10f,%.10f,%.10f}\n",
         bbox.w, bbox.s, bbox.e, bbox.n;
      for(j = 1; j <= numberof(qqcodes(qqkeys(i))); j++) {
         write, f, format="    {%s}\n", qqcodes(qqkeys(i))(j);
      }
      write, f, format="  }%s", "\n";
   }
   write, f, format="%s\n", "}";
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
