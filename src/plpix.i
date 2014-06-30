// vim: set ts=2 sts=2 sw=2 ai sr et:

func plpix(data, mode=, cmin=, cmax=, win=, square=) {
/* DOCUMENT plpix, data, mode=, cmin=, cmax=, win=, square=

  This pixel-plots the given data. The algorithm looks at the current limits
  and viewport to calculate the spatial dimensions of the current view as well
  as the pixel dimensions of the current view. The data is rasterized into a
  grid where each grid cell matches a screen pixel. That grid is then plotted.

  This function automatically issues an FMA as a core part of how it operates.
  If you must plot this with other items, make sure you plot this first.

  After zooming or panning, you can reissue this command to refresh your plot
  to match the new view.

  This function gives a similar plot as plcm. However, it will usually run
  orders of magnitude faster. It also allows for much faster zooming and
  panning, though you will need to re-run the command once you settle on a view
  you wish to look at. Even still, it is faster than waiting for a plcm plot to
  refresh. It also repaints very quickly if you cover and uncover the window,
  unlike plcm plots.
*/
  default, win, max(0, current_window());
  default, square, 1;

  wbkp = current_window();
  window, win;
  pltitle, "working...";
  limits, square=square;
  pause, 0;

  // Determine the dimensions in pixels of the viewport.
  vp = viewport();
  pixel = window_geometry()(2);
  xpx = long(0.5 + (vp(2) - vp(1))/pixel);
  ypx = long(0.5 + (vp(4) - vp(3))/pixel);

  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;

  xminall = x(min);
  xmaxall = x(max);
  yminall = y(min);
  ymaxall = y(max);

  // Calculate the spatial extent of the plot
  lims = limits();
  flags = long(lims(5));
  xmin = (flags & 0x01) ? xminall : lims(1);
  xmax = (flags & 0x02) ? xmaxall : lims(2);
  ymin = (flags & 0x04) ? yminall : lims(3);
  ymax = (flags & 0x08) ? ymaxall : lims(4);

  // If square=1 and any of the directions are set to use their extreme values,
  // then we need to recalculate the spatial extent to maintain the square=1
  // property and avoid distorting the gridded data.
  if((flags & 0x040) && (flags & 0x0f)) {
    fma;
    pltitle, "working...";
    plg, [ymin, ymax], [xmin, xmax], hide=0;
    limits;
    lims = limits();
    //pause, 0;
    pledit, numberof(plq()), hide=1;
    pause, 0;
    xmin = lims(1);
    xmax = lims(2);
    ymin = lims(3);
    ymax = lims(4);
  }

  // Throw out unneeded points.

  w = data_box(x, y, xmin, xmax, ymin, ymax);
  if(is_void(w)) goto ERR;
  x = x(w);
  y = y(w);
  z = z(w);

  if(!is_void(cmin)) {
    w = where(cmin <= z);
    if(is_void(w)) goto ERR;
    x = x(w);
    y = y(w);
    z = z(w);
  }

  if(!is_void(cmax)) {
    w = where(z <= cmax);
    if(is_void(w)) goto ERR;
    x = x(w);
    y = y(w);
    z = z(w);
  }

  // Convert spatial x/y values into pixel cell x/y values
  xcell = (xmax - xmin) / xpx;
  ycell = (ymax - ymin) / ypx;
  if(xcell < 0.01 || ycell < 0.01) {
    write, "WARNING: pixel size larger than 1cm";
  }
  xx = min(long((x-xmin)/xcell + 1), xpx);
  yy = min(long((y-ymin)/ycell + 1), ypx);

  // Resolve z values for pixel cells
  nodata = double(long(z(min) - 100));
  zg = array(nodata, xpx, ypx);
  idx = (yy-1) * xpx + xx;
  zg(idx) = z;

  // Set up the grid information for plf
  dims = [2, xpx+1, ypx+1];
  xg = array(0, dims) + span(xmin, xmax, xpx+1)(,-);
  yg = array(0, dims) + span(ymin, ymax, ypx+1)(-,);
  ireg = array(0, dims);
  ireg(2:,2:) = zg != nodata;

  fma;
  plf, zg, yg, xg, ireg, cmin=cmin, cmax=cmax;

  window_select, wbkp;
  return;

ERR:
  fma;
  pltitle, "no data in view";
  window_select, wbkp;
}
