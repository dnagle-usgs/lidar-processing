/*
   $Id$


   W. Wright

   7/7/02 WW
	Added north= to first_surface. 
   
*/

write,"$Id$"

require, "eaarl_constants.i"
require, "eaarl_mounting_bias.i"
require, "edb_access.i"
require, "rbpnav.i"
require, "rbtans.i"
require, "scanflatmirror2_direct_vector.i"
require, "plcm.i"
require, "ll2utm.i"
require, "irg.i"

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

 
struct R {
 long rn(120);       // contains raster # and pulse number in msb
 long mnorth(120);       // mirror northing
 long meast(120);        // mirror east
 long melevation(120);   // mirror elevation
 long north(120);        // surface north
 long east(120);         // surface east
 long elevation(120);    // surface elevation (m)
 short intensity(120);	 // surface return intensity
 double soe(120);
};


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




func display(rrr, i=,j=, mode=, cmin=, cmax=, size=, win=, dofma=, edt=, marker=, skip= ) {
/* DOCUMENT display(rrr, i=,j=, cmin=, cmax=, size=, win=, dofma=, edt=, marker= )

 
   Display EAARL laser samples.
   rrr		type "R" data array.
   i            Starting point.
   j            Stopping point.
   mode=	"elev"       elevation
                "intensity"  intensity
   cmin=        Deepest point in centimeters ( -3500 default )
   cmax=        Highest point in centimeters ( -1500 )
   size=        Screen size of each point. Fiddle with this
                to get the filling-in like you want.
   edt=		1 to plot only good data. Don't include this
                if you want un-edited data.
   marker=      Use a particular marker shape for each pixel.
   msize        Set the size for each pixel in ndc coords.

  The rrr northing and easting values are divided by 100 so the scales
 are in meters instead of centimeters.  The elevation remains in centimeters.
 
 
*/
 if ( is_void(mode) )
	mode = "elev";

 if ( is_void(win) )
	win = 5;

 if ( is_void(i) ) 
	i = 1;
 if ( is_void(j) ) 
	j = dimsof(rrr)(2);
 window,win 
 if ( !is_void( dofma ) )
	fma;
 if (is_void(skip)) skip = 1;


write,format="Please wait while drawing..........%s", "\r"
 if ( is_void( cmin )) cmin = -3500;
 if ( is_void( cmax )) cmax = -1500;
 if ( is_void( size )) size = 1.4;
 ii = i;
 /*
 if ( !is_void(edt) ) {
   ea = rrr.elevation;
   ea = ( (ea >= cmin) & ( ea <= cmax ) );
 } else {
   ea = rrr.elevation;
   ea = (ea != 0 );
 }
 */
for ( ; i<=j; i++ ) {
 if ( !is_void(edt) ) {
   //ea = rrr(i).elevation;
   //q = where((ea >= cmin) & (ea <= cmax) & (rrr(i).north != 0))
   q = where(rrr(i).north);
   //q = where( (ea(,i)) &  (rrr(i).north) );
 } else {
   q = where( (rrr(i).elevation) & (rrr(i).north) );
 }
  if ( numberof(q) >= 1) {
     if ( mode == "elev" ) { 
       plcm, [rrr(i).elevation(q)](1:0:skip), ([rrr(i).north(q)](1:0:skip))/100.0, ([rrr(i).east(q)](1:0:skip))/100.0,
       msize=size,cmin=cmin, cmax=cmax, marker=marker
     } else if ( mode == "intensity" ) {
       plcm, rrr(i).intensity(q), (rrr(i).north(q)(1:0:skip))/100.0, (rrr(i).east(q)(1:0:skip))/100.0,
       msize=size,cmin=cmin, cmax=cmax, marker=marker
     }
   }
  }
write,format="Draw complete. %d rasters drawn. %s", j-ii, "\n"
}





func first_surface(start=, stop=, center=, delta=, north=, usecentroid=, use_highelv_echo=) {
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

*/
 extern roll, pitch, heading, palt, utm, northing, easting
 extern a, _utm

 if ( !is_void( center ) ) {
    if ( is_void(delta) ) 
	delta = 100;
    i = center - delta;
    j = center + delta;
 } else if ( !is_void( start ) ) {
          if ( !is_void( delta ) ) {
    i = start;
    j = start + delta;
   } else if ( !is_void( stop ) ) {
    i = start;
    j = stop;
   }
 } 

 a = irg(i,j, usecentroid=usecentroid, use_highelv_echo=use_highelv_echo);		

atime   = a.soe - soe_day_start;

write, format="\n%cInterpolating: roll...", 0x20
roll    =  interp( tans.roll,    tans.somd, atime ) 

write,format="%cpitch...",0x20
pitch   = interp( tans.pitch,   tans.somd, atime ) 

if ( is_void( north ) ) {
 write,format="%cheading...", 0x20
 hy = interp( sin( tans.heading*deg2rad), tans.somd, atime );
 hx = interp( cos( tans.heading*deg2rad), tans.somd, atime );
 heading = atan( hy, hx)/deg2rad;
} else {
 write,"interpolating North only..."
 heading = interp( array( 0.0, dimsof(tans)(2) ), tans.somd, atime ) 

}

write,format="%caltitude...",0x20
palt  = interp( pnav.alt,   pnav.sod,  atime )

if ( is_void( _utm ) ) {
   write,"Converting from lat/lon to UTM..."
   _utm = fll2utm( pnav.lat, pnav.lon )
} else {
  if ( dimsof(pnav)(2) != dimsof(pnav)(2) ) 
   write,"_utm has changed, re-converting from lat/lon to UTM..."
   _utm = fll2utm( pnav.lat, pnav.lon )
}

write,format="%cnorthing/easting...\n", 0x20
northing = interp( _utm(1,), pnav.sod, atime )
easting  = interp( _utm(2,), pnav.sod, atime )

  sz = j - i + 1;
 rrr = array(R, sz);
 if ( is_void(step) ) 
   step = 1;
  dx = cyaw = gz = gx = gy = lasang = yaw = array(0.0, 120);
  dy = array( -2.0, 120);	// mirror offset along fuselage
  dz = array(-1.3, 120);	// vertical mirror offset 
  mirang = array(-22.5, 120);
  lasang = array(45.0, 120);

write,"Projecting to the surface..."
 for ( i=1; i< sz; i += step) { 
   gx = easting(, i);
   gy = northing(, i);
   yaw = -heading(, i);
   scan_ang = (360.0/8000.0)  * a(i).sa + scan_bias;

// edit out tx/rx dropouts
 el = ( int(a(i).irange) & 0xc000 ) == 0 ;
 a(i).irange *= el;

   srm = (a(i).irange*NS2MAIR - range_biasM);
   gz = palt(, i);
  m = scanflatmirror2_direct_vector(yaw+yaw_bias,
	pitch(,i)+pitch_bias,roll(,i)+roll_bias,
         gx,gy,gz,dx,dy,dz,cyaw, lasang, mirang, scan_ang, srm)
  
  rrr(i).meast  =     m(,1) * 100.0;
  rrr(i).mnorth =     m(,2) * 100.0;
  rrr(i).melevation=  m(,3) * 100.0;
  rrr(i).east   =     m(,4) * 100.0;
  rrr(i).north  =     m(,5) * 100.0;
  rrr(i).elevation =  m(,6) * 100.0;
  rrr(i).rn = (a(i).raster&0xffffff);
  rrr(i).intensity = a(i).intensity;
  rrr(i).rn += (indgen(120)*2^24);
  rrr(i).soe = a(i).soe;
  if ( (i % 100 ) == 0 ) { 
    write,format="%5d %8.1f %6.2f %6.2f %6.2f\n", 
         i, (a(i).soe(60))%86400, palt(60,i), roll(60,i), pitch(60,i);
  }
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
   scan_ang = (360.0/8000.0)  * a(i).sa + scan_bias;
   srm = (a(i).irange*NS2MAIR - range_biasM);
   gz = palt(, i);
  m = scanflatmirror2_direct_vector(yaw,pitch(,i),roll(,i)+roll_bias,
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
   croll = ((720.0/8000) * a(i).sa ) + roll(, i) + roll_bias;
   rad_roll = roll * d2r; 
   cr = cos( rad_roll);
   srm = a(i).irange*NS2MAIR;
   hm = srm * cr * cos(pitch(,i)*d2r); //   - cr*0.11*srm(64);
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

func make_fs(latutm=, q=, ext_bad_att=, usecentroid=) {
  /* DOCUMENT make_fs(latutm=, q=, ext_bad_att=)
     This function prepares data to write/plot first surface topography 
     for a selected region of flightlines.
     amar nayegandhi 09/18/02
  */
  extern edb, soe_day_start, tans, pnav, type, utm, fs_all, rn_arr_idx, rn_arr;
  fs_all = [];
  rn_arr =[];
   if (!is_array(tans)) {
     write, "TANS information not loaded.  Running function rbtans() ... \n";
     tans = rbtans();
     write, "\n";
   }
   write, "TANS information LOADED. \n";
   if (!is_array(pnav)) {
     write, "Precision Navigation (PNAV) data not loaded."+ 
            "Running function rbpnav() ... \n";
     pnav = rbpnav();
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

   for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
       fcount ++;
       write, format="Processing segment %d of %d for first_surface...\n",i,no_t;
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=usecentroid); 
       //a=[];
       grow, fs_all, rrr;
       tot_count += numberof(rrr.elevation);
      }
    }

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
    write, format="Total number of records processed = %d\n",tot_count;
    write, format="Total number of records with false first "+
                   "returns data = %d\n",ba_count;
    write, format="Total number of GOOD data points = %d \n",
                   (tot_count-ba_count);

    if ( tot_count != 0 ) {
       pba = float(ba_count)*100.0/tot_count;
       write, format = "%5.2f%% of the total records had "+
                       "false first returns! \n",pba;
    } else 
	write, "No good returns found"

    no_append = 0;

// Compute a list of indices into each flight segment from rn_arr.
// This information can be used to selectively plot each selected segment
// along, or only a specfic group of selected segments.
    rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);	

write,"fs_all contains the data, and rn_arr_idx contains a list of indices"
tkcmd, swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))


    return fs_all;
 } else write, "No good returns found"

}

func hist_fs( fs_all, binsize=, win=, dofma=, color=, normalize=, lst=, width= ) {
/* DOCUMENT hist_fs(fs)

   Return the histogram of the good elevations in fs.  The input fs elevation
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs: 
	fs_all		An array of "R" structures.  
	binsize=	Binsize in centimeters from 1.0 to 200.0  
	win=		Defaults to 0.
	dofma=		Defaults to 1 (Yes), Set to zero if you don't want an fma.
	color=		Set graph color
	width=		Set line width
	normalize=	Defaults to 0 (not normalized),  Set to 1  to cause it to normalize
                        to one.  This is very useful in case you are plotting multiple 
                        histograms where you actually want to compare their peak value.
        lst=            An optional externally generated "where" filter list.
	

  Outputs:
	A histogram graphic in Window 0

  Returns:
	An 2xn array of x values and counts found at those values.

 Orginal: W. Wright 9/29/2002

See also: R
*/

  if ( is_void(binsize))
	binsize = 100.0;

  if ( is_void(win) ) 
	win = 0;

  if ( is_void(lst)) 
     lst = where(fs_all.elevation);

  elev = fs_all.elevation(lst);
 melev = fs_all.melevation(lst);
// build an edit array indicating where values are between -60 meters
// and 3000 meters.  Thats enough to encompass any EAARL data than
// can ever be taken.
  gidx = (elev > -6000) | (elev <300000);  

// Now kick out values which are within 1-meter of the mirror. Some
// functions will set the elevation to the mirror value if they cant
// process it.
  gidx &= (elev < (melev-1));


// Now generate a list of where the good values are.
  q = where( gidx )
  

// now find the minimum 
minn = elev(q)(min);
maxx = elev(q)(max);

 fsy = elev(q) - minn ;
// minn /= binsize;
// maxx /= binsize;

  minn /= 100.0
  maxx /= 100.0


// make a histogram of the data indexed by q.
  h = histogram( (fsy / int(binsize)) + 1 );
  zero_list = where( h == 0 ) 
  if ( numberof(h) < 2 ) {
    h = [1,h(1),1];   
  }
  if ( numberof(zero_list) )
  	h( zero_list ) = 1;
  e = span( minn, maxx, numberof(h) )  ; 
  w = window();
  window,win; 
  if ( dofma ) 
  	fma; 
  if ( normalize ) {
	h = float(h);
	h = h/(h(max));
   }
  plg,h,e, color=color, width=width;
  pltitle(swrite( format="Elevation Histogram %s", data_path));
  xytitles,"Elevation (meters)", "Number of measurements"
  //limits
  hst = [e,h];
  window, win; limits,,,,hst(max,2) * 1.5
  window(w);
  return hst;
}

func write_topo(opath, ofname, fs_all, type=) {

//this function writes a binary file containing georeferenced topo data.
// amar nayegandhi 03/29/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

nwpr = long(9);

if (is_void(type)) {
   if (fs_all.soe(1) == 0) {
      type = 3;
      nwpr = long(8);
   } else {
      type = 101;
   }
}

rec = array(long, 4);
/* the first word in the file will define the endian system. */
rec(1) = 0x0000ffff;
/* the second word defines the type of output file */
rec(2) = type;
/* the third word defines the number of words in each record */
rec(3) = nwpr;
/* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
rec(4) = 0;

a = structof(fs_all);
_write, f, 0, rec;

write, format="Writing first surface data of type %d\n",type

byt_pos = 16; /* 4bytes , 4words  for header position*/
num_rec = 0;


/* now look through the geodepth array of structures and write out only valid points */
len = numberof(fs_all);

for (i=1;i<len;i++) {
  indx = where(fs_all(i).north !=  0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     //if (a == R) {
     _write, f, byt_pos, fs_all(i).rn(indx(j));
     //} else {
     //_write, f, byt_pos, fs_all(i).rn(indx(j));
     //}
     
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).mnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).meast(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).melevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).intensity(indx(j));
     byt_pos = byt_pos + 2;
     if (type = 101) {
       _write, f, byt_pos, fs_all(i).soe(indx(j));
       byt_pos = byt_pos + 8;
     }
     if ((i%1000)==0) write, format="%d of %d\r", i, len;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}

func  r_to_fs(data) {
/*DOCUMENT r_to_fs(data)
    this function converts the data array from the raster structure R to the point structure FS for surface topography.
    amar nayegandhi
    03/08/03.
*/
 if (numberof(data) != numberof(data.north)) {
	data_new = array(FS, numberof(data)*120);
        indx = where(data.rn >= 0);
        data_new.rn = data.rn(indx);
        data_new.north = data.north(indx);
        data_new.east = data.east(indx);
        data_new.elevation = data.elevation(indx);
        data_new.mnorth = data.mnorth(indx);
        data_new.meast = data.meast(indx);
        data_new.melevation = data.melevation(indx);
        data_new.intensity = data.intensity(indx);
        data_new.soe = data.soe(indx);
  } else data_new = data;
  return data_new
}

func clean_fs(fs_all, rcf_width=) {
  /* DOCUMENT clean_fs(fs_all, rcf_width=)
   this function cleans the fs_all array
   amar nayegandhi 08/03/03
   Input: fs_all	: Initial data array of structure R or FS
          rcf_width	: The elevation width (m) to be used for the RCF filter.  If not set, rcf is not used.
   Output: Cleaned data array of type FS
  */

  if (numberof(fs_all) != numberof(fs_all.north)) {
      // convert R to FS
      write, "converting raster structure (R) to point structure (FS)";
      fs_all = r_to_fs(fs_all);
  }
  
  write, "cleaning data...";


  // remove pts that had north values assigned to 0
  indx = where(fs_all.north != 0);
  if (is_array(indx)) {
     fs_all = fs_all(indx);
  } else {
      fs_all = [];
      return fs_all
  }


  // remove points that have been assigned mirror elevation values
  indx = where(fs_all.elevation < (0.75*fs_all.melevation))
  if (is_array(indx)) {
    fs_all = fs_all(indx);
  } else {
    fs_all = [];
    return fs_all
  }

  if (is_array(rcf_width)) {
    write, "using rcf filter to clean fs data..."
    //run rcf on the entire data set
    ptr = rcf(fs_all.elevation, rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
        fs_all = fs_all(*ptr(1));
    } else {
        fs_all = [];
    }
  }


  return fs_all
}
