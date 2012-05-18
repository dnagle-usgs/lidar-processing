// vim: set ts=2 sts=2 sw=2 ai sr et:

/******************************************************************************
 * RUNNING A JOB
 ******************************************************************************
  Syntax for running a job is:
    yorick -batch job.i COMMAND [ARGS]
  where COMMAND is the name of a job command defined in job_commands.i and ARGS
  are any additional arguments to be processed.

  A job command is a special function defined in job_command.i. All command
  functions are prefixed with "job_". See documentation in job_command.i for
  further details.

  ARGS can be any number of additional arguments. The expected arguments should
  be documented in the job function's help.

 ******************************************************************************/

// Only kick off a job if called in batch mode.
if(batch()) {
  // Must add the lidar-processing/src directory to the search path
  // Also, for safety sake, drop the ./ part of the default path
  set_path, strpart(get_includes()(0), :-5) + strpart(get_path(), 3:);
  require, "rrequire.i";
  require, "job_support.i";
  __job_run, get_argv();
}
