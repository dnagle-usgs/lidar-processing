// vim: set ts=2 sts=2 sw=2 ai sr et:

// Only kick off a job if called in batch mode.
if(batch()) {
  // Must add the lidar-processing/src directory to the search path
  // Also, for safety sake, drop the ./ part of the default path
  set_path, strpart(get_includes()(0), :-5) + strpart(get_path(), 3:);
  require, "rrequire.i";
  require, "job_support.i";
  __job_run, get_argv();
}
