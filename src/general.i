/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
write, "$Id$"

local general_i;
/* DOCUMENT general.i
	
	This file contains an assortment of some general purpose functions.
	
	Functions working in a cartesian plane:
	
		calculate_heading
		perpendicular_intercept
		find_nearest_point
		find_points_in_radius
	
	Functions for interpolations:

		interp_periodic
	
	Functions to convert strings to numbers:

		atoi
		atof
		atod
*/

func calculate_heading(x, y) {
/* DOCUMENT calculate_heading(x, y)
	
	Returns the heading in degrees clockwise from north that an object
	moved from each pair of consecutive points.

	The returned array will have one less index than x and y.

	The following parameters are required:
		
		x: An array representing the easting. Must be in UTM.

		y: An array representing the northing. Must be in UTM.

	Function returns:

		Array of headings in degrees clockwise from north.
*/
	if(typeof(x) == "int" || typeof(x) == "long")
		x = double(x);
	if(typeof(y) == "int" || typeof(y) == "long")
		y = double(y);
	
	x_dif = x(dif);
	y_dif = y(dif);

	radians = array(structof(x_dif), numberof(x_dif));

	// Special case - radians
	temp = where(!x_dif);
	if(numberof(temp))
		radians(temp) = pi/2.0;
	
	// Normal case - radians
	temp = where(x_dif);
	if(numberof(temp))
		radians(temp) = atan(y_dif(temp)/x_dif(temp));

	// Convert to degrees
	degrees = radians * 180.0 / pi;
	
	// Fix quadrants
	temp = where(x_dif < 0);
	if(numberof(temp))
		degrees(temp) -= 180;
	
	// Fix quadrants
	temp = where(y_dif < 0 & !x_dif);
	if(numberof(temp))
		degrees(temp) -= 180;

	// Convert to heading
	heading = 90.0 - degrees;

	return heading;
}

func perpendicular_intercept(x1, y1, x2, y2, x3, y3) {
/* DOCUMENT perpendicular_intercept(x1, y1, x2, y2, x3, y3)
	
	Returns the coordinates of the point where the line that passes through
	(x1, y1) and (x2, y2) intersects with the line that passes through
	(x3, y3)	and is perpendicular to the first line.

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

	require, "data_rgn_selector.i";
	
	// Validate radius
	if(is_void(radius)) { radius = 1.0; }
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

func find_points_in_radius(x, y, xs, ys, radius=, verbose=) {
/* DOCUMENT find_points_in_radius(x, y, xs, ys, radius=, verbose=)

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

	require, "data_rgn_selector.i";
	
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

	Performs a piece-wise linear interpolation with periodic (cyclic) values.
	This is designed to be similar to interp. The difference is it handles
	situations where the values of xp are periodic such as with degrees
	and radians.

	Parameters:

		y: The known values around which to interpolate.

		x: The reference values corresponding to the known values.

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

	See also: interp
*/
	if(numberof(x) * numberof(xp) > 16000000 && numberof(xp) > 1) {
		yp = array(structof(y(1)), numberof(xp));
		for(i = 1; i <= numberof(yp); i++) {
			yp(i) = interp_periodic(y, x, [xp(i)], ps, pe);
		}
		return yp;
	}

	pl = pe - ps;
	ph = pl * 0.5;

	yd = array(0.0, numberof(y));
	yd(:-1) = abs(y(dif));

	diff = x(-:1:numberof(xp),) - xp(,-:1:numberof(x));
	gt = diff > 0;
	eq = diff == 0;

	too_lo = where(gt(,sum) == numberof(x));
	too_hi = where(gt(,sum) == 0);

	gtd = gt(,dif);

	wgtd = where(gtd);
	weq = where(eq);

	i = indgen(numberof(xp))(,-:1:numberof(x));
	v = indgen(numberof(x))(-:1:numberof(xp),);

	gtr = array(0.0, numberof(xp));
	eqr = gtr;
	
	if(numberof(wgtd))
		gtr(i(wgtd)) = v(wgtd);
	if(numberof(weq))
		eqr(i(weq)) = v(weq);

	idx_lo = array(0, numberof(xp));
	idx_hi = idx_lo;
	val_lo = array(0.0, numberof(xp));
	val_hi = val_lo;
	ref_lo = ref_hi = val_lo;
	yd_lo = val_lo;

	if(numberof(where(eqr))) {
		idx_lo(where(eqr)) = eqr(where(eqr));
		idx_hi(where(eqr)) = eqr(where(eqr));
	}

	if(numberof(where(! idx_lo)))
		idx_lo(where(! idx_lo)) = gtr(where(! idx_lo));
	if(numberof(where(! idx_hi)))
		idx_hi(where(! idx_hi)) = gtr(where(! idx_hi)) + 1;
	if(numberof(where(idx_hi == 1)))
		idx_hi(where(idx_hi == 1)) = 0;

	wl = where(idx_lo);
	wh = where(idx_hi);

	if(numberof(wl)) {
		ref_lo(wl) =  x(idx_lo(wl));
		val_lo(wl) =  y(idx_lo(wl));
		yd_lo(wl)  = yd(idx_lo(wl));
	}
	if(numberof(wh)) {
		ref_hi(wh) = x(idx_hi(wh));
		val_hi(wh) = y(idx_hi(wh));
	}

	yp = array(0.0, numberof(xp));
	we = where(idx_lo > 0 & ref_hi == ref_lo);
	wd_bn = where(idx_lo > 0 & ref_hi != ref_lo & yd_lo <= ph);
	wd_by_al = where(idx_lo > 0 & ref_hi != ref_lo & yd_lo > ph & val_lo < val_hi);
	wd_by_ah = where(idx_lo > 0 & ref_hi != ref_lo & yd_lo > ph & val_lo > val_hi);
	wd = where(idx_lo > 0 & ref_hi != ref_lo);
	if(numberof(we))
		yp(we) = val_lo(we);
	if(numberof(wd_bn))
		yp(wd_bn) = 1.0 * (xp(wd_bn) - ref_lo(wd_bn))/(ref_hi(wd_bn) - ref_lo(wd_bn)) * val_hi(wd_bn) +
					  1.0 * (ref_hi(wd_bn) - xp(wd_bn))/(ref_hi(wd_bn) - ref_lo(wd_bn)) * val_lo(wd_bn);
	if(numberof(wd_by_al))
		yp(wd_by_al) = (( 1.0 * (xp(wd_by_al) - ref_lo(wd_by_al))/(ref_hi(wd_by_al) - ref_lo(wd_by_al)) * val_hi(wd_by_al) +
						     1.0 * (ref_hi(wd_by_al) - xp(wd_by_al))/(ref_hi(wd_by_al) - ref_lo(wd_by_al)) * (val_lo(wd_by_al) + pl)
						   ) - ps ) % pl + ps;
	if(numberof(wd_by_ah))
		yp(wd_by_ah) = (( 1.0 * (xp(wd_by_ah) - ref_lo(wd_by_ah))/(ref_hi(wd_by_ah) - ref_lo(wd_by_ah)) * (val_hi(wd_by_ah) + pl) +
						     1.0 * (ref_hi(wd_by_ah) - xp(wd_by_ah))/(ref_hi(wd_by_ah) - ref_lo(wd_by_ah)) * val_lo(wd_by_ah)
							) - ps ) % pl + ps;
	if(numberof(too_lo))
		yp(too_lo) = y(1);
	if(numberof(too_hi))
		yp(too_hi) = y(0);
	
	return yp;
}

func atoi(str) {
/* DOCUMENT atoi(str)
	
	Converts a string representation of a number into an integer.

	The following paramters are required:

		str: A string representation of an integer.
	
	Function returns:

		An integer value.
*/
	i = array(int, numberof(str));
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
	f = array(float, numberof(str));
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
	d = array(double, numberof(str));
	sread, str, format="%f", d;
	return d;
}
