func histogram1 (list,binsize=, plot=, width=, color=, type=, win=, dofma=) {
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
    plg, h, e/100., color=color, width=width, type=type;
  }
  hst = [e/100.,h];
  window, win; limits,,,,hst(max,2)*1.5
  //window, cur_win;
  return hst;
}


func plot_histogram (hst, win=, dots=, titlexy=, titlepl=, mean=, cl=, diff1=) {
 /* DOCUMENT plot_histogram (hst, win=, dots=, titlexy=, titlepl=, mean=, cl=)
    amar nayegandhi 06/06/05
 */

 window, win;
 fma;
 plg, hst(,2), hst(,1), color=color, width=width, type=type;
 plmk, hst(,2), hst(,1), msize=0.2, marker=4, color="red", width=10
 
 // find mean and plot
 maxn = max(hst(,2));
 maxe = (hst(,2))(mxx);
 plg, [maxn,0], [hst(maxe,1), hst(maxe,1)], type=5, color="blue", width=3.0;
 if (titlexy) 
    xytitles, "Quantized Height Difference (m)", "Number of points per bin";

 if (cl < 1) {
  noc = cl*numberof(diff1);
  clmx = max(abs(diff1));
    for (cli=clmx;cli>0;) {
      iindx = where(abs(diff1) < cli);
      if (numberof(iindx) <= noc) break;
      cli -= 0.01;
    }
  plg, [maxn,0], [max(diff1(iindx)), max(diff1(iindx))], type=3, color="red", width=3.5;
  plg, [maxn,0], [min(diff1(iindx)), min(diff1(iindx))], type=3, color="red", width=3.5;
 }
 
 
}

 
