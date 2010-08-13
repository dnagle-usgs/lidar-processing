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
