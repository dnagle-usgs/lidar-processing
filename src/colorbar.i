/*
   $Id$
*/
write, "$Id$" 
func colorbar(cmin, cmax, drag=, delta=)
/* DOCUMENT colorbar
            colorbar, cmin, cmax, drag=
     draw a color bar to the right of the plot.  If CMIN and CMAX
     are specified, label the top and bottom of the bar with those
     numbers.  If drag=1 then the user will be prompted to drag
     out a rectangle for the colorbar;
 */
{
xoff = 0.0;
yoff = 0.0;
  x = [.67,.67,.625,.625]  + xoff
  y = [.46,.84,.84,.46] + yoff
  if ( !is_void( drag ) ) {
    if ( _ytk ) 
////        tkcmd, " center_win  [ toplevel .temp ]\r"
///	tkcmd, "tk_messageBox -message {Drag out a rectangle for the color bar}\r";
///        tkcmd, "destroy .temp\r";
    mm = mouse(0, 1, "Drag out a rectangle for the color bar:");
    if ( mm(2) > mm(4) ) {
      tmp = mm(2); 
      mm(2) = mm(4);
      mm(4) = tmp;
    }
    if ( mm(1) > mm(3) ) {
      tmp = mm(1);
      mm(1) = mm(3);
      mm(3) = tmp;
    }
    x(1) = x(2) = mm(1);
    x(3) = x(4) = mm(3);
    y(1) = y(4) = mm(2);
    y(2) = y(3) = mm(4);
  }
  dpx = abs(x(3) - x(1));
  dpy = abs(y(4) - y(2));
 if ( dpx < dpy ) {
   vert = 1;
 }
  yy = [ y(2), y(2) ] 
  xx = [ x(3), (x(1)-x(3))/4 + x(3) ]
  sys = plsys( 0);
  dy = yy - y(1)
  if ( vert ) {
    pli, span(0,1,200)(-,), x(1)+xoff,y(4)+yoff,x(4)+xoff,y(2)+yoff, legend="";
    plg, y,x, closed=1, marks=0,color="fg",width=1,type=1,legend="";
    plg, dy/2+y(1), xx, color="fg", width=3, type = 1, legend="";
    plt, pr1(cmin), x(1)+xoff,y(1)+yoff, justify="CT";
    plt, pr1(cmax), x(1)+xoff,y(2)+yoff, justify="CB";
    plt, pr1(cmax-cmin), x(3)+0.002,y(3)-dpy/2, justify="CA", orient=3;
  } else {
    pli, span(0,1,200)(,-), x(1),y(4),x(4),y(2), legend="";
    plg, y,x, closed=1, marks=0,color="fg",width=1,type=1,legend="";
    plt, pr1(cmin), x(1),y(1), justify="CT";
    plt, pr1(cmax), x(3),y(1), justify="CT";
    plt, pr1(cmax-cmin), xx(1)-dpx/2,y(3), justify="CB";
  }
  plsys(sys);  
}


