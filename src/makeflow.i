// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "job_support.i";

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
    memory: How much memory the job is estimated to require, in MB (optional)

  The "options" key should be an oxy group object that corresponds to the
  command line switches and arguments. This object should be formatted exactly
  like the output expected from _job_parse_options in job.i. For example:
  options=save(string(0), [], foo="bar", answer="42")

  So an example configuration with a dummy debug job might be:
    > conf = save()
    > save, conf, string(0), save(command="job_debug_parse_to_file",
    CONT> output="/data/bar", options=save(string(0), [], "foo-bar", "baz")

  A few notes:
    - All files used by the job as input MUST be documented under the input
      key.
    - All files created/updated by the job as output MUST be documented uner
      the output key.
    - All path names MUST be absolute.

  A makeflow job can be run in one of two ways: via Makeflow or within the
  current ALPS session. If the job is run by Makeflow, it needs to carry along
  all of its dependencies. If it is run in the current ALPS session, then it
  doesn't make sense to prepare to carry along all of its dependencies if some
  of those dependencies are available in the session already. Also, if a job is
  run by Makeflow, it needn't worry about consequences to the running session;
  but a job running in the current ALPS session though, it needs to be quite
  careful about undesirable side effects.

  With that in mind:

  Make sure your job doesn't create any undesirable side effects in the
  session. Test it with makeflow disabled to verify.

  Make sure your job conf only contains the elements that would be necessary
  for running without makeflow enabled. Then use hooks to supply the elements
  that would be needed when running under makeflow. You'll want to look at the
  hooks "makeflow_run" and "job_run", as well as the function
  "makeflow_requires_jobenv".

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

  // If makeflow is enabled, attempt to find a makeflow executable
  makeflow_exe = "";
  enabled = alpsrc.makeflow_enable;
  // If enabled but using local mode with 1 core, force disable (unless
  // makeflow_enable is set to 2 to force enable)
  if(enabled == 1 && alpsrc.makeflow_type == "local" && alpsrc.cores_local <= 1)
    enabled = 0;
  if(enabled)
    makeflow_exe = file_join(alpsrc.cctools_bin, "makeflow");

  // If no makeflow executable is available/allowed, fall back to pure Yorick.
  if(!file_exists(makeflow_exe) && !norun) {
    sans_makeflow, conf, interval=interval;
    return;
  }

  tempdir = [];
  if(is_void(fn)) {
    if(norun)
      error, "You can't provide norun=1 unless you also provide fn.";
    tempdir = mktempdir("makeflow");
    fn = file_join(tempdir, "Makeflow");
  }

  // Associated files always get created alongside makeflow file
  makeflow_log = fn+".makeflowlog";

  restore, hook_invoke("makeflow_run", save(norun, conf, fn, makeflow_log));

  // Generate makeflow
  makeflow_conf_to_script, conf, fn;

  // Abort: this lets the caller examine the output without running the
  // makeflow.
  if(norun) {
    write, format=" Makeflow written to:\n %s\n", fn;
    return;
  }

  opts = swrite(format="%s -T %s -N %s",
    alpsrc.makeflow_opts, alpsrc.makeflow_type, alpsrc.makeflow_project);
  if(alpsrc.makeflow_type == "local") {
    opts += swrite(format=" -J %d", alpsrc.cores_local);
  } else {
    opts += swrite(format=" -j %d -J %d", alpsrc.cores_local,
      alpsrc.cores_remote);
  }

  cmd_makeflow = swrite(format="%s %s %s > /dev/null",
    makeflow_exe, opts, fn);

  // Need to remove any existing makeflow log to avoid possibility of accessing
  // old log before new log is created.
  remove, makeflow_log;

  // Initialize status
  job_count = conf(*);
  status, start;

  // Launch
  f = popen(cmd_makeflow, 0);

  // Monitor logfile until finished.
  do {
    pause, 250;
    parsed = makeflow_parse_log(makeflow_log);
    if(is_void(parsed)) continue;
    last = parsed.log(0);
    msg = swrite(format="Makeflow running (W:%d R:%d D:%d",
      last.nodes_waiting, last.nodes_running, last.nodes_complete);
    if(last.nodes_failed) msg += swrite(format=" F:%d", last.nodes_failed);
    if(last.nodes_aborted) msg += swrite(format=" A:%d", last.nodes_aborted);
    msg += ")";
    status, progress, parsed.jobs_finished, job_count, msg=msg;
  } while(!is_void(parsed) && !parsed.status);
  close, f;
  status, finished;

  if(!is_void(tempdir)) {
    remove, makeflow_log;
    remove, fn;
    rmdir, tempdir;
  }

  write, format="%s", "Jobs completed.\n";
}

func hook_makeflow_jobs_env(data, env) {
/* DOCUMENT hook_makeflow_jobs_env(env)
  Hook on makeflow_run that adds jobenv to jobs that need it.

  To add a job to the list of jobs that get a jobenv, use
  makeflow_requires_jobenv.
*/
  if(is_void(data.jobs)) return env;

  conf = obj_copy(env.conf, recurse=1);
  jobenv = file_rootname(env.fn) + ".env";
  needed = 0;

  for(i = 1; i <= conf(*); i++) {
    item = conf(noop(i));
    if(noneof(item.command == data.jobs)) continue;

    needed = 1;
    save, item, input=grow(item.input, jobenv);
    save, item.options, jobenv;
  }

  if(needed) {
    jobs_env_wrap, jobenv;
    save, env, conf;
  }

  return env;
}
hook_makeflow_jobs_env = closure(hook_makeflow_jobs_env, save(jobs=[]));
hook_add, "makeflow_run", "hook_makeflow_jobs_env";

func makeflow_requires_jobenv(job) {
/* DOCUMENT makeflow_requires_jobenv, job
  This adds JOB to the list of jobs that require a jobenv to be sent along with
  the job. When the Makeflow is generates, a jobenv file will be created and
  --jobenv added to those jobs' parameter lists.
*/
    save, hook_makeflow_jobs_env.data, jobs=set_remove_duplicates(
      grow(hook_makeflow_jobs_env.data.jobs, job));
}

func makeflow_parse_log(fn) {
/* DOCUMENT makeflow_parse_log(fn)
  Parses a makeflow log and returns oxy group with the information parsed from
  it. All fields are integers. Times are unix time in microseconds. There
  are two sets of fields. At the top level are:

    status - Current status of makeflow process. Possible values:
        0 - running
        1 - completed
        2 - aborted
        3 - failed
    started - Time when the makeflow was started.
    ended - Time when the makeflow ended.
    jobs_pending - Number of jobs that have not finished.
    jobs_finished - Number of jobs that have finished.
    log - An array of struct MAKEFLOW_LOG containing the log entries.

  The second set of fields are the contents of result.log, as noted above, an
  array of struct MAKEFLOW_LOG. (The MAKEFLOW_LOG struct is not externally
  defined and is created on-the-fly.) All field are again integers, as follows.

    timestamp
    node_id
    new_state
    job_id
    nodes_waiting
    nodes_running
    nodes_complete
    nodes_failed
    nodes_aborted
    node_id_counter

  These fields are as described in the Makeflow manual at:
    http://www.nd.edu/~ccl/software/manuals/makeflow.html

  If the file does not exist, then [] is returned.
*/
  if(catch(0x02)) return;
  lines = rdfile(fn);
  started = ended = status = 0;

  w = where(strpart(lines, 1:9) == "# STARTED");
  if(numberof(w) == 1) {
    null = string(0);
    sread, lines(w(1)), format="# %s %d", null, started;
  }

  if(strpart(lines(0), 1:1) == "#") {
    key = strtok(strpart(lines(0), 3:))(1);
    status = where(key == ["COMPLETED", "ABORTED", "FAILED"]);
    status = numberof(status) ? status(1) : 0;
    if(status) {
      null = string(0);
      sread, lines(0), format="# %s %d", null, ended;
    }
  }

  w = where(strpart(lines, 1:1) != "#");
  count = numberof(w);
  if(!count) return;
  lines = lines(w);

  // Clobbering builtin timestamp, make sure not to put this at global scope
  timestamp = node_id = new_state = job_id = nodes_waiting = nodes_running =
    nodes_complete = nodes_failed = nodes_aborted = node_id_counter =
    array(long, count);

  sread, lines, format="%d %d %d %d %d %d %d %d", timestamp, node_id, new_state,
    job_id, nodes_waiting, nodes_running, nodes_complete, nodes_failed,
    nodes_aborted, node_id_counter;

  // Clobbering builtin log, make sure not to put this at global scope
  log = obj2struct(save(timestamp, node_id, new_state, job_id, nodes_waiting,
    nodes_running, nodes_complete, nodes_failed, nodes_aborted,
    node_id_counter), name="MAKEFLOW_LOG", ary=1);

  last = log(0);
  jobs_pending = last.nodes_waiting + last.nodes_running;
  jobs_finished = last.nodes_complete + last.nodes_failed + last.nodes_aborted;

  return save(status, started, ended, jobs_pending, jobs_finished, log);
}

func makeflow_conf_to_script(conf, fn) {
/* DOCUMENT makeflow_conf_to_script, conf, fn

  Given a configuration, generates a makeflow script.

  SEE ALSO: makeflow
*/
  f = [];
  if(is_string(fn))
    f = open(fn, "w");

  // Make a copy, then sort by memory requirement
  conf = obj_copy(conf);
  mem = array(0, conf(*));
  for(i = 1; i <= conf(*); i++)
    mem(i) = conf(noop(i))(*,"memory") ? conf(noop(i)).memory : 100;
  // msort makes it stable
  conf = conf(msort(mem));

  write, f, format="YORICK=%syorick\n", Y_LAUNCH;
  write, f, format="JOB=%sjob.i\n", get_cwd();

  lastmem = -1;
  for(i = 1; i <= conf(*); i++) {
    item = conf(noop(i));

    // Round memory requirement up to next 100MB interval, min 100MB
    mem = item.memory;
    if(!mem) mem = 100;
    mem = long(ceil(mem/100.)*100);
    if(lastmem != mem) {
      write, f, format="CATEGORY=\"memory%d\"\n", mem;
      write, f, format="CORES=1\nMEMORY=%d\n", mem;
      lastmem = mem;
    }

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

    if(item(*,"raw")) {
      write, f, format="\n%s:%s\n", output, input;
      write, f, format="\t%s\n", item.raw;
      continue;
    }

    args = [];
    if(!is_void(item.options)) {
      args = makeflow_obj_to_switches(item.options(2:));
      if(numberof(item.options(1)))
        grow, args, item.options(1);
      args = strjoin(args, " ");
    }

    cmd = item.command;

    write, f, format="\n%s:%s\n", output, input;
    write, f, format="\t$YORICK -batch $JOB %s %s\n",
      cmd, args;
  }

  if(f) close, f;
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
      for(j = 1; j <= numberof(obj(noop(i))); j++) {
        val = obj(noop(i))(j);
        if(is_integer(val))
          val = swrite(format="%d", val);
        if(typeof(val) == "double")
          val = swrite(format="%.16g", val);
        if(typeof(val) == "float")
          val = swrite(format="%.8g", val);
        grow, result, [prefix+"-"+keys(i), val];
      }
    }
  }
  return result;
}

func sans_makeflow(conf, interval=, current=, count=) {
/* DOCUMENT sans_makeflow, conf, interval=
  Runs a makeflow batch, without using makeflow. Useful for systems that don't
  have makeflow installed.

    conf: The configuration parameter that would normally go to makeflow.
    interval= Interval to pass to timer_remaining. Default is 15.
*/
  default, interval, 15;
  default, current, 0;
  default, count, conf(*);
  t0 = t1 = tp = array(double, 3);
  timer, t0;

  // Scan through the conf and make sure input exists; if it doesn't, we defer
  // all items after the first with missing input
  defer = save();
  for(i = 1; i <= conf(*); i++) {
    cur = conf(noop(i));
    if(nallof(file_exists(cur.input))) {
      defer = conf(i:);
      conf = conf(:i-1);
      break;
    }
  }

  if(defer(*)) {
    write, format="Processing %d jobs; %d deferred\n", conf(*), defer(*);
  } else {
    write, format="Processing %d jobs\n", conf(*);
  }

  if(!current && count == conf(*))
    status, start, msg="Running jobs, finished CURRENT of COUNT", count=count;
  for(i = 1; i <= conf(*); i++) {
    cur = conf(noop(i));

    if(cur(*,"raw")) {
      system, cur.raw;
      current++;
      status, progress, current, count;
      continue;
    }

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

    current++;
    status, progress, current, count;
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
    sans_makeflow, defer, interval=interval, current=current, count=count;
  }

  status, finished;
}
