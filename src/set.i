// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func set_contains(A, b) {
/* DOCUMENT set_contains(A, b)
   Returns an array of boolean values indicating which values in b are
   contained in A.
*/
   idx = set_intersection(b, unref(A), idx=1);
   result = array(0, dimsof(b));
   if(numberof(idx)) {
      if(dimsof(result)(1))
         result(idx) = 1;
      else
         result = 1;
   }
   return result;
}

func set_intersection(A, B, idx=, delta=) {
/* DOCUMENT set_intersection(A, B, idx=, delta=)

   Returns the intersection of the sets represented by A and B.

   The intersection of A and B is the set of all elements that occur in A that
   also occur in B.

   The elements of set_intersection(a,b) and set_intersection(b,a) will be the
   same, but the arrays will not be ordered the same.

   Options:

      idx= Set to 1 and the index of the intersection set into A will be
         returned instead of the elements.

      delta= If provided, this provides the range over which values are
         considered equal, useful when dealing with floats and doubles.
*/
   default, idx, 0;
   default, delta, 0;

   // Trivial case
   if(! numberof(A) || ! numberof(B))
      return [];

   aw = set_remove_duplicates(A, idx=1);
   B = set_remove_duplicates(B);
   an = numberof(aw);
   bn = numberof(B);
   ai = bi = 1;
   C = array(short(0), numberof(aw));
   if(delta) {
      while(ai <= an && bi <= bn) {
         if(abs(A(aw(ai)) - B(bi)) <= delta) {
            C(ai) = 1;
            ai++;
            bi++;
         } else {
            if(A(aw(ai)) < B(bi))
               ai++;
            else
               bi++;
         }
      }
   } else {
      while(ai <= an && bi <= bn) {
         if(A(aw(ai)) == B(bi)) {
            C(ai) = 1;
            ai++;
            bi++;
         } else {
            if(A(aw(ai)) < B(bi))
               ai++;
            else
               bi++;
         }
      }
   }
   index = where(C);
   if(idx)
      return aw(index);
   if(numberof(index))
      return A(aw(index))
   else
      return [];
}

func set_intersect3(A, B) {
/* DOCUMENT result = set_intersect3(A, B)

   Returns the intersection and differences between sets A and B. Return result
   will be a Yorick group object.

      result.left  -or-  result(1)
         Items in A that are not in B. (A - B)
      result.both  -or-  result(2)
         Items in both A and B. (A * B)
      result.right  -or-  result(3)
         Items in B that are not in A. (B - A)

   Unlike other set commands, this does not accept idx= or delta= options.
*/
   C = set_union(A, B);
   state = array(0, numberof(C));
   idx = set_intersection(C, A, idx=1);
   if(numberof(idx))
      state(idx)--;
   idx = set_intersection(C, B, idx=1);
   if(numberof(idx))
      state(idx)++;
   result = save();
   w = where(state == -1);
   save, result, left=(numberof(w) ? C(w) : []);
   w = where(state == 0);
   save, result, both=(numberof(w) ? C(w) : []);
   w = where(state == 1);
   save, result, right=(numberof(w) ? C(w) : []);
   return result;
}

func set_difference(A, B, idx=, delta=) {
/* DOCUMENT set_difference(A, B, idx=, delta=)

   Returns the difference of the sets represented by A and B.
   
   The difference of A - B is the set of all elements that occur in A that do
   not occur in B.

   The elements of set_difference(a,b) and set_difference(b,a) will usually be
   completely different.

   To obtain a set S's complement when S is a subset of X, use
   set_difference(X,S).

   Options:

      idx= Set to 1 and the index of the difference set into A will be returned
         instead of the elements.

      delta= If provided, this provides the range over which values are
         considered equal, useful when dealing with floats and doubles.
*/
   default, idx, 0;
   default, delta, 0;

   // Trivial cases
   if(! numberof(A))
      return [];
   if(! numberof(B))
      return idx ? indgen(numberof(A)) : A;

   C = array(1, numberof(A));
   if(delta)
      for(i = 1; i <= numberof(B); i++)
         C &= (abs(A - B(i)) > delta);
   else
      for(i = 1; i <= numberof(B); i++)
         C &= (A != B(i));
   index = where(C);

   if(idx)
      return index;
   if(numberof(index))
      return A(index);
   else
      return [];
}

func set_symmetric_difference(A, B, delta=) {
/* DOCUMENT set_symmetric_difference(A, B, delta=)

   Returns the symmetric difference of the sets represented by A and B.

   The symmetric difference of A and B is all elements that occur in A or that
   occur in B, but that do not occur in both A and B.
   
   The elements of set_symmetric_difference(a,b) and
   set_symmetric_difference(b,a) will be the same, but the arrays may not be
   ordered the same.
   
   Options:

      delta= If provided, this provides the range over which values are
         considered equal, useful when dealing with floats and doubles.
*/
   default, delta, 0;
   return grow(set_difference(A, B, delta=delta), set_difference(B, A, delta=delta));
}

func set_union(A, B) {
/* DOCUMENT set_union(A, B)

   Returns the union of the sets represented by A and B.

   The union of A and B is the set of all elements that occur in A or in B.
   (Elements are not duplicated.)

   The elements of set_union(a,b) and set_union(b,a) will be the same, but the
   arrays may not be ordered the same.
*/
   return set_remove_duplicates(grow(unref(A), unref(B)));
}

func set_cartesian_product(A, B) {
/* DOCUMENT set_cartesian_product(A, B)

   Returns the cartesian product of A and B.

   The cartesian product of A and B is the set of all ordered pairs [X,Y] where
   X is a member of A and Y is a member of B.
   
   The returned array will be two-dimensional.
   
   If,   cp = set_cartesian_product(a,b);
   Then, cp(,1) is the values from a
         cp(,2) is the values from b
         cp(i,) is the ith ordered pair [xi,yi]
*/
   if(! numberof(A) || ! numberof(B))
      return [];
   C = array(A(1), numberof(A)*numberof(B), 2);
   C(,1) = A(-:1:numberof(B),)(*);
   C(,2) = B(,-:1:numberof(A))(*);
   return C;
}

func set_remove_duplicates(A, idx=, delta=) {
/* DOCUMENT set_remove_duplicates(A, idx=, delta=)

   Returns the set A with its duplicate elements removed. The returned list
   will also be sorted.

   If idx=1, then the indices will be returned rather than the values.

   See also: unique (in ALPS, bathy_filter.i)
*/
   default, idx, 0;
   default, delta, 0;
   if(delta)
      return set_remove_duplicates_delta(A, delta=delta, idx=idx);

   // Trivial/edge cases
   if(! numberof(A))
      return [];
   if(numberof(A) == 1)
      return idx ? [1] : A;

   if(typeof(A) == "string")
      return set_remove_duplicates_string(unref(A), idx=idx);

   // Eliminate any dimensionality
   A = unref(A)(*);

   // Eliminate duplicates in the initial sequence. Valuable when there are a
   // large number of items that take a long time to sort, especially with
   // strings.
   seq = where(grow([1n], A(:-1) != A(2:)));

   // If there's only one item, we're done!
   if(numberof(seq) == 1)
      return idx ? seq : A(seq);

   // Sort them
   srt = heapsort(A(seq));

   // Eliminate duplicates in the sorted sequence
   unq = where(grow([1n], A(seq)(srt)(:-1) != A(seq)(srt)(2:)));

   // If they want indices, we want to index into an index list instead of A
   if(idx) A = indgen(numberof(unref(A)));

   return A(seq)(srt)(unq);
}

func set_remove_duplicates_delta(A, delta=, idx=) {
   extern EPSILON;
   default, delta, EPSILON;
   default, idx, 0;

   // Trivial/edge cases
   if(! numberof(A))
      return [];
   if(numberof(A) == 1)
      return idx ? [1] : A;

   // Eliminate any dimensionality
   A = unref(A)(*);

   // Eliminate duplicates in the initial sequence. Valuable when there are a
   // large number of items that take a long time to sort, especially with
   // strings.
   seq = where(grow([1n], abs(A(:-1) - A(2:)) > delta));

   // If there's only one item, we're done!
   if(numberof(seq) == 1)
      return idx ? seq : A(seq);

   // Sort them
   srt = heapsort(A(seq));

   // Eliminate duplicates in the sorted sequence
   unq = where(grow([1n], abs(A(seq)(srt)(:-1) - A(seq)(srt)(2:)) > delta));

   // If they want indices, we want to index into an index list instead of A
   if(idx) A = indgen(numberof(unref(A)));

   return A(seq)(srt)(unq);
}

func set_remove_duplicates_string(A, idx=) {
/* DOCUMENT set_remove_duplicates_string(A, idx=)
   Returns the set A with its duplicate elements removed. The returned list
   will also be sorted.
   
   Note that A *must* be strings. Anything else will cause an error.

   If idx=1, then the indices will be returned rather than the values.

   See also: set_remove_duplicates
*/
// Original David Nagle 2009-07-15
// Speed trials shows that this algorithm works much faster than the one in
// set_remove_duplicates for strings, due to Yorick's slow performance with
// string sorting.
   default, idx, 0;
   // Create a hash table that has a key for each unique item. Set the value to
   // the first index we found it at.
   set = h_new();
   for(i = 1; i <= numberof(A); i++) {
      if(! h_has(set, A(i)))
         h_set, set, A(i), i;
   }
   A = [];
   // Sort and return the list, if they do not want indexes.
   keys = h_keys(set);
   keys = keys(sort(keys));
   if(! idx)
      return keys;
   // If they want indexes, we have to manually extract them from the hash.
   idx = array(long, dimsof(keys));
   for(i = 1; i <= numberof(keys); i++) {
      idx(i) = set(keys(i));
   }
   return idx;
}

func unique(x) {
/* DOCUMENT unique(x)
   Returns the indexes into x corresponding to unique values. This is exactly
   equivalent to set_remove_duplicates(x, idx=1). Example:
      > data = [1,2,1,2,3,2,1,2,3,4,3,2,1]
      > unique(data) // index list
      [13,4,9,10]
      > data(unique(data)) // values
      [1,2,3,4]

   SEE ALSO: set_remove_duplicates sort
*/
   return set_remove_duplicates(unref(x), idx=1);
}

func heapsort_rank(x, &list) {
/* DOCUMENT heapsort_rank(x)
   -or- heapsort_rank(x, list)
   Identical to msort_rank, except it uses heapsort instead of sort.
*/
   rank = array(0, dimsof(x));
   if(numberof(x) < 2) return rank;
   void = use_origins(0);
   list = heapsort(x(*));
   x = x(list);
   x = (x(1:-1) != x(2:0))(cum);
   rank(list) = x;
   return rank;
}

func munique(x, ..) {
/* DOCUMENT munique(x1, x2, x3, ...)
   Returns the indexes into the given arrays that correspond to unique tuples
   of values. For example, if you have a set of points identified by x and y,
   then munique(x,y) is all unique x,y points.

   The Xi may be numbers or strings in any combination, but must all be
   conformable arrays.

   SEE ALSO: unique munique_array msort
*/
   mxrank = numberof(x)-1;
   rank = heapsort_rank(x);

   norm = 1./(mxrank+1.);
   if(1.+norm == 1.) error, pr1(mxrank+1)+" is too large an array";

   while(max(rank) != mxrank && more_args()) {
      x = next_arg();
      rank += heapsort_rank(x) * norm;
      rank = heapsort_rank(rank);
   }

   return unique(rank);
}

func munique_array(x, which) {
/* DOCUMENT munique_array(x, which)
   This is like munique, but instead of operating over multiple arrays, it
   operates over a single array along one of its dimensions (like msort_array).
   The WHICH parameter specifies which dimension to use, defaulting to the
   smallest.

   SEE ALSO: unique munique msort_array
*/
   dims = dimsof(x);
   default, which, dims(2:)(mnx);

   // Juggle dimensions so that we can index into final dimension
   if(which != dims(1))
      x = transpose(x, indgen(dims(1):which:-1));

   count = dims(which+1);
   mxrank = numberof(x(..,1))-1;
   rank = heapsort_rank(x(..,1));

   norm = 1./(mxrank+1.);
   if(1.+norm == 1.) error, pr1(mxrank+1)+" is too large an array";

   for(i = 2; i <= count && max(rank) != mxrank; i++) {
      rank += heapsort_rank(x(..,i))*norm;
      rank = heapsort_rank(rank);
   }

   return unique(rank);
}
