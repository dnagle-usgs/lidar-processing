/*
   $Id$
   W. Wright


   8/17/02 WW
	Added XRTRS data type to return range data and
        interpolated attitude and altitude info.

   7/6/02 WW
	Minor changes to omit progress bar when fewer then 10
	rasters to process.
*/

require, "eaarl_constants.i"
require, "edb_access.i"

write,"$Id$"


// RTRS = Raster/Time/Range/ScanAngle
/* DOCUMENT RTRS

  RTRS means: Raster/Time/Range/ScanAngle.  The structure contains
information on a given raster including the raster number, an array
of soe's (start of epoch) time values for each pulse in the raster,
the irange (integer range) which is the non-range-walk corrected basic
range measurement returned by the EAARL data system, and the sa (scan
angle) in digital counts.  The sa contains digital counts based on
8000 counts for one 360 degree revolution.
 When using sa, remember that the angle the laser is deflected is 
 twice the angle of incidence, so effectively you should use 4000
counts/revolution.


 ---------end-----------
*/
  struct RTRS { 
     int    raster;		// the raster number;
     double soe(120); 		// Seconds of the epoch for each pulse.
     short  irange(120); 	// integer range counter values.
     short  sa(120); 		// scan angle counts.
  };

local XRTRS
/* DOCUMENT XRTRS
  XRTRS = Extended RTRS to hold info for qde georef.  The additional
  information is radian roll, pitch, and precision altitude in meters.

  See also:  info, XRTRS

  -----end----------------
*/


  struct XRTRS {
     int    raster;		// the raster number;
     double soe(120); 		// Seconds of the epoch for each pulse.
     short  irange(120); 	// integer range counter values.
     short  sa(120); 		// scan angle counts.
     float  rroll(120);		// Roll in radians
     float  rpitch(120);	// Pitch in radians
     float  alt(120);		// altitude in either NS or meters.
}

func open_irg_status_bar {
  if ( use_ytk ) {
    tkcmd,"destroy .irg; toplevel .irg; set progress 0;"
    tkcmd,swrite(format="ProgressBar .irg.pb \
	-fg green \
	-troughcolor red \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", len );
    tkcmd,"pack .irg.pb; update;" 
    tkcmd,"center_win .irg;"
  }
}




func irg( b, e, georef= ) {
/* DOCUMENT irg(b, e, georef=) 
   Returns an array of irange values from record
   b to record e.

   georef=	<null> 	Return RTRS records like normal.
		1       Return XRTRS records.

   Returns an array of RTRS structures, or an array of XRTRS.

*/

  len = e - b;				// Compute the length of the return
					// data.
  if ( is_void(georef) )		// if no georef, then return RTRS
  	a = array( RTRS,  len + 1 );
  else					// else return an extended XRTRS
  	a = array( XRTRS,  len + 1 );	//   with georef information included.


  if ( _ytk && ( len > 10 ) )		// Determine if ytk popup status
	use_ytk = 1;			// dialogs are used.
  else
	use_ytk = 0;

  open_irg_status_bar;

  for ( di=1, si=b; si<=e; di++, si++ ) {
    rp = decode_raster( get_erast( rn=si )) ;	// decode a raster
    a(di).raster = si; 				// install the raster nbr
    a(di).soe = rp.offset_time ;		
    a(di).irange = rp.irange;
    a(di).sa  = rp.sa;
    if ( (di % 10) == 0  )
      if ( use_ytk ) {
        tkcmd,swrite(format="set progress %d", di)
      } else 
        write,format="  %d/%d     \r", di, len
  }
  if ( !is_void(georef) ) {
    atime = a.soe - soe_day_start;
    a.rroll = interp( tans.roll*d2r,    tans.somd, atime );
    a.rpitch= interp( tans.pitch*d2r,   tans.somd, atime );
    a.alt   = interp( pnav.alt,   pnav.sod,  atime );
  }
  if ( use_ytk ) 
    tkcmd,"destroy .irg";

  return a;
}



