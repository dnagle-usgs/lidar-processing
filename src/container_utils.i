// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

/*
   This file is intended to gather various "container" related utility code.
   For the purpose of this file, a "container" is anything that groups together
   data. This includes:
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

func obj_merge(obj, ..) {
/* DOCUMENT obj = obj_merge(objA, objB, objC, ...)
   -or-  obj_merge, objA, objB, objC, ...

   Merges all of its arguments together into a single object. All objects must
   be oxy group objects. In the functional form, the new merged object is
   returned. In the subroutine form, the first object is updated to contain the
   result of the merge. If two objects use the same key name, the last object's
   value is used.
*/
// Original David Nagle 2010-08-03
   if(!am_subroutine())
      obj = obj(:);
   while(more_args()) {
      src = next_arg();
      for(i = 1; i <= src(*); i++)
         save, obj, src(*,i), src(noop(i));
   }
   return obj;
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

func hash2ptr(hash, token=) {
/* DOCUMENT ptr = hash2ptr(hash, token=)
   Converts a Yeti hash into a pointer tree, which can then be stored safely in
   a Yorick pbd file.

   Keyword token indicates whether a "HASH POINTER" token should be included in
   the pointer structure. Without this, there's no way to safely automatically
   determine whether a pointer structure represents a hash or not; including it
   allows for a hash tree to be recursively stored. By default, it is included
   (token=1), but if you know for a fact that you will never need to determine
   via automatic introspection that the pointer represents a hash you can set
   token=0 to disable its inclusion. (Note that hash members that are
   themselves hashes will be stored with token=1 either way, to allow for
   recursive restoration.)

   SEE ALSO: ptr2hash hash2pbd
*/
// Original David Nagle 2010-04-28
   default, token, 1;
   tokentext = "HASH POINTER";
   keys = h_keys(hash);
   ptr = p_new();
   if(numberof(h_keys(hash))) {
      keys = keys(sort(keys));
      num = numberof(keys);
      for(i = 1; i <= num; i++) {
         if(is_hash(hash(keys(i))))
            p_set, ptr, keys(i), hash2ptr(hash(keys(i)));
         else
            p_set, ptr, keys(i), hash(keys(i));
      }
   }
   if(token)
      ptr = &(grow(*ptr, &tokentext));
   return ptr;
}

func ptr2hash(ptr) {
/* DOCUMENT hash = ptr2hash(ptr)
   Converts a pointer tree returned by hash2ptr into a Yeti hash.

   SEE ALSO: hash2ptr
*/
// Original David Nagle 2010-04-28
   keys = p_keys(ptr);
   num = numberof(keys);
   hash = h_new();
   for(i = 1; i <= num; i++) {
      item = p_get(ptr, keys(i));
      if(
         is_hashptr(item) && numberof(*item) == 3 &&
         is_string(*(*item)(3)) && *(*item)(3) == "HASH POINTER"
      )
         h_set, hash, keys(i), ptr2hash(item);
      else
         h_set, hash, keys(i), item;
   }
   return hash;
}

func pbd2hash(pbd) {
/* DOCUMENT hash = pbd2hash(pbd)
   Creates a Yeti hash whose contents match the pbd's contents. The pbd
   argument may be the filename of a pbd file, or it may be an open filehandle
   to a binary file that contains variables.

   SEE ALSO: hash2pbd
*/
// Original David Nagle 2010-01-28
   if(is_string(pbd))
      pbd = openb(pbd);

   hash = h_new();
   vars = *(get_vars(pbd)(1));
   for(i = 1; i <= numberof(vars); i++)
      // Wrap the get_member in parens to ensure we don't end up with a
      // reference to the file.
      h_set, hash, vars(i), (get_member(pbd, vars(i)));

   return hash;
}

func hash2pbd(hash, pbd) {
/* DOCUMENT hash2pbd, hash, pbd
   Creates a pbd file whose contents match the Yeti hash's contents.

   SEE ALSO: pbd2hash hash2ptr
*/
// Original David Nagle 2010-01-28
   if(is_string(pbd))
      pbd = createb(pbd);

   vars = h_keys(hash);
   for(i = 1; i <= numberof(vars); i++) {
      if(is_void(hash(vars(i))))
         continue;
      add_variable, pbd, -1, vars(i), structof(hash(vars(i))), dimsof(hash(vars(i)));
      get_member(pbd, vars(i)) = hash(vars(i));
   }
}

func obj2hash(obj) {
/* DOCUMENT hash = obj2hash(obj)
   Converts a Yorick object into a Yeti hash.

   SEE ALSO: hash2obj oxy h_new
*/
// Original David Nagle 2010-07-26
   count = obj(*);
   hash = h_new();
   for(i = 1; i <= count; i++)
      h_set, hash, obj(*,i), obj(noop(i));
   return hash;
}

func hash2obj(hash) {
/* DOCUMENT obj = hash2obj(hash)
   Converts a Yeti hash into a Yorick object.

   SEE ALSO: obj2hash oxy h_new
*/
// Original David Nagle 2010-07-26
   keys = h_keys(hash);
   count = numberof(keys);
   obj = save();
   for(i = 1; i <= count; i++)
      save, obj, keys(i), hash(keys(i));
   return obj;
}

func obj2ptr(obj) {
/* DOCUMENT ptrhash = obj2ptr(obj)
   Converts a Yorick object into a pointer hash.

   SEE ALSO: ptr2hash ptr2obj obj2hash
*/
   return hash2ptr(obj2hash(obj));
}

func ptr2obj(ptr) {
/* DOCUMENT obj = ptr2obj(ptrhash)
   Converts a pointer hash into a Yorick object.

   SEE ALSO: ptr2hash obj2ptr hash2obj
*/
   return hash2obj(ptr2hash(ptr));
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

   The only caveat is that you have to know what kind of data structure you're
   using up front (to pre-create the array) and that it has to be
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

func splitary(ary, num, &a1, &a2, &a3, &a4, &a5, &a6) {
/* DOCUMENT splitary, ary, num, a1, a2, a3, a4, a5, a6
   result = splitary(ary, num)

   This allows you to split up an array using a dimension of a specified size.
   The split up parts will then be copied to the output arguments, and the
   return result will contain the parts in a single array that can be indexed
   by its final dimension.

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

   When used in a subroutine form, up to six output arguments can be used to
   acquire the split results, which effectively limits num to 6. However, The
   limit is a soft limit and does not apply at all when used in the functional
   form. To illustrate:

      > ary = array(short, 2, 3, 100, 4, 5)
      > info, ary
       array(short,2,3,100,4,5)
      > info, splitary(ary, 100)
       array(short,2,3,4,5,100)
      > splitary, ary, 100, u, v, w, x, y, z
      > info, u
       array(short,2,3,4,5)

   Output arguments may also be selectively omitted when you do not need all of
   them:

      > ary = array(short, 100, 3)
      > splitary, ary, 3, , , z
*/
// Original David Nagle 2010-03-08
   dims = dimsof(ary);
   if(dims(1) < 1)
      error, "Input must be array (with 1 or more dimensions).";
   w = where(dims(2:) == num);
   if(!numberof(w))
      error, "Input array does not contain requested dimension.";
   if(dims(0) != num)
      ary = transpose(ary, indgen(dims(1):w(1):-1));
   a1 = a2 = a3 = a4 = a5 = a6 = [];
   if(num >= 1)
      a1 = ary(..,1);
   if(num >= 2)
      a2 = ary(..,2);
   if(num >= 3)
      a3 = ary(..,3);
   if(num >= 4)
      a4 = ary(..,4);
   if(num >= 5)
      a5 = ary(..,5);
   if(num >= 6)
      a6 = ary(..,6);
   return ary;
}

func obj_copy(dst) {
/* DOCUMENT obj_copy -- method for generic objects
   newobj = obj(copy,)
   obj, copy, dst

   When called as a function, returns a new object that is a complete copy of
   the calling object.

   When called as a subroutine, copies the data and methods of the calling
   object to the provided DST object, overwriting existing members as
   necessary.
*/
// Original David Nagle 2010-07-30
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   keys = use(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      save, dst, noop(key), use(noop(key));
   }
   return dst;
}

func obj_copy_methods(dst) {
/* DOCUMENT obj_copy_methods -- method for generic objects
   newobj = obj(copy_methods,)
   obj, copy_methods, dst

   When called as a function, returns a new object that has the same methods as
   the calling object.

   When called as a subroutine, copies the methods of the calling object to the
   provided DST object, overwriting existing members as necessary.
*/
// Original David Nagle 2010-07-30
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   keys = use(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      if(is_func(use(noop(key))))
         save, dst, noop(key), use(noop(key));
   }
   return dst;
}

func obj_copy_data(dst) {
/* DOCUMENT obj_copy_data -- method for generic objects
   newobj = obj(copy_data,)
   obj, copy_data, dst

   When called as a function, returns a new object that has the same data as
   the calling object.

   When called as a subroutine, copies the data of the calling object to the
   provided DST object, overwriting existing members as necessary.
*/
// Original David Nagle 2010-07-30
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   keys = use(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      if(!is_func(use(noop(key))))
         save, dst, noop(key), use(noop(key));
   }
   return dst;
}
