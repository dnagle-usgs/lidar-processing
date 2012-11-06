// vim: set ts=2 sts=2 sw=2 ai sr et:

/*
  Implementation note:

  For disabling assert, it might be tempting to redefine it using "noop". That
  would result in a no-operation invocation and would allow one to dispense
  with the "if(assert)" protection. However, this is sub-optimal.

  Consider this block using the noop approach:

    assert = noop;
    foo = random(10000000);
    assert, noneof(foo < 0), "random made a negative number";

  The assert line is handled by Yorick as follows:
    1. Compare all 10 million random doubles to 0, resulting in an array of 10
      million longs.
    2. Scan through the 10 million longs to make sure all are zero, resulting
      in scalar 1.
    3. Pass the value 1 and the value "random made a negative number" to
      "noop", which does nothing.

  Consider the same block using the "if(assert)" protection:

    assert = [];
    foo = random(10000000);
    if(assert) assert, noneof(foo < 0), "random made a negative number";

  The assert line is handled by Yorick as follows:
    1. The if statement tests "assert" and finds it to be false. Execution
      skips over the true branch, which means nothing is done.

  In the contrived example above, the "noop" approach results in 20 million
  unwanted operations, whereas the "if(assert)" approach results in just one.
  Typically assertions are disabled to boost performance, so "if(assert)" is
  the clear winner.
*/

func assert(expr, msg) {
/* DOCUMENT assert
  Usage:
    if(assert) assert, <expr>
    if(assert) assert, <expr>, "<msg>"

  Asserts that a given expression should always be true. If the given
  expression is not true, an error will result.

  Calls to assert should ALWAYS be protected by if statements as shown above.
  If assertions are disabled, the command is redefined to void and thus will
  generate an error if you try to invoke it as a function.
  
  If msg is given, it should be a string describing the assertion failure. This
  will result in an error messages like this:
    ERROR (*main*) assert failed: <msg>
  If msg is omitted, the error will instead resemble this:
    ERROR (*main*) assert failed

  Do NOT use assert to test for "normal" error conditions, such as whether a
  user selected a file that exists. Assert should be used only for tests that
  you never expect to fail. The function should be able to work properly if
  assertions are disabled, so use another mechanism to test things such as user
  input.

  If you provide msg, try to construct it in such a way as to avoid errors in
  the construction of the string. For instance, avoid a construction like this:
    assert, x >= 1, swrite(format="non-positive x value of %d", x)
  This would only work if x is an integer. This "improvement"
  is also to be avoided:
    assert, x >= 1, swrite(format="non-positive x value of %f", double(x))
  This will fail if x is somehow a string or other non-numeric value. Instead,
  use the pr1 function to force the value into string form like so:
    assert, x >= 1, swrite(format="non-positive x value of %s", pr1(x))

  To disable assertions, simply invoke:
    assert_disable
  To later re-enable assertions, simply invoke:
    assert_enable

  Assertions are enabled by default (and will be re-enabled if you re-source
  assert.i).

  Please do not disable assertions unless you specifically need to. Having
  assertions enabled may help to track down obscure bugs when they happen
  unexpectedly.
*/
  if(expr) return;
  if(is_string(msg)) {
    if(logger && logger(error)) logger, error, "assertion failed: "+msg;
    error, "assertion failed: "+msg;
  } else {
    if(logger && logger(error)) logger, error, "assertion failed";
    error, "assertion failed";
  }
}
errs2caller, assert;

func assert_enable(fnc) {
/* DOCUMENT assert_enable
  Enables assertions.

  SEE ALSO: assert assert_disable
*/
  extern assert;
  assert = fnc;
  if(logger && logger(info)) logger, info, "assertions enabled";
}
assert_enable = closure(assert_enable, assert);

func assert_disable(void) {
/* DOCUMENT assert_disable
  Disables assertions.

  SEE ALSO: assert assert_enable
*/
  extern assert;
  assert = [];
  if(logger && logger(info)) logger, info, "assertions disabled";
}

// Enable by default (this is largely redundant, but is invoked for clarity's
// sake and to trigger logging if available).
assert_enable;
