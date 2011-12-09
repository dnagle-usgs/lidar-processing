// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

local makeflow_conf;
/* DOCUMENT makeflow_conf
  This documents the format of the configuration group object expected by the
  makeflow function.

  A conf object is an oxy group containing a series of jobs, as thus:
    > conf = save()
    > save, conf, string(0), JOB1
    > save, conf, string(0), JOB2
    > save, conf, string(0), JOB3
  Where JOB1, JOB2, JOB3, etc. are job configuration group objects.

  A job configuration group object is an oxy group that contains the following
  keys:
    input: A list of input files needed (optional, but effectively required)
    output: File to be created (required)
    command: The job command to run (as defined in job.i) (required)
    options: The options to pass to the job command (optional but effectively
        required) (see below for details)
    forcelocal: If present and true, forces local execution; otherwise, the job
        may be dispatched to other servers if a multi-server setup is available
        (optional)

  The "options" key may be formatted in a few different ways:
  
    - The simplest is a simple string consisting of the command line switches
      and arguments to pass to the job invocation. For example:
          options="--foo bar --answer 42"

    - The next simplest is an array of strings consisting of the command line
      switches and arguments. For example:
          options=["--foo", "bar", "--answer", "42"]

    - The last option is to pass an oxy group object that corresponds to the
      command line switches and arguments. This object should be formatted
      exactly like the output expected from _job_parse_options in job.i. For
      example:
          options=save(string(0), [], foo="bar", answer="42")

  So an example configuration with a dummy debug job might be:
    > conf = save()
    > save, conf, string(0), save(command="job_debug_parse_to_file",
    CONT> output="/data/bar", options="--foo-bar baz")

  A few notes:
    - All files used by the job as input MUST be documented under the input
      key.
    - All path names must be absolute.

  SEE ALSO: makeflow, _job_parse_options
*/

func makeflow(conf, fn) {
/* DOCUMENT makeflow, conf, fn;
  Runs a set of jobs using Makeflow.
  
  Arguments:
    conf: The configuration directives that define the jobs to run. See
      makeflow_conf for details.
    fn: The filename at which to create the Makeflow file. This should
      generally have a suffix of ".makeflow".

  SEE ALSO: makeflow_conf
*/
  extern alpsrc;
  makeflow_exe = file_join(alpsrc.cctools_bin, "makeflow");
  monitor_exe = file_join(alpsrc.cctools_bin, "makeflow_monitor");
  makeflow_log = fn+".makeflowlog";

  makeflow_conf_to_script, conf, fn;
  cmd_makeflow = swrite(format="cd %s ; %s %s %s > /dev/null",
    file_dirname(fn), makeflow_exe, alpsrc.makeflow_opts, file_tail(fn));
  cmd_monitor = swrite(format="%s -H %s", monitor_exe, makeflow_log);

  if(file_exists(makeflow_log))
    remove, makeflow_log;

  f = popen(cmd_makeflow, 0);
  pause, 10;
  //pipe = popen("sh", 1);
  //write, pipe, format="%s > /dev/null\n", cmd_makeflow;
  //fflush, pipe;
  while(!file_exists(fn+".makeflowlog"))
    pause, 10;
  system, cmd_monitor;
  //close, pipe;
  close, f;

  write, format="%s", "Jobs completed.\n";
}

func makeflow_conf_to_script(conf, fn) {
/* DOCUMENT makeflow_conf_to_script, conf, fn
  script = makeflow_conf_to_script(conf)

  Given a configuration, generates a makeflow script.

  SEE ALSO: makeflow
*/
  flow = "";

  flow += swrite(format="YORICK=%syorick\n", Y_LAUNCH);
  flow += swrite(format="JOB=%sjob.i\n", get_cwd());

  for(i = 1; i <= conf(*); i++) {
    item = conf(noop(i));

    output = [];
    if(is_scalar(item.output))
      output = item.output;
    else
      output = strjoin(item.output(*), " ");

    input = "";
    if(item(*,"input")) {
      if(is_scalar(item.input))
        input = " " + item.input;
      else
        input = (" " + item.input(*))(sum);
    }

    args = [];
    if(is_string(item.options)) {
      if(is_scalar(item.options)) {
        args = item.options;
      } else {
        args = strjoin(item.options(*), " ");
      }
    }
    if(is_obj(item.options)) {
      args = makeflow_obj_to_switches(item.options(2:));
      if(numberof(item.options(1)))
        grow, args, item.options(1);
      args = strjoin(args, " ");
    }

    cmd = item.command;

    forcelocal = item.forcelocal ? "LOCAL " : "";

    flow += "\n";
    flow += swrite(format="%s:%s\n", output, input);
    flow += swrite(format="\t%s$YORICK -batch $JOB %s %s\n",
      forcelocal, cmd, args);
  }

  if(is_string(fn))
    write, open(fn, "w"), format="%s", flow;

  return flow;
}

func makeflow_obj_to_switches(obj, prefix) {
/* DOCUMENT makeflow_obj_to_switches(obj, prefix)
  Converts an oxy group object into an array of key/value switches. Intended
  for internal use in makeflow.i.
  SEE ALSO: makeflow
*/
  default, prefix, "-";
  result = [];
  keys = obj(*,);
  for(i = 1; i <= obj(*); i++) {
    if(is_obj(obj(noop(i)))) {
      grow, result, makeflow_obj_to_switches(obj(noop(i)), prefix+"-"+keys(i));
    } else {
      for(j = 1; j <= numberof(obj(noop(i))); j++)
        grow, result, [prefix+"-"+keys(i), obj(noop(i))(j)];
    }
  }
  return result;
}
