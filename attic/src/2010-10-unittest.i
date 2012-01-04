// vim: set ts=3 sts=3 sw=3 ai sr et:
/******************************************************************************\
* This file was moved to the attic on 2010-10-15. This functionality was never *
* utilized.                                                                    *
\******************************************************************************/

local unittest, tc_assert, tc_assert_false, tc_assert_equal,
tc_assert_not_equal, tc_assert_almost_equal, tc_assert_not_almost_equal,
tc_assert_error, tc_fail;
/* DOCUMENT Unit Testing Framework

   The functions in unittest.i provide a framework for developing unit tests.

   A suite of unit tests is run using tc_run. For example, the unit tests for
   hashptr.i would be run using:
      tc_run, "test_hashptr_*"

   The above command will find all functions that start with "test_hashptr_",
   then test each one. These functions are provided by the programmer,
   typically using a similarly named file in the test/ subdirectory (such as
   test/hashptr.i). The functions themselves are also typically named with a
   similar convention, as implied by the example above. Care should be taken
   that each suite has unique enough prefixes that a search pattern can be used
   to specify them without any unwanted inclusions.

   Unit testing functions should be written to accept no arguments, as they
   will be invoked with no arguments. When the function runs, one of three
   resulting states are detected:
      * The function ran without any issues
      * The function failed a defined testing condition
      * The function raised an error

   Checks for defined testing conditions are implemented using the following
   functions:
      tc_assert, expr, msg
            Asserts that EXPR must be true.
      tc_assert_false, expr, msg
            Asserts that EXPR must be false.
      tc_assert_equal, first, second, msg
            Asserts that FIRST must equal SECOND.
      tc_assert_not_equal, first, second, msg
            Asserts that FIRST must not equal SECOND.
      tc_assert_almost_equal, first, second, places, msg
            Asserts that FIRST and SECOND must be equal when rounded to PLACES
            decimal places. (Warning: this is NOT the same as precision.)
      tc_assert_not_almost_equal, first, second, places, msg
            Asserts that FIRST and SECOND must not be equal when rounded to
            PLACES decimal places. (Warning: this is NOT the same as
            precision.)
      tc_assert_error, cmd, msg
            Asserts that the given CMD should raise an error when called using
            funcdef. (Thus, CMD must be a string suitable for passing to
            funcdef.)
      tc_fail, msg
            Forces a failure.

   All of the above testing condition functions accept an optional argument MSG
   that specifies a message that should be provided if the test case fails. If
   not provided, it will default to a string based on its input.

   This framework is inspired by the Python unittest module and shares some
   light similarities with it.

   SEE ALSO: tc_run
*/

func tc_run(pattern, symbol_type=, report=, verbose=) {
/* DOCUMENT tc_run, pattern, symbol_type=, report=, verbose=
   Runs a set of test cases.

   Parameters:
      pattern: A search string representing the functions to test.

   Options:
      symbol_type= Restricts which kinds of functions should be used. Default
         is 2096. See symbol_names for details.
      report= Filename to write out the report to.
      verbose= How verbose to be.
            verbose=1      Normal report
            verbose=2      Include which tests passed as well

   Test case functions should be written to accept/require no parameters. They
   should use assertions as provided in the unittest.i framework.
*/
   default, verbose, 1;
   // 16: interpreted functions
   // 32: builtin functions
   // 2048: auto-loaded functions
   default, symbol_type, 2096;
   fns = symbol_names(symbol_type);

   w = where(strglob(pattern, fns));
   if(!numberof(w))
      error, "Search pattern matches no functions.";
   cases = fns(w);
   fns = [];

   cases = cases(sort(cases));
   ncases = numberof(cases);
   results = array(short, ncases);
   messages = array(string, ncases);

   local res, msg;
   t0 = t1 = array(double, 3);
   timer, t0;
   for(i = 1; i <= ncases; i++) {
      tc_run_case, cases(i), res, msg;
      results(i) = res;
      messages(i) = msg;

      write, format="%s", ["F","E","."](res);
   }
   timer, t1;

   output = swrite(format="Ran %d tests in %.3fs\n", ncases, t1(3)-t0(3));

   w = where(results == 0);
   num = numberof(w);
   if(num && verbose > 1) {
      output += "\n";
      output += swrite(format="PASSED in %d test cases:\n", num);
      output += swrite(format="  %s\n", cases(w))(sum);
   }

   w = where(results == 1);
   num = numberof(w);
   if(num) {
      output += "\n";
      output += swrite(format="FAILURE in %d test cases:\n", num);
      output += swrite(format="  %s : %s\n", cases(w), messages(w))(sum);
   }

   w = where(results == 2);
   num = numberof(w);
   if(num) {
      output += "\n";
      output += swrite(format="ERROR in %d test cases:\n", num);
      output += swrite(format="  %s : %s\n", cases(w), messages(w))(sum);
   }

   output += swrite(
      format="\nSummary:\n  PASS: %d\n  FAIL: %d\n ERROR: %d\n",
      numberof(where(results == 0)), numberof(where(results == 1)),
      numberof(where(results == 2)));

   write, format="\n\n%s\n", output;
   if(!is_void(report)) {
      f = open(report, "w");
      write, f, format="%s", output;
      close, f;
   }
}

func tc_run_case(tc, &res, &msg) {
/* DOCUMENT tc_run_case, tc, res, msg
   Called internally by tc_run. Runs a single test case. Do not use this
   function directly.

   Parameters:
      tc: The name of the test case function to run.
   Output parameters:
      res: The result. 0=pass, 1=fail, 2=error.
      msg: Message associated with failure or error.
*/
   if(catch(-1)) {
      if(regmatch("^TC ERROR: (.*)$", catch_message, , tcmsg)) {
         res = 1;
         msg = tcmsg;
      } else {
         res = 2;
         msg = catch_message;
      }
      return;
   }
   f = funcdef(tc);
   f;
   res = 0;
   msg = string(0);
}

func tc_assert(expr, msg) {
   default, msg, "tc_assert("+pr1(expr)+")";
   if(!expr) error, "TC ERROR: " + msg;
}

func tc_assert_false(expr, msg) {
   default, msg, "tc_assert_false("+pr1(expr)+")";
   if(expr) error, "TC ERROR: " + msg;
}

func tc_assert_equal(first, second, msg) {
   default, msg, "tc_assert_equal("+pr1(first)+","+pr1(second)+")";
   if(first != second) error, "TC ERROR: " + msg;
}

func tc_assert_not_equal(first, second, msg) {
   default, msg, "tc_assert_not_equal("+pr1(first)+","+pr1(second)+")";
   if(first == second) error, "TC ERROR: " + msg;
}

func tc_assert_almost_equal(first, second, places, msg) {
   default, places, 7;
   default, msg, "tc_assert_almost_equal("+pr1(first)+","+pr1(second)+","+pr1(places)+")";
   if(long(round(first*10^places)) != long(round(second*10^places)))
      error, "TC ERROR: " + msg;
}

func tc_assert_not_almost_equal(first, second, places, msg) {
   default, places, 7;
   default, msg, "tc_assert_not_almost_equal("+pr1(first)+","+pr1(second)+","+pr1(places)+")";
   if(long(round(first*10^places)) == long(round(second*10^places)))
      error, "TC ERROR: " + msg;
}

func tc_assert_error(cmd, msg) {
   default, msg, "tc_assert_error("+pr1(cmd)+")";
   if(!__tc_test_for_error(cmd)) error, "TC ERROR: " + msg;
}

func __tc_test_for_error(cmd) {
/* DOCUMENT __tc_test_for_error
   PRIVATE FUNCTION: Used internally by tc_assert_error.
*/
   if(catch(-1)) {
      return 1;
   }
   funcdef(cmd);
   return 0;
}

func tc_fail(msg) {
   default, msg, "tc_fail";
   error, "TC ERROR: " + msg;
}
