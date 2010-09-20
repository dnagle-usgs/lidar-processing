// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func keydefault(args) {
/* DOCUMENT keydefault, obj, key1, val1, key2, val2, ...
   keydefault, obj, key1=val1, key2=val2, ...

   For a given object OBJ, if the given keys are not present, then they are set
   with the corresponding given values.

   SEE ALSO: keyrequire default save
*/
// Original David Nagle 2010-08-09
   if(!(args(0) % 2))
      error, "invalid call to keydefault";
   obj = args(1);
   for(i = 2; i <= args(0); i += 2) {
      key = args(0,i) ? args(i) : args(-,i);
      if(!obj(*,key))
         save, obj, noop(key), args(i+1);
   }
   keys = args(-);
   for(i = 1; i <= numberof(keys); i++) {
      key = keys(i);
      if(!obj(*,key))
         save, obj, noop(key), args(key);
   }
}
wrap_args, keydefault;

func keyrequire(args) {
/* DOCUMENT keyrequire, obj, key1, key2, ...
   -or- keyrequire, obj, key1=, key2=, ...

   Checks to make sure that each of the keys given are present in the given
   object OBJ. If any are missing, an error is generated.

   SEE ALSO: keydefault default save
*/
// Original David Nagle 2010-09-13
   if(!args(0))
      error, "invalid call to keyrequire";
   obj = args(1);
   keys = args(-);
   for(i = 2; i <= args(0); i++)
      grow, keys, (args(0,i) ? args(i) : args(-,i));
   missing = !obj(*,keys);
   if(anyof(missing)) {
      missing = strjoin(keys(where(missing)), ", ");
      error, "missing required keys: "+missing;
   }
}
errs2caller, keyrequire;
wrap_args, keyrequire;

func obj_merge(obj, ..) {
/* DOCUMENT obj = obj_merge(objA, objB, objC, ...)
   -or-  obj_merge, objA, objB, objC, ...

   Merges all of its arguments together into a single object. All objects must
   be oxy group objects. In the functional form, the new merged object is
   returned. In the subroutine form, the first object is updated to contain the
   result of the merge. If two objects use the same key name, the last object's
   value is used.

   This function can be used as an object method by using a closure whose
   data item is 0:
      save, obj, merge=closure(obj_merge, 0)
   You can then call merge like this:
      obj(merge, ...)
      obj, merge, ...
*/
// Original David Nagle 2010-08-03
   if(!obj)
      obj = use();
   if(!am_subroutine())
      obj = obj_copy(obj);
   while(more_args()) {
      src = next_arg();
      for(i = 1; i <= src(*); i++)
         save, obj, src(*,i), src(noop(i));
   }
   return obj;
}

func obj_grow(util, this, .., ref=, size=, exclude=) {
/* DOCUMENT obj_grow, this, that, .., ref=, size=, exclude=
   -or- result = obj_grow(this, that, .., ref=, size=, exclude=)
   Grows the growable members of a set of objects.

   This is intended to be used on objects that have keyed members where some
   members are non-scalar arrays and other members may be scalars and/or
   functions. The non-scalar arrays are expected to be of equal leading
   dimension size within an object. Such members from successive objects will
   be grown together into the result. If a member does not exist in the other
   object, it will be dummied out for growing so that the result remains
   conformable with other grown members.

   For example:
      > foo = save(a="Foo", b=indgen(10), c=indgen(10))
      > bar = save(a="Test", b=indgen(5), d=indgen(5))
      > baz = obj_grow(foo, bar)
      > obj_show, baz, maxary=15
       TOP (oxy_object, 4 entries)
       |- a (string) "Foo"
       |- b (long,15) [1,2,3,4,5,6,7,8,9,10,1,2,3,4,5]
       |- c (long,15) [1,2,3,4,5,6,7,8,9,10,0,0,0,0,0]
       `- d (long,15) [0,0,0,0,0,0,0,0,0,0,1,2,3,4,5]

   If ref= is provided, it should be the name of a key to use to determine the
   leading size for the object. This key must be present in all objects. In the
   above example, we could have used ref="b".

   If size= is provided, it should be the name of a member (as a string) that
   will return the leading size for the object. This key must be present in all
   objects.

   If neither ref= nor size= is provided, then all members are checked for
   size. If they all have the same size, then that size is used. If more than
   one size is detected, then none of the members will be used.

   If exclude= is provided, then it should be an array of key names that should
   be skipped if present.

   If called as a subroutine, then the first object is grown in place.
   Otherwise, a new object is created and returned.
*/
   if(!this)
      this = use();
   if(!am_subroutine())
      this = obj_copy(this);

   this_size = that_size = this_need = that_need = [];
   while(more_args()) {
      that = next_arg();

      util, find_needed, this, ref, size, exclude, this_size, this_need;
      util, find_needed, that, ref, size, exclude, that_size, that_need;

      // Scan through THIS and grow everything that needs to be grown
      for(i = 1; i <= this(*); i++) {
         if(!this_need(i))
            continue;

         key = this(*,i);
         this_val = this(noop(i));

         // Check to see if THAT has this key; if so, grow; otherwise, extend
         j = that(*,key);
         if(j) {
            // If THAT doesn't need it, then it isn't growable... error!
            if(!that_need(j))
               error, "Unable to grow \""+key+"\"";
            that_need(j) = 0;
            that_val = that(noop(j));
         } else {
            that_val = util(dummy_array, this_val, that_size);
         }

         save, this, noop(key), tp_grow(this_val, that_val);
      }

      for(j = 1; j <= that(*); j++) {
         if(!that_need(j))
            continue;

         key = that(*,j);
         that_val = that(noop(j));

         // If the key exists in THIS, then it wasn't growable... error!
         if(this(*,key))
            error, "Unable to grow \""+key+"\"";
         this_val = util(dummy_array, that_val, this_size);

         save, this, noop(key), tp_grow(this_val, that_val);
      }

      // Need to clear that_need to avoid having find_needed apply it to the
      // next object
      that_need = [];
   }

   return this;
}

scratch = save(scratch, tmp);
tmp = save(dummy_array, find_needed);

func dummy_array(val, size) {
// Utility function for obj_grow
// Creates a dummy array with struct and dimensionf of VAL, except that its
// leading dimension is changed to SIZE.
   dims = dimsof(val);
   dims(2) = size;
   return array(structof(val), dims);
}

func find_needed(obj, ref, sizekey, exclude, &size, &need) {
// Utility function for obj_grow
// For a given object, finds the dimension size of its growable members and
// determines which members need to be grown

   if(!is_void(ref) && !obj(*,ref))
      error, "Reference key \""+key+"\" not present in object";

   // Determine the size of each member. If the member is not a non-scalar
   // array, then give it size 0.
   sizes = array(long(0), obj(*));
   for(i = 1; i <= obj(*); i++) {
      // Only consider keyed items
      key = obj(*,i);
      if(!key)
         continue;

      // check for excluded items
      if(!is_void(exclude) && anyof(exclude == key))
         continue;

      // Only consider non-scalar arrays
      val = obj(noop(i));
      if(is_scalar(val) || !is_array(val))
         continue;

      sizes(i) = dimsof(val)(2);
   }

   // Determine the size to use for growable members. If ref is present, it
   // determines. If size is present, it determines. Otherwise, we can only
   // grow if all growable members are the same size.
   if(!is_void(ref)) {
      size = dimsof(obj(noop(ref)))(2);
   } else if(is_string(sizekey)) {
      size = obj(noop(sizekey),);
   } else {
      size = 0;
      w = where(sizes);
      if(numberof(w)) {
         size_list = set_remove_duplicates(sizes(w));
         if(numberof(size_list) == 1)
            size = size_list(1);
         size_list = [];
      }
   }

   last_need = need;

   // Only want to grow for non-zero-size members of the right size
   need = (size > 0) & (sizes == size);

   // This is used to make sure we don't accidentally pick up members when
   // growing multiple objects in sequence. For example, if our object had a
   // reference size of 10 and one of the members was 25, it would be excluded.
   // However, if the first object that grew onto it was size 15, the new
   // reference would be 25. The following ensures that we remember not to grow
   // the original size 25 member.
   if(!is_void(last_need))
      need(:numberof(last_need)) &= last_need;
}

obj_grow = closure(obj_grow, restore(tmp));
restore, scratch;

func obj_index(this, idx, which=, ref=, size=, bymethod=, ignoremissing=) {
/* DOCUMENT result = obj_index(obj, idx, which=, ref=, size= bymethod=,
      ignoremissing=)
   -or- obj_index, obj, index, idx, which=, ref=, size=, bymethod=,
      ignoremissing=

   Indexes into the member variables of the given object.

   Parameter:
      idx: Must be an expression suitable for indexing into arrays, such as a
         range or a vector of longs.

   Options:
      which= Specifies which fields should be indexed into. All remaining
         fields are left as-is. If not provided, then all indexable fields are
         indexed into. To forcibly indicate that no fields should be indexed
         into, use which=string(0).
      ref= Specifies a member (by string name) that should be indexed. Its
         leading size is used to determine which other members can also be
         indexed. Only those members will be indexed.
      size= Specifies a member (by string name) that will return the leading
         size of the members that should be indexed.  Only those members will
         be indexed.
      bymethod= Specifies fields that contain objects that need to be indexed
         via a given method. This option should be provided as a group object
         whose members are member names for the object and whose values are the
         corresponding methods that should be called for those members. For
         example, supposing you had an object "obj" and called obj_index with
         this option:
            bymethod=save(foo="index", bar="index", baz="myindex")
         This would index by calling obj(foo,index,idx), obj(bar,index,idx) and
         obj(baz,myindex,idx).
      ignoremissing= By default, missing keys are silently ignored. Provide
         ignoremissing=0 to raise errors instead.

   If any fields are multi-dimensional arrays, they are indexed along their
   first dimension: field(idx,).

   This function can be used as an object method by using a closure whose data
   item is 0:
      save, obj, index=closure(obj_index, 0)
   You can then call index like this:
      obj(index, ...)
      obj, index, ...

   Examples:

      > example = save(index=closure(obj_index, 0), a=[2,4,6,8,10],
      cont> b=span(.1,.5,5))
      > obj_show, example
      TOP (oxy_object, 4 entries)
      |- index (function)
      |- a (long,5) [2,4,6,8,10]
      `- b (double,5) [0.1,0.2,0.3,0.4,0.5]
      > indexed = example(index, [2,4])
      > obj_show, indexed
      TOP (oxy_object, 4 entries)
      |- index (function)
      |- copy (function)
      |- a (long,2) [4,8]
      `- b (double,2) [0.2,0.4]
      >

      > nested = save(index=closure(obj_index, 0), example, c=[1,2,3,4,5],
      cont> d=span(0,1,5), g=42)
      > obj_show, nested
      TOP (oxy_object, 6 entries)
      |- index (function)
      |- copy (function)
      |- example (oxy_object, 4 entries)
      |  |- index (function)
      |  |- a (long,5) [2,4,6,8,10]
      |  `- b (double,5) [0.1,0.2,0.3,0.4,0.5]
      |- c (long,5) [1,2,3,4,5]
      |- d (double,5) [0,0.25,0.5,0.75,1]
      `- g (long) 42
      > nested, index, ::2, which=["c","d"], bymethod=save(example="index")
      > obj_show, nested
      TOP (oxy_object, 6 entries)
      |- index (function)
      |- example (oxy_object, 4 entries)
      |  |- index (function)
      |  |- copy (function)
      |  |- a (long,3) [2,6,10]
      |  `- b (double,3) [0.1,0.3,0.5]
      |- c (long,3) [1,3,5]
      |- d (double,3) [0,0.5,1]
      `- g (long) 42
      >
*/
// Original David Nagle 2010-08-09
   if(!this)
      this = use();
   result = am_subroutine() ? this : obj_copy(this);
   default, which, this(*,);
   default, bymethod, save();
   default, ignoremissing, 1;
   if(is_scalar(which))
      which = [which];

   // Handle members that require sub-methods for indexing
   keys = bymethod(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      if(result(*,keys(i)))
         save, result, keys(i), result(keys(i), bymethod(keys(i)), idx);
      else if(!ignoremissing)
         error, "Missing key: " + keys(j);
   }

   // Eliminate any keys in which that were handled by bymethod
   which = set_difference(which, bymethod(*,));

   // Discard any string(0) keys
   w = where(which);
   if(!numberof(w))
      return result;
   which = which(w);

   // If ref= or size= are provided, then retrieve the size that needs to be
   // used and store in leading for comparison
   leading = 0;
   if(!is_void(ref)) {
      if(!result(*,ref))
         error, "object does not have ref member: "+ref;
      leading = dimsof(result(noop(ref)))(2);
   } else if(!is_void(size)) {
      if(!result(*,size))
         error, "object does not have size member: "+size;
      leading = result(noop(size),);
   }

   // Handle directly-indexable members
   count = numberof(which);
   for(i = 1; i <= count; i++) {
      if(result(*,which(i))) {
         if(is_scalar(result(which(i))))
            continue;
         if(is_array(result(which(i)))) {
            if(leading && dimsof(result(which(i)))(2) != leading)
               continue;
            save, result, which(i), result(which(i),idx,..);
         } else if(is_obj(result(which(i)))) {
            if(leading && result(which(i))(*) != leading)
               continue;
            save, result, which(i), result(which(i), noop(idx));
         }
      } else if(!ignoremissing) {
         error, "Missing key: " + which(i);
      }
   }

   return result;
}

func obj_copy(this, dst, recurse=) {
/* DOCUMENT newobj = obj_copy(obj)
   -or- obj_copy, obj, dst

   When called as a function, returns a new object that is a complete copy of
   the calling object.

   When called as a subroutine, copies the data and methods of the calling
   object to the provided DST object, overwriting existing members as
   necessary.

   By default, a shallow copy is made. Use recurse=1 to recursively apply
   obj_copy to any member objects encountered.

   This function can be used as an object method by using a closure whose data
   item is 0:
      save, obj, copy=closure(obj_copy, 0)
   You can then call copy like this:
      obj(copy, ...)
      obj, copy, ...
*/
// Original David Nagle 2010-07-30
   if(!this)
      this = use();
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   for(i = 1; i <= this(*); i++) {
      val = this(noop(i));
      if(recurse && is_obj(val))
         val = obj_copy(val, recurse=1);
      save, dst, this(*,i), val;
   }
   return dst;
}

func obj_copy_methods(this, dst) {
/* DOCUMENT newobj = obj_copy_methods(obj)
   obj_copy_methods, obj, dst

   When called as a function, returns a new object that has the same methods as
   the calling object.

   When called as a subroutine, copies the methods of the calling object to the
   provided DST object, overwriting existing members as necessary.

   This function can be used as an object method by using a closure whose data
   item is 0:
      save, obj, copy_methods=closure(obj_copy_methods, 0)
   You can then call copy_methods like this:
      obj(copy_methods, ...)
      obj, copy_methods, ...
*/
// Original David Nagle 2010-07-30
   if(!this)
      this = use();
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   for(i = 1; i <= this(*); i++) {
      if(is_func(this(noop(i))))
         save, dst, this(*,i), this(noop(i));
   }
   return dst;
}

func obj_copy_data(this, dst) {
/* DOCUMENT newobj = obj_copy_data(obj)
   obj_copy_data, obj, dst

   When called as a function, returns a new object that has the same data as
   the calling object.

   When called as a subroutine, copies the data of the calling object to the
   provided DST object, overwriting existing members as necessary.

   This function can be used as an object method by using a closure whose data
   item is 0:
      save, obj, copy_data=closure(obj_copy_data, 0)
   You can then call copy_data like this:
      obj(copy_data, ...)
      obj, copy_data, ...
*/
// Original David Nagle 2010-07-30
   if(!this)
      this = use();
   if(!am_subroutine())
      dst = save();
   else if(!is_obj(dst))
      error, "Called as subroutine without destination argument";
   for(i = 1; i <= this(*); i++) {
      if(!is_func(this(noop(i))))
         save, dst, this(*,i), this(noop(i));
   }
   return dst;
}
