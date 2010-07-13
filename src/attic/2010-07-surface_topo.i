/******************************************************************************\
* This file was created in the attic on 2010-07-13. It contains obsolete       *
* functions from the file surface_topo.i that are no longer in use. The        *
* functions are:                                                               *
*     winsel                                                                   *
*     make_pnav_from_gga                                                       *
*     pz                                                                       *
* Each function has comments below detailing the alternative functionality     *
* that is currently available that supercedes it, as applicable.               *
\******************************************************************************/

/*
   The functionality of 'winsel' is provided and expanded upon by
   'sel_data_rgn' from data_rgn_selector.i.
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

/*
   The functionality of 'make_pnav_from_gga' can be reproduced by using
   'struct_cast' in eaarl_data.i:
      pnav = struct_cast(gga, PNAV)
*/

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

/*
   Function 'pz' is undocumented and is not in use in any place within our code.
*/

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
