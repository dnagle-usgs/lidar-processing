func large_window(win) {
/* DOCUMENT large_window(win)
   This function plots the large window.
   amar nayegandhi 07/13/04
*/
 
 if (is_void(win)) win=0;
 winkill, win;
 window, win, dpi=100, style="landscape11x85.gs",height=850,width=1100;
}
