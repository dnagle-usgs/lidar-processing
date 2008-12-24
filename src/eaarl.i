/*
   Place to collect all yorick .i files that eaarl needs.
*/

if(is_void(__eaarl_includes_included__)) {
   __eaarl_includes_included__ = 1;

   write,"$Id$";

   // Built-in and plugin includes
   require, "jpeg.i";
   require, "msort.i";
   require, "pnm.i";
   require, "string.i";
   require, "yeti.i";
   require, "yeti_regex.i";
   require, "ytk.i";
   /*
   The Yeti package is available from:
   http://www-obs.univ-lyon1.fr/~thiebaut/yeti.html
   */

   // ALPS plugin requires
   require, "rcf_triangulate.i";
   require, "rcf_utils.i";
   require, "triangle.i";

   // ALPS requires
   require, "batch_process.i";
   require, "bathy_filter.i";
   require, "change_window_size.i";
   require, "colorbar.i";
   require, "comparison_fns.i";
   require, "data_rgn_selector.i";
   require, "dir.i";
   require, "dmars.i";
   require, "eaarl_constants.i";
   require, "eaarl_mounting_bias.i";
   require, "edb_access.i";
   require, "general.i";
   require, "geometry.i";
   require, "gridr.i";
   require, "groundtruth.i";
   require, "jpeg_support.i";
   require, "lines.i";
   require, "ll2utm.i";
   require, "map.i";
   require, "mathop.i";
   require, "nav.i";
   require, "pip.i";
   require, "qq24k.i";
   require, "rbgga.i";
   require, "rbpnav.i";
   require, "rbtans.i";
   require, "rcf.i";
   require, "read_yfile.i";
   require, "rlw.i";
   require, "sel_file.i";
   require, "set.i";
   require, "transect.i";
   require, "waves.i";
   require, "ytime.i";
   require, "zone.i";
}


// Functions for working with sf_a.tcl

if(is_void(last_somd)) last_somd = 0;

func send_sod_to_sf(somd) {
/* DOCUMENT send_sod_to_sf, somd
   Wrapper around the Tcl command send_sod_to_sf
*/
   extern last_somd;
   tkcmd, swrite(format="send_sod_to_sf %d", somd);
   last_somd = somd;
}

func send_tans_to_sf(somd, pitch, roll, heading) {
/* DOCUMENT send_tans_to_sf, somd, pitch, roll, heading
   Wrapper around the Tcl command send_tans_to_sf
*/
   extern last_somd;
   tkcmd, swrite(format="send_tans_to_sf %d %f %f %f",
      somd, pitch, roll, heading);
   last_somd = somd;
}
