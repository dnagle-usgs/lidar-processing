/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
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
*/
   if(is_void(var)) var = val;
}

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

func timer_remaining(t0, current, count, &tp, interval=) {
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
   t1 = array(double, 3);
   default, tp, t1;
   default, interval, -1;
   timer, t1;
   if(t1(3) - tp(3) >= interval) {
      tp = t1;
      elapsed = t1(3) - t0(3);
      remain = elapsed/double(current) * (count - current);
      write, format="[%s elapsed. Estimated %s remaining.]\n",
         seconds2prettytime(elapsed, maxparts=2),
         seconds2prettytime(remain, maxparts=2);
   }
}

func timer_finished(t0) {
/* DOCUMENT timer_finished, t0;
   Used in conjunction with timer_remaining to display how much time a process
   took.

   t0: Should be initialized at the start of the process.

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
   t1 = array(double, 3);
   timer, t1;
   elapsed = t1(3) - t0(3);
   write, format="Finished in %s.\n", seconds2prettytime(elapsed, maxparts=2);
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

func h_merge(..) {
/* DOCUMENT h_merge(objA, objB, objC, ...)
   Merges all of its arguments into a single hash. They must all be Yeti hash
   tables.

   If two objects share a key and both values are hashes, then the result will
   merge those two hashes together to set the value of that key (using h_merge,
   recursively).

   If two objects share a key and either of the two values are not a hash, then
   the latter object's value will overwrite the earlier object's value in the
   resulting hash.
*/
// Original David Nagle 2008-09-10
   obj = h_new();
   while(more_args()) {
      src = next_arg();
      keys = h_keys(src);
      for(i = 1; i <= numberof(keys); i++) {
         if(h_has(obj, keys(i))) {
            if(typeof(src(keys(i))) == "hash_table"
                  && typeof(obj(keys(i))) == "hash_table") {
               h_set, obj, keys(i), h_merge(obj(keys(i)), src(keys(i)));
               continue;
            }
         }
         h_set, obj, keys(i), src(keys(i));
      }
   }
   return obj;
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

func assign(ary, &v1, &v2, &v3, &v4, &v5, &v6, &v7, &v8, &v9, &v10) {
/* DOCUMENT assign, ary, v1, v2, v3, v4, v5, .., v10

   Assigns the values in an array to the specified variables. For example:

      > assign, [2, 4, 6], a, b, c
      > a
      2
      > b
      4
      > c
      6
*/
// Original David Nagle 2008-12-29
   __assign, ary, 1, v1;
   __assign, ary, 2, v2;
   __assign, ary, 3, v3;
   __assign, ary, 4, v4;
   __assign, ary, 5, v5;
   __assign, ary, 6, v6;
   __assign, ary, 7, v7;
   __assign, ary, 8, v8;
   __assign, ary, 9, v9;
   __assign, ary, 10, v10;
}

func __assign(&ary, &idx, &var) {
/* DOCUMENT __assign, &ary, &idx, &var
   Helper function for assign.
*/
   if(numberof(ary) >= idx) var = ary(idx);
}

func pbd_append(file, vname, data, uniq=) {
/* DOCUMENT pbd_append, file, vname, data, uniq=
   
   This creates or appends "data" in the pbd "file" using the variable name
   "vname". If appending, it will merge "data" with whatever data is pointed to
   by the existing pbd's vname variable. However, when writing, the vname will
   be set to "vname".

   By default, the option uniq= is set to 1 which will ensure that all merged
   data points are unique by eliminating duplicate data points with the same
   soe. If duplicate data should not be eliminated based on soe, then set
   uniq=0.

   Note that if "file" already exists, then the struct of its data must match
   the struct of "data".

   See also: pbd_save pbd_load
*/
// Original David Nagle 2008-07-16
   default, uniq, 1;
   if(file_exists(file))
      data = grow(pbd_load(file), unref(data));
   if(uniq)
      data = data(set_remove_duplicates(data.soe, idx=1));
   pbd_save, file, vname, data;
}

func pbd_save(file, vname, data) {
/* DOCUMENT pbd_save, file, vname, data
   This creates the pbd "file" using variable name "vname" to store "data". If
   the file already exists, it will be overwritten.

   See also: pbd_append pbd_load
*/
// Original David Nagle 2009-12-28
   // Sanitize vname
   if(regmatch("^[0-9]", vname))
      vname = "v" + vname;
   vname = regsub(" ", vname, "_", all=1);
   vname = regsub("-", vname, "_", all=1);

   f = createb(file, i86_primitives);
   add_variable, f, -1, vname, structof(data), dimsof(data);
   get_member(f, vname) = data;
   save, f, vname;
   close, f;
}

func pbd_load(file, &err, &vname) {
/* DOCUMENT data = pbd_load(filename);
   data = pbd_load(filename, err);
   data = pbd_load(filename, , vname);
   data = pbd_load(filename, err, vname);

   Loads data from a PBD file. The PBD file should have (at least) two
   variables defined. The first should be "vname", which specifies the name of
   the other variable. That variable should contain the data.

   If everything is in order then the data is returned; otherwise [] is
   returned.

   Output parameter "err" will contain a string indicating what error was
   encountered while loading the data. A nil string indicates no error was
   encountered. A return result of [] can mean that an error was encountered OR
   that the file contained an empty data array; these cases can be
   differentiated by the presence or absence of an error message in err.

   Output parameter "vname" will contain the value of vname. A nil string
   indicates that no vname was found (which only happens when there's an
   error).

   Possible errors:
      "file does not exist"
      "file not readable"
      "not a PBD file"
      "no vname"
      "invalid vname"

   See also: pbd_append pbd_save
*/
// Original David Nagle 2009-12-21
   err = string(0);
   vname = string(0);

   if(!file_exists(file)) {
      err = "file does not exist";
      return [];
   }

   if(!file_readable(file)) {
      err = "file not readable";
      return [];
   }

   if(!is_pbd(file)) {
      err = "not a PBD file";
      return [];
   }

   f = openb(file);
   vars = get_vars(f);

   if(!is_present(vars, "vname")) {
      err = "no vname";
      return [];
   }

   vname = f.vname;
   if(!is_present(vars, vname)) {
      err = "invalid vname";
      return [];
   }

   data = get_member(f, vname);
   return unref(data);
}

func is_pbd(file) {
   yPDBopen = 1;
   f = open(file, "rb");
   result = ! _not_pdb(f, 0);
   close, f;
   return result;
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

func structeq(a, b) {
/* DOCUMENT structeq(a, b)
   Returns boolean indicating whether the given structures are the same.

   The normal expectation is that the following sequence should always provide
   consist results:

   > test = array(GEOALL, 20);
   > structof(test) == GEOALL
   1

   However, if the stucture GEOALL is redefined, the test fails:

   > test = array(GEOALL, 20);
   > #include "geo_bath.i"
   > structof(test) == GEOALL
   0

   This function works around this unexpected result by comparing the string
   representation of the respective structures if the structures themselves do
   not appear to match.

   > test = array(GEOALL, 20);
   > #include "geo_bath.i"
   > structeq(structof(test), GEOALL)
   1
*/
// Original David Nagle 2009-10-01
   if(a == b) return 1;
   return print(a)(sum) == print(b)(sum);
}

func structeqany(a, ..) {
/* DOCUMENT structeqany(a, s1, s2, s2, ...)
   Returns boolean indicating whether the structure 'a' matches any of the
   structures s1, s2, s3, etc. Any number of structures can be given. Returns 1
   if it matches any, otherwise 0.

   > test = array(GEOALL, 20);
   > structeqany(structof(foo), VEG, VEG_, VEG__)
   0
   > test = array(VEG_, 20);
   > structeqany(structof(foo), VEG, VEG_, VEG__)
   1
*/
// Original David Nagle 2009-10-01
   while(more_args()) {
      if(structeq(a, next_arg()))
         return 1;
   }
   return 0;
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
