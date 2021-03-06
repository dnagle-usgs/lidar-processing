// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "rrequire.i";
require, "ascii_encode.i";
require, "yeti.i";

require, "ytk_tksync.i";

local ytk;
/* DOCUMENT ytk

  Ytk is a Tcl/Tk/Expect program to glue Yorick and Tcl/Tk together in order
  to give Yorick programs better GUI capabilities.

  Original YTK can be found at http://ytk.sf.net and is distributed with this
  notice:

    Copyright C. W. Wright IAW with GNU GENERAL PUBLIC LICENSE Version 2,
    June 1991.  Find a copy in gpl.txt distributed with this package.

  This version is heavily modified from the original to better suit the needs
  of ALPS.
*/

func initialize_ytk(ytk_fn, tky_fn) {
/* DOCUMENT initialize_ytk, ytk_fn, ytk_fn
  Initializes the Yorick side of the Ytk environment. The two filenames should
  be the pipes Tcl has created for interacting with Yorick.
*/
  open_tkcmd_fifo, ytk_fn;
  open_tky_fifo, tky_fn;
  tkcmd, "set ::Y_SITE {" + Y_SITE + "}";
  write, "Ytk ready.  Yorick and Tcl/Tk communication pipes established.";
}

func open_tkcmd_fifo(fn) {
/* DOCUMENT open_tkcmd, fifo, fn
  Attempts to open the ytk fifo. If it's already open, throws an error.
*/
  extern ytkfifo;
  if(!is_void(ytkfifo) && typeof(ytkfifo) == "text_stream") {
    error, "The tkcmd fifo is already open!";
  } else {
    ytkfifo = open( fn, "r+");
  }
}

func open_tky_fifo(fn) {
/* DOCUMENT open_tky_fifo, fn
  Attempts to open the tky fifo. If it's already open, throws an error.
*/
  extern tkyfifo;
  if(!is_void(tkyfifo) && typeof(tkyfifo) == "spawn-process") {
    error, "The tky fifo is already open!";
  } else {
    tkyfifo = spawn(["cat", fn], tky_stdout);
  }
}

/*******************************************************************************
 * Handling for Tcl "ybkg" command
 */
scratch = save(scratch, temp, tky_bg_stdout, tky_decode, tky_bg_handler,
  tky_bg_pop, tky_bg_append);
temp = save(fragment, data, stdout, decode, handler, pop, append);
fragment = [];
data = save();
func tky_bg_stdout(msg) {
  self = use();
  fragment = self.fragment;
  lines = spawn_callback(fragment, msg);
  save, self, fragment;
  for(i = 1; i <= numberof(lines); i++) {
    line = lines(i);
    if(!line) {
      // process has died! should probably handle this better...
    } else {
      if(logger && logger(trace))
        logger, trace, "Raw background command: "+line;
      cmd = strpart(line, 1:3);
      data = strpart(line, 5:);
      if(cmd == "bkg") {
        data = self(decode, data);
        if(logger && logger(trace))
          logger, trace, "Received background command: "+data;
        self, append, data;
        tkcmd, "set ::__ybkg__wait 0"
      } else {
        if(logger && logger(warn))
          logger, warn, "Received unknown command type: "+cmd;
      }
    }
  }
  after, 0, self, handler;
}
stdout = tky_bg_stdout;

func tky_decode(data) {
  if(catch(0x10)) {
    if(logger && logger(error))
      logger, error, "Error encountered decoding background command: "+data;
    return "";
  }
  return strchar(base64_decode(data));
}
decode = tky_decode;

func tky_bg_handler {
  self = use();
  if(self.data(*)) {
    f = self(pop,);
    safe_run_funcdef, funcdef(f);
    after, 0, self, handler;
    tksync, check;
  }
}
handler = tky_bg_handler;

func tky_bg_pop(nil) {
  self = use();
  if(self.data(*)) {
    item = self.data(1);
    if(self.data(*) > 1)
      save, self, data=self.data(2:);
    else
      save, self, data=save();
    return item;
  } else {
    return [];
  }
}
pop = tky_bg_pop;

func tky_bg_append(item) {
  use, data;
  save, data, string(0), item;
}
append = tky_bg_append;

tky_bg = restore(temp);
restore, scratch;

func tky_stdout(msg) {
  extern ytk_bg;
  tky_bg, stdout, msg;
}

func safe_run_funcdef(f) {
  if(catch(-1)) {
    if(logger && logger(error))
      logger, warn, "safe_run_funcdef encountered an error";
    return;
  }
  f;
  return;
}

/* End of "ybkg" handling
 ******************************************************************************/

func tkcmd(s, async=) {
/* DOCUMENT tkcmd, s;
  This sends its input to Tcl for evaluation. The string must be a valid
  statement suitable for evaluation in Tcl.

  Commands are normally sent asynchronously. For non-asynchronous operation,
  add async=0 to your command. For example, for a 1-second pause:
    tkcmd, "after 1000", async=0
*/
  extern ytkfifo, _pid, Y_USER;
  if(logger && logger(trace))
    logger, trace, "Sending background command: "+pr1(s);
  write, ytkfifo, format="%s\n", s;
  if(ytkfifo)
    fflush, ytkfifo;
  if(!is_void(async) && !async) {
    blockfn = swrite(format="tkyunblock.%d", _pid);
    mkdirp, Y_USER;
    write, ytkfifo, "::fileutil::writeFile {" + Y_USER + "/" + blockfn + "} {}";
    if(ytkfifo)
      fflush, ytkfifo;
    if(logger && logger(trace))
      logger, trace, "  async mode - blocking";
    while(noneof(lsdir(Y_USER) == blockfn))
      continue;
    if(logger && logger(trace))
      logger, trace, "  async mode - unblocked";
    remove, Y_USER + "/" + blockfn;
  }
}

func tksetval(tkvar, yval) {
/* DOCUMENT tksetval, tkvar, yval
  Given the name of a tcl variable (as a string) and an arbitrary Yorick
  value, this will set the tcl variable to that value.

  SEE ALSO: tksetvar
*/
  p = print(yval)(sum);
  // If yval contains a string that is too long, it will receive a line
  // continuation character. This corrupts the data when sent to Tcl.
  // Increasing the line length fixes the issue.
  // TODO: Find a solution that doens't reset print_format to 80, since that
  // clobbers any user-set value. (That does not happen often though.)
  if(strlen(p) > 79) {
    print_format, strlen(p);
    p = print(yval)(sum);
    print_format, 80;
  }
  tkcmd, swrite(format="tky_set %s {%s}", tkvar, p);
}

func tksetvar(tkvar, yvar) {
/* DOCUMENT tksetvar, tkvar, yvar
  Given the name of a tcl variable (as a string) and a Yorick variable
  expression (as a string), this will set the tcl variable to the Yorick
  variable's value.

  SEE ALSO: tksetval
*/
  tksetval, tkvar, var_expr_get(yvar);
}

func tksetsym(tkvar, ysym) {
/* DOCUMENT tksetsym, tkvar, ysym
  Given the name of a tcl variable (as a string) and the name of a Yorick
  variable (as a string), this will set the tcl variable to the Yorick
  variable's value.

  This can handle dotted symbols, such as foo.bar.baz. They will be
  dereferenced using var_expr_get.
*/
  tksetval, tkvar, var_expr_get(ysym);
}

func tksetfunc(tkvar, yfunc, ..) {
/* DOCUMENT tksetsym, tkvar, yfunc, ..
  Given the name of a tcl variable (as a string) and the name of a Yorick
  function (as a string), this will set the tcl variable to the return value
  of the function. If additional arguments are given, they will be passed to
  the Yorick function when it is called. Currently, a maximum of 4 arguments
  may be passed. (Options are not supported.)
*/
  args = [];
  while(more_args())
    grow, args, &next_arg();
  nargs = numberof(args);
  if(nargs == 0)
    tksetval, tkvar, symbol_def(yfunc)();
  else if(nargs == 1)
    tksetval, tkvar, symbol_def(yfunc)(*args(1));
  else if(nargs == 2)
    tksetval, tkvar, symbol_def(yfunc)(*args(1), *args(2));
  else if(nargs == 3)
    tksetval, tkvar, symbol_def(yfunc)(*args(1), *args(2), *args(3));
  else if(nargs == 4)
    tksetval, tkvar, symbol_def(yfunc)(*args(1), *args(2), *args(3), *args(4));
  else
    error, "tksetfunc not yet implemented for more than 4 arguments."
}

func var_expr_tkupdate(expr, tkval) {
/* DOCUMENT var_expr_tkupdate, expr, tkval
  Given a variable expression (expr), this will update it to a new value as
  specified by tkval. However, it tries to maintain type. So if expr is a
  string, it stays a string; if expr is a double, tkval is cast to a double;
  etc. Tkval is expected to be provided as a string.
*/
  val = var_expr_get(expr);
  if(anyof(typeof(val) == ["long","int","short","double","float"])) {
    newval = double(0);
    sread, tkval, format="%f", newval;
    newval = structof(val)(newval);
  } else {
    // either it's a string, or we can't handle it properly
    newval = tkval;
  }
  var_expr_set, expr, newval;
}

func var_expr_get(expr) {
/* DOCUMENT val = var_expr_get(expr)
  Given a variable expression (scalar string), this returns its value.

  A variable expression can be any valid Yorick variable name or any valid
  Yorick variable name followed key names delimited by commas. This allows you
  to retrieve nested values from plain variables, struct instances, Yeti
  hashes, and oxy group objects.

  A non-existing expression results in [].

  Examples:

    > foo = 42
    > var_expr_get("foo")
    42
    > foo = h_new(bar=h_new(baz=42))
    > var_expr_get("foo.bar.baz")
    42
    > foo = save(bar=save(baz=42))
    > var_expr_get("foo.bar.baz")
    42
    > foo = save(bar=h_new(baz=42))
    > var_expr_get("foo.bar.baz")
    42
    > struct BAR { long baz; }
    > struct FOO { BAR bar; }
    > foo = FOO(bar=BAR(baz=42))
    > var_expr_get("foo.bar.baz")
    42

  SEE ALSO: var_expr_set
*/
  parts = strtok(expr, ".");
  val = symbol_exists(parts(1)) ? symbol_def(parts(1)) : [];
  while(parts(2)) {
    parts = strtok(parts(2), ".");
    val = has_member(val, parts(1)) ? get_member(val, parts(1)) : [];
  }
  return val;
}

func var_expr_set(expr, val) {
/* DOCUMENT var_expr_set, expr, val
  Given a variable expression (scalar string), this sets its value.

  See var_expr_get for what is permissible for expr.

  Examples:

    > foo = 10
    > foo
    10
    > var_expr_set, "foo", 5
    > foo
    5
    > foo = h_new(bar=h_new(baz=42))
    > foo.bar.baz
    42
    > var_expr_set, "foo.bar.baz", 3.14
    > foo.bar.baz
    3.14

  If a variable expression doesn't exist, it will be created. If a nested
  container is needed, it will be created as a Yeti hash if its parent is a
  Yeti hash; otherwise, it will be created as an oxy group object.
*/
  parts = strtok(expr, ".");

  // If there's a period, then we must dereference
  if(parts(2)) {
    parent = var = [];

    // If symbol exists, load it in
    if(symbol_exists(parts(1))) {
      var = is_array(symbol_def(parts(1))) \
        ? &symbol_def(parts(1)) : symbol_def(parts(1));
    }
    // If symbol can't be dereferenced, clobber it with a new oxy group
    if(!has_members(var, deref=1)) {
      symbol_set, parts(1), save();
      var = symbol_def(parts(1));
    }

    // processed contains the string corresponding to var's current value
    processed = parts(1);

    // Deference until we have no more subkeys to process
    while(parts(2)) {
      parent = var;
      parts = strtok(parts(2), ".");
      if(parts(2)) {
        // If it doesn't have the key specified, we must create it
        if(!has_member(var, parts(1))) {
          // If the variable isn't an object/hash, then clobber + force it to
          // be
          if(!is_hash(var) && !is_obj(var)) {
            if(is_hash(parent)) {
              var_expr_set, processed, h_new();
            } else {
              var_expr_set, processed, save();
            }
            var = var_expr_get(processed);
          }
          if(is_hash(var))
            h_set, var, parts(1), h_new();
          else
            save, var, parts(1), save();
        }
        var = is_pointer(var) ? *var : var;
        var = is_array(get_member(var, parts(1))) \
          ? &get_member(var, parts(1)) : get_member(var, parts(1));
        processed += "." + parts(1);
      }
    }

    // Hashes are straightforward: add or replace key
    if(is_hash(var)) {
      h_set, var, parts(1), val;
    // Oxy group -- update
    } else if(is_obj(var)) {
      save, var, parts(1), val;
    // Hash key -- update
    } else if(is_pointer(var) && has_member(*var, parts(1))) {
      get_member(*var, parts(1)) = val;
    // No key -- clobber + add
    } else {
      var_expr_set, processed, save();
      var = var_expr_get(processed);
      save, var, parts(1), val;
    }

  // No period! Just set it.
  } else {
    symbol_set, parts(1), val;
  }
}

func ytk_not_present(void) {
/* DOCUMENT ytk_not_present;
  Prints a message saying ytk isn't present. Helper function for various ytk
  functions.
*/
  write, "Ytk not present. This function will not work without the ytk program.";
}
