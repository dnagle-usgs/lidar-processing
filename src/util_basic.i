// vim: set ts=2 sts=2 sw=2 ai sr et:

// Functions appearing in this file should have NO dependencies on other Yorick
// files. They should all be basic functions comprising of only built-in Yorick
// functionality.

func default(&var, val) {
/* DOCUMENT default, &variable, value

  This function is meant to be used at the beginning of functions as a helper.
  It will set the variable to value if and only if the variable is void. This
  is a very simple wrapper intended to help abbreviate code and help it
  self-document better.

  Parameters:

    variable: The variable to be set to a default value, if void. It will be
      updated in place.

    value: The default value.

  SEE ALSO: require_keywords
*/
  if(is_void(var)) var = val;
}

func require_keywords(args) {
/* DOCUMENT require_keywords, key1, key2, key3
  This checks each of the given variables to make sure that the user provided
  a non-void value for them.

  For example, consider this function:

    func increment(&x, amount=) {
      require_keywords, amount;
      x += amount;
    }

  If the user omits the "amount=" keyword (or if they provide it, but define
  it to []), then they will receive an error. Otherwise, it works. To
  illustrate:

    > x=0
    > increment, x, amount=5
    > x
    5
    > increment, x
    ERROR (increment) Missing required keyword: amount
    WARNING source code unavailable (try dbdis function)
    now at pc= 3 (of 21), failed at pc= 7
     To enter debug mode, type <RETURN> now (then dbexit to get out)
    >

  SEE ALSO: default
*/
  arg_count = args(0);
  for(i = 1; i <= arg_count; i++)
    if(is_string(args(-,i)) && is_void(args(i)))
      error, "Missing required keyword: "+args(-,i);
}
errs2caller, require_keywords;
wrap_args, require_keywords;

func popen_rdfile(cmd) {
/* DOCUMENT popen_rdfile(cmd)
  This opens a pipe to the command given and reads its output, returning it as
  an array of lines. (It combines popen and rdfile into a single function,
  thus the name.)
*/
  f = popen(cmd, 0);
  lines = rdfile(f);
  close, f;
  return lines;
}

func bound(val, bmin, bmax) {
/* DOCUMENT bound(val, bmin, bmax)
  Constrains a value to a set of bounds. Note that val can have any
  dimensions.

  If bmin <= val <= bmax, then returns val
  If val < bmin, then returns bmin
  if bmax < val, then returns bmax
*/
  return min(bmax, max(bmin, val));
}

func get_user(void) {
/* DOCUMENT get_user()
  Returns the current user's username. If not found, returns string(0).
*/
  if(_user) return _user;
  return get_env("USER");
}

func get_host(void) {
/* DOCUMENT get_host()
  Returns the current host's hostname. If not found, returns string(0).
*/
  if(get_env("HOSTNAME")) return get_env("HOSTNAME");
  return get_env("HOST");
}

func pass_void(f, val) {
/* DOCUMENT pass_void(f, val)
  If VAL is void, return VAL (that is, return []).
  Otherwise, return F(VAL).
  This is useful if you need to filter val through a function, but only if it's
  non-void -- and you're fine with it staying void if it already is.
*/
  if(is_void(val)) return val;
  return f(val);
}

func int_digits(num) {
/* DOCUMENT digits = int_digits(num)
  Returns the number of digitis required to represent the given value as an
  integer. The given value should probably an integer, but floats are also
  accepted.

  Typical usage is for constructing a format string for a series of integers to
  keep them the same length:

    > flts = indgen(12);
    > fmt = swrite(format="flt%%0%dd", int_digits(numberof(flts)));
    > swrite(format=fmt, flts);
    ["flt01","flt02","flt03","flt04","flt05","flt06","flt07","flt08","flt09",
    "flt10","flt11","flt12"]
*/
  return long(log10(num))+1;
}

func fastmax(ary) {
/* DOCUMENT val = fastmax(ary)
  Returns the maximum value in an array.

  If possible, this uses CALPS to provide a faster result than the native
  max(ary) or ary(max).
*/
  if(is_func(minmax) == 1)
    return max(ary);
  return minmax(ary)(2);
}

func fastmin(ary) {
/* DOCUMENT val = fastmin(ary)
  Returns the minimum value in an array.

  If possible, this uses CALPS to provide a faster result than the native
  min(ary) or ary(min).
*/
  if(is_func(minmax) == 1)
    return min(ary);
  return minmax(ary)(1);
}

func terminal_cols(void) {
/* DOCUMENT terminal_cols()
  Returns the number of columns in the current terminal window.
*/
  cols = rows = long(0);
  sread, popen_rdfile("stty size")(1), format="%d %d", rows, cols;
  return cols;
}
