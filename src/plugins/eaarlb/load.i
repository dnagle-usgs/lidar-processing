scratch = save(scratch, base);

// We cannot assume that this directory is in the user's Yorick search path, so
// absolute path names are required. All files to include will be siblings to
// the current file.
base = file_dirname(current_include())+"/";
include, base + "autoselect.i";
include, base + "batch_veg_energy.i";
include, base + "bathy.i";
include, base + "drast.i";
include, base + "eaarla_filter.i";
include, base + "eaarla_process.i";
include, base + "eaarla_raster.i";
include, base + "eaarla_vector.i";
include, base + "eaarla_wf.i";
include, base + "eaarlb_json_log.i";
include, base + "edb_access.i";
include, base + "geo_bath.i";
include, base + "mission.i";
include, base + "mission_constants.i";
include, base + "mosaic_biases.i";
include, base + "surface_topo.i";
include, base + "veg.i";
include, base + "veg_energy.i";

restore, scratch;
