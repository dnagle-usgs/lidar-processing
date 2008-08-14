/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$"
require, "general.i";

local geometry_i;
/* DOCUMENT geometry.i

   This file contains geometric and related functions.

   Functions for working with affine matrixes:

      solve_affine
      affine_transform

   Functions for working in a cartesian plane:

      find_nearest_point
      find_points_in_radius

   Functions for interpolations:

      interp_angles

   Functions for working with degrees:

      slope2degrees
      normalize_degrees
      rereference_angle

*/

func solve_affine(sx, sy, dx, dy) {
/* DOCUMENT solve_affine(sx, sy, dx, dy)

   For a set of points (sx, sy), this finds the affine matrix that will
   transform them into (dx, dy). (Source x/y -> Destination x/y.)

   Returned will be an array of the six coefficients of the affine matrix, as
   thus:

   / x' \   / a c e \ / x \
   | y' | = | b d f | | y |
   \ 1  /   \ 0 0 1 / \ 1 /

   A set of three points will return a perfect-fit solution. A set of more than
   three points will return a least-squares solution as per QRsolve.

   Note that the affine elements are ordered as they would be for a JGW file.

   See also: affine_transform
*/
   if(abs([numberof(sx), numberof(sy), numberof(dx), numberof(dy)](dif))(sum))
      error, "Number of points is not conformable."
   if(numberof(sx) < 3)
      error, "At least three points must be provided."

   return transpose(QRsolve([sx, sy, 1], [dx, dy, 1])(,1:2))(*);
}

func affine_transform(&sx, &sy, coeffs) {
/* DOCUMENT [dx, dy] = affine_transform(sx, sy, coeffs)
            affine_transform, &x, &y, coeffs

   Applies the affine transform indicated by the coeffs array to
   the given points.

   First form will apply the transform to arrays of source points
   and return an array of destination points. Second form will
   update the variables in place.

   The coeffs array may take one of three forms:

      coeffs = [a,b,c,d,e,f]
      coeffs = [[a,c,e],[b,d,f]]
      coeffs = [[a,b],[c,d],[e,f]]

   Where a-f correspond to the matrix shown in solve_affine.

   See also: solve_affine
*/
   if(numberof(coeffs) != 6)
      error, "Affine transformations require 6 coefficients.";
   dims = dimsof(coeffs);
   if(dims(1) == 2 && dims(2) == 2)
      coeffs = transpose(coeffs);
   if(dims(1) == 1)
      coeffs = transpose(reform(coeffs(*), [2,2,3]));
   A = array(double, 3, 3);
   A(,1:2) = reform(coeffs(*), [2,3,2]);
   A(3,3) = 1;
   d = (A(+,) * [sx, sy, 1](,+))(1:2,);
   if(am_subroutine()) {
      sx = d(1,);
      sy = d(2,);
   } else {
      return d;
   }
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
