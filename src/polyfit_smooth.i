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

func polyfit_data(data, gridsize=, mode=, buffer=, ndivide=, nrand=,
xy=) {
/* DOCUMENT polyfit_data(data, gridsize=, mode=, buffer=, ndivide=,
   nrand=, xy=)

  This is a smoothing function. It divides the data into grid cells. In each
  grid cell, a 3rd order polynomial is fit to the data. New points are created
  using the polynomial fit, and only those points are returned.

  Parameter:
    data: Data array to be smoothed. (This must have had test_and_clean applied
      already.)

  Options:
    gridsize= Size of grid cells in meters. Data will be divided into grid
      cells of size GRID by GRID meters. Random points will be generated from
      the smoothing polynomial within each grid cell.
        gridsize=15   15 meter by 15 meter grid cells (default)
    buffer= A buffer size in meters to put around each grid cell. These extra
      points are included when deriving the smoothing polynomial.
        buffer=0    No buffer (default)
        buffer=1    Add a 1 meter buffer
    mode= Specified data mode to use.
      mode="fs"     First surface (default)
      mode="ba"     Bathymetry
      mode="be"     Bare earth
    nrand= The number of random points to generate in each cell. If provided,
      ndivide is ignored; otherwise ndivide will determine nrand. This must be
      at least 1.
    ndivide= Factor used to determine the number of random points to be added
      within each grid cell.
        ndivide=8   Default, use a factor of 8
      The area of the cells are divided by ndivide to determine nrand. Exact
      formula used:
        nrand = long(min(2,long(gridsize^2))/ndivide)+1
    xy= Specifies how the x,y coordinates are determined when generating new
      points. Default is xy="uniform".
        xy="uniform"  Points are selected from a uniformally spaced sub-grid
        xy="random"   Points are completely random in the grid cell
        xy="replace"  Replacements use x,y points from original data

  Output:
    Data array of the same type as the original data array.
*/
  if(is_void(data)) return;

  t0 = array(double, 3);
  timer, t0;

  default, mode, "fs";
  default, gridsize, 15;
  default, buffer, 0;
  default, ndivide, 8;
  default, xy, "uniform";

  if(is_integer(mode))
    mode = ["fs","ba","be"](mode);

  // Integer meters area of cells. Must be at least 2, though.
  narea = min(2, long(gridsize^2));
  // Number of random points
  if(is_void(nrand))
    nrand = long(narea/ndivide) + 1;

  strct = structof(data(1));

  data = sortdata(data, mode=mode, method="x");
  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;

  // Calculate grid cell for each point
  xgrid = long(x/gridsize);
  ygrid = long(y/gridsize);

  // Determine buffering extents
  if(buffer) {
    xbuf_lo = long((x-buffer)/gridsize);
    xbuf_hi = long((x+buffer)/gridsize);
    ybuf_lo = long((y-buffer)/gridsize);
    ybuf_hi = long((y+buffer)/gridsize);
  }

  // Figure out how many x-columns we have
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  status, start, msg="Polyfit smooth...";
  if(buffer)
    curxbuf_hi = indgen(numberof(data));

  result = array(pointer, xgrid_count);
  count = 0;
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for this column; abort if we mysteriously have none
    curxmatch = where(xgrid == xgrid_uniq(xgi));
    if(is_void(curxmatch))
      continue;
    if(buffer) {
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

      if(buffer) {
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
      if(!buffer)
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

        if(xy == "replace") {
          if(numberof(indx) > 1)
            indx = indx(sort(random(numberof(indx))));
          w = indx(:min(numberof(indx),nrand));
          xp = x(w);
          yp = y(w);
        } else if(xy == "random") {
          xp = (xgrid_uniq(xgi) + random(nrand)) * gridsize;
          yp = (ygrid_uniq(ygi) + random(nrand)) * gridsize;
        } else {
          // assume uniform
          xp1 = xgrid_uniq(xgi) * gridsize;
          yp1 = ygrid_uniq(ygi) * gridsize;
          xp0 = xp1 + gridsize;
          yp0 = yp1 + gridsize;

          xs = span(xp1, xp0, narea);
          ys = span(yp1, yp0, narea);

          xidx = long(random(nrand)*narea)+1;
          yidx = long(random(nrand)*narea)+1;

          xp = xs(xidx);
          yp = ys(yidx);
        }
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

func polyfit_pbd(file_in, file_out, mode=, gridsize=, buffer=, ndivide=,
nrand=, xy=) {
/* DOCUMENT polyfit_pbd, file_in, file_out, mode=, gridsize=, buffer=,
   ndivide=, nrand=, xy=

   Simple wrapper around polyfit_data. This loads FILE_IN, calls polyfit_data,
   then writes FILE_OUT.
*/
  local vname;
  data = pbd_load(file_in, , vname);
  if(is_void(data)) return;
  data = polyfit_data(data, mode=mode, gridsize=gridsize, buffer=buffer,
    ndivide=ndivide, nrand=nrand, xy=xy);
  if(is_void(data)) return;
  vname += "_pf";
  pbd_save, file_out, vname, data;
}

func batch_polyfit(dir, searchstr=, files=, update=, mode=, gridsize=, buffer=,
ndivide=, nrand=, xy=) {
  default, searchstr, "*.pbd";
  default, update, 0;
  default, mode, "fs";
  default, gridsize, 15;
  default, buffer, 0;
  default, ndivide, 8;
  default, xy, "uniform";

  if(is_void(files))
    files = find(dir, glob=searchstr);

  if(xy == "random")
    suffix = "_pfr_";
  else if(xy == "_replace")
    suffix = "_pfs_";
  else
    suffix = "_pfu_";
  suffix += swrite(format="g%d_b%d_", long(gridsize*100), long(buffer*100));
  if(!is_void(nrand))
    suffix += swrite(format="nr%d", nrand);
  else
    suffix += swrite(format="nd%d", ndivide);

  files_out = file_rootname(files)+suffix+".pbd";

  if(update) {
    w = where(!file_exists(files_out));
    if(!numberof(w)) {
      write, "All files already exist.";
      return;
    }
    files = files(w);
    files_out = files_out(w);
  }

  count = numberof(files);
  for(i = 1; i <= count; i++) {
    polyfit_pbd, files(i), files_out(i), mode=mode, gridsize=gridsize,
      buffer=buffer, ndivide=ndivide, nrand=nrand, xy=xy;
  }
}
