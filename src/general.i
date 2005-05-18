/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent: */
/* $Id$ */

local general_i;
/* DOCUMENT general.i
	
	This file contains an assortment of some general purpose functions.
	
	Functions working in a cartesian plane:
	
		calculate_heading
		perpendicular_intercept
		find_nearest_point
		find_points_in_radius
	
	Functions to convert strings to numbers:

		atoi
		atof
		atod
*/

func calculate_heading(x1, y1, x2, y2) {
/* DOCUMENT calculate_heading(x1, y1, x2, y2)
	
	Returns the heading in degrees clockwise from north of an object
	that moved from point x1, y1 to point x2, y2.

	The following parameters are required:

		x1, y1: An ordered pair for the first point an object passed through
		x2, y2: An ordered pair for the second point an object passed through
	
	Function returns:

		heading in degrees clockwise from north
*/
	// Calculate the angle of the point in radians CCW from the positive x-axis
	if(x1 == x2) // Special case
		radians = pi/2.0;
	else       // Normal case
		radians = atan(float(y2-y1)/float(x2-x1));
	
	degrees = radians * 180.0 / pi;

	// Put angle in the proper quadrant
	if(x2 < x1 || (y2 < y1 && x2 == x1)) degrees -= 180;

	// Convert angle to a heading 
	heading = 90 - degrees;
	return heading;
}

func perpendicular_intercept(x1, y1, x2, y2, x3, y3) {
/* DOCUMENT perpendicular_intercept(x1, y1, x2, y2, x3, y3)
	
	Returns the coordinates of the point where the line that passes through
	(x1, y1) and (x2, y2) intersects with the line that passes through
	(x3, y3)	and is perpendicular to the first line.

	The following paramaters are required:

		x1, y1: An ordered pair for a point on a line
		x2, y2: An ordered pair for a point on the same line as x1, y1
		x3, y3: An ordered pair from which to find a perpendicular intersect

	Function returns:

		[x, y]
*/
	
	// Make everything doubles to avoid integer-related errors
	x1 = double(x1);
	y1 = double(y1);
	x2 = double(x2);
	y2 = double(y2);
	x3 = double(x3);
	y3 = double(y3);

	if (x1 == x2) { // Special case
		xi = x1;
		yi = y3;
	} else if (y1 == y2) { // Special case
		yi = y1;
		xi = x3;
	} else { // Normal case
		// m12 - slope of the line passing through pts 1 and 2
		m12 = (y2 - y1)/(x2 - x1);
		// m3 - slope of the line passing through pt 3, perpendicular to line 12
		m3 = -1 / m12;

		// y-intercepts of the two lines
		b12 = y1 - m12 * x1;
		b3 = y3 - m3 * x3;

		// x value of the intersection point
		xi = (b3 - b12)/(m12 - m3);

		// y value of the intersection point
		yi = m12 * xi + b12;
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
