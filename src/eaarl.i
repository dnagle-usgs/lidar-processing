/*
   Place to collect all yorick .i files that eaarl needs.
*/

if(is_void(__eaarl_includes_included__)) {
   __eaarl_includes_included__ = 1;

   // roll is a yorick function but often gets overwritten, so copy it to yroll
   // so that it doesn't get lost
   if(is_void(yroll))
      yroll = roll;

   // merge is another yorick function that sometimes gets overwritten
   if(is_void(ymerge))
      ymerge = merge;

   // string.i replaces two built-ins, so we'll save them to avoid a warning
   // message about them being freed
   if(is_void(yis_scalar))
      yis_scalar = is_scalar;
   if(is_void(yis_vector))
      yis_vector = is_vector;

   // Built-in and plugin includes
   require, "jpeg.i";
   require, "msort.i";
   require, "pnm.i";
   require, "string.i";
   require, "yeti.i";
   require, "yeti_regex.i";
   require, "yeti_yhdf.i";
   require, "ytk.i";
   /*
   The Yeti package is available from:
   http://www-obs.univ-lyon1.fr/~thiebaut/yeti.html
   */

   // Replace built-in median with Yeti's median which is much faster
   if(is_void(ymedian))
      ymedian = median;
   median = quick_median;

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
   require, "json.i";
   require, "lines.i";
   require, "ll2utm.i";
   require, "manual_filter.i";
   require, "map.i";
   require, "mathop.i";
   require, "mouse.i";
   require, "nad832navd88.i";
   require, "nav.i";
   require, "pip.i";
   require, "parse.i";
   require, "qq24k.i";
   require, "rbgga.i";
   require, "rbpnav.i";
   require, "rbtans.i";
   require, "rcf.i";
   require, "read_yfile.i";
   require, "remove_bathy_from_veg.i";
   require, "rlw.i";
   require, "sel_file.i";
   require, "set.i";
   require, "transect.i";
   require, "waves.i";
   require, "wgs842nad83.i";
   require, "ytime.i";
   require, "zone.i";

   // Check for yutils -- warn user if not present
   // Yutils will put things in autoload, so we check for a few functions...
   if(is_func(replot_all) && is_func(lmfit)) {
      require, "copy_plot.i";
      require, "lmfit.i";
      require, "rdcols.i";
      require, "utils.i";
   } else {
      write, "***********************************************************";
      write, "* WARNING: Your system does not appear to have the yutils *";
      write, "* package installed! Please download it from lidar.net at *";
      write, "* /mnt/alps/eaarl/tarfiles and install into your Yorick.  *";
      write, "* ALPS will continue, but you might encounter errors if   *";
      write, "* you attempt to use yutils-derived functionality.        *";
      write, "***********************************************************";
      // yutils is hosted on the yorick SourceForge CVS as well: yorick.sf.net
   }

   // Must come last, because it depends on some of the above (it actually runs
   // something instead of only defining functions)
   require, "alpsrc.i";
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
