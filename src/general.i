// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func default(&var, val) {
/* DOCUMENT default, &variable, value
   
   This function is meant to be used at the beginning of functions as a helper.
   It will set the variable to value if and only if the variable is void. This
   is a very simple wrapper intended to help abbreviate code and help it
   self-document better.

   Parameters:

      variable: The variable to be set to a default value, if void. It will be
         updated in place.

      value: The default value.

   SEE ALSO: require_keywords
*/
   if(is_void(var)) var = val;
}

func require_keywords(args) {
/* DOCUMENT require_keywords, key1, key2, key3
   This checks each of the given variables to make sure that the user provided
   a non-void value for them.

   For example, consider this function:

      func increment(&x, amount=) {
         require_keywords, amount;
         x += amount;
      }

   If the user omits the "amount=" keyword (or if they provide it, but define
   it to []), then they will receive an error. Otherwise, it works. To
   illustrate:

      > x=0
      > increment, x, amount=5
      > x
      5
      > increment, x
      ERROR (increment) Missing required keyword: amount
      WARNING source code unavailable (try dbdis function)
      now at pc= 3 (of 21), failed at pc= 7
       To enter debug mode, type <RETURN> now (then dbexit to get out)
      >

   SEE ALSO: default
*/
// Original David Nagle 2010-07-29
   arg_count = args(0);
   for(i = 1; i <= arg_count; i++)
      if(is_string(args(-,i)) && is_void(args(i)))
         error, "Missing required keyword: "+args(-,i);
}
errs2caller, require_keywords;
wrap_args, require_keywords;

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
         ELAPSED - time elapsed
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

func popen_rdfile(cmd) {
/* DOCUMENT popen_rdfile(cmd)
   This opens a pipe to the command given and reads its output, returning it as
   an array of lines. (It combines popen and rdfile into a single function,
   thus the name.)
*/
   f = popen(cmd, 0);
   lines = rdfile(f);
   close, f;
   return lines;
}

func quartiles(ary) {
/* DOCUMENT quartiles(ary)
   Returns the first, second, and third quartiles for the array.

   See also: median
*/
// Original David Nagle 2008-03-26
   ary = ary(sort(ary));
   q1 = median(ary(:numberof(ary)/2));
   q2 = median(ary);
   q3 = median(ary(::-1)(:numberof(ary)/2));
   return [q1, q2, q3];
}

func bound(val, bmin, bmax) {
/* DOCUMENT bound(val, bmin, bmax)
   Constrains a value to a set of bounds. Note that val can have any
   dimensions.
   
   If bmin <= val <= bmax, then returns val
   If val < bmin, then returns bmin
   if bmax < val, then returns bmax
*/
// Original David Nagle 2008-11-18
   return min(bmax, max(bmin, val));
}

func get_user(void) {
/* DOCUMENT get_user()
   Returns the current user's username. If not found, returns string(0).
*/
// Original David Nagle 2009-06-04
   if(get_env("USER")) return get_env("USER");
   return string(0);
}

func get_host(void) {
/* DOCUMENT get_host()
   Returns the current host's hostname. If not found, returns string(0).
*/
// Original David Nagle 2009-06-04
   if(get_env("HOSTNAME")) return get_env("HOSTNAME");
   if(get_env("HOST")) return get_env("HOST");
   return string(0);
}

func binary_search(ary, val, exact=, inline=) {
/* DOCUMENT binary_search(ary, val, exact=, inline=)
   Searches in ary for val. The ary must be sorted and must contain numerical
   data. Will return the index corresponding to the value in ary that is
   nearest to val.

   Parameters:
      ary - Array of data to search in. Must be numerical, sorted, and
         one-dimensional.
      val - Value to search for. Must be a scalar number.

   Options:
      exact= By default, the closest match is returned. If exact=1, it will
         instead only return the index if it finds an exact match. If no match
         is found, it will return [].
      inline= If enabled, returns the matched value instead of the index.
*/
   default, exact, 0;
   default, inline, 0;

   // Initial bounds cover entire list
   b0 = 1
   b1 = numberof(ary);

   // Make sure the value is in bounds. If not... this becomes trivial.
   if(val <= ary(b0))
      b1 = b0;
   else if(ary(b1) <= val)
      b0 = b1;

   // Narrow bounds until it's either a single value or adjacent indexes
   while(b1 - b0 > 1) {
      pivot = long((b0 + b1) / 2.);
      pivotVal = ary(pivot);

      if(pivotVal == val) {
         b0 = b1 = pivot;
      } else if(pivotVal < val) {
         b0 = pivot;
      } else {
         b1 = pivot;
      }
   }

   // Select the nearest index
   nearest = [];
   if(b0 == b1) {
      nearest = b0;
   } else {
      db0 = abs(val - ary(b0));
      db1 = abs(val - ary(b1));
      nearest = (db0 < db1) ? b0 : b1;
   }

   // Handle exact=1
   if(exact && ary(nearest) != val)
      nearest = [];

   // Handle inline=1
   if(inline && !is_void(nearest))
      nearest = ary(nearest);

   return nearest;
}

func bytes2text(bytes) {
/* DOCUMENT bytes2text(bytes)
   Converts a value in bytes to a textified representation in bytes, KB, MB, or
   GB. Works on scalars and arrays.
*/
   dims = dimsof(bytes);
   bytes = long(reform(bytes, numberof(bytes)));
   result = array(string, numberof(bytes));
   zero = !bytes;
   if(anyof(zero)) {
      result(where(zero)) = "0 bytes";
      bytes(where(zero)) = 1;
   }
   mag = log(bytes)/log(1024);
   mag = ymedian(transpose([0, 3, long(floor(mag-0.01))]));
   low = !result & mag == 0;
   if(anyof(low))
      result(where(low)) = swrite(format="%d bytes", bytes(where(low)));
   remaining = !result;
   if(anyof(remaining)) {
      w = where(remaining);
      fbytes = bytes(w) / (1024.^mag(w));
      suffix = ["KB", "MB", "GB"](mag(w));
      result(w) = swrite(format="%.2f %s", fbytes, suffix);
   }
   if(dims(1) == 0)
      return result(1);
   else
      return reform(result, dims);
}

func z_compress(data) {
/* DOCUMENT z_compress(data)
   Wrapper around z_deflate/z_flush that compresses data in a single call.
   Returns the compressed data.
   SEE ALSO: z_flush z_deflate z_inflate z_decompress
*/
// Original David B. Nagle 2010-07-23
   return z_flush(z_deflate(), data);
}

func z_decompress(data, type) {
/* DOCUMENT z_decompress(data, type)
   Wrapper around z_inflate/z_flush that decompresses data in a single call.
   Returns the decompressed data. The type parameter is optional; if provided,
   it should be the data type to decompress as (by default, char).
   SEE ALSO: z_flush z_deflate z_inflate z_compress
*/
// Original David B. Nagle 2010-07-23
   default, type, char;
   buffer = z_inflate();
   flag = z_inflate(buffer, data);
   if(flag == 0 || flag == -1) {
      return z_flush(buffer, type);
   } else {
      error, swrite(format="could not decompress, error code %d", flag);
   }
}
