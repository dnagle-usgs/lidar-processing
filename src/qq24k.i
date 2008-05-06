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

   Functions for the CLICK 24k Quarter-Quad tiling scheme.

      calc24qq
      get_conusqq_data
      get_utm_qqcodes
      qq_segment_pbds
      qq_segment_pbd
      qq_merge_pbds
      batch_2k_to_qq

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

func qq2ll(qq, bbox=) {
/* DOCUMENT ll = qq2ll(qq, bbox=)

   Returns the latitude and longitude of the SE corner of the 24k Quarter-Quad
   represented by the give code (or array of codes).

   Return value is [lat, lon].

   If bbox=1, then return value is [south, east, north, west].

   See calc24qq for documentation on the 24k Quarter-Quad format.
*/
   default, bbox, 0;
   len = strlen(qq);
   if(numberof(where(len != 8))) {
      write, "All input must be exactly 8 characters long. Aborting."
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
   that correspond them.

   See also: calc24qq qq_segment_pbd
*/
   // First, convert the coordinates to lat/lon
   ll = utm2ll(north, east, zone);
   lat = ll(,2);
   lon = ll(,1);
   ll = []; // free memory

   // Then, find the quarter-quad corner for the points
   lat = int(lat / .0625) * 0.0625;
   lon = int(lon / .0625) * 0.0625;

   // calc24qq does the rest
   return calc24qq(lat, lon);
}

func qq_segment_pbds(sdir, odir, glob=, mode=) {
/* DOCUMENT qq_segment_pbds, sdir, odir, glob=, mode=

   Rescurses through sdir, finding all files that match glob, and segments each
   one into odir.

   Parameters:

      sdir: The source directory containing pbd's. They must be in the standard
         2k by 2k format (t_e###_n###_ZZ_etc.)

      odir: The output directory, where the segmented files should go.

   Options:

      glob= Specifies which files to segment by a glob pattern. Defaults to
         "*.pbd" (all pbds). May be an array of globs (any file matching any
         glob will be used).

      mode= The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface (default)
         2 = bathy
         3 = bare earth

   See also: qq_segment_pbd batch_2k_to_qq qq_merge_pbds
*/
   default, mode, 1;
   if(mode < 1 || mode > 3)
      error, "Invalid mode.";
   fix_dir, sdir;
   fix_dir, odir;
   default, glob, "*.pbd";

   files = find(sdir, glob=glob);
   timer_init, tstamp;
   for(i = 1; i<= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files),
         swrite(format=" * Segmenting %s [%i/%i]      ",
         split_path(files(i),0)(0), i, numberof(files));
      qq_segment_pbd, files(i), odir, mode=mode;
   }
}

func qq_segment_pbd(fname, odir, zone=, mode=, remove_buffers=) {
/* DOCUMENT qq_segment_pbd, fname, odir, zone=, mode=, remove_buffers=

   The pbd given by fname will be segmented into separate files for each
   quarter-quad present in the data.

   The created files will have the same filename as fname, but with their
   quarter-quad code prepended. So fname="file.pbd" might result in
   "48117h4c_file.pbd".

   Parameters:

      fname: The *.pbd file to process, containing EAARL data.

      odir: The output directory to which the segmented files will be written.

   Options:
   
      zone: The UTM zone of the data. If not provided, it will parse it from
         the filename (must be formatted as t_n###_e###_ZZ_etc where ZZ is the
         zone.)

      mode= The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface (default)
         2 = bathy
         3 = bare earth

      remove_buffers= If set to 1, the data from each source file will be
         constrained to its tile size. Otherwise (if 0), it will include all
         data present.  The default is 1.

   See also: qq_segment_pbds qq_merge_pbds
*/
   default, mode, 1;
   default, remove_buffers, 1;
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   fix_dir, odir;
   fn = split_path(fname, 0)(0);
   default, zone, atoi(strpart(fn,strword(fn, "_", 5))(4));
   fn = [];

   f = openb(fname);
   restore, f, vname;
   if(get_member(f,vname) == 0) exit; //?
   data = get_member(f,vname);
   close, f;

   basefile = split_path(fname, 0)(0);

   regmatch, "^t_e([0-9]*)_n([0-9]*)_([0-9]*)", basefile, , e, n, z;
   n = atoi(n);
   e = atoi(e);
   z = atoi(z);

   if(remove_buffers) {
      mask  = get_member(data, north) >= (n - 2000.0) * 100.0;
      mask &= get_member(data, north) <=  n           * 100.0;
      mask &= get_member(data, east ) >=  e           * 100.0;
      mask &= get_member(data, east ) <= (e + 2000.0) * 100.0;
      data = data(where(mask));
      if(numberof(data) == 0) {
         write, format="\n Problem: No data found after buffers removed. File:\n %s\n", fname;
         return;
      }
   }
   
   orig = vname;

   qq = get_utm_qqcodes(get_member(data, north)/100.0,
      get_member(data, east)/100.0, zone);
   qcodes = set_remove_duplicates(qq);
   
   i = 1;
   for(i = i; i <= numberof(qcodes); i++) {
      vname = swrite(format="qq%s-%s", qcodes(i), orig);
      vdata = data(where(qq == qcodes(i)));
      f = createb(odir + qcodes(i) + "_" + basefile);
      add_variable, f, -1, vname, structof(vdata), dimsof(vdata);
      get_member(f, vname) = vdata;
      save, f, vname;
      close, f;
   }
}

func qq_merge_pbds(idir, odir, mode, dir_struc=) {
/* DOCUMENT qq_merge_pbds, idir, odir

   This merges the quarter-quad data files in idir and writes the results
   to odir. This is intended to be used over the results of qq_segment_pbd
   after having run over multiple files.

   Output files will be the quarter-quad code + ".pdb".

   Parameters:

      idir: The input directory.

      odir: The output directory.

      dir_struc: Creates a directory structure, in the output directory,
                 of the Quarter-Quad tiles being put into their respective
                 Quarter-Quad folders similar to the Index Tiles.

   See also: batch_2k_to_qq qq_segment_pbds
*/
   fix_dir, idir;
   fix_dir, odir;
   infiles = lsfiles(idir, glob="*.pbd");
   qfiles = strpart(infiles, 1:8);
   qcodes = set_remove_duplicates(qfiles);

   timer_init, tstamp;
   for(i = 1; i <= numberof(qcodes); i++) {
      timer_tick, tstamp, i, numberof(qcodes),
         swrite(format=" * Merging for %s [%i/%i]", qcodes(i), i, numberof(qcodes));
      vfiles = infiles(where(qfiles == qcodes(i)));
      vdata = [];
      for(j = 1; j <= numberof(vfiles); j++) {
         f = openb(idir + vfiles(j));
         grow, vdata, get_member(f, get_member(f, "vname"));
         close, f;
      }
      vdata = vdata(sort(vdata.soe));
      vname = "qq" + qcodes(i);
      
      if(!is_void(dir_struc)) {
         filepath=odir + qcodes(i) +"/";
         mkdirp(filepath);
      } else {
         filepath=odir;
      }

      
      if(mode==3) {
         endoffile="_be.pbd";
      } if(mode==2) {
         endoffile="_ba.pbd";
      } if(mode==1) {
         endoffile="_fs.pbd";
      }




      f = createb(filepath  + qcodes(i) + endoffile);
      add_variable, f, -1, vname, structof(vdata), dimsof(vdata);
      get_member(f, vname) = vdata;
      save, f, vname;
      close, f;
   }
}

func batch_2k_to_qq(src_dir, dest_dir, mode, seg_dir=, searchstr=, dir_struc=) {
/* DOCUMENT batch_2k_to_qq, src_dir, dest_dir, mode, seg_dir=, glob=
   
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
      
      seg_dir= The segmented directory. If set, this directory will contain the
         interim files. Each pbd in the src_dir is segmented into a series of
         pbds corresponding to the quarter quads, which are later collated into
         single quarter quad files. Normally, a temp directory is used and is
         deleted at the end of the process.

      searchstr= The glob string to use. Narrows the criteria for inclusion in
         src_dir. Default is "*.pbd".

      dir_struc= creates a Quarter-Quad directory structure; similar to Index
                 Tiles.

   See also: get_conusqq_data qq_segment_pbds qq_merge_pbds
*/
   if(mode < 1 || mode > 3)
      error, "Invalid mode.";
   seg_tmp = 0;
   if(is_void(seg_dir)) {
      seg_dir = mktempdir("batch2ktoqq");
      seg_tmp = 1;
   }
   fix_dir, src_dir;
   fix_dir, dest_dir;
   fix_dir, seg_dir;
   default, searchstr, "*.pbd";
   
   write, "Segmenting PBDs.";
   qq_segment_pbds, src_dir, seg_dir, glob=searchstr, mode=mode;
   write, "Merging PBDs.";
   qq_merge_pbds, seg_dir, dest_dir,mode, dir_struc=dir_struc;
   
   if(seg_tmp) {
      files = lsfiles(seg_dir);
      for(i = 1; i <= numberof(files); i++) {
         remove, seg_dir+files(i);
      }
      rmdir, seg_dir;
   }
}


