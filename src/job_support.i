// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "job_commands.i";

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
