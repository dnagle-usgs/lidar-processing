// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
require, "job.i";

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

func makeflow_run(conf, fn, norun=, interval=) {
/* DOCUMENT makeflow_run, conf, fn, interval=;
  Runs a set of jobs using Makeflow. If Makeflow isn't available (or is
  disabled), falls back on sans_makeflow.
  
  Arguments:
    conf: The configuration directives that define the jobs to run. See
      makeflow_conf for details.
    fn: The filename at which to create the Makeflow file. This should
      generally have a suffix of ".makeflow". If omitted, a temporary file will
      be used and then discarded.
  Option:
    norun= Indicates that the Makeflow file should be created, but not
      executed.
    interval= Time interval passed to timer_remaining when using sans_makeflow.
      Ignored if Makeflow is available.

  SEE ALSO: makeflow_conf
*/
  extern alpsrc;
  default, norun, 0;

  makeflow_exe = monitor_exe = "";

  if(alpsrc.makeflow_enable) {
    makeflow_exe = file_join(alpsrc.cctools_bin, "makeflow");
    monitor_exe = file_join(alpsrc.cctools_bin, "makeflow_monitor");
  }

  if(!file_exists(makeflow_exe) || !file_exists(monitor_exe)) {
    sans_makeflow, conf, interval=interval;
    return;
  }

  tempdir = [];
  if(is_void(fn)) {
    if(norun) {
      error, "You can't provide norun=1 unless you also provide fn.";
    }
    tempdir = mktempdir("makeflow");
    fn = file_join(tempdir, "Makeflow");
  }

  makeflow_log = fn+".makeflowlog";

  makeflow_conf_to_script, conf, fn;
  if(norun) {
    write, format=" Makeflow written to:\n %s\n", fn;
    return;
  }

  cmd_makeflow = swrite(format="%s %s %s > /dev/null",
    makeflow_exe, alpsrc.makeflow_opts, fn);
  cmd_monitor = swrite(format="%s -H %s", monitor_exe, makeflow_log);

  if(file_exists(makeflow_log))
    remove, makeflow_log;

  f = popen(cmd_makeflow, 0);
  do {
    pause, 10;
  } while(!file_exists(fn+".makeflowlog"));
  system, cmd_monitor;
  close, f;

  if(!is_void(tempdir)) {
    remove, makeflow_log;
    remove, fn;
    rmdir, tempdir;
  }

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

func sans_makeflow(conf, interval=) {
/* DOCUMENT sans_makeflow, conf, interval=
  Runs a makeflow batch, without using makeflow. Useful for systems that don't
  have makeflow installed.

    conf: The configuration parameter that would normally go to makeflow.
    interval= Interval to pass to timer_remaining. Default is 15.
*/
  default, interval, 15;
  t0 = t1 = tp = array(double, 3);
  timer, t0;

  // Scan through the conf and do two things:
  //    - calculate the size of input (plus 1 byte, to avoid 0 byte files)
  //    - make sure input exists; if it doesn't, we defer all items after the
  //      first with missing input
  defer = save();
  sizes = array(1., conf(*));
  for(i = 1; i <= conf(*); i++) {
    cur = conf(noop(i));
    if(nallof(file_exists(cur.input))) {
      defer = conf(i:);
      conf = conf(:i-1);
      sizes = sizes(:i-1);
      break;
    }

    sizes(i) += double(file_size(cur.input))(*)(sum);
  }

  // Recast sizes to be cumulative
  sizes = sizes(cum)(2:);

  if(defer(*)) {
    write, format="Processing %d jobs; %d deferred\n", conf(*), defer(*);
  } else {
    write, format="Processing %d jobs\n", conf(*);
  }

  timer, t1;
  for(i = 1; i <= conf(*); i++) {
    cur = conf(noop(i));
    cmd = cur.command;
    opt = cur.options;

    // Convert options to an object format. However, if it's already in an
    // object format, first coerce into switch format to normalize cases like
    // this:
    //    save(file=save(in="/a", out="/b"))
    //    save("file-in", "/a", "file-out", "/b")
    // Both yield equivalent switches, but the job functions expect the first
    // format.
    if(is_obj(opt)) {
      args = makeflow_obj_to_switches(opt(2:));
      if(numberof(opt(1)))
        grow, args, opt(1);
      opt = args;
      args = [];
    }
    if(is_scalar(opt)) {
      opt = strsplit(opt, " ");
    }
    opt = _job_parse_options(opt);

    f = symbol_def(cmd);
    f, opt;

    timer_remaining, t1, sizes(i), sizes(0), tp, interval=interval;
  }

  timer_finished, t0, fmt=swrite(format="Finished %d jobs in ELAPSED.\n", conf(*));

  if(defer(*)) {
    timer, t0;
    while(nallof(file_exists(defer(1).input))) {
      pause, 100;
      timer, t1;
      if(t1(3) - t1(3) > 120)
        break;
    }
    if(nallof(file_exists(defer(1).input))) {
      error, "Timed out while waiting for next input file to exist.";
    }
    write, "";
    sans_makeflow, defer, interval=interval;
  }
}
