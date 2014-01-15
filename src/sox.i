// vim: set ts=2 sts=2 sw=2 ai sr et:

func sox_load(file) {
/* DOCUMENT data = sox_load("<file>")
  Given the path to a sox log file, this returns the file's lat, lon, and alt
  data as an array. The array will be two dimensional as such:

    [lat, lon, alt]

  Or,
    lat = data(,1)
    lon = data(,2)
    alt = data(,3)
*/
  cols = rdcols(file);
  if(numberof(cols) < 3) error, "invalid sox file";
  lat = *cols(1);
  lon = *cols(2);
  alt = *cols(3);
  if(!is_numerical(lat) || !is_numerical(lon) || !is_numerical(alt))
    error, "invalid sox file";
  return [lat,lon,alt];
}

func sox_plot(data, win=, width=, msize=, color=, type=, sample=) {
/* DOCUMENT sox_plot, "<file>", win=, width=, msize=, color=, type=, sample=
  -OR- sox_plot, data, win=, width=, msize=, color=, type=, sample=

  Given a sox FILE (or an array of DATA loaded from a sox file via sox_load),
  this plots the data for visualization. The plot will have two elements:
    - each point is represented by a small square marker (via plmk)
    - a circle is plotted around each point to show footprint

  Options:
    win= The window to plot in. Defaults to current window.
    width= The line width to use for the circles.
        width=1     Default
        width=0     Disables plotting of circles
    msize= The size of the small square marker.
        msize=0.2   Default
        msize=0     Disables plotting of markers
    color= Specifies a color to use.
    type= Specifies a line type to use for the circles.
        type="dot"  Default
    sample= Specifies the number of samples to use when plotting the circles.
      More samples will result in a smoother circle. Fewer samples will result
      in a more lightweight plot.
        sample=20   Default

  Two externs will impact the function's behavior:
    utm - Controls whether the data is plotted as lat/lon or UTM.
    curzone - Specifies which zone the data is converted to if utm=1.

  Note that if utm=0, the circles will not look like perfect circles. The
  circles are calculated in UTM and then converted to lat/lon, which results in
  some minor distortion.
*/
  extern curzone, utm;
  local north, east, zone, x, y, cx, cy;
  default, width, 1;
  default, msize, 0.2;
  default, type, "dot";
  default, sample, 20;

  if(is_string(data)) data = sox_load(data);

  wbkp = current_window(win);
  window, win;

  lat = data(,1);
  lon = data(,2);
  alt = data(,3);
  count = numberof(lat);

  // Convert to UTM
  ll2utm, lat, lon, north, east, zone, force_zone=curzone;

  // alt is altitude in feet
  // r is radius in meters
  // radius is 0.09125 meters per foot
  r = alt * 0.09125;

  // Determine where circle points will go
  t = (2.0*pi/sample)*indgen(sample);
  cos_t = cos(t);
  sin_t = sin(t);
  tx = ty = array(double, count, sample);
  for(i = 1; i <= count; i++) {
    tx(i,) = east(i) + r(i) * sin_t;
    ty(i,) = north(i) + r(i) * cos_t;
  }

  // Convert to lat/lon if needed
  if(utm) {
    x = east;
    y = north;
    cx = tx;
    cy = ty;
  } else {
    utm2ll, north, east, zone, x, y;
    utm2ll, ty, tx, zone, cx, cy;
  }

  // Plot circles
  if(width) {
    for(i = 1; i <= count; i++) {
      plg, cy(i,), cx(i,), width=width, color=color, type=type, marks=0, closed=1;
    }
  }

  if(msize) {
    plmk, y, x, msize=msize, color=color, marker=1;
  }

  window_select, wbkp;
}
