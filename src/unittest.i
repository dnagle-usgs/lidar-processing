// vim: set ts=2 sts=2 sw=2 ai sr et:

local unittest;
/* DOCUMENT unittest

  File unittest.i implements a very simple unit testing framework.

  A unittest file is simply a Yorick file that uses the command ut_ok to check
  outputs. Here's an example:

    a = 1;
    b = 3;
    ut_ok, a + b == 4, "addition works";
    ut_ok, "a != b";

  If you created a file test/mytest.i that contains the above, you can then run
  it like so:

    ut_run, "test/mytest.i";

  You will then get output showing how many tests and details on which tests
  failed.

  Alternately, you can run a directory of tests with an optional search string:

    ut_run_dir, "test", searchstr="*.i";

  There are two ways to invoke ut_ok, as shown above. The first is:
    ut_ok, expr, msg;
  In this case, expr should resolve into a true/false value and msg is a short
  string to identify that test case. The second is:
    ut_ok, "expr";
  In this case, the string "expr" should be an expression that resolves into a
  true/false value (as in the first case); however, it is also used as the
  descriptive text to identify the test case.

  A typical unittest file should not contain any function definitions. If you
  need function definitions, then you should wrap your main test body as a
  function named UT_TEST_CASES:

    func UT_TEST_CASES {
      a = 1;
      b = 3;
      ut_ok, a + b == 4, "addition works";
    }

  At then end of the UT_TEST_CASES function, be sure to redefine the functions
  you created to [] so that they do not persist outside of your unittest file.
*/

func ut_run_dir(dir, searchstr=) {
/* DOCUMENT ut_run_dir, dir, searchstr=
  Runs a directory of unit tests. If searchstr is omitted, it defaults to
  "*.i". If dir is omitted, it defaults to "test".

  SEE ALSO: unittest
*/
  default, dir, "test";
  default, searchstr, "*.i";
  files = find(dir, searchstr=searchstr);
  files = files(sort(files));
  n = numberof(files);
  for(i = 1; i <= n; i++) {
    write, format="\n%s\n", array("_", 72)(sum);
    write, format="\n%s\n", file_relative(dir, files(i));
    ut_run, files(i);
  }
}

func ut_run(fn) {
/* DOCUMENT ut_run, fn
  Evaluates a single unittest file.

  SEE ALSO: unittest
*/
  extern ut_res, ut_msg;

  ut_res = [];
  ut_msg = [];

  write, "";
  res = ut_run_helper(fn);
  write, format="%s", "\n\n";

  if(!res) {
    write, format="%s\n\n", "Encountered unexpected error!";
  }

  if(!numberof(ut_res)) {
    write, format="%s", "No tests run.\n";
    return;
  }

  write, format="Passed %d of %d tests.\n", ut_res(sum), numberof(ut_res);
  if(nallof(ut_res)) {
    write, format="\nFailures:%s", "\n";
    w = where(!ut_res);
    for(i = 1; i <= numberof(w); i++) {
      write, format="  %d: %s\n", w(i), ut_msg(w(i));
    }
  }

  if(!res) {
    write, format="\nLast test before error:\n  %d: %s\n",
      numberof(ut_res), ut_msg(0);
  }
}

/* ut_run_helper has to be a bit convoluted to work around yorick deficiencies.
 * Catch and include do not play well together. If the file is directly
 * included, or even if it's read to a string array and then included, catch
 * will fail to handle errors it raises. By reading it to a string array and
 * then bracketing it off as a function, this allows catch to work properly
 * because the source is only defining the function rather then executing the
 * code. (Though a syntax error would still cause problems.)
*/
func ut_run_helper(fn) {
/* DOCUMENT ut_run_helper(fn)
  Internal function for ut_run.
*/
  if(catch(-1)) {
    return 0;
  }
  code = rdfile(fn);
  if(noneof(strglob("*func UT_TEST_CASES*", code))) {
    code = grow("func UT_TEST_CASES {", code, "}");
  }
  include, code, 1;
  UT_TEST_CASES;
  UT_TEST_CASES = [];
  return 1;
}

func ut_item(res, msg) {
/* DOCUMENT ut_item, res, msg;
  Internal function for unittest framework. RES should be 0 or 1; 0 = failure,
  1 = success. MSG should be a string. A symbol (! or .) will be printed and
  the information will be appended to the test results.

  SEE ALSO: unittest
*/
  extern ut_res, ut_msg;
  default, msg, "unspecified";
  write, format="%s", ["!","."](res+1);
  grow, ut_res, res;
  grow, ut_msg, msg;
}

func ut_ok(expr, msg) {
/* DOCUMENT ut_ok, expr, "<msg>"
  -or- ut_ok, "<expr>"

  Unit test case that verifies that EXPR is true.

  If EXPR is a string and MSG is omitted, then EXPR is used for MSG and it is
  then evaluated like so to resolve it: "expr = ("+expr+")"

  SEE ALSO: unittest
*/
  if(is_string(expr) && is_void(msg)) {
    msg = expr;
    include, ["expr = ("+expr+");"], 1;
  }

  res = expr ? 1 : 0;
  ut_item, res, msg;
}

func ut_error(expr, msg) {
/* DOCUMENT ut_error, fnc, "<msg>";
  -or-  ut_error, "<expr>";

  Unit test case that verifies that FNC or EXPR throw an error. This test
  succeeds if the input throws an error. If it does not throw an error, then
  the test fails.

  FNC should be a function name. EXPR should be a string to evaluate.

  For example, this is a successful test case:

    ut_error, "tmp = 1/0.", "divide by zero";
*/
  if(catch(-1)) {
    ut_item, 1, msg;
    return;
  }
  if(is_string(expr)) {
    default, msg, expr(1);
    code = grow("func UT_ERROR_HELPER {", expr, "}");
    include, code, 1;
  } else {
    UT_ERROR_HELPER = expr;
  }
  if(is_func(UT_ERROR_HELPER)) {
    UT_ERROR_HELPER;
  }
  UT_ERROR_HELPER = [];
  ut_item, 0, msg;
}
