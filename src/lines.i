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

   // Coerce same dimensions
   dims = dimsof(x1);
   if(dims(1) < dimsof(x2)(1))
      dims = dimsof(x2);
   if(dims(1) < dimsof(x3)(1))
      dims = dimsof(x3);

   if(dimsof(x1)(1) < dims(1)) {
      x1 = array(x1, dims);
      y1 = array(y1, dims);
   }

   if(dimsof(x2)(1) < dims(1)) {
      x2 = array(x2, dims);
      y2 = array(y2, dims);
   }

   if(dimsof(x3)(1) < dims(1)) {
      x3 = array(x3, dims);
      y3 = array(y3, dims);
   }
   
   // Result arrays
   xi = yi = array(double, dims);

   // Generate indexes for different portions
   x_eq = x1 == x2; // Special case
   y_eq = y1 == y2; // Special case
   norm = !x_eq & !y_eq; // Normal
   
   // Special case
   if(anyof(x_eq)) {
      w = where(x_eq);
      xi(w) = x1(w);
      yi(w) = y3(w);
   }

   // Special case
   if(anyof(y_eq)) {
      w = where(y_eq);
      yi(w) = y1(w);
      xi(w) = x3(w);
   }

   // Normal
   if(anyof(norm)) {
      w = where(norm);
      // m12: Slope of line passing through pts 1 and 2
      m12 = (y2(w) - y1(w))/(x2(w) - x1(w));
      // m3: Slope of line passing through pt 3, perpendicular to line 12
      m3 = -1 / m12;

      // y-intercepts of the two lines
      b12 = y1(w) - m12 * x1(w);
      b3 = y3(w) - m3 * x3(w);

      // x and y values of intersection points
      xi(w) = (b3 - b12)/(m12 - m3);
      yi(w) = m12 * xi(w) + b12;
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
/* DOCUMENT smooth_line(x, y, &upX, &upY, &idx, bin=, upsample=)
   
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

func line_point_dist(x1, y1, x2, y2, xp, yp) {
/* DOCUMENT dist = line_point_dist(x1, y1, x2, y2, xp, yp);
   Returns the array of distances between the points xp,yp and the line defined
   by (x1,y1),(x2,y2).

   Parameters:
      x1, y1 - A point on the line. Scalars.
      x2, y2 - A different point on the same line. Scalars.
      xp, yp - Arrays of point coordinates.

   Returns:
      dist - Array of distances, conformable with xp and yp.
*/
   intercepts = perpendicular_intercept(x1, y1, x2, y2, xp, yp);
   return ppdist([xp, yp], intercepts, tp=1);
}

func downsample_line(x, y, maxdist=, idx=) {
/* DOCUMENT downsample_line(x, y, maxdist=, idx=)
   Given a polyline defined by a series of x and y coordinates, this will
   downsample the polyline to a subset of those coordinates that still fits the
   original polyline.

   Parameters:
      x, y: Arrays of x and y coordinates.

   Options:
      maxdist= The maximum distance that the downsampled line may be from the
         given points. Default: maxdist=1.
      idx= Specifies whether to return coordinates or indices. Settings:
            idx=0    Return [xd, yd], the downsampled line. (Default)
            idx=1    Return w, the indices into x, y for the downsampled line.

*/
   default, maxdist, 1.;
   default, idx, 0;

   // The new polyline will be a subset of the original. We need to decide
   // which points must be kept in order to retain the shape.

   // Start by keeping just the first and last points.
   keep = array(char(0), numberof(x));
   keep(1) = keep(0) = 1;

   // Check each segment in the new polyline. If any segment is too far from
   // the points it corresponds to, then add the furthest point to the new
   // polyline. New segments are checked further until they fit the threshold.
   w = where(keep);
   for(i = 1; i <= numberof(w) - 1; i++) {
      if(w(i) + 1 == w(i+1))
         continue;
      rng = w(i):w(i+1)
      sx = x(rng);
      sy = y(rng);
      dist = line_point_dist(sx(1), sy(1), sx(0), sy(0), sx, sy);

      if(dist(max) > maxdist) {
         mx = dist(mxx);
         adding = w(i) + mx - 1;
         keep(adding) = 1;
         w = where(keep);
         i--;
      }
   }

   // We now have a reasonable model. However, it can be thinned out even
   // further by reassessing the kept points.

   // We want to repeat this code block until we stop losing points.
   startcount = numberof(keep);
   endcount = numberof(w);
   while(endcount < startcount) {
      startcount = endcount;

      // Tune: Update all kept points to minimize the maximum distance from the
      // original line. Also, if we discover any points that aren't needed...
      // throw them out.
      for(i = 1; i <= numberof(w) - 2; i++) {
         rng = w(i):w(i+2);
         sx = x(rng);
         sy = y(rng);
         dist = line_point_dist(sx(1), sy(1), sx(0), sy(0), sx, sy);

         if(dist(max) > maxdist) {
            mx = dist(mxx);
            adding = w(i) + mx - 1;
            if(adding != w(i+1)) {
               keep(w(i+1)) = 0;
               keep(adding) = 1;
               w = where(keep);
            }
         } else {
            keep(w(i+1)) = 0;
            w = where(keep);
            i--;
         }
      }

      // Thinout: Scan through looking at subseries of four kept points. Check
      // to see if the central two points can be removed. If not, check to see
      // if they can be replaced by a single point.
      thinout = 1;
      while(thinout) {
         thinout = 0;
         for(i = 1; i <= numberof(w) - 3; i++) {
            rng = w(i):w(i+3);
            sx = x(rng);
            sy = y(rng);
            dist = line_point_dist(sx(1), sy(1), sx(0), sy(0), sx, sy);

            if(dist(max) <= maxdist) {
               keep(w(i+1)) = 0;
               keep(w(i+2)) = 0;
               w = where(keep);
               i--;
               thinout = 1;
            } else {
               pivot = dist(mxx);

               p1x = sx(:pivot);
               p1y = sy(:pivot);
               dist1 = line_point_dist(p1x(1), p1y(1), p1x(0), p1x(0), p1x, p1y);

               p2x = sx(pivot:);
               p2y = sy(pivot:);
               dist2 = line_point_dist(p2x(1), p2y(1), p2x(0), p2x(0), p2x, p2y);

               if(dist1(max) <= maxdist && dist2(max) <= maxdist) {
                  keep(w(i+1)) = 0;
                  keep(w(i+2)) = 0;
                  adding = w(i) + pivot - 1;
                  keep(adding) = 1;
                  w = where(keep);
                  i--;
                  thinout = 1;
               }
            }
         }
      }

      endcount = numberof(w);
   }

   return idx ? w : [x(w), y(w)];
}

func level_short_dips(seq, dist=, thresh=) {
/* DOCUMENT leveled = level_short_dips(seq, dist=, thresh=)
   Removes short "dips" in a data array, smoothing out some of its "noise".

   seq should be a 1-dimensional array of numerical values. For example:
      seq=[4,4,4,3,3,4,4,4,5,5,5,6,5,5]

   The sequnce of "3,3" in the above is a short "dip". This function is
   intended to smooth that sort of thing out:
      leveled=[4,4,4,4,4,4,4,4,5,5,5,6,5,5]

   Short peaks will be left alone; only short dips will be leveled.

   Parameter:
      seq: An array of numbers with values to be smoothed out.

   Options:
      dist= If provided, this must be the same length of seq. It defaults to
         [1,2,3...numberof(seq)]. This is used with thresh to determine which
         items on either side of a value are used for comparisons. This array
         is the cummulative differences of distances from point to point. (So
         the default assumes they are equally spaced.)
      thresh= The threshold for how far on either side of a value the algorithm
         should look for determining whether it's a dip. Default is 10.

   Examples:
      > seq = [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
      > seq
      [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
      > level_short_dips(seq, thresh=2)
      [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
      > level_short_dips(seq, thresh=4)
      [2,2,1,1,1,1,1,1,1,2,2,2,2,2,2,3]
      > level_short_dips(seq, thresh=5)
      [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3]
      > dist = [2,1,1,2,1,1,2,1,1,2,1,1,2,1,1](cum)
      > dist
      [0,2,3,4,6,7,8,10,11,12,14,15,16,18,19,20]
      > level_short_dips(seq, thresh=4, dist=dist)
      [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
*/
   default, dist, indgen(numberof(seq));
   default, thresh, 10;

   // We don't want to change the original array, so forcibly create new
   // instance.
   seq = (seq);

   count = numberof(seq);
   // Must make two passes
   // Pass one will miss points that are near the edges of long dips but will
   // fill their centers.
   for(pass = 1; pass <= 2; pass++) {
      r1 = r2 = 1;
      for(i = 1; i <= count; i++) {
         b1 = dist(i) - thresh;
         b2 = dist(i) + thresh;

         // Bring the lower bound within range
         while(r1 <= count && dist(r1) < b1)
            r1++;

         // Push the upper bound /just/ out of range then bring it back in
         while(r2 <= count && dist(r2) < b2)
            r2++;
         r2--;

         // Determine upper and lower max
         lower = seq(r1:i)(max);
         upper = seq(i:r2)(max);

         // Get median value among current and two maxes
         medmax = median([seq(i), lower, upper]);

         // If the median is higher than our current value, change it
         if(seq(i) < medmax)
            seq(i) = medmax;
      }
   }

   return seq;
}
