write, "$Id$";
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

	extern _ytk_window_size

	if (is_void(dofma)) dofma=0;

	if (is_void(_ytk_window_size)) {
		_ytk_window_size = array(int, 64);
	}

	if (_ytk_window_size(win) != winsize) {
		if (!dofma) {
			msg = "Cannot change window size without performing fma. Please check the fma button and try again"
			cmd = "tk_messageBox -icon warning -message {" + msg + "}\n"
			tkcmd, cmd;
			return 0;
		} else {
			winkill, win;
			_ytk_window_size(win) = winsize;
			if (_ytk_window_size(win) == 1) {
				window, win, dpi=75;
			}
			if (_ytk_window_size(win) == 2) {
				window, win, dpi=100;
			}
			if (_ytk_window_size(win) == 3) {
				window, win, dpi=75, style="landscape11x85.gs", width=825, height=638;
			}
			if (_ytk_window_size(win) == 4) {
				window, win, dpi=100, style="landscape11x85.gs", width=1100, height=850;
			}
			limits, square=1;
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
