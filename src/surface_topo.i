/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "l1pro.i";
require, "scanflatmirror2_direct_vector.i";

/*
   W. Wright

   7/7/02 WW
	Added north= to first_surface. 
*/

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

func winsel(junk) {
/* DOCUMENT q = winsel()
   Select a section from a gga map with the mouse, and this will return
 the  raster numbers that occurs in the selection.  Works with lat/lon
 gga data only at this point.

*/
 ma = mouse(1,1,
  "Hold the left mouse button down, select a region:");
 ma(1:4)
 minlon = min( [ ma(1), ma(3) ] )
 maxlon = max( [ ma(1), ma(3) ] )
 minlat = min( [ ma(2), ma(4) ] )
 maxlat = max( [ ma(2), ma(4) ] )
 q = where( rrr.east > minlon );
 qq = where( rrr.east(q) < maxlon );  q = q(qq);
 qq = where( rrr.north(q) > minlat ); q = q(qq);
 qq = where( rrr.north(q) < maxlat ); q = q(qq);
 write,format="%d records found\n", numberof(q);
return q
}


func make_pnav_from_gga( gga ) {
/* make_pnav_from_gga( gga )
 
  Builds and returns a pnav structure from a gga structure.

*/
   pnav = array( PNAV, dimsof( gga )(2) );
   pnav.sod = gga.sod;
   pnav.lat = gga.lat;
   pnav.lon = gga.lon;
   pnav.alt = gga.alt;
   return pnav;
}

func first_surface(nil, start=, stop=, center=, delta=, north=, usecentroid=, use_highelv_echo=, quiet=, verbose=) {
/* DOCUMENT first_surface(start=, stop=, center=, delta=, north= )

   Project the EAARL threshold trigger point to the surface. 

 Inputs:
   start=	Raster number to start with.
    stop=	Ending raster number.
  center=	Center raster when doing before and after.
   delta=	NUmber of rasters to process before and after.
   north=       Ignore heading, and assume north.
usecentroid=	Set to 1 to use the centroid of the waveform.  
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
   extern a, irg_a, _utm;
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

   a = irg(start, stop, usecentroid=usecentroid, use_highelv_echo=use_highelv_echo);		
   irg_a = a;

   atime   = a.soe - soe_day_start;

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
      heading = interp( array( 0.0, dimsof(tans)(2) ), tans.somd, atime ) 
   }

   if(verbose)
      write, format="%s", " altitude...";
   palt  = interp( pnav.alt,   pnav.sod,  atime )

   if ( is_void( _utm ) ) {
      if(verbose)
         write, "Converting from lat/lon to UTM...";
      _utm = fll2utm( pnav.lat, pnav.lon )
   } else {
      if ( dimsof(pnav)(2) != dimsof(pnav)(2) ) 
      if(verbose)
         write, "_utm has changed, re-converting from lat/lon to UTM...";
      _utm = fll2utm( pnav.lat, pnav.lon )
   }

   if(verbose)
      write, format="%s", " northing/easting...\n";
   northing = interp( _utm(1,), pnav.sod, atime )
   easting  = interp( _utm(2,), pnav.sod, atime )

   sz = stop - start + 1;
   rrr = array(R, sz);
   if ( is_void(step) ) 
      step = 1;
   cyaw = gz = gx = gy = lasang = yaw = array( 0.0, 120);
   dx = array( ops_conf.x_offset, 120);
   dy = array( ops_conf.y_offset, 120);	// mirror offset along fuselage
   dz = array( ops_conf.z_offset, 120);	// vertical mirror offset 
   mirang = array(-22.5, 120);
   lasang = array(45.0, 120);

   if(verbose)
      write, "Projecting to the surface...";

   if ( is_array(fix_sa1) ) {    // we'll assume both are set
      write,"####################### MARK HERE ###################"
      sb=array(0, sz);

      // "MARK A"
      info,a;

      if ( a(1).sa(1) > a(1).sa(118) ) {
         fix=fix_sa1(start:stop);
      } else { 
         fix=fix_sa2(start:stop);
      }
   }

   for ( i=1; i< sz; i += step) {


      gx  = easting (, i);
      gy  = northing(, i);
      yaw = -heading(, i);

      if ( is_array(fix) ) {
         // sb(i) = fix(i) - a(i).sa(1);
         // "MARK B"
         sb(i) = a(i).sa(1) - fix(i);

         scan_ang = SAD * (a(i).sa + sb(i));
         /*
         fix = (a(i).sa(118) + sb(i));
         */
      } else
         scan_ang = SAD * (a(i).sa + ops_conf.scan_bias);

// edit out tx/rx dropouts
      el = ( int(a(i).irange) & 0xc000 ) == 0 ;
      a(i).irange *= el;

      srm = (a(i).irange*NS2MAIR - ops_conf.range_biasM);
      gz = palt(, i);
      // "MARK C"
      m = scanflatmirror2_direct_vector(yaw+ ops_conf.yaw_bias,
      pitch(,i)+ ops_conf.pitch_bias,roll(,i)+ ops_conf.roll_bias,
         gx,gy,gz,dx,dy,dz,cyaw, lasang, mirang, scan_ang, srm)
      // "MARK D"
  
      rrr(i).meast  =     m(,1) * 100.0;
      rrr(i).mnorth =     m(,2) * 100.0;
      rrr(i).melevation=  m(,3) * 100.0;
      rrr(i).east   =     m(,4) * 100.0;
      rrr(i).north  =     m(,5) * 100.0;
      rrr(i).elevation =  m(,6) * 100.0;
      rrr(i).rn = (a(i).raster&0xffffff);
      rrr(i).intensity = a(i).intensity;
      rrr(i).fs_rtn_centroid = a(i).fs_rtn_centroid;
      rrr(i).rn += (indgen(120)*2^24);
      rrr(i).soe = a(i).soe;
      if(verbose && !(i % 100))
         write, format="%5d %8.1f %6.2f %6.2f %6.2f\n",
            i, (a(i).soe(60))%86400, palt(60,i), roll(60,i), pitch(60,i);
   }

   return rrr;
}

func pz(i, j, step=, xpause=) {
extern a, rrr
 rrr = array(R, j-i + 1);
 if ( is_void(step) ) 
   step = 1;
  dx = dy = dz = cyaw = gz = gx = gy = lasang = yaw = array(0.0, 120);
  mirang = array(-22.5, 120);
  lasang = array(45.0, 120);


animate,1
for ( ; i< j; i += step) { 
   gx = easting(, i);
   gy = northing(, i);
   yaw = -heading(, i);
   scan_ang = SAD * a(i).sa + ops_conf.scan_bias;
   srm = (a(i).irange*NS2MAIR - ops_conf.range_biasM);
   gz = palt(, i);
  m = scanflatmirror2_direct_vector(yaw,pitch(,i),roll(,i)+ ops_conf.roll_bias,
         gx,gy,gz,dx,dy,dz,cyaw, lasang, mirang, scan_ang, srm)
  
  rrr(i).east   =  m(,1);
  rrr(i).north  =  m(,2);
  rrr(i).elevation =  m(,3);


// Select returns based on range.  This will only work for water
// targets.
  q = where( m(,3) > -35.0 )
  qq = where( m(q,3 ) < -30.0 );
  ar = m(q(qq),3) (avg);
  if ( (i % 10 ) == 0 ) { 
    write,format="%5d %8.1f %6.2f %6.2f %6.2f %6.2f\n", 
         i, (a(i).soe(60))%86400, ar, palt(60,i), roll(60,i), pitch(60,i);
  }
  
  fma; plmk, m(,3), m(,1), color="black", msize=.15, marker=1; 
///////////  plg, m(q(qq),3), m(q(qq),1), marks=0, color="red";

// If there is more than one bottom trigger, draw a line between 
// the points.
  q = where( m(,3) > -50.0 )
  qq = where( m(q,3 ) < -37.0 );
/********
  if ( numberof(qq) > 1 ) 
     plg, m(q(qq),3), m(q(qq),1), marks=0, color="blue";
*******/

  if ( !is_void(xpause) ) 
	pause( xpause);
}
animate,0

}


func pe(i,j, step=) {
extern a
animate,1;  
 if ( is_void(step) ) 
   step = 1;
//    plmk, a(2,,i) * NS2MAIR, a.sa,msize=.1, marker=1; 
for ( ; i< j; i += step){ 
   fma; 
   croll = (SAD2 * a(i).sa ) + roll(, i) + ops_conf.roll_bias;
   rad_roll = roll * DEG2RAD; 
   cr = cos( rad_roll);
   srm = a(i).irange*NS2MAIR;
   hm = srm * cr * cos(pitch(,i)*DEG2RAD); //   - cr*0.11*srm(64);
   el = palt(, i) - hm;
   if ( hm(60) > 0 ) 
	nn = 60;
   else
	nn = 61
    
   
   xmeters = hm(nn) * tan( rad_roll );
   qq = where( xmeters > 200 );
   plmk,  el(64), xmeters(64),
        msize=.4, marker=1, color="blue";
   plmk, el , xmeters,msize=.1, marker=1, color="red"; 
   if ( (i % 100) == 0  )  {
      write,format="%d %6.1f %6.1f %4.2f\n", i, roll(60), tpr(60, i), palt(60, i);
   }
 }; animate,0

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
  extern edb, soe_day_start, tans, pnav, type, utm, fs_all, rn_arr_idx, rn_arr;
  fs_all = [];
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
