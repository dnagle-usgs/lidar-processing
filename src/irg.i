/*
   $Id$
*/

require, "eaarl_constants.i"
require, "edb_access.i"



// RTRS = Raster/Time/Range/ScanAngle
  struct RTRS { 
     int    raster;		// the raster number;
     double soe(120); 		// Seconds of the epoch for each pulse.
     short  irange(120); 	// integer range counter values.
     short  sa(120); 		// scan angle counts.
  };

func irg( b, e ) {
/* DOCUMENT irg(b, e) 
   Returns an array of irange values from record
   b to record e.

   Returns an array of RTRS structures.

*/

  len = e - b;
  a = array( RTRS,  len + 1 );

  if ( _ytk ) {
    tkcmd,"destroy .irg; toplevel .irg; set progress 0;"
    tkcmd,swrite(format="ProgressBar .irg.pb \
	-fg green \
	-troughcolor red \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", len );
    tkcmd,"pack .irg.pb; update; center_win .irg;"
  }
  for ( di=1, si=b; si<=e; di++, si++ ) {
    rp = decode_raster( get_erast( rn=si )) ;
    a(di).raster = si; 
    a(di).soe = rp.offset_time ;
    a(di).irange = rp.irange;
    a(di).sa  = rp.sa;
   if ( (di % 10) == 0  )
    if ( _ytk ) {
      tkcmd,swrite(format="set progress %d", di)
    } else 
       write,format="  %d/%d     \r", di, len
  }
  if ( _ytk ) 
    tkcmd,"destroy .irg";

  return a;
}



