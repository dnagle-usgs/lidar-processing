// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "yeti_regex.i";

func timer_init(&tstamp) {
/* DOCUMENT timer_init, &tstamp
  Initializes timer for use with timer_tick.
*/
  tstamp = array(double, 3);
  timer, tstamp;
}

func timer_tick(&t0, cur, cnt, msg) {
/* DOCUMENT timer_tick, &tstamp, cur, cnt, msg

  Displays progress information, updated once per second and at the end.

  Parameters:

    tstamp: A timer variable, initialized with timer_init.

    cur: The current value, indicating how far we are between 1 and cnt.

    cnt: The maximum value.

    msg: A string to indicate our progress. Default is " * cur/cnt". Do not
      append "\n" or "\r" to this.
*/
  t1 = array(double, 3);
  timer, t1;
  if(cur == cnt || t1(3) - t0(3) >= 1) {
    t0 = t1;
    default, msg, swrite(format=" * %i/%i", cur, cnt);
    write, format="%s\r", msg;
    if(cur == cnt) {
      write, format="%s", "\n";
    }
  }
}

func timer_remaining(t0, current, count, &tp, interval=, fmt=) {
/* DOCUMENT timer_remaining, t0, current, count;
  timer_remaining, t0, current, count, tp, interval=;

  Estimates how much time is remaining and displays to the screen.

  t0: Should be a timer variable initialized externally at the very start.
    This will not be altered.
  current: Current progress. If you're doing a for loop for(i = 1; i <=
    numberof(something); i++) then set current to i.
  count: Maximum items you're working towards. With the previous for loop,
    this would be numberof(something).

  tp: If set, this variable will be kept updated in place. It maintains the
    time at which we previously emitted a time remaining message.
  interval= Specifies that we should only emit the message if this many
    seconds have passed since the last one.
  fmt= Allows you to customize the output. The string will have the following
    tokens replaced by their relevant value:
      CURRENT - value for current (coerced to long)
      COUNT - value for count (coerced to long)
      ELAPSED - time elapsed
      REMAINING - time remaining
    All tokens are optional. Your string must include a newline if you wish
    to have one.

  Example:
    t0 = array(double, 3);
    timer, t0;
    for(i = 1; i <= numberof(data); i++) {
      // Do something here that takes some time!
      data = mywork(data);

      timer_remaining, t0, i, numberof(data);
    }

  Alternately:
    t0 = tp = array(double, 3);
    timer, t0;
    for(i = 1; i <= numberof(data); i++) {
      // Do something here that takes some time, but isn't so slow that you
      // want to constantly barrage the user with time remaining
      // information.
      data = mywork(data);

      timer_remaining, t0, i, numberof(data), tp, interval=20;
    }
*/
  default, fmt, "[ELAPSED elapsed. Estimated REMAINING remaining.]\n";
  t1 = array(double, 3);
  default, tp, t1;
  default, interval, -1;
  timer, t1;
  if(t1(3) - tp(3) >= interval) {
    tp = t1;
    elapsed = t1(3) - t0(3);
    remain = elapsed/double(current) * (count - current);
    fmt = regsub("CURRENT", fmt, swrite(format="%.0f", double(current)), all=1);
    fmt = regsub("COUNT", fmt, swrite(format="%.0f", double(count)), all=1);
    fmt = regsub("ELAPSED", fmt, seconds2prettytime(elapsed, maxparts=2), all=1);
    fmt = regsub("REMAINING", fmt, seconds2prettytime(remain, maxparts=2), all=1);
    write, format="%s", fmt;
    pause, 1;
  }
}

func timer_finished(t0, fmt=) {
/* DOCUMENT timer_finished, t0;
  Used in conjunction with timer_remaining to display how much time a process
  took.

  t0: Should be initialized at the start of the process.

  fmt= Allows you to customize the output. The string will have the following
    token replaced by its relevant value:
      ELAPSED - time elapsed in pretty-printed output
      SECONDS - time elapsed in seconds to four decimal places
    Your string must include a newline if you wish to have one.

  Example:
    t0 = array(double, 3);
    timer, t0;
    for(i = 1; i <= numberof(data); i++) {
      // Do something here that takes some time!
      data = mywork(data);

      timer_remaining, t0, i, numberof(data);
    }
    timer_finished, t0;
*/
  default, fmt, "Finished in ELAPSED.\n";
  t1 = array(double, 3);
  timer, t1;
  elapsed = t1(3) - t0(3);
  fmt = regsub("ELAPSED", fmt, seconds2prettytime(elapsed, maxparts=2), all=1);
  fmt = regsub("SECONDS", fmt, swrite(format="%.4f", elapsed), all=1);
  write, format="%s", fmt;
}

scratch = save(scratch, tmp, status_start, status_progress, status_finished,
    status_noop, status_enable, status_disable);
tmp = save(start, progress, finished, enable, disable, cache);

func status_start(count=, interval=, msg=) {
  use, cache;
  default, count, 1;
  default, interval, 1;
  default, msg, "Processing...";

  t0 = array(double, 3);
  timer, t0;
  tp = t0;

  save, cache, interval, t0, tp, pct=0.;

  tkcmd, "::l1pro::status::start "+swrite(count)+" {"+msg+"}";
}
start = status_start;

func status_progress(current, count, msg=) {
  use, cache;

  update = 0;

  pct = double(current)/count;
  if(abs(pct - cache.pct) > 0.005) {
    save, cache, pct;
    update = 1;
  }

  t1 = cache.t0;
  timer, t1;
  if(t1(3) - cache.tp(3) >= cache.interval) {
    save, cache, tp=t1;
    update = 1;
  }

  if(!update) return;

  cmd = "";
  if(!is_void(msg)) cmd = "set ::status(template) {"+msg+"}; ";
  cmd += "::l1pro::status::progress "+swrite(current)+" "+swrite(count);
  tkcmd, cmd;
}
progress = status_progress;

func status_finished {
  tkcmd, "::l1pro::status::finished";
}
finished = status_finished;

func status_noop(a, b, count=, interval=, msg=) {}

func status_enable(fncs, prior) {
  default, prior, _ytk;
  result = status.cache.enabled;
  if(prior && _ytk) {
    save, status, start=fncs.start, progress=fncs.progress,
      finished=fncs.finished;
    save, status.cache, enabled=1;
  } else {
    status, disable;
  }
  return result;
}
enable = closure(status_enable, save(start, progress, finished));

func status_disable(fncs, void) {
  result = status.cache.enabled;
  save, status.cache, enabled=0;
  save, status, start=fncs.noop, progress=fncs.noop,
    finished=fncs.noop;
  return result;
}
disable = closure(status_disable, save(noop=status_noop));

if(!_ytk) {
  start = progress = finished = status_noop;
}

cache = save(enabled=_ytk!=0);

local status; status = restore(tmp); restore, scratch;
/* DOCUMENT status

  The status object is used to send status and progress information to the
  l1pro GUI status area. This is primarily used to give progress information
  during long-running processes.

  The status object has three subcommands:

  status, start, count=, interval=, msg=
    Used at the start of a process to initialize the status display.
    Parameters:
        count= Specifies the number of steps in the task. Only necessary if
          msg= uses the COUNT substitution. Defaults to 1.
        interval= The interval at which the time display will be updated.
          Defaults to 1 second.
        msg= The message to display in the status area. This can optionally
          have two substitution keywords: COUNT and CURRENT. These will be
          substituted based on what's passed to 'status, progress'. (For the
          initial display, current will be 0 and count will be 1 or what is
          passed via count=.) Default is "Processing...".
    This will initialize the status text using the given MSG. The time
    remaining will be blanked, and the progress bar will be emptied. Note that
    this can also be used to update the status message arbitrarily in between
    tasks.

  status, progress, current, count
    Used during the process to update the progress information. CURRENT is the
    current numerical value indicating how far through to COUNT the process is.
    If the time elapsed since the last update is more then INTERVAL, the status
    message and time remaining will be updated. If the percent progress has
    changed by more than 0.5%, the progress bar will be updated.

  status, finished
    Used to reset the status when processing is finished. The status text will
    be set to "Ready.", the time remaining will be cleared, and the progress
    bar will be emptied.

  status, disable
  enabled = status(disable,)
    This will disable the status framework, making all commands no-ops. It
    returns the previous state for status, 1 if it was enabled and 0 if it
    was not.

  status, enable
    This will re-enable the status framework if YTK is available. Otherwise,
    all commands will remain no-ops.

  status, enable, enabled
    If "enabled" is 1, it will enable the status framework if YTK is
    available. Otherwise, it will disable.

  If you need to disable the status framework for a block of code, use this
  pattern:

    prog_enabled = status(disable,)
    // code goes here...
    status, enable, prog_enabled

  The above patterns will function properly even if you have nested disabled
  blocks.

  If YTK is not available at startup, all of these functions will be no-ops.
*/
