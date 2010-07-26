// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
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
   require, "batch_multipip_process.i";
   require, "batch_process.i";
   require, "batch_veg_energy.i";
   require, "bathy.i";
   require, "bathy_filter.i";
   require, "centroid.i";
   require, "change_window_size.i";
   require, "colorbar.i";
   require, "compare_transects.i";
   require, "comparison_fns.i";
   require, "container_utils.i";
   require, "cs.i";
   require, "data_rgn_selector.i";
   require, "data_segments.i";
   require, "dataexplore.i";
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
   require, "gridr.i";
   require, "groundtruth.i";
   require, "hashptr.i";
   require, "histogram.i";
   require, "ircf.i";
   require, "irg.i";
   require, "jpeg_support.i";
   require, "json.i";
   require, "kml.i";
   require, "lines.i";
   require, "ll2utm.i";
   require, "manual_filter.i";
   require, "map.i";
   require, "mathop.i";
   require, "mosaic_tools.i";
   require, "mouse.i";
   require, "nad832navd88.i";
   require, "nav.i";
   require, "parse.i";
   require, "pbd2las.i";
   require, "pip.i";
   require, "plcm.i";
   require, "qaqc_fns.i";
   require, "qq24k.i";
   require, "raspulsearch.i";
   require, "rbgga.i";
   require, "rbpnav.i";
   require, "rbtans.i";
   require, "rcf.i";
   require, "read_yfile.i";
   require, "remove_bathy_from_veg.i";
   require, "rlw.i";
   require, "sel_file.i";
   require, "set.i";
   require, "sf.i";
   require, "strutil.i";
   require, "surface_topo.i";
   require, "transect.i";
   require, "veg.i";
   require, "wgs842nad83.i";
   require, "ytime.i";
   require, "ytriangulate.i";
   require, "zone.i";

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
