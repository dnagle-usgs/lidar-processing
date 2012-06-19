// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func dm2deg(coord) {
/* DOCUMENT dm2deg(coord)

  Converts coordinates in degree-minute format to degrees.

  The following parameter is required:

    coord: A scalar or array of coordinate values to be converted.
      The format should be DDDMM.MM where DDD is the value for
      degrees and MM.MM is the value for minutes. Minutes must
      have a width of two (zero-padding if necessary). (The number
      of places after the decimal may vary.)

  Function returns:

    A scalar or array of the converted degree values.

  SEE ALSO: deg2dm, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
  d = int(coord / 100.0);
  coord -= d * 100;
  m = coord / 60.0;
  deg = d + m;
  return d + m;
}

func deg2dm(coord) {
/* DOCUMENT deg2dm(coord)

  Converts coordinates in degrees to degree-minute format.

  Required parameter:

    coord: A scalar or array of coordinate values in degrees to
      be converted.

  Function returns:

    A scalar or array of converted degree-minute values.

  SEE ALSO: dm2deg, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
  d = floor(abs(coord));
  m = (abs(coord) - d) * 60;
  dm = sign(coord) * (d * 100 + m);
  return dm;
}

func ddm2deg(coord) {
/* DOCUMENT ddm2deg(coord)

  Converts coordinates in degree-deciminute format to degrees.

  The following parameter is required:

    coord: A scalar or array of coordinate values to be converted.
      The format should be DDDMMMM.MM where DDD is the value for
      degrees and MMMM.MM is the value for deciminutes. Deciminutes
      must have a width of four (zero-padding if necessary). (The
      number of places after the decimal may vary.)

  Function returns:

    A scalar or array of the converted degree values.

  SEE ALSO: dm2deg, deg2dm, deg2ddm, dms2deg, deg2dms
*/
  return dm2deg(coord / 100.0);
}

func deg2ddm(coord) {
/* DOCUMENT deg2ddm(coord)

  Converts coordinates in degrees to degree-deciminute format.

  Required parameter:

    coord: A scalar or array of coordinate values in degrees to
      be converted.

  Function returns:

    A scalar or array of converted degree-deciminute values.

  SEE ALSO: dm2deg, deg2dm, ddm2deg, dms2deg, deg2dms
*/
  return deg2dm(coord) * 100;
}

func dms2deg(coord) {
/* DOCUMENT dms2deg(coord)

  Converts coordinates in degree-minute-second format to degrees.

  The following parameter is required:

    coord: A scalar or array of coordinate values to be converted.
      The format should be DDDMMSS.SS where DDD is the value for
      degrees, MM is the value for minutes, and SS.SS is the value
      for seconds. Minutes and seconds must each have a width of
      two (zero-padding if necessary). (The number of places after
      the decimal may vary.)

  Function returns:

    A scalar or array of the converted degree values.

  SEE ALSO: dm2deg, deg2dm, deg2dms, ddm2deg, deg2ddm
*/
  d = int(coord / 10000.0);
  coord -= d * 10000;
  m = int(coord / 100.0);
  s = coord - (m * 100);
  deg = d + m / 60.0 + s / 3600.0;
  return deg;
}

func deg2dms(coord, arr=) {
/* DOCUMENT deg2dms(coord, arr=)

  Converts coordinates in degrees to degrees, minutes, and seconds.

  Required parameter:

    coord: A scalar or array of coordinates values in degrees to
      be converted.

  Options:

    arr= Set to any non-zero value to make this return an array
      of [d, m, s]. Otherwise, returns [ddmmss.ss].

  Function returns:

    Depending on arr=, either [d, m, s] or [ddmmss.ss].

  SEE ALSO: dm2deg, deg2dm, dms2deg, ddm2deg, deg2ddm
*/
  d = floor(abs(coord));
  m = floor((abs(coord) - d) * 60);
  s = ((abs(coord) - d) * 60 - m) * 60;
  if(arr)
    return sign(coord) * [d, m, s];
  else
    return sign(coord) * (d * 10000 + m * 100 + s);
}

func deg2dms_string(coord) {
/* DOCUMENT deg2dms_string(coord)
  Given a coordinate (or array of coordinates) in decimal degrees, this
  returns a string (or array of strings) in degree-minute-seconds, formatted
  nicely.
*/
  dms = deg2dms(coord, arr=1);
  // ASCII: 176 = degree  39 = single-quote  34 = double-quote
  return swrite(format="%.0f%c %.0f%c %.2f%c", dms(..,1), 176, abs(dms(..,2)),
    39, abs(dms(..,3)), 34);
}

func dms_string2deg(coord) {
/* DOCUMENT dms_string2deg(coord)
  Converts a geographic coordinate in a string representation of
  degrees-minutes-seconds format into decimal degrees. Return values will be
  doubles in the range (-180,180].

  As an illustrative example of the input this can handle, given this test
  input:

    [
      ["n25:08:53.69144", "w080:31:58.48680"],
      ["n25:08:53.69144", "w80:31:58.48680"],
      ["n25 08 53.69144", "w080 31 58.48680"],
      ["n25 08 53.69144", "w80 31 58.48680"],
      ["n250853.69144",   "w0803158.48680"],
      ["n250853.69144",   "w803158.48680"],
      ["25:08:53.69144",  "-080:31:58.48680"],
      ["25:08:53.69144",  "-80:31:58.48680"],
      ["25 08 53.69144",  "-080 31 58.48680"],
      ["25 08 53.69144",  "-80 31 58.48680"],
      ["250853.69144",    "-0803158.48680"],
      ["n25:08:53.69144", "E279:28:1.5132"],
      ["n250853.69144",   "E2792801.5132"],
      ["25:08:53.69144",  "279:28:1.5132"],
      ["250853.69144",    "2792801.5132"]
    ]

  The output should all be pairs of [25.14824762,-80.532913].

  Specifically:
    - Direction can optionally be noted with any of N, S, W, E, n, s, w, or e
      as the first character. North and east are positive, south and west are
      negative.
    - Direction can also be noted using a negative sign.
    - In the absence of a leading letter or sign, the coordinate is treated as
      positive.
    - The degrees, minutes, and seconds may optionally be separated by a colon
      or space.
    - If the deegres, minutes, and seconds are not separated by a colon or
      space, then minutes and seconds must be zero padded if the values are
      less than 10.
    - If longitude is given as a positive value over 180, it will be converted
      into the corresponding negative value.
    - The output will have the same dimensionality as the input.
    - Output is not well defined for values that do not fit expected input. A
      string with no numerical values will result in 0, other strings may have
      arbitrary results.
*/
  if(!is_scalar(coord)) {
    result = array(double, dimsof(coord));
    count = numberof(result);
    for(i = 1; i <= count; i++) {
      result(i) = dms_string2deg(coord(i));
    }
    return result;
  }

  // Ignore leading/trailing whitespace
  coord = strtrim(coord);

  // Return 0 for a bad string
  if(!strlen(coord))
    return 0;

  // Detect sign
  sgn = 1;
  if(strmatch("NnEeSsWw", strpart(coord, 1:1))) {
    if(strmatch("SsWw", strpart(coord, 1:1)))
      sgn = -1;
    coord = strpart(coord, 2:);
  }

  // Coerce to number(s)
  d = m = s = 0.;
  null = "";
  count = sread(coord, format="%f%[-: ]%f%[-: ]%f", d, null, m, null, s);

  // Coerce to degrees
  if(count == 1)
    deg = sgn * dms2deg(d);
  else
    deg = (abs(d) + m / 60.0 + s / 3600.0) * sign(d) * sgn;

  // Handle large longitudes
  if(deg > 180)
    deg -= 360;

  return deg;
}

func xyz_dm2deg(xyz, fixlon=) {
/* DOCUMENT result = xyz_dm2deg(xyz, fixlon=)
  Given a 2-dimensional array with five columns as [x degrees, x minutes, y
  degrees, y minutes, z], this will convert it to [x degrees, y degrees, z].
  In other words, it converts the degrees+minutes to decimal minutes for each
  of x and y. The z values are left untouched.

  By default, if all y degree resulting values are positive, they will be
  converted to negative since we typically work in the western hemisphere. If
  you wish to suppress this behavior, use fixlon=0.
*/
  local xdeg, xmin, ydeg, ymin, x, y, z;
  default, fixlon, 1;
  splitary, xyz, xdeg, xmin, ydeg, ymin, z;
  x = xdeg + (xmin/60.);
  y = ydeg + (ymin/60.);
  if(fixlon && allof(x > 0))
    x *= -1;
  return [x,y,z];
}

func display_coord_bounds(x, y, cs, prefix=) {
/* DOCUMENT display_coord_bounds, x, y, cs, prefix=
  Displays the bounds for the given set of coordinates. X and Y must be arrays
  of coordinate values. CS must be the coordinate system. PREFIX defaults to "
  " and is used as a prefix to each output line.
*/
  default, prefix, " ";
  cs = cs_parse(cs, output="hash");

  // cells is an array of cell data in string form that will get displayed in
  // tabular fashion
  cells = [["","min","max"],["","",""]];
  if(cs.proj == "longlat") {
    grow, cells, [["x/lon:", swrite(format="%.11f", x(min)),
      swrite(format="%.11f", x(max))]];
    grow, cells, [["", deg2dms_string(x(min)), deg2dms_string(x(max))]];
    grow, cells, [["","",""]];
    grow, cells, [["y/lat:", swrite(format="%.11f", y(min)),
      swrite(format="%.11f", y(max))]];
    grow, cells, [["", deg2dms_string(y(min)), deg2dms_string(y(max))]];
  } else {
    grow, cells, [["x/east:", swrite(format="%.2f", x(min)),
      swrite(format="%.2f", x(max))]];
    grow, cells, [["y/north:", swrite(format="%.2f", y(min)),
      swrite(format="%.2f", y(max))]];
  }

  // rows is an array of strings, one per row of cells
  rows = array(string, dimsof(cells)(3));

  // cols is the width of each column
  cols = strlen(cells)(,max);

  // the min and max column headers get padded to center them
  cells(2) += array(" ", cols(2)/2)(sum);
  cells(3) += array(" ", cols(3)/2)(sum);

  // blank is rows that are blank -- those that get replaced by lines
  blank = strlen(cells)(max,) == 0;

  // fill in the rows with data or lines
  fmt = swrite(format="%%%ds | %%%ds | %%%ds", cols(1), cols(2), cols(3));
  w = where(!blank);
  rows(w) = swrite(format=fmt, cells(1,w), cells(2,w), cells(3,w));
  w = where(blank);
  rows(w) = swrite(format="%s-+-%s-+-%s", array("-", cols(1))(sum),
    array("-", cols(2))(sum), array("-", cols(3))(sum));

  write, format="%s%s\n", prefix, rows;
}

func lldist(lat0, lon0, lat1, lon1) {
/* DOCUMENT lldist(lat0, lon0, lat1, lon1)
  -or- lldist([lat0, lon0, lat1, lon1])
  Calculates the great circle distance in nautical miles between two points
  given in geographic coordiantes. Input values may be conformable arrays;
  output will have dimensionality to match.

  To convert to kilometers, multiply by 1.852
  To convert to statute miles, multiply by 1.150779
*/
  if(is_void(lon0) && numberof(lat0) == 4) {
    assign, noop(lat0), lat0, lon0, lat1, lon1;
  }
  lat0 *= DEG2RAD;
  lon0 *= DEG2RAD;
  lat1 *= DEG2RAD;
  lon1 *= DEG2RAD;
  // Calculate the central angle between the two points, using the spherical
  // law of cosines
  ca = acos(sin(lat0)*sin(lat1) + cos(lat0)*cos(lat1)*cos(lon0-lon1));
  // Convert the central angle into degrees; then convert degrees into nautical
  // miles. A nautical mile is defined as a minute of arc along a meridian, so
  // we can approximate the conversion by multiplying by 60 (the number of
  // arcminutes in a degree).
  return ca * RAD2DEG * 60;
}
