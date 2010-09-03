// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "l1pro.i";
require, "scanflatmirror2.i";

/*
   the a array has an array of RTRS structures;
  struct RTRS {
  int raster;
  double soe(120);
  short irange(120);
  short intensity(120);
  short sa(120);
}
*/

/*
   Structure used to hold laser return vector information. All the
 values are in air-centimeters.
*/

func first_surface(nil, start=, stop=, center=, delta=, north=, usecentroid=, use_highelv_echo=, quiet=, verbose=) {
/* DOCUMENT first_surface(start=, stop=, center=, delta=, north= )

   Project the EAARL threshold trigger point to the surface.

 Inputs:
   start=   Raster number to start with.
    stop=   Ending raster number.
  center=   Center raster when doing before and after.
   delta=   NUmber of rasters to process before and after.
   north=       Ignore heading, and assume north.
usecentroid=   Set to 1 to use the centroid of the waveform.
use_highelv_echo= Set to 1 to exclude waveforms that tripped above the range gate.

 This returns an array of type "R" which
 will contain the xyz of the mirror "track point" and the xyz of the
 "first surface threshold trigger point" or "fsttp."  The "fsttp" is
 derived here by using the "irange" (integer range) value from the raw
 data.  While the fsttp is certainly not the best range measurement, it
 does establish highly acurate vector information which will greatly
 simplify additional subaerial waveform processing.

  0 = center, delta
  1 = start,  stop
  2 = start,  delta

   verbose= By default, progress/info output is enabled (verbose=1). Set
   verbose=0 to silence it. (For backwards compatibility, there is also a
   quiet= option that works inversely to verbose=, but it is deprecated.)

*/
   extern roll, pitch, heading, palt, utm, northing, easting;
   extern a, irg_a;
   default, quiet, 0;
   default, verbose, !quiet;
   default, north, 0;

   if(is_void(ops_conf))
      error, "ops_conf is not set";

   i = j = [];
   if(!is_void(center)) {
      default, delta, 100;
      start = center - delta;
      stop = center + delta;
   } else {
      if(is_void(start))
         error, "Must provide start= or center=";
      if(!is_void(delta))
         stop = start + delta;
      else if(is_void(stop))
         error, "When using start=, you must provide delta= or stop=";
   }

   // This is to prevent overrunning available memory
   maxcount = 25000;
   if(stop - start >= maxcount) {
      count = stop - start + 1;
      intervals = long(ceil(count/double(maxcount)));
      parts = array(pointer, intervals);
      for(i = start, interval = 1; interval <= intervals; i+=maxcount, interval++) {
         i = min(stop, i);
         j = min(stop, i + maxcount - 1);
         parts(interval) = &first_surface(start=i, stop=j, north=north,
            usecentroid=usecentroid, use_highelv_echo=use_highelv_echo,
            verbose=verbose);
      }
      return merge_pointers(parts);
   }

   a = irg(start, stop, usecentroid=usecentroid, use_highelv_echo=use_highelv_echo);
   irg_a = a;

   atime = a.soe - soe_day_start;

   if(verbose)
      write, format="%s", "\n Interpolating: roll...";
   roll = interp(tans.roll, tans.somd, atime);

   if(verbose)
      write, format="%s", " pitch...";
   pitch = interp(tans.pitch, tans.somd, atime);

   if(!north) {
      if(verbose)
         write, format="%s", " heading...";
      heading = interp_angles(tans.heading, tans.somd, atime);
   } else {
      if(verbose)
         write, format="%s", " interpolating north only...";
      heading = array(0., dimsof(atime));
   }

   if(verbose)
      write, format="%s", " altitude...";
   palt = interp(pnav.alt, pnav.sod, atime);

   if(verbose)
      write, format="%s", " northing/easting...\n";
   local pnav_north, pnav_east;
   ll2utm, pnav.lat, pnav.lon, pnav_north, pnav_east;
   northing = interp(pnav_north, pnav.sod, atime);
   easting = interp(pnav_east, pnav.sod, atime);
   pnav_north = pnav_east = [];

   count = stop - start + 1;
   rrr = array(R, count);

   cyaw = array(0., 120);

   // mirror offsets
   dx = array(ops_conf.x_offset, 120); // perpendicular to fuselage
   dy = array(ops_conf.y_offset, 120); // along fuselage
   dz = array(ops_conf.z_offset, 120); // vertical

   // Constants for mirror angle and laser angle
   mirang = array(-22.5, 120);
   lasang = array(45.0, 120);

   if(verbose)
      write, "Projecting to the surface...";

   // Check to see if scan angles must be fixed. If not, use ops_conf bias.
   scan_bias = array(ops_conf.scan_bias, count);
   fix = [];
   if(is_array(fix_sa1) && is_array(fix_sa2)) {
      write, "Using scan angle fixes...";

      if(a(1).sa(1) > a(1).sa(118))
         fix=fix_sa1(start:stop);
      else
         fix=fix_sa2(start:stop);

      for(i = 1; i <= count; i++)
         scan_bias(i) = a(i).sa(1) - fix(i);
   }

   // Calculate scan angles
   scan_angles = SAD * (a.sa + scan_bias(-,));
   scan_bias = [];

   // edit out tx/rx dropouts
   a.irange *= ((long(a.irange) & 0xc000) == 0);

   // Calculate magnitude of vectors from mirror to ground
   mag = a.irange * NS2MAIR - ops_conf.range_biasM;

   pitch += ops_conf.pitch_bias;
   roll += ops_conf.roll_bias;
   yaw = -heading + ops_conf.yaw_bias;

   bcast = long(yaw * 0);

   m = scanflatmirror2_direct_vector(
      yaw, pitch, roll,
      easting, northing, palt,
      dx, dy, dz,
      bcast + cyaw(,-),
      bcast + lasang(,-),
      bcast + mirang(,-), scan_angles, mag);

   rrr.meast  =     m(..,1) * 100.0;
   rrr.mnorth =     m(..,2) * 100.0;
   rrr.melevation=  m(..,3) * 100.0;
   rrr.east   =     m(..,4) * 100.0;
   rrr.north  =     m(..,5) * 100.0;
   rrr.elevation =  m(..,6) * 100.0;
   rrr.rn = (a.raster&0xffffff)(-,);
   rrr.intensity = a.intensity;
   rrr.fs_rtn_centroid = a.fs_rtn_centroid;
   rrr.rn += (indgen(120)*2^24)(,-);
   rrr.soe = a.soe;

   if(verbose && count >= 100)
      write, format="%5d %8.1f %6.2f %6.2f %6.2f\n",
         indgen(100:count:100),
         a(100:count:100).soe(60)%86400,
         palt(60,100:count:100),
         roll(60,100:count:100),
         pitch(60,100:count:100);

   return rrr;
}

func open_seg_process_status_bar {
  if ( _ytk  ) {
    tkcmd,"destroy .seg; toplevel .seg; set progress 0;wm title .seg \"Flight Segment Progress Bar\""
    tkcmd,swrite(format="ProgressBar .seg.pb \
   -fg cyan \
   -troughcolor blue \
   -relief raised \
   -maximum %d \
   -variable progress \
   -height 30 \
   -width 400", 100 );
    tkcmd,"pack .seg.pb; update;"
    tkcmd,"center_win .seg;"
  }
}

func make_fs(latutm=, q=, ext_bad_att=, usecentroid=) {
  /* DOCUMENT make_fs(latutm=, q=, ext_bad_att=)
     This function prepares data to write/plot first surface topography
     for a selected region of flightlines.
     amar nayegandhi 09/18/02
  */
  extern edb, soe_day_start, tans, pnav, type, utm, rn_arr_idx, rn_arr;
  rn_arr =[];
   if(is_void(ops_conf))
      error, "ops_conf is not set";


   if (!is_array(tans)) {
     write, "INS information not loaded.  Running function load_iexpbd() ... \n";
     // tans = rbtans();
    x = ops_conf;        // save ops_conf before load_iexpbd trashes it.
    load_iexpbd, ins_filename;
    ops_conf = x;        // now set it back.
     write, "\n";
   }
   write, "TANS information LOADED. \n";
   if (!is_array(pnav)) {
     write, "Precision Navigation (PNAV) data not loaded."+
            "Running function rbpnav() ... \n";
     pnav = rbpnav(fn=pnav_filename);
   }
   write, "PNAV information LOADED. \n"
   write, "\n";

   if (!is_array(q)) {
    /* select a region using function gga_win_sel in rbgga.i */
    q = gga_win_sel(2, latutm=latutm, llarr=llarr);
   }

  /* find start and stop raster numbers for all flightlines */
   rn_arr = sel_region(q);

 if (!is_void(rn_arr)) {

   no_t = numberof(rn_arr(1,));

   /* initialize counter variables */
   tot_count = 0;
   ba_count = 0;
   fcount = 0;

   open_seg_process_status_bar;
   fs_all = array(R, rn_arr(dif,sum)(1)+numberof(rn_arr(1,)));
   end = 0;
   for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
       fcount ++;
       write, format="Processing segment %d of %d for first_surface...\n",i,no_t;
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=usecentroid);
       //a=[];
       new_end = end + numberof(rrr);
       fs_all(end+1:new_end) = rrr;
       end = new_end;
       tot_count += numberof(rrr.elevation);
      }
    }
    fs_all = end ? fs_all(:end) : [];

    if ( _ytk )
      tkcmd,"destroy .seg";

   /* if ext_bad_att is set, find all points having elevation = 70% of ht
       of airplane
   */
   if (is_array(fs_all)) {
    if (ext_bad_att) {
        write, "Extracting and writing false first points";
        /* compare rrr.elevation within 20m  of rrr.melevation */
   elv_thresh = fs_all.melevation-2000;
        ba_indx = where(fs_all.elevation > elv_thresh);
   ba_count += numberof(ba_indx);
   ba_fs = fs_all;
   deast = fs_all.east;
      if ((is_array(ba_indx))) {
     deast(ba_indx) = 0;
        }
   dnorth = fs_all.north;
      if ((is_array(ba_indx))) {
    dnorth(ba_indx) = 0;
   }
   fs_all.east = deast;
   fs_all.north = dnorth;

   ba_indx_r = where(ba_fs.elevation < elv_thresh);
   bdeast = ba_fs.east;
      if ((is_array(ba_indx_r))) {
    bdeast(ba_indx_r) = 0;
   }
   bdnorth = ba_fs.north;
      if ((is_array(ba_indx_r))) {
    bdnorth(ba_indx_r) = 0;
   }
   ba_fs.east = bdeast;
   ba_fs.north = bdnorth;

      }
    }


    write, "\nStatistics: \r";
    write, format="Total records processed = %d\n",tot_count;
    write, format="Total records with inconclusive first surface"+
                   "return range = %d\n",ba_count;

    if ( tot_count != 0 ) {
       pba = float(ba_count)*100.0/tot_count;
       write, format = "%5.2f%% of the total records had "+
                       "inconclusive first surface return ranges \n",pba;
    } else
   write, "No first surface returns found"

    no_append = 0;

// Compute a list of indices into each flight segment from rn_arr.
// This information can be used to selectively plot each selected segment
// along, or only a specfic group of selected segments.
    rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);

    write,"fs_all contains the data, and rn_arr_idx contains a list of indices"
    str=swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))
    if ( _ytk ) {
      tkcmd, str;
    } else {
      write, str;
    }

    return fs_all;
 } else write, "No good returns found"

}
