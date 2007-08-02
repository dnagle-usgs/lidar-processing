/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

require, "data_rgn_selector.i";
require, "spline.i";

local general_i;
/* DOCUMENT general.i
   
   This file contains an assortment of some general purpose functions.
   
   Functions working in a cartesian plane:
   
      perpendicular_intercept
      find_nearest_point
      find_points_in_radius
   
   Functions for interpolations:
   
      interp_angles
   
   Functions to convert strings to numbers:

      atoi
      atof
      atod
   
   Functions for working with degrees:

      slope2degrees
      normalize_degrees
   
   Deprecated functions:

      interp_periodic
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

func find_nearest_point(x, y, xs, ys, force_single=, radius=) {
/* DOCUMENT find_nearest_point(x, y, xs, ys, force_single=, radius=)

   Returns the index(es) of the nearest point(s) to a specified location.

   The following parameters are required:

      x, y: An ordered pair for the location to be found near.

      xs, ys: Correlating arrays of x and y values in which to find the
         nearest point.

   The following options are optional:

      force_single= By default, if several points are all equally near
         then the indexes of all of them will be returned in an array.
         Specifying force_single to a positive value will return only
         one value, selected randomly. Specifying force_single to a
         negative value will return only the first value.

      radius= The initial radius within which to search. Radius multiplies
         by the square root of 2 on each interation of the search. By
         default, radius initializes to 1.

   Function returns:

      The index (or indexes) of the point(s) nearest to the specified point.
*/
   // Validate radius
   if(is_void(radius)) radius = 1.0;
   radius = abs(radius);

   // Initialize the indx of points in the box def by radius
   indx = data_box(xs, ys, x-radius, x+radius, y-radius, y+radius);

   /* The points furthest away from the center in a data_box actually have a
      radius of r * sqrt(2). Thus, when we initially find a box containing
      points, we have to expand the box to make sure there weren't any closer
      ones that just happened to be at the wrong angle. */
   do {
      indx_orig = indx;
      radius *= 2 ^ .5;
      indx = data_box(xs, ys, x-radius, x+radius, y-radius, y+radius);
   } while (!is_array(indx_orig));

   // Calculate the distance of each point in the index from the center
   dist = array(double, numberof(xs));
   dist() = -1;
   dist(indx) = ( (x - xs(indx))^2 + (y - ys(indx))^2 ) ^ .5;
   
   // Find the minimum distance
   above_zero = where(dist(indx)>=0);
   min_dist = min(dist(indx)(above_zero));

   // Find the indexes in the original array that have the min dist
   point_indx = where(dist == min_dist);

   // Force single return if necessary
   if(force_single > 0) {
      pick = int(floor(numberof(point_indx) * random() + 1));
      if(pick > numberof(point_indx)) { pick = int(numberof(point_indx)); }
      point_indx = point_indx(pick);
   } else {
      point_indx = point_indx(1);
   }
   
   return point_indx;
}

func find_points_in_radius(x, y, xs, ys, radius=) {
/* DOCUMENT find_points_in_radius(x, y, xs, ys, radius=)

   Returns the index(es) of the points within a radius of a specified location.

   The following parameters are required:

      x, y: An ordered pair for the location to be found near.

      xs, ys: Correlating arrays of x and y values in which to find the
         nearest point.

   The following options are optional:

      radius= The radius within which to search. By default, radius
         initializes to 3.

   Function returns:

      The indexes of the points within radius.
*/
   // Validate radius
   if(is_void(radius)) { radius = 3.0; }
   radius = abs(radius);

   // Initialize the indx of points in the box def by radius 
   indx = data_box(xs, ys, x-radius, x+radius, y-radius, y+radius);

   // Calculate the distance of each point in the index from the center
   dist = array(double, numberof(xs));
   dist() = radius + 1;  // By default, points are too far away
   dist(indx) = ( (x - xs(indx))^2 + (y - ys(indx))^2 ) ^ .5;
   
   // Find the indexes in the original array that are within radius
   point_indx = where(dist <= radius);

   return point_indx;
}

func interp_periodic(y, x, xp, ps, pe) {
/* DOCUMENT interp_periodic(y, x, xp, ps, pe)

   NOTE: This function is deprecated. You should probably use interp_angles
   instead.

   Performs a piece-wise linear interpolation with periodic (cyclic) values.
   This is designed to be similar to interp. The difference is it handles
   situations where the values of xp are periodic such as with degrees
   and radians.

   Parameters:

      y: The known values around which to interpolate.

      x: The reference values corresponding to the known values. Must be
         monotonically increasing.

      xp: The reference values for which you want to interpolate values.

      ps: The start of the period.

      pe: The end of the period.
   
   Returns:

      yp, which is the interpolated values.
   
   Examples:

      Suppose you're working in degrees, which range from 0 to 360. You
      have known values of x=[1,2,3,4,5] and y=[300,320,350,10,30].
      You want the values of yp for xp=[2.2,3.6,4.1].

         yp = interp_periodic(y, x, xp, 0, 360);

      Suppose you're working in radians, which range from -pi to pi.
      You have known values of x=[1,2,3,4,5] and y=[-2,-3,3,2,1.5].
      You want the values of yp for xp=[2.2,3.6,4.1].
      
         yp = interp_periodic(y, x, xp, -pi, pi);

   See also: interp interp_angles
*/
   yp = array(double, numberof(xp));
   pl = pe - ps;
   for(i = 1; i <= numberof(yp); i++) {
      x_eq = where(x == xp(i));
      if(numberof(x_eq) == 1) {
         yp(i) = y(x_eq);
      } else {
         x_hi = digitize(xp(i), x);
         x_lo = x_hi - 1;
         if(x_lo >= 1) {
            if(x_hi <= numberof(x)) {
               length = abs(x(x_hi) - x(x_lo));
               ratio = abs(xp(i) - x(x_lo))/length;

               diff = y(x_hi) - y(x_lo);
               if(abs(diff) > 0.5*pl) {
                  if(diff < 0) {
                     diff += pl;
                  } else {
                     diff -= pl;
                  }
               }
               
               yp(i) = y(x_lo) + diff * ratio;

               while(yp(i) > pe) {
                  yp(i) -= pl;
               }
               while(yp(i) < ps) {
                  yp(i) += pl;
               }
            } else {
               yp(i) = y(x_lo);
            }
         } else {
            if(x_hi <= numberof(x)) {
               yp(i) = y(x_hi);
            }
         }
      }
   }
   return yp;
}

func interp_angles(ang, i, ip, rad=) {
/* DOCUMENT interp_angles(ang, i, ip, rad=)

   This performs linear interpolation on a sequence of angles. This is designed
   to accept arguments similar to interp. It works by breaking the angle into
   its component pieces for the interpolation, which circumvents problems at
   the boundaries of the cycle.

   Parameters:

      ang: The known angles around which to interpolate.

      i: The reference values corresponding to the known values. Must be
         strictly monotonic.

      ip: The reference values for which you want to interpolate values.

   Options:

      rad= Set to 1 if the angles are in radians. By default, this assumes
         degrees.
*/
   if(is_void(rad)) rad = 0;
   if(is_void(linear)) linear = 0;
   
   angp = array(double, numberof(ip));
   
   if(!rad) ang *= pi/180.0;

   x = cos(ang);
   y = sin(ang);

   xp = interp(x, i, ip);
   yp = interp(y, i, ip);
   
   angp = atan(yp, xp);
   
   if(!rad) angp *= 180.0/pi;

   return angp;
}

func atoi(str) {
/* DOCUMENT atoi(str)
   
   Converts a string representation of a number into an integer.

   The following paramters are required:

      str: A string representation of an integer.
   
   Function returns:

      An integer value.
*/
   i = array(int, dimsof(str));
   sread, str, format="%i", i;
   return i;
}

func atof(str) {
/* DOCUMENT atof(str)
   
   Converts a string representation of a number into a float.

   The following paramters are required:

      str: A string representation of a float.
   
   Function returns:

      A float value.
*/
   f = array(float, dimsof(str));
   sread, str, format="%f", f;
   return f;
}

func atod(str) {
/* DOCUMENT atod(str)
   
   Converts a string representation of a number into a double.

   The following paramters are required:

      str: A string representation of a double.
   
   Function returns:

      A double value.
*/
   d = array(double, dimsof(str));
   sread, str, format="%f", d;
   return d;
}

func slope2degrees(slope, xdif) {
/* DOCUMENT slope2degrees(slope, xdif)

   Calculates the angle in degrees that corresponds to a given slope and
   delta x (xdif). The exact value of xdif is irrelevant; all that is
   considered is its sign (<0 or >0).

   Returns the angle in degrees counter-clockwise from the positive x-axis.
*/
   theta = atan(slope) * 180 / pi;
   if(xdif < 0) {
      theta += 180;
      theta = normalize_degrees([theta], mode=2)(1);
   }
   return theta;
}

func normalize_degrees(ary, mode=) {
/* DOCUMENT normalize_degrees(ary, mode=)

   Adjusts degree values so that all angles are represented within
   a normalized range. The resulting angles will be equivalent to
   the original angles.

   Parameter:
   
      ary: An array of degree values.
   
   Option:
   
      mode= Either 1 or 2, as follows.
         1. The range will be [0,360). (Default)
         2. The range will be (-180,180].
*/
   while(numberof(where(ary<0.0))) {
      ary += 360.0;
   }
   ary %= 360.0;
   if(mode==2 && numberof(where(ary>180.0))) {
      ary(where(ary>180.0)) -= 360.0;
   }
   return ary;
}

func rereference_angle(ang, fdir, fref, tdir, tref, rad=) {
/* DOCUMENT rereference_angle(ang, fdir, fref, tdir, tref, rad=)
   
   This function converts angles from one point of reference to
   another. For example, from 'CW from E' to 'CCW from W'.

   The results may need to be cleaned up with normalize_degrees.

   Parameters:

      ang: An angle, or an array of angles.

      fdir: The original orientation direction. CW or CCW

      fref: The original reference direction. N, E, S, or W.

      tdir: The destination orientation direction. CW or CCW

      tref: The destination reference direction. N, E, S, or W.
   
   Option:

      rad= Set to 1 if the angles are in radians. Omit or set to 0
         for degrees.
   
   Returns:

      An array of doubles containing the rereferenced angles.
*/
   if(fdir != "CW" && fdir != "CCW")
      error, "Second parameter must be CW or CCW.";
   if(fref != "N" && fref != "E" && fref != "S" && fref != "W")
      error, "Third parameter must be N, E, S or W.";
   if(tdir != "CW" && tdir != "CCW")
      error, "Fourth parameter must be CW or CCW.";
   if(tref != "N" && tref != "E" && tref != "S" && tref != "W")
      error, "Fifth parameter must be N, E, S or W.";
   if(is_void(rad))
      rad = 0;
   
   // Convert ang to double so we don't lose anything if it's ints
   ang = double(ang);

   // Change to CW
   if(fdir == "CCW")
      ang *= -1;
   
   // Calculate turns needed to reorient current to north
   if(fref == "N")
      turns = 0;
   else if(fref == "E")
      turns = 1;
   else if(fref == "S")
      turns = -2;
   else if(fref == "W")
      turns = -1;
   
   // Calculate turns needed to reorient from north to destination
   if(tref == "N")
      turns += 0;
   else if(tref == "E")
      turns += -1;
   else if(tref == "S")
      turns += 2;
   else if(tref == "W")
      turns += 1;
   
   // Apply turns
   if(rad)
      ang += turns * 0.5 * pi;
   else
      ang += turns * 90.0;
   
   // Change to CCW if necessary
   if(tdir == "CCW")
      ang *= -1;
   
   return ang;
}

func average_line(x, y, bin=, taper=) {
/* DOCUMENT average_line(x, y, bin=)

   Computes the moving average for an x-y scatter. Each sequence of 'bin'
   points results in an average value in the results. The results array
   will have bin-1 fewer coordinate pairs than the input data.

   Parameters:

      x: An array of floats or doubles.

      y: An array of floats or doubles.

   Options:

      bin= A bin size to use. Default is 10.

      taper= If set to true, the bin size will taper on the ends so that
         the result spans the full distance of x and y, rather than cutting
         off the ends. Default is false, which disables this behavior.

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
         smoothed line is as close to the original as possible. The default
         is 25.

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

func default(&var, val) {
/* DOCUMENT default, &variable, value
   
   This function is meant to be used at the beginning of functions as a helper.
   It will set the variable to value if and only if the variable is void. This
   is a very simple wrapper intended to help abbreviate code and help it
   self-document better.

   Parameters:

      variable: The variable to be set to a default value, if void. It will be
         updated in place.

      value: The default value.
*/
   if(is_void(var)) var = val;
}

func timer_init(&tstamp) {
/* DOCUMENT timer_init, &tstamp
   Initializes timer for use with timer_tick.
*/
   tstamp = 60 * 60 * 60;
}

func timer_tick(&tstamp, cur, cnt, msg) {
/* DOCUMENT timer_tick, &tstamp, cur, cnt, msg

   Displays progress information, updated once per second and at the end.

   Parameters:

      tstamp: A timer variable, initialized with timer_init.

      cur: The current value, indicating how far we are between 1 and cnt.

      cnt: The maximum value.

      msg: A string to indicate our progress. Default is " * cur/cnt". Do not
         append "\n" or "\r" to this.
*/
   if(tstamp != getsod() || cur == cnt) {
      tstamp = getsod();
      default, msg, swrite(format=" * %i/%i", cur, cnt);
      write, format="%s\r", msg;
      if(cur == cnt) {
         write, format="%s", "\n";
      }
   }
}
