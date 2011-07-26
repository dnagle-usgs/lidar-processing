// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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
   if(!numberof(indx))
      return [];

   // Calculate the distance of each point in the index from the center
   // Start with all points too far away
   dist = array(double(radius) + 1, numberof(xs));
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
   default, rad, 0;

   // Eliminates errors for scalars and simplifies handling of multi-dim arrays
   dims = dimsof(ip);
   ip = ip(*);

   angp = array(double, numberof(ip));

   // Trigonometric functions are expensive. Rather than converting ALL of
   // angles back and forth, we can save a lot of time by only converting the
   // range of values that we'll actually need for interpolation.
   minidx = max(1, digitize(ip(min), i) - 1);
   maxidx = min(numberof(i), digitize(ip(max), i) + 1);
   ang = ang(minidx:maxidx);
   i = i(minidx:maxidx);

   if(!rad) ang *= DEG2RAD;

   // Use C-ALPS helper if available
   if(is_func(_yinterp_angles)) {
      ib = digitize(ip, i);
      _yinterp_angles, i, ang, numberof(i),
         ip, angp, ib, numberof(ip);
   } else {
      x = cos(ang);
      y = sin(ang);

      xp = interp(x, i, ip);
      yp = interp(y, i, ip);

      angp = atan(yp, xp);
   }

   if(!rad) angp *= RAD2DEG;

   return dims(1) ? reform(angp, dims) : angp(1);
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
   while(anyof(ary<0.0)) {
      ary += 360.0;
   }
   ary %= 360.0;
   if(mode==2 && anyof(ary>180.0)) {
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

func point_project(p1, p2, dist, tp=) {
/* DOCUMENT point_project(p1, p2, dist, tp=)
   Generalized point projection function. p1 and p2 must have conformable
   dimensions. This works with points of any dimension (2d, 3d, or higher).

   By default, points are assumed to be similar to [[x1,y1],[x2,y2],...]. To
   provide points as [[x1,x2,...],[y1,y2,...]], set tp=1 (stands for
   "transpose", and indicates that an internal set of transposes are
   necessary).

   This will return the point that lies DIST distance further beyond P2 from
   P1. Some examples:

      > point_project([0,0,0], [1,1,1], 2)
      [2.1547,2.1547,2.1547]
      > point_project([0,1], [0,0], 1)
      [0,-1]
      > point_project([0,1], [0,0], [1,2,3])
      [[0,-1],[0,-2],[0,-3]]
*/
   d1 = ppdist(p1, p2, tp=tp);
   if(nallof(d1))
      error, "p1 and p2 must not be the same";
   d2 = d1 + dist;
   return p1 + (p2 - p1) * (d2/d1)(-,);
}

func ppdist(p1, p2, tp=) {
/* DOCUMENT ppdist(p1, p2, tp=)
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
      return transpose(ppdist(transpose(unref(p1)), transpose(unref(p2))));
   } else {
      return sqrt(((unref(p1) - unref(p2)) ^ 2)(sum,));
   }
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

func poly_bbox(x, y) {
/* DOCUMENT poly_bbox(x, y)
   poly_bbox(ply)

   Given a polygon, this returns its bounding box: [xmin, xmax, ymin, ymax].
*/
// Original David B. Nagle 2009-04-16
   if(is_void(y)) {
      y = x(2,);
      x = x(1,);
   }
   x = x(*);
   y = y(*);
   return [x(min), x(max), y(min), y(max)];
}

func poly_area(x1, y1) {
/* DOCUMENT poly_area(x, y)
   poly_area(ply)

   Calculates and returns the area of a polygon.
   
   The polygon can be defined in one of two ways:
      x, y -- the x and y points of the polygon
      ply -- x,y points in an array where dimsof(ply) == [2,2,n]

   For simple (non-intersecting) polygons, the area is the area covered by
   the polygon in its plane.

   For self-intersecting polygons, the area is affected by regional densities
   due to crossings. For example:
      * The central convex pentagon within a pentagram has a density of 2.
        Its area counts twice.
      * A cross-quadrilateral (such as [[0,0],[0,1],[1,0],[1,1]]) will have
        two triangular regions of opposite-signed densities. The total area
        will thus be less than the area covered by the polygon in its plane
        (and can even be zero, as in the example given).
*/
// Original David B. Nagle 2009-03-10
// Using math and explanation as found from Wikipedia:
// http://en.wikipedia.org/w/index.php?title=Polygon&oldid=271086171
   if(is_void(y1)) {
      y1 = x1(2,);
      x1 = x1(1,);
   }
   x2 = yroll(x1,-1);
   y2 = yroll(y1,-1);
   area = 0.5 * (x1*y2 - x2*y1)(sum);
   return abs(area);
}

func convex_hull(x, y) {
/* DOCUMENT hull = convex_hull(x, y)
   hull = convex_hull(ply)
   Returns the polygon that represents the convex hull of the given points.

   dimsof(hull) == [2,2,n]
   hull(1,) == x's
   hull(2,) == y's
*/
// Original David B. Nagle 2009-03-10
// Adapted from algorithm found on Wikipedia:
// http://en.wikipedia.org/w/index.php?title=Graham_scan&oldid=274508758
   if(is_void(y)) {
      splitary, noop(x), 2, x, y;
   }
   x = x(*);
   y = y(*);
   count = numberof(x);

   srt = sort(x);
   x = double(x(srt));
   y = double(y(srt));
   srt = [];

   // L - lower; U - upper
   Lx = Ly = Ux = Uy = array(double, count);
   Lx([1,2]) = Ux([1,2]) = x([1,2]);
   Ly([1,2]) = Uy([1,2]) = y([1,2]);
   Li = Ui = 2;
   for(i = 3; i <= count; i++) {
      while(
         Li >= 2 &&
         cross_product_sign(Lx(Li-1), Ly(Li-1), Lx(Li), Ly(Li), x(i), y(i)) <= 0
      ) {
         Li--;
      }
      Li++;
      Lx(Li) = x(i);
      Ly(Li) = y(i);

      while(
         Ui >= 2 &&
         cross_product_sign(Ux(Ui-1), Uy(Ui-1), Ux(Ui), Uy(Ui), x(i), y(i)) >= 0
      ) {
         Ui--;
      }
      Ui++;
      Ux(Ui) = x(i);
      Uy(Ui) = y(i);
   }
   Lx = unref(Lx)(:Li-1);
   Ly = unref(Ly)(:Li-1);
   Ux = unref(Ux)(:Ui)(::-1);
   Uy = unref(Uy)(:Ui)(::-1);
   LUx = grow(unref(Lx),unref(Ux));
   LUy = grow(unref(Ly),unref(Uy));
   LU = transpose([unref(LUx), unref(LUy)]);
   return LU;
}

func cross_product_sign(x1, y1, x2, y2, x3, y3) {
/* DOCUMENT handed = cross_product_sign(x1, y1, x2, y2, x3, y3)
   Returns a value whose sign indicates the "handedness" of the cross
   product. Primarily intended for use within convex_hull.

   handed < 0 -- "right turn"
   handed > 0 -- "left turn"
   handed == 0 -- collinear
*/
// Original David B. Nagle 2009-03-10
// Using math from Wikipedia:
// http://en.wikipedia.org/w/index.php?title=Graham_scan&oldid=274508758
   if(is_func(_ycross_product_sign)) {
      result = array(double(0.), dimsof(x1,y1,x2,y2,x3,y3));
      if(is_void(result))
         error, "Input not conformable.";
      // Adding result to everything belong forces them all to double and
      // broadcasts them to the result size if necessary.
      _ycross_product_sign, result+unref(x1), result+unref(y1),
         result+unref(x2), result+unref(y2), result+unref(x3),
         result+unref(y3), result, numberof(result);
      return result;
   }
   x2x1 = unref(x2) - x1;
   y3y1 = unref(y3) - y1;
   y2y1 = unref(y2) - unref(y1);
   x3x1 = unref(x3) - unref(x1);
   return unref(x2x1)*unref(y3y1)-unref(y2y1)*unref(x3x1);
}

func in_triangle(x1, y1, x2, y2, x3, y3, xp, yp) {
/* DOCUMENT in_triangle(x1, y1, x2, y2, x3, y3, xp, yp)
   Returns an array of boolean values (1 or 0) indicating whether each point
   xp, yp is within the triangle defined by the points x1,y1, x2,y2, and x3,y3.

   All input may be scalar or array; if arrays are given, they must all be
   conformable.

   This is effectively a specialized version of testPoly/testPoly2 for
   triangles.
*/
// Original David Nagle 2010-02-10
   if(is_func(_yin_triangle)) {
      result = array(short(0), dimsof(x1,y1,x2,y2,x3,y3,xp,yp));
      if(is_void(result))
         error, "Input not conformable.";
      // Adding result to everything broadcasts them to the result size if
      // necessary.
      _yin_triangle, result+unref(x1), result+unref(y1), result+unref(x2),
         result+unref(y2), result+unref(x3), result+unref(y3),
         result+unref(xp), result+unref(yp), result, numberof(result);
      return result;
   }
   AB = cross_product_sign(x1, y1, x2, y2, xp, yp);
   BC = cross_product_sign(x2, y2, x3, y3, xp, yp);
   CA = cross_product_sign(x3, y3, x1, y1, xp, yp);
   return ((AB >= 0) & (BC >= 0) & (CA >= 0)) | ((AB <= 0) & (BC <= 0) & (CA <= 0));
}

func triangle_areas(x1, y1, x2, y2, x3, y3) {
/* DOCUMENT area = triangle_areas(x1, y1, x2, y2, x3, y3)
   Returns the areas of the triangles defined by the points given. Each value
   may be array or scalar, but all values must be conformable with one
   another.
*/
// Original David B. Nagle 2009-03-10
   yd1 = y2 - y3;
   yd2 = unref(y3) - y1;
   yd3 = unref(y1) - unref(y2);
   area = 0.5 * (
      unref(x1) * unref(yd1) +
      unref(x2) * unref(yd2) +
      unref(x3) * unref(yd3)
   );
   return area;
}

func buffer_hull(ply, buffer, pts=) {
/* DOCUMENT buffer_hull(ply, buffer)
   Given a convex hull, this will add a buffer around it.

   In order to calculate the buffered hull, each point in the input hull is
   treated as the center of a circle. Points are sampled along the
   circumference of the circle at equal intervals and added to a new point
   cloud. Then, the convex hull of the new point cloud is returned.

   ply - Should be a polygon. Normally this is a polygon returned by
      convex_hull, however, any polygon can be passed (though the returned
      result will be a convex hull around it if it's not a convex hull).

   buffer - The amount of buffer to be applied around the hull.

   pts= This is the number of sample points around each input point that should
      be added to the polygon before recreating its convex hull. It defaults to
      8. This needs to be at least 1. Higher numbers result in a smoother
      buffered hull, but will also result in a hull with more data points. Very
      low values (under 4) may result in unsatisfactory results.
*/
// Original David B. Nagle 2009-03-13
   default, pts, 8;
   mixed_points = ply;
   angles = span(0, 2*pi, pts+1)(:-1);
   for(i = 1; i <= numberof(angles); i++) {
      grow, mixed_points, ply + (buffer * [cos(angles(i)), sin(angles(i))]);
   }
   return convex_hull(mixed_points(1,), mixed_points(2,));
}

func angular_range(ang, rad=) {
/* DOCUMENT [min, max, span] = angular_range(ang, rad=)
   Returns metrics on the angular range of the given array of angles.

   Angles may be in degrees or radians. Default is degrees. Use rad=1 if they
   are in radians. The return value will have the same kind of angles as the
   input.

   This finds the bounding angles for a set of angles and returns the minimum
   and maximum angles and the distance between those angles.

   Examples:

   > angular_range([4,6,12])
   [4,12,8]
   > angular_range([0,2,4,6,8,9,7,5,3,1])
   [0,9,9]
   > angular_range([0,10,20,340,350])
   [-20,20,40]
   > angular_range([175,180,185])
   [175,185,10]
*/
// Original David B. Nagle 2009-03-16
   default, rad, 0;

   ang = set_remove_duplicates(ang);
   if(!rad) ang *= pi/180.;

   // normalize them
   ang = atan(sin(ang),cos(ang));

   amin = ang(min);
   amax = ang(max);

   inner = numberof(where(amin < ang & ang < amax));
   outer = numberof(where(amin > ang | ang > amax));

   result = [];
   if(outer > inner) {
      result = [amax, amin, 2 * pi - (amax - amin)];
   } else {
      result = [amin, amax, amax - amin];
   }

   w = where(ang < 0);
   if(numberof(w)) {
      ang(w) += 2 * pi;
      amin = ang(min);
      amax = ang(max);

      inner = numberof(where(amin < ang & ang < amax));
      outer = numberof(where(amin > ang | ang > amax));

      if(outer > inner) {
         rng = 2 * pi - (amax - amin);
         if(rng < result(3)) {
            result = [amax, amin, 2 * pi - (amax - amin)];
         }
      } else {
         rng = amax - amin;
         if(rng < result(3)) {
            result = [amin, amax, amax - amin];
         }
      }

   }

   if(!rad) result *= 180./pi;

   return result;
}

func planar_params_from_pts(x1, y1, z1, x2, y2, z2, x3, y3, z3) {
/* DOCUMENT planar_params_from_pts(x1, y1, z1, x2, y2, z2, x3, y3, z3)
   planar_params_from_pts(p1, p2, p3)

   Returns an array of three values [A, B, C] that are the parameters that
   define the plane containing the given three points. The points may be
   specified individually, or in triplets.

   The parameters can be used with this equation:
      z = Ax + By + C
*/
   if(is_void(x2)) {
      assign, z1, x3, y3, z3;
      assign, y1, x2, y2, z2;
      assign, (x1), x1, x2, x3;
   }
   if(is_func(_yplanar_params_from_pts)) {
      A = B = D = double(0);
      _yplanar_params_from_pts, x1, y1, z1, x2, y2, z2, x3, y3, z3, A, B, D;
      return [A,B,D];
   }

   /*
   Equation of a plane is:

      Ax + By + Cz + D = 0

   Given three points defined as x1 .. z3, the constants are defined by the
   following determinants:

          | 1 y1 z1 |      | x1 1 z1 |      | x1 y1 1 |       | x1 y1 z1 |
      A = | 1 y2 z2 |  B = | x2 1 z2 |  C = | x2 y2 1 |  -D = | x2 y2 z2 |
          | 1 y3 z3 |      | x3 1 z3 |      | x3 y3 1 |       | x3 y3 z3 |

   We then normalize it to solve for z by coercing z's factor to 1.

      Ax + By + Cz + D = 0
      Cz = -Ax + -By + -D
      z = (-A/C)x + (-B/C)y + (-D/C)
      z = A'x + B'y + C'
      A' = -A/C   B' = -B/C   C' = -D/C

   */

   A = det([[1,y1,z1],[1,y2,z2],[1,y3,z3]]);
   B = det([[x1,1,z1],[x2,1,z2],[x3,1,z3]]);
   C = det([[x1,y1,1],[x2,y2,1],[x3,y3,1]]);
   D = -det([[x1,y1,z1],[x2,y2,z2],[x3,y3,z3]]);

   return [A,B,D]/(-C);
}

func line_to_poly(x0, y0, x1, y1, width=) {
/* DOCUMENT line_to_poly(x0, y0, x1, y1, width=)
   Given a line defined as passing through points (X0,Y0) and (X1,Y1), this
   will return a polygon that corresponds to it. If WIDTH= is given, the
   polygon will be given that width.
*/
   ply = [[x0,y0],[x0,y0],[x1,y1],[x1,y1]]
   if(is_void(width))
      return ply;

   // Cut the width in half, so we can apply it in both directions.
   width = width/2.;

   // Special case: vertical line
   if(x0 == x1) {
      offset = [[width,0],[-width,0],[-width,0],[width,0]];
      return ply + offset;
   }

   // Special case: horizontal line
   if(y0 == y1) {
      offset = [[0,width],[0,-width],[0,-width],[0,width]];
      return ply + offset;
   }

   // Normal case: line with slope

   // Calculate theta of line perpendicular to that of the points
   theta = atan(y1 - y0, x1 - x0) + pi/2;

   // Determine x/y offsets given theta
   xoff = cos(theta) * width;
   yoff = sin(theta) * width;

   offset = [[xoff,yoff],[-xoff,-yoff],[-xoff,-yoff],[xoff,yoff]];
   return ply + offset;
}

func poly_to_circle(x, y) {
/* DOCUMENT poly_to_circle(x, y)
   -or- poly_to_circle(xy)

   Given a polygon defined by the given coordinates, a circle that
   circumscribes that polygon will be returned. The circle's center will be the
   polygon's centroid, and the radius will be the distance to the furthest
   point of the polygon from the centroid.

   Returns:
      [X, Y, R] where X and Y are the center and R is the radius

   You can plot using pl_circle:
      pl_circle, X, Y, R
*/
   if(is_void(y)) {
      splitary, noop(x), x, y;
   }
   if(x(0) == x(1) && y(0) == y(1)) {
      x = x(:-1);
      y = y(:-1);
   }

   X = x(avg);
   Y = y(avg);
   R = ppdist([x,y], [X,Y], tp=1)(max);

   return [X,Y,R];
}

func poly_intersect_circle_test(x0, y0, x1, y1) {
/* DOCUMENT poly_intersect_circle_test(x0, y0, x1, y1)
   Tests to see if two polygons might intersect by using a simple circle test.
   A circle is calculated that circumscribes each polygon, then the distance
   between their centers is compared to the sum of their radii.

   Returns:
      0 if the polygons are known to not intersect
      1 if the polygons might intersect
*/
   local X0, Y0, R0, X1, Y1, R1;
   assign, poly_to_circle(x0, y0), X0, Y0, R0;
   assign, poly_to_circle(x1, y1), X1, Y1, R1;
   dist = ppdist([X0,Y0], [X1,Y1]);
   return dist <= R0 + R1;
}

func poly_intersect_bbox_test(x0, y0, x1, y1) {
/* DOCUMENT poly_intersect_bbox_test(x0, y0, x1, y1)
   Tests to see if two polygons might intersect by using a simple bounding box
   test. The bounding box of each polygon is calculated and the bounding boxes
   are checked to see if they overlap.

   Returns:
      0 if the polygons are known to not intersect
      1 if the polygons might intersect
*/
   if(x0(min) > x1(max)) return 0;
   if(x1(min) > x0(max)) return 0;
   if(y0(min) > y1(max)) return 0;
   if(y1(min) > y0(max)) return 0;
   return 1;
}

func poly_intersect_test(x0, y0, x1, y1) {
/* DOCUMENT poly_intersect_test(x0, y0, x1, y1)
   Tests to see if two polygons might intersect by using simple circle and bbox
   tests. This DOES NOT GUARANTEE that they intersect if it returns true, only
   that they MIGHT.

   Returns:
      0 if the polygons are known to not intersect
      1 if the polygons might intersect
*/
   if(!poly_intersect_bbox_test(x0, y0, x1, y1))
      return 0
   if(!poly_intersect_circle_test(x0, y0, x1, y1))
      return 0;
   return 1;
}

func convex_poly_collision(x0, y0, x1, y1) {
/* DOCUMENT convex_poly_collision(x0, y0, x1, y1)
   Given two polygons defined by x0,y0 and x1,y1, returns 1 if the polygons
   intersect and 0 if they do not. This only works with convex polygons. The
   function assumes the user is passing it convex polygons and will not verify.
*/
   // Shortcut for obvious cases
   if(!poly_intersect_bbox_test(x0, y0, x1, y1))
      return 0;

   poly_normalize, x0, y0;
   poly_normalize, x1, y1;

   n0 = numberof(x0);
   n1 = numberof(x1);

   polys = [&[&x0, &y0], &[&x1, &y1]];

   // Iterate over each poly...
   for(j = 1; j <= 2; j++) {
      eq_nocopy, xs, *(*polys(j))(1);
      eq_nocopy, ys, *(*polys(j))(2);

      // For each line segment in the poly...
      for(i = 1; i < n0; i++) {
         // For the current line segment, determine a line that's perpendicular
         // to it
         xa = xs(i);
         ya = ys(i);
         xb = xs(i) + (ys(i+1)-ys(i));
         yb = ys(i) - (xs(i+1)-xs(i));

         // Project all points onto the perpedicular line
         p0 = perpendicular_intercept(xa, ya, xb, yb, x0, y0);
         p1 = perpendicular_intercept(xa, ya, xb, yb, x1, y1);

         // Determine whether x or y varies more quickly
         if(p0(max,1)-p0(min,1) > p0(max,2)-p0(min,2)) {
            // See if the segments are separated
            if(p0(max,1) < p1(min,1))
               return 0;
            else if(p0(min,1) > p1(max,1))
               return 0;
         } else {
            // See if the segments are separated
            if(p0(max,2) < p1(min,2))
               return 0;
            else if(p0(min,2) > p1(max,2))
               return 0;
         }
      }
   }

   return 1;
}

func poly_normalize(&x, &y) {
/* DOCUMENT poly_normalize, x, y
   -or- poly_normalize, ply
   -or- poly_normalize(x, y)

   Normalizes a polygon so that:
      - it is closed
      - it has no duplicated points in sequence
      - points are in clockwise order
      - first point is smallest x, then smallest y

   Updates in place as subroutine, else returns new [x,y].
*/
   if(is_void(y)) {
      splitary, x, 2, _x, _y;
   } else {
      _x = x;
      _y = y;
   }

   // Make sure the polygon is closed
   grow, _x, _x(1);
   grow, _y, _y(1);

   // Eliminate any duplicated points
   w = where(grow(1, (_x(:-1) != _x(2:)) | (_y(:-1) != _y(2:))));
   _x = _x(w);
   _y = _y(w);

   // Make sure points are in a clockwise order
   dir = ((_x(2:) - _x(:-1)) * (_y(2:) + _y(:-1)))(sum);
   if(dir < 0) {
      _x = _x(::-1);
      _y = _y(::-1);
   }

   // Make sure first point is smallest x, then smallest y
   start = msort(_x, _y)(1);
   if(start > 1) {
      _x = grow(_x(start:-1), _x(1:start));
      _y = grow(_y(start:-1), _y(1:start));
   }

   if(am_subroutine()) {
      if(is_void(y)) {
         x = [_x, _y];
      } else {
         x = _x;
         y = _y;
      }
   } else {
      return [_x, _y];
   }
}

