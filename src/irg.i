/*
   $Id$
   W. Wright

   8/23/02 WW Minor additions to irg to permit giving an initial
        raster number and an increment instead of a start and stop.

   8/17/02 WW
	Added XRTRS data type to return range data and
        interpolated attitude and altitude info.

   7/6/02 WW
	Minor changes to omit progress bar when fewer then 10
	rasters to process.



 test...
*/

require, "eaarl_constants.i"
require, "edb_access.i"
require, "centroid-1.i"

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

Though the "irange" value comes from the system as an integer, it 
is converted and stored in RTRS as a floating point value.  In this
way it can be refined to better than the one-ns resolution by 
processing methods. By carying it as a float, we don't have to scale
it.


 ---------end-----------
*/
  struct RTRS { 
     int    raster;		// the raster number;
     double    soe(120); 	// Seconds of the epoch for each pulse.
     float    irange(120); 	// integer range counter values.
     short  intensity(120);	// Laser return intensity
     short      sa(120); 	// scan angle counts.
     short  fs_rtn_centroid(120); // The location within the return waveform of the
                                  // first return centroid.  This is to used to subtract
                                  // from the depth idx to get true depth.
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
     double    soe(120); 	// Seconds of the epoch for each pulse.
     float    irange(120); 	// integer range counter values.
     short  intensity(120);	// Laser return intensity
     short      sa(120); 	// scan angle counts.
     float   rroll(120);	// Roll in radians
     float  rpitch(120);	// Pitch in radians
     float     alt(120);	// altitude in either NS or meters.
     short  fs_rtn_centroid(120); // The location within the return waveform of the
                                  // first return centroid.  This is to used to subtract
                                  // from the depth idx to get true depth.
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




func irg( b, e, inc=, delta=, georef=, usecentroid=, use_highelv_echo= ) {
/* DOCUMENT irg(b, e, georef=) 
   Returns an array of irange values from record
   b to record e.  "e" can be left out and it will default to 1.  Don't
   include e if you supply inc=.

   inc=         NN      Returns "inc" records beginning with b.
    delta=      NN      Generate records from b-delta to b+delta.
   georef=	<null> 	Return RTRS records like normal.
		1       Return XRTRS records.
  usecentroid=  1	Set to determine centroid range using 
                        all 3 waveforms to correct for range walk.
  use_highelv_echo =    Set to 1 to exclude  the waveforms that tripped above
			the range gate and its echo caused a peak in the 
			positive direction higher than the bias.
   Returns an array of RTRS structures, or an array of XRTRS.

*/

  if ( !is_void( delta ) ) {
     e = b + delta;
     b = b - delta;
  }

  if ( !is_void( inc ) ) {
     e = b + inc;
  } 

  if ( is_void(e) ) 
	e = b + 1;

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
    if ( usecentroid == 1 ) {
       for (ii=1; ii< rp.npixels(1); ii++ ) {
	  if (use_highelv_echo) {
	    if (int((*rp.rx(ii,1))(max)-min((*rp.rx(ii,1))(1),(*rp.rx(ii,1))(0))) < 5) {
              centroid_values     = pcr(rp, ii);
              if ( numberof(centroid_values) ) {
	        a(di).irange(ii)    = centroid_values(1);
	        a(di).intensity(ii) = centroid_values(2);
	        a(di).fs_rtn_centroid(ii) = centroid_values(4);
              }
	    }
 	  } else {
            centroid_values     = pcr(rp, ii);
            if ( numberof(centroid_values) ) {
	      a(di).irange(ii)    = centroid_values(1);
	      a(di).intensity(ii) = centroid_values(2);
	      a(di).fs_rtn_centroid(ii) = centroid_values(4);
            }
         }
            
       }
    } else if ( usecentroid == 2 ) {	//  This area is for the Leading-edge-tracker stuff
	for (ii=1; ii< rp.npixels(1); ii++ ) {
           centroid_values     = let(rp, ii);
	   a(di).irange(ii)    = centroid_values(1);
	   a(di).intensity(ii) = centroid_values(2);
        }
    } else {	// This section processes basic irange
      a(di).irange = rp.irange;
/****************
      for ( ii=1; ii< rp.npixels(1); ii++ ) { 
       ta = -float(*rp.tx(ii));
       x = indgen(1:numberof(ta))-1;
       txb = ta(1:3)(avg);
       ta -= txb;
       tas = ta(sum);
       if ( tas ) {
          tc = (ta * x )(sum) / tas;
          a(di).irange(ii) -= tc; 
       }
         
       if ( numberof( (*rp.rx(ii,1) )) >= 8 ) {
         bias = (*rp.rx(ii,1) )(1:5)(avg);
	 w = -((*rp.rx(ii,1) )(6:8) -bias);
         if ( w(1) > 0 )
           a(di).intensity(ii) = w(3) - w(1); //   
        }
      }
****************/
    }
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



