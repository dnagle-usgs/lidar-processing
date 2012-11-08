// vim: set ts=2 sts=2 sw=2 ai sr et:

require, "ytime.i";

/* DOCUMENT __logfh
  This is the file handle used for logging by the logger command.
*/
local __logfh;

func logger_logdir(dir, void) {
/* DOCUMENT logger_logdir()
  Returns the directory used by logging.

  SEE ALSO: logger_logfn logger_logfh
*/
  if(dir) return dir;

  // If running within a normal ALPS session, alpsrc.log_dir should be defined.
  // If not running in a normal ALPS session, attempt to retrieve the log_dir
  // from the current environment. Otherwise, use the default "/tmp/alps.log/".
  if(is_func(is_hash) && is_hash(alpsrc) && is_string(alpsrc.log_dir)) {
    dir = alpsrc.log_dir;
  } else {
    dir = get_env("ALPS_LOG_DIR");
    if(!strlen(dir))
      dir = "/tmp/alps.log/";
  }

  if(strpart(dir, 0:) != "/") dir += "/";

  // This ensures that the log dir is only calculated once.
  logger_logdir = closure(logger_logdir.function, dir);

  return dir;
}
logger_logdir = closure(logger_logdir, string(0));

func logger_logfn_datetime(soe) {
/* DOCUMENT logger_logfn_datetime(soe)
  Returns the YYMMDD.HHMMSS string corresponding to the given SOE to be used in
  a log filename.
*/
  ts = strchar(soe2iso8601(soe));
  ts = strchar(ts([3,4,6,7,9,10]))+"."+strchar(ts([12,13,15,16,18,19]));
  return ts;
}

func logger_logfn(fn, void) {
/* DOCUMENT logger_logfn()
  Returns the filename used by logging in the current session.

  SEE ALSO: logger_logdir logger_logfh
*/
  if(fn) return fn;

  log_dir = logger_logdir();

  // If running within YTK, _starttime will be defined as the time when YTK
  // started. Otherwise, best we can do is to use the current time.
  started = 0;
  if(is_numerical(_starttime))
    started = _starttime;
  else
    started = getsoe();
  started = long(started);

  // If running within YTK, _pid will be defined to YTK's process ID.
  // Otherwise, if the get_pid C-ALPS function is available, we can use that to
  // get this Yorick's process ID. Otherwise, we have no way to get a process
  // ID so use 0.
  pid = 0;
  if(is_numerical(_pid))
    pid = _pid;
  else if(is_func(get_pid))
    pid = get_pid();
  pid = long(pid);

  // Construct file name as YYMMDD.HHMMSS.PID
  ts = logger_logfn_datetime(started);
  fn = swrite(format="%s/%s.%d", log_dir, ts, pid);

  // Append username if available (only under YTK)
  user = [];
  if(_user)
    user = _user;
  else if(is_func(get_user))
    user = get_user();
  if(user)
    fn += "." + user;

  // This ensures that the log file is only calculated once.
  logger_logfn = closure(logger_logfn.function, fn);

  return fn;
}
logger_logfn = closure(logger_logfn, string(0));

func logger_logfh(void) {
/* DOCUMENT logger_logfh()
  Opens a filehandle to the logging file used by the logger command. File is
  opened for appending only. This is only intended to be used by the logger
  command.

  If a filehandle cannot be created, 0 is returned instead.

  SEE ALSO: logger __logger __logfh logger_logfn logger_logdir
*/
  mkdirp, logger_logdir();
  fn = logger_logfn();

  if(catch(0x02)) {
    return 0;
  }
  return open(fn, "a");
}

scratch = save(scratch, __logger);
func __logger(level, msg) {
/* DOCUMENT __logger, level, msg
  Command that implements logger functionality. When a logging level is
  enabled, logger passes through to __logger.

  SEE ALSO: logger open_logfh
*/
  extern __logfh;
  if(!__logfh) {
    if(__logfh != 0) {
      __logfh = logger_logfh();
    }
    if(!__logfh) return;
  }

  // Messages in the log file are formatted as:
  // YYYY-MM-DD HH:MM:SS [level] <yor> MESSAGE
  level = swrite(format="%5s", strpart(level, 1:5));
  prefix = soe2iso8601(getsoe()) + " ["+level+"] <yor>";

  parts = [string(0), msg];
  do {
    parts = strtok(parts(2), "\n");
    write, __logfh, format="%s %s\n", prefix, parts(1);
  } while(parts(2));
  fflush, __logfh;
}

func logger_level(cmd, level) {
/* DOCUMENT logger_level, "<level>"
  Sets the level at which to log. Level should be one of: "none", "error",
  "warn", "info", "debug", or "trace". Refer to documentation for logger for
  details on log levels.

  SEE ALSO: logger
*/
  extern logger;
  if(logger && logger(info))
    logger, info, "changing logging level to "+pr1(level);
  levels = ["error", "warn", "info", "debug", "trace"];
  if(level == "none") {
    w = 0;
  } else {
    w = where(level == levels);
    w = numberof(w) ? w(1) : 4;
  }
  logger = save();
  for(i = 1; i <= w; i++) {
    save, logger, levels(i), closure(cmd, levels(i));
  }
  for(i = w+1; i <= 5; i++) {
    save, logger, levels(i), 0;
  }
  if(logger(info)) logger, info, "logging at level "+level;
}

logger_level = closure(logger_level, __logger);
restore, scratch;

/*
  Implementation note:

  See the implementation note at the top of assert.i for an explanation for why
  logger invocations are protected with if tests rather than redefining them to
  noop.
*/

local logger;
/* DOCUMENT logger
  Usage:
    if(logger(error)) logger, error, "<message>"
    if(logger(warn)) logger, warn, "<message>"
    if(logger(info)) logger, info, "<message>"
    if(logger(debug)) logger, debug, "<message>"
    if(logger(trace)) logger, trace, "<message>"

  Logs the given message to the log file at the given log level, if the given
  log level is enabled.

  Calls to the logger command should ALWAYS be protected by if statements as
  shown above. If a log level is disabled, the subcommand will resolve to the
  integer 0 instead of a function; that in turn will generate an error if the
  log level is disabled and the call is not protected by an if statement.

  The benefit of protecting with an if statement is that, when disabled, the
  cost of the logger call is reduced to a single boolean check. If your message
  string has any overhead, that overhead is thus negated.

  The logger command is guaranteed to be available in ALPS. However, it may not
  be automatically available in some non-ALPS scenarios, such as distributed
  job calls. In such code, if you do not wish to explicitly require the logger
  library, you can instead protect logger calls as follows:

    if(logger && logger(debug)) logger, debug, "<message>"

  -- Log File Location --
  The location of the log file is determined as follows.
    - If running in ALPS, then "alpsrc" should be available and should contain
      a "log_dir" setting. If present, this is used.
    - Otherwise, if an environment variable ALPS_LOG_DIR is available, it is
      used.
    - Otherwise, /tmp/alps.log/ is used.

  -- Log File Name --
  The log file will be given the name YYMMDD.HHMMSS.PID or
  YYMMDD.HHMMSS.PID.USERNAME. This encodes the start-up time (as a date and
  time), the process ID, and (if available) the current user's login name. More
  specifically:
    - If running under YTK, the date/time will be when Tcl started and the
      process ID will be that of YTK.
    - If not running under YTK, the date/time will be the time of the first log
      message.
    - If not running under YTK and get_pid is available, then Yorick's PID is
      used. Otherwise, the PID will be set to 0.
    - The username will only be included if it's available. It will always be
      available under ALPS/YTK. Otherwise, it may or may not be available.

  -- Log Levels --
  Five log levels are defined. They should be used as follows.

    error - Something really bad happened, something that most likely
      interrupted what the user was doing with an error.

    warn - Something somewhat bad happened. A deprecated function was used, a
      function was used in a poor way, an "almost error" occured, etc. This is
      something undesired and/or unexpected, but not exactly wrong.

    info - Interesting events in normal usage. Startup and shutdown info.
      Invocation of important commands (such as batch commands). Loading of
      files.

    debug - Detailed information about the flow through the system.

    trace - Extremely detailed inforamtion that one would not normally want
      even during debugging. This might include dumping of lots of data or the
      logging of state during each iteration of a large loop.

  The level at which logging occurs is set by the logger_level command. By
  default, ALPS logs at the "debug" level and higher. This corresponds to this
  invocation:

    logger_level, "debug"

  It is expected that ALPS will usually log at the "debug" level. If very high
  performance is critical, it may be helpful to set the debug level to "info"
  but this is generally discouraged. The "trace" debug level should only be
  turned on when there is a specific need for it, as it may lead to excessively
  large log files.

  SEE ALSO: logger_level assert
*/

// Initialize logger. Use alpsrc setting if available; otherwise start at
// "debug".
if(is_void(logger)) {
  if(is_func(is_hash) && is_hash(alpsrc) && is_string(alpsrc.log_level))
    logger_level, alpsrc.log_level;
  else
    logger_level, "debug";
}

func logger_id(last, void) {
/* DOCUMENT logger_id()
  Returns a unique identifier that can be used within logging output to
  identify, for example, which function you're in. Always returns an odd number
  in parentheses followed by a space as a string, like so: "(1) ". (A similar
  utility function exists in Tcl that always returns an even number. The odd
  versus even distinction helps prevent confusion if they happen to
  interleave.)

  Here's an example of usage:

    func example(foo, bar) {
      log_id = logger_id();
      if(logger(debug)) {
        logger, debug, log_id+"Entering example()";
        logger, debug, log_id+"foo = "+pr1(foo);
        logger, debug, log_id+"bar = "+pr1(bar);
      }
      // do something with foo and bar...
      if(logger(debug)) logger, debug, log_id+"Leaving example()";
    }
*/
  last += 2;
  logger_id = closure(logger_id.function, last);
  return swrite(format="(%d) ", last);
}
logger_id = closure(logger_id, -1);

func logger_purge(days) {
/* DOCUMENTS logger_purge, <days>
  Purges (deletes) log files older than <DAYS>. If <DAYS> is non-positive, this
  is a no-op. Only the user's own log files are deleted.

  The log directory is determined as for open_logfh. If this directory does not
  exist, then this is a no-op.
*/
  if(assert) assert, is_numerical(days), "days is non-numeric";
  logid = logger_id();
  if(logger(debug)) logger, debug, logid+"logger_purge, "+pr1(days)+";";

  thresh = getsoe() - days * 86400;
  ts = logger_logfn_datetime(thresh);
  if(logger(debug)) logger, debug, logid+"datetime threshold = "+ts;

  log_dir = logger_logdir();
  if(logger(debug)) logger, debug, logid+"log_dir = "+log_dir;

  files = lsdir(log_dir);
  if(structof(files) == long) return;
  if(!numberof(files)) return;

  user = [];
  if(_user)
    user = _user;
  else if(is_func(get_user))
    user = get_user();
  if(!user) return;
  if(logger(debug)) logger, debug, logid+"restricting to user="+user;
  w = where(strglob("*."+user, files));
  if(!numberof(w)) return;
  files = files(w);

  w = where(files < ts);
  if(!numberof(w)) return;
  files = files(w);

  for(i = 1; i <= numberof(files); i++) {
    fn = log_dir + files(i);
    remove, fn;
    if(logger(info)) {
      if(noneof(lsdirs(log_dir) == files(i)))
        logger, info, "deleted old log: "+fn;
      else if(logger(debug))
        logger, debug, logid+"unable to delete old log: "+fn;
    }
  }
}
