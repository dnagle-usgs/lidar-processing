/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";
write, "$Id$";

local general_i;
/* DOCUMENT general.i
   
   This file contains an assortment of some general purpose functions.
   
   Functions to convert strings to numbers:

      atoi
      atof
      atod
   
   Utility functions:

      default
      timer_init
      timer_tick
      meta_init
      meta_build
      strsplit
      strjoin
      popen_rdfile
*/

func atoi(str) {
/* DOCUMENT atoi(str)
   
   Converts a string representation of a number into an integer.

   The following paramters are required:

      str: A string representation of an integer.
   
   Function returns:

      An integer value.
*/
   i = array(float, dimsof(str));
   sread, str, format="%f", i;
   return int(i);
}

func atof(str) {
/* DOCUMENT atof(str)
   
   Converts a string representation of a number into a float.

   The following paramters are required:

      str: A string representation of a float.
   
   Function returns:

      A float value.
*/
   f = array(float, dimsof(str));
   sread, str, format="%f", f;
   return f;
}

func atod(str) {
/* DOCUMENT atod(str)
   
   Converts a string representation of a number into a double.

   The following paramters are required:

      str: A string representation of a double.
   
   Function returns:

      A double value.
*/
   d = array(double, dimsof(str));
   sread, str, format="%f", d;
   return d;
}

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
   tstamp = 60 * 60 * 60;
}

func timer_tick(&tstamp, cur, cnt, msg) {
/* DOCUMENT timer_tick, &tstamp, cur, cnt, msg

   Displays progress information, updated once per second and at the end.

   Parameters:

      tstamp: A timer variable, initialized with timer_init.

      cur: The current value, indicating how far we are between 1 and cnt.

      cnt: The maximum value.

      msg: A string to indicate our progress. Default is " * cur/cnt". Do not
         append "\n" or "\r" to this.
*/
   if(tstamp != getsod() || cur == cnt) {
      tstamp = getsod();
      default, msg, swrite(format=" * %i/%i", cur, cnt);
      write, format="%s\r", msg;
      if(cur == cnt) {
         write, format="%s", "\n";
      }
   }
}

func strsplit(str, sep) {
/* DOCUMENT strsplit(str, sep)

   Given an input string (or array of strings), this will split the string(s)
   into arrays at each instance of the separator.

   A pair of separators with nothing between them results in "". If some of the
   strings in an array have more fields than others, the shorter-fielded ones
   will be padded with (nil).

   This will work only on one-dimensional arrays and scalar strings.

   Examples:

   > strsplit("hello,world", ",")
   ["hello","world"]

   > strsplit("foo,,bar", ",")
   ["foo","","bar"]

   > strsplit(["a b c", "1 2 3 4"], " ")
   [["a","1"],["b","2"],["c","3"],[(nil), "4"]]

   > strsplit("anythingSPLITcanSPLITseparate", "SPLIT")
   ["anything", "can", "separate"]

   In a one-dimensional array: If res is the result, then res(1,) contains the
   substrings for the first element, and res(,1) contains the first field of
   all elements.

   Original David Nagle
*/
   str = str;
   match = [];
   parts = array(string, dimsof(str), 1);
   res = regmatch(sep, str, match, indices=1);
   while(numberof(where(res))) {
      new = array(string, dimsof(str));
      w = where(match(1,) > 1 & res);
      if(numberof(w)) {
         idx = array(0, 2, numberof(w));
         idx(2,) = match(1,w) - 1;
         new(w) = strpart(str(w), idx);
         idx = array(0, 2, numberof(w));
         idx(1,) = match(2,w) - 1;
         idx(2,) = strlen(str(w));
         str(w) = strpart(str(w), idx);
      }
      w = where(match(1,) <= 1 & res);
      if(numberof(w)) {
         new(w) = "";
         idx = array(0, 2, numberof(w));
         idx(1,) = match(2,w) - 1;
         idx(2,) = strlen(str(w));
         str(w) = strpart(str(w), idx);
      }
      w = where(strlen(str) > 0 & !res);
      if(numberof(w)) {
         new(w) = str(w);
         str(w) = string(0);
      }
      grow, parts, new;
      res = regmatch(sep, str, match, indices=1);
   }
   w = where(strlen(str) > 0);
   if(numberof(w)) {
      new = array(string, dimsof(str));
      new(w) = str(w);
      grow, parts, new;
   }
   if(dimsof(parts)(1) > 1)
      return parts(,2:);
   else
      return parts(2:);
}

func strjoin(lst, sep) {
/* DOCUMENT strjoin(lst, sep)

   Given an input array of strings, this will join the strings into a single
   string, using the separator between each array item. If the array is not
   one-dimensional, it will be collapsed as str(*).

   Example: strjoin(["a", "b", "c"], "--") will return "a--b--c".

   See also: string
*/
   if(!numberof(lst)) return;
   return transpose([lst(*), sep])(*)(:-1)(sum);
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
/* bound(val, bmin, bmax)
   Constrains a value to a set of bounds. Note that val can have any
   dimensions.
   
   If bmin <= val <= bmax, then returns val
   If val < bmin, then returns bmin
   if bmax < val, then returns bmax
*/
// Original David Nagle 2008-11-18
   return min(bmax, max(bmin, val));
}
