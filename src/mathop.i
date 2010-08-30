// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

scratch = save(scratch, tmp);
tmp = save(lt, le, gt, ge, eq, ne, cmp, bw_not);

func lt(a, b) { return a < b; }
/* DOCUMENT lt(a, b)
   Equivalent to a < b
   SEE ALSO: le gt ge eq ne cmp bw_not
*/

func le(a, b) { return a <= b; }
/* DOCUMENT le(a, b)
   Equivalent to a <= b
   SEE ALSO: lt gt ge eq ne cmp bw_not
*/

func gt(a, b) { return a > b; }
/* DOCUMENT gt(a, b)
   Equivalent to a > b
   SEE ALSO: lt le ge eq ne cmp bw_not
*/

func ge(a, b) { return a >= b; }
/* DOCUMENT ge(a, b)
   Equivalent to a >= b
   SEE ALSO: lt le gt eq ne cmp bw_not
*/

func eq(a, b) { return a == b; }
/* DOCUMENT eq(a, b)
   Equivalent to a == b
   SEE ALSO: lt le gt ge ne cmp bw_not
*/

func ne(a, b) { return a != b; }
/* DOCUMENT ne(a, b)
   Equivalent to a != b
   SEE ALSO: lt le gt ge eq cmp bw_not
*/

func cmp(a, b) { return a < b ? -1 : a > b; }
/* DOCUMENT cmp(a, b)
   Equivalent to Perl's a <=> b. Will return:
      -1 if a < b
       0 if a == b
       1 if a > b
   SEE ALSO: lt le gt ge eq ne bw_not
*/

func bw_not(a) { return ~a; }
/* DOCUMENT bw_not(a)
   Equivalent to ~a
   SEE ALSO: lt le gt ge eq ne cmp
*/

mathop = restore(tmp);
restore, scratch;

save, mathop,
   "<", mathop.lt,
   "<=", mathop.le,
   ">", mathop.gt,
   ">=", mathop.ge,
   "==", mathop.eq,
   "!=", mathop.ne,
   "<=>", mathop.cmp,
   "~", mathop.bw_not;

func det(A) {
/* DOCUMENT det(A)
   Returns the determinant of A. A must be a square matrix. At present, this is
   only implemented for 2x2 and 3x3 matrices.

   > det([[5,2],[7,3]])
   1
   > det([[-1,2,0],[3,-2,1],[-2,9,-2]])
   13
*/
   dims = dimsof(A);
   if(dims(1) != 2 || dims(2) != dims(3) || dims(2) < 2)
      error, "'A' must be a 2x2 or 3x3 square matrix.";
   if(numberof(A) != 4 && numberof(A) != 9)
      error, "'A' must be a 2x2 or 3x3 square matrix.";

   if(is_func(_ydet))
      return _ydet(double(A), numberof(A));

   if(dims(2) == 2)
      return A(1)*A(4)-A(2)*A(3);

   if(dims(2) == 3)
      return A(1)*(A(5)*A(9)-A(6)*A(8)) +
         A(2)*(A(6)*A(7)-A(4)*A(9)) +
         A(3)*(A(4)*A(8)-A(5)*A(7));
}
