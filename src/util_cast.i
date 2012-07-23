// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "set.i";
require, "ytk.i";

func can_iter_list(x) {
/* DOCUMENT can_iter_list(data)
  Returns 1 if DATA is suitable for passing through iter_list, 0 otherwise.
*/
  if(is_range(x)) return 1;
  if(is_array(x) && !is_scalar(x)) return 1;
  if(is_obj(x) == 3) return 1;
  if(is_list(x)) return 1;
  return 0;
}

func iter_list(f, data) {
/* DOCUMENT iter_list(data)
  Wrapper around various kinds of lists that lets you iterate through them all
  in a consistent way. DATA can be an array, an oxy object (provided it allows
  numerical indexing), a Yorick list, or a range. An object will be returned
  with three members:
    result(data,) -- This is what you passed in to it.
    result(count,) -- The number of items in data.
    result(item,) -- Function that will return a item specified by index.

  Example:
    > foo = [10,20,30]
    > bar = iter_list(foo)
    > bar.count
    3
    > bar(item,1)
    10
    > bar(item,3)
    30

  This can be used in code like so:

    iter = iter_list(data);
    for(i = 1; i <= iter.count; i++) {
      item = iter(item, i);
      // do something with item
    }
*/
// Original David B. Nagle 2010-12-15
  if(is_range(data))
    data = indgen(data);
  result = save(data);
  if(is_array(data)) {
    save, result, count=dimsof(data)(0);
    save, result, item=f.array_item;
  } else if(is_obj(data) == 3) {
    save, result, count=data(*);
    save, result, item=f.obj_item;
  } else if(is_list(data)) {
    save, result, count=_len(data);
    save, result, item=f.list_item;
  } else {
    error, "don't know how to iterate over "+typeof(data);
  }
  return result;
}

scratch = save(scratch, tmp);
tmp = save(array_item, obj_item, list_item);
func array_item(i) {return use(data,..,i);}
func obj_item(i) {return use(data,noop(i));}
func list_item(i) {return _car(use(data),i);}
iter_list = closure(iter_list, restore(tmp));
restore, scratch;

func can_iter_dict(x) {
/* DOCUMENT can_iter_dict(data)
  Returns 1 if DATA is suitable for passing through iter_dict, 0 otherwise.
*/
  if(is_obj(x))
    return !x(*) || allof(x(*,));
  return has_members(x);
}

func iter_dict(f, data) {
/* DOCUMENT iter_list(data)
  Wrapper around various kinds of dictionaries/associative arrays that lets
  you iterate through them all in a consistent way. DATA can be an an
  oxy object, a Yeti hash, a struct instance, or an open binary file stream.
  An object will be returned with four members:
    result(data,) -- This is what you passed in to it.
    result(count,) -- The number of items in data.
    result(keys,) -- A string array of key names.
    result(item,) -- Function that will return a item specified by key/index.

  Example:
    > foo = save(a=10,b=23,c=42)
    > bar = iter_dict(foo)
    > bar.count
    3
    > bar(item,1)
    10
    > bar(item,"c")
    30
    > bar.keys
    ["a","b","c"]

  This can be used in code like so:

    iter = iter_dict(data);
    for(i = 1; i <= iter.count; i++) {
      key = iter.keys(i);
      item = iter(item, key);
      // or if the key doesn't matter...
      item = iter(item, i);
      // then do something with key/item
    }
*/
// Original David B. Nagle 2010-12-15
  result = save(data);
  if(is_obj(data) && data(*) && nallof(data(*,)))
    error, "one or more members of object lacks key name";
  if(has_members(data)) {
    save, result, keys=get_members(data);
    save, result, count=numberof(result.keys);
    save, result, item=f.member_item;
  } else {
    error, "don't know how to iterate over "+typeof(data);
  }
  return result;
}

scratch = save(scratch, tmp);
tmp = save(member_item);
func member_item(i) {
  if(!is_string(i)) i = use(keys, i);
  return get_member(use(data), i);
}
iter_dict = closure(iter_dict, restore(tmp));
restore, scratch;

func bool(val) {
/* DOCUMENT result = bool(val)
  Coerces its result into boolean values. RESULT will be an array of type
  char, where 0x00 is false and 0x01 is true.

  This can accept virtually anything as input. It is logically equivalent to
  the following:
    result = (val ? 0x01 : 0x00)
  However, it also works for arrays and will maintain their dimensions.
*/
  return char(!(!val));
}

func pointers2group(pary) {
/* DOCUMENT grp = pointers2group(pary)
  Given an array of pointers PARY, this returns a group object GRP that
  contains the dereferenced pointers' contents such that grp(i) == *pary(i).

  SEE ALSO: hash2obj hash2pbd obj2hash obj2pbd pbd2hash pbd2obj oxy
*/
  obj = save();
  count = numberof(pary);
  for(i = 1; i <= count; i++)
    save, obj, string(0), *pary(i);
  return obj;
}

func pbd2hash(pbd) {
/* DOCUMENT hash = pbd2hash(pbd)
  Creates a Yeti hash whose contents match the pbd's contents. The pbd
  argument may be the filename of a pbd file, or it may be an open filehandle
  to a binary file that contains variables.

  SEE ALSO: hash2obj hash2pbd obj2hash obj2pbd pbd2obj pointers2group h_new
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

  SEE ALSO: hash2obj obj2hash obj2pbd pbd2hash pbd2obj pointers2group h_new
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

  SEE ALSO: hash2obj hash2pbd obj2pbd pbd2hash pbd2obj pointers2group oxy
    h_new
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

  SEE ALSO: hash2pbd obj2hash obj2pbd pbd2hash pbd2obj pointers2group oxy
    h_new
*/
// Original David Nagle 2010-07-26
  keys = h_keys(hash);
  count = numberof(keys);
  obj = save();
  for(i = 1; i <= count; i++)
    save, obj, keys(i), hash(keys(i));
  return obj;
}

func obj2pbd(obj, pbd) {
/* DOCUMENT obj2pbd, obj, pbd
  Converts a Yorick group object to a PBD file. Caveat: Only group members
  that are arrays and have non-nil key names will get saved.

  SEE ALSO: hash2obj hash2pbd obj2hash pbd2hash pbd2obj pointers2group oxy
*/
  if(is_string(pbd))
    pbd = createb(pbd);
  for(i = 1; i <= obj(*); i++) {
    key = obj(*,i);
    val = obj(noop(i));
    if(!strlen(key) || !is_array(val))
      continue;
    save, pbd, noop(key), val;
  }
}

func pbd2obj(pbd) {
/* DOCUMENT obj = pbd2obj(pbd)
  Converts a PBD file to a Yorick group object.

  SEE ALSO: hash2obj hash2pbd obj2hash obj2pbd pbd2hash pointers2group oxy
*/
  if(is_string(pbd))
    pbd = openb(pbd);
  obj = save();
  vars = *(get_vars(pbd)(1));
  for(i = 1; i <= numberof(vars); i++)
    // Wrap the get_member in parens to ensure we don't end up with a
    // reference to the file.
    save, obj, vars(i), (get_member(pbd, vars(i)));
  return obj;
}

func obj2array(obj, &success) {
/* DOCUMENT obj2array(obj, &success)
  Converts an oxy group object into an array, if possible. Return parameter
  success is 1 if it was possible, or 0 if not. Returns [] when success == 0;

    > obj2array(save(a=10, b=20, c=30), success)
    [10,20,30]
    > success
    1
    > obj2array(save(), success)
    []
    > success
    1
    > obj2array(save(a=1,b="foo"), success)
    []
    > success
    0
*/
  success = 0;
  count = obj(*);

  if(!count) {
    success = 1;
    return [];
  }

  // Any errors means that we failed
  if(catch(0x01 | 0x08 | 0x10)) {
    return [];
  }

  // Scan object to determine member types and dimensions
  types = array(string, count);
  dims = array(short, count);
  for(i = 1; i <= count; i++) {
    types(i) = typeof(obj(noop(i)));

    d = dimsof(obj(noop(i)));
    if(numberof(d))
      dims(i) = d(1);
    else
      dims(i) = -1;
  }

  // Can't convert if everything isn't conformable
  if(nallof(dims == dims(1)))
    return [];

  // Upcast numeric types if needed
  has_int = has_flt = 0;

  upcast = ["char", "short", "int", "long"];
  idx = set_intersection(upcast, types, idx=1);
  if(numberof(idx)) {
    has_int = 1;
    upcast = upcast(idx(sort(idx)));
    idx = set_intersection(types, upcast, idx=1);
    types(idx) = upcast(0);
  }

  upcast = ["float", "double"];
  idx = set_intersection(upcast, types, idx=1);
  if(numberof(idx)) {
    has_flt = 1;
    upcast = upcast(idx(sort(idx)));
    idx = set_intersection(types, upcast, idx=1);
    types(idx) = upcast(0);
  }

  if(has_int && has_flt) {
    upcast = ["char", "short", "int", "long", "float", "double"];
    idx = set_intersection(types, upcast, idx=1);
    types(idx) = "double";
  }

  // Make sure only permissible types are present
  if(nallof(types == types(1)))
    return [];

  // Copy contents of obj to ary, but abort if any dims fail to match up
  dims = dimsof(obj(1));
  ary = array(symbol_def(types(1)), dims, count);
  for(i = 1; i <= count; i++) {
    if(nallof(dims == dimsof(obj(noop(i))))) {
      return [];
    }
    ary(..,i) = obj(noop(i));
  }

  success = 1;
  return ary;
}

func struct2hash(data) {
/* DOCUMENT struct2hash(data)
  Converts data that is held in a struct to an equivalent hash (using Yeti).
*/
  fields = get_members(data);
  hash = h_new();
  for(i = 1; i <= numberof(fields); i++) {
    h_set, hash, fields(i), get_member(data, fields(i));
  }
  return hash;
}

func struct2obj(data) {
/* DOCUMENT struct2obj(data)
  Converts data that is held in a struct to an equivalent oxy object.
*/
  fields = get_members(data);
  count = numberof(fields);
  obj = save();
  for(i = 1; i <= count; i++)
    save, obj, fields(i), get_member(data, fields(i));
  return obj;
}

func obj2struct(data, name=, ary=) {
/* DOCUMENT obj2struct(data, name=, ary=)
  Converts an oxy group object to a struct instance.

  Parameter:
    data: An oxy group object

  Options:
    name= The name to use for the temporary struct created to initialize the
      result. This defaults to "temp_struct". This must be a valid Yorick
      variable name.
    ary= By default, a scalar result is returned. Use ary=1 if all members are
      arrays with the same dimensionality to return an array of struct
      instances with the same dimensionality.

  SEE ALSO: hash2struct struct2hash struct2obj
*/
  default, name, "temp_struct";
  default, ary, 0;

  if(!data(*))
    return [];

  bkp = [];
  if(symbol_exists(name))
    bkp = symbol_def(name);

  keys = data(*,);
  if(noneof(keys))
    error, "no keys found";
  // have to eliminate anonymous members
  keys = keys(where(keys));

  count = numberof(keys);
  sdef = ["struct "+name+" {\n"];
  for(i = 1; i <= count; i++) {
    key = keys(i);
    val = data(noop(key));
    tmp = typeof(val) + " " + key;
    if(!ary && !is_scalar(val)) {
      dims = dimsof(val);
      ndims = numberof(dims);
      tmp += "(";
      for(j = 2; j <= ndims; j++) {
        tmp += swrite(format="%d", dims(j));
        if(j < ndims)
          tmp += ",";
      }
      tmp += ")";
    }
    tmp += ";\n";
    grow, sdef, tmp;
  }
  grow, sdef, "};\n";
  include, sdef, 1;

  if(ary)
    result = array(symbol_def(name), dimsof(val));
  else
    result = symbol_def(name)();

  for(i = 1; i <= count; i++) {
    get_member(result, keys(i)) = data(keys(i));
  }

  symbol_set, name, bkp;
  return result;
}

func hash2struct(data, name=, ary=) {
/* DOCUMENT hash2struct(data, name=, ary=)
  Converts a Yeti hash to a struct instance. See obj2struct for details.
  SEE ALSO: obj2struct struct2hash struct2obj
*/
  return obj2struct(hash2obj(data), name=name, ary=ary);
}

func list2obj(data) {
/* DOCUMENT list2obj(data)
  Converts a Yorick list DATA into a Yorick oxy group object.
*/
  count = _len(data);
  result = save();
  for(i = 1; i <= count; i++) {
    save, result, string(0), _car(data, i);
  }
  return result;
}

func args2obj(args) {
/* DOCUMENT args2obj(args)
  Converts an ARGS object (from wrap_args) into a Yorick oxy group object.
*/
  obj = save();
  for(i = 1; i <= args(0); i++)
    save, obj, string(0), args(noop(i));
  keys = args(-);
  count = numberof(keys);
  for(i = 1; i <= count; i++)
    save, obj, keys(i), args(keys(i));
  return obj;
}

func args2hash(args) {
/* DOCUMENT args2obj(args)
  Converts an ARGS object (from wrap_args) into a Yeti hash.
*/
  return obj2hash(args2obj(args));
}
