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




REV = 8000
range_bias = -6.0;
 scan_bias =  0.0;
 roll_bias = -1.45;
d2r = pi/180.0

struct R {
 int raster(120);	// contains raster # and pulse number in msb
 double mnorth(120);	// mirror northing
 double meast(120);	// mirror east
 double melevation(120);	// mirror elevation
 double north(120);
 double east(120);
 float  elevation(120);
};


func winsel(junk) {
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



func first_surface(i,j) {
 extern roll, pitch, heading, palt, utm, northing, easting
 extern a, rrr

 a = irg(i,j);		

// The line interpolating heading needs to be done using x/y from a 
// unit circle to work for norther headings.
atime   = a.soe - soe_day_start;
roll    =  interp( tans.roll,    tans.somd, atime ) 
pitch   = interp( tans.pitch,   tans.somd, atime ) 
heading = interp( tans.heading, tans.somd, atime ) 
palt  = interp( pnav.alt,   pnav.sod,  atime )
utm = fll2utm( pnav.lat, pnav.lon )
northing = interp( utm(1,), pnav.sod, atime )
easting  = interp( utm(2,), pnav.sod, atime )

  sz = j - i + 1;
 rrr = array(R, sz);
 if ( is_void(step) ) 
   step = 1;
  dx = dy = dz = cyaw = gz = gx = gy = lasang = yaw = array(0.0, 120);
  mirang = array(-22.5, 120);
  lasang = array(45.0, 120);

 for ( i=1; i< sz; i += step) { 
   gx = easting(, i);
   gy = northing(, i);
   yaw = -heading(, i);
   scan_ang = (360.0/8000.0)  * a(i).sa + scan_bias;
   srm = (a(i).irange*NS2MAIR - range_bias);
   gz = palt(, i);
  m = scanflatmirror2_direct_vector(yaw,pitch(,i),roll(,i)+roll_bias,
         gx,gy,gz,dx,dy,dz,cyaw, lasang, mirang, scan_ang, srm)
  
  rrr(i).meast  =  m(,1);
  rrr(i).mnorth =  m(,2);
  rrr(i).melevation=  m(,3);
  rrr(i).east   =  m(,4);
  rrr(i).north  =  m(,5);
  rrr(i).elevation =  m(,6);
  rrr(i).raster = (a(i).raster&0xffffff);
  rrr(i).raster += (indgen(120)*2^24);
  if ( (i % 100 ) == 0 ) { 
    write,format="%5d %8.1f %6.2f %6.2f %6.2f\n", 
         i, (a(i).soe(60))%86400, palt(60,i), roll(60,i), pitch(60,i);
  }
 }
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

