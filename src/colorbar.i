// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

require, "eaarl.i";

func set_cbar(bar,w=) {
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
      tkcmd, swrite(format="set cdelta %.2f", abs(m-n));
   } else {
      write, "set_cbar was called with an unknown option: " + bar;
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
   // Coercing type to avoid type mismatch in swrites later in function.
   cmin = is_void(cmin) ? [] : double(cmin);
   cmax = is_void(cmax) ? [] : double(cmax);
   xoff = 0.0;
   yoff = 0.0;
   if (drag) {
      mm = mouse(0, 1, "Drag out a rectangle for the color bar:");
      x = y = array(double, 4);
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

func auto_cbar(data, method, mode=, factor=) {
/* DOCUMENT auto_cbar, data, method, mode=, factor=
   Automatically sets the colorbar for data using the given method.

   Alternatively, if called as a function, will return [cmin, cmax] instead of
   automatically setting colorbar.

   Parameters:
      data: An array of data suitable for passing to data2xyz.
      method: The method to use for determining the colorbar. Valid values:
            method="stdev"       Use standard deviations about the mean
            method="percentage"  Use central percentage of data
            method="rcf"         Use random consensus filter
            method="all"         Set cmin/cmax to include all data

   Options:
      mode= A mode suitable for data2xyz.
      factor= A numeric value whose purpose depends on method.
         When method="stdev", factor is the number of standard deviations about
         the mean to use.
            factor=2    two standard deviations about mean (default)
            factor=1    one standard deviation about mean
         When method="percentage", factor is the percentage of points that
         should be between cmin and cmax. An equal number of points are
         excluded at that upper and lower bounds to result in this percentage.
            factor=0.99    use 99% of the data (default)
            factor=0.9     use 90% of the data
         When method="rcf", factor is the desired cdelta value. The RCF filter
         is used to find the cmin/cmax containing the most points for this
         cdelta.
            factor=20.     use 20m window (default)
            factor=5       use 5m window
         When method="all", factor is ignored.
*/
// Original David Nagle 2010-04-23
   local z, cmin, cmax, cdelta;
   data2xyz, data, , , z, mode=mode;
   z = z(sort(z));

   if(method == "stdev") {
      default, factor, 2;
      cminmax = z(avg) + z(rms) * factor * [-1, 1];
      cmin = cminmax(1);
      cmax = cminmax(2);
      cdelta = cminmax(dif)(1);
   } else if(method == "percentage") {
      default, factor, 0.99;
      factor = (1 - factor)/2.;
      count = numberof(z) - 1;
      cmini = long(count * factor + 0.5) + 1;
      factor = 1 - factor;
      cmaxi = long(count * factor + 0.5) + 1;
      cmin = z(cmini);
      cmax = z(cmaxi);
      cdelta = cmax - cmin;
   } else if(method == "rcf") {
      default, factor, 20.;
      cdelta = double(factor);
      cmin = rcf(z, cdelta, mode=0)(1);
      cmax = cmin + cdelta;
   } else if(method == "all") {
      cmin = z(min);
      cmax = z(max);
      cdelta = cmax - cmin;
   }

   if(am_subroutine()) {
      tkcmd, swrite(format="set plot_settings(cmin) %.2f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %.2f", cmax);
      tkcmd, swrite(format="set cdelta %.2f", cdelta);
   } else {
      return [cmin, cmax];
   }
}
