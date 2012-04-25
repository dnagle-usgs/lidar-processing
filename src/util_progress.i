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
