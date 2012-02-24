// vim: set ts=2 sts=2 sw=2 ai sr et:

scratch = save(scratch, tmp, mapobj_serialize, mapobj_deserialize, mapobj_cleanup, mapobj_set, mapobj_lookup, mapobj_query, mapobj_where, mapobj_grow, mapobj_index);
tmp = save(__bless, __version, serialize, deserialize, cleanup, set, lookup, query, where, grow, index, help);

/*
  names, mapping
*/

__bless = "mapobj";
__version = 1;
func mapobj(base, start) {
/* DOCUMENT mapobj()
  Creates a mapping object. This can be called in the following ways:

    data = mapobj(count)
      Creates a mapping object with COUNT items. All items are initialized to
      the empty string, "".
    data = mapobj(string_vector)
      Creates a mapping object with numberof(STRING_VECTOR) items. The items
      are initialized to the strings found in STRING_VECTOR, such that
      data(lookup,) == STRING_VECTOR.
    data = mapobj(chardata)
      Restores a mapping object using an array of character data CHARDATA, as
      returned by the serialize method.
    data = mapobj(oxy_group)
      Converts the given OXY_GROUP into a mapping object. It is recommended to
      only use this against items that were already MAPOBJ objects. Creating a
      suitable OXY_GROUP manually requires knowlege of this class's internals,
      which may change.

  A mapobj object is comprised of two data members as well as various methods.
  Some of these are considered "private" and some of them are considered
  "public". Calling code should avoid using "private" members and methods.

  Data members:
    data(names,)      public    array(string)
      An array containing the unique names used in this mapping. This will be
      sorteda
    data(mapping,)    private   array(long)
      An array containing indexes into data(names,) that map each item onto its
      corresponding string value.

  Public methods:
    data, help
      Displays this help documentation.
    data(serialize,)
      Returns an array of type char that represents the data stored in the
      object. This character array is opaque; outside code should not try to
      modify it. The mapping object can be restored later by calling mapobj
      with this character data as its argument.
    data, set, idx, name
      Set the name for the items specified by IDX to NAME. IDX can be an index
      list (array of longs), a range, or may be omitted to apply to all items.
      NAME may be a scalar string or an array of strings whose length matches
      the specified items.
    data(lookup, idx)
      Returns the names for the items specified by IDX. IDX can be an index
      list (array of longs), a range, or may be omitted to return all items.
    data(where, wanted)
      Returns an index list (or <nuller>) indicating which items match the
      given WANTED names. WANTED may be a scalar string or an array of strings.
    data(query, wanted)
      Returns an array indicating which items match the given WANTED names,
      such that where(data(query,wanted)) == data(where,wanted).
    data, grow, obj
      Extends the current mapping object by appending the data from the given
      OBJ, which must also be a mapping object.
    data(index, idx)
      Returns a new mapobj that contains just the items specified by IDX.

  Private methods (for internal use only):
    data(deserialize, chardata)
      Given an array of chardata, returns an oxy group with the corresponding
      names and mapping members.
    data, cleanup, &names, &mapping
      This is a class method instead of an object method. It does some cleanup
      on the given NAMES and MAPPING arrays, simplifying the code in other
      methods.

*/
  if(is_obj(start)) {
    if(am_subroutine)
      obj = start;
    else
      obj = obj_copy(start);
  } else {
    names = mapping = [];
    if(is_scalar(start)) {
      mapping = array(char(1), start);
      names = [""];
      obj = save(names, mapping);
    } else if(is_string(start)) {
      names = set_remove_duplicates(start);
      mapping = array(long, numberof(start));
      for(i = 1; i <= numberof(names); i++) {
        w = where(start == names(i));
        mapping(w) = i;
      }
      base, cleanup, names, mapping;
      obj = save(names, mapping);
    } else {
      obj = base.deserialize(start);
    }
  }
  obj_copy, base, obj;
  return obj;
}

func mapobj_serialize(nil) {
  use, __version, names, mapping;
  numnames = numberof(names);

  // byte sequence:
  //  byte 0: marker, always 0
  //  byte 1: version number
  //  next bytes are names with null terminators
  //  following last name is a second null terminator
  //  remaining data is encoded mapped values:
  //    if numberof(names) < 0xff, then mapped values are char
  //    if numberof(names) >= 0xff, mapped values are two-byte integers as
  //      sequence of char
  // this only supports up to 65,535 names, if we need more, it can be extended
  // later

  if(!numnames)
    error, "Invalid data found!";

  if(numnames <= 0xff)
    return grow(char(0), char(__version), strchar(names), char(0), char(mapping(*)));

  if(numnames > 0xffff)
    error, "Too many names; must implement support for more than 65535 names";

  return grow(char(0), char(__version), strchar(names), char(0), i16char(mapping(*)));
}
serialize = mapobj_serialize;

func mapobj_deserialize(bits) {
/*
  This is a private class method. It does not utilize any internal data and may
  be called directly from the base class.
*/
  if(numberof(bits) < 3)
    error, "too few bytes";
  if(bits(1) != 0)
    error, "invalid leading byte";
  version = long(bits(2));
  bits = bits(3:);

  data = save();

  if(version == 1) {
    zeroes = !bits;
    w = where(zeroes(:-1) & zeroes(2:));
    if(!numberof(w))
      error, "invalid data";

    names = strchar(bits(:w(1)));
    mapping = bits(w(1)+2:);
    save, data, names, mapping;
  // version != 1
  } else {
    error, "unknown version number";
  }

  return data;
}
deserialize = mapobj_deserialize;

func mapobj_cleanup(&names, &mapping) {
  len = strlen(names);
  if(nallof(len))
    names(where(!len)) = "";
  used = set_remove_duplicates(mapping);
  if(!numberof(used) || nallof(used))
    error, "invalid mapping";
  newnames = names(used);
  newnames = newnames(sort(newnames));
  numnames = numberof(newnames);
  if(numnames == numberof(names)) {
    if(allof(newnames == names))
      return;
  }
  newmapping = mapping;
  for(i = 1; i <= numnames; i++) {
    j = where(newnames(i) == names)(1);
    if(i == j) continue;
    w = where(mapping == j);
    newmapping(w) = i;
  }
  names = newnames;
  mapping = newmapping;
}
cleanup = mapobj_cleanup;

func mapobj_set(idx, name) {
  use, names, mapping;
  grow, names, set_difference(name, names);
  numnames = numberof(names);
  count = numberof(mapping);
  if(is_range(idx))
    idx = range_to_index(idx, count);
  else if(is_void(idx))
    idx = indgen(count);
  if(is_scalar(name) && numberof(name) < numberof(idx))
    name = array(name, numberof(idx));
  for(i = 1; i <= numnames; i++) {
    w = where(name == names(i));
    if(!numberof(w)) continue;
    mapping(idx(w)) = i;
  }
  names;
  noop, use(cleanup, names, mapping);
}
set = mapobj_set;

func mapobj_lookup(idx) {
  use, names, mapping;
  return names(mapping(idx));
}
lookup = mapobj_lookup;

func mapobj_query(wanted) {
  use, mapping;
  result = array(char(0), numberof(mapping));
  w = use(where, wanted);
  if(numberof(w)) result(w) = 1;
  return result;
}
query = mapobj_query;

func mapobj_where(wanted) {
  use, names, mapping;
  w = set_intersection(names, wanted, idx=1);
  if(!numberof(w))
    return where(0);
  return set_intersection(mapping, w, idx=1);
}
where = mapobj_where;

func mapobj_grow(obj) {
  use, names, mapping;
  grow, mapping, obj(mapping,)+numberof(names);
  grow, names, obj(names,);
  noop, use(cleanup, names, mapping);
}
grow = mapobj_grow;

func mapobj_index(idx) {
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
  if(is_string(idx))
    idx = use(where, idx);
  obj_index, res, idx;
  mapobj, res;
  return res;
}
index = mapobj_index;

help = closure(help, mapobj);

mapobj = closure(mapobj, restore(tmp));
restore, scratch;
