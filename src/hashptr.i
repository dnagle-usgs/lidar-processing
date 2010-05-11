local hashptr, hashptr_i;
/* DOCUMENT hashptr.i
   A hash pointer (or pointer hash) is an associate array structure that
   contains a set of key-value pairs stored using pointers. Such pointers
   should be handled exlusively by the functions in hashptr.i.

   A hash pointer is a simple pointer value. This pointer must point to a
   structure with the following requirements. Assuming the hash pointer is
   named "ptr", then...
      *ptr           ->  array(pointer, 2)
      *(*ptr)(1)     ->  array(char, X)      Character array of string names
      *(*ptr)(2)     ->  array(pointer, X)   Pointer array of values
      strchar(*(*ptr)(1))(1) -> first key
      strchar(*(*ptr)(1))(2) -> second key
      *(*(*ptr)(1))(1) -> first value
      *(*(*ptr)(1))(2) -> second value

   Keys and values are in the same order.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/

func p_keys(ptr) {
/* DOCUMENT keys = p_keys(ptr)
   Returns list of members of hash pointer PTR as a string vector of key names.
   The order in which keys are returned is arbitrary.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   // At present, for internal usage, ordering of keys and values will match,
   // and keys will be alphabetical. The suit of p_* functions may use this
   // implicit feature, but other code should NOT depend on it in case the
   // feature is removed later.
   keys = *(*ptr)(1);
   if(!numberof(keys))
      return [];
   if(numberof(keys))
      keys = strchar(keys);
   if(is_scalar(keys))
      keys = [keys];
   return keys;
}

func p_values(ptr) {
/* DOCUMENT vals = p_values(ptr)
   Returns list of values for hash pointer PTR as an array of pointers. The
   order in which values are returned is arbitrary (and may not correspond to
   order provided by p_keys).

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   // At present, for internal usage, ordering of keys and values will match,
   // and keys will be alphabetical. The suit of p_* functions may use this
   // implicit feature, but other code should NOT depend on it in case the
   // feature is removed later.
   return *(*ptr)(2);
}

func p_clean(ptr) {
/* DOCUMENT ptr = p_clean(ptr)
   PRIVATE FUNCTION: Not intended for use except internally within the suite of
   p_* functions. Implementation may change or function may be removed at later
   time.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   // This cleans up the hash pointer by removing duplicate keys (keeps last)
   keys = p_keys(ptr);
   vals = p_values(ptr);
   npairs = numberof(keys);
   if(npairs < 2)
      return p_assemble(keys, vals);
   idx = (npairs + 1) - set_remove_duplicates(keys(::-1), idx=1);
   keys = keys(idx);
   vals = vals(idx);
   return p_assemble(keys, vals);
}

func p_assemble(keys, vals) {
/* DOCUMENT ptr = p_assemble(keys, vals)
   PRIVATE FUNCTION: Not intended for use except internally within the suite of
   p_* functions. Implementation may change or function may be removed at later
   time.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   // Collates keys/values into the appropriate pointer format expected by
   // p_keys and p_values.
   // Store keys as a character array for better memory usage (Yorick struggles
   // with strings).
   if(is_string(keys))
      keys = pointer(keys);
   if(is_pointer(keys))
      keys = strchar(string(keys));
   return &[&keys, &vals];
}

func p_new(args) {
/* DOCUMENT ptr = p_new();
   or ptr = p_new(key=value, ...);
   or ptr = p_new("key", value, ...);

   Returns a new hash pointer with member(s) KEY set to VALUE. There may be any
   number of KEY-VALUE pairs. A particular member can be specified as a scalar
   string "KEY" or using keyword syntax key=; however, keyword syntax is only
   possible when KEY is a valid Yorick symbol name. VALUE can be anything that
   a pointer can point to.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   nargs = args(0);
   if(nargs == 1 && is_void(args(1)))
      nargs = 0;
   if(nargs % 2)
      error, "Key and value count must match.";

   // Extract "key", value pairs
   keys = vals = [];
   if(nargs) {
      npair = nargs / 2;
      grow, keys, array(string, npair);
      grow, vals, array(pointer, npair);
      for(i = 1; i <= npair; i++) {
         keys(i) = args(i*2-1);
         vals(i) = &args(i*2);
      }
   }
   ppositional = p_assemble(keys, vals);

   // Extract key=value pairs
   keys = args(-);
   vals = [];
   nkeys = numberof(keys);
   if(nkeys) {
      vals = array(pointer, nkeys);
      for(i = 1; i <= nkeys; i++)
         vals(i) = &args(-i);
   }
   pkeywords = nkeys ? p_assemble(keys, vals) : p_assemble([], []);

   return p_merge(ppositional, pkeywords);
}
wrap_args, p_new;

func p_copy(ptr) {
/* DOCUMENT p_copy(ptr);
   Make a copy of hash pointer PTR. Simple variable assignment does not
   actually make a copy of a hash pointer since it is simply a pointer value.
   Using p_copy will generate a distinct, independent hash pointer whose values
   are all identical to the original hash pointer.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   keys = p_keys(ptr);
   vals = p_values(ptr);
   npairs = numberof(keys);
   if(!npairs)
      return p_new();
   for(i = 1; i <= npairs; i++)
      vals(i) = &(*vals(i));
   return p_assemble(keys, vals);
}

func __p_keyname(args) {
/* DOCUMENT key = __p_keyname(args);
   PRIVATE FUNCTION: Not intended for use except internally within the suite of
   p_* functions. Implementation may change or function may be removed at later
   time.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   // Given an args object from wrap_args, returns the single key specified by
   // user. Intended for use within functions like p_get, which require a
   // single key.
   pkey = (args(0) == 2) ? args(2) : [];
   kkey = (numberof(args(-)) == 1) ? args(-)(1) : [];
   if(is_void(pkey) ~ is_void(kkey))
      return is_void(pkey) ? kkey : pkey;
   else
      return [];
}

func p_get(args) {
/* DOCUMENT p_get(ptr, key=);
         or p_get(ptr, "key");
   Returns the value of member KEY of pointer hash PTR. If no member KEY exists
   in PTR, nil is returned.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   ptr = args(1);
   key = __p_keyname(args);
   if(is_void(key))
      error, "Invalid argument/key count.";
   keys = p_keys(ptr);
   vals = p_values(ptr);
   w = where(keys == key);
   // If more than one match, we have an unclean hash... return last
   // matching item but don't complain.
   return (numberof(w)) ? *(vals(w)(0)) : [];
}
wrap_args, p_get;

func p_has(args) {
/* DOCUMENT p_has(ptr, "key");
         or p_has(ptr, key=);
   Returns 1 if member KEY is defined in hash pointer PTR, else 0.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   ptr = args(1);
   key = __p_keyname(args);
   if(is_void(key))
      error, "Invalid argument/key count.";
   keys = p_keys(ptr);
   return numberof(keys) ? anyof(keys == key) : [];
}
wrap_args, p_has;

func p_pop(args) {
/* DOCUMENT p_pop(ptr, "key");
         or p_pop(ptr, key=);
   Pop member KEY out of hash pointer PTR and return it. When called as a
   subroutine, the net result is therefore to delete the member from the hash
   pointer.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   ptr = args(1);
   key = __p_keyname(args);
   if(is_void(key))
      error, "Invalid argument/key count.";
   keys = p_keys(ptr);
   vals = p_values(ptr);
   match = keys == key;
   w = where(match);
   result = numberof(w) ? *(vals(w)(0)) : [];
   w = where(!match);
   newptr = numberof(w) ? p_assemble(keys(w), vals(w)) : p_new();
   (*ptr)(*) = (*newptr)(*);
   return result;
}
wrap_args, p_pop;

func p_set(args) {
/* DOCUMENT p_set, ptr, key=value, ...;
         or p_set, ptr, "key", value, ...;
   Stores VALUE in member KEY of hash pointer PTR. There may be any number of
   KEY-VALUE pairs. If called as a function, the returned value is PTR.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   nargs = args(0) - 1;
   if(nargs % 2)
      error, "Key and value count must match.";

   // Get original pointer
   poriginal = args(1);

   // Extract "key", value pairs
   keys = vals = [];
   if(nargs) {
      npair = nargs / 2;
      grow, keys, array(string, npair);
      grow, vals, array(pointer, npair);
      for(i = 1; i <= npair; i++) {
         keys(i) = args(i*2);
         vals(i) = &args(i*2+1);
      }
   }
   ppositional = p_assemble(keys, vals);

   // Extract key=value pairs
   keys = args(-);
   vals = [];
   nkeys = numberof(keys);
   if(nkeys) {
      vals = array(pointer, nkeys);
      for(i = 1; i <= nkeys; i++)
         vals(i) = &args(-i);
   }
   pkeywords = nkeys ? p_assemble(keys, vals) : p_assemble([], []);

   newptr = p_merge(poriginal, ppositional, pkeywords);
   (*poriginal)(*) = (*newptr)(*);
   return poriginal;
}
wrap_args, p_set;

func p_delete(args) {
/* DOCUMENT p_delete, ptr, "key", ...;
         or p_delete, ptr, ["key", ...];
         or p_delete, ptr, key=, ...;
   Delete members KEY, ... from pointer hash PTR, if they exist within it.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   ptr = args(1);
   drop = args(-);
   for(i = 2; i <= args(0); i++)
      grow, drop, args(i)(*);
   keys = p_keys(ptr);
   vals = p_values(ptr);
   w = set_difference(keys, drop, idx=1);
   newptr = numberof(w) ? p_assemble(keys(w), vals(w)) : p_new();
   (*ptr)(*) = (*newptr)(*);
   return ptr;
}
wrap_args, p_delete;

func p_info(ptr, align) {
/* DOCUMENT p_info, ptr;
         or p_info, ptr, align;
   List contents of hash pointer PTR in alphabetical order of keys. If second
   argument is true, the key names are right aligned.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   keys = p_keys(ptr);
   vals = p_values(ptr);
   npairs = numberof(keys);
   if(!npairs)
      return;
   len = strlen(keys)(max);
   fmt = align ? swrite(format="%%%ds:", len) : swrite(format="%%-%ds:", len);
   for(i = 1; i <= npairs; i++) {
      write, format=fmt, keys(i);
      info, *vals(i);
   }
}

func p_merge(ptr, ..) {
/* DOCUMENT p_merge(ptrA, ptrB, ...)
   Merges all of its arguments into a single hash pointer. All arguments must
   be valid pointer hashes. If multiple hashes contain the same key, the last
   instance takes precedence.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   default, ptr, &array(pointer, 2);
   keys = (*ptr)(1);
   vals = (*ptr)(2);
   while(more_args()) {
      ptr = next_arg();
      grow, keys, (*ptr)(1);
      grow, vals, (*ptr)(2);
   }
   keys = merge_pointers(keys);
   vals = merge_pointers(vals);
   return p_clean(p_assemble(keys, vals));
}

func p_number(ptr) {
/* DOCUMENT p_number(ptr)
   Returns the number of key-value pairs in PTR.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   return numberof(p_values(ptr));
}

func p_show(ptr) {
/* DOCUMENT p_show, ptr;
   Displays the contents of PTR in the same style that Yeti hashes are
   displayed via h_show.

   SEE ALSO: hashptr p_copy p_delete p_get p_has p_hash p_info p_keys p_merge
             p_new p_number p_pop p_set p_show p_values
*/
   h_show, p_hash(ptr);
}

func p_hash(ptr) {
/* DOCUMENT hash = p_hash(ptr);
   Convert hash pointer PTR into a Yeti hash HASH.

   SEE ALSO: h_new h_hashptr p_new
*/
   keys = p_keys(ptr);
   vals = p_values(ptr);
   hash = h_new();
   npairs = numberof(keys);
   for(i = 1; i <= npairs; i++) {
      h_set, hash, keys(i), *vals(i);
   }
   return hash;
}

func h_hashptr(hash) {
/* DOCUMENT ptr = h_hashptr(hash);
   Convert Yeti hash HASH into hash pointer PTR.

   SEE ALSO: h_new p_hash p_new
*/
   keys = h_keys(hash);
   npairs = numberof(keys);
   if(!npairs)
      return p_new();
   vals = array(pointer, npairs);
   for(i = 1; i <= npairs; i++) {
      vals(i) = &hash(keys(i));
   }
   return p_clean(p_assemble(keys, vals));
}
