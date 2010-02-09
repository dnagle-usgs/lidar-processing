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

func hex_to_string(input) {
/* DOCUMENT s = hex_to_string(input)
   Given an input string in hexadecimal, this converts it to the data it
   represents and returns it as a string.

   Example:

      > foo = "Hello, world!"
      > bar = swrite(format="%02x", strchar(foo))(sum)
      > bar
      "48656c6c6f2c20776f726c642100"
      > hex_to_string(bar)
      "Hello, world!"
      > hex_to_string(bar) == foo
      1
*/
// This is needed for ASCII-armoring commands sent from Tcl to Yorick.
   output = array(char, strlen(input)/2);
   sread, input, format="%2x", output;
   return strchar(output);
}

func tky_stdout(msg) {
/* DOCUMENT tky_stdout, msg;
   DO NOT CALL THIS DIRECTLY!

   This is used internally by Ytk to handle messages sent to it via the tky
   pipe.
*/
   extern __tky_fragment, __ybkg_list;
   lines = spawn_callback(__tky_fragment, msg);
   for(i = 1; i <= numberof(lines); i++) {
      line = lines(i);
      if(!line) {
         // process has died! should probably handle this better...
      } else {
         cmd = strpart(line, 1:3);
         data = strpart(line, 5:);
         if(cmd == "bkg") {
            data = hex_to_string(data);
            logger, "debug", "Queueing background command: " + data;
            __ybkg_list = _cat(__ybkg_list, data);
            tkcmd, "set ::__ybkg__wait 0"
         } else {
            logger, "error", "Unknown command received by tky: " + line;
         }
      }
   }
   after, 0, tky_ybkg_handler;
}

func tky_ybkg_handler {
   extern __ybkg_list;

   if(_len(__ybkg_list)) {
      // Using && to try to enforce atomic operation
      temp = (f = _car(__ybkg_list, 1)) && (__ybkg_list = _cdr(__ybkg_list, 1));
      logger, "debug", "Evaluating background command: " + f;
      safe_run_funcdef, funcdef(f);

      after, 0, tky_ybkg_handler;
   }
}

func safe_run_funcdef(f) {
   if(catch(-1)) {
      return;
   }
   f;
   return;
}

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

func var_expr_tkupdate(expr, tkval) {
/* DOCUMENT var_expr_tkupdate, expr, tkval
   Given a variable expression (expr), this will update it to a new value as
   specified by tkval. However, it tries to maintain type. So if expr is a
   string, it stays a string; if expr is a double, tkval is cast to a double;
   etc. Tkval is expected to be provided as a string.
*/
// Original David Nagle 2009-08-14
   val = var_expr_get(expr);
   if(numberof(where(typeof(val) == ["long","int","short","double","float"]))) {
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
   return is_stream(val) | is_hash(val) | (typeof(val) == "struct_instance");
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

func logger(level, message) {
/* DOCUMENT logger, level, message
   Sends a message to the logger.

   level: Must be a string, one of: emergency, alert, critical, error, warning,
      notice, info, debug.

   message: Any text string to be displayed in the logger.

   This is basically a wrapper around ytk's ylogger command.
*/
// Original David Nagle 2009-05-19
   parts = [string(0), message];
   do {
      parts = strtok(parts(2), "\n");
      tkcmd, swrite(format="ylogger {%s} {%s}", level, parts(1));
   } while(parts(2));
}

_ytk_logger_id = -1;
func logger_id(void) {
/* DOCUMENT logger_id()
   Returns a unique identifier that can be used within logging output to
   identify, for example, which function you're in. Always returns an odd
   number in parentheses as a string.

   For example, in a function named "foo", you might do this:

   log_id = logger_id();
   logger, "debug", log_id + " Entering foo()";
   ...
   logger, "debug", log_id + swrite(format=" i = %d", i);
   ...
   logger, "debug", log_id + " Leaving foo";

   This lets you keep track of which function call is generating which output,
   which is useful when you have debug output mixed together from a function
   that calls a function that calls a function...
*/
// Original David Nagle 2009-05-20
   extern _ytk_logger_id;
   id = _ytk_logger_id += 2;
   return swrite(format="(%d)", id);
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
}

ytk_startup;
