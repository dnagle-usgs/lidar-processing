// vim: set ts=2 sts=2 sw=2 ai sr et:
// Place to collect all yorick .i files that eaarl needs.

if(is_void(src_path))
  src_path = pwd();

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
} else {
  require, "noytk.i";
}
require, "ytk_extra.i";
require, "zlib.i";

// Patches for core / plugins
require, "patches/2012-08-yutils.i";
require, "patches/2012-09-funcset.i";

// Replace built-in median with Yeti's median which is much faster
if(is_void(ymedian))
  ymedian = median;
median = quick_median;

// ALPS requires
// These must come first, since some other functions make use of them at the
// top level
require, "logger.i";
require, "assert.i";
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
require, "class_deque.i";
require, "colorbar.i";
require, "cs.i";
require, "cs_geotiff.i";
require, "data_rgn_selector.i";
require, "data_segments.i";
require, "datum_converter.i";
require, "dir.i";
require, "dirload.i";
require, "dmars.i";
require, "edf.i";
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
require, "plugins.i";
require, "polyfit_smooth.i";
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
require, "statistics.i";
require, "tiles.i";
require, "transect.i";
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
