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

func load_atm_raw(fname) {
/* DOCUMENT load_atm_raw(fname)

   Loads the ATM data from file fname and returns it as an array of ATM_RAW.

   See also: atm_to_alps qi_to_tiles
*/
   f = open(fname, "rb");
   sun_primitives, f;

   // The size of each word
   word_len = 4;
   
   // The size of each record
   rec_len = 0;
   _read, f, 0, rec_len;

   // Data segment offset
   data_offset = 0;
   _read, f, rec_len + word_len, data_offset;

   // Size of file
   file_len = sizeof(f);

   // Number of records
   rec_num = (file_len - data_offset + 1) / rec_len;
   
   all_fields = ["rel_time", "lat", "lon", "elev", "pulse_start", "pulse_refl",
         "azimuth", "pitch", "roll", "psig", "plat", "plon", "pelev",
         "gps-time"];
   if(rec_len == 14 * word_len) {
      fields = all_fields;
   } else if(rec_len == 10 * word_len) {
      fields = all_fields([1,2,3,4,5,6,7,8,9,14]);
   } else {
      error, swrite(format="Don't know how to handle a record length of %d.",
            rec_len);
   }
   
   for(i = 1; i <= numberof(fields); i++) {
      add_member, f, "ATM_RAW", (i - 1) * word_len, fields(i), int, 1;
   }
   install_struct, f, "ATM_RAW";

   atm_raw = array(ATM_RAW, rec_num);
   _read, f, data_offset, atm_raw;
   
  /* 
   bad = atm_raw.lat < 0 ; 
   
   write, format=" There %i (of %i, %.2f%%) unusable points with bad lat coordinates.\n",
      numberof(where(bad)), numberof(atm_raw), 1.0*numberof(where(bad))/numberof(atm_raw);
   
   if (numberof(where(bad == 1)) == numberof(atm_raw))
      atm_raw= [];
   

   if (where(bad)==1 != 0) 
      if(!is_void(atm_raw)) 
         atm_raw=atm_raw(where(bad == 0 ));
   
   if(!is_void(atm_raw)) {
      bad = [];
      bad = atm_raw.lon > 0 ; 
      write, format=" There %i (of %i, %.2f%%) unusable points with bad lon coordinates.\n",
      numberof(where(bad)), numberof(atm_raw), 1.0*numberof(where(bad))/numberof(atm_raw);
   
      if (numberof(where(bad == 1)) == numberof(atm_raw))
         atm_raw= [];
      
      if (!is_void(bad)) 
          if(!is_void(atm_raw)) 
             atm_raw=atm_raw(where(bad == 0));
      
      bad = [];
  } 
  jim();
  */

   return atm_raw;
}

func atm_to_alps(atm_raw, ymd) {
/* DOCUMENT atm_to_alps(atm_raw, ymd)

   Converts ATM_RAW to ATM.

   Parameters:

      atm_raw: An array of ATM_RAW data.

      ymd: The year-month-day of the data

   See also: load_atm_raw atm_create_tiles
*/
   atm = array(ATM2, numberof(atm_raw));

   write, "Converting ATM lat/lon to UTM";
   idx = where(atm_raw.lat != 0 & atm_raw.lon != 0);
   if(numberof(idx)) {
      u = fll2utm(atm_raw(idx).lat/1000000.0, atm_raw(idx).lon/1000000.0);
      d=int(u);
      atm(idx).north = (d(1,) * 100);
      atm(idx).east = (d(2,) * 100);
      zone = d(3,);
      write, "UTM Zone of data:"
      write, "Min:", min(zone);
      write, "Max:", max(zone);
      atm(idx).zone = int(u(3,));
   } else {
      write, "Serious problem encountered: No lat/lon info!";
   }
   
   atm.elevation = atm_raw.elev/10.0;
   atm.fint = atm_raw.pulse_refl;
   
   write, "Converting ATM passive lat/lon to UTM";
   idx = where(atm_raw.plat != 0 & atm_raw.plon != 0);
   if(numberof(idx)) {
      u = fll2utm(atm_raw(idx).plat/1000000.0, atm_raw(idx).plon/-1000000.0);
      atm(idx).lnorth = u(1,) * 100;
      atm(idx).least  = u(2,) * 100;
   }
   atm.lint = atm_raw.psig;

   write, "Converting ATM GPS Time to SOE";
   for (i=0; i<numberof(atm); i++) {
      atm.soe(i) = time2soe([int(ymd/10000), ymd2doy(ymd),
             (hms2sod(atm_raw.gps_time(i)/100.0)), 0, 0, 0]);
   }
   atm.sint = atm_raw.pulse_start;
   atm.scaz = atm_raw.azimuth;
   atm.pitch = atm_raw.pitch;
   atm.roll = atm_raw.roll;

   return atm;
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
