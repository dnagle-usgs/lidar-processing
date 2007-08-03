/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
write, "$Id$";
require, "plcm.i";
require, "sel_file.i";
require, "ll2utm.i";
require, "ytime.i";

// Yorick functions to display atm data.

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

func load_atm_raw(fname) {
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
   return atm_raw;
}

func atm_to_alps(atm_raw, ymd) {
   atm = array(ATM2, numberof(atm_raw));

   write, "Converting ATM lat/lon to UTM";
   idx = where(atm_raw.lat != 0 & atm_raw.lon != 0);
   if(numberof(idx)) {
      u = fll2utm(atm_raw(idx).lat/1000000.0, atm_raw(idx).lon/1000000.0);
      atm(idx).north = int(u(1,) * 100);
      atm(idx).east = int(u(2,) * 100);
      zone = u(3,);
      write, "UTM Zone of data:"
      write, "Min:", min(zone);
      write, "Max:", max(zone);
      atm(idx).zone = int(u(3,));
   } else {
      write, "Serious problem encountered: No lat/lon info!";
   }
   
   atm.elevation = atm_raw.elev;
   atm.fint = atm_raw.pulse_refl;
   
   write, "Converting ATM passive lat/lon to UTM";
   idx = where(atm_raw.plat != 0 & atm_raw.plon != 0);
   if(numberof(idx)) {
      u = fll2utm(atm_raw(idx).plat/1000000.0, atm_raw(idx).plon/-1000000.0);
      atm(idx).lnorth = int(u(1,) * 100);
      atm(idx).least = int(u(2,) * 100);
   }
   atm.lint = atm_raw.psig;

   write, "Converting ATM GPS Time to SOE";
   doy = ymd2doy(ymd);
   atm.soe = time2soe([int(ymd/10000), ymd2doy(ymd),
         hms2sod(atm_raw.gps_time/100.0), 0, 0, 0]);

   atm.sint = atm_raw.pulse_start;
   atm.scaz = atm_raw.azimuth;
   atm.pitch = atm_raw.pitch;
   atm.roll = atm_raw.roll;

   return atm;
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

func rcf_atm_pbds(ipath, ifname=, searchstr=, buf=, w=, opath=) {
/* DOCUMENT rcf_atm_pbds, ipath, ifname=, searchstr=, buf=, w=, opath=
*/
  // Original: Amar Nayegandhi, 10/05/2006

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
      restore, f;
      info, atm_out;
      close, f;
      atm_rcf = rcfilter_eaarl_pts(atm_out, buf=buf, w=w, mode=1);

      // write atm_rcf to a pbd file
      ofn_split = split_path(fn_arr(i),0);
      ofn_split1 = split_path(ofn_split(2),0,ext=1);
      ofn = ofn_split1(1)+"_rcf.pbd";
      write, format="Writing file %s\n",ofn;
      if (opath) {
         f = createb(opath+ofn);
      } else {
         f = createb(ofn_split(1)+ofn);
      }
      save, f, atm_rcf;
      close, f
   }
}
