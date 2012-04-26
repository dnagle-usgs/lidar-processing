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
    status_msg);
tmp = save(start, progress, finished, cache, msg);

func status_start(count=, interval=, msg=) {
  use, cache;
  default, count, 1;
  default, interval, 1;
  default, msg, "Processing...";

  t0 = array(double, 3);
  timer, t0;
  tp = t0;

  save, cache, interval, msg, t0, tp, pct=0,
      has_current=strglob("*CURRENT*", msg),
      has_count=strglob("*COUNT*", msg);

  tkcmd, swrite(format="set ::status(message) {%s}", use(msg, 0, count));
  tkcmd, "set ::status(time) {--:--:--}";
  tkcmd, "set ::status(progress) 0";
}
start = status_start;

func status_progress(current, count) {
  use, cache;
  t1 = cache.t0;
  timer, t1;
  if(t1(3) - cache.tp(3) >= cache.interval) {
    save, cache, tp=t1;
    elapsed = t1(3) - cache.t0(3);
    remain = elapsed/double(current) * (count - current);
    tkcmd, swrite(format="set ::status(message) {%s}", use(msg, current, count));
    tkcmd, swrite(format="set ::status(time) {%s}", seconds2clocktime(remain));
  }
  pct = 100*double(current)/count;
  if(abs(pct - cache.pct) > 0.5) {
    save, cache, pct;
    tkcmd, swrite(format="set ::status(progress) {%f}", pct);
  }
}
progress = status_progress;

func status_finished {
  tkcmd, "set ::status(message) {Ready.}";
  tkcmd, "set ::status(time) {}";
  tkcmd, "set ::status(progress) 0";
}
finished = status_finished;

func status_msg(current, count) {
  use, cache;
  msg = cache.msg;
  if(cache.has_current) {
    fmt = is_integer(current) ? "%d" : "%f";
    msg = regsub("CURRENT", msg, swrite(format=fmt, current), all=1);
  }
  if(cache.has_count) {
    fmt = is_integer(count) ? "%d" : "%f";
    msg = regsub("COUNT", msg, swrite(format=fmt, count), all=1);
  }
  return msg;
}
msg = status_msg;

cache = save();

local status; status = restore(tmp); restore, scratch;
/* DOCUMENT status
  The status object is used to send status and progress information to the
  l1pro GUI status area. This is primarily used to give progress information
  during long-running processes.

  The status object has three subcommands:

  status, start, count=, interval=, msg=
    Used at the start of a process to initialize the status display. Parameters:
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
    remaining will be updated to "--:--:--", and the progress bar will be
    emptied.

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
*/
