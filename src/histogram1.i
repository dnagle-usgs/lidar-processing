func histogram1 (list,binsize=, plot=, width=, color=, type=, win=) {
/* DOCUMENT histogram1 (list,binsize=, plot=, width=, color=, type=)
  This function computes the histogram by counting the number of 
  occurences of each element of the input index LIST.  The element can
  be defined by the optional keyword binsize.  The list can be a positve
  or negative integer (unlike the default histogram function).
  INPUT KEYWORDS:
  list : input array
  binsize = set to the length of each element.  All occurences within binsize
  	    will be calculated as 1 element.
  plot = DEFAULTS TO 1.  Set to 0 if you do not want the histogram to plot in
	 window.
  width=, color=, type=: all used in plg command.
  win= window number to plot. Defaults to 0.

  OUTPUT:
  hst : 2-D array containing the elements and the number of occurences for each
   	element.

  Amar Nayegandhi June 4, 2005
*/

  if (is_void(binsize)) binsize = 1;
  if (is_void(win)) win = 0;
  if (is_void(plot)) plot = 1; // plot by default
  
  minn = min(list);
  maxx = max(list);
  list1 = list - min(list);
  h = histogram( (list1/int(binsize)) + 1);
  zero_list = where( h == 0 );
  if (numberof(h) < 2) {
    h = [1,h(1),1];
  }
  if (numberof(zero_list)) 
    h(zero_list) = 1;
  e = span(minn,maxx,numberof(h));
  //cur_win = window();
  window, win;
  if (dofma) fma;
  if (normalize) {
     h = float(h);
     h = h/(h(max));
  }
  if (plot) {
    plg, h, e, color=color, width=width, type=type;
  }
  hst = [e,h];
  window, win; limits,,,,hst(max,2)*1.5
  //window, cur_win;
  return hst;
}
