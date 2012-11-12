// vim: set ts=2 sts=2 sw=2 ai sr et:

func poly2_fit_safe(y, x1, x2, m, w) {
/* DOCUMENT poly2_fit_safe(y, x1, x2, m)
  poly2_fit_safe(y, x1, x2, m, w)

  This is a simple wrapper around poly2_fit. If an interpreted error occurs
  during poly2_fit (as throw by the 'error' statement), a void result will be
  returned instead of stopping for the error. This is intended to address the
  scenario where an error arises when data points resolve into a singular
  matrix.
*/
  if(catch(0x10)) {
    return [];
  }
  return poly2_fit(y, x1, x2, m, w);
}

func polyfit_eaarl_pts(data, wslide=, mode=, wbuf=, ndivide=) {
/* DOCUMENT polyfit_eaarl_pts(data, wslide=, mode=, wbuf=, ndivide=)

  This function creates a 3rd order magnitude polynomial fit within the give
  data region and introduces random points within the selected region based on
  the polynomial surface. The points within the region are replaced by these
  random points. The entire input data is considered for smoothing. A window
  (size wslide x wslide) slides through the data array, and all points within
  the window + buffer (wbuf) are considered for deriving the surface.

  Parameter:
    data: Data array to be smoothed. (This must have had test_and_clean applied
      already.)

  Options:
    wslide = window size in cm that slides through the data array
    mode =
      mode = "fs"; //for first surface
      mode = "ba"; //for bathymetry (default)
      mode = "be"; //for bare earth vegetation
    wbuf = buffer distance (cm) around the selected region.  Default = 0
    ndivide= factor used to determine the number of random points to be added
      within each grid cell.  ( total area of the selected region is divided
      by ndivide). Default = 8;

  Output:
    Data array of the same type as the original data array.
*/
// Original 2005-08-05 Amar Nayegandhi
  if(is_void(data)) return;

  t0 = array(double, 3);
  timer, t0;

  default, mode, "ba";
  default, wslide, 1500;
  default, wbuf, 0;
  default, ndivide, 8;

  if(is_integer(mode))
    mode = ["fs","ba","be"](mode);

  // Convert to meters
  wslide /= 100.;
  if(wbuf)
    wbuf /= 100.;

  // Integer meters area of cells. Must be at least 2, though.
  narea = min(2, long(wslide^2));
  // Number of random points
  nrand = long(narea/ndivide) + 1;

  strct = structof(data(1));

  data = sortdata(data, mode=mode, method="x");
  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;

  // Calculate grid cell for each point
  xgrid = long(x/wslide);
  ygrid = long(y/wslide);

  // Determine buffering extents
  if(wbuf) {
    xbuf_lo = long((x-wbuf)/wslide);
    xbuf_hi = long((x+wbuf)/wslide);
    ybuf_lo = long((y-wbuf)/wslide);
    ybuf_hi = long((y+wbuf)/wslide);
  }

  // Figure out how many x-columns we have
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  status, start, msg="Polyfit smooth...";
  if(wbuf)
    curxbuf_hi = indgen(numberof(data));

  result = array(pointer, xgrid_count);
  count = 0;
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for this column; abort if we mysteriously have none
    curxmatch = where(xgrid == xgrid_uniq(xgi));
    if(is_void(curxmatch))
      continue;
    if(wbuf) {
      // curxbuf_hi for each iteration will contain all the points for all
      // further iterations, but removes some of the points from previous
      // iterations. Thus an efficiency boost is gained by trimming it down at
      // each step rather than fully recalculating.
      w = where(xgrid_uniq(xgi) <= xbuf_hi(curxbuf_hi));
      // This should never happen...
      if(!numberof(w))
        break;
      curxbuf_hi = curxbuf_hi(w);

      // For current cell, also need to constrain with xbuf_lo
      w = where(xbuf_lo(curxbuf_hi) <= xgrid_uniq(xgi));
      if(!numberof(w))
        continue;

      // Whatever remains is what we'll use to start constraining for ybuf.
      curybuf_hi = curxbuf_hi(w);
    }

    // Figure out how many y-rows we have
    ygrid_uniq = set_remove_duplicates(ygrid(curxmatch));
    ygrid_count = numberof(ygrid_uniq);

    // Iterate over rows
    xresult = array(pointer, ygrid_count);
    for(ygi = 1; ygi <= ygrid_count; ygi++) {
      // Extract indices for row+col; abort if we mysteriously have none
      curymatch = where(ygrid(curxmatch) == ygrid_uniq(ygi));
      if(is_void(curymatch))
        continue;
      indx = curxmatch(curymatch);

      if(wbuf) {
        // curybuf_hi works much like curxbuf_hi
        w = where(ygrid_uniq(ygi) <= ybuf_hi(curybuf_hi));
        // This should never happen...
        if(!numberof(w))
          continue;
        curybuf_hi = curybuf_hi(w);

        // For current cell, also need to constrain with ybuf_lo
        w = where(ybuf_lo(curybuf_hi) <= ygrid_uniq(ygi));
        if(!numberof(w))
          continue;

        // Whatever remains is what we'll use for the current cell
        curbuf = curybuf_hi(w);
      }

      // indx are the points in this cell (without buffer)
      // curbuf are the points that are within the buffer region for this cell

      // If not using a buffer region, then both are the same
      if(!wbuf)
        curbuf = indx;

      // A two-dimensional fit requires at least 3 points to avoid crazy
      // results.
      if(numberof(curbuf) > 3) {
        // z bounds of points in buffer
        zmin = z(curbuf)(min);
        zmax = z(curbuf)(max);
        // Find two-dimensional polynomial fit using order 3
        c = poly2_fit_safe(z(curbuf), x(curbuf), y(curbuf), 3);
        // The poly2_fit function does not always work; poly2_fit_safe returns
        // [] when it fails. In these cases, we just skip the current cell. Not
        // much else we can do.
        if(is_void(c)) {
          continue;
        }

        // define a random set of points in that area selected to apply
        // this fit
        xp1 = xgrid_uniq(xgi) * wslide;
        yp1 = ygrid_uniq(ygi) * wslide;
        xp0 = xp1 + wslide;
        yp0 = yp1 + wslide;

        xs = span(xp1, xp0, narea);
        ys = span(yp1, yp0, narea);

        xidx = long(random(nrand)*narea)+1;
        yidx = long(random(nrand)*narea)+1;

        xp = xs(xidx);
        yp = ys(yidx);
        zp = poly2(xp, yp, c);

        w = where(zp >= zmin & zp <= zmax);
        if(!numberof(w)) {
          continue;
        }
        xp = xp(w);
        yp = yp(w);
        zp = zp(w);

        npts = numberof(xp);
        new_pts = array(strct, npts);

        if(mode != "fs")
          new_pts = xyz2data(xp, yp, zp, new_pts, mode=mode);
        new_pts = xyz2data(xp, yp, zp, new_pts, mode="fs");

        new_pts.rn = new_pts.soe = indgen(count+1:count+npts);
        count += npts;

        xresult(ygi) = &new_pts;
      }
      status, progress, xgi - 1 + double(ygi)/ygrid_count, xgrid_count;
      indx = curbuf = curymatch = [];
    }
    result(xgi) = &merge_pointers(xresult);
  }
  result = merge_pointers(result);
  status, finished;

  // Fake out mirror coordinates (assume AGL to be 300m)
  if(numberof(result)) {
    result.meast = result.east;
    result.mnorth = result.north;
    result.melevation = result.elevation + 30000;
  }

  timer_finished, t0;
  return result;
}
