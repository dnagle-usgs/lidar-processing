/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";

local lines_i;
/* DOCUMENT lines.i
   
   This file contains functions for working with lines.

   perpendicular_intercept
   average_line
   smooth_line
   linear_regression
   avgline
   comparelines
*/

func perpendicular_intercept(x1, y1, x2, y2, x3, y3) {
/* DOCUMENT perpendicular_intercept(x1, y1, x2, y2, x3, y3)
   
   Returns the coordinates of the point where the line that passes through
   (x1, y1) and (x2, y2) intersects with the line that passes through
   (x3, y3) and is perpendicular to the first line.

   Either scalars or arrays may be passed as parameters provided the
   arrays all have the same size.

   The following paramaters are required:

      x1, y1: An ordered pair for a point on a line
      x2, y2: An ordered pair for a point on the same line as x1, y1
      x3, y3: An ordered pair from which to find a perpendicular intersect

   Function returns:

      [x, y] where x and y are arrays of the same size as the parameters.
*/
   // Make everything doubles to avoid integer-related errors
   x1 = double(x1);
   y1 = double(y1);
   x2 = double(x2);
   y2 = double(y2);
   x3 = double(x3);
   y3 = double(y3);
   
   // Result arrays
   xi = yi = array(double, numberof(x1));

   // Generate indexes for different portions
   x_eq = where(x1 == x2); // Special case
   y_eq = where(y1 == y2); // Special case
   norm = where(!x1 == x2 | !y1 == y2); // Normal
   
   // Special case
   if(numberof(x_eq)) {
      xi(x_eq) = x1(x_eq);
      yi(x_eq) = y3(x_eq);
   }

   // Special case
   if(numberof(y_eq)) {
      yi(y_eq) = y1(y_eq);
      xi(y_eq) = x3(y_eq);
   }

   // Normal
   if(numberof(norm)) {
      // m12: Slope of line passing through pts 1 and 2
      m12 = (y2(norm) - y1(norm))/(x2(norm) - x1(norm));
      // m3: Slope of line passing through pt 3, perpendicular to line 12
      m3 = -1 / m12;

      // y-intercepts of the two lines
      b12 = y1(norm) - m12 * x1(norm);
      b3 = y3(norm) - m3 * x3(norm);

      // x and y values of intersection points
      xi(norm) = (b3 - b12)/(m12 - m3);
      yi(norm) = m12 * xi(norm) + b12;
   }

   return [xi, yi];
}

func average_line(x, y, bin=, taper=) {
/* DOCUMENT average_line(x, y, bin=, taper=)

   Computes the moving average for an x-y scatter. Each sequence of 'bin'
   points results in an average value in the results. The results array will
   have bin-1 fewer coordinate pairs than the input data unless taper is set.

   Parameters:

      x: An array of floats or doubles.

      y: An array of floats or doubles.

   Options:

      bin= A bin size to use. Default is 10.

      taper= If set to true, the bin size will taper on the ends so that the
         result spans the full distance of x and y, rather than cutting off the
         ends. Default is false, which disables this behavior.

   Returns:

      [avgX, avgY] - An array of doubles of the averaged values.
*/
   if(is_void(bin)) bin=10;
   if(is_void(taper)) taper=0;
   if(bin < 1)
      error, "Bin must be at least 1.";
   if(numberof(x) != numberof(y))
      error, "X and Y must have the same range.";
   if(dimsof(x)(1) != 1)
      error, "X and Y must be one-dimensional arrays.";
   if(bin > numberof(x))
      error, "Bin is too big. Bin must be smaller than X and Y.";
   
   resX = array(double, numberof(x)-bin+1);
   resY = array(double, numberof(x)-bin+1);

   for (i = 1; i <= bin; i++) {
      resX += x(i:-bin+i) / double(bin);
      resY += y(i:-bin+i) / double(bin);
   }

   if(taper) {
      need = bin - 1;
      need_lo = int(need / 2);
      need_hi = need - need_lo;
      lo_resX = array(double, need_lo);
      lo_resY = array(double, need_lo);
      hi_resX = array(double, need_hi);
      hi_resY = array(double, need_hi);
      for(i = 1; i <= need_lo; i++) {
         w = (i - 1) * 2 + 1;
         lo_resX(i) = x(1:w)(avg);
         lo_resY(i) = y(1:w)(avg);
      }
      for(i = 1; i <= need_hi; i++) {
         w = (i - 1) * -2;
         hi_resX(i) = x(w:0)(avg);
         hi_resY(i) = y(w:0)(avg);
      }
      resX = grow(lo_resX, resX, hi_resX);
      resY = grow(lo_resY, resY, hi_resY);
   }

   return [resX, resY];
}

func smooth_line(x, y, &upX, &upY, &idx, bin=, upsample=) {
/* smooth_line(x, y, &upX, &upY, &idx, bin=, upsample=)
   
   This function smooths the line given by [x, y].

   Parameters:

      x, y: Arrays of doubles for the coordinates.

   Output parameters:

      upX: This is set to the upsampled, smoothed X coordinates.

      upY: This is set to the upsampled, smoothed Y coordinates.

      idx: This is the indexes into upX, upY that correspond to the points
         from x, y.

   Options:

      bin= The size of the bin to use for smoothing. This is passed on to
         average_line. Odd size bins are prefered over even sized ones. The
         default is 11.

      upsample= The average_line result is upsampled to provide a higher
         resolution to search against. Higher values will ensure that the
         smoothed line is as close to the original as possible. The default is
         25.

   Returns:

      An array [x, y] of the smoothed line. It is equivalent to [upX(idx),
      upY(idx)].

      Given data = smoothline(x, y), then data(,1) is the new x and data(,2) is
      the new y.
*/
   if(is_void(bin)) bin = 11;
   bin = int(bin);
   if(is_void(upsample)) upsample=25;

   avg_bin = bin;
   write, "Calculating average line...";
   average = average_line(x, y, bin=avg_bin, taper=1);
   avgX = average(, 1);
   avgY = average(, 2);

   src_idx = span(1, numberof(avgX), numberof(avgX));
   dst_idx = span(1, numberof(avgX), numberof(avgX)*upsample+1);
   write, "Upsampling average X coordinates...";
   upX = spline(avgX, src_idx, dst_idx);
   write, "Upsampling average Y coordinates...";
   upY = spline(avgY, src_idx, dst_idx);
   src_idx = dst_idx = [];
   idx = array(int, numberof(x));

   write, "Finding nearest points...";
   timer_init, tstamp;
   for (i = 1; i <= numberof(x); i++) {
      timer_tick, tstamp, i, numberof(x),
         swrite(format=" * Point %d of %d...", i, numberof(x));
      c = (i - 1) * upsample + 1;
      flo = c - upsample * 2;
      fhi = c + upsample * 2;
      if(flo < 1) flo = 1;
      if(fhi > numberof(upX)) fhi = 0;
      idx(i) = flo - 1 + find_nearest_point(x(i), y(i), upX(flo:fhi), upY(flo:fhi), force_single=1);
   }

   return [upX(idx), upY(idx)];
}

func linear_regression(x, y, m=, b=, plotline=) {
/* DOCUMENT linear_regression(x, y, m=, b=, plotline=)

   This program performs a linear regression on the points x,y and outputs m
   (slope), b (y-isept), rsq (statistical r squared), rad (average physical
   radius from the points to the avg. line, squared). If m= or b= is set, the
   program uses that value instead of the statistical value. This allows one to
   force b=0, or by setting m and b, one can find the average radius squared to
   the some other line (specified by m and b).

   Parameters:

      x, y: The points to perform linear regression on.

   Options:

      m, b= A slope and y-intercept, see description above.

      plotline= If set to 1, the data will be plotted.

   Returns:

      [m, b, rsq, rad] where m, b are as above, rsq is statistical r squared,
         and rad is the average radius
*/
   x = double(x);
   y = double(y);
   d = sum(x^2)*numberof(x) - sum(x)^2;
   mm = (sum(x*y)*numberof(x) - sum(x)*sum(y))/d;
   bb = (sum(x^2)*sum(y) - sum(x*y)*sum(x))/d;
   if (is_void(m)) m = mm;
   if (is_void(b)) b = bb;
   ydash = m*x + b;
   xmean = avg(x);
   ymean = avg(y);
   rsq = (sum((ydash-ymean)^2))/(sum((y-ymean)^2));

   binv = y+x/m;
   xisect = (binv - b)/(m+1/m);
   yisect = xisect*m + b;
   r = sqrt( (x-xisect)^2 + (y-yisect)^2 );
   rad = avg(r^2);
   if (plotline) {
      minx = min(x);
      maxx = max(x);
      miny = minx*m+b;
      maxy = maxx*m+b;
      pldj, minx, miny, maxx, maxy, color="red", width=2;
   }
   return [m, b, rsq, rad];
}

func avgline(x, y, step=) {
/* DOCUMENT avgline(x, y, step=)

   This program finds the moving-average line of an x-y scatter. The program
   moves along the x direction and replaces every step= points with the average
   x and average y in that bin. The output is a new array [newx, newy] of the
   average line.  x and y are the points to be averaged.

   The dimensions of the output line will be reduced by a factor of step.

   step= is the number of points to bin for one average point. Default is set
      to 10. For faster changing, but less noisy lines this should be reduced.

   See also: average_line
*/
   default, step, 10;
   num = numberof(x);
   numstep = floor(num/step);
   if(numstep < 2) { /* In case of a too-small dataset */
      newx = avg(x);
      newy = avg(y);
   } else {
      newx = array(float, int(numstep));
      newy = array(float, int(numstep));
      step = int(step);
      for (i=1;i<=numstep;i++) {
         xx = x((i-1)*step+1:step*i);
         yy = y((i-1)*step+1:step*i);
         newx(i) = avg(xx);
         newy(i) = avg(yy);
      }
   }
   return [newx, newy];
}

func comparelines(x, y, a, b, start=, stop=) {
/* DOCUMENT comaparelines(x, y, a, b, start=, stop=)

   This function returns the average y-distance between points (a,b) and line
   (x, y).

   x, y is the reference, or zero line.
   a, b is the line to be compared to x, y.
   start= is the x value to start the analysis.
   stop= is the x value to stop the analysis.
*/
   default, start, min(x);
   default, stop, max(x);
   x = x(sort(x));
   y = y(sort(x));
   a = a(sort(a));
   b = b(sort(a));
   x = x(where(x >= start));
   y = y(where(x >= start));
   if (is_array(x)) x = x(where(x <= stop));
   if (is_array(y)) y = y(where(x <= stop));
   err = array(float, numberof(a));
   count = 1;
   for (i=1; i<=numberof(x)-1; i++) {
      start = x(i);
      stop = x(i+1);
      aa = a(where(a >= start));
      if (is_array(aa)) bb = b(where(a >= start));
      if (is_array(aa)) aa = aa(where(aa < stop));
      if (is_array(aa)) bb = bb(where(aa < stop));
      if (!is_array(aa)) continue;
      m = (y(i)-y(i+1))/(x(i)-x(i+1));
      s = y(i) - m*x(i);
      for (j=1;j<=numberof(aa);j++) {
         err(count) = bb(j)- (m*aa(j)+s);
         count++;
      }
   }
   err = err(where(err));
   if (is_array(err)) avgerr = avg(err^2);
   if (!is_array(err)) avgerr = 0;
   return avgerr;
}
