/******************************************************************************\
* This file was created in the attic on 2010-07-15. It contains obsolete       *
* functions from atm.i:                                                        *
*     load                                                                     *
*     show_all                                                                 *
*     show_frame                                                               *
*     atm_rq_ascii_to_pbd                                                      *
*     rcf_atm_pbds                                                             *
* See file atm.i for the currently-used functions. Function 'rcf_atm_pbds' is  *
* replaced by new_batch_rcf.                                                   *
\******************************************************************************/

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

func atm_rq_ascii_to_pbd(ipath, ifname=, searchstr=, opath=) {
/* DOCUMENT atm_rq_ascii_to_pbd, ipath, ifname=, searchstr=, opath=
   
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
      asc_out = read_ascii(fn_arra(i));
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
