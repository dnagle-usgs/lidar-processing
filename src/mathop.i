local mathop_i;
/* DOCUMENT mathop_i

   Contains functional versions of some of the math operators. At present, this
   is primarily just the comparison operators. On rare occasions, it is helpful
   to have a functional form available for these things.

   Functions:
      lt le gt ge eq ne cmp

   Original David Nagle 2008-07-31
*/

func lt(a, b) { return a < b; }
/* DOCUMENT lt(a, b)
   Equivalent to a < b
*/

func le(a, b) { return a <= b; }
/* DOCUMENT le(a, b)
   Equivalent to a <= b
*/

func gt(a, b) { return a > b; }
/* DOCUMENT gt(a, b)
   Equivalent to a > b
*/

func ge(a, b) { return a >= b; }
/* DOCUMENT ge(a, b)
   Equivalent to a >= b
*/

func eq(a, b) { return a == b; }
/* DOCUMENT eq(a, b)
   Equivalent to a == b
*/

func ne(a, b) { return a != b; }
/* DOCUMENT ne(a, b)
   Equivalent to a != b
*/

func cmp(a, b) { return a < b ? -1 : a > b; }
/* DOCUMENT cmp(a, b)
   Equivalent to Perl's a <=> b. Will return:
      -1 if a < b
       0 if a == b
       1 if a > b
*/
