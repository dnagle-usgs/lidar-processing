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

  For debug purposes, you can also invoke a job by batching -batch to -i like
  so:
    yorick -batch job.i COMMAND [ARGS]
  The difference is that -batch runs and exits, whereas -i runs and leaves you
  in an interactive terminal.

 ******************************************************************************/

// Some code refers to src_path directly.
src_path = strpart(current_include(), :-5);

// Must add the lidar-processing/src directory to the search path
// Also, for safety sake, drop the ./ part of the default path
set_path, src_path + strpart(get_path(), 3:);

require, "rrequire.i";
require, "calps_compat.i";
require, "job_support.i";
__job_run, process_argv();
