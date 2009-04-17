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

   The following parameters are required:

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

   The following parameters are required:

      str: A string representation of a double.
   
   Function returns:

      A double value.
*/
   d = array(double, dimsof(str));
   sread, str, format="%f", d;
   return d;
}

func atoc(str) {
/* DOCUMENT atoc(str)
   
   Converts a string representation of a char into a char.

   The following parameters are required:

      str: A string representation of a char.

   Function returns:

      A char value.

   Caveat: Every string element must be exactly one character in length.
*/
// Original David B. Nagle 2009-04-17
   if(numberof(where(strlen(str) != 1)))
      error, "Input string elements must be exactly one character in length.";
   c = array(char, dimsof(str));
   for(i = 1; i <= numberof(str); i++) {
      c(i) = strchar(str(i))(1);
   }
   return c;
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

func strjoin(lst, sep, stripnil=) {
/* DOCUMENT strjoin(lst, sep, stripnil=)

   Given an input array of strings, this will join the strings into a single
   string, using the separator between each array item. If the array is not
   one-dimensional, it will be collapsed as str(*).

   If stripnil=1, then any nil values will be removed prior to joining.

   Example: strjoin(["a", "b", "c"], "--") will return "a--b--c".

   See also: string
*/
   default, stripnil, 0;
   if(!numberof(lst)) return string(0);
   if(stripnil) {
      w = where(lst);
      if(!numberof(w))
         return string(0);
      lst = lst(w);
   }
   if(numberof(lst) > 1) {
      lst = lst(*);
      lst(:-1) += sep;
   }
   return lst(sum);
}

func strwrap(str, space=, newline=, paragraph=, width=) {
/* DOCUMENT wrapped = strwrap(str, space=, newline=, paragraph=, width=)
   Performs word-wrapping on the string defined by str.

   Options:
      space= Defaults to " ". This represets the string that delimits words.
      newline= Defaults to "\n". This represents the string the delimits lines.
      paragraph= Defaults to "\n\n". This represents the string the delimits
         paragraphs.
      width= Defaults 72. Specifies the maximum width for the wrapped text.
*/
// Original David B. Nagle 2009-04-03
   default, space, " ";
   default, newline, "\n";
   default, paragraph, "\n\n";
   default, width, 72;

   result = string(0);
   paragraphs = strsplit(str, paragraph);
   for(i = 1; i <= numberof(paragraphs); i++) {
      this_paragraph = string(0);
      this_line = string(0);
      lines = strsplit(paragraphs(i), newline);
      lines = strtrim(unref(lines));
      for(j = 1; j <= numberof(lines); j++) {
         words = strsplit(lines(j), space);
         for(k = 1; k <= numberof(words); k++) {
            trial_line = strjoin([this_line, words(k)], space, stripnil=1);
            if(strlen(trial_line) <= width) {
               this_line = trial_line;
            } else {
               this_paragraph = strjoin([this_paragraph, this_line], newline, stripnil=1);
               this_line = words(k);
            }
         }
      }
      if(strlen(this_line)) {
         this_paragraph = strjoin([this_paragraph, this_line], newline, stripnil=1);
      }
      result = strjoin([result, this_paragraph], paragraph, stripnil=1);
   }
   return result;
}

func strindent(str, ind) {
/* DOCUMENT newstr = strindent(str, ind);
   Indents each line of str (as deliminted by newlines) with the indentation
   given by ind.
*/
// Original David B. Nagle 2009-04-09
   return regsub("^(.*)$", str, ind + "\\1", newline=1, all=1);
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

   Original David Nagle 2008-07-16
*/
   default, uniq, 1;
   if(file_exists(file)) {
      f = openb(file);
      grow, data, get_member(f, f.vname);
      close, f;
      if(uniq)
         data = data(set_remove_duplicates(data.soe, idx=1));
   }
   f = createb(file);
   add_variable, f, -1, vname, structof(data), dimsof(data);
   get_member(f, vname) = data;
   save, f, vname;
   close, f;
}


