scratch = save(scratch, base);

// We cannot assume that this directory is in the user's Yorick search path, so
// absolute path names are required. All files to include will be siblings to
// the current file.
base = file_dirname(current_include())+"/";

// Have to come first, used directly in files at loading
include, base + "eaarl_constants.i";
include, base + "class_chanconfobj.i";
include, base + "class_bathconfobj.i";
include, base + "class_mpconfobj.i";
include, base + "class_sbconfobj.i";
include, base + "class_vegconfobj.i";
include, base + "class_cfconfobj.i";

include, base + "eaarl_handlers.i";
include, base + "eaarl_hooks.i";

include, base + "autoselect.i";
include, base + "batch_veg_energy.i";
include, base + "bathy.i";
include, base + "calps_compat.i";
include, base + "centroid.i";
include, base + "drast.i";
include, base + "eaarl_json_log.i";
include, base + "eaarl_raster.i";
include, base + "eaarl_vector.i";
include, base + "edb_access.i";
include, base + "geo_bath.i";
include, base + "irg.i";
include, base + "job_commands.i";
include, base + "manual_filter.i";
include, base + "mission.i";
include, base + "mission_constants.i";
include, base + "mosaic_biases.i";
include, base + "parse.i";
include, base + "pixelwf.i";
include, base + "process_ba.i";
include, base + "process_be.i";
include, base + "process_fs.i";
include, base + "process_mp.i";
include, base + "process_sb.i";
include, base + "process_cf.i";
include, base + "process_main.i";
include, base + "sasr.i";
include, base + "surface_topo.i";
include, base + "util_ba.i";
include, base + "util_mp.i";
include, base + "util_process.i";
include, base + "veg.i";
include, base + "veg_energy.i";

restore, scratch;
