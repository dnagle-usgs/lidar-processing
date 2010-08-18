/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
require, "l1pro.i";

local ATM2;
/* DOCUMENT
   Point structure for ATM data structure, designed to mimic the VEG__
   structure. This allows most of the EAARL functions to work with ATM data.

   struct ATM2 {
      long north;       UTM northing in cm
      long east;        UTM easting in cm
      short zone;       UTM zone
      long elevation;   elevation in cm
      short fint;       reflected laser signal strength (intensity)
      long least;       passive channel easting in cm
      long lnorth;      passive channel northing in cm
      short lzone;      passive channel zone
      short lint;       passive intensity
      double soe;       soe timestamp
      short sint;       start pulse signal strength (relative)
      long scaz;        scanning azimuth in milliarcdegrees
      long pitch;       pitch in milliarcdegrees
      long roll;        roll in milliarcdegrees
   }
*/
struct ATM2 {
   long north, east;
   short zone;
   long elevation;
   short fint;
   long least, lnorth;
   short lzone, lint;
   double soe;
   short sint;
   long scaz, pitch, roll;
}

local ATM_RAW, ATM_RAW_10, ATM_RAW_14;
/* DOCUMENT
   Structures for reading raw ATM QI binary files. ATM_RAW is the generalized
   structure that has all possible fields that might be found in QI files.
   ATM_RAW_10 and ATM_RAW_14 are specific formats which contain subsets of the
   fields; each can be safely cast to ATM_RAW.

   struct ATM_RAW {
      int rel_time;     Relative time - msec from start of data file
      int lat;          laser spot latitude (degrees x 1,000,000)
      int lon;          laser spot longitude (degrees x 1,000,000)
      int elev;         Elevation (millimeters)
      int pulse_start;  Start Pulse Signal Strength (relative)
      int pulse_refl;   Reflected Laser Signal Strength (relative)
      int azimuth;      Scan azimuth (degrees x 1,000)
      int pitch;        Pitch (degrees x 1,000)
      int roll;         Roll (degrees x 1,000)
      int psig;         Passive signal (relative)
      int plat;         Passive Footprint latitude (degrees x 1,000,000)
      int plon;         Passive footprint longitude (degrees x 1,000,000)
      int pelev;        Passive footprint synthesized elevation (millimeters)
      int gps_time;     GPS time packed (example: 153320100 = 15h 33m 20s 100ms)
   }

   struct ATM_RAW_10 is the same as ATM_RAW except that it lacks these fields:
   psig, plat, plon, pelev.

   struct ATM_RAW_14 is identicial to ATM_RAW.
*/
struct ATM_RAW {
   int rel_time, lat, lon, elev, pulse_start, pulse_refl, azimuth, pitch, roll;
   int psig, plat, plon, pelev, gps_time;
}
struct ATM_RAW_10 {
   int rel_time, lat, lon, elev, pulse_start, pulse_refl, azimuth, pitch, roll;
   int gps_time;
}
struct ATM_RAW_14 {
   int rel_time, lat, lon, elev, pulse_start, pulse_refl, azimuth, pitch, roll;
   int psig, plat, plon, pelev, gps_time;
}

func qi_open(fname, verbose=) {
/* DOCUMENT f = qi_open(fname, verbose=)
   Returns a filehandle for an ATM QI file with these variables installed:
      f.rec_len -- Record length
      f.data_offset -- Offset to data
      f.data -- Array of ATM data, either ATM_RAW_10 or ATM_RAW_14
   If problems are encountered, some or all of those members may be omitted and
   warnings will be displayed to screen. Use verbose=0 to prevent warnings from
   displaying.
*/
   default, verbose, 1;
   word_len = 4;

   f = open(fname, "rb");
   sun_primitives, f;
   file_len = sizeof(f);

   if(file_len < 4) {
      if(verbose)
         write, format=" File too short at %d bytes\n", file_len;
      return f;
   }
   add_variable, f, 0, "rec_len", long;

   if(file_len < word_len + f.rec_len + 4) {
      if(verbose)
         write, format=" File too short at %d bytes\n", file_len;
      return f;
   }
   add_variable, f, word_len + f.rec_len, "data_offset", long;

   if(!f.rec_len) {
      if(verbose)
         write, "Record length of 0";
      return f;
   }

   data_len = file_len - f.data_offset;
   if(data_len % f.rec_len) {
      if(verbose)
         write, "Data region does not conform to record length";
      return f;
   }

   rec_num = data_len / f.rec_len;

   if(f.rec_len == 14 * word_len)
      add_variable, f, f.data_offset, "data", ATM_RAW_14, rec_num;
   else if(f.rec_len == 10 * word_len)
      add_variable, f, f.data_offset, "data", ATM_RAW_10, rec_num;
   else if(verbose)
      write, format=" Unknown record length %d\n", f.rec_len;

   return f;
}

func qi_load(fname, verbose=) {
/* DOCUMENT qi_load(fname, verbose=)
   Loads the ATM data from file fname and returns it as an array of ATM_RAW.
   If errors are encounted, warnings will be displayed and [] will be returned.
   Use verbose=0 to disable warning messages.
   SEE ALSO: qi_import qi_open
*/
   default, verbose, 1;
   f = qi_open(fname, verbose=verbose);
   if(!has_member(f, "data")) {
      if(verbose)
         write, format=" Unable to extract data from %s\n", file_tail(fname);
      return [];
   }
   return struct_cast(f.data, ATM_RAW);
}

func qi_import(atm_raw, ymd, verbose=) {
/* DOCUMENT qi_import(atm_raw, ymd, verbose=)
   Converts ATM_RAW to ATM.

   Parameters:
      atm_raw: An array of ATM_RAW data.
      ymd: The year-month-day of the data
   Option:
      verbose= Specifies whether progress information should be shown.
            verbose=0   Silence output
            verbose=1   Show output (default)

   SEE ALSO: qi_load qi2pbd batch_qi2pbd
*/
   default, verbose, 1;
   if(!is_integer(ymd) || ymd < 19800000 || ymd > 21000000)
      error, "YMD argument must be an integer in YYYYMMDD format.";

   bad = atm_raw.lat == 0 | atm_raw.lon == 0;
   if(allof(bad)) {
      if(verbose)
         write, "All points have bad lat/lon";
      return [];
   }
   if(anyof(bad) && verbose) {
      w = where(bad);
      write, format=" Discarding %d of %d points (%.2f%%) with bad lat/lon\n",
         numberof(w), numberof(atm_raw), 100.*numberof(w)/numberof(atm_raw);
   }
   w = where(!bad);
   atm_raw = atm_raw(w);

   atm = array(ATM2, numberof(atm_raw));

   if(verbose)
      write, "Converting ATM lat/lon to UTM";
   u = fll2utm(atm_raw.lat/1000000.0, atm_raw.lon/1000000.0);
   atm.north = (u(1,) * 100);
   atm.east = (u(2,) * 100);
   atm.zone = long(u(3,));
   if(verbose) {
      write, "UTM Zone of data:"
      write, "Min:", min(atm.zone);
      write, "Max:", max(atm.zone);
   }
   
   atm.elevation = atm_raw.elev/10.0;
   atm.fint = atm_raw.pulse_refl;

   if(verbose)
      write, "Converting ATM passive lat/lon to UTM";
   idx = where(atm_raw.plat != 0 & atm_raw.plon != 0);
   if(numberof(idx)) {
      u = fll2utm(atm_raw(idx).plat/1000000.0, atm_raw(idx).plon/-1000000.0);
      atm(idx).lnorth = u(1,) * 100;
      atm(idx).least  = u(2,) * 100;
   }
   atm.lint = atm_raw.psig;

   if(verbose)
      write, "Converting ATM GPS Time to SOE";
   atm.soe = time2soe([int(ymd/10000), ymd2doy(ymd),
      (hms2sod(atm_raw.gps_time/1000.)), 0, 0, 0]);
   atm.sint = atm_raw.pulse_start;
   atm.scaz = atm_raw.azimuth;
   atm.pitch = atm_raw.pitch;
   atm.roll = atm_raw.roll;

   return atm;
}

func batch_qi2pbd(srcdir, ymd, outdir=, files=, searchstr=, maxcount=, verbose=) {
/* DOCUMENT batch_qi2pbd, srcdir, ymd, outdir=, files=, searchstr=, maxcount=,
      verbose=
   Batch converts ATM *.qi files into ALPS *.pbd files.

   Parameters:
      srcdir: The path to the files to convert.
      ymd: An integer in YYYYMMDD format specifying the date of the data.
   Options:
      outdir= Specifies the directory to create the output files in. By
         default, they are created alongside the source files.
      files= If provided, this is a list of files to convert. Specifying this
         disables searchstr=.
      searchstr= The search string used to find files to convert.
            searchstr=["*.qi", "*.QI"]    default, all QI files
      maxcount= Specifies the maximum number of data points to store in a
         single output file. If there are more points than this, then multiple
         files will be created for a given input file. Each file will have the
         suffix _NUM.pbd, where NUM is its number in the sequence as created.
      verbose= Specifies whether progress information should be shown.
            verbose=0   Silence output
            verbose=1   Show output (default)
            verbose=2   Show lots of output
*/
   default, searchstr, ["*.qi", "*.QI"];
   default, verbose, 1;

   if(is_void(files))
      files = find(srcdir, glob=searchstr);
   outfiles = file_rootname(files) + ".pbd";
   if(!is_void(outdir))
      outfiles = file_join(outdir, file_tail(outfiles));

   count = numberof(files);
   if(count > 1)
      sizes = file_size(files)(cum)(2:);
   else if(count)
      sizes = file_size(files);
   else
      error, "No files found.";

   t0 = array(double, 3);
   timer, t0;
   for(i = 1; i <= count; i++) {
      qi2pbd, files(i), ymd, outfile=outfiles(i), maxcount=maxcount,
         verbose=(verbose > 1);
      if(verbose)
         timer_remaining, t0, sizes(i), sizes(0);
   }
   if(verbose)
      timer_finished, t0;
}

func qi2pbd(file, ymd, outfile=, vname=, maxcount=, verbose=) {
/* DOCUMENT qi2pbd, file, ymd, outfile=, vname=, maxcount=, verbose=
   Converts an ATM *.qi file into an ALPS *.pbd file.

   Parameters:
      file: The path to the file to convert.
      ymd: An integer in YYYYMMDD format specifying the date of the data.
   Options:
      outfile= Specifies the output file to create. By default, uses the same
         filename as FILE but with a .pbd suffix.
      vname= Specifies the vname to use in the pbd file. Default is FILE,
         without its leading path or extension.
      maxcount= Specifies the maximum number of data points to store in a
         single output file. If there are more points than this, then multiple
         files will be created. Each file will have the suffix _NUM.pbd, where
         NUM is its number in the sequence as created.
            maxcount=1750000  Default, results in files ~94MB in size
      verbose= Specifies whether progress information should be shown.
            verbose=0   Silence output
            verbose=1   Show output (default)
*/
   default, outfile, file_rootname(file)+".pbd";
   default, vname, file_rootname(file_tail(file));
   default, maxcount, 1750000;
   default, verbose, 1;
   data = qi_import(qi_load(file), ymd, verbose=verbose);

   bad = data.north == 0 | data.east == 0;
   if(allof(bad))
      return;
   if(anyof(bad))
      data = data(where(!bad));

   count = numberof(data);
   if(count <= maxcount) {
      pbd_save, outfile, vname, data;
   } else {
      maxnum = long(ceil(count/double(maxcount)));
      digits = long(log10(maxnum)) + 1;
      fmt = swrite(format="%%0%dd", digits);
      outfilefmt = file_rootname(outfile) + "_" + fmt + ".pbd";
      vnamefmt = vname + "_" + fmt;
      for(i = 1; i <= maxnum; i++) {
         lower = (i-1) * maxcount + 1;
         upper = min(i*maxcount, count);
         pbd_save, swrite(format=outfilefmt, i), swrite(format=vnamefmt, i),
            data(lower:upper);
      }
   }
}
