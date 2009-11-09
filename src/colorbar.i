// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

require, "eaarl.i";

/* DOCUMENT CBAR
   Struct for colorbar values.
   The values from l1pro.ytk can be sent to the cbar variable by executing
   tkcmd, ycbar from within a yorick program.
*/
struct CBAR {
   float cmax;
   float cmin;
   float cdelta;
}

if(is_void(cbar)) cbar = CBAR();

func set_cbar(bar,w=, opt=) {
/* DOCUMENT set_cbar(bar, w=)
   Lets the user interactively set the colorbar using a histogram.
*/
   default, w, 7;
   window, w;
   if(bar == "cmax") {
      write, format="Select a point to use as cmax from window %d\n", w;
      m = mouse();
      tkcmd, swrite(format="set plot_settings(cmax) %.2f", m(1));
   } else if ( bar == "cmin" ) {
      write, format="Select a point to use as cmin from window %d\n", w;
      m = mouse();
      tkcmd, swrite(format="set plot_settings(cmin) %.2f", m(1));
   } else if ( bar == "both" ) {
      write, format="Select points to use as cmin and cmax from window %d\n", w;
      m = mouse()(1);
      n = mouse()(1);
      tkcmd, swrite(format="set plot_settings(cmin) %.2f", min(m,n));
      tkcmd, swrite(format="set plot_settings(cmax) %.2f", max(m,n));
   } else {
      write, "set_cbar was called with an unknown option: " + bar;
   }
   if ( opt == "dismiss" ) {
    tkcmd, swrite(format="destroy %s", ".cbartool");
    winkill, w;
   }
}

func colorbar(cmin, cmax, drag=, landscape=, units=, datum=) {
/* DOCUMENT colorbar
            colorbar, cmin, cmax, drag=, landscape=, units=, datum=

   Draws a color bar on the plot.

   If cmin and cmax are specified, the colorbar will be labeled with those
   values.

   If drag=1 is specified, then the user is prompted to draw a bounding box for
   where the colorbar will be plotted.

   If drag=0 (default), the colorbar will be automatically placed to the right
   of the plot for portrait windows or above for landscape windows.

   If units= is provided, it must be a string and will be used to label the
   cmax/cmin values.

   If datum= is provided, it must be a string and will be plotted to illustrate
   the current datum.

   The landscape= option is ignored and exists for historical reasons.
*/
   xoff = 0.0;
   yoff = 0.0;
   if (drag) {
      mm = mouse(0, 1, "Drag out a rectangle for the color bar:");
      x(1) = x(2) = mm([1,3])(min);
      x(3) = x(4) = mm([1,3])(max);
      y(1) = y(4) = mm([2,4])(min);
      y(2) = y(3) = mm([2,4])(max);
   } else {
      vp = viewport();
      if(vp(1) < 0.1) {
         if(is_void(cmin)) {
            x = [.62,.62,1., 1.];
            y = [.75,.79,.79,.75];
         } else {
            x = [.62,.62,1., 1.];
            y = [.76,.78,.78,.76];
         }
      } else {
         x = [.67,.67,.64,.64];
         y = [.46,.84,.84,.46];
      }
   }
   dpx = abs(x(3) - x(1));
   dpy = abs(y(4) - y(2));
   vert = dpx < dpy;
   yy = [y(2), y(2)];
   xx = [x(3), (x(1)-x(3))/4 + x(3)];
   sys = plsys(0);
   dy = yy - y(1);
   if (vert) {
      pli, span(0,1,200)(-,), x(1)+xoff, y(4)+yoff, x(4)+xoff, y(2)+yoff,
         legend="";
      plg, y, x, closed=1, marks=0, color="fg", width=1, type=1, legend="";
      plg, dy/2+y(1), xx, color="fg", width=3, type = 1, legend="";
      if(!is_void(cmin)) {
         plt, swrite(format="%5.2f", cmax-cmin), x(3)+0.002, y(3)-dpy/2,
            justify="CA", orient=3;
         if(is_void(units)) units = "";
         plt, swrite(format=" %.2f %s", cmin, units), x(1)+xoff-0.03,
            y(1)+yoff, justify="CT";
         plt, swrite(format=" %.2f %s", cmax, units), x(1)+xoff-0.03,
            y(2)+yoff, justify="CB";
      }
      if (datum) {
         plt, datum, x(1)+xoff-0.03, y(1)+yoff-0.03, justify="CT";
         plt, "elevations", x(1)+xoff-0.03, y(1)+yoff-0.05, justify="CT";	
      }
   } else {
      pli, span(0,1,200)(,-), x(1), y(4), x(4), y(2), legend="";
      plg, y, x, closed=1, marks=0, color="fg", width=1, type=1, legend="";
      if (!is_void(cmin)) {
         plt, swrite(format="%5.2f", cmin), x(1),y(1), justify="CT";
         plt, swrite(format="%5.2f", cmax), x(3),y(1), justify="CT";
         plt, swrite(format="%5.2f", cmax-cmin), xx(1)-dpx/2, y(3),
            justify="CB";
      }
   }
   plsys, sys;
}

func stdev_min_max(x, N_factor=) {
/* DOCUMENT stdev_min_max(x, N_factor=)

   For a given array of data, this will return an array [min, max] that
   provides a bounding range for values within N_factor standard deviations of
   the data's mean.

   This is useful for automatically determining a reasonable colorbar for data.

   N_factor defaults to 2.
*/
   default, N_factor, 2;
   x = unref(x)(*);
   return x(avg) + N_factor * x(rms) * [-1, 1];
}
