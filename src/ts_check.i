


/*
   $Id$

  W. Wright

  ts_check.i 

  Functions to verify that the lidar time is in sync with the
  GPS time.

*/


require, "irg.i"
require, "edb_access.i"
require, "rbgga.i"

// load_edb
// gga = rbgga();

irg_t = 0;

func irg_replot ( temp_time_offset=, range_offset= ) {
 extern irg_t
  if ( is_void( range_offset) ) 
	range_offset = 0;

  if ( is_void( temp_time_offset ) ) 
	temp_time_offset = eaarl_time_offset;

  irg_t  = (rtrs.soe - soe_day_start ) + temp_time_offset;
 
  window,7; fma;
  plg,gga.alt, gga.sod, marks=0 
  plmk, rtrs.irange(60,)*NS2MAIR + range_offset, irg_t(60,),msize=.05, color="red"
  xytitles, "Seconds of the Mission Day", "Altitude (Meters)"
  pltitle,data_path
  write,"irg_replot_complete"
}





