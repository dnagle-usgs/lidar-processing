// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

/*
   This file is intended to gather various "container" related utility code
   that doesn't have a more appropriate home elsewhere.  For the purpose of
   this file, a "container" is anything that groups together data. This
   includes:
      - arrays
      - lists
      - structs
      - Yeti hashes
      - pointer hashes
      - Yorick objects (oxy)
      - Yorick binary files
*/

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

func assign(args) {
/* DOCUMENT assign, ary, v1, v2, v3, ...
   Assigns the values in an array to the specified variables. For example:

      > assign, [2, 4, 6], a, b, c
      > a
      2
      > b
      4
      > c
      6

   Any number of variables may be given. If there are more variables than there
   are values in ARY, then the remaining variables are set to [].
*/
// Original David Nagle 2008-12-29
   ary = args(1);
   size = numberof(ary);
   for(i = 1; i < args(0); i++)
      args, i+1, (i <= size ? ary(i) : []);
}
wrap_args, assign;

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

func sanitize_vname(&vname) {
/* DOCUMENT sanitized = sanitize_vname(vname)
   -or-  sanitize_vname, vname

   Sanitizes a string so that it can serve as a valid Yorick variable name.
   Variable names in Yorick must match this regular express to be valid:
      [A-Za-z_][A-Za-z0-9_]*

   Two steps are taken to sanitize the variable name:
      1. If vname starts with a number, it is prefixed by "v".
      2. Each series of invalid characters in vname are replaced by a single
         underscore.

   Examples:
      > sanitize_vname("abc")
      "abc"
      > sanitize_vname("123")
      "v123"
      > sanitize_vname("abc123")
      "abc123"
      > sanitize_vname("e123_n4567_12_fs_mf.pbd")
      "e123_n4567_12_fs_mf_pbd"
      > sanitize_vname("abc~!...123////&abc")
      "abc_123_abc"
      > sanitize_vname("Hello, world!")
      "Hello_world_"
*/
// Original David Nagle 2010-03-13
   ovname = (vname);
   if(regmatch("^[0-9]", ovname))
      ovname = "v" + ovname;
   ovname = regsub("[^A-Za-z0-9_]+", ovname, "_", all=1);
   if(am_subroutine())
      vname = ovname;
   else
      return ovname;
}

func pbd_save(file, vname, data) {
/* DOCUMENT pbd_save, file, vname, data
   This creates the pbd "file" using variable name "vname" to store "data". If
   the file already exists, it will be overwritten.

   See also: pbd_append pbd_load
*/
// Original David Nagle 2009-12-28
   default, vname, file_rootname(file_tail(file));
   sanitize_vname, vname;
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
/* DOCUMENT is_pbd(filename)
   Checks if the given file is a PBD file. Returns 1 if it is, 0 if it's not.
*/
   yPDBopen = 1;
   f = open(file, "rb");
   result = ! _not_pdb(f, 0);
   close, f;
   return result;
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

func map_pointers(__map__f, __map__input) {
/* DOCUMENT map_pointers(f, input);
   Map scalar function F onto pointer array argument INPUT to mimic
   element-wise unary operation on each pointer's value. Returns an array of
   pointers.
*/
// Original David Nagle 2010-07-26
   // Funny local names used to reduce likelihood of clashes, in case called
   // function requires extern use
   __map__output = array(pointer, dimsof(__map__input));
   __map__count = numberof(__map__input);
   for(__i = 1; __i <= __map__count; __i++) {
      if(__map__input(__i))
         __map__output(__i) = &__map__f(*__map__input(__i));
   }
   return __map__output;
}

func merge_pointers(pary) {
/* DOCUMENT merged = merge_pointers(ptr_ary);
   Merges the data pointed to by an array of pointers.

   > example = array(pointer, 3);
   > example(1) = &[1,2,3];
   > example(2) = &[4,5,6];
   > example(3) = &[7,8,9,10];
   > merge_pointers(example)
   [1,2,3,4,5,6,7,8,9,10]
*/
   // Edge case: no input
   if(numberof(pary) == 0 || noneof(pary))
      return [];
   // Eliminate null pointers
   pary = pary(where(pary));

   size = 0;
   for(i = 1; i <= numberof(pary); i++)
      size += numberof(*pary(i));
   mary = array(structof(*pary(1)), size);
   offset = 1;
   for(i= 1; i <= numberof(pary); i++) {
      nextoffset = offset + numberof(*pary(i));
      mary(offset:nextoffset-1) = (*pary(i))(*);
      offset = nextoffset;
   }
   return mary;
}

func array_allocate(&data, request) {
/* DOCUMENT array_allocate, data, request
   Used to smartly allocate space in the data array.

   Instead of writing this:

   data = [];
   for(i = 1; i <= 100000; i++) {
      newdata = getnewdata(i);
      grow, data, newdata;
   }

   Write this instead:

   data = array(double, 1);
   last = 0;
   for(i = 1; i <= 100000; i++) {
      newdata = getnewdata(i);
      array_allocate, data, numberof(newdata) + last;
      data(last+1:last+numberof(newdata)) = newdata;
      last += numberof(newdata);
   }
   data = data(:last);

   This will drastically speed running time up by reducing the number of times
   mememory has to be reallocated for your data. Repeated grows is very
   expensive!

   The only caveats are that you have to know what kind of data structure
   you're using up front (to pre-create the array) and that it has to be
   one-dimensional.
*/
   size = numberof(data);

   // If we have enough space... do nothing!
   if(request <= size)
      return;

   // If we need to more than double... then just grow to the size requested
   if(size/double(request) < 0.5) {
      grow, data, data(array('\01', request-size));
      return;
   }

   // Try to double. If we fail, try to increase to the size requested.
   if(catch(0x08)) {
      grow, data, data(array('\01', request-size));
      return;
   }

   grow, data, data;
}

func splitary(args) {
/* DOCUMENT splitary, ary, num, a1, a2, a3, ...
   -or- splitary, ary, a1, a2, a3, ...
   -or- result = splitary(ary, num)

   This allows you to split up an array using a dimension of a specified size.
   The split up parts will then be copied to the output arguments, and the
   return result will contain the parts in a single array that can be indexed
   by its final dimension.

   Arguments:
      ary: Must be an array with appropriate dimensions.
      num: If provided, must be a literal integer or an expression; a variable
         reference will not work. (Surround with noop() if you need to use a
         variable.)
      a1, a2, a3, ...: Output arguments, where the parts get stored. If num is
         not provided, then it is autodetermined by counting the number of
         output arguments.

   Here are some examples that illustrate. This first example shows that a 3xn
   and nx3 array will both yield the same results:

      > ary = array(short, 100, 3)
      > info, ary
       array(short,100,3)
      > splitary, ary, 3, x, y, z
      > info, x
       array(short,100)
      > info, splitary(ary, 3)
       array(short,100,3)

      > ary = array(short, 3, 100)
      > info, ary
       array(short,3,100)
      > splitary, ary, 3, x, y, z
      > info, x
       array(short,100)
      > info, splitary(ary, 3)
       array(short,100,3)

   And an example that shows it can auto-detect the dimension of interest:

      > ary = array(short, 100, 3)
      > info, ary
       array(short,100,3)
      > splitary, ary, x, y, z
      > info, x
       array(short,100)
      > info, splitary(ary, 3)
       array(short,100,3)

   And here's some examples showing that it can handle arrays with numerous
   dimensions:

      > ary = array(short,1,2,3,4,5,6,7)
      > info, ary
       array(short,1,2,3,4,5,6,7)
      > splitary, ary, 5, v, w, x, y, z
      > info, v
       array(short,1,2,3,4,6,7)
      > splitary, ary, 2, x, y
      > info, x
       array(short,1,3,4,5,6,7)
      > info, splitary(ary, 7)
       array(short,1,2,3,4,5,6,7)
      > info, splitary(ary, 6)
       array(short,1,2,3,4,5,7,6)
      > info, splitary(ary, 5)
       array(short,1,2,3,4,6,7,5)
      > info, splitary(ary, 4)
       array(short,1,2,3,5,6,7,4)
      > info, splitary(ary, 3)
       array(short,1,2,4,5,6,7,3)

   In some cases, there might be ambiguity on which dimension to use. This
   function will split on the last dimension if it can; otherwise, it will
   split on the first dimension that works. For example, in this case:

      > ary = array(short, 3, 3, 3)
      > splitary, ary, 3, x, y, z

   The last dimension is used. The result is equivalent to this:

      > ary = array(short, 3, 3, 3)
      > x = ary(..,1)
      > y = ary(..,2)
      > z = ary(..,3)

   Another example:

      > ary = array(short, 2, 3, 4, 3, 5)
      > splitary, ary, 3, x, y, z

   In this case, the second dimension is used. The result is equivalent to
   this:

      > ary = array(short, 2, 3, 4, 3, 5)
      > x = ary(,1,,,)
      > y = ary(,2,,,)
      > z = ary(,3,,,)

   If you provide a dimension size explicitly, then output arguments may also
   be selectively omitted when you do not need all of them:

      > ary = array(short, 100, 3)
      > splitary, ary, 3, , , z
*/
// Original David Nagle 2010-03-08
   if(args(0) == 1)
      return;
   if(args(0,2) == 1 && is_integer(args(2))) {
      num = args(2);
      offset = 2;
   } else {
      num = args(0) - 1;
      offset = 1;
   }
   ary = args(1);
   dims = dimsof(ary);
   if(dims(1) < 1)
      error, "Input must be array (with 1 or more dimensions).";
   w = where(dims(2:) == num);
   if(!numberof(w))
      error, "Input array does not contain required dimension.";
   if(dims(0) != num)
      ary = transpose(ary, indgen(dims(1):w(1):-1));
   for(i = 1; i <= num; i++)
      args, i + offset, ary(..,i);
   return ary;
}
wrap_args, splitary;

func tp_grow(&ary, .., tp=, tpinv=) {
/* DOCUMENT result = tp_grow(ary1, ary2, ..., tp=, tpinv=)
   -or- tp_grow, ary1, ary2, ..., tp=, tpinv=

   This is equivalent to:
      result = transpose(grow(transpose(ary1,tp), transpose(ary2,tp)),tpinv)
   It is useful for growing arrays whose dimensions are in the wrong order for
   a simple grow.

   If called as a subroutine, first array is updated in-place.

   Options:
      tp: Value to use for second parameter to transpose for converting arrays
         to growable format. Default is [1,0].
      tpinv: Value to use for second parameter to transpose for converting
         result from growable format back to normal format. Default is to use
         tp.
*/
   default, tp, [1,0];
   default, tpinv, tp;
   res = transpose(ary, tp);
   while(more_args())
      grow, res, transpose(next_arg(), tp);
   res = transpose(unref(res), tpinv);
   if(am_subroutine())
      eq_nocopy, ary, res;
   return res;
}

func msort_array(x, which) {
/* DOCUMENT idx = msort_array(x, which)
   This is like msort, but instead of operating over multiple arrays, it
   operates over a single array along one of its dimensions. Thus, this:
      > data = array(double, 3, 100)
      > idx = msort(data(1,), data(2,), data(3,))
   Is equivalent to this:
      > data = array(double, 3, 100)
      > idx = msort_array(data, 1)
   If WHICH is omitted, then the smallest dimension will be used. The code for
   this function is modeled on msort.

   SEE ALSO: sort, msort, msort_rank
*/
   local list;
   dims = dimsof(x);
   default, which, dims(2:)(mnx);

   // Juggle dimensions so that we can index into final dimension
   if(which != dims(1))
      x = transpose(x, indgen(dims(1):which:-1));

   count = dims(which+1);
   mxrank = numberof(x(..,1))-1;
   rank = msort_rank(x(..,1), list);
   if(max(rank) == mxrank) return list;

   norm = 1./(mxrank+1.);
   if(1.+norm == 1.) error, pr1(mxrank+1)+" is too large an array";

   for(i = 2; i <= count; i++) {
      // Adjust rank for next index, then renormalize
      rank += msort_rank(x(..,i))*norm;
      rank = msort_rank(rank, list);
      if(max(rank) == mxrank) return list;
   }

   return sort(rank+indgen(0:mxrank)*norm);
}
