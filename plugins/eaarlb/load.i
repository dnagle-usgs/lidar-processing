scratch = save(scratch, base);

// We cannot assume that this directory is in the user's Yorick search path, so
// absolute path names are required. All files to include will be siblings to
// the current file.
base = file_dirname(current_include())+"/";

// Has to come first, used directly in files at loading
include, base + "class_bathconfobj.i";

include, base + "autoselect.i";
include, base + "batch_process.i";
include, base + "batch_veg_energy.i";
include, base + "bathy.i";
include, base + "centroid.i";
include, base + "drast.i";
include, base + "eaarl_constants.i";
include, base + "eaarl_json_log.i";
include, base + "eaarl_raster.i";
include, base + "eaarl_vector.i";
include, base + "edb_access.i";
include, base + "geo_bath.i";
include, base + "irg.i";
include, base + "makeflow_eaarl.i";
include, base + "manual_filter.i";
include, base + "mission.i";
include, base + "mission_constants.i";
include, base + "mosaic_biases.i";
include, base + "parse.i";
include, base + "pixelwf.i";
include, base + "process_fs.i";
include, base + "sf.i";
include, base + "surface_topo.i";
include, base + "veg.i";
include, base + "veg_energy.i";

restore, scratch;
