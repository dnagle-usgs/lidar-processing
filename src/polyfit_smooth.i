// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

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

func polyfit_xyz_xyz(x, y, z, grid=, buf=, n=, degree=, constrain=) {
/* DOCUMENT polyfit_xyz_xyz(x, y, z, grid=, buf=, n=, degree=, constrain=)
  Given a set of XYZ points, this will return a new set of XYZ points where
  each XY point in the original is polyfit within a grid cell to determine a
  new Z value.

  See polyfit_data for more details.
*/
  default, grid, 2.5;
  default, buf, 1;
  default, n, 3;
  default, degree, 3;
  default, constrain, 0;

  grid = double(grid);

  // Calculate grid points
  xgrid = long(x/grid);
  ygrid = long(y/grid);

  // Make a copy of z for output
  zfit = noop(z);

  // Figure out the x-columns
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  // iterate over x-columns
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for x grid and bufding
    xg = xgrid_uniq(xgi);
    curx_grid = where(xgrid == xg);
    if(buf)
      curx_buf = where(xg-buf <= xgrid & xgrid <= xg+buf);
    else
      curx_buf = curx_grid;

    // Extract values to avoid having to repeatedly index into data
    ygrid_xg = ygrid(curx_grid);
    ygrid_xb = ygrid(curx_buf);

    // Figure out the y-rows
    ygrid_uniq = set_remove_duplicates(ygrid_xg);
    ygrid_count = numberof(ygrid_uniq);

    // iterate over y-rows
    for(ygi = 1; ygi <= ygrid_count; ygi++) {
      // Extract indices for y grid and bufding
      yg = ygrid_uniq(ygi);
      cury_grid = where(ygrid_xg == yg);
      if(buf)
        cury_buf = where(yg-buf <= ygrid_xb & ygrid_xb <= yg+buf);
      else
        cury_buf = cury_grid;

      // resolve indices
      idx_grid = curx_grid(cury_grid);
      idx_buf = curx_buf(cury_buf);

      // Ensure we have threshhold points
      if(numberof(idx_buf) < n)
        continue;

      // Polyfit
      c = poly2_fit_safe(z(idx_buf), x(idx_buf), y(idx_buf), degree);
      if(is_void(c))
        continue;
      zfit(idx_grid) = poly2(x(idx_grid), y(idx_grid), c);

      if(constrain) {
        if(constrain == 1) {
          zmin = z(idx_grid)(min);
          zmax = z(idx_grid)(max);
        } else if(constrain == 2) {
          zmin = z(idx_buf)(min);
          zmax = z(idx_buf)(max);
        } else {
          error, "Invalid constrain= value.";
        }
        w = where(zfit(idx_grid) < zmin | zfit(idx_grid) > zmax);
        if(numberof(w)) {
          zfit(idx_grid(w)) = z(idx_grid)(w);
        }
      }
    }
  }

  return [x,y,zfit];
}

func polyfit_xyz_rnd(x, y, z, grid=, buf=, n=, degree=, constrain=, pts=) {
/* DOCUMENT polyfit_xyz_rnd(x, y, z, grid=, buf=, n=, degree=, constrain=,
  pts=)

  Given a set of XYZ points, this will return a new set of XYZ points that are
  randomly distributed in each grid square, with elevations poly-fit to the
  input points.

  See polyfit_data for more details.
*/
  default, grid, 2.5;
  default, buf, 1;
  default, n, 3;
  default, degree, 3;
  default, constrain, 0;
  default, pts, 2;

  grid = double(grid);

  // Calculate grid points
  xgrid = long(x/grid);
  ygrid = long(y/grid);

  // Figure out the x-columns
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  // Temporary storage for x results
  xtmp = array(pointer, xgrid_count, 3);

  // iterate over x-columns
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for x grid and bufding
    xg = xgrid_uniq(xgi);
    curx_grid = where(xgrid == xg);
    if(buf)
      curx_buf = where(xg-buf <= xgrid & xgrid <= xg+buf);
    else
      curx_buf = curx_grid;

    // Extract values to avoid having to repeatedly index into data
    ygrid_xg = ygrid(curx_grid);
    ygrid_xb = ygrid(curx_buf);

    // Figure out the y-rows
    ygrid_uniq = set_remove_duplicates(ygrid_xg);
    ygrid_count = numberof(ygrid_uniq);

    // Temporary storage for y results
    ytmp = array(pointer, ygrid_count, 3);

    // iterate over y-rows
    for(ygi = 1; ygi <= ygrid_count; ygi++) {
      // Extract indices for y grid and bufding
      yg = ygrid_uniq(ygi);
      cury_grid = where(ygrid_xg == yg);
      if(buf)
        cury_buf = where(yg-buf <= ygrid_xb & ygrid_xb <= yg+buf);
      else
        cury_buf = cury_grid;

      // resolve indices
      idx_buf = curx_buf(cury_buf);

      // Ensure we have threshhold points
      if(numberof(idx_buf) < n)
        continue;

      // Generate random points
      rx = (xg + random(pts)) * grid;
      ry = (yg + random(pts)) * grid;

      // Polyfit
      c = poly2_fit_safe(z(idx_buf), x(idx_buf), y(idx_buf), degree);
      if(is_void(c))
        continue;
      rz = poly2(rx, ry, c);

      if(constrain) {
        if(constrain == 1) {
          idx_grid = curx_grid(cury_grid);
          zmin = z(idx_grid)(min);
          zmax = z(idx_grid)(max);
        } else if(constrain == 2) {
          zmin = z(idx_buf)(min);
          zmax = z(idx_buf)(max);
        } else {
          error, "Invalid constrain= value.";
        }
        w = where(zmin <= rz & rz <= zmax);
        if(!numberof(w)) {
          rx = ry = rz = [];
          continue;
        }
        rx = rx(w);
        ry = ry(w);
        rz = rz(w);
      }

      ytmp(ygi,1) = &rx;
      ytmp(ygi,2) = &ry;
      ytmp(ygi,3) = &rz;
      rx = ry = rz = [];
    }

    // Coalesce y results and put in temporary x storage
    xtmp(xgi,1) = &merge_pointers(ytmp(,1));
    xtmp(xgi,2) = &merge_pointers(ytmp(,2));
    xtmp(xgi,3) = &merge_pointers(ytmp(,3));
    ytmp = [];
  }

  // Coalesce x results
  rx = merge_pointers(xtmp(,1));
  ry = merge_pointers(xtmp(,2));
  rz = merge_pointers(xtmp(,3));
  xtmp = [];

  return [rx,ry,rz];
}

func polyfit_xyz_grd(x, y, z, grid=, buf=, n=, degree=, constrain=, pts=) {
/* DOCUMENT polyfit_xyz_grd(x, y, z, grid=, buf=, n=, degree=, pts=)
  Given a set of XYZ points, this will return a new set of XYZ points that are
  distributed in a regular grid in each grid square, with elevations poly-fit
  to the input points.

  See polyfit_data for more details.
*/
  default, grid, 250;
  default, buf, 1;
  default, n, 3;
  default, degree, 3;
  default, constrain, 0;
  default, pts, 2;

  grid = double(grid);

  // Calculate grid points
  xgrid = long(x/grid);
  ygrid = long(y/grid);

  // Figure out the x-columns
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  // Temporary storage for x results
  xtmp = array(pointer, xgrid_count, 3);

  // Determine offsets to add to each grid cell to generate points
  tmp = 1./pts/2.;
  off = span(tmp, 1-tmp, pts);
  xoff = array(off, pts)(*);
  yoff = transpose(array(off, pts))(*);
  tmp = off = [];

  // iterate over x-columns
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for x grid and bufding
    xg = xgrid_uniq(xgi);
    curx_grid = where(xgrid == xg);
    if(buf)
      curx_buf = where(xg-buf <= xgrid & xgrid <= xg+buf);
    else
      curx_buf = curx_grid;

    // Extract values to avoid having to repeatedly index into data
    ygrid_xg = ygrid(curx_grid);
    ygrid_xb = ygrid(curx_buf);

    // Figure out the y-rows
    ygrid_uniq = set_remove_duplicates(ygrid_xg);
    ygrid_count = numberof(ygrid_uniq);

    // Temporary storage for y results
    ytmp = array(pointer, ygrid_count, 3);

    // iterate over y-rows
    for(ygi = 1; ygi <= ygrid_count; ygi++) {
      // Extract indices for y grid and bufding
      yg = ygrid_uniq(ygi);
      cury_grid = where(ygrid_xg == yg);
      if(buf)
        cury_buf = where(yg-buf <= ygrid_xb & ygrid_xb <= yg+buf);
      else
        cury_buf = cury_grid;

      // resolve indices
      idx_buf = curx_buf(cury_buf);

      // Ensure we have threshhold points
      if(numberof(idx_buf) < n)
        continue;

      // Generate random points
      gx = (xg + xoff) * grid;
      gy = (yg + yoff) * grid;

      // Polyfit
      c = poly2_fit_safe(z(idx_buf), x(idx_buf), y(idx_buf), degree);
      if(is_void(c))
        continue;
      gz = poly2(gx, gy, c);

      if(constrain) {
        if(constrain == 1) {
          idx_grid = curx_grid(cury_grid);
          zmin = z(idx_grid)(min);
          zmax = z(idx_grid)(max);
        } else if(constrain == 2) {
          zmin = z(idx_buf)(min);
          zmax = z(idx_buf)(max);
        } else {
          error, "Invalid constrain= value.";
        }
        w = where(zmin <= gz & gz <= zmax);
        if(!numberof(w)) {
          gx = gy = gz = [];
          continue;
        }
        gx = gx(w);
        gy = gy(w);
        gz = gz(w);
      }

      ytmp(ygi,1) = &gx;
      ytmp(ygi,2) = &gy;
      ytmp(ygi,3) = &gz;
      gx = gy = gz = [];
    }

    // Coalesce y results and put in temporary x storage
    xtmp(xgi,1) = &merge_pointers(ytmp(,1));
    xtmp(xgi,2) = &merge_pointers(ytmp(,2));
    xtmp(xgi,3) = &merge_pointers(ytmp(,3));
    ytmp = [];
  }

  // Coalesce x results
  gx = merge_pointers(xtmp(,1));
  gy = merge_pointers(xtmp(,2));
  gz = merge_pointers(xtmp(,3));
  xtmp = [];

  return [gx,gy,gz];
}

func polyfit_data(data, mode=, method=, grid=, buf=, n=, degree=, constrain=,
pts=) {
/* DOCUMENT polyfit_data(data, mode=, method=, grid=, buf=, n=, degree=,
  constrain=, pts)

  Given ALPS data, this will return a new set of ALPS data that have had a
  polyfit algorithm applied.

  See batch_polyfit_data for more details.
*/
  default, mode, "fs";
  default, method, "xyz";
  default, grid, 2.5;
  default, buf, 1;
  default, n, 3;
  default, degree, 3;
  default, constrain, 0;
  default, pts, 2;

  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;

  if(method == "xyz") {
    fit = polyfit_xyz_xyz(x, y, z, grid=grid, buf=buf, n=n, degree=degree,
      constrain=constrain);
    if(is_numerical(data))
      return fit;
    return xyz2data(fit, data, mode=mode);
  }

  if(method == "random")
    fnc = polyfit_xyz_rnd;
  else if(method == "grid")
    fnc = polyfit_xyz_grd;
  else
    error, "Unknown method=.";

  fit = fnc(x, y, z, grid=grid, buf=buf, n=n, degree=degree,
    constrain=constrain, pts=pts);

  if(is_numerical(data))
    return fit;
  return xyz2data(fit, structof(data), mode=mode);
}

func batch_polyfit_data(dir, outdir=, files=, searchstr=, update=, mode=,
method=, grid=, buf=, n=, degree=, constrain=, pts=, verbose=) {
/* DOCUMENT batch_polyfit_data, dir, outdir=, files=, searchstr=, update=,
  mode=, method=, grid=, buf=, n=, degree=, constrain=, pts=, verbose=

  Runs in batch mode over a set of files and apply a polyfit algorithm to
  each.

  Parameter:
    dir: The directory in which to find files to polyfit.

  Options:
    outdir= Output directory for files. If omitted, they are created
      alongside the originals.
    files= Specifies an array of files to convert. If provided, "dir" is
      ignored.
    searchstr= A search string specifying the files to convert. Ignored if
      "files=" specified.
        searchstr="*.pbd"    Default
    update= Specifies whether to skip existing output files.
        update=0    Replace existing files (default)
        update=1    Skip existing files
    mode= Data mode to run in.
        mode="fs"   Default
        mode="be"
        mode="ba"
    method= Polyfit algorithm to use.
        method="xyz"   In-place polyfit using x,y of original data, default
        method="grid"  Polyfit to a regularly spaced grid of points
        method="random"   Randomly select locations to polyfit
    grid= A size in meters specifying what size grid cells to put on the
      data. The polyfitting will operate on points within each of these grid
      cells.
        grid=2.5    2.5 meters, default
    buf= An integer specifying how many adjacent grid cells should be used
      for the polyfit model calculation. If buf=1, then 1 additional layer
      of grid cells is used, meaning that a 2.5m x 2.5m grid cell will have
      its poly model determined based on the surrounding 7.5m x 7.5m region
      (3x3 cells). This must be a non-negative integer.
        buf=1    1 layer of buffer cells, default
        buf=0    No buffer cells
    n= The number of points that must be present within the buffer region in
      order to construct a poly model. If fewer points are found, no poly
      models is created. For method="xyz", the original point will be left
      unmodified. For method="grid" and method="random", that grid cell will
      receive no points.
        n=3      3 points, default
    degree= The degree of the 2D polynomial to fit.
        degree=3    Fit a cubic polynomial (default)
        degree=2    Fit a quadratic polynomial
        degree=4    Fit a quartic polynomial
        degree=1    Fit a linear polynomial
    constrain= Specifies whether the points for a grid cell should be
      constrained to the grid cell's original elevation bounds. This has
      slightly different effects depending on method. For method="xyz", any
      points that would get fit outside of the bounds will simply be left at
      their original value. For method="random" and method="grid", any
      points that would get fit outside of the bounds will be discarded.
      Using constrain=1 will constrain to the elevations found within just
      the grid cell itself whereas constrain=2 will constrain to the bounds
      of the whole buffer. (So constrain=2 is more relaxed than
      constrain=1.)
        constrain=0    Do not constrain to grid elevation bounds, default
        constrain=1    Constrain to grid cell elevation bounds
        constrain=2    Constrain to buffer area elevation bounds
    pts= Parameter that specifies how many points to add. For method="xyz",
      this parameter is ignored. For method="random", this many points are
      added for each grid cell. For method="grid", a grid of PTS x PTS will
      be added for each grid cell (so the number of points added is the
      square of PTS).
        pts=2    Default. 2 random points, or a 2x2 grid of points.
    verbose= Specifies whether to give progress output.
        verbose=1   Display progress, default
        verbose=0   Be quiet

  Output files:
    The output files are named in a way that reflects the parameters used.
    Examples below are based on a file with an original name of ORIGINAL.pbd.

    For method="xyz", output files will have a name like this:
      ORIGINAL_pfz_g250_b1_n3_d3_c0.pbd
    This means:
      pfz - Poly Fit using xyZ method
      g250 - 2.50m grid cell
      b1 - 1 buffer layer
      n3 - 3 points minimum for polyfit
      d3 - polynomial of degree 3
      c0 - points were not constrained

    For method="random", output files will have a name like this:
      ORIGINAL_pfr_g250_b1_n3_d3_p2_c0.pbd
    This means:
      pfr - Poly Fit using Random method
      g250 - 2.50m grid cell
      b1 - 1 buffer layer
      n3 - 3 points minimum for polyfit
      d3 - polynomial of degree 3
      p2 - 2 points created per grid cell
      c0 - points were not constrained

    For method="grid", output files will have a name like this:
      ORIGINAL_pfg_g250_b1_n3_d3_p2_c0.pbd
    This means:
      pfg - Poly Fit using Grid method
      g250 - 2.50m grid cell
      b1 - 1 buffer layer
      n3 - 3 points minimum for polyfit
      d3 - polynomial of degree 3
      p2 - 2x2 points created per grid cell
      c0 - points were not constrained

    The letters match to parameters as:
      g - grid=
      b - buf=
      n - n=
      d - degree=
      p - pts=
      c - constrain=

    Variable names will have a simple suffix added:
      VNAME_pfz  for method="xyz"
      VNAME_pfr  for method="random"
      VNAME_pfg  for method="grid"
*/
  default, searchstr, "*.pbd";
  default, mode, "fs";
  default, method, "xyz";
  default, grid, 2.5;
  default, buf, 1;
  default, n, 3;
  default, degree, 3;
  default, pts, 2;
  default, constrain, 0;
  default, verbose, 1;

  if(is_void(files))
    files = find(dir, glob=searchstr);

  outfiles = file_rootname(files);
  if(!is_void(outdir))
    outfiles = file_join(outdir, file_tail(outfiles));
  if(method == "xyz") {
    outfiles += swrite(format="_pfz_g%d_b%d_n%d_d%d_c%d.pbd",
      long(grid*100+.5), long(buf), long(n), long(degree), long(constrain));
    suffix = "_pfz";
  } else {
    if(method == "random")
      pf = "r";
    else if(method == "grid")
      pf = "g";
    else
      error, "Unknown method";
    outfiles += swrite(format="_pf%s_g%d_b%d_n%d_d%d_p%d_c%d.pbd", pf,
      long(grid*100+.5), long(buf), long(n), long(degree), long(pts),
      long(constrain));
    suffix = "_pf" + pf;
  }

  if(update) {
    exists = file_exists(outfiles);
    if(allof(exists)) {
      if(verbose)
        write, "All output files exist, aborting.";
      return;
    }
    if(anyof(exists)) {
      if(verbose)
        write, format=" Skipping %d files that already exist\n",
          numberof(where(exists));
      w = where(!exists);
      files = files(w);
      outfiles = outfiles(w);
      w = [];
    }
  }

  if(numberof(files) > 1)
    sizes = double(file_size(files))(cum)(2:);
  else
    sizes = file_size(files);

  local data, vname;
  t0 = tp = array(double, 3);
  timer, t0;

  for(i = 1; i <= numberof(files); i++) {
    data = pbd_load(files(i), , vname);

    if(!numberof(data)) {
      if(verbose)
        write, format=" Skipping %s, contained no data...\n",
          file_tail(files(i));
      continue;
    }

    data = polyfit_data(unref(data), mode=mode, method=method, grid=grid,
      buf=buf, n=n, degree=degree, pts=pts, constrain=constrain);

    if(!numberof(data)) {
      if(verbose)
        write, format=" Skipping %d, poly fit removed all data...\n",
          file_tail(files(i));
      continue;
    }

    vname += suffix;
    pbd_save, outfiles(i), vname, data;

    if(verbose)
      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
  }

  if(verbose)
    timer_finished, t0;
}

func polyfit_eaarl_pts(eaarl, wslide=, mode=, boxlist=, wbuf=, gridmode=,
ndivide=) {
/* DOCUMENT polyfit_eaarl_pts(eaarl, wslide=, mode=, boxlist=, wbuf=,
  gridmode=, ndivide=)

  This function creates a 3rd order magnitude polynomial fit within the give
  data region and introduces random points within the selected region based on
  the polynomial surface. The points within the region are replaced by these
  random points.  The region can be defined in an array (boxlist=), or if
  gridmode is set to 1, the entire input data is considered for smoothing.  A
  window (size wslide x wslide) slides through the data array, and all points
  within the window + buffer (wbuf) are considered for deriving the surface.

  Parameter:
    eaarl: data array to be smoothed.

  Options:
    wslide = window size that slides through the data array.
    mode =
      mode = 1; //for first surface
      mode = 2; //for bathymetry (default)
      mode = 3; // for bare earth vegetation
    gridmode= set to 1 to work in a grid mode. All data will be fitted to a
      polynomial within the defined wslide range and buffer distance (wbuf).
    boxlist = list of regions (x,y bounding box) where the poly fit function
      is to be applied.  All data within that region will be removed, and
      fitted with data within some wbuf buffer distance.
    wbuf = buffer distance (cm) around the selected region.  Default = 0
    ndivide= factor used to determine the number of random points to be added
      within each grid cell.  ( total area of the selected region is divided
      by ndivide). Default = 8;

  Output:
    Data array of the same type as the 'eaarl' data array.
*/
// Original 2005-08-05 Amar Nayegandhi
  default, mode, 2;
  default, gridmode, 1;
  default, wbuf, 0;
  default, ndivide, 8;

  tmr1 = tmr2 = array(double, 3);
  timer, tmr1;

  eaarl = test_and_clean(eaarl);

  a = structof(eaarl(1));
  new_eaarl = array(a, numberof(eaarl) );
  count = 0;
  new_count = numberof(eaarl);

  if (!is_array(eaarl)) return;

  indx = [];
  if (mode == 3) {
    eaarl = eaarl(sort(eaarl.least)); // for bare_earth
  } else {
    eaarl = eaarl(sort(eaarl.east)); // for first surface and bathy
  }

  eaarl_orig = eaarl;

  // define a bounding box
  bbox = array(float, 4);
  if (mode != 3) {
    bbox(1) = min(eaarl.east);
    bbox(2) = max(eaarl.east);
    bbox(3) = min(eaarl.north);
    bbox(4) = max(eaarl.north);
  } else {
    bbox(1) = min(eaarl.least);
    bbox(2) = max(eaarl.least);
    bbox(3) = min(eaarl.lnorth);
    bbox(4) = max(eaarl.lnorth);
  }

  if (!wslide) wslide = 1500; //in centimeters

  //now make a grid in the bbox
  if (gridmode) {
    ngridx = int(ceil((bbox(2)-bbox(1))/wslide));
  } else {
    // number of regions where poly fit will be needed.
    ngridx = numberof(boxlist(,1));
  }
  ngridy = int(ceil((bbox(4)-bbox(3))/wslide));

  if (gridmode) {
    if (ngridx > 1) {
      xgrid = bbox(1)+span(0, wslide*(ngridx-1), ngridx);
    } else {
      xgrid = [bbox(1)];
    }
  }

  if (ngridy > 1) {
    ygrid = bbox(3)+span(0, wslide*(ngridy-1), ngridy);
  } else {
    ygrid = [bbox(3)];
  }

  if ( _ytk && (ngridy>1)) {
    tkcmd,"destroy .polyfit; toplevel .polyfit; set progress 0;"
    tkcmd,swrite(format="ProgressBar .polyfit.pb \
      -fg blue \
      -troughcolor white \
      -relief raised \
      -maximum %d \
      -variable progress \
      -height 30 \
      -width 400", int(ngridy));
    tkcmd,"pack .polyfit.pb; update; center_win .polyfit;"
  }

  //timer, t0

  origdata = [];
  if (!gridmode) {
    maxblistall = max(max(boxlist(*,2),boxlist(*,4)));
    minblistall = min(min(boxlist(,2),boxlist(,4)));
  }
  for (i = 1; i <= ngridy; i++) {
    if (!gridmode) {
      // check to see if ygrid is within the boxlist region
      yi = ygrid(i)/100.;
      yib = (ygrid(i) + wslide)/100.;
      if ((yi > maxblistall) || (yi < minblistall) || (yib > maxblistall) || (yib < minblistall)) continue;
    }
    q = [];
    if (mode == 3) {
      q = where(eaarl.lnorth >= ygrid(i)-wbuf);
      if (is_array(q)) {
        qq = where(eaarl.lnorth(q) <= ygrid(i)+wslide+wbuf);
        if (is_array(qq)) {
          q = q(qq);
        } else q = []
      }
    } else {
      q = where (eaarl.north >= ygrid(i)-wbuf);
      if (is_array(q)) {
        qq = where(eaarl.north(q) <= ygrid(i)+wslide+wbuf);
        if (is_array(qq)){
          q = q(qq);
        } else q = [];
      }
    }
    if (!(is_array(q))) continue;

    for (j = 1; j <= ngridx; j++) {
      if (!gridmode) {
        // check to see if ygrid is within the boxlist region
        maxblist = max(boxlist(j,2),boxlist(j,4));
        minblist = min(boxlist(j,2),boxlist(j,4));
        if ((yi > maxblist) || (yi < minblist) || (yib > maxblist) || (yib < minblist)) continue;
      }
      //define the extent of the strip to fit
      m = array(double, 4); // in meters
      if (!gridmode) {
        m(1) = min(boxlist(j,1),boxlist(j,3))-wbuf/100.;
        m(3) = max(boxlist(j,1),boxlist(j,3))+wbuf/100.;
      } else {
        m(1) = (xgrid(j)-wbuf)/100.;
        m(3) = (xgrid(j) + wslide+wbuf)/100.;
      }
      m(2) = ygrid(i)/100.;
      m(4) = (ygrid(i) + wslide)/100.;
      indx = [];
      if (is_array(q)) {
        if (mode == 3) {
          indx = where(eaarl.least(q) >= m(1)*100.);
          if (is_array(indx)) {
            iindx = where(eaarl.least(q)(indx) <= m(3)*100.);
            if (is_array(iindx)) {
              indx = indx(iindx);
              indx = q(indx);
            } else indx = [];
          }
        } else {
          indx = where(eaarl.east(q) >= m(1)*100);
          if (is_array(indx)) {
            iindx = where(eaarl.east(q)(indx) <= m(3)*100);
            if (is_array(iindx)) {
              indx = indx(iindx);
              indx = q(indx);
            } else indx = [];
          }
        }
      }
      if (numberof(indx) > 3) {
      // this is the data inside the box
      // tag these points in the original data array, so that we can remove
      // them later.
        eaarl(indx).rn = 0;
        if (mode==3) {
          be_elv = eaarl.lelv(indx);
        }
        if (mode==2) {
          be_elv = eaarl.elevation(indx)+eaarl.depth(indx);
        }
        if (mode==1) {
          be_elv = eaarl.elevation(indx);
        }
        e1 = eaarl(indx);
        //find min and max for be_elv
        mn_be_elv = min(be_elv);
        mx_be_elv = max(be_elv);
        // now find the 2-D polynomial fit for these points using order 3.
        c = poly2_fit(be_elv/100., e1.east/100., e1.north/100., 3);
        // define a random set of points in that area selected to apply
        // this fit

        // this is the area of the region in m^2.
        narea = abs((m(3)-m(1))*(m(4)-m(2)));
        narea = int(narea);
        a1 = [m(1),m(2)];
        a2 = [m(3), m(4)];
        ss = span(a1,a2,narea);

        nrand = int(narea/ndivide) + 1;
        rr1 = random(nrand);
        iidx1 = int(rr1*narea)+1;
        rr2 = random(nrand);
        iidx2 = int(rr2*narea)+1;
        elvall = array(double, nrand);
        for (k=1;k<=nrand;k++) {
          x = ss(iidx1(k),1);
          y = ss(iidx2(k),2);
          elvall(k) = c(1)+c(2)*x+c(3)*y+c(4)*x^2+c(5)*x*y + c(6)*y^2 + c(7)*x^3 + c(8)*x^2*y + c(9)*x*y^2 + c(10)*y^3;
        }
        if (mode == 1) {
          a = structof(eaarl(1));
          if (structeq(a, FS)) new_pts = array(R,nrand);
          if (structeq(a, VEG__)) new_pts = array(VEG__,nrand);
        }
        if (mode == 2)
          new_pts = array(GEO,nrand);
        if (mode == 3)
          new_pts = array(VEG__,nrand);
        new_pts.east = int(ss(iidx1,1)*100);
        new_pts.north = int(ss(iidx2,2)*100);
        if (mode == 3) {
          new_pts.least = int(ss(iidx1,1)*100);
          new_pts.lnorth = int(ss(iidx2,2)*100);
        }
        if (mode == 2) {
          new_pts.elevation = -10;
          new_pts.depth = int(elvall*100 + 10);
        }
        if (mode == 3) {
          new_pts.lelv = int(elvall*100);
        }
        if (mode == 1) {
          new_pts.elevation = int(elvall*100);
        }
        new_pts.rn = span(count+1,count+nrand,nrand);
        new_pts.soe = span(count+1,count+nrand,nrand);

        // remove any points that are not within the elevation boundaries
        // of the original points
        if (mode==1)
          xidx = where(((new_pts.elevation) > mn_be_elv) & ((new_pts.elevation) < mx_be_elv));
        if (mode==2)
          xidx = where(((new_pts.elevation+new_pts.depth) > mn_be_elv) & ((new_pts.elevation+new_pts.depth) < mx_be_elv));
        if (mode==3)
          xidx = where(((new_pts.lelv) > mn_be_elv) & ((new_pts.lelv) < mx_be_elv));
        if (is_array(xidx)) {
          new_pts = new_pts(xidx);
        } else {
          new_pts = []; nrand=0; continue;
        }
        xidx = [];
        nrand = numberof(new_pts);

        if ((count+nrand) > numberof(new_eaarl)) {
          new_eaarl1 = new_eaarl(1:count);
          new_count += numberof(new_eaarl);
          if (mode==1 || mode ==3)
            new_eaarl = array(VEG__, new_count);
          if (mode==2)
            new_eaarl = array(GEO, new_count);
          new_eaarl(1:count) = new_eaarl1;
          new_eaarl1 = [];
        }
        new_eaarl(count+1:count+nrand) = new_pts;
        count += nrand;
      }
    }

    if (_ytk && (ngridy>1))
      tkcmd, swrite(format="set progress %d", i)
  }
  if (_ytk) {
    tkcmd, "destroy .polyfit"
  }
  // remove points from eaarl_orig, that were tagged with rn = 0 in eaarl;
  rnidx = [];
  if (!gridmode) {
    rnidx = grow(rnidx, where(eaarl.rn != 0));
    new_eaarl = grow(new_eaarl, eaarl(rnidx));
  }

  new_eaarl = new_eaarl(1:count);

  // add fake mirror east,north, and elevation values (assume AGL to be 300m)
  new_eaarl.meast = new_eaarl.east;
  new_eaarl.mnorth = new_eaarl.north;
  new_eaarl.melevation = new_eaarl.elevation + 300*100;

  if (mode == 1) {
    if (structeq(structof(new_eaarl), VEG__)) {
      // make last elevations the same as first return elevations
      new_eaarl.lnorth = new_eaarl.east;
      new_eaarl.least = new_eaarl.east;
      new_eaarl.lelv = new_eaarl.elevation;
    }
  }

  return new_eaarl;
}

func make_boxlist(win) {
// Original 2005-08-08 Amar Nayegandhi
  window, win;

  boxlist = array(double, 10, 4);
  count = 1;
  contadd = 1;
  icount = 1;
  ans = 'n';
  while (contadd) {
    m = mouse(1,1,"select region: ");
    plg, [m(2),m(2),m(4),m(4),m(2)], [m(1),m(3),m(3),m(1),m(1)], color="red", width=1.5;
    if ((count % 10) == 0) {
      icount++;
      boxlist1 = boxlist;
      boxlist = array(double, 10*icount,4);
      boxlist(1:count,) = boxlist1;
    }
    boxlist(count++,) = m(1:4);
    n = read(prompt="Continue? (y/n):", format="%c",ans);
    if (ans != 'y' ) contadd = 0;
  }

  boxlist = boxlist(1:count-1,);
  return boxlist;
}

func batch_polyfit_smooth(bdata, iwin=, wslide=, mode=, boxlist=, wbuf=,
gridmode=, ndivide=) {
/* DOCUMENT batch_polyfit_smooth(idata, iwin=, wslide=, mode=, boxlist=, wbuf=,
  gridmode=, ndivide=)
  See polyfit_eaarl_pts for explanation of input parameters
*/
// Original 2005-08-12 Amar Nayegandhi
  default, iwin, 5;
  default, mode, 2;

  window, iwin;
  // ensure there are no 0 east or north values in bdata
  idx = where(bdata.east != 0);
  bdata = bdata(idx);
  idx = where(bdata.north != 0);
  bdata = bdata(idx);

  n_bdata = numberof(bdata);
  if (mode == 1)
    outdata = array(FS, n_bdata);
  if (mode == 2)
    outdata = array(GEO, n_bdata);
  if (mode == 3)
    outdata = array(VEG__, n_bdata);

  ncount = 0;
  nt_bdata = 1;

  // find boundaries of bdata
  mineast = min(bdata.east)/100.;
  maxeast = max(bdata.east)/100.;
  minnorth = min(bdata.north)/100.;
  maxnorth = max(bdata.north)/100.;

  ind_e_min = 2000 * (int((mineast/2000)));
  ind_e_max = 2000 * (1+int((maxeast/2000)));
  if ((maxeast % 2000) == 0) ind_e_max = maxeast;
  ind_n_min = 2000 * (int((minnorth/2000)));
  ind_n_max = 2000 * (1+int((maxnorth/2000)));
  if ((maxnorth % 2000) == 0) ind_n_max = maxnorth;

  n_east = (ind_e_max - ind_e_min)/2000;
  n_north = (ind_n_max - ind_n_min)/2000;
  n = n_east * n_north;

  min_e = array(float, n);
  max_e = array(float, n);
  min_n = array(float, n);
  max_n = array(float, n);

  i = 1;
  for (e=ind_e_min; e<=(ind_e_max-2000); e=e+2000) {
    for(north=(ind_n_min+2000); north<=ind_n_max; north=north+2000) {
      min_e(i) = e;
      max_e(i) = e+2000;
      min_n(i) = north-2000;
      max_n(i) = north;
      i++;
    }
  }

  pldj, min_e, min_n, min_e, max_n, color="green";
  pldj, min_e, min_n, max_e, min_n, color="green";
  pldj, max_e, min_n, max_e, max_n, color="green";
  pldj, max_e, max_n, min_e, max_n, color="green";

  for (i=1;i<=n;i++) {
    write, format="Processing Region %d of %d\r",i,n;
    dt_idx  = data_box(bdata.east/100., bdata.north/100., min_e(i)-100, max_e(i)+100, min_n(i)-100, max_n(i)+100);

    if (!is_array(dt_idx)) continue;
    dtdata = bdata(dt_idx);

    dtdp = polyfit_eaarl_pts(dtdata, wslide=wslide, mode=mode, wbuf=wbuf, gridmode=gridmode,ndivide=ndivide);

    if (!is_array(dtdp)) continue;

    didx  = data_box(dtdp.east/100., dtdp.north/100., min_e(i), max_e(i), min_n(i), max_n(i));

    if (!is_array(didx)) continue;
    dtdp = dtdp(didx);

    n_dtdp = numberof(dtdp);
    if ((ncount+n_dtdp) > n_bdata) {
      // increase the output data array
      nt_bdata++;
      if (nt_bdata==1)
        write, format="Warning... Output data array is bigger than input data array...\n";
      outdata1 = outdata(1:ncount);
      outdata = array(GEO,ncount+n_dtdp);
      outdata(1:ncount) = outdata1;
      outdata1 = [];
    }

    outdata(ncount+1:ncount+n_dtdp) = dtdp;
    ncount += n_dtdp;
    pldj, min_e(i), min_n(i), min_e(i), max_n(i), color="black";
    pldj, min_e, min_n(i), max_e, min_n(i), color="black";
    pldj, max_e, min_n(i), max_e, max_n(i), color="black";
    pldj, max_e(i), max_n(i), min_e(i), max_n(i), color="black";
  }

  outdata = outdata(1:ncount);

  // change the rn and soe values of outdata so that they are unique
  outdata.rn = span(1,ncount,ncount);
  outdata.soe = span(1,ncount,ncount);
  return outdata;

}
