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
   ^        pow      2        raise to power
   *        mul      2        multiply
   /        div      2        divide
   %        mod      2        modulo
   +        add      2        add
   -        sub      2        subtract
   <<       lshift   2        left shift
   >>       rshift   2        right shift
   <        lt       2        less than
   <=       le       2        less than or equal to
   >        gt       2        greater than
   >=       ge       2        greater than or equal to
   ==       eq       2        equal
   !=       ne       2        not equal
   <=>      cmp      2        SCALAR ONLY; 0 if equal, -1 if <, 1 if >
   &&       and      2        SCALAR ONLY; logical and
   ||       or       2        SCALAR ONLY; logical or
   !        not      1        not
   (n/a)    bw_inv   1        bitwise complement
   ~        bw_xor   2        bitwise xor
   &        bw_and   2        bitwise and
   |        bw_or    2        bitwise or
   ?:       cond     3        ternary conditional
*/

scratch = save(scratch, tmp);
tmp = save(pow, mul, div, mod, add, sub, lshift, rshift, lt, le, gt, ge, eq,
   ne, cmp, and, or, not, bw_inv, bw_xor, bw_and, bw_or, cond);

func pow(a, b) { return a ^ b; }
func mul(a, b) { return a * b; }
func div(a, b) { return a / b; }
func mod(a, b) { return a % b; }
func add(a, b) { return a + b; }
func sub(a, b) { return a - b; }
func lshift(a, b) { return a << b; }
func rshift(a, b) { return a >> b; }
func lt(a, b) { return a < b; }
func le(a, b) { return a <= b; }
func gt(a, b) { return a > b; }
func ge(a, b) { return a >= b; }
func eq(a, b) { return a == b; }
func ne(a, b) { return a != b; }
func cmp(a, b) { return a < b ? -1 : a > b; }
func and(a, b) { return a && b; }
func or(a, b) { return a || b; }
func not(a) { return !a; }
func bw_inv(a) { return ~a; }
func bw_xor(a, b) { return a ~ b; }
func bw_and(a, b) { return a & b; }
func bw_or(a, b) { return a | b; }
func cond(a, b, c) { return a ? b : c; }

mathop = restore(tmp);
restore, scratch;

save, mathop,
   "^", mathop.pow,
   "*", mathop.mul,
   "/", mathop.div,
   "%", mathop.mod,
   "+", mathop.add,
   "-", mathop.sub,
   "<<", mathop.lshift,
   ">>", mathop.rshift,
   "<", mathop.lt,
   "<=", mathop.le,
   ">", mathop.gt,
   ">=", mathop.ge,
   "==", mathop.eq,
   "!=", mathop.ne,
   "<=>", mathop.cmp,
   "&&", mathop.and,
   "||", mathop.or,
   "!", mathop.not,
   "~", mathop.bw_xor,
   "&", mathop.bw_and,
   "|", mathop.bw_or,
   "?:", mathop.cond;

func math_parse_infix(expr, precedence=, operators=, accept_variables=,
accept_numbers=, accept_parens=) {
/* DOCUMENT postfix = math_parse_infix(expr, precedence=, operators=,
   accept_variables=, accept_numbers=, accept_parens=)

   Given an infix expression, this will return a deque object that contains the
   parsed postfix stack that corresponds to it. The stack may be passed to
   math_eval_postfix for evaluation.

   See math_eval_infix for documentation on the options accepted.
*/
   default, accept_variables, 1;
   default, accept_numbers, 1;
   default, accept_parens, 1;

   default, precedence, save(
      "!", 10,
      "^", 9,
      "*", 8, "/", 8, "%", 8,
      "+", 7, "-", 7,
      ">>", 6, "<<", 6,
      ">=", 5, ">", 5, "<=", 5, "<", 5,
      "==", 4, "!=", 4,
      "&", 3,
      "~", 2,
      "|", 1,
      "&&", 0, "||", 0
   );
   default, operators, precedence(*,);
   max_op_len = strlen(operators)(max);

   expr = strtrim(expr);

   postfix = deque();
   opstack = deque();
   while(strlen(expr)) {

      // parse off operator, if it exists; check from longest to shortest to
      // ensure we don't mistake "!=" as "!", etc.
      token = string(0);
      for(check = max_op_len; check; check--) {
         if(anyof(operators == strpart(expr, :check))) {
            token = strpart(expr, :check);
            break;
         }
      }

      // handle operator
      if(token) {
         check = precedence(noop(token));
         while(
            opstack(count,) && precedence(*,opstack(last,))
            && check <= precedence(opstack(last,))
         ) {
            postfix, push, opstack(pop,);
         }
         opstack, push, token;

      // handle parentheses
      } else if(strpart(expr, :1) == "(") {
         if(!accept_parens)
            error, "invalid input";
         token = "(";
         opstack, push, token;
      } else if(strpart(expr, :1) == ")") {
         if(!accept_parens)
            error, "invalid input";
         token = ")";
         while(opstack(count,) && opstack(last,) != "(")
            postfix, push, opstack(pop,);
         if(!opstack(count,))
            error, "mismatched parentheses";
         opstack, pop;

      } else {
         // handle variable names
         offset = strgrep("^[a-zA-Z_][a-zA-Z_0-9]*", expr);
         if(offset(2) > -1) {
            if(!accept_variables)
               error, "invalid input";
            token = strpart(expr, offset);
            postfix, push, token;
         } else {
            offset = strgrep("^([1-9][0-9]*)?[0-9]?\.?[1-9]+", expr);
            if(offset(2) > -1) {
               if(!accept_numbers)
                  error, "invalid input";
               token = strpart(expr, offset);
               postfix, push, token;
            } else {
               error, "invalid input";
            }
         }
      }

      // strip off the token now that we've consumed it
      expr = strtrim(strpart(expr, strlen(token)+1:), 1);
   }

   while(opstack(count,)) {
      if(opstack(last,) == "(")
         error, "mismatched parentheses";
      postfix, push, opstack(pop,);
   }
   opstack = [];

   return postfix;
}

func math_eval_postfix(postfix, operators=, operands=, math=, variables=,
missing=) {
/* DOCUMENT result = math_eval_postfix(postfix, operators=, operands=, math=,
   variables=, missing=)

   Given an postfix deque (as returned by math_parse_infix), this evaluate the
   stack and return the result.

   See math_eval_infix for documentation on the options accepted.
*/
   // By default, use math functions defined in mathop
   extern mathop;
   default, math, mathop;

   // This list of operators must match the default for math_parse_infix
   default, operators, ["!", "^", "*", "/", "%", "+", "-", ">>", "<<", ">=",
      ">", "<=", "<", "==", "!=", "&", "~", "|", "&&", "||"];

   // All operators are assumed to have 2 operands except for !, which has 1
   if(is_void(operands)) {
      operands = save();
      for(i = 1; i <= numberof(operators); i++)
         save, operands, operators(i), 2;
      save, operands, "!", 1;
   }

   // Make a copy so that we don't destroy the original
   postfix = deque(postfix.data);

   // process postfix using shunting-yard algorithm
   work = deque();
   while(postfix(count,)) {
      token = postfix(shift,);
      if(anyof(operators == token)) {
         params = operands(noop(token));
         if(params == 1) {
            A = work(pop,);
            work, push, math(noop(token), A);
         } else if(params == 2) {
            A = work(pop,);
            B = work(pop,);
            work, push, math(noop(token), A, B);
         } else if(params == 3) {
            A = work(pop,);
            B = work(pop,);
            C = work(pop,);
            work, push, math(noop(token), A, B, C);
         } else {
            error, "invalid operand count";
         }
      } else if(strgrep("^[a-zA-Z_][a-zA-Z_0-9]*$", token)(2) > -1) {
         if(is_void(variables))
            work, push, (symbol_exists(token) ? symbol_def(token) : missing);
         else
            work, push, (variables(*,token) ? variables(noop(token)) : missing);
      } else if(strgrep("^([1-9][0-9]*)?[0-9]?\.?[1-9]+$", token)(2) > -1) {
         work, push, atod(token);
      } else {
         error, "invalid input";
      }
   }

   if(work(count,) == 1)
      return work(pop,);
   else
      error, "invalid input";
}

func math_eval_infix(expr, precedence=, operators=, operands=, math=,
variables=, missing=, accept_variables=, accept_numbers=, accept_parens=) {
/* DOCUMENT result = math_eval_infix(expr, precedence=, operators=, operands=,
   math=, variables=, missing=, accept_variables=, accept_numbers=,
   accept_parens=)

   Evaluates an infix expression and returns the result. Infix notation is the
   normal notation used for mathematical expressions in Yorick. For example:
      2 * (3 - 5)
   Such expressions should be passed to this function in string form. They will
   then be evaluated, and a numerical result will be returned.

   Options:
      precedence= A Yorick group object whose keys are operators and whose
         values are precedence values. Higher precedence values indicate higher
         precedence. Example:
            precedence=save("*",2,"/",2,"+",1,"-",1)
         The default precedence object follows the Yorick rules for precedence,
         defining the following (from highest to lowest precedence):
            !              unary not
            ^              raise to power
            * / %          multiply, divide, modulo
            + -            add, subtract
            >> <<          right shift, left shift
            >= < <= >      (not) less, (not) greater
            == !=          equal, not equal
            &              bitwise and
            ~              bitwise xor
            |              bitwise or
            && ||          logical and, logical or
      operators= A string array whose values define which operators may be
         used. If not provided, all members from precedence will be used. This
         results in the following under the default value for precedence:
            operators=["!", "^", "*", "/", "%", "+", "-", ">>", "<<", ">=",
               ">", "<=", "<", "==", "!=", "&", "~", "|", "&&", "||"]
      operands= A Yorick group object that specifies how many operands each
         operator accepts. The default is initialized such that "!" has one
         operand and anything else has 2.
      math= A Yorick group object that defines the functions that may be used.
         This must have keys that match precedence, operators, and operands.
         The default is to use the extern mathop.
      variables= A Yorick group object defines the variables that may be used.
         If not provided, then variables are retrieved from the current symbol
         table.
      missing= Value to use if a variable is not found in variables; default is
         void [].
      accept_variables= Boolean specifying whether the expression may contain
         variables. Default is true.
      accept_numbers= Boolean specifying whether the expression may contain
         numbers. Default is true. However, only simple positive decimal
         numbers are accepted. So "120" and "1234.5679" are valid but "-4" and
         "1e23" are not. If you need a negative number, you'll need to use
         awkward syntax like "(0 - 5)" for -5.
      accept_parens= Boolean specifying whether the expression may contain
         parentheses for grouping. Default is true.
*/
   if(is_void(operators) && !is_void(precedence))
      operators = precedence(*,);
   pf = math_parse_infix(expr, precedence=precedence, operators=operators,
      accept_variables=accept_variables, accept_numbers=accept_numbers,
      accept_parens=accept_parens);
   return math_eval_postfix(pf, operators=operators, operands=operands,
      math=math, variables=variables, missing=missing);
}

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
