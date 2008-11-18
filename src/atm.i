/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
write, "$Id$";
//require, "yeti.i"; // Shouldn't be needed at present
require, "plcm.i";
require, "sel_file.i";
require, "ll2utm.i";
require, "ytime.i";
require, "general.i";
require, "dir.i";

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
                  f = openb(ttdir + files(k));
                  restore, f, vname;
                  grow, vdata, get_member(f, vname);
                  close, f;
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

func batch_qi_to_tiles(con_dir, ymd, dir,searchstr=, name=) {
/* DOCUMENT batch_qi_to_tiles, con_dir, ymd, dir,searchstr, name=

   Loads the data from the files in fname and generates index tiles for them in
   dir.

   Parameters:

      con_dir, string: File names of the qi files.

      ymd: The year-month-date of the qi files. format YYYYMMDD

      dir, string: The directory in which to create the Index Tiles.

   Options:

      searchstr, string: search string of files to search for   default:"*.pbd"

      name, string= A name to use within the pbd file that gets generated. This
         defaults to the first portion of the qi file's filename, up to the
         first dot.

   See also: load_atm_raw atm_create_tiles merge_qi_tiles

*/

   if(is_void(searchstr)) {
          searchstr="*.qi"
   }

   command = swrite(format="find %s -name '%s'", con_dir, searchstr);

   files = ""
   s = array(string,10000);
   f = popen(command, 0);
   nn = read(f,format="%s",s);
   s = s(where(s));
   numfiles = numberof(s);
   newline = "\n"
   data=[];

   for(i=1; i<=numfiles; i++) {

      filename=s(i);
      qi_to_tiles(filename, ymd, dir, name=)

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
   write, format=" There %i (of %i, %.2f%%) unusable points without north/east coords.\n",
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

// The following functions are completely unrelated to the preceeding
// functions. Though they all deal with ATM data, the following use a
// completely unrelated structure/approach/set of variables as the preceeding.
// So you probably can't mix and match.

func load {
/* DOCUMENT load
   Loads an ATM .pbd. This .pbd should have the following variables at minimum:
   iz (elevation), lat, lon, z(?). They will be set as externs, as will fn, f,
   ilat, and ilon.
*/
   extern fn, f, lat,lon, ilat,ilon, iz, z;
   fn = sel_file(ss="*.pbd") (1);         // select the data file
   f = openb(fn);                         // open selected file
   show,f;                                // display vars in file
   restore,f;                             // load the data to ram
   write,format="%s loaded %d points\n", fn, numberof(ilat);
   lat = ilat / 1.0e6;                    // make a floating pt lat
   lon = ilon / 1.0e6 - 360.0;            // make fp lon 
}

func show_all(ani=)  {
/* DOCUMENT show_all, ani=

   Display an entire atm data file as sequencial images false color coded
   elevation maps. Expects its data to be in externs as follows:

      extern iz - Elevation
      extern lat - Latitude
      extern lon - Longitude

   Set ani=1 to only see completed images, using animation.
*/
   default, ani, 0;  // Don't use animation by default
   b = 1;            // starting record number
   inc = 50000;      // number to adjust start pt by
   n = 50000;        // number of points to display/image
   if(ani) animate, 1;
   for (b = 1; b < numberof(lat)-inc-1; b += inc ) {   // loop thru file
      fma;
      write, format="%8d %8.4f %8.4f\n", b, lat(b), lon(b);
      plcm, iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=-41000, cmax=-30000,
         marker=1, msize=1.0;
   }
   if(ani) animate, 0;
}


func show_frame (b, n, cmin=, cmax=, marker=, msize= ){
/* DOCUMENT show_frame

   Display a single atm display frame. Expects its data to be in externs as
   follows:

      extern iz - Elevation
      extern lat - Latitude
      extern lon - Longitude

   b is the indice into them each to start at, and n is the number of points to
   use from that indice.
*/
   default, cmin, -42000;
   default, cmax, -22000;
   default, sz, 0.0015;
   default, msize, 1.0;
   fma; 
   write, format="%8d %8.4f %8.4f\n", b, lat(b), lon(b);
   plcm, iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=cmin, cmax=cmax, marker=1, msize=msize;
}

func atm_rq_ascii_to_pbd(ipath, ifname=, columns=, searchstr=, opath=) {
/* DOCUMENT atm_rq_ascii_to_pbd, ipath, ifname=, columns=, searchstr=, opath=
   
   Converts an atm_rq_ascii(?) to a pbd, using struct ATM2.
*/
   // Original: Amar Nayegandhi, 10/05/2006

   if (is_void(ifname)) {
      s = array(string, 10000);
      default, searchstr, ["*.txt", "*.xyz"];
      scmd = swrite(format="find %s -name '%s'", ipath, searchstr);
      fp = 1;
      lp = 0;
      for (i=1; i<=numberof(scmd); i++) {
         f=popen(scmd(i), 0);
         n = read(f,format="%s", s);
         close, f;
         lp = lp + n;
         if(n) fn_arr = s(fp:lp);
         fp = fp + n;
      }
   } else {
      fn_arr = ipath + ifname;
      n = numberof(ifname);
   }

   write, format="Number of files to read = %d \n", n;

   for (i=1;i<=n;i++) {
      // read ascii file
      write, format="Reading file %d of %d\n",i,n;
      fn_split = split_path(fn_arr(i),0);
      asc_out = read_ascii_xyz(ipath=fn_split(1),ifname=fn_split(2),columns=columns);
      ncount = numberof(asc_out(1,));
      atm_out = array(ATM2,ncount);
      // convert lat lon to utm
      e_utm = fll2utm(asc_out(1,), asc_out(2,));
      atm_out.east = long(e_utm(2,)*100);
      atm_out.north = long(e_utm(1,)*100);
      atm_out.elevation = long(asc_out(3,)*100);
      atm_out.fint = short(asc_out(4,));
      e_utm = fll2utm(asc_out(5,), asc_out(5,));
      atm_out.least = long(e_utm(2,)*100);
      atm_out.lnorth = long(e_utm(1,)*100);
      atm_out.lint = short(asc_out(7,));
      atm_out.soe = asc_out(8,);
      // write atm_out to a pbd file
      ofn_split = split_path(fn_arr(i),0);
      ofn_split1 = split_path(ofn_split(2),0,ext=1);
      ofn = ofn_split1(1)+".pbd";
      write, format="Writing file %s\n",ofn;
      if (opath)
         f = createb(opath+ofn);
      else
         f = createb(ofn_split(1)+ofn);
      save, f, atm_out;
      close, f;
   }
}

func rcf_atm_pbds(ipath, ifname=, searchstr=, buf=, w=, opath=, meta=) {
/* DOCUMENT rcf_atm_pbds, ipath, ifname=, searchstr=, buf=, w=, opath=
ipath = string, pathname of the directory containing the atm pbd files
ifname = string, pathname of an individual file that you would like to filter
buf= the buf variable for the rcf filter
w = the w variable for the rcf filter
opath = output path for the files (defaults to the same directory where
         the originals are.
meta = set to 1 if you want the filtering parameters in the filename set
       to 0 if otherwise (defaults to 1)


note:  This function only uses the regular rcf filter because ATM data
       contains only first surface points.

*/
  // Original: Amar Nayegandhi, 10/05/2006
   if (is_void(meta)) meta=1;
   default, buf, 1000;
   default, w, 2000;
   if (is_void(ifname)) {
      s = array(string, 10000);
      default, searchstr, ["*.pbd"];
      scmd = swrite(format = "find %s -name '%s'",ipath, searchstr);
      fp = 1;
      lp = 0;
      for (i=1; i<=numberof(scmd); i++) {
         f=popen(scmd(i), 0);
         n = read(f, format="%s", s);
         close, f;
         lp = lp + n;
         if(n) fn_arr = s(fp:lp);
         fp = fp + n;
      }
   } else {
      fn_arr = ipath+ifname;
      n = numberof(ifname);
   }

   write, format="Number of files to read = %d\n", n;

   for (i=1; i<=n; i++) {
      // read pbd file
      f = openb(fn_arr(i));
      restore, f, vname;
      atm_out=get_member(f, vname);
      info, atm_out;
      close, f;
      atm_rcf = rcfilter_eaarl_pts(atm_out, buf=buf, w=w, mode=1);

      // write atm_rcf to a pbd file
      ofn_split = split_path(fn_arr(i),0);
      ofn_split1 = split_path(ofn_split(2),0,ext=1);
      
      if(meta!=1) { 
         ofn = ofn_split1(1)+"_rcf.pbd";
      } else {
         ofn = ofn_split1(1)+swrite(format = "_b%d_w%d_rcf.pbd", buf, w)
      }
      write, format="Writing file %s\n",ofn;
      if(atm_rcf!=[]) {
         
         if (opath) {
          f = createb(opath+ofn);
         } else {
          f = createb(ofn_split(1)+ofn);
         }
         add_variable, f, -1, vname, structof(atm_rcf), dimsof(atm_rcf);
         get_member(f, vname) = atm_rcf;
         save, f, vname;
         close, f
      } else {
         close, f
      }
   }
}

func write_atm(opath, ofname, atm_all, type=) {
// David Nagle 2008-08-28
   fs_all = array(FS, numberof(atm_all));
   fs_all.north = atm_all.north;
   fs_all.east = atm_all.east;
   fs_all.elevation = atm_all.elevation;
   fs_all.intensity = atm_all.fint;
   fs_all.soe = atm_all.soe;
   write_topo, opath, ofname, fs_all;
}
