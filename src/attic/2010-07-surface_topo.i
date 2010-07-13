
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
