/*
   $Id$
*/

require, "eaarl_constants.i"
require, "edb_access.i"
require, "rbpnav.i"
require, "rbtans.i"
require, "scanflatmirror2_direct_vector.i"
require, "plcm.i"
require, "ll2utm.i"

/*
   the a array has the data.

   a(1,,)  is seconds
   a(2,,)  range in meters ( 1ns lsb )
   a(3,,)  scan angle  (degrees)
      
   a(, s, )    s =  ranges from 1 to 120 and is the pulse position in the scan
   a(,  ,r)    r =  rasta numba 


*/



func load {
fn = rdline(prompt="Enter file: ");
fn
f = openb(fn);
show,f
write,"Reading the data in......"
restore,f
write,"Data load complete"
close,f
write,"Type  pe( b, e)   to see some waveforms. \n Set b to the start, and e to the end record numbers"
}


/* 


// check for time roll-over, and correct it
  q = where( pn.sod(dif) < 0 );
  if ( numberof(q) ) {
    rng = q(1)+1:dimsof(pn.sod)(2);
    pn.sod(rng) += 86400;
  }

// convert tans time to sod, then check/correct for rollover
  tans(1,) = tans(1,)%86400; 
  q = where( tans(1, ) < 0 );
  if ( numberof(q) ) {
    rng = q(1)+1:dimsof(tans(1,) )(2);
    tans(1,) += 86400;
  }
 
  


) #include "rbtans.i"	// for Tans-Vector attitude data
) #include "rbpnav.i"	// for B.J.'s trajectory
) Correct for 13 second difference and 4 hours from GMT
  tr = interp( tans.roll, tans.sod%86400-13.0,  a.soe%86400-4*3600 );
 tpr = interp( tans.pitch, tans.sod%86400-13.0,  a.soe%86400-4*3600 );
/////////////  tr = interp( tans(2,), tans(1,)%86400-13.0,  a.soe%86400-4*3600 );
////////  tpr = interp( tans(3,), tans(1,)%86400-13.0,  a.soe%86400-4*3600 );
palt = interp( pn.alt, pn.sod-13, a.soe%86400-4*3600 );

// Convert lat/lon to utm for projection to surface
utm = fll2utm( pn.lat, pn.lon ) 
northing = interp( utm(1,), pn.sod-13, a.soe%86400-4*3600 );
easting = interp( utm(2,), pn.sod-13, a.soe%86400-4*3600 );
theading = interp( tans.heading, tans.sod%86400-13.0,  a.soe%86400-4*3600 + 86400 );



*/


REV = 8000
///////// window,0
////// limits,-175,175,-20,20
write,"Type    load   to load the data"

range_bias = -6.0;
 scan_bias =  0.0;
 roll_bias = -1.45;
d2r = pi/180.0

struct R {
 double north(120);
 double east(120);
 float  elevation(120);
};

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
   yaw = -theading(, i);
   scan_ang = (360.0/8000.0)  * a(i).sa + scan_bias;
   srm = (a(i).irange*NS2MAIR - range_bias);
   gz = palt(, i);
  m = scanflatmirror2_direct_vector(yaw,tpr(,i),tr(,i)+roll_bias,
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
         i, (a(i).soe(60)-4*3600)%86400, ar, palt(60,i), tr(60,i), tpr(60,i);
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
   roll = ((720.0/8000) * a(i).sa ) + tr(, i) + roll_bias;
   rad_roll = roll * d2r; 
   cr = cos( rad_roll);
   srm = a(i).irange*NS2MAIR;
   hm = srm * cr * cos(tpr(,i)*d2r); //   - cr*0.11*srm(64);
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

