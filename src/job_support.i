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

    > obj_show, _job_parse_options(["--foo", "1", "--bar-a", "2", \
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
  process_argv(). It must be an array of strings. ARGV(1) is the job function
  to run. ARGV(2:) is optional (though it wouldn't make sense to omit) and will
  be passed to the function specified as they are (that is, as an array of
  strings).

  So, __job_run(argv) is roughly equivalent to:
    symbol_def(argv(1)), argv(2:)
*/
  // first argument is job function
  // remaining arguments pass to job function
  if(numberof(argv) < 1)
    error, "must specify job function";
  job_func = argv(1);

  conf = save();
  if(numberof(argv) > 1)
    conf = _job_parse_options(argv(2:));
  else
    conf = _job_parse_options([]);

  if(strpart(job_func, 1:4) != "job_")
    error, "job function must start with \"job_\"";

  // Restore env, if provided
  if(conf(*,"jobenv"))
    jobs_env_unwrap, conf.jobenv;

  // Only run hook if hooks are available (via jobenv)
  if(!is_void(hook_invoke))
    restore, hook_invoke("job_run", save(job_func, conf));

  if(!symbol_exists(job_func))
    error, "unknown job function: "+job_func;

  f = symbol_def(job_func);
  if(!is_func(f))
    error, "invalid job function: "+job_func;

  f, conf;
}

func jobs_env_wrap(fn) {
/* DOCUMENT jobs_env_wrap, "<filename>"
  Wraps up (part of) the current environment and saves it to file for use by a
  job. This is intended to be unwrapped by jobs_env_unwrap. It should be
  provided to the job as --jobenv <filename>, which will trigger its
  unwrapping.

  By default, the following things are saved:
    - the variable 'curzone'
    - the list of loaded plugins
    - all current hooks
    - all current handlers

  By using the hook "jobs_env_wrap", calling code can:
    - save additional variables
    - specify source files

  Calling code can also potentially add other arbitrary items, provided a hook
  is set for jobs_env_unwrap to specify how to handle those items.

  See jobs_env_unwrap for info on how the above are interpreted.
*/
  extern curzone;

  env = save(
    vars=save(curzone),
    plugins=plugins_loaded(),
    hooks=hook_serialize(),
    handlers=handler_serialize(),
    includes=[]
  );

  restore, hook_invoke("jobs_env_wrap", save(env, fn));

  save, env, vars=serialize(env.vars);
  mkdirp, file_dirname(fn);
  obj2pbd, env, fn;
}

func jobs_env_unwrap(fn) {
/* DOCUMENT jobs_env_unwrap, "<filename>"
  Unwraps a wrapped environment saved by jobs_env_wrap.

  This will do the following (in this order):
    - Load any plugins specified
    - Source any include files specified
    - Restore any variables saved
    - Restore hooks and handlers
    - Invoke the hook "jobs_env_unwrap"
*/
  require, "eaarl.i";
  env = pbd2obj(fn);

  if(numberof(env.plugins)) {
    plugins_load, env.plugins;
  }

  for(i = 1; i <= numberof(env.includes); i++)
    require, env.includes(i);

  if(is_pointer(env.vars))
    restore, deserialize(env.vars);

  if(numberof(env.hooks)) {
    require, "hook.i";
    hook_deserialize, env.hooks, clear=1;
  }

  if(numberof(env.handlers)) {
    require, "handler.i";
    handler_deserialize, env.handlers, clear=1;
  }

  hook_invoke, "jobs_env_unwrap", save(env, fn);
}

func jobs_env_include(fn) {
/* DOCUMENT jobs_env_include;
  -or- jobs_env_include, "<filename>";

  This function lets you easily add custom include files to be loaded during
  job execution. This lets you easily create a file with custom code that will
  get included.

  The simplest way to use the function is to simply add "jobs_env_include;" to
  your include file. Then load your include file into your current ALPS
  session. Your include file will automatically be added to the list of files
  included by jobs.

  You can also manually specify an include file (or an array of include files)
  to be added.

  This is primarily intended for use during development/testing of new code
  that isn't yet part of ALPS. Avoid having your include file do much on load;
  be mindful that it'll be included by ALL jobs that run.

  (Technically speaking, omitting the filename means that the default filename
  is current_include(). This only works if you include the file at some point.
  It also means that omitting the filename when using the function
  interactively is a no-op, since current_include() returns [] on the Yorick
  command line.)
*/
  if(is_void(fn)) fn = current_include();
  save, __jobs_env_include_hook.data, includes=set_remove_duplicates(grow(
    __jobs_env_include_hook.data.includes, fn));
  hook_add, "jobs_env_wrap", "__jobs_env_include_hook";
}

func jobs_env_include_remove(fn) {
/* DOCUMENT jobs_env_include_remove, "<filename>";
  Removes a custom include file that was added via jobs_env_include.
*/
  save, __jobs_env_include_hook.data, includes=set_difference(
    __jobs_env_include_hook.data.includes, fn);
  if(is_void(__jobs_env_include_hook.data.includes))
    hook_remove, "jobs_env_wrap", "__jobs_env_include_hook";
}

func __jobs_env_include_hook(data, env) {
/* DOCUMENT env = __jobs_env_include_hook(env);
  Hook function used by jobs_env_include.
*/
  save, env.env, includes=grow(env.env.includes, data.includes);
  return env;
}
__jobs_env_include_hook = closure(__jobs_env_include_hook, save(includes=[]));

func jobs_env_vars(vnames) {
/* DOCUMENT jobs_env_vars, "<varname>";
  -or- jobs_env_vars, ["<varname1>", "<varname2>", ...];

  This function lets you easily add custom variables from your current session
  that should be copied and used during job execution.

  The argument to the function is a string (or array of strings) specifying the
  variable name to transfer. The variable referred to must be a scalar or array
  value that can be saved to a pbd file.

  The variable values aren't retrieved until the Makeflow for the jobs is
  created.

  Be mindful that the variables you specify will be used for ALL jobs that run.
  You may wish to remove the variables you add using jobs_env_vars_remove after
  the Makeflow is initialized.
*/
  save, __jobs_env_vars_hook.data, vars=set_remove_duplicates(grow(
    __jobs_env_vars_hook.data.vars, vnames));
  hook_add, "jobs_env_wrap", "__jobs_env_vars_hook";
}

func jobs_env_vars_remove(vnames) {
/* DOCUMENT jobs_env_vars_remove, "<varname>";
  -or- jobs_env_vars_remove, ["<varname1>", "<varname2>", ...];
  Removes a variable added by jobs_env_vars.
*/
  save, __jobs_env_vars_hook.data, vars=set_difference(
    __jobs_env_vars_hook.data.vars, vnames);
  if(is_void(__jobs_env_vars_hook.data.vars))
    hook_remove, "jobs_env_wrap", "__jobs_env_vars_hook";
}

func __jobs_env_vars_hook(data, env) {
/* DOCUMENT env = __jobs_env_vars_hook(env);
  Hook function used by jobs_env_vars_hook.
*/
  for(i = 1; i <= data.vars; i++)
    save, env.env.vars, data.vars(i), symbol_def(data.vars(i));
  return env;
}
