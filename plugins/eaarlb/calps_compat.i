// vim: set ts=2 sts=2 sw=2 ai sr et:

// This is the plugin version of src/calps_compat.i, see that file for details.

scratch = save(scratch, base);
base = file_dirname(current_include())+"/";

// Added 2013-09-24
if(!is_func(eaarl_decode_fast))
  require, base+"calps/eaarl_decode_fast.i";

if(!is_func(cent))
  require, base+"calps/cent.i";

restore, scratch;
