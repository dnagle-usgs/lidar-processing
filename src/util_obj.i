// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

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
      obj = obj(:);
   while(more_args()) {
      src = next_arg();
      for(i = 1; i <= src(*); i++)
         save, obj, src(*,i), src(noop(i));
   }
   return obj;
}

func obj_index(this, idx, which=, bymethod=, ignoremissing=) {
/* DOCUMENT result = obj_index(obj, idx, which=, bymethod=, ignoremissing=)
   -or- obj_index, obj, index, idx, which=, bymethod=, ignoremissing=

   Indexes into the member variables of the given object.

   Parameter:
      idx: Must be an expression suitable for indexing into arrays, such as a
         range or a vector of longs.

   Options:
      which= Specifies which fields should be indexed into. All remaining
         fields are left as-is. If not provided, then all indexable fields are
         indexed into. To forcibly indicate that no fields should be indexed
         into, use which=string(0).
      bymethod= Specifies fields that contain objects that need to be indexed
         via a given method. This option should be provided as a group object
         whose members are method names and whose values are the corresponding
         object members to index using the given method name.
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
      > nested, index, ::2, which=["c","d"], bymethod=save(index=["example"])
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

   methods = bymethod(*,);
   count = numberof(methods);
   for(i = 1; i <= count; i++) {
      keys = bymethod(methods(i));
      which = set_difference(which, keys);
      nkeys = numberof(keys);
      for(j = 1; j <= nkeys; j++) {
         if(result(*,keys(j)))
            save, result, keys(j), result(keys(j), methods(i), idx);
         else if(!ignoremissing)
            error, "Missing key: " + keys(j);
      }
   }

   // Discard any string(0) keys
   w = where(which);
   if(!numberof(w))
      return result;
   which = which(w);

   count = numberof(which);
   for(i = 1; i <= count; i++) {
      if(result(*,which(i))) {
         if(is_array(result(which(i))))
            save, result, which(i), result(which(i),idx,..);
         else if(is_obj(result(which(i))))
            save, result, which(i), result(which(i), idx);
      } else if(!ignoremissing) {
         error, "Missing key: " + which(i);
      }
   }

   return result;
}

func obj_copy(this, dst) {
/* DOCUMENT newobj = obj_copy(obj)
   -or- obj_copy, obj, dst

   When called as a function, returns a new object that is a complete copy of
   the calling object.

   When called as a subroutine, copies the data and methods of the calling
   object to the provided DST object, overwriting existing members as
   necessary.

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
   keys = this(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      save, dst, noop(key), this(noop(key));
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
   keys = this(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      if(is_func(this(noop(key))))
         save, dst, noop(key), this(noop(key));
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
   keys = this(*,);
   count = numberof(keys);
   for(i = 1; i <= count; i++) {
      key = keys(i);
      if(!is_func(this(noop(key))))
         save, dst, noop(key), this(noop(key));
   }
   return dst;
}
