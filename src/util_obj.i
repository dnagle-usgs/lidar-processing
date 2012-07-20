// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "general.i";
require, "set.i";
require, "util_cast.i";

func bless(obj, cls) {
/* DOCUMENT bless, obj, class
  -or- bless, obj
  -or- bless(obj, class)
  -or- bless(obj)

  "Blesses" the given oxy group OBJ into the given "class" CLASS. CLASS must be
  a function name (as a string) or a function reference. The function must
  accept one parameter, the oxy group. It should perform whatever setup is
  necessary to "bless" the group into its "class".

  For example, this:
    bless, myobj, "wfobj"
  Is equivalent to:
    wfobj, myobj

  If the CLASS parameter is omitted, it is inferred from the oxy group itself
  by looking for a member named __bless. This allows for an object to be
  blessed (or re-blessed) even withough explicitly knowing its class. This, in
  part, helps support "sub-classing".
*/
  if(is_void(cls)) cls = obj.__bless;
  if(!is_func(cls)) {
    if(!symbol_exists(cls)) error, "Unknown class";
    cls = symbol_def(cls);
  }
  if(!am_subroutine())
    return cls(obj);
  cls, obj;
}

func keydefault(args) {
/* DOCUMENT keydefault, obj, key1, val1, key2, val2, ...
  keydefault, obj, key1=val1, key2=val2, ...

  For a given object OBJ, if the given keys are not present, then they are set
  with the corresponding given values.

  SEE ALSO: key_default_and_cast keyrequire default save
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

func key_default_and_cast(args) {
/* DOCUMENT key_default_and_cast, obj, key1, val1, key2, val2, ...
  key_default_and_cast, obj, key1=val1, key2=val2, ...

  For a given object OBJ, if the given keys are not present, then they are set
  with the corresponding given values. If the given keys are present, then
  their values are cast to the same type as the value given.

  SEE ALSO: keydefault keyrequire default save
*/
  if(!(args(0) % 2))
    error, "invalid call to key_default_and_cast";
  obj = args(1);
  for(i = 2; i <= args(0); i += 2) {
    key = args(0,i) ? args(i) : args(-,i);
    if(!obj(*,key))
      save, obj, noop(key), args(i+1);
    save, obj, noop(key), structof(args(i+1))(obj(noop(key)));
  }
  keys = args(-);
  for(i = 1; i <= numberof(keys); i++) {
    key = keys(i);
    if(!obj(*,key))
      save, obj, noop(key), args(key);
    save, obj, noop(key), structof(args(key))(obj(noop(key)));
  }
}
wrap_args, key_default_and_cast;

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

scratch = save(scratch, tmp, obj_grow_dummy_array, obj_grow_find_needed);
tmp = save(dummy_array, find_needed);

func obj_grow_dummy_array(val, size) {
// Utility function for obj_grow
// Creates a dummy array with struct and dimensionf of VAL, except that its
// leading dimension is changed to SIZE.
  dims = dimsof(val);
  dims(2) = size;
  return array(structof(val), dims);
}
dummy_array = obj_grow_dummy_array;

func obj_grow_find_needed(obj, ref, sizekey, exclude, &size, &need) {
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
find_needed = obj_grow_find_needed;

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
        save, result, which(i), obj_index(result(which(i)), idx);
      }
    } else if(!ignoremissing) {
      error, "Missing key: " + which(i);
    }
  }

  return result;
}

func obj_sort(this, fields, which=, ref=, size=, bymethod=, ignoremissing=) {
/* DOCUMENT result = obj_index(obj, fields, which=, ref=, size= bymethod=,
    ignoremissing=)
  -or- obj_index, obj, fields, idx, which=, ref=, size=, bymethod=,
    ignoremissing=

  Sorts using the specified fields.

  Parameter:
    fields: Must be a string or array of strings, specifying the field names
      to sort by (in the order to use them). Prefixing a field name with a
      minus sign means to sort by reverse order on that field.

  Options:
    Options are all passed to obj_index. See obj_index for details.

  This is a wrapper around obj_index that constructs its argument by sorting
  the specified fields. All fields must be conformable.
*/
  local list;

  if(!this)
    this = use();
  result = am_subroutine() ? this : obj_copy(this);

  // Parse to determine which should sort in reverse order
  fields = fields(*);
  asc = strpart(fields, :1) != "-";
  if(nallof(asc))
    fields(where(!asc)) = strpart(fields(where(!asc)), 2:)
  direction = (asc*2) - 1;

  mxrank = numberof(result(fields(1),))-1;
  norm = 1./(mxrank+1.);
  if(1.+norm == 1.)
    error, pr1(mxrank+1)+" is too large an array";

  rank = msort_rank(result(fields(1),), list) * direction(1);
  rank = msort_rank(rank);

  for(i = 2; i <= numberof(fields); i++) {
    rank += (msort_rank(result(fields(i),)) * norm * direction(i));
    rank = msort_rank(rank, list);
    if(max(rank) == mxrank)
      break;
  }

  rank = sort(rank + indgen(0:mxrank)*norm);

  obj_index, result, rank, which=which, ref=ref, size=size,
    bymethod=bymethod, ignoremissing=ignoremissing;

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

func obj_pop(args) {
/* DOCUMENT obj_pop(obj, key)
  -or- obj_pop, obj, key
  Pop member KEY out of object OBJ and return the value that was associated
  with it. Or if called as a subroutine, simply delete the member from the
  object. Caveats/notes:
    * KEY may be specified as a simple variable reference (as elsewhere with
      oxy), in which case the value is ignored. It may also be specified as a
      string value or a key. So obj_pop(obj, foo), obj_pop(obj, "foo"), and
      obj_pop(obj, foo=) are all equivalent.
    * If KEY does not exist in OBJ, [] is returned and no change is made.
    * If KEY exists and is removed from OBJ, then a new object is created and
      stored back to OBJ. This effectively updates OBJ. However, if there are
      other references to the same object elsewhere, the key will NOT be
      removed for them. This is an inherent limitation of the oxy
      functionality.
  SEE ALSO: obj_delete
*/
  if(args(0) == 1) {
    obj = args(1);
    if(numberof(args(-)) != 1)
      error, "obj_pop requires key name";
    key = args(-)(1);
  } else if(args(0) == 2) {
    obj = args(1);
    if(args(0,2) == 0)
      key = args(-,2);
    else
      key = args(2);
  } else {
    error, "obj_pop requires object and key";
  }
  if(!is_obj(obj))
    error, "obj_pop requires object";
  if(!is_string(key))
    error, "obj_pop requires key name";
  if(obj(*,key)) {
    result = obj(noop(key));
    if(args(0,1) == 0) {
      w = where(obj(*,) != key);
      obj = numberof(w) ? obj(noop(w)) : save();
      args, 1, obj;
    }
    return result;
  } else {
    return [];
  }
}
errs2caller, obj_pop;
wrap_args, obj_pop;

func obj_delete(args) {
/* DOCUMENT obj_delete(obj, keyA, keyB, keyC, ...)
  -or- obj_delete, obj, keyA, keyB, keyC, ...
  Deletes the various given KEYS from OBJ and returns OBJ. Caveats/notes:
    * KEYS may be specified as a simple variable reference (as elsewhere with
      oxy), in which case the value is ignored. It may also be specified as a
      string value or a key. So obj_delete(obj, foo), obj_delete(obj, "foo"),
      and obj_delete(obj, foo=) are all equivalent.
    * KEYS do not need to exist in OBJ. If they do not, no action is taken.
    * If KEYS exist and are removed from OBJ, then a new object. In
      functional form, that new object is returned. In subroutine form, it
      gets stored back to OBJ. However, if there are other references to the
      same object elsewhere, KEYS will NOT be removed for them. This is an
      inherent limitation of the oxy functionality.
  SEE ALSO: obj_pop
*/
  obj = args(1);
  if(!is_obj(obj))
    error, "obj_delete requires object";
  drop = args(-);
  for(i = 2; i <= args(0); i++) {
    key = args(0,i) ? args(i) : args(-,i);
    if(!is_string(key))
      error, "invalid key";
    grow, drop, key;
  }
  keys = obj(*,);
  keep = array(1, numberof(keys));
  n = numberof(drop);
  for(i = 1; i <= n; i++)
    keep &= keys != drop(i);
  w = where(keep);
  result = numberof(w) ? obj(noop(w)) : save();
  if(!am_subroutine()) {
    return result;
  } else if(args(0,1) == 0) {
    args, 1, result;
  } else {
    // subroutine call on value that's not simple reference
  }
}
errs2caller, obj_delete;
wrap_args, obj_delete;

func obj_transpose(obj, ary=, fill_void=) {
/* DOCUMENT obj_transpose(obj, ary=, fill_void=)
  Transposes a group of groups. For example:
    > temp = obj_transpose(save(alpha=save(a=1,b=2), beta=save(a=10,b=20)))
    > obj_show, temp
     TOP (oxy_object, 2 entries)
     |- a (oxy_object, 2 entries)
     |  |- alpha (long) 1
     |  `- beta (long) 10
     `- b (oxy_object, 2 entries)
       |- alpha (long) 2
       `- beta (long) 20
  Missing items will be represented by [].

  If ary=1, then a group of arrays will be returned instead, if possible.
    > grp = save()
    > save, grp, string(0), save(a=1,b=2)
    > save, grp, string(0), save(a=10,b=20)
    > obj_show, obj_transpose(grp, ary=1)
     TOP (oxy_object, 2 entries)
     |- a (long,2) [1,10]
     `- b (long,2) [2,20]
  Groups that cannot be converted successful to arrays (via obj2array) will
  remain groups.

  If fill_void=1, then when converting groups of arrays (with ary=1), any void
  items will be replaced by zero or nil in an attempt to help coerce the data
  into arrays.
    > grp = save()
    > save, grp, string(0), save(a=1,b=2)
    > save, grp, string(0), save(b=20)
    > obj_show, obj_transpose(grp, ary=1, fill_void=1)
     TOP (oxy_object, 2 entries)
     |- a (long,2) [1,0]
     `- b (long,2) [2,20]
*/
  local success;
  default, ary, 0;
  default, fill_void, 0;
  keys = array(pointer, obj(*));
  for(i = 1; i <= obj(*); i++)
    keys(i) = &(obj(noop(i))(*,));
  keys = set_remove_duplicates(merge_pointers(keys));

  result = save();
  for(i = 1; i <= numberof(keys); i++) {
    key = keys(i);
    curres = save();
    for(j = 1; j <= obj(*); j++) {
      curobj = obj(noop(j));
      if(curobj(*,key))
        save, curres, obj(*,j), curobj(noop(key));
      else
        save, curres, obj(*,j), [];
    }
    if(ary) {
      curary = obj_copy(curres);
      if(fill_void) {
        type = [];
        for(j = 1; j <= curres(*); j++) {
          if(!is_void(curres(noop(j)))) {
            type = structof(curres(noop(j)));
            break;
          }
        }
        for(j = 1; j <= curres(*); j++) {
          if(is_void(curres(noop(j))))
            save, curary, noop(j), type();
        }
      }
      curary = obj2array(curary, success);
      if(success)
        save, result, noop(key), noop(curary);
      else
        save, result, noop(key), noop(curres);
    } else {
      save, result, noop(key), noop(curres);
    }
  }

  return result;
}

func obj_subkeys(data) {
/* DOCUMENT obj_subkeys(data)
  Returns a list of all subkeys found in the given data, which should be an oxy
  group object where each member is also an oxy group object.

    > example = save(a=save(foo=1, bar=2), b=save(foo=3, baz=4),
    cont> c=save(bar=5, baz=6));
    ["foo","bar","baz"]

  The return result is not guaranteed to be in any particular order.
*/
  count = data(*);
  subkeys = save();
  for(i = 1; i <= count; i++) {
    keys = data(noop(i))(*,);
    nkeys = numberof(keys);
    for(j = 1; j <= nkeys; j++)
      save, subkeys, keys(j), '\0';
  }
  return subkeys(*,);
}

func obj_has_subkey(data, subkey) {
/* DOCUMENT obj_has_subkey(data, subkey)
  Checks to see if a subkey is contained within each element in data, which
  should be an oxy group object where each member is also an oxy group object.
  An array is returned with the same length as data; 0 indicates the subkey was
  not found, a positive number indicates the the subkey was found and specifies
  its index.

    > example = save(a=save(foo=1, bar=2), b=save(foo=3, baz=4),
    cont> c=save(bar=5, baz=6));
    > obj_has_subkey(example, "foo")
    [1,1,0]
    > obj_has_subkey(example, "bar")
    [2,0,1]
    > obj_has_subkey(example, "baz")
    [0,2,2]
*/
  count = data(*);
  result = array(short, count);
  for(i = 1; i <= count; i++) {
    result(i) = data(noop(i))(*,subkey);
  }
  return result;
}

func obj_anons(obj) {
/* DOCUMENT w = obj_anons(obj)
  Returns an an index into OBJ indicating which members are anonymous.
*/
  if(!obj(*)) return where(0);
  return where(strlen(obj(*,))==0);
}

func obj_keys(obj) {
/* DOCUMENT keys = obj_keys(obj)
  Returns the keyword members of OBJ. If there are anonymous members, they will
  not be included.
*/
  if(!obj(*)) return [];
  keys = obj(*,);
  return keys(where(strlen(keys)));
}
