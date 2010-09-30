// vim: set ts=3 sts=3 sw=3 ai sr et:
// Place to collect all yorick .i files that eaarl needs.

if(is_void(__eaarl_includes_included__)) {
   __eaarl_includes_included__ = 1;

   // roll is a yorick function but often gets overwritten, so copy it to yroll
   // so that it doesn't get lost
   if(is_void(yroll))
      yroll = roll;

   // merge is another yorick function that sometimes gets overwritten
   if(is_void(ymerge))
      ymerge = merge;

   // Built-in and plugin includes
   require, "copy_plot.i";
   require, "jpeg.i";
   require, "lmfit.i";
   require, "msort.i";
   require, "pnm.i";
   require, "rdcols.i";
   require, "string.i";
   require, "unsigned.i";
   require, "utils.i";
   require, "yeti.i";
   require, "yeti_regex.i";
   require, "yeti_yhdf.i";
   require, "ytk.i";
   require, "zlib.i";

   // Replace built-in median with Yeti's median which is much faster
   if(is_void(ymedian))
      ymedian = median;
   median = quick_median;

   // ALPS requires
   // These must come first, since some other functions make use of them at the
   // top level
   require, "eaarl_constants.i";
   require, "eaarl_structs.i";
   require, "eaarl_data.i";
   require, "general.i";

   require, "asciixyz.i";
   require, "atm.i";
   require, "batch_analysis.i";
   require, "batch_process.i";
   require, "batch_veg_energy.i";
   require, "bathy.i";
   require, "bathy_filter.i";
   require, "centroid.i";
   require, "colorbar.i";
   require, "compare_transects.i";
   require, "comparison_fns.i";
   require, "cs.i";
   require, "data_rgn_selector.i";
   require, "data_segments.i";
   require, "datum_converter.i";
   require, "determine_bias.i";
   require, "dir.i";
   require, "dirload.i";
   require, "dmars.i";
   require, "drast.i";
   require, "eaarl_mounting_bias.i";
   require, "edb_access.i";
   require, "edf.i";
   require, "geo_bath.i";
   require, "geometry.i";
   require, "gridding.i";
   require, "histogram.i";
   require, "ircf.i";
   require, "irg.i";
   require, "jpeg_support.i";
   require, "json.i";
   require, "kml.i";
   require, "las.i";
   require, "lines.i";
   require, "ll2utm.i";
   require, "manual_filter.i";
   require, "map.i";
   require, "mission_conf.i";
   require, "mosaic_tools.i";
   require, "mouse.i";
   require, "nad832navd88.i";
   require, "nav.i";
   require, "parse.i";
   require, "pip.i";
   require, "qaqc_fns.i";
   require, "raspulsearch.i";
   require, "rbgga.i";
   require, "rbpnav.i";
   require, "rbtans.i";
   require, "rcf.i";
   require, "read_yfile.i";
   require, "rlw.i";
   require, "seamless.i";
   require, "set.i";
   require, "sf.i";
   require, "shapefile.i";
   require, "surface_topo.i";
   require, "tiles.i";
   require, "transect.i";
   require, "util_cast.i";
   require, "util_container.i";
   require, "util_coord.i";
   require, "util_plot.i";
   require, "util_str.i";
   require, "veg.i";
   require, "wgs842nad83.i";
   require, "window.i";
   require, "ytime.i";
   require, "ytriangulate.i";
   require, "zone.i";

   // Check for Yorick 2.2.00x and include things that depend on it if safe.
   // Yorick 2.2 will be required in the future, but for now it is optional.
   // This comes below the rest because the class_* files require some of the
   // above functions at the global scope, for closures.
   if(is_func(is_obj)) {
      // util_obj.i must come first because class_* may use it
      require, "util_obj.i";

      require, "class_clsobj.i";
      require, "class_deque.i";
      require, "class_pcobj.i";
      require, "class_wfobj.i";
      require, "eaarl1_wf.i";
      require, "mathop.i";
      require, "obj_show.i";
      require, "pcobj_import.i";
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
   extern last_somd, soe_day_start;
   tkcmd, swrite(format="send_sod_to_sf %d", somd);
   soe = int(soe_day_start + somd);
   tkcmd, swrite(format="::sf::mediator broadcast soe %d", soe);
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
