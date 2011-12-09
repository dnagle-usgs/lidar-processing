// vim: set ts=2 sts=2 sw=2 ai sr et:

/******************************************************************************
 * RUNNING A JOB
 ******************************************************************************
  Syntax for running a job is:
    yorick -batch job.i COMMAND [ARGS]
  where COMMAND is the name of a job command defined below and ARGS are any
  additional arguments to be processed.

  A command is a special function defined below. All command functions are
  prefixed with "job_". See JOB COMMANDS below for further details.

  ARGS can be any number of additional arguments. The expected arguments should
  be documented in the job function's help.

 ******************************************************************************
 * JOB COMMANDS                                                               *
 ******************************************************************************
  A job command is a special function defined below that has a "job_" prefix.
  The job function will be called with a single argument, which will be an
  array of strings which are the remaining command line arguments. Job
  functions are called as subroutines.

  Job functions should be fairly short. They should be simple wrappers around
  functions defined in other files. Most of the work should be in converting
  the configuration options in the passed configuration argument into
  parameters for an external function.

  As above, arbitrary arguments ARGS can be specified on the command line and
  will be passed as-is to the job function. A helper function exists to convert
  that array into an oxy group object using key/value option switches. See
  _job_parse_options for details on usage. It's strongly recommended that job
  functions use this to evaluate their arguments. Using switches will help
  better document what the input values are as they're given, and it will allow
  more flexibility in case the accepted arguments need to change later.

  As an example, here's the content of the debug command debug_show_conf.

    func job_debug_parse(args) {
      require, "obj_show.i";
      obj_show, _job_parse_options(args);
    }

  And here's an example invocation:

    $ yorick -batch job.i job_debug_parse --foo-bar baz --answer 42
     TOP (oxy_object, 4 entries)
     |- (nil) (void) []
     |- foo (oxy_object, 1 entry)
     |  `- bar (string) "baz"
     `- answer (string) "42"
    $

  Note that numbers remain as strings. The job function needs to handle any
  type conversions itself.

  Also, note that your job function MUST require any additional include files
  it needs. This file (job.i) does not include any other include files.

 ******************************************************************************/

func job_debug_echo(args) {
/* DOCUMENT job_debug_echo, args
  Simple job command that echoes its input as expected to have received on the
  command line.
    > job_debug_echo, ["foo", "bar"]
    yorick -batch job.i job_debug_echo "foo" "bar"
    >
*/
  args = swrite(format=" \"%s\"", args)(sum);
  write, format="yorick -batch job.i job_debug_echo%s\n", args;
}

func job_debug_parse(args) {
/* DOCUMENT job_debug_parse, args
  Simple job command that parses its arguments and dumps the tree to stdout.
    > job_debug_parse, ["--foo-bar", "baz", "--answer", "42"]
     TOP (oxy_object, 4 entries)
     |- (nil) (void) []
     |- foo (oxy_object, 1 entry)
     |  `- bar (string) "baz"
     `- answer (string) "42"
    >
*/
  require, "obj_show.i";
  obj_show, _job_parse_options(args);
}

func job_debug_parse_to_file(args) {
/* DOCUMENT job_debug_parse_to_file, args
  Simple job command that parses its arguments and dumps the tree to a file.
  The first non-switch argument will be used as the output file name. It's an
  error if at least one non-switch argument isn't given.
*/
  pause, 5000;
  require, "obj_show.i";
  conf = _job_parse_options(args);
  fn = conf(1)(1);
  write, open(fn, "w"), format="%s\n", obj_show(conf);
}

func job_dirload(args) {
/* DOCUMENT job_dirload, args
  This is a wrapper around dirload. Each accepted command-line option
  corresponds to an option or parameter of dirload as follows.

    --file-in   corresponds to  files=
    --file-out  corresponds to  outfile=
    --vname     corresponds to  outvname=
    --uniq      corresponds to  uniq=
    --skip      corresponds to  skip=

  Additionally,

    --file-in may be provided multiple times
    --uniq defaults to "0"
    --skip defaults to "1"
*/
  conf = _job_parse_options(args);
  files = outfile = outvname = uniq = skip = [];
  if(!conf(*,"file"))
    error, "missing required keys --file-in and --file-out";
  if(nallof(conf.file(*,["in","out"])))
    error, "missing required keys --file-in and --file-out";
  files = conf.file.in;
  outfile = conf.file.out;
  uniq = conf(*,"uniq") ? conf.uniq : "0";
  skip = conf(*,"skip") ? conf.skip : "1";
  outvname = conf(*,"vname") ? conf.vname : [];

  require, "util_str.i";
  uniq = atoi(uniq);
  skip = atoi(skip);

  require, "dirload.i";
  dirload, files=files, outfile=outfile, outvname=outvname, uniq=uniq,
      skip=skip, verbose=0;
}

func job_rcf_eaarl(args) {
/* DOCUMENT job_rcf_eaarl, args
  This is a wrapper around rcf_filter_eaarl_file. Each accepted command-line
  option corresponds to an option or parameter of rcf_filter_eaarl_file as
  follows.

    --file-in         corresponds to  file_in
    --file-out        corresponds to  file_out
    --mode            corresponds to  mode=
    --clean           corresponds to  clean=
    --rcfmode         corresponds to  rcfmode=
    --buf             corresponds to  buf=
    --w               corresponds to  w=
    --n               corresponds to  n=
    --prefilter-min   corresponds to  prefilter_min=
    --prefilter-max   corresponds to  prefilter_max=
*/
  conf = _job_parse_options(args);
  require, "util_str.i";
  clean = buf = w = n = prefilter_min = prefilter_max = [];
  if(conf(*,"clean")) buf = atoi(conf.clean);
  if(conf(*,"buf")) buf = atoi(conf.buf);
  if(conf(*,"w")) w = atoi(conf.w);
  if(conf(*,"n")) n = atoi(conf.n);
  if(conf(*,"prefilter")) {
    // .min and .max are syntax errors to the Yorick parser, so ("min") and
    // ("max") must be used instead
    if(conf.prefilter(*,"min")) prefilter_min = atod(conf.prefilter("min"));
    if(conf.prefilter(*,"max")) prefilter_max = atod(conf.prefilter("max"));
  }

  require, "rcf.i";
  rcf_filter_eaarl_file, conf.file.in, conf.file.out, mode=conf.mode,
      clean=clean, rcfmode=conf.rcfmode, buf=buf, w=w, n=n,
      prefilter_min=prefilter_min, prefilter_max=prefilter_max, verbose=0;
}

/******************************************************************************
 * INTERNALS                                                                  *
 ******************************************************************************
  Do not touch anything below when adding new jobs!
 ******************************************************************************/

func _job_parse_options(args) {
/* DOCUMENT conf = _job_parse_options(args)
  Argument ARGV should be an array of strings consisting of option/value pairs
  and arguments to parse. The result of the parsing is an oxy group, which will
  be returned.

  Arguments starting with two dashes will be parsed as key names. If the
  argument has multiple segments separated by dashes, they will be subkeys. The
  value for that key is the next argument. If an option is repeated, the key
  will receive an array with all of the values given.

  Arguments without two initial dashes will be stored as-is as an array as an
  anonymous key in the first slot of the oxy group.

  As a special case, two dashes without any key name ("--") will be stored in
  the anonymous key array as-is.

    > obj_show, _job_parse_options(["yorick", "--foo", "1", "--bar-a", "2", \
    cont> "extra", "--bar-b", "3", "more", "--foo", "4"])
     TOP (oxy_object, 3 entries)
     |- (nil) (string,2) ["extra","more"]
     |- foo (string,2) ["1","4"]
     `- bar (oxy_object, 2 entries)
        |- a (string) "2"
        `- b (string) "3"
    >

  This function's name is prefixed with an underscore to prevent it from being
  called as a job command function.
*/
  conf = save()
  save, conf, string(0), [];

  i = 1;
  while(i <= numberof(args)) {
    // Handle double-dash options
    if(strpart(args(i), :2) == "--" && strlen(args(i)) > 2) {
      if(i == numberof(args))
        error, "missing value for option "+args(i);
      obj = conf;
      parts = ["", strpart(args(i), 3:)];
      while(parts(2)) {
        parts = strtok(parts(2), "-");
        // If there's more sub-keys, drill down further
        if(parts(2)) {
          // If it doesn't have the subkey already, create it
          if(!obj(*,parts(1))) {
            save, obj, parts(1), save();
          }
          obj = obj(parts(1));
        // No more subkeys? Store the value
        } else {
          if(!is_obj(obj))
            error, "option "+args(i)+" conflcits with earlier option";
          if(obj(*,parts(1))) {
            if(is_obj(obj(parts(1))))
              error, "option "+args(i)+" conflicts with earlier option";
            save, obj, parts(1), grow(obj(parts(1)), args(i+1));
          } else {
            save, obj, parts(1), args(i+1);
          }
        }
      }
      i += 2;

    // Handle anything else
    } else {
      val = conf(1);
      grow, val, args(i);
      save, conf, 1, val;
      i++;
    }
  }

  return conf;

}

func __job_run(argv) {
/* DOCUMENT __job_run, argv
  Runs the job specified in a command line. ARGV should be the result of
  get_argv(). It must be an array of strings. ARGV(1) is the path to Yorick and
  is disregarded. ARGV(2) is the job function to run. ARGV(3:) is optional
  (though it wouldn't make sense to omit) and will be passed to the function
  specified as they are (that is, as an array of strings).

  So, __job_run(argv) is roughly equivalent to:
    symbol_def(argv(2)), argv(3:)
*/
  // first argument is path to yorick, skip
  // second argument is job function
  // remaining arguments pass to job function
  if(numberof(argv) < 2)
    error, "must specify job function";
  job_func = argv(2);
  args = numberof(argv) < 3 ? [] : argv(3:);
  
  if(strpart(job_func, 1:4) != "job_")
    error, "job function must start with \"job_\"";

  if(!symbol_exists(job_func))
    error, "unknown job function: "+job_func;

  f = symbol_def(job_func);
  if(!is_func(f))
    error, "invalid job function: "+job_func;

  f, args;
}

// Only kick off a job if called in batch mode.
if(batch()) {
  // Must add the lidar-processing/src directory to the search path
  // Also, for safety sake, drop the ./ part of the default path
  set_path, strpart(get_includes()(0), :-5) + strpart(get_path(), 3:);
  __job_run, get_argv();
}
