// vim: set ts=2 sts=2 sw=2 ai sr et:

local serialize, deserialize;
/* DOCUMENT serialize(data)
  -or- deserialize(data)

  As the functions' names imply, these functions convert Yorick variables to
  and from a serialized form. This serialized form is suitable for saving
  to/from pbd files.

  This is primarily intended for short-term use for exchanging data between
  Yorick processes (as with distributed processing). It is not recommended for
  long-term storage.
*/

scratch = save(scratch, tmps, tmpu,
  serialize_direct, deserialize_direct,
  serialize_function, deserialize_function,
  serialize_oxygroup, deserialize_oxygroup,
  serialize_struct_instance, deserialize_struct_instance,
  serialize_yetihash, deserialize_yetihash
);

tmps = save();
tmpu = save();

func serialize(helper, data) {
  if(is_hash(data)) return helper(yetihash, data);
  if(is_obj(data)) return helper(oxygroup, data);
  if(typeof(data) == "struct_instance") return helper(struct_instance, data);
  if(is_func(data)) return helper(function, data);
  return helper(direct, data);
}

func deserialize(helper, data) {
  return helper(*data(1), data);
}

func serialize_direct(data) {
  type = "direct";
  return [&type, &noop(data)];
}
save, tmps, direct=serialize_direct;

func deserialize_direct(data) {
  return *data(2);
}
save, tmpu, direct=deserialize_direct;

func serialize_function(data) {
  name = nameof(data);
  type = is_void(name) ? "direct" : "function";
  return [&type, &name];
}
save, tmps, function=serialize_function;

func deserialize_function(data) {
  name = *data(2);
  if(symbol_exists(name))
    return symbol_def(name);
  return [];
}
save, tmpu, function=deserialize_function;

func serialize_oxygroup(data) {
  type = "oxygroup";
  if(!data(*)) {
    null = [];
    return [&type, &null, &null];
  }
  keys = data(*,);
  vals = array(pointer, data(*));
  for(i = 1; i <= data(*); i++) {
    vals(i) = &serialize(data(noop(i)));
  }
  return [&type, &keys, &vals];
}
save, tmps, oxygroup=serialize_oxygroup;

func deserialize_oxygroup(data) {
  keys = *data(2);
  vals = *data(3);
  result = save();
  for(i = 1; i <= numberof(keys); i++) {
    save, result, keys(i), deserialize(*vals(i));
  }
  return result;
}
save, tmpu, oxygroup=deserialize_oxygroup;

func serialize_struct_instance(data) {
  type = "struct_instance";
  name = nameof(structof(data));
  val = serialize(struct2obj(data));
  return [&type, &name, &val];
}
save, tmps, struct_instance=serialize_struct_instance;

func deserialize_struct_instance(data) {
  name = *data(2);
  obj = deserialize(*data(3));
  result = obj2struct(obj, name=name);
  if(symbol_exists(name) && is_struct(symbol_def(name)))
    struct_cast, result, symbol_def(name);
  return result;
}
save, tmpu, struct_instance=deserialize_struct_instance;

func serialize_yetihash(data) {
  type = "yetihash";
  keys = h_keys(data);
  count = numberof(keys);
  if(!count) {
    null = [];
    return [&type, &null, &null];
  }
  vals = array(pointer, count);
  for(i = 1; i <= count; i++) {
    vals(i) = &serialize(h_get(data, keys(i)));
  }
  return [&type, &keys, &vals];
}
save, tmps, yetihash=serialize_yetihash;

func deserialize_yetihash(data) {
  keys = *data(2);
  vals = *data(3);
  result = h_new();
  for(i = 1; i <= numberof(keys); i++) {
    h_set, result, keys(i), deserialize(*vals(i));
  }
  return result;
}
save, tmpu, yetihash=deserialize_yetihash;

serialize = closure(serialize, tmps);
deserialize = closure(deserialize, tmpu);

restore, scratch;
