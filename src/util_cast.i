// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";

func pointers2group(pary) {
/* DOCUMENT grp = pointers2group(pary)
   Given an array of pointers PARY, this returns a group object GRP that
   contains the dereferenced pointers' contents such that grp(i) == *pary(i).
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

   SEE ALSO: pbd2hash
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

func obj2pbd(obj, pbd) {
/* DOCUMENT obj2pbd, obj, pbd
   Converts a Yorick group object to a PBD file. Caveat: Only group members
   that are arrays and have non-nil key names will get saved.

   SEE ALSO: pbd2obj
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

   SEE ALSO: obj2pbd
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
