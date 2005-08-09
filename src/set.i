/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
write, "$Id$";

local set_i;
/* DOCUMENT set_i

	This file provides functions for set operations:

		set_union
		set_intersection
		set_difference
		set_symmetric_difference
		set_cartesian_product
		set_remove_dupicates
	
	Note that a set's complement can be obtained with set_difference
	(see set_difference).

	All set functions assume that the arrays passed are one-dimensional
	and have no repeated elements (except set_remove_duplicates, which
	removes the repeated elements). The returned arrays will not have
	any guaranteed ordering for the elements, except where noted. Empty
	sets are permissible as [].
*/

func set_intersection(A, B, idx=) {
/* DOCUMENT set_intersection(A, B, idx=)

	Returns the intersection of the sets represented by A and B.

	The intersection of A and B is the set of all elements that occur
	in A that also occur in B.

	The elements of set_intersection(a,b) and set_intersection(b,a)
	will be the same, but the arrays will not be ordered the same.

	Options:

		idx= Set to 1 and the index of the intersection set into A will
			be returned instead of the elements.
*/
	if(! numberof(A) || ! numberof(B))
		return [];
	C = array(0, numberof(A));
	for(i = 1; i <= numberof(A); i++) {
		for(j = 1; j <= numberof(B); j++) {
			if(A(i) == B(j)) {
				C(i) = 1;
			}
		}
	}
	index = where(C);
	if(idx)
		return index;
	if(numberof(index))
		return A(index);
	else
		return [];
}

func set_difference(A, B, idx=) {
/* DOCUMENT set_difference(A, B, idx=)

	Returns the difference of the sets represented by A and B.
	
	The difference of A - B is the set of all elements that occur
	in A that do not occur in B.

	The elements of set_difference(a,b) and set_difference(b,a)
	will usually be completely different.

	To obtain a set S's complement when S is a subset of X,
	use set_difference(X,S).

	Options:

		idx= Set to 1 and the index of the difference set into A will
			be returned instead of the elements.
*/
	if(! numberof(A) || ! numberof(B))
		return A;
	C = array(1, numberof(A));
	for(i = 1; i <= numberof(A); i++) {
		for(j = 1; j <= numberof(B); j++) {
			if(A(i) == B(j)) {
				C(i) = 0;
			}
		}
	}
	index = where(C);

	if(idx)
		return index;
	if(numberof(index))
		return A(index);
	else
		return [];
}

func set_symmetric_difference(A, B) {
/* DOCUMENT set_symmetric_difference(A, B)

	Returns the symmetric difference of the sets represented by A and B.

	The symmetric difference of A and B is all elements that occur in
	A or that occur in B, but that do not occur in both A and B.
	
	The elements of set_symmetric_difference(a,b) and
	set_symmetric_difference(b,a) will be the same, but the arrays will not
	be ordered the same.
*/
	AA = set_difference(A, B);
	BB = set_difference(B, A);

	if(! numberof(BB))
		return AA;
	if(! numberof(AA))
		return BB;

	AB = array(A(1), numberof(AA) + numberof(BB));
	AB(:numberof(AA)) = AA;
	AB(numberof(AA)+1:) = BB;

	return AB;
}

func set_union(A, B) {
/* DOCUMENT set_union(A, B)

	Returns the union of the sets represented by A and B.

	The union of A and B is the set of all elements that occur
	in A or in B. (Elements are not duplicated.)

	The elements of set_union(a,b) and set_union(b,a) will be
	the same, but the arrays will not be ordered the same.
*/
	sd = set_symmetric_difference(A, B);
	i  = set_intersection(A, B);

	if(! numberof(sd))
		return i;
	if(! numberof(i))
		return sd;

	u = array(A(1), numberof(sd) + numberof(i));
	u(:numberof(sd)) = sd;
	u(numberof(sd)+1:) = i;
	
	return u;
}

func set_cartesian_product(A, B) {
/* DOCUMENT set_cartesian_product(A, B)

	Returns the cartesian product of A and B.

	The cartesian product of A and B is the set of all ordered
	pairs [X,Y] where X is a member of A and Y is a member of B.
	
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

func set_remove_duplicates(A) {
/* DOCUMENT set_remove_duplicates(A)

	Returns the set A with its duplicate elements removed. The
	returned list will also be sorted.
*/
	if(! numberof(A))
		return [];
	sorted = A(sort(A));
	a = sorted(:-1);
	b = sorted(2:);
	remove = where(a == b);
	keep = set_difference(indgen(numberof(sorted)), remove);
	return sorted(keep);
}

