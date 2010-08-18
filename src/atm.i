/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
require, "l1pro.i";

// Yorick functions for ATM data.

// ATM2 structure has been designed to mimic the VEG__ structure.  This allows
// most of the EAARL functions to work with ATM2.
struct ATM2 {
   long north;       // UTM northing in cm
   long east;        // UTM easting in cm
   short zone;       // UTM zone
   long elevation;   // elevation in cm
   short fint;       // reflected laser signal strength (intensity)
   long least;       // passive channel easting in cm
   long lnorth;      // passive channel northing in cm
   short lzone;      // passive channel zone
   short lint;       // passive intensity
   double soe;       // soe timestamp
   short sint;       // Start Pulse Signal Strength (relative)
   long scaz;        // Scanning azimuth in milliarcdegrees
   long pitch;       // Pitch in milliarcdegrees
   long roll;        // Roll in milliarcdegrees
}

// ATM_RAW is used to read the binary data only.
struct ATM_RAW {
   int rel_time;     // Relative time - msec from start of data file
   int lat;          // laser spot latitude (degrees x 1,000,000)
   int lon;          // laser spot longitude (degrees x 1,000,000)
   int elev;         // Elevation (millimeters)
   int pulse_start;  // Start Pulse Signal Strength (relative)
   int pulse_refl;   // Reflected Laser Signal Strength (relative)
   int azimuth;      // Scan azimuth (degrees x 1,000)
   int pitch;        // Pitch (degrees x 1,000)
   int roll;         // Roll (degrees x 1,000)
   int psig;         // Passive signal (relative)
   int plat;         // Passive Footprint latitude (degrees x 1,000,000)
   int plon;         // Passive footprint longitude (degrees x 1,000,000)
   int pelev;        // Passive footprint synthesized elevation (millimeters)
   int gps_time;     // GPS time packed (example: 153320100 = 15h 33m 20s 100ms)
}

struct ATM_RAW_10 {
   int rel_time;     // Relative time - msec from start of data file
   int lat;          // laser spot latitude (degrees x 1,000,000)
   int lon;          // laser spot longitude (degrees x 1,000,000)
   int elev;         // Elevation (millimeters)
   int pulse_start;  // Start Pulse Signal Strength (relative)
   int pulse_refl;   // Reflected Laser Signal Strength (relative)
   int azimuth;      // Scan azimuth (degrees x 1,000)
   int pitch;        // Pitch (degrees x 1,000)
   int roll;         // Roll (degrees x 1,000)
   int gps_time;     // GPS time packed (example: 153320100 = 15h 33m 20s 100ms)
}

struct ATM_RAW_14 {
   int rel_time;     // Relative time - msec from start of data file
   int lat;          // laser spot latitude (degrees x 1,000,000)
   int lon;          // laser spot longitude (degrees x 1,000,000)
   int elev;         // Elevation (millimeters)
   int pulse_start;  // Start Pulse Signal Strength (relative)
   int pulse_refl;   // Reflected Laser Signal Strength (relative)
   int azimuth;      // Scan azimuth (degrees x 1,000)
   int pitch;        // Pitch (degrees x 1,000)
   int roll;         // Roll (degrees x 1,000)
   int psig;         // Passive signal (relative)
   int plat;         // Passive Footprint latitude (degrees x 1,000,000)
   int plon;         // Passive footprint longitude (degrees x 1,000,000)
   int pelev;        // Passive footprint synthesized elevation (millimeters)
   int gps_time;     // GPS time packed (example: 153320100 = 15h 33m 20s 100ms)
}

func merge_qi_tiles(dir, glob=, srt=) {
/* DOCUMENT merge_qi_tiles, dir, glob=, srt=

   This browses through a directory of Index Tiles and merges the QI pbds into
   single pbds. The directory structure must be in the Index Tile scheme, using
   i_e######_n#######_##/t_e######_n#######_##.

   Each tile with data will have a _merged.pbd created.

   Parameters:

      dir: The directory in which the Index Tiles are located.

   Options:
   
      glob= A glob to use in searching for files to be merged. By default, this
         is "*_qi.pbd", which matches the default output of qi_to_tiles.

      srt= If set to 1, the data will be sorted by soe before writing the
         merged file. This is off by default, as it slows things down a lot.

   See also: qi_to_tiles
*/
   fix_dir, dir;
   default, glob, "*_qi.pbd";
   default, srt, 0;
   itiles = lsdirs(dir);
   w = where(strpart(itiles, strgrep("^i_e[0-9]*_n[0-9]*_[0-9]*$", itiles)));
   if(numberof(w)) {
      itiles = itiles(w);
   } else {
      write, "No index tile directories found.";
      return;
   }
   for(i = 1; i <= numberof(itiles); i++) {
      itdir = dir + itiles(i);
      fix_dir, itdir;
      ttiles = lsdirs(itdir);
      w = where(strpart(ttiles, strgrep("t_e[0-9]*_n[0-9]*_[0-9]*$", ttiles)));
      if(numberof(w)) {
         write, format=" Scanning index tile %s\n", itiles(i);
         ttiles = ttiles(w);
         for(j = 1; j <= numberof(ttiles); j++) {
            write, format=" - Scanning tile %s\n", ttiles(j);
            ttdir = itdir + ttiles(j);
            fix_dir, ttdir;
            files = lsfiles(ttdir, glob=glob);
            if(numberof(files)) {
               vdata = [];
               for(k = 1; k <= numberof(files); k++) {
                  write, format="   - Loading %s\n", files(k);
                  grow, vdata, pbd_load(ttdir + files(k));
               }
               vfile = ttiles(j) + "_merged.pbd";
               write, format="   - Creating %s\n", vfile;
               vname = ttiles(j);
               if(srt)
                  vdata = vdata(sort(vdata.soe));
               f = createb(ttdir + vfile);
               add_variable, f, -1, vname, structof(vdata), dimsof(vdata);
               get_member(f, vname) = vdata;
               save, f, vname;
               close, f;
               write, format="   - Logging tile%s", "\n";
               f = open(ttdir + ttiles(j) + "_merged.txt", "w");
               write, f, files;
               close, f;
            } else {
               write, format="   - No files found%s", "\n";
            }
         }
      } else {
         write, format=" - No tiles found%s", "\n";
      }
   }
}

func batch_qi_to_tiles(con_dir, ymd, dir, searchstr=, name=) {
/* DOCUMENT batch_qi_to_tiles, con_dir, ymd, dir, searchstr=, name=

   Finds the files in CON_DIR and generates Index Tiles for them in DIR.

   Parameters:
      con_dir: Path where qi files are found.
      ymd: A 8-digit integer representing the year-month-date of the qi files
         in YYYYMMDD format. Example: 19980215 (for Feb. 15, 1998)
      dir: The directory in which to create the Index Tiles.

   Options:
      searchstr= Search string to use to find files.
            searchstr="*.qi"     (default)
      name= A name to use within the pbd file that gets generated. This
         defaults to the first portion of the qi file's filename, up to the
         first dot.

   SEE ALSO: load_atm_raw atm_create_tiles merge_qi_tiles
*/
// Original Jim Lebonitte 2008-01-23
// Rewritten David Nagle 2009-01-27
   default, searchstr, "*.qi";
   files = find(con_dir, glob=search_str);

   for(i = 1; i<=numberof(files); i++) {
      qi_to_tiles, files(i), ymd, dir, name=name;
   }
}

func qi_to_tiles(fname, ymd, dir, name=) {
/* DOCUMENT qi_to_tiles, fname, ymd, dir, name=

   Loads the data from the files in fname and generates index tiles for them in
   dir.

   Parameters:

      fname: File names of the qi files.

      ymd: The year-month-date of the qi files.

      dir: The directory in which to create the Index Tiles.

   Options:

      name= A name to use within the pbd file that gets generated. This
         defaults to the first portion of the qi file's filename, up to the
         first dot.

   See also: load_atm_raw atm_create_tiles merge_qi_tiles
*/
   if(numberof(ymd) > 1 && (numberof(fname) != numberof(ymd)))
      error, "Error: numberof(fname) must equal numberof(ymd), or there must be only one ymd";
   default, name, strtok(strpart(fname, transpose(
         [strfind("/", fname, back=1)(2,), strlen(fname)])), ".")(1,);
   if(numberof(fname) != numberof(name)) {
      error, "Error: numberof(fname) must equal numberof(name)";
   }
   if(numberof(ymd) == 1 && numberof(fname) > 1) {
      ymd = array(ymd, numberof(fname));
   }
   for(i = 1; i <= numberof(fname); i++) {
      write, format=" Loading %s\n", fname(i);
      atm_raw = load_atm_raw(fname(i));
      if (!is_void(atm_raw)){
         atm = atm_to_alps(atm_raw, ymd(i));
         atm_raw = [];
         atm_create_tiles, atm, dir, name=name(i), buffer=0;
         atm = [];
         write, format="%s", "\n";
      }
   }
}

func open_atm_raw(fname, verbose=) {
/* DOCUMENT f = open_atm_raw(fname, verbose=)
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

   data_len = file_len - f.data_offset + 1;
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

func load_atm_raw(fname, verbose=) {
/* DOCUMENT load_atm_raw(fname, verbose=)
   Loads the ATM data from file fname and returns it as an array of ATM_RAW.
   If errors are encounted, warnings will be displayed and [] will be returned.
   Use verbose=0 to disable warning messages.
   SEE ALSO: atm_to_alps qi_to_tiles open_atm_raw
*/
   default, verbose, 1;
   f = open_atm_raw(fname, verbose=verbose);
   if(!has_member(f, "data")) {
      if(verbose)
         write, format=" Unable to extract data from %s\n", file_tail(fname);
      return [];
   }
   return struct_cast(f.data, ATM_RAW);
}

func atm_to_alps(atm_raw, ymd, verbose=) {
/* DOCUMENT atm_to_alps(atm_raw, ymd, verbose=)

   Converts ATM_RAW to ATM.

   Parameters:

      atm_raw: An array of ATM_RAW data.

      ymd: The year-month-day of the data

   See also: load_atm_raw atm_create_tiles
*/
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

func batch_qi2pbd(srcdir, ymd, outdir=, files=, searchstr=, maxcount=) {
/* DOCUMENT batch_qi2pbd, srcdir, ymd, outdir=, files=, searchstr=, maxcount=
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
*/
   default, searchstr, ["*.qi", "*.QI"];

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
      qi2pbd, files(i), ymd, outfile=outfiles(i), maxcount=maxcount;
      timer_remaining, t0, sizes(i), sizes(0);
   }
   timer_finished, t0;
}

func qi2pbd(file, ymd, outfile=, vname=, maxcount=) {
/* DOCUMENT qi2pbd, file, ymd, outfile=, vname=, maxcount=
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
*/
   default, outfile, file_rootname(file)+".pbd";
   default, vname, file_rootname(file_tail(file));
   default, maxcount, 1750000;
   data = atm_to_alps(load_atm_raw(file), ymd);

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

func atm_create_tiles(atm, dir, name=, buffer=) {
/* DOCUMENT atm_create_tiles, atm, dir, name=, buffer=

   For a given array of ATM data (atm), this creates tiles in directory dir.

   Parameters:

      atm: An array of ATM2 data.

      dir: The directory for the output.

   Options:

      name= A string that will get embedded in the pbd filenames that are
         written. Defaults to "atm_raw". All strings also get "_qi.pbd"
         appended as well.

      buffer= A buffer to add around each tile, in centimeters. Default is
         20000 cm (200 m). Use buffer=0 to disable.

   See also: qi_to_tiles merge_qi_tiles atm_to_alps
*/
   default, name, "atm_raw";
   default, buffer, 20000;
   fix_dir, dir;
   mkdir, dir;
   
   bad = atm.north == 0 | atm.east == 0;
   write, format=" There are %i (of %i, %.2f%%) unusable points without north/east coords.\n",
      numberof(where(bad)), numberof(atm), 1.0*numberof(where(bad))/numberof(atm);
   atm = atm(where(!bad));
   bad = [];
   
   // Segment data by zone
   for(z = min(atm.zone); z <= max(atm.zone); z++) {
      w = where(atm.zone == z);
      if(numberof(w)) {
         atm_z = atm(w);
         minin = int(ceil(min(atm_z.north)/1000000.0)*1000000);
         maxin = int(ceil(max(atm_z.north)/1000000.0)*1000000);
         // Segment data into itiles, by northing then easting
         for(in = minin; in <= maxin; in += 1000000) {
            w = where(atm_z.north > in - 1000000 - buffer & atm_z.north <= in + buffer);
            if(numberof(w)) {
               atm_in = atm_z(w);
               minie = int(floor(min(atm_in.east)/1000000.0)*1000000);
               maxie = int(floor(max(atm_in.east)/1000000.0)*1000000);
               for(ie = minie; ie <= maxie; ie += 1000000) {
                  w = where(atm_in.east >= ie - buffer & atm_in.east < ie + 1000000 + buffer);
                  if(numberof(w)) {
                     atm_ie = atm_in(w);
                     itile = swrite(format="i_e%d_n%d_%d", ie/100, in/100, z);
                     ipath = dir + itile + "/";
                     mintn = int(ceil(min(atm_ie.north)/200000.0)*200000);
                     maxtn = int(ceil(max(atm_ie.north)/200000.0)*200000);
                     // Segment data into tiles, by northing then easting
                     for(tn = mintn; tn <= maxtn; tn += 200000) {
                        w = where(atm_ie.north > tn - 1000000 - buffer & atm_ie.north <= tn + buffer);
                        if(numberof(w)) {
                           atm_tn = atm_ie(w);
                           minte = int(floor(min(atm_tn.east)/200000.0)*200000);
                           maxte = int(floor(max(atm_tn.east)/200000.0)*200000);
                           for(te = minte; te <= maxte; te += 200000) {
                              w = where(atm_tn.east >= te - buffer & atm_tn.east < te + 200000 + buffer);
                              if(numberof(w)) {
                                 atm_te = atm_tn(w);
                                 ttile = swrite(format="t_e%d_n%d_%d", te/100, tn/100, z);
                                 tpath = ipath + ttile + "/";
                                 // Need better names here.
                                 vname = swrite(format="e%d_n%d_%d_%s", te/100000, tn/100000, z, name);
                                 tfile = swrite(format="%s_%s_qi.pbd", ttile, name);
                                 write, format=" * Creating %s\n", tfile;
                                 mkdir, ipath;
                                 mkdir, tpath;
                                 f = createb(tpath + tfile);
                                 add_variable, f, -1, vname, structof(atm_te), dimsof(atm_te);
                                 get_member(f, vname) = atm_te;
                                 save, f, vname;
                                 close, f;
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}
