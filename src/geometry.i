/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";
write, "$Id$"

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

func ppdist(p1, p2, tp=) {
/* ppdist(p1, p2)
   Generalized point-to-point distance function. p1 and p2 must have
   conformable dimensions. This works with points of any dimension (2d, 3d,
   or higher).

   By default, points are assumed to be similar to [[x1,y1],[x2,y2],...]. To
   provide points as [[x1,x2,...],[y1,y2,...]], set tp=1 (stands for
   "transpose", and indicates that an internal set of transposes are
   necessary).

   Examples:
      > ppdist([3,4], [0,0])
      5
      > ppdist([3,4,12], [0,0,0])
      13
      > ppdist([3,4,0], [[0,0,0], [0,0,12]])
      [5,13]
      > ppdist([[[3,4,0]],[[3,4,0]]],[[[0,0,0]],[[0,0,12]]])
      [[5],[13]]
      > ppdist([[[3,4,0],[3,4,0]]],[[[0,0,0],[0,0,12]]])
      [[5,13]]
      > ppdist(0, [[3,3,5],[4,4,12],[0,12,84]], tp=1)
      [5,13,85]
*/
// Original David Nagle 2008-11-18
   default, tp, 0;
   if(tp) {
      p1 = transpose(p1);
      p2 = transpose(p2);
   }
   dist = sqrt(((p1 - p2) ^ 2)(sum,));
   if(tp)
      dist = transpose(dist);
   return dist;
}

/*
--- Explanation of math involved for Tait-Bryan rotations ---

Tait-Bryan rotations (which are the standard aerospace sequence of rotations)
are applied in the order yaw-pitch-roll. The variable 'rotation' is an array
[roll, pitch, yaw]. For purposes of notation, let X, Y, and Z be the angles of
rotation about the x, y, and z axes, corresponding to pitch, roll, and yaw.

The math involved uses the sine and consine of each of the angles X, Y, and Z
extensively. For ease of notation, I will abbreviate sine(X) as sx and
cosine(X) as cs, and similar abbreviations for Y and Z.

Following, we define a 3x3 matrix that will transform coordinates from the
plane's frame of reference to the GPS (world) frame of reference. The
deriviation of this matrix is as follows.

We have values for roll, pitch, and heading, which are the angular rotations
performed to transform between the two frames of reference. These correspond to
angular transforms about the y-axiz, x-axis, and z-axis, in that order. To
tranform a coordinate vector P in plane coordinates [Px,Py,Pz] to the
equivalent gps coordinate G in gps coordinates [Gx,Gy,Gz], we need to perform a
series of matrix multipications as follows:

   Rz * Rx * Ry * P -> G

Rz, Rx, and Ry are the matrixes used to rotate about the z-axis, x-axis, and
y-axis respectively. They are defined as follows:

        / 1 0   0  \        /  cy 0 sy \        / cz -sz 0 \
   Rx = | 0 cx -sx |   Ry = |  0  1 0  |   Rz = | sz  cz 0 |
        \ 0 sx  cx /        \ -sy 0 cy /        \ 0   0  1 /

If we multiply the three matrices together, the result is the following:

                  / cz -sz 0 \   / 1 0   0  \   /  cy 0 sy \
   Rz * Rx * Ry = | sz  cz 0 | * | 0 cx -sx | * |  0  1 0  |
                  \ 0   0  1 /   \ 0 sx  cx /   \ -sy 0 cy /

                  / cz -sz 0 \   / (cy)     (0)  (sy)     \
                = | sz  cz 0 | * | (sx*sy)  (cx) (-sx*cy) |
                  \ 0   0  1 /   \ (-cx*sy) (sx) (cx*cy)  /

                  / (cy*cz - sx*sy*sz) (-cx*sz) (sy*cz + sx*cy*sz) \
                = | (cy*sz + sx*sy*cz) (cx*cz)  (sy*sz - sx*cy*cz) |
                  \ (-cx*sy)           (sx)     (cx*cy)            /

Note: In the above, sin(x), sin(y), cos(z), etc. are abbreviated as sx, sy, cz,
etc.
*/

func transform_delta_rotation(reference_point, delta, rotation) {
/* DOCUMENT transform_delta_rotation(reference_point, delta, rotation)

   This function will return an array of points with equivalent dimensions to
   reference_point that represent the location defined by the given delta and
   rotation with respect to the reference point.

   The arguments are:

      reference_point: An array of points in the form [x,y,z] that represents a
         point whose location is known in the target coordinate system.

      delta: An array of deltas in the form [dx,dy,dz] that represents the
         distance vector between the known reference point and the unknown
         target point whose location we wish to determine.

      rotation: An array of Tait-Bryan rotations in the form [roll, pitch,
         heading], in degrees, that represent the rotations required to
         transform the reference axis system of the delta measurements to the
         reference axis system of the reference_point.

   A practical example for this function would be to determine the location of
   a camera mounted on an airplace. Our input data would be:

      reference_point: Data obtained from a GPS unit.

      delta: Manually acquired measurments that define where the camera is in
         relation to the GPS unit.

      rotation: Data obtained from an INS unit.

   All arrays should be for a single point.
*/
// Original David Nagle 2008-12-30

   // Given:
   //    A reference point whose real-world coordinates we know
   //       Defined as reference_point (array of [x,y,z])
   //    A target point whose location is defined by a displacement vector with
   //       respect to the reference point
   //       Defined as delta (array of [dx, dy, dz])
   //    A set of yaw-pitch-roll angles that define the inertial difference
   //       between the local system's x-y-z axes and the real world's x-y-z axes
   //       Defined as rotation (array of [roll, pitch, heading])

   // Derive the rotation matrix
   R = tbr_to_matrix(rotation);

   // To determine the real-world location of our target point, we convert its
   // delta into a real-world delta, then apply that delta to the reference
   // points coordinates

   return R(+,) * delta(+) + reference_point;
}

func tbr_to_matrix(r, p, h) {
/* DOCUMENT R = tbr_to_matrix(roll, pitch, heading)
            R = tbr_to_matrix([roll, pitch, heading])
   Given a roll, pitch, and heading from a series of Tait-Bryan rotations, this
   will return the corresponding 3x3 matrix.

   See also: matrix_to_tbr
*/
// Original David Nagle 2008-12-30

   if(is_void(p)) {
      tbr = r;
   } else {
      tbr = [r, p, h];
   }

   // Convert to radians
   tbr *= pi / 180.0;

   // Rename the angles by the coordinate they rotate around
   assign, tbr, Y, X, Z;
      
   // The rotation matrix we'll be making will use sin and cos on these a lot.
   // We make shorthand variables to make the matrix more readable and the code
   // more efficient.
   assign, cos([X,Y,Z]), cx, cy, cz;
   assign, sin([X,Y,Z]), sx, sy, sz;

   R = [ [(cy*cz - sx*sy*sz), (-cx*sz), (sy*cz + sx*cy*sz) ],
         [(cy*sz + sx*sy*cz), (cx*cz) , (sy*sz - sx*cy*cz) ],
         [(-cx*sy)          , (sx)    , (cx*cy)            ] ];

   return R;
}

func matrix_to_tbr(R) {
/* DOCUMENT matrix_to_tbr(R)
   Given a 3x3 matrix that can be used to apply a series of Tait-Bryan
   rotations, this will return the [roll, pitch, heading] corresponding to the
   matrix. This ONLY works if the matrix is guaranteed to correspond to such a
   series of rotations.

   Return value is an array [roll, pitch, heading] in degrees.

   See also: tbr_to_matrix
*/
// Original David Nagle 2008-12-30

   // R(2,3) is sin(x)
   X = asin(R(2,3));

   // R(1,3) is -cx*sy and R(3,3) is cx*cy
   // -cx*sy / cx*cy = -sy/cy = -tan(y)
   Y = atan(-1 * R(1,3), R(3,3));

   // R(2,1) is -cx*sz and R(2,2) is cx*cz
   // -cx*sz / cx*cz = -sz/cz = -tan(z)
   Z = atan(-1 * R(2,1), R(2,2));
   
   // Convert to degrees
   tbr = [Y,X,Z] * 180. / pi;

   return tbr;
}
