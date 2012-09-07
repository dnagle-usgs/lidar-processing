scratch = save(scratch, base);

// We cannot assume that this directory is in the user's Yorick search path, so
// absolute path names are required. All files to include will be siblings to
// the current file.
base = file_dirname(current_include())+"/";
require, base + "eaarla_filter.i";
require, base + "eaarla_process.i";
require, base + "eaarla_raster.i";
require, base + "eaarla_vector.i";
require, base + "eaarla_wf.i";
require, base + "eaarlb_json_log.i";
require, base + "mission_constants.i";

restore, scratch;
