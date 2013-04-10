// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "ytk.i";

// This is kept separate from ytk.i to enable us to re-include ytk.i after
// startup.

scratch = save(scratch, args);
args = get_argv();
if(numberof(args) > 3 && args(-2) == "ytk_startup.i") {
  initialize_ytk, args(-1), args(0);
}
restore, scratch;

if(!is_func(is_obj))
  tkcmd, "ytk_alps_update_required";
