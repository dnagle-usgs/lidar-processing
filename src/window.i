// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func window_embed_tk(win, parent, dofma, style, dpi, sys0) {
/* DOCUMENT window_embed_tk, win, parent
  -or-  window_embed_tk, win, parent, dofma
  -or-  window_embed_tk, win, parent, dofma, style
  -or-  window_embed_tk, win, parent, dofma, style, dpi
  -or-  window_embed_tk, win, parent, dofma, style, dpi, sys0

  Wrapper around change_window_style. If omitted, the last three parameters
  have these defaults:
    dofma=0
    style="work"
    dpi=75
    sys0=1
  This then calls change_window_style as follows:
    change_window_style, style, dpi=dpi, dofma=dofma, win=win, parent=parent,
      xpos=0, ypos=0, sys0=sys0

  This is primarily intended to be used in Tcl/Tk using the ybkg command, since
  it does not support passing keywords.

  Note: When using ybkg to call this, make sure the ID is passed as a decimal
  integer. By default, [winfo id $win] returns a number in hexadecimal form,
  which doesn't work for some reason. So use [expr {[winfo id $win]}] to cast
  to a decimal form.
*/
  default, style, "work";
  default, dpi, 75;
  default, dofma, 0;
  default, sys0, 1;
  change_window_style, style, dpi=dpi, dofma=dofma, win=win, parent=parent,
    xpos=0, ypos=0, sys0=sys0, wait=0;
}

func change_window_style(style, win=, dofma=, dpi=, sys0=, parent=, xpos=,
ypos=, wait=) {
/* DOCUMENT change_window_style, style, win=, dofma=, dpi=, sys0=, parent=,
   xpos=, ypos=, wait=

  Changes the style of a Yorick window.
  Parameter:
    style: Name of style sheet to use, such as "work" or "nobox"
  Options:
    win= Window number to change. If not provided, uses current window. If
      there is no current window, then uses window 0.
    dofma= Set to 1 to issue an FMA prior to changing. This avoids the need
      to re-plot the window's contents.
    dpi= The DPI setting to use. Normally either dpi=75 or dpi=100.
    sys0= Set to 1 to include system 0 (which includes plot and axis titles).

  These options are passed to window without modification:
    parent=
    xpos=
    ypos=
    wait=
*/
  local wdata;
  default, win, current_window();
  default, dofma, 0;
  default, dpi, 75;
  default, sys0, 0;

  if(win < 0)
    win = window();

  width = height = [];
  if(style == "landscape11x85") {
    if(dpi == 75) {
      width = 825;
      height = 638;
    } else if(dpi == 100) {
      width = 1100;
      height = 850;
    }
  } else {
    if(dpi == 75) {
      width = height = 450;
    } else if(dpi == 100) {
      width = height = 600;
    }
  }

  wdata = [];
  if(!dofma && window_exists(win))
    wdata = save_plot(win);

  winkill, win;
  window, win, dpi=dpi, style=style+".gs", width=width, height=height,
    parent=parent, xpos=xpos, ypos=ypos, wait=wait;
  window, win, width=0, height=0;

  // Avoid copying system 0. It contains axis and plot labels, which will
  // render in the wrong spot when changing to/from landscape.
  systems = (sys0 ? [0,1] : [1]);
  if(!is_void(wdata))
    load_plot, wdata, win, style=0, systems=systems;
}

func change_window_size(win, winsize, dofma) {
/* DOCUMENT change_window_size(win, winsize, dofma)
  This function is used to change the size of the yorick window.
  INPUT:
    win: window number
    winsize: window size (1=small, 2=medium, 3=large, 4=huge)
    dofma: clear plot (fma).  must be set to 1 to change window size.
  OUTPUT:
    wset: 1 if window size has been changed, 0 otherwise.

    Original: Amar Nayegandhi 12/12/2005.
*/
  if(winsize == 1)
    change_window_style, "work", win=win, dpi=75, dofma=dofma;
  else if(winsize == 2)
    change_window_style, "work", win=win, dpi=100, dofma=dofma;
  else if(winsize == 3)
    change_window_style, "landscape11x85", win=win, dpi=75, dofma=dofma;
  else if(winsize == 4)
    change_window_style, "landscape11x85", win=win, dpi=100, dofma=dofma;
  return 1;
}

func copy_limits(src, dst) {
/* DOCUMENT copy_limits, src, dst
  -or- copy_limits, src
  Copies the limits from window SRC to window DST. DST may be an array to
  apply to multiple windows. If DST is omitted, then the limits from SRC are
  applied to all open windows.
*/
  wbkp = current_window();
  window, src;
  lims = limits();
  default, dst, window_list();
  for(i = 1; i <= numberof(dst); i++) {
    window, dst(i);
    limits, lims(1), lims(2), lims(3), lims(4);
  }
  window_select, wbkp;
}

func window2image(file, win=) {
/* window2image, filename, win=
  Creates an image from the specified window.

  file: The destination filename, such as /path/to/file.png
  win= The window to dump (if not provided will use current window)

  Caveats:
    * This will only work if xwd is on your path.
    * This will only work if convert is on your path.
    * This will only work if the Yorick window is named "Yorick 0" or
      similar. If you have multiple Yoricks running and this one's windows
      are named "Yorick 0 <2>" or similar, this will grab the wrong window.
*/
  // Original David Nagle 2009-01-28
  default, win, max(current_window(), 0);
  dir = mktempdir();
  xwdfile = file_join(dir, "temp.xwd");
  system, swrite(format="xwd -out %s -name 'Yorick %d'", xwdfile, win);
  system, swrite(format="convert %s %s", xwdfile, file);
  remove, xwdfile;
  rmdir, dir;
}
