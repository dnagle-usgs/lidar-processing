/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
write, "$Id$";
require, "yeti.i";
require, "yeti_regex.i";
require, "dir.i";
require, "ll2utm.i";
require, "set.i";
require, "general.i";

/*
This file requires Eric Thiébaut's Yeti package, available from:
http://www-obs.univ-lyon1.fr/~thiebaut/yeti.html
*/

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
   u = fll2utm( bbox([1,3])(avg), bbox([2,4])(avg) );
   if(centroid)
      return u(,1);
   else
      return u(3,1);
}

func extract_for_qq(north, east, zone, qq, buffer=) {
/* DOCUMENT extract_for_qq(north, east, qq, buffer=)

   This will return an index into north/east of all coordinates that fall
   within the bounds of the given quarter quad, which should be the string name
   of the quarter quad.

   The buffer= option specifies a buffer (in meters) to extend the quarter
   quad's boundaries by. By default, it is 100 meters.

   Note that this will ALWAYS add a small buffer, even if buffer=0. This is
   because the quarter quad scheme is based on lat/lon whereas these
   coordinates are in UTM. The index is determined based on a UTM bounding box
   around that quarter quad. If you need to extract only the points that lie
   within the quarter quad, then this function will not work for you safely.

   Original David Nagle 2008-07-17
*/
   default, buffer, 100;
   bbox = qq2ll(qq, bbox=1);
   // When the QQ is projected into UTM, its edges might be slightly curved.
   // Normally, a simple bounding box should probably suffice. However, just in
   // case a side bows out such that the middle is further out than the
   // corners, we sample five points along each edge to help ensure full
   // coverage. The most extreme points in each direction are then used.
   lats = span(bbox(1), bbox(3), 5);
   lons = span(bbox(2), bbox(4), 5);
   min_n = fll2utm(array(lats(1), 5), lons)(1, min) - buffer;
   max_n = fll2utm(array(lats(5), 5), lons)(1, max) + buffer;
   min_e = fll2utm(lats, array(lons(5), 5))(2, max) - buffer;
   max_e = fll2utm(lats, array(lons(1), 5))(2, min) + buffer;
   qqz = qq2uz(qq);
   
   if(qqz != zone) {
      // It's expensive to convert the entire data array. So instead, we just
      // convert the bounding box and check to see if the data stands a chance
      // at being in the right spot. I put a 2000 meter buffer around it, which
      // is probably bigger than is needed but will ensure that all good data
      // is kept while avoiding the need to check most data tiles
      ubb = rezone_utm([north(min), north(min), north(max), north(max)],
         [east(min), east(max), east(max), east(min)], zone, qqz);
      chk_n = [ubb(1,min), ubb(1,max)];
      chk_e = [ubb(2,min), ubb(2,max)];
      if(max_e + 2000 > chk_e(min) && min_e - 2000 < chk_e(max) &&
         max_n + 2000 > chk_n(min) && min_n - 2000 < chk_n(max) ) {
         rezone_utm, north, east, zone, qqz;
      } else {
         return [];
      }
   }

   return where(
      min_n <= north & north <= max_n &
      min_e <= east  & east  <= max_e
   );
}

func extract_for_dt(north, east, dt, buffer=) {
/* DOCUMENT extract_for_dt(north, east, dt, buffer=)
   
   This will return an index into north/east of all coordinates that fall
   within the bounds of the given 2k data tile dt, which should be the string
   name of the data tile.

   The buffer= option specifies a buffer in meters to extend the quarter quad's
   boundaries by. By default, it is 100 meters. Setting buffer=0 will constrain
   the data to the exact tile boundaries.

   Original David Nagle 2008-07-21
*/
   default, buffer, 100;
   bbox = dt2utm(dt, bbox=1);
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

   a = strfind(a, "abcdefgh", case=0)(2) - 1;
   a = a * 0.125;
   lat += a;

   o = o - 1;
   o = o * 0.125;
   lon += o;

   q = strfind(q, "abcd", case=0)(2);
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
   the quarter quad name(s).

   Original David Nagle 2008-07-17
*/
   regmatch, "(^|_)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   return qq;
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

func get_utm_dtcodes(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcodes(north, east, zone)
   
   For a set of UTM northings, eastings, and zones, this will calculate each
   coordinate's data tile name and return an array of strings that correspond
   to them.

   Original David Nagle 2008-07-21
*/
   return swrite(format="t_e%.0f000_n%.0f000_%d",
      floor(east /2000.0)*2,
      ceil (north/2000.0)*2,
      int(zone));
}

func get_dt_itcodes(dtcodes) {
/* DOCUMENT it = get_dt_itcodes(dtcodes)
   For an array of data tile codes, this will return the corresponding index
   tile codes.

   Original David Nagle 2008-07-21
*/
   east  = floor(atoi(strpart(dtcodes, 4:6))  /10.0)*10;
   north = ceil (atoi(strpart(dtcodes, 12:15))/10.0)*10;
   zone  = strpart(dtcodes, 20:21);
   return swrite(format="i_e%.0f000_n%.0f000_%s", east, north, zone);
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

func dt_short(dtcodes) {
/* DOCUMENT shortnames = dt_short(dtcodes)
   Returns abbreviated names for an array of data tile codes.

   Example:

      > dt_short("t_e466000_n3354000_16")
      "e466_n3354_16"

   Original David Nagle 2008-07-21
*/
   w = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z;
   return swrite(format="e%s_n%s_%s", w, n, z);
}

func dt_long(dtcodes) {
/* DOCUMENT longnames = dt_long(dtcodes)
   Returns full names for an array of data tile codes.

   Example:

      > dt_long("e466_n3354_16")
      "t_e466000_n3354000_16"
   
   Original David Nagle 2008-08-07
*/
   w = n = z = []; // prevents the next line from making them externs
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z;
   return swrite(format="t_e%s000_n%s000_%s", w, n, z);
}

func dt2utm(dtcodes, &north, &east, &zone, bbox=) {
/* DOCUMENT dt2utm(dtcodes, bbox=)
   dt2utm, dtcodes, &north, &east, &zone

   Returns the northwest coordinates for the given dtcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   If called as a subroutine, it sets the northwest coordinates of the given
   output variables.

   Original David Nagle 2008-07-21
*/
   w = n = z = []; // prevents the next line from making them externs
   if(regmatch("(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)(_|\\.|$)", dtcodes, , , w, , n, , z)) {
      n = atoi(n + "000");
      w = atoi(w + "000");
      z = atoi(z);
   } else {
      w = n = z = [];
   }

   if(am_subroutine()) {
      north = n;
      east = w;
      zone = z;
   }

   if(is_void(z))
      return [];
   else if(bbox)
      return [n - 2000, w + 2000, n, w, z];
   else
      return [n, w, z];
}

func it2utm(itcodes, bbox=) {
/* DOCUMENT it2utm(itcodes, bbox=)
   Returns the northwest coordinates for the given itcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   Original David Nagle 2008-07-21
*/
   u = dt2utm(itcodes);
   if(bbox)
      return [u(,1) - 10000, u(,2) + 10000, u(,1), u(,2), u(,3)];
   else
      return u;
}

func batch_2k_to_qq(src_dir, dest_dir, mode, searchstr=, dir_struc=, prefix=,
suffix=, remove_buffers=, buffer=) {
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
         pbd_append, outpath + prefix + qqcodes(j) + suffix, vname, vdata;
      }
   }
}

func batch_qq_to_2k(src_dir, dest_dir, mode, searchstr=, suffix=,
remove_buffers=, buffer=) {
/* DOCUMENT batch_2k_to_qq, src_dir, dest_dir, mode, searchstr=, suffix=,
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
         pbd_append, outpath + qq_dtcodes(j) + suffix, vname, vdata;

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

func pbd_append(file, vname, data, uniq=) {
/* DOCUMENT pbd_append, file, vname, data, uniq=
   
   This creates or appends "data" in the pbd "file" using the variable name
   "vname". If appending, it will merge "data" with whatever data is pointed to
   by the existing pbd's vname variable. However, when writing, the vname will
   be set to "vname".

   By default, the option uniq= is set to 1 which will ensure that all merged
   data points are unique by eliminating duplicate data points with the same
   soe. If duplicate data should not be eliminated based on soe, then set
   uniq=0.

   Note that if "file" already exists, then the struct of its data must match
   the struct of "data".

   Original David Nagle 2008-07-16
*/
   default, uniq, 1;
   if(file_exists(file)) {
      f = openb(file);
      grow, data, get_member(f, f.vname);
      close, f;
      if(uniq)
         data = data(set_remove_duplicates(data.soe, idx=1));
   }
   f = createb(file);
   add_variable, f, -1, vname, structof(data), dimsof(data);
   get_member(f, vname) = data;
   save, f, vname;
   close, f;
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
/* DOCUMENT qqtiff_gms_prep(tif_dir, pbd_dir, mode, outfile, tif_glob=, pdf_glob=
   
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
