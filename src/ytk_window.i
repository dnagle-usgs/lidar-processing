// vim: set ts=2 sts=2 sw=2 ai sr et:

local _ytk_window_parents;
if(is_void(_ytk_window_parents))
  _ytk_window_parents = array(0, 64);
/* DOCUMENT _ytk_window_parents
  Used internally by ytk_window. Stores the parent IDs for the frames that
  Yorick should embed its windows into (using parent=).

  SEE ALSO: ytk_window
*/

func ytk_window(win, display=, dpi=, wait=, private=, hcp=, dump=, legends=,
style=, width=, height=, rgb=, parent=, xpos=, ypos=, keeptk=) {
/* DOCUMENT ytk_window, win, display=, dpi=, wait=, private=, hcp=, dump=,
   legends=, style=, width=, height=, rgb=, parent=, xpos=, ypos=,
   keeptk=

  Please use "help, yor_window" for details on how to use the window command.

  Function "ytk_window" is a wrapper around Yorick's built-in "window"
  function. If you are encountering this help using "help, window", then that
  means the built-in Yorick "window" command has been replaced by ytk_window.
  You can access the original window command at "yor_window". HOWEVER: For most
  purposes, you can use ytk_window (or window, if it's replacing it) exactly as
  you would yor_window.

  The purpose of ytk_window is to automatically embed windows into Tcl/Tk
  windows. This allows windows to be consistently handled and it makes it
  easier to add GUI controls to windows in Tcl. It also avoids various
  difficulties that arise when trying to put windows into Tcl frames on-the-fly
  only part of the time. This function will tell Tcl to hide or display its
  window, as appropriate.

  SEE ALSO: ytk_window yor_window window
*/
  extern _ytk_window_parents;

  if(is_void(win)) win = current_window();
  if(win < 0) win = 0;

  if(is_void(dpi) && !window_exists(win)) dpi = 75;
  
  parent = _ytk_window_parents(win+1);
  xpos = ypos = (parent > 0) ? -2 : 0;

  width = height = [];
  if(style == "landscape11x85.gs") {
    width = (dpi == 100) ? 1100 : 825;
    height = (dpi == 100) ? 850 : 638;
  }

  if(display == "") {
    if(!keeptk) {
      tkcmd, swrite(format=".yorwin%d withdraw", win);
    }
    // When a window is killed, it reverts to the default style and DPI
    tkcmd, swrite(format=".yorwin%d configure -style {%s} -dpi %d",
      win, "work.gs", 75);
  } else {
    tkcmd, swrite(format=".yorwin%d show", win);
  }
  if(!window_exists(win)) {
    if(!is_void(style)) {
      tkcmd, swrite(format=".yorwin%d configure -style {%s}", win, style);
    }
    if(!is_void(dpi)) {
      tkcmd, swrite(format=".yorwin%d configure -dpi %d", win, dpi);
    }
  }

  cmd = "result = yor_window(win";
  if(!is_void(display))
    cmd += ", display=display";
  if(!is_void(dpi))
    cmd += ", dpi=dpi";
  if(!is_void(wait))
    cmd += ", wait=wait";
  if(!is_void(private))
    cmd += ", private=private";
  if(!is_void(hcp))
    cmd += ", hcp=hcp";
  if(!is_void(dump))
    cmd += ", dump=dump";
  if(!is_void(legends))
    cmd += ", legends=legends";
  if(!is_void(style))
    cmd += ", style=style";
  if(!is_void(width))
    cmd += ", width=width";
  if(!is_void(height))
    cmd += ", height=height";
  if(!is_void(rgb))
    cmd += ", rgb=rgb";
  if(!is_void(parent))
    cmd += ", parent=parent";
  if(!is_void(xpos))
    cmd += ", xpos=xpos";
  if(!is_void(ypos))
    cmd += ", ypos=ypos";
  cmd += ")\n";
  result = [];
  include, [cmd], 1;

  if(width || height)
    yor_window, win, width=0, height=0;

  return result;
}

func ytk_winkill(win, keeptk=) {
/* DOCUMENT ytk_winkill, win, keeptk=
  Deletes the current graphics window, or window WIN.

  If you intend to immediately re-open the window and do not want it to change
  position or stacking order, set keeptk=1.
*/
  window, win, display="", hcp="", keeptk=keeptk;
}

// Yorick's window is built-in, ours is interpreted. If the current "window" is
// built-in, back it up and initializing YTK windowing.
if(is_func(window) == 2) {
  yor_window = window;
  yor_winkill = winkill;

  tkcmd, "package require yorick::window";
  tkcmd, "::yorick::window::initialize";
}

window = ytk_window;
winkill = ytk_winkill;
