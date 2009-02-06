/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";
write, "$Id$";

local set_i;
/* DOCUMENT set_i

   This file provides functions for set operations:

      set_union
      set_intersection
      set_difference
      set_symmetric_difference
      set_cartesian_product
      set_remove_duplicates
   
   Note that a set's complement can be obtained with set_difference (see
   set_difference).

   All set functions assume that the arrays passed are one-dimensional and have
   no repeated elements (except set_remove_duplicates, which removes the
   repeated elements). The returned arrays will not have any guaranteed
   ordering for the elements, except where noted. Empty sets are permissible as
   [].
*/

func set_contains(A, b) {
/* DOCUMENT set_contains(A, b)
   Returns an array of boolean values indicating which values in b are
   contained in A.
*/
   idx = set_intersection(b, unref(A), idx=1);
   result = array(0, dimsof(b));
   if(numberof(idx))
      result(idx) = 1;
   return result;
}

func set_intersection(A, B, idx=) {
/* DOCUMENT set_intersection(A, B, idx=)

   Returns the intersection of the sets represented by A and B.

   The intersection of A and B is the set of all elements that occur in A that
   also occur in B.

   The elements of set_intersection(a,b) and set_intersection(b,a) will be the
   same, but the arrays will not be ordered the same.

   Options:

      idx= Set to 1 and the index of the intersection set into A will be
         returned instead of the elements.
*/
   default, idx, 0;

   // Trivial cases
   if(! numberof(A) || ! numberof(B))
      return [];

   // If A << B, then we'll get better performance if we switch the operands
   // (But we can only do that if idx=0)
   if(!idx && numberof(A) < numberof(B))
      return set_intersection(unref(B), unref(A));

   C = array(0, dimsof(A));
   for(i = 1; i <= numberof(B); i++)
      C |= (A == B(i));
   index = where(C);

   if(idx)
      return index;
   if(numberof(index))
      return A(index);
   else
      return [];
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

func set_remove_duplicates(A, idx=, ret_sort=) {
/* DOCUMENT set_remove_duplicates(A, idx=, ret_sort=)

   Returns the set A with its duplicate elements removed. The returned list
   will also be sorted.

   If idx=1, then the indices will be returned rather than the values.

   If ret_sort=1, then indexes will be returned into A(sort(A)). This is
   equivalent to (and in fact, calls) the unique function. This can be
   expensive, especially with large arrays of strings. Using ret_sort=0 is
   always more efficient than sorting externally, since it incorporates a sort.

   See also: unique (in ALPS, bathy_filter.i)
*/
   default, idx, 0;
   default, ret_sort, 0;
   if(ret_sort)
      return unique(unref(A), ret_sort=1);

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
   seq = where(grow([1n], A(:-1) != A(2:)));

   // If there's only one item, we're done!
   if(numberof(seq) == 1)
      return idx ? seq : A(seq);

   // Sort them
   srt = sort(A(seq));

   // Eliminate duplicates in the sorted sequence
   unq = where(grow([1n], A(seq)(srt)(:-1) != A(seq)(srt)(2:)));

   // If they want indices, we want to index into an index list instead of A
   if(idx) A = indgen(numberof(unref(A)));

   return A(seq)(srt)(unq);
}
