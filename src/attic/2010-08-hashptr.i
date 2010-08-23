/******************************************************************************\
* This file was moved to the attic on 2010-08-23. The functionality it was     *
* intended to provide is no longer needed due to the introduction of the oxy   *
* object system in Yorick. The functions here had not yet been put into use    *
* throughout the ALPS codebase.                                                *
\******************************************************************************/

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

func is_hashptr(obj) {
   // Must be scalar (implies non-void) pointer
   if(!is_scalar(obj) || !is_pointer(obj))
      return 0;

   // Dereferenced should yield array(pointer, 2)
   if(!is_pointer(*obj))
      return 0;

   // Dimensions must be [1,2] or [1,3]
   dims = dimsof(*obj);
   if(dims(1) != 1 || !anyof(dims(2) == [2,3]))
      return 0;

   // An empty hash pointer is [(nil), (nil)]; if we have this, return true
   if(noneof((*obj)(1:2)))
      return 1;

   obj1 = *(*obj)(1);
   obj2 = *(*obj)(2);

   // A non-empty hash pointer has a character vector for its first pointer value
   if(typeof(obj1) != "char" || !is_vector(obj1))
      return 0;

   // The second value should be a vector of pointers
   if(!is_pointer(obj2) || !is_vector(obj2))
      return 0;

   // When obj1 is turned into a string, it must match array size with obj2
   // Final test -- return result.
   return numberof(strchar(obj1)) == numberof(obj2);
}

func p_subkey_wrapper(args) {
/* DOCUMENT p_subkey_wrapper(obj, key, amsub, repl, default)
   This is intended to make it easy to make a "wrapper" function providing
   access to KEY in OBJ.

   Here is an example of a function that would use it:
      func test(obj, repl) {
         return p_subkey_wrapper(obj, "test", am_subroutine(), repl);
      }

   Such a function can them be called two ways, as a function or as a subroutine.

   The functional form allows you to interact with the key's content directly.
   For example, if the key points to another pointer hash, you could do the
   following:
      p_set, test(obj), foo="bar"
      p_get, test(obj), "foo"
      p_show, test(obj)
   This is shorter and perhaps clearer than the alternative:
      p_set, p_get(obj, test=), foo="bar"
      p_get, p_get(obj, test=), "foo"
      p_show, p_get(obj, test=)

   If OBJ does not have key KEY, then it will default to a pointer hash. You
   can alter this behavior by providing the optional DEFAULT argument, which
   provides an alternate value to use as a default.

   The subroutine form allows you to assign/replace the key's content. Any
   existing value is lost. For example:
      replacement = p_new(a=1, b=2, c=3)
      test, obj, replacement
   If you'd like to merge the replacement fields in with existing fields, you
   can do this instead:
      replacement = p_new(a=1, b=2, c=3)
      test, obj, p_merge(test(obj), replacement)

   Note: The above function "test" is an example and is not actually defined.
*/
   if(args(0) < 4 || 5 < args(0))
      error, "Invalid argument count.";
   if(args(3)) {
      p_set, args(1), args(2), args(4);
   } else {
      if(!p_has(args(1), args(2)))
         p_set, args(1), args(2), (args(0) > 4 ? args(5) : p_new());
      return p_get(args(1), args(2));
   }
}
wrap_args, p_subkey_wrapper;

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
