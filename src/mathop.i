// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

local mathop;
/* DOCUMENT mathop
   Yorick group object that defines functions equivalent to Yorick operators.
   Math operators typically are defined both with a name and a symbol.

   To obtain a reference to a function EXAMPLE, call with one of the following
   syntaxes:
      ref = mathop(EXAMPLE)
      ref = mathop("EXAMPLE")
      ref = mathop.EXAMPLE

   To use function EXAMPLE, if it is a function of two parameters, call like
   this:
      result = mathop(EXAMPLE, a, b)
      result = mathop("EXAMPLE", a, b)
      result = mathop.EXAMPLE, a, b
   Or, if you have a reference as acquired above:
      result = ref(a, b)
   Unary and ternary operators function similarly.

   On exception to the above: if you want to use a string for the operator's
   name and it is stored in a variable, you must wrap the variable's name in
   noop():
      ref = mathop(noop(VARNAME))
      result = matho(noop(VARNAME), a, b)

   Also, if you wish to use the symbol to reference the function, you must pass
   it as a string since it is not a valid Yorick bare variable name.

   Symbol   Name     #args    Comments
   ~        bw_not   1        bitwise not
   <        lt       2        less than
   <=       le       2        less than or equal to
   >        gt       2        greater than
   >=       ge       2        greater than or equal to
   ==       eq       2        equal
   !=       ne       2        not equal
   <=>      cmp      2        SCALAR ONLY; 0 if equal, -1 if <, 1 if >
*/

scratch = save(scratch, tmp);
tmp = save(lt, le, gt, ge, eq, ne, cmp, bw_not);

func lt(a, b) { return a < b; }
func le(a, b) { return a <= b; }
func gt(a, b) { return a > b; }
func ge(a, b) { return a >= b; }
func eq(a, b) { return a == b; }
func ne(a, b) { return a != b; }
func cmp(a, b) { return a < b ? -1 : a > b; }
func bw_not(a) { return ~a; }

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
