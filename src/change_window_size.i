write, "$Id$";
require, "copy_plot.i";

local alps_windows;
/* DOCUMENT alps_windows

   This documents what windows are used for throughout ALPS.

   window, 0
      - Used to display a pixel waveform (drast.i, raspulsearch.i)

   window, 1
      - Used for the raster (drast.i)

   window, 2
      - Used for the georectified raster (drast.i)

   window, 3
      - Default window for transects (transect.i)

   window, 4
      - ? raspulsearch.i

   window, 5
      - Default window for plotting processed data in l1pro.ytk

   window, 6
      - Default window for plotting flightlines (pnav) in plot.tcl, etc.
*/

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
	extern _ytk_window_size;

   default, dofma, 0;
   default, _ytk_window_size, array(int, 64);

   if(_ytk_window_size(win) != winsize) {
      if(!dofma) {
         // find unused window
         bkpwin = 63;
         while(bkpwin >= 0 && window_exists(bkpwin)) bkpwin -= 1;
         if(bkpwin >= 0) {
            replot_all, win, bkpwin;
         } else {
            bkpwin = [];
         }
      }

      winkill, win;
      _ytk_window_size(win) = winsize;
      if (_ytk_window_size(win) == 1) {
         window, win, dpi=75, style="work.gs", width=450, height=450;
      }
      if (_ytk_window_size(win) == 2) {
         window, win, dpi=100, style="work.gs", width=600, height=600;
      }
      if (_ytk_window_size(win) == 3) {
         window, win, dpi=75, style="landscape11x85.gs", width=825, height=638;
      }
      if (_ytk_window_size(win) == 4) {
         window, win, dpi=100, style="landscape11x85.gs", width=1100, height=850;
      }
      limits, square=1;

      if(!is_void(bkpwin)) {
         replot_all, bkpwin, win;
         winkill, bkpwin;
      }
	} else {
		if (dofma) {
			window, win; fma; limits, square=1;
		} else {
			window, win;
		}
	}
	return 1;
}

func winlimits( win1, win2 ) {
/* DOCUMENT set_winlimits( window1, window2 )
    Convenient shortcut function to set the window limits in window2
    equal to the limits in window1. i.e. make window2 look like window1.
*/
  window, win1;
  lm=limits();
  window, win2;
  limits,lm(1),lm(2),lm(3),lm(4);
  window, win1;
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
