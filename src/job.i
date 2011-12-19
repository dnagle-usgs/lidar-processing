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

  As above, arbitrary arguments ARGS can be specified on the command line.
  These arguments will be converted into an oxy group object using key/value
  option switches. See _job_parse_options for details on usage. It's strongly
  recommended that job functions use switches for their arguments. Using
  switches will help better document what the input values are as they're
  given, and it will allow more flexibility in case the accepted arguments need
  to change later.

  As an example, here's the content of the debug command debug_show_conf.

    func job_debug_dump(conf) {
      require, "obj_show.i";
      obj_show, conf;
    }

  And here's an example invocation:

    $ yorick -batch job.i job_debug_dump --foo-bar baz --answer 42
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

func job_debug_dump(args) {
/* DOCUMENT job_debug_dump, conf
  Simple job command that parses its arguments and dumps the tree to stdout.
    > job_debug_dump, ["--foo-bar", "baz", "--answer", "42"]
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

func job_debug_dump_file(conf) {
/* DOCUMENT job_debug_dump_file, conf
  Simple job command that parses its arguments and dumps the tree to a file.
  The first non-switch argument will be used as the output file name. It's an
  error if at least one non-switch argument isn't given.
*/
  fn = conf(1)(1);
  write, open(fn, "w"), format="%s\n", obj_show(conf);
}

func job_dirload(conf) {
/* DOCUMENT job_dirload, conf
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
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;
  uniq = conf(*,"uniq") ? atoi(conf.uniq) : "0";
  skip = conf(*,"skip") ? atoi(conf.skip) : "1";

  require, "dirload.i";
  dirload, files=conf.file.in, outfile=conf.file.out, outvname=conf.vname,
    uniq=uniq, skip=skip, verbose=0;
}

func job_rcf_eaarl(conf) {
/* DOCUMENT job_rcf_eaarl, conf
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
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;
  clean = pass_void(atoi, conf.clean);
  buf = pass_void(atoi, conf.buf);
  w = pass_void(atoi, conf.w);
  n = pass_void(atoi, conf.n);
  prefilter_min = prefilter_max = [];
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

func job_georef_eaarla(conf) {
/* DOCUMENT job_georef_eaarla, conf
  This is a wrapper around georef_eaarla. Each accepted command-line option
  corresponds to an option or parameter of georef_eaarla as follows.

    --file-in-tld   corresponds to  rasts
    --file-in-gns   corresponds to  gns
    --file-in-ins   corresponds to  ins
    --file-in-ops   corresponds to  ops
    --daystart      corresponds to  daystart
    --file-out      corresponds to  outfile=

  Additionally, the following parameter not required by georef_eaarla is
  required as well:

    --gps_time_correction

  All options are required.
*/
  extern gps_time_correction;
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=, daystart=, gps_time_correction=;
  keyrequire, conf.file, in=, out=;
  keyrequire, conf.file.in, tld=, gns=, ins=, ops=;
  daystart = atoi(conf.daystart);
  gps_time_correction = atod(conf.gps_time_correction);

  require, "eaarla_wf.i";
  georef_eaarla, conf.file.in.tld, conf.file.in.gns, conf.file.in.ins,
    conf.file.in.ops, daystart, outfile=conf.file.out;
}

func job_pbd2las(conf) {
/* DOCUMENT job_pbd2las, conf
  This is a wrapper around pbd2las. Each accepted command-line option
  corresponds to an option or parameter of pbd2las as follows.

    --file-in                   corresponds to  fn_pbd
    --file-out                  corresponds to  fn_las=
    --mode                      corresponds to  mode=
    --v_maj                     corresponds to  v_maj=
    --v_min                     corresponds to  v_min=
    --cs                        corresponds to  cs=
    --cs_out                    corresponds to  cs_out=
    --pdrf                      corresponds to  pdrf=
    --encode_rn                 corresponds to  encode_rn=
    --include_scan_angle_rank   corresponds to  include_scan_angle_rank=
    --buffer                    corresponds to  buffer=
    --classification=           corresponds to  classification=
    --header                    corresponds to  header=

  The --cs and --cs_out options have special interpetations. These options are
  each supposed to be a space-delimited string, but spaces do not work well on
  the command line. To avoid issues, these strings are encoded as thus:
    base64_encode(strchar(CS),maxlen=-1)
  This ensures that the resulting argument is a simple string, without spaces.

  The --header option has a special interpretation. The header= option is
  supposed to be a Yeti hash, but that can't be passed via the command line.
  Thus, the hash is encoded as thus:
    base64_encode(z_compress(strchar(json_encode(HEADER)),9),maxlen=-1)
  This ensures that the resulting argument is a simple string, without
  quotation marks.
*/
  require, "general.i";
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;

  v_maj = pass_void(atoi, conf.v_maj);
  v_min = pass_void(atoi, conf.v_min);
  pdrf = pass_void(atoi, conf.pdrf);
  encode_rn = pass_void(atoi, conf.encode_rn);
  include_scan_angle_rank = pass_void(atoi, conf.include_scan_angle_rank);
  buffer = pass_void(atod, conf.buffer);
  classification = pass_void(atoi, conf.classification);

  cs = cs_out = header = [];
  if(anyof(conf(*,["cs","cs_out","header"]))) {
    require, "json_decode.i";
    require, "ascii_encode.i";

    if(conf(*,"cs"))
      cs = strchar(base64_decode(conf.cs));
    if(conf(*,"cs_out"))
      cs_out = strchar(base64_decode(conf.cs_out));
    if(conf(*,"header"))
      header = json_decode(strchar(z_decompress(base64_decode(conf.header))));
  }

  require, "las.i";
  pbd2las, conf.file.in, fn_las=conf.file.out, mode=conf.mode, v_maj=v_maj,
    v_min=v_min, cs=cs, cs_out=cs_out, pdrf=pdrf, encode_rn=encode_rn,
    include_scan_angle_rank=include_scan_angle_rank, buffer=buffer,
    classification=classification, header=header, verbose=0;
}

func job_las2pbd(conf) {
/* DOCUMENT job_las2pbd, conf
  This is a wrapper around las2pbd. Each accepted command-line option
  corresponds to an option or parameter of las2pbd as follows.

    --file-in     corresponds to  fn_las
    --file-out    corresponds to  fn_pbd=
    --format      corresponds to  format=
    --vname       corresponds to  vname=
    --fakemirror  corresponds to  fakemirror=
    --rgbrn       corresponds to  rgbrn=
    --date        corresponds to  date=
    --geo         corresponds to  geo=
    --zone        corresponds to  zone=
*/
  require, "general.i";
  require, "util_obj.i";
  require, "util_str.i";
  keyrequire, conf, file=;
  keyrequire, conf.file, in=, out=;

  fakemirror = pass_void(atoi, conf.fakemirror);
  rgbrn = pass_void(atoi, conf.rgbrn);
  geo = pass_void(atoi, conf.geo);
  zone = pass_void(atoi, conf.zone);

  require, "las.i";
  las2pbd, conf.file.in, fn_pbd=conf.file.out, format=conf.format,
    vname=conf.vname, fakemirror=fakemirror, rgbrn=rgbrn, verbose=0,
    date=conf.date, geo=geo, zone=zone;
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

  conf = save();
  if(numberof(argv) > 2)
    conf = _job_parse_options(argv(3:));
  
  if(strpart(job_func, 1:4) != "job_")
    error, "job function must start with \"job_\"";

  if(!symbol_exists(job_func))
    error, "unknown job function: "+job_func;

  f = symbol_def(job_func);
  if(!is_func(f))
    error, "invalid job function: "+job_func;

  f, conf;
}

// Only kick off a job if called in batch mode.
if(batch()) {
  // Must add the lidar-processing/src directory to the search path
  // Also, for safety sake, drop the ./ part of the default path
  set_path, strpart(get_includes()(0), :-5) + strpart(get_path(), 3:);
  require, "rrequire.i";
  __job_run, get_argv();
}
