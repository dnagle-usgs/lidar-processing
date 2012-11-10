// vim: set ts=2 sts=2 sw=2 ai sr et:

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

