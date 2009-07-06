/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
require, "eaarl.i";
write, "$Id$";

local qq24k_i;
/* DOCUMENT qq24k_i

   Functions for the CLICK 24k Quarter-Quad tiling scheme and the 2k tiling
   scheme.

   Conversions:

      batch_2k_to_qq
      batch_qq_to_2k

   Quarter-quad processing:
   
      qq2uz
      extract_for_qq
      qq2ll
      calc24qq
      extract_qq
      get_conusqq_data
      get_utm_qqcodes

   Quarter-quad plotting:

      draw_qq
      draw_q
      draw_ll_box
      draw_qq_grid

   2k data tile processing:

      extract_for_dt
      get_utm_dtcodes
      get_dt_itcodes
      get_utm_dtcode_candidates
      dt_short
      dt2utm
      it2utm

   Miscellaneous:

      pbd_append
      qqtiff_gms_prep
      calculate_qq_extents

   Structs defined:

      CONUSQQ
*/

struct CONUSQQ {
   string   codeqq;
   double   lat;
   double   lon;
   string   name24k;
   string   state24k;
   string   code24k;
   int      utmzone;
   string   nedquad;
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
   u = array(double, 3, dimsof(qq));
   u(*) = fll2utm( bbox(..,[1,3])(..,avg), bbox(..,[2,4])(..,avg) )(*);
   if(centroid)
      return u;
   else
      return u(3,);
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
   return where(dist <= buffer);
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
   if(numberof(where(strlen(qq) != 8))) {
      write, "Not all input contained valid quarter quads. Aborting."
      return;
   }

   AA    = atoi(strpart(qq, 1:2));
   OOO   = atoi(strpart(qq, 3:5));
   a     =      strpart(qq, 6:6);
   o     = atoi(strpart(qq, 7:7));
   q     =      strpart(qq, 8:8);

   lat = AA;
   lon = OOO;

   // The following line converts a-h to 0-7
   a = int(atoc(strcase(0,a))) - int(atoc("a"));
   a *= 0.125;
   lat += a;

   o = o - 1;
   o = o * 0.125;
   lon += o;

   // The following line converts a-d to 1-4
   q = int(atoc(strcase(0,q))) - int(atoc("a")) + 1;
   qa = (q == 2 | q == 3);
   qo = (q >= 3);
   
   qa = qa * 0.0625;
   qo = qo * 0.0625;
   
   lat += qa;
   lon += qo;

   if(bbox)
      return [lat, -1 * lon, lat + 0.0625, -1 * (lon + 0.0625)];
   else
      return [lat, -1 * lon];
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

func get_conusqq_data(void) {
/* DOCUMENT get_conusqq_data()
   
   Loads and returns the CONUS quarter quad data from ../CONUSQQ/conusqq.pbd.
   This file can be downloaded from

      lidar.net:/mnt/alps/eaarl/tarfiles/CONUSQQ/conusqq.pbd

   It should be placed in the directory eaarl/lidar-processing/CONUSQQ/, which
   makes its relative path ../CONUSQQ/ from the perspective of Ytk (when run
   from lidar-processing/src).

   This data was collected from a shapefile provided by Jason Stoker of the
   USGS.  It uses a quarter quad tile scheme as described in calc24qq. This
   data provides additional information for each tile.

   The return data is an array of CONUSQQ.

   See also: calc24qq
*/
   fname = "../CONUSQQ/conusqq.pbd";
   if(!open(fname,"r",1)) {
      message = "The conus quarter-quad data is not available. Please download it from lidar.net:/mnt/alps/eaarl/tarfiles/CONUSQQ/conusqq.pbd and place it in the directory eaarl/lidar-processing/CONUSQQ/."
      tkcmd, "MessageDlg .conusqqerror -type ok -icon error -title {Data not available} -message {" + message + "}"
      write, format="%s\n", message;
   } else {
      restore, openb(fname), conusqq;
      return conusqq;
   }
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

func batch_2k_to_qq(src_dir, dest_dir, mode, searchstr=, dir_struc=, prefix=,
suffix=, remove_buffers=, buffer=, uniq=) {
/* DOCUMENT batch_2k_to_qq, src_dir, dest_dir, mode, searchstr=, dir_struc=,
   prefix=, suffix=, move_buffers=, buffer=

   Crawls through a directory structure of 2km x 2km EAARL tiles to generate
   the corresponding quarter-quad tiles. Input and output are both pbd files.

   Parameters:
   
      src_dir: The source directory. This should be the root directory of the
         directory structure containing the EAARL 2kx2k tiles in pbd format
         that need to be converted into quarter quad tiles.

      dest_dir: The destination directory. The quarter quad pbd's will be
         written here.

      mode: The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface
         2 = bathy
         3 = bare earth

   Options:
      
      searchstr= The glob string to use. Narrows the criteria for inclusion in
         src_dir. Default is "*.pbd".

      dir_struc= If set to 1, the quarter quad data files will be organized
         into a directory structure in the output directory. Each tile will get
         a directory named after it. If not set (which is the default), all
         files will go into the output directory as is, without any
         subdirectory organization.

      prefix= A string to prefix at the beginning of each quarter quad file
         name. By default, there is no prefix (prefix=""). If using a prefix,
         it can optionally include a trailing "_" (if not present, it will be
         added).

      suffix= A string to suffix at the end of each quarter quad file name. By
         default, this is two letters based on the mode: 1="fs", 2="ba",
         3="be". This can optionally include a trailing ".pbd" (if not present,
         it will be added) and can optionally be preceded by a leading "_" (if
         not present, it will be added). To suppress the suffix, use suffix="".

      remove_buffers= If 1, this will clip each 2k pbd's data to the file's 2k
         extent, removing any buffer regions that may be present. If 0, then
         all data from the file will be used regardless of where it's actually
         located. The defaults to 1.

      buffer= Specifies a buffer in meters to add around each quarter quad
         tile. The buffer is a minimum, see extract_for_qq for details. Default
         is buffer=100. Use buffer=0 to suppress the buffer.

      uniq= Specifies whether data points should be contrained to only unique
         points by sod when saved to the pbd file. Default is 1. Set uniq=0 to
         avoid this constraint. (This is necessary with ATM data, which may
         have unreliable sod values.)

   Original David Nagle 2008-07-16
*/
   fix_dir, src_dir;
   fix_dir, dest_dir;
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, buffer, 100;

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   // Default a prefix that is empty
   default, prefix, "";
   if(strlen(prefix) && strpart(prefix, 0:0) != "_")
      prefix = prefix + "_";
   
   // Default a suffix that specifies data type
   default, suffix, "_" + ["fs", "ba", "be"](mode) + ".pbd";
   if(strlen(suffix)) {
      if(strpart(suffix, -3:0) != ".pbd")
         suffix = suffix + ".pbd";
      if(strpart(suffix, 1:1) != "_")
         suffix = "_" + suffix;
   }

   // Source files
   files = find(src_dir, glob=searchstr);
   files = files(sort(file_tail(files)));

   // Iterate over the source files to determine the qq tiles
   qqcodes = [];
   tstamp = 0;
   timer_init, tstamp;
   write, "Scanning source files to generate list of QQ tiles...";
   for(i = 1; i<= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files);
      basefile = file_tail(files(i));
      n = e = z = [];
      dt2utm, basefile, n, e, z;
      
      // Load data
      f = openb(files(i));
      data = get_member(f, get_member(f, "vname"));
      close, f;

      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, basefile, buffer=0);
         data = data(idx);
         if(numberof(data) == 0) continue;
      }

      // Get a list of the quarter quad codes represented by the data
      new_qqcodes = get_utm_qqcodes(get_member(data, north)/100.0,
         get_member(data, east)/100.0, z);
      grow, new_qqcodes, qqcodes;
      qqcodes = set_remove_duplicates(new_qqcodes);
   }
   write, format=" %i QQ tiles will be generated\n", numberof(qqcodes);

   qqcodes = qqcodes(sort(qqcodes));

   // Iterate over each source file to actually partition data
   write, "Scanning source files to generate QQ files:";
   for(i = 1; i<= numberof(files); i++) {
      // Extract UTM coordinates for data tile
      basefile = file_tail(files(i));
      n = e = z = [];
      dt2utm, basefile, n, e, z;

      write, format=" * [%d/%d] Scanning %s\n", i, numberof(files), basefile;
      
      // Load data
      f = openb(files(i));
      data = get_member(f, f.vname);
      close, f;
      
      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, basefile, buffer=0);
         data = data(idx);
         if(numberof(data) == 0) {
            write, "  Problem: No data found after buffers removed.";
            continue;
         }
      }

      // Iterate through each qq
      for(j = 1; j <= numberof(qqcodes); j++) {
         // Try to extract data for the qq
         idx = extract_for_qq(get_member(data, north)/100.0,
            get_member(data, east)/100.0, z, qqcodes(j), buffer=buffer);
         if(!numberof(idx)) // skip if no data
            continue;
         vdata = data(idx);

         // Make sure the data's zone matches the qq's zone
         qqzone = qq2uz(qqcodes(j));
         if(qqzone != z) {
            write, format="   - %s: Rezoning data %d -> %d\n", qqcodes(j), int(z), int(qqzone);
            rezone_data_utm, vdata, z, qqzone;
         }

         write, format="   - Writing for %s\n", qqcodes(j);

         // variable name is qqcode preceeded by "qq"
         vname = swrite(format="qq%s", qqcodes(j));

         // determine and create output directory
         outpath = dest_dir;
         if(dir_struc)
            outpath = outpath + qqcodes(j) + "/";
         mkdirp, outpath;

         // write data
         pbd_append, outpath + prefix + qqcodes(j) + suffix, vname, vdata, uniq=uniq;
      }
   }
}

func batch_qq_to_2k(src_dir, dest_dir, mode, searchstr=, suffix=,
remove_buffers=, buffer=, uniq=) {
/* DOCUMENT batch_qq_to_2k, src_dir, dest_dir, mode, searchstr=, suffix=,
   remove_buffers=, buffer=

   Crawls through a directory structure of quarter quad tiles to generate the
   corresponding 2km x 2km EAARL tiles. Input and output are both pbd files.

   The output directory will contain a directory structure of index tile
   directories that contain data tile directories that contain data tile files.

   Parameters:
   
      src_dir: The source directory. This should be the root directory of the
         directory structure containing the quarter quad tiles in pbd format
         that need to be converted into 2km tiles.

      dest_dir: The destination directory. The index tiles (containing data
         tiles) will be written here.

      mode: The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface
         2 = bathy
         3 = bare earth

   Options:
      
      searchstr= The glob string to use. Narrows the criteria for inclusion in
         src_dir. Default is "*.pbd".

      suffix= A string to suffix at the end of each data tile file name. By
         default, this is two letters based on the mode: 1="fs", 2="ba",
         3="be". This can optionally include a trailing ".pbd" (if not present,
         it will be added) and can optionally be preceded by a leading "_" (if
         not present, it will be added). To suppress the suffix, use suffix="".

      remove_buffers= If 1, this will clip each qq pbd's data to the file's qq
         extent, removing any buffer regions that may be present. If 0, then
         all data from the file will be used regardless of where it's actually
         located. The defaults to 1.

      buffer= Specifies a buffer in meters to add around each data tile.
         Default is buffer=100. Use buffer=0 to suppress the buffer.

      uniq= Specifies whether data points should be contrained to only unique
         points by sod when saved to the pbd file. Default is 1. Set uniq=0 to
         avoid this constraint. (This is necessary with ATM data, which may
         have unreliable sod values.)

   Original David Nagle 2008-07-18
*/
   fix_dir, src_dir;
   fix_dir, dest_dir;
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, buffer, 100;

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   // Default a suffix that specifies data type
   default, suffix, "_" + ["fs", "ba", "be"](mode) + ".pbd";
   if(strlen(suffix)) {
      if(strpart(suffix, -3:0) != ".pbd")
         suffix = suffix + ".pbd";
      if(strpart(suffix, 1:1) != "_")
         suffix = "_" + suffix;
   }

   // Source files
   files = find(src_dir, glob=searchstr);
   files = files(sort(file_tail(files)));

   dtcodes = [];
   dtfiles = [];
   write, format="Batch converting quarter quads into data tiles:%s", "\n";
   for(i = 1; i<= numberof(files); i++) {
      basefile = file_tail(files(i));
      write, format="[%d/%d] %s     \r", i, numberof(files), basefile;
      qq = extract_qq(basefile);
      qqzone = qq2uz(qq);
      
      // load qq tile
      f = openb(files(i));
      data = get_member(f, get_member(f, "vname"));
      close, f;
      
      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         qq_list = get_utm_qqcodes(get_member(data, north)/100.0,
            get_member(data, east)/100.0, qqzone);
         data = data(where(qq == qq_list));
         if(numberof(data) == 0) continue;
      }

      // determine which data tiles are covered by dataset
      //   - note them as good
      new_dtcodes = get_utm_dtcodes(get_member(data, north)/100.0,
         get_member(data, east)/100.0, qqzone);
      dtcodes = set_union(new_dtcodes, dtcodes);
      
      // determine possible dtcodes (for buffer included)
      qq_dtcodes = get_utm_dtcode_candidates(get_member(data, north)/100.0,
         get_member(data, east)/100.0, qqzone, buffer);
      qq_itcodes = get_dt_itcodes(qq_dtcodes);

      // for each possible dtcode:
      for(j = 1; j <= numberof(qq_dtcodes); j++) {
         // extract relevant data
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, qq_dtcodes(j), buffer=buffer);
         if(!numberof(idx)) // skip if no data
            continue;
         vdata = data(idx);
         
         // make sure zones match; if not, rezone
         dtzone = [];
         dt2utm, qq_dtcodes(j), , , dtzone;
         if(dtzone != qqzone) 
            rezone_data_utm, vdata, dtzone, qqzone;

         // variable name is short dtcode
         vname = dt_short(qq_dtcodes(j));

         // determine and create output directory
         outpath = dest_dir + qq_itcodes(j) + "/" + qq_dtcodes(j) + "/";
         mkdirp, outpath;

         // write data
         pbd_append, outpath + qq_dtcodes(j) + suffix, vname, vdata, uniq=uniq;

         // note as created
         dtfiles = set_union(dtfiles, [outpath + qq_dtcodes(j) + suffix]);
      }
   }

   // iterate through created files and remove the ones not in the good list
   write, format="\nDeleting extraneous files...                            %s", "\n";
   dtfilecodes = dt_long(file_tail(dtfiles));
   removeidx = set_difference(dtfilecodes, dtcodes, idx=1);
   for(i = 1; i <= numberof(removeidx); i++) {
      remove, dtfiles(removeidx(i));
   }
}

func draw_qq(qq, win, pts=) {
/* DOCUMENT draw_qq, qq, win, pts=
   Draws a grey box for the given quarter quad(s) in the given window.

   If given pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   Original David Nagle 2008-07-18
*/
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

   If given pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   Original David Nagle 2008-07-18
*/
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

   Original David Nagle 2008-07-18
*/
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

func show_qq_grid_location(w, m) {
   extern curzone;
   default, w, 5;
   window, w;
   if(is_void(m))
      m = mouse();
   if(!curzone) {
      zone = "void";
      write, "Please enter the current UTM zone:\n";
      read(zone);
      curzone = 0;
      sread(zone, format="%d", curzone);
   }
   qq = get_utm_qqcodes(m(2), m(1), curzone);
   write, format="Quarter Quad: %s\n", qq(1);
}

func draw_qq_grid(win, pts=) {
/* DOCUMENT draw_qq_grid, win, pts=
   Draws a quarter quad grid for the given window. This will draw all quads and
   quarter quads that fall within the visible region in the given window.

   Quads are in red, quarter quads in grey.

   If given pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   If the current plot crosses UTM zone boundaries, please set fixedzone.

   KNOWN ISSUES:
   - If using over a large area, you should click on the plot to manually set
     the limits before using this. Otherwise, it'll automatically adjust the
     window limits after each quarter quad is drawn, which dramatically
     increases the time it takes to plot the grid.

   Original David Nagle 2008-07-18
*/
   if(is_void(win)) return;
   extern curzone;
   if(is_void(curzone)) {
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

func qqtiff_gms_prep(tif_dir, pbd_dir, mode, outfile, tif_glob=, pbd_glob=) {
/* DOCUMENT qqtiff_gms_prep, tif_dir, pbd_dir, mode, outfile, tif_glob=, pdb_glob=
   
   Creates a data tcl file that can be used by gm_tiff2ktoqq.tcl to generate a
   Global Mapper script that can be used to convert 2k data tile geotiffs into
   quarter quad geotiffs.

   Parameters:
   
      tif_dir: The directory containing the 2k tiled geotiffs.

      pbd_dir: The directory containing quarter quad pbds that contain the same
         source data points used to make the 2k data tiles repartitioned.

      mode: The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface
         2 = bathy
         3 = bare earth

      outfile: The full path and filename to the output file to generate. This
         will be taken to Windows for use with gm_tiff2ktoqq.tcl.
   
   Options:
   
      tif_glob= A file glob that can be used to more specifically select the
         tiff files from their directory. Default is *.tif.

      pbd_glob= A file glob that can be used to more specifically select the
         pbd files from their directory. Default is *.pbd.
*/
   fix_dir, tif_dir;
   fix_dir, pbd_dir;

   default, tif_glob, "*.tif";
   default, pbd_glob, "*.pbd";

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   // Source files
   files = find(tif_dir, glob=tif_glob);

   // Scan pbds for exents
   extents = calculate_qq_extents(pbd_dir, glob=pbd_glob);

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

func calculate_qq_extents(qqdir, glob=, remove_buffers=) {
/* DOCUMENT calculate_qq_extents(qqdir, glob=, remove_buffers=)
   Calculates the lat/lon extents for a each quarter quad using the given
   directory of qq pbd files. Returns a Yeti hash with the results.
*/
   fix_dir, qqdir;
   default, glob, "*.pbd";
   default, remove_buffers, 1;

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

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
      f = openb(files(i));
      data = get_member(f, get_member(f, "vname"));
      close, f;

      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         qq_list = get_utm_qqcodes(get_member(data, north)/100.0,
            get_member(data, east)/100.0, z);
         data = data(where(qq == qq_list));
         if(numberof(data) == 0) {
            write, "  Problem: No data found after buffers removed.";
            continue;
         }
      }

      // Convert data to lat/lon
      ll = utm2ll(get_member(data, north)/100.0,
         get_member(data, east)/100.0, z);

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

func partition_into_2k(north, east, zone, buffer=, shorten=) {
/* DOCUMENT partition_into_2k(north, east, zone, buffer=, shorten=)
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

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;

   dtcodes = get_utm_dtcodes(north, east, zone);
   dtcodes = set_remove_duplicates(dtcodes);
   if(shorten)
      dtcodes = dt_short(dtcodes);

   tiles = h_new();
   for(i = 1; i <= numberof(dtcodes); i++) {
      this_zone = dt2uz(dtcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_dt(data(1,), data(2,), dtcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, dtcodes(i), idx;
   }
   return tiles;
}

func partition_into_10k(north, east, zone, buffer=, shorten=) {
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

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;

   dtcodes = get_utm_dtcodes(north, east, zone);
   itcodes = get_dt_itcodes(dtcodes);
   itcodes = set_remove_duplicates(itcodes);
   if(shorten)
      itcodes = dt_short(itcodes);

   tiles = h_new();
   for(i = 1; i <= numberof(itcodes); i++) {
      this_zone = dt2uz(itcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_it(data(1,), data(2,), itcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, itcodes(i), idx;
   }
   return tiles;
}

func partition_into_qq(north, east, zone, buffer=) {
/* DOCUMENT partition_into_qq(north, east, zone, buffer=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into quarter quad tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   qqcodes = get_utm_qqcodes(north, east, zone);
   qqcodes = set_remove_duplicates(qqcodes);

   tiles = h_new();
   for(i = 1; i <= numberof(qqcodes); i++) {
      w = extract_for_qq(north, east, zone, qqcodes(i), buffer=buffer);
      if(numberof(w))
         h_set, tiles, qqcodes(i), w;
   }
   return tiles;
}

func partition_by_tile_type(type, north, east, zone, buffer=, shorten=) {
/* DOCUMENT partition_by_tile_type(type, north, east, zone, buffer=, shorten=)
   This is a wrapper around other partition types that allows the user to call
   the right one based on a type parameter.

   There are three legal values for type. They are listed below along with the
   functions each maps to.
      qq --> partition_into_qq
      2k --> partition_into_2k
      10k --> partition_into_10k

   Arguments and options are passed to the functions as is, as appropriate.
*/
// Original David B. Nagle 2009-04-01
   if(type == "qq") {
      return partition_into_qq(north, east, zone, buffer=buffer);
   } else if(type == "2k") {
      return partition_into_2k(north, east, zone, buffer=buffer,
         shorten=shorten);
   } else if(type == "10k") {
      return partition_into_10k(north, east, zone, buffer=buffer,
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

func save_data_to_tiles(data, zone, dest_dir, scheme=, north=, east=, mode=,
suffix=, buffer=, shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=) {
/* DOCUMENT save_data_to_tiles, data, zone, dest_dir, scheme=, north=, east=,
   mode=, suffix=, buffer=, shorten=, flat=, uniq=, overwrite=, verbose=,
   split_zones=

   Given an array of data (which must be in an ALPS data structure such as
   VEG__) and a scalar or array of zone corresponding to it, this will create
   PBD files in dest_dir partitioned using the given scheme.

   Parameters:
      data: Array of data in ALPS data struct
      zone: Scalar or array of UTM zone of data
      dest_dir: Destination directory for output pbd files

   Options:
      scheme= Should be one of the following; defaults to 10k2k.
         qq - Quarter quad tiles
         2k - 2-km data tiles
         10k - 10-km index tiles
         10k2k - Two-tiered index tile/data tile
      north= The struct field in data containing the northings to use. Defaults
         to "north".
      east= The struct field in data containing the eastings to use. Defaults
         to "east".
      mode= If provided, will override north and east based on the data mode
         specified. Must be one of the following:
         1 = first surface
         2 = bathy
         3 = bare earth
      suffix= Specifies the suffix to use when naming the files. By default,
         files are named (tile-name).pbd. If suffix is provided, they will be
         named (tile-name)_(suffix).pbd.
      buffer= Specifies a buffer to include around each tile, in meters.
         Defaults to 100.
      shorten= By default, the long form of 2k, 10k, and 10k2k tile names will
         be used. If shorten=1, the short forms will be used.
      flat= If set to 1, then no directory structure will be created. Instead,
         all files will be created directly into dest_dir.
      uniq= With the default value of uniq=1, only unique data points will be
         stored in the output pbd files; duplicates will be removed. Set uniq=0
         to keep duplicate data points.
      overwrite= By default, data will be appended to any existing pbd files.
         Set overwrite=1 to clobber them instead.
      verbose= By default, progress information will be provided. Set verbose=0
         to silence it.
      split_zones= This can be set to one of the following three values:
         0 = Never split data out by zone. This is the default for most schemes.
         1 = Split data out by zone if there are multiple zones present. This
            is the default for the qq scheme.
         2 = Always split data out by zone, even if only one zone is present.
         (Note: If flat=1, split_zones is ignored.)
*/
// Original David Nagle 2009-07-06

   default, scheme, "10k2k";
   default, mode, [];
   default, north, "north";
   default, east, "east";
   default, suffix, string(0);
   default, buffer, 100;
   default, shorten, 0;
   default, flat, 0;
   default, uniq, 1;
   default, overwrite, 0;
   default, verbose, 1;
   default, split_zones, scheme == "qq";

   bilevel = scheme == "10k2k";
   if(bilevel) scheme = "2k";

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else if(!is_void(mode)) {
      error, "Invalid mode.";
   }

   if(numberof(zone) == 1)
      zone = array(zone, dimsof(data));

   if(verbose)
      write, "Partitioning data...";
   tiles = partition_by_tile_type(scheme, get_member(data, north)/100.,
      get_member(data, east)/100., zone, buffer=buffer, shorten=shorten);

   tile_names = h_keys(tiles);
   tile_names = tile_names(sort(tile_names));

   if(verbose)
      write, format=" Creating files for %d tiles...\n", numberof(tile_names);
   
   tile_zones = (scheme == "qq") ? qq2uz(tile_names) : dt2uz(tile_names);
   tile_zones = long(tile_zones);
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

      outfile = curtile;
      if(suffix) outfile += "_" + suffix;
      outfile += ".pbd";

      outdest = file_join(outpath, outfile);

      if(overwrite && file_exists(outdest))
         remove, outdest;
      
      pbd_append, outdest, vname, vdata, uniq=uniq;
      if(verbose)
         write, format=" %d: %s\n", i, outfile;
   }
}
