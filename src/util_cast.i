// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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

func list2array(lst, strict=, depth=) {
/* DOCUMENT list2array(lst, strict=, depth=)
   Converts a Yorick list into a Yorick array, if possible. If not possible,
   will return the original list.

   This can handle char, int, long, float, double, and string values. If
   the list contains a mixture, then it will cast everything in whatever
   can handle them all. (For example: a mix of int and double will be cast
   as double; a mix of int, float, and string will be cast as string.)

   If strict=1, then it will not try to typecast numerical values as strings.

   If depth is positive, this will recurse that many additional layers if it
   finds nested lists. So, depth=1 will possibly return up to a two-dimensional
   array and depth=5 can return up to a 6-dimensional array. If depth is
   negative, it will recurse to any depth. By default, no recursion is done.
*/
   default, strict, 0;
   default, depth, 0;

   // lists are always passed by reference. We make changes, and we don't want
   // to propogate them.
   lst = _cpy(lst);
   orig_lst = _cpy(lst);
   if(depth != 0) {
      nextdepth = depth - 1;
      for(i = 1; i <= _len(lst); i++) {
         item = _car(lst, i);
         if(typeof(item) == "list")
            _car, lst, i, list2array(item, depth=nextdepth, strict=strict);
      }
   }

   types = ["char", "int", "long", "float", "double", "string"];
   cast = -1;
   count = _len(lst);
   dims = dimsof(_car(lst, 1));
   ary_l = array(long, dims, count);
   ary_d = array(double, dims, count);
   ary_s = array(string, dims, count);
   has_num = 0;
   has_str = 0;
   for(i = 1; i <= count; i++) {
      item = _car(lst, i);

      // Check dimensionality
      if(dimsof(item)(1) != dims(1)) return orig_lst;
      if((dimsof(item) != dims)(sum) > 0) return orig_lst;

      // Check type
      typ = where(typeof(item) == types);
      if(numberof(typ) != 1) {
         // Unknown type!
         return orig_lst;
      } else {
         typ = typ(1);
      }
      if(typeof(item) == "string") {
         has_str = 1;
      } else {
         has_num = 1;
      }

      // Check for strict violation
      if(strict && has_str && has_num) return orig_lst;

      cast = max([cast, typ]);
      if(typ == 1) {
         ary_l(..,i) = ary_d(..,i) = item;
         ary_s(..,i) = swrite(format="%c", item);
      } else if(typ <= 3) {
         ary_l(..,i) = ary_d(..,i) = item;
         ary_s(..,i) = swrite(format="%d", item);
      } else if(typ <= 5) {
         ary_d(..,i) = item;
         ary_s(..,i) = swrite(format="%.16e", item);
      } else {
         ary_s(..,i) = item;
      }
   }
   if(cast < 0) {
      return orig_lst;
   } else if(cast == 1) {
      return char(ary_l);
   } else if(cast == 2) {
      return int(ary_l);
   } else if(cast == 3) {
      return ary_l;
   } else if(cast == 4) {
      return float(ary_d);
   } else if(cast == 5) {
      return ary_d;
   } else {
      return ary_s;
   }
}
