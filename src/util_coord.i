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

  See also: deg2dm, ddm2deg, deg2ddm, dms2deg, deg2dms
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

  See also: dm2deg, ddm2deg, deg2ddm, dms2deg, deg2dms
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

  See also: dm2deg, deg2dm, deg2ddm, dms2deg, deg2dms
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

  See also: dm2deg, deg2dm, ddm2deg, dms2deg, deg2dms
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

  See also: dm2deg, deg2dm, deg2dms, ddm2deg, deg2ddm
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

  See also: dm2deg, deg2dm, dms2deg, ddm2deg, deg2ddm
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
  Displays the boundars for the given set of coordinates. X and Y must be
  arrays of coordinate values. CS must be the coordinate system. PREFIX
  defaults to " " and is used as a prefix to each output line.
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
