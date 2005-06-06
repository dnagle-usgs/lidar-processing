
/*
    $Id$

  Place to collect all yorick .i files that eaarl needs.

*/

write,"$Id$"
require, "eaarl_constants.i"
require, "eaarl_mounting_bias.i"
require, "load_cmd.i"
require, "rbgga.i"
require, "edb_access.i"
require, "rbtans.i"
require, "rbpnav.i"
require, "nav.i"
require, "map.i"
require, "waves.i"
require, "gridr.i"
require, "dmars.i"
require, "batch_process.i"
require, "transect.i"
require, "large_window.i"
if(!is_void(plug_in)) {
	require, "triangle.i";
	require, "rcf_triangulate.i";
	require, "rcf_utils.i";
}

/* DOCUMENT CBAR
 The color bar values from l1pro.ytk
 can be send to cbar by executing tkcmd, "ycbar"
 from within a yorick program.
*/
struct CBAR { float cmax; float cmin; float cdelta; }
if ( is_void(cbar)) cbar = CBAR();


// Transmit somd time to sf_a
if ( is_void( last_somd) )
    last_somd = 0;

func send_sod_to_sf( somd ) {
 extern last_somd
    tkcmd, swrite(format="send_sod_to_sf %d", somd);
    last_somd = somd;
}

func send_tans_to_sf( somd, pitch, roll, heading ) {
  extern last_somd
  tkcmd, swrite(format="send_tans_to_sf %d %f %f %f", somd, pitch, roll, heading
);
  last_somd = somd;
  }



