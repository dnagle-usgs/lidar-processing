// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "ascii_encode.i";
require, "yeti.i";

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
scratch = save(scratch, temp, tky_bg_stdout, tky_bg_handler, tky_bg_pop,
  tky_bg_append);
temp = save(fragment, data, stdout, handler, pop, append);
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
      cmd = strpart(line, 1:3);
      data = strpart(line, 5:);
      if(cmd == "bkg") {
        data = strchar(base64_decode(data));
        self, append, data;
        tkcmd, "set ::__ybkg__wait 0"
      } else {
      }
    }
  }
  after, 0, self, handler;
}
stdout = tky_bg_stdout;

func tky_bg_handler {
  self = use();
  if(self.data(*)) {
    f = self(pop,);
    safe_run_funcdef, funcdef(f);
    after, 0, self, handler;
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
  write, ytkfifo, s;
  if(ytkfifo)
    fflush, ytkfifo;
  if(!is_void(async) && !async) {
    blockfn = swrite(format="tkyunblock.%d", _pid);
    mkdirp, Y_USER;
    write, ytkfifo, "::fileutil::writeFile {" + Y_USER + "/" + blockfn + "} {}";
    if(ytkfifo)
      fflush, ytkfifo;
    while(noneof(lsdir(Y_USER) == blockfn))
      continue;
    remove, Y_USER + "/" + blockfn;
  }
}

func tksetval(tkvar, yval) {
/* DOCUMENT tksetval, tkvar, yval
  Given the name of a tcl variable (as a string) and an arbitrary Yorick
  value, this will set the tcl variable to that value.

  See also: tksetvar
*/
// Original David Nagle 2009-08-13
  tkcmd, swrite(format="tky_set %s {%s}", tkvar, print(yval)(sum));
}

func tksetvar(tkvar, yvar) {
/* DOCUMENT tksetvar, tkvar, yvar
  Given the name of a tcl variable (as a string) and a Yorick variable
  expression (as a string), this will set the tcl variable to the Yorick
  variable's value.

  See also: tksetval
*/
// Original David Nagle 2009-09-14
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
// Original David Nagle 2009-08-13
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
// Original David Nagle 2010-02-16
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
// Original David Nagle 2009-08-14
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

  The variable expression can be any of the following:

    - The name of a variable.
    - The name of a yeti hash value with dotted keys to dereference.
    - The name of a variable of struct data with dotted fields to
      dereference.

  A non-existing expression results in [].

  Examples:

    > foo = 10
    > var_expr_get("foo")
    10
    > foo = h_new(bar=h_new(baz=42))
    > var_expr_get("foo.bar.baz")
    42

  See also: var_expr_set
*/
// Original David Nagle 2009-08-14
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

*/
// Original David Nagle 2009-08-14
  parts = strtok(expr, ".");

  // If there's a period, then we must dereference
  if(parts(2)) {
    parent = var = [];

    // If symbol exists, load it in
    if(symbol_exists(parts(1))) {
      var = is_array(symbol_def(parts(1))) \
        ? &symbol_def(parts(1)) : symbol_def(parts(1));
    }
    // If symbol can't be dereferenced, clobber it with a new Yeti hash
    if(!has_members(var, deref=1)) {
      symbol_set, parts(1), h_new();
      var = symbol_def(parts(1));
    }

    // processed contains the string corresponding to var's current value
    processed = parts(1);

    // Deference until we have no more subkeys to process
    while(parts(2)) {
      parts = strtok(parts(2), ".");
      if(parts(2)) {
        // If it doesn't have the key specified, we must create it
        if(!has_member(var, parts(1))) {
          // If the variable isn't a hash, then clobber + force it to be
          if(!is_hash(var)) {
            var_expr_set, processed, h_new();
            var = var_expr_get(processed);
          }
          h_set, var, parts(1), h_new();
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
    // Non-hashes can't have new keys added, so either replace key or clobber
    } else {
      // Hash key -- update
      if(has_member(*var, parts(1))) {
        get_member(*var, parts(1)) = val;
      // No key -- clobber + add
      } else {
        var_expr_set, processed, h_new();
        var = var_expr_get(processed);
        h_set, var, parts(1), val;
      }
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

func has_member(val, member, deref=) {
/* DOCUMENT has_member(val, member, deref=)
  Tests to see if the given value contains a member with the given name.
  Returns 1 if it does, 0 if it does not.

  If deref=1, then pointers will be derefenced as necessary.
*/
// Original David Nagle 2009-08-14
  if(deref && is_pointer(val)) val = *val;
  if(is_hash(val)) return h_has(val, member);
  if(is_stream(val)) return anyof(*(get_vars(val)(1)) == member);
  if(is_obj(val)) return val(*,member) > 0;
  if(catch(0x08)) {
    return 0;
  }
  get_member, val, member;
  return 1;
}

func has_members(val, deref=) {
/* DOCUMENT has_members(val, deref=)
  Checks to see if val is something that has members that can be accessed via
  get_member. Returns 1 if so, 0 if not.

  If deref=1, then pointers will be dereferenced as necessary.
*/
// Original David Nagle 2009-08-14
  if(deref && is_pointer(val)) val = *val;
  return is_stream(val) || is_hash(val) || is_obj(val) ||
    (typeof(val) == "struct_instance");
}

func get_members(val) {
/* DOCUMENT members = get_members(val);
  Returns an array of strings, corresponding to the members in val (which can
  be a Yeti hash, a stream, or a struct instance).
*/
  if(is_hash(val)) return h_keys(val);
  if(is_stream(val)) return *(get_vars(val)(1));
  if(typeof(val) == "struct_instance") {
    fields = print(structof(val))(2:-1);
    fields = regsub("^ +", fields);
    fields = regsub("(\\(.+\\))?;$", fields);
    fields = strsplit(fields, " ")(,2);
    return fields;
  }
  if(is_obj(val)) {
    fields = val(*,);
    w = where(fields);
    if(!numberof(w))
      return [];
    return fields(w);
  }
  return [];
}

func get_dir(void, initialdir=, title=, mustexist=) {
/* DOCUMENT get_dir(void, initialdir=, title=, mustexist=)
  If _ytk is enabled, will use tk_chooseDirectory to prompt for a directory to
  select. Otherwise, prompts via the console. Returns directory name.
*/
  extern _ytk;
  if(!_ytk) {
    if(is_void(initialdir)) initialdir = ".";
    if(is_void(title)) title="Directory list of: " + initialdir;
    flist = lsdir(initialdir, dirs);
    if(numberof(dirs) == 0) return "";
    write, format="\n\n%s\n\n", title;

    rs = select_item_in_string_list(dirs, bol=" ", numfmt="= ",
      prompt="Enter your selection number:");
    rs = rs ? initialdir + "/" + rs : "";
    return rs;
  }
  cmdargs = "";
  if(!is_void(initialdir))
    cmdargs += swrite(format=" -initialdir {%s}", initialdir);
  if(!is_void(title))
    cmdargs += swrite(format=" -title {%s}", title);
  if(!is_void(mustexist))
    cmdargs += swrite(format=" -mustexist %s", mustexist);
  tkcmd, swrite(format="exp_send [tk_chooseDirectory %s]\\r", cmdargs);

  return rdline(prompt="") + "/";
}

func get_openfn(void, initialdir=, defaultextension=, title=, filetypes=,
filetype=, initialfile=) {
/* DOCUMENT get_openfn(initialdir=, defaultextension=, title=, filetypes=,
  filetype=, initialfile=)

  If _ytk is enabled, will use tk_getOpenFile to prompt for a file to select.
  Otherwise, uses Yeti's select_file. Returns the selected file.
*/
  extern _ytk;
  if(!_ytk) {
    return select_file(initialdir);
  }

  cmdargs = __get_opensavefn_args(initialdir, initialfile, defaultextension,
    title, filetype, filetypes);
  tkcmd, swrite(format="exp_send [tk_getOpenFile %s]\\r", cmdargs);

  return rdline(prompt="");
}

func get_savefn(void, initialdir=, defaultextension=, title=, filetypes=,
filetype=, initialfile=) {
/* DOCUMENT get_savefn(initialdir=, defaultextension=, title=, filetypes=,
  filetype=, initialfile=)

  If _ytk is enabled, prompts for a file using tk_getSaveFile. Otherwise,
  provides a prompt that requires the user to type their path in manually.
*/
  extern _ytk;
  if(!_ytk) {
    if(is_void(initialdir)) initialdir = "";
    if(is_void(title)) title="Enter file name:";
    rv = "";
    read, prompt=title, format="%s", rv;
    return initialdir + rv;
  }

  cmdargs = __get_opensavefn_args(initialdir, initialfile, defaultextension,
    title, filetype, filetypes);
  tkcmd, swrite(format="exp_send [tk_getSaveFile %s]\\r", cmdargs);

  return rdline(prompt="");
}

func __get_opensavefn_args(initialdir, initialfile, defaultextension, title,
filetype, filetypes) {
/* DOCUMENT __get_opensavefn_args
  Private helper function to get_openfn and get_savefn.
*/
  cmdargs = "";
  if (!is_void(initialdir))
    cmdargs += swrite(format=" -initialdir {%s}", initialdir);
  if (!is_void(defaultextension))
    cmdargs += swrite(format=" -defaultextension {%s}", defaultextension);
  if (!is_void(initialfile))
    cmdargs += swrite(format=" -initialfile {%s}", initialfile);
  if (!is_void(title))
    cmdargs += swrite(format=" -title {%s}", title);
  if (!is_void(filetype))
    cmdargs += swrite(format=" -filetypes { {{%s} {%s}} } ", filetype, filetype);
  else if (!is_void(filetypes))
    cmdargs += swrite(format=" -filetypes %s", filetypes);
  return cmdargs;
}

func tk_messageBox(message, type, title=) {
/* DOCUMENT tk_messageBox(message, type, title=)
  tk_messageBox pops up a message box. The Tcl/Tk side is implemented in
  y_messageBox. Returns the value of tk_messageBox.
*/
  extern _ytk;
  if(is_void(_ytk)) {
    ytk_not_present;
    return;
  }
  if(is_void(title)) title = "";
  tkcmd, swrite(format="y_messageBox {%s} {%s} {%s}", message, type, title);
  return rdline(prompt="");
}

func source(fn) {
/* DOCUMENT source, fn;
  Tells Tcl to source the given file.
*/
  extern _ytk;
  if(is_void(_ytk)) {
    ytk_not_present;
    return;
  }
  tkcmd, swrite(format="source {%s}", fn);
}

func ytk_startup(void) {
/* DOCUMENT ytk_startup;
  When ytk.i is sourced, this function is called. It checks argv to see if it
  looks like this was started from ytk with fifo arguments and, if so,
  attempts to initialize the fifos.
*/
// Original David Nagle 2009-08-20
  args = get_argv();
  if(numberof(args) > 3 && args(-2) == "ytk.i") {
    initialize_ytk, args(-1), args(0);
  }

  if(!is_func(is_obj))
    tkcmd, "ytk_alps_update_required";
}

func ytkquit {
/* DOCUMENT ytkquit
  Exit YTK. This tells TCL to exit, which in turn automatically shuts down
  Yorick. (This is safer than exiting Yorick directly and hoping that Tcl
  takes the hint.)

  The Yorick built-in command quit was renamed to __quit if you need it.
*/
  tkcmd, "ytk_exit 0";
  __quit;
}
__quit = quit;
// Disabled for now. This was preventing command history from saving.
//quit = ytkquit;

ytk_startup;
