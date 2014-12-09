// vim: set ts=2 sts=2 sw=2 ai sr et:
// Place to collect all yorick .i files that eaarl needs.

// Include calps, if available. This makes sure it doesn't accidentally get
// clobberred if a function gets (re)defined prior to autoloading it.
if(is_func(calps_compatibility))
  require, "calps.i";

// Added 2014-08-01
// This notice should be kept for at least 6 months (until 2015-02-01)
if(!is_func(gist_gpbox)) {
  write, "";
  write, "Your ALPS installation is out of date and cannot run the current code."
  write, "You have two options:"
  write, "  Option 1: You can downgrade your ALPS repository code. To do this,";
  write, "            go to the lidar-processing directory and run this";
  write, "            command:";
  write, "                hg update -r 76d8da69c8e3";
  write, "            After that ALPS should start normally. Do not update ALPS";
  write, "            again until you have upgraded your ALPS prerequisites."
  write, "  Option 2: Upgrade your ALPS prerequisites. You will need to obtain";
  write, "            a copy of the ALPS installer and install it to bring your";
  write, "            ALPS dependencies (such as Yorick) up to date.";
  write, "Option 2 is preferred, since Option 1 locks you in to an older";
  write, "version of ALPS.";
  quit;
}

if(is_void(src_path))
  src_path = pwd();

// Comptibility routines for CALPS
require, "calps_compat.i";

// Configure doubles and floats so that northing values will render with two
// decimal places interactively by default
print_format, float="%.10g", double="%.10g";

plmk_default, msize=.1;
pldefault, marks=0;

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
require, "poly.i";
require, "rdcols.i";
require, "string.i";
require, "unsigned.i";
require, "utils.i";
require, "yeti.i";
require, "yeti_regex.i";
require, "yeti_yhdf.i";
if(_ytk) {
  require, "ytk.i";
  require, "ytk_window.i";
  require, "ytk_window_resizable.i";
} else {
  require, "noytk.i";
}
require, "ytk_extra.i";
require, "zlib.i";

// Patches for core / plugins
require, "patches/2012-08-yutils.i";
require, "patches/2012-09-funcset.i";
require, "patches/2013-05-help.i";

// Replace built-in median with Yeti's median which is much faster
if(is_void(ymedian))
  ymedian = median;
median = quick_median;

// ALPS requires
// These must come first, since some other functions make use of them at the
// top level
require, "logger.i";
require, "handler.i";
require, "hook.i";
require, "int_t.i";
require, "alps_constants.i";
require, "alps_data.i";
require, "alps_structs.i";
require, "util_basic.i";
require, "general.i";
require, "util_obj.i";
require, "util_progress.i";

require, "ascii.i";
require, "ascii_encode.i";
require, "asciixyz.i";
require, "batch_process.i";
require, "batch_retile.i";
require, "class_confobj.i";
require, "class_deque.i";
require, "colorbar.i";
require, "cs.i";
require, "cs_geotiff.i";
require, "data2xyz.i";
require, "data_rgn_selector.i";
require, "data_segments.i";
require, "datum_converter.i";
require, "depth_adjust.i";
require, "dir.i";
require, "dirload.i";
require, "distributions.i";
require, "dmars.i";
require, "edf.i";
require, "expix.i";
require, "filter.i";
require, "flight_planning.i";
require, "geometry.i";
require, "geotiff_tags.i";
require, "gridding.i";
require, "groundtruth.i";
require, "histogram.i";
require, "ircf.i";
require, "jpeg_support.i";
require, "json_decode.i";
require, "json_encode.i";
require, "kml.i";
require, "kml_extents.i";
require, "kml_flightlines.i";
require, "kml_fp.i";
require, "kml_jgw.i";
require, "kml_lines.i";
require, "kml_markup.i";
require, "las.i";
require, "las_filter.i";
require, "lines.i";
require, "ll2utm.i";
require, "makeflow.i";
require, "makeflow_las.i";
require, "makeflow_rcf.i";
require, "manual_filter.i";
require, "map.i";
require, "mathop.i";
require, "mission.i";
require, "mission_gui.i";
require, "mosaic_tools.i";
require, "mouse.i";
require, "nad832navd88.i";
require, "obj_show.i";
require, "parse.i";
require, "pip.i";
require, "pldirtiles.i";
require, "plpix.i";
require, "plugins.i";
require, "polyfit_smooth.i";
require, "polyplot.i";
require, "rbgga.i";
require, "rbpnav.i";
require, "rbtans.i";
require, "rcf.i";
require, "read_yfile.i";
require, "rlw.i";
require, "seamless.i";
require, "serialize.i";
require, "set.i";
require, "sf.i";
require, "shapefile.i";
require, "shapefile_extract.i";
require, "statistics.i";
require, "sox.i";
require, "tiles.i";
require, "transect.i";
require, "unittest.i";
require, "util_cast.i";
require, "util_container.i";
require, "util_coord.i";
require, "util_plot.i";
require, "util_str.i";
require, "wf_analysis.i";
require, "wf_filter.i";
require, "wgs842nad83.i";
require, "window.i";
require, "ytime.i";
require, "ytriangulate.i";
require, "zone.i";

// Must come last, because it depends on some of the above (it actually runs
// something instead of only defining functions)
require, "alpsrc.i";
require, "geotiff_constants.i";

// Invoke any autoloading needed for plugins.
plugins_autoload;
