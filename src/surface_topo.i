/*
   $Id$
*/

write,"$Id$"

require, "eaarl_constants.i"
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
  short sa(120);
}


*/




REV = 8000;		// Counts for 360 degrees of scan angle
range_bias  = -6.0;	// Laser range measurement bias.
 scan_bias  =  0.0;	// The mounting bias of the scan encoder.
 roll_bias  = -1.45;	// The mounting bias of the instrument in the plane.
 pitch_bias = -0.5;	// pitch mounting bias
 yaw_bias   =  0.0;	// Yaw mounting bias

d2r = pi/180.0;		// Convert degrees to radians.

/*
   Structure used to hold laser return vector information. All the 
 values are in air-centimeters. 
*/
struct R {
 long raster(120);	 // contains raster # and pulse number in msb
 long mnorth(120);	 // mirror northing
 long meast(120);	 // mirror east
 long melevation(120);   // mirror elevation
 long north(120);	 // mirror north
 long east(120);	 // mirror east
 long elevation(120);  // mirror elevation (m)
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


func display(rrr, i=,j=, cmin=, cmax=, size=, win=, dofma= ) {
/* DOCUMENT display, i, j, cmin=, cmax=, size=
 
   Display EAARL laser samples.
   rrr		type "R" data array.
   i            Starting point.
   j            Stopping point.
   cmin=        Deepest point in meters ( -35 default )
   cmax=        Highest point in meters ( -15 )
   size=        Screen size of each point. Fiddle with this
                to get the filling-in like you want.
 
*/

 if ( is_void(win) )
	win = 5;

 if ( is_void(i) ) 
	i = 1;
 if ( is_void(j) ) 
	j = dimsof(rrr)(2);
 window,win 
 if ( !is_void( dofma ) )
	fma;

write,format="Please wait while drawing..........%s", "\r"
 if ( is_void( cmin )) cmin = -35.0;
 if ( is_void( cmax )) cmax = -15.0;
 if ( is_void( size )) size = 1.4;
for ( ; i<j; i++ ) {
  plcm, rrr(i).elevation, rrr(i).north, rrr(i).east,
      msize=size,cmin=cmin, cmax=cmax
  }
write,format="Draw complete. %d rasters drawn. %s", j-i, "\n"
}


func mdist {
/* DOCUMENT mdist
   
  Use the mouse to measure a distance, in meters, on a UTM
data plot.

*/
   cc = mouse(,2,"Click and dragout a distance to measure:");
    dx = cc(3) - cc(1);
    dy = cc(4) - cc(2);
  dist = sqrt( dx^2 + dy^2);
  if ( dist > 1000.0 )
    write,format="Distance is %5.3f kilometers\n", dist/1000.0;
  else
    write,format="Distance is %5.3f meters\n", dist;
}




func first_surface(start=, stop=, center=, delta=) {
/* DOCUMENT first_surface,i,j

   Project the EAARL threshold trigger point to the surface. Start with
 raster "i" and stop at "j."  This returns an array of type "R" which
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
 extern a

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

 a = irg(i,j);		

// The line interpolating heading needs to be done using x/y from a 
// unit circle to work for norther headings.
atime   = a.soe - soe_day_start;

write,"interpolating roll..."
roll    =  interp( tans.roll,    tans.somd, atime ) 
write,"interpolating pitch..."
pitch   = interp( tans.pitch,   tans.somd, atime ) 
write,"interpolating heading..."
heading = interp( tans.heading, tans.somd, atime ) 
write,"interpolating altitude..."
palt  = interp( pnav.alt,   pnav.sod,  atime )
write,"Converting from lat/lon to UTM..."
utm = fll2utm( pnav.lat, pnav.lon )
write,"Interpolating northing and easting values..."
northing = interp( utm(1,), pnav.sod, atime )
easting  = interp( utm(2,), pnav.sod, atime )

  sz = j - i + 1;
 rrr = array(R, sz);
 if ( is_void(step) ) 
   step = 1;
  dx = cyaw = gz = gx = gy = lasang = yaw = array(0.0, 120);
  dy = array( 2.0, 120);	// mirror offset along fuselage
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
 el = ( a(i).irange & 0xc000 ) == 0 ;
 a(i).irange *= el;

   srm = (a(i).irange*NS2MAIR - range_bias);
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
  rrr(i).raster = (a(i).raster&0xffffff);
  rrr(i).raster += (indgen(120)*2^24);
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
   srm = (a(i).irange*NS2MAIR - range_bias);
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

