/*
   $Id$
*/
write, "$Id$" 
func colorbar(cmin, cmax)
/* DOCUMENT colorbar
            colorbar, cmin, cmax
     draw a color bar to the right of the plot.  If CMIN and CMAX
     are specified, label the top and bottom of the bar with those
     numbers.
 */
{
  plsys, 0;
  pli, span(0,1,200)(-,), .625,.46,.67,.84, legend="";
  plg, [.46,.84,.84,.46],[.67,.67,.625,.625], closed=1,
    marks=0,color="fg",width=1,type=1,legend="";
  plsys, 1;  /* assumes there is only one coordinate system */
  if (!is_void(cmin)) {
    plt, pr1(cmin), .6475,.46, justify="CT";
    plt, pr1(cmax), .6475,.84, justify="CB";
  }
}


