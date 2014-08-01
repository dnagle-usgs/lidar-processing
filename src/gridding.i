// vim: set ts=2 sts=2 sw=2 ai sr et:

func batch_grid(dir, outdir=, searchstr=, method=, mode=, toarc=, buffer=,
cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=, minpoints=,
powerwt=, update=) {
/* DOCUMENT batch_grid, dir, outdir=, searchstr=, method=, mode=, toarc=,
  buffer=, cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=,
  minpoints=, powerwt=, update=;

  Batch grids data.

  Parameter:
    dir: A directory in which to find PBD files to grid.

  General batch options:
    outdir= Directory to create gridded data files in. Default is to create
      them alongside the input files. Output files will be named the same as
      input, but will have the .pbd extension replaced with _grid.pbd.
    searchstr= Search string used to find the files to grid.
        searchstr="*qc.pbd"  (default)
    method= Gridding method to use.
        method="triangle"         Use triangulation (default)
        method="radius_invdist"   Use radius-based inverse distance weighting
        method="radius_average"   Use radius-based moving average
        method="cell_last"        Use last value in cell (per current ordering)
        method="cell_average"     Use average of values in cell
        method="cell_median"      Use median of values in cell
    mode= The data mode to use for the input data. By default, this is
      determined from the file name if possible; if not possible, the file
      is skipped.
    toarc= Use this to create ARC ASCII files as well. Saves you from calling
      batch_write_arc_grid later.
        toarc=0     Do not create ARC ASCII files. (default)
        toarc=1     Create ARC ASCII files.
    update= By default, existing files are deleted and recreated. Use update=1
      to skip existing files. Note that this only looks at the pbd file; it
      won't create missing arc files for existing pbd files if you use toarc=1.

  General gridding options:
    buffer= By default each input file will be clipped to the bounds of the
      tile defined in its filename. This alters that behavior.
        buffer=0    Clip to exact tile boundary. (default)
        buffer=100  Add a 100m buffer to tile boundary.
        buffer=-1   Disable clipping; grid all data.
    cell= The cell size to use. Cells are always square.
        cell=1.     1m cell size (default)
        cell=0.25   25cm cell size
        cell=5      5m cell size
    nodata= No data value to use.
        nodata=-32767.       (default)

  Options used for method="triangle":
    maxside= Maximum side length allowed for triangles
        maxside=50.    50 square meters (default)
        maxside=0      Do not filter triangles by side
    maxarea= Maximum area allowed for triangles
        maxarea=200.   200m (default)
        maxarea=0      Do not filter triangles by area
    minangle= Minimum angle allowed for triangles
        minangle=5     5 degrees
        minangle=0     Do not filter triangles by angle (default)

  Options used for method="radius_average":
    maxradius= Maximum search radius to use around each point.
    minpoints= Minimum number of points that must be found to interpolate.

  Options used for method="radius_invdist":
    maxradius= Maximum search radius to use around each point.
    minpoints= Minimum number of points that must be found to interpolate.
    powerwt= Weighting power.

  SEE ALSO: pbd_grid, data_grid, data_triangle_grid, data_radius_grid
*/
  local curmode;

  default, searchstr, "*qc.pbd";
  default, buffer, 0;
  default, cell, 1.;
  default, toarc, 0;
  default, method, "triangle";
  default, update, 0;

  files = find(dir, searchstr=searchstr);

  if(!numberof(files)) {
    write, "Nothing to do: no files found.";
    return;
  }

  outfiles = file_rootname(files) + "_grid.pbd";
  if(!is_void(outdir))
    outfiles = file_join(outdir, file_tail(outfiles));

  if(update) {
    w = where(!file_exists(outfiles));
    if(!numberof(w)) {
      write, "All files already generated";
      return;
    }
    files = files(w);
    outfiles = outfiles(w);
  }

  options = save(string(0), [], method, toarc, buffer, cell, nodata, maxside,
    maxarea, minangle, maxradius, minpoints, powerwt);

  conf = save();

  arcfile = [];
  for(i = 1; i <= numberof(files); i++) {
    tail = file_tail(files(i));

    // Determine mode
    if(is_void(mode)) {
      if(!regmatch("(^|_)(fs|be|ba)(_|\.)", tail, , , curmode)) {
        write, format="Skipping %s: cannot determine data mode\n", tail;
        continue;
      }
    } else {
      curmode = mode;
    }

    if(toarc) {
      arcfile = file_rootname(outfiles(i)) + ".asc";
      remove, arcfile;
    }

    remove, outfiles(i);
    save, conf, string(0), save(
      input=files(i),
      output=grow(outfiles(i), arcfile),
      command="job_pbd_grid",
      options=obj_merge(options, save(
        infile=files(i), outfile=outfiles(i), arcfile, mode=curmode
      ))
    );
  }

  makeflow_run, conf;
}

func pbd_grid(infile, outfile=, method=, mode=, toarc=, arcfile=, buffer=,
cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=, minpoints=,
powerwt=) {
/* DOCUMENT pbd_grid, infile, outfile=, method=, mode=, toarc=, arcfile=,
   buffer=, cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=,
   minpoints=, powerwt=

  Grids data for a PBD file.

  Parameter:
    infile: PBD file to grid.

  Options:
    outfile= PBD file to output to. Default is to replace the .pbd extension of
      INFILE with _grid.pbd.
    arcfile= ASC file to output to for ARC ASCII. Default is to replace .pbd
      extension of OUTFILE with .asc.

  See batch_grid for details on these options:
    method=
    mode=
    toarc=
    cell=
    nodata=
    maxside=
    maxarea=
    minangle=
    maxradius=
    minpoints=
    powerwt=

  SEE ALSO: batch_grid, data_grid, data_triangle_grid, data_radius_grid
*/
  local err, vname;

  default, outfile, file_rootname(infile) + "_grid.pbd";
  default, mode, "fs";
  default, buffer, 0;
  default, cell, 1.;
  default, toarc, 0;
  default, arcfile, file_rootname(outfile) + ".asc";
  default, method, "triangle";

  data = pbd_load(infile, err, vname);
  if(is_void(data)) {
    if(strlen(err))
      error, "unable to load pbd: "+err;
    else
      error, "pbd empty";
  }

  vname += "_grid";

  if(buffer < 0) {
    xmin = xmax = ymin = ymax = [];
  } else {
    bbox = tile2bbox(file_tail(infile));
    xmin = bbox([2,4])(min) - buffer;
    xmax = bbox([2,4])(max) + buffer;
    ymin = bbox([1,3])(min) - buffer;
    ymax = bbox([1,3])(max) + buffer;
  }

  grid = data_grid(data, method=method, mode=mode, xmin=xmin, xmax=xmax,
    ymin=ymin, ymax=ymax, cell=cell, nodata=nodata, maxside=maxside,
    maxarea=maxarea, minangle=minangle, maxradius=maxradius,
    minpoints=minpoints, powerwt=powerwt);
  data = [];

  pbd_save, outfile, vname, grid;

  if(toarc)
    write_arc_grid, grid, arcfile;
}

func data_grid(data, method=, mode=, region=, xmin=, xmax=, ymin=, ymax=,
cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=, minpoints=,
powerwt=) {
/* DOCUMENT gridded = data_grid(data, method=, mode=, xmin=, xmax=, ymin=,
   ymax=, cell=, nodata=, maxside=, maxarea=, minangle=, maxradius=,
   minpoints=, powerwt=)

  Grids data.

  Parameter:
    data: Data to grid.

  Options:
    xmin=, xmax=, ymin=, ymax= If provided, the gridded data will be restricted
      to these bounds. Otherwise, the full extent of the data will be used.
    region= If provided, this will be used to determine the bounds. If the
      region specified is not square, then the bounding box of the region will
      be used. (This overwrites xmin, xmax, ymin, ymax if they are also
      provided.)

  See batch_grid for details on these options:
    method=
    mode=
    cell=
    nodata=
    maxside=
    maxarea=
    minangle=
    maxradius=
    minpoints=
    powerwt=

  SEE ALSO: batch_grid, pbd_grid, data_triangle_grid, data_radius_grid
*/
  if(!is_void(region)) {
    assign, region_to_bbox(region, geo=geo), xmin, xmax, ymin, ymax;
  }

  if(method == "triangle")
    return data_triangle_grid(data, mode=mode, xmin=xmin, xmax=xmax,
      ymin=ymin, ymax=ymax, cell=cell, nodata=nodata, maxside=maxside,
      maxarea=maxarea, minangle=minangle);
  else if(strpart(method, 1:7) == "radius_")
    return data_radius_grid(data, strpart(method, 8:), mode=mode, xmin=xmin,
      xmax=xmax, ymin=ymin, ymax=ymax, cell=cell, nodata=nodata,
      maxradius=maxradius, minpoints=minpoints, wtpower=wtpower, verbose=0);
  else if(strpart(method, 1:5) == "cell_")
    return data_cell_grid(data, method=strpart(method, 6:), mode=mode,
      xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, cell=cell, nodata=nodata);
  else
    error, "Unknown method";
}

func data_triangle_grid(data, mode=, xmin=, xmax=, ymin=, ymax=, cell=,
nodata=, maxside=, maxarea=, minangle=, tile=, buffer=) {
/* DOCUMENT data_triangle_grid(data, mode=, xmin=, xmax=, ymin=, ymax=, cell=,
  nodata=, maxside=, maxarea=, minangle=, tile=, buffer=)

  Grids an array of EAARL data using triangulation and returns a ZGRID value.

  NOTE: This function requires C-ALPS.

  Parameter:
    data: An array of EAARL data.
  Options:
    mode= Data mode to use.
    xmin= Lower x-boundary of grid
    xmax= Upper x-boundary of grid
    ymin= Lower y-boundary of grid
    ymax= Upper y-boundary of grid
    cell= Cell size
    nodata= Nodata value to use (defaults to -32767.)
    maxside= Maximum side length allowed for triangles
        maxside=50.    (default)
    maxarea= Maximum area allowed for triangles
        maxarea=200.   (default)
    minangle= Minimum angle allowed for triangles (not used by default)
    tile= A tile name that defines xmin,xmax,ymin,ymax (dt, it, qq codes).
    buffer= A buffer to extend around tile=, if it is used.
*/
  local x, y, z, v;
  default, maxarea, 200.;
  default, maxside, 50.;
  default, buffer, 0;
  if(!is_void(tile)) {
    default, buffer, 0;
    bbox = tile2bbox(tile);
    if(is_void(bbox))
      error, "Invalid tile name provided.";
    xmin = bbox([2,4])(min) - buffer;
    xmax = bbox([2,4])(max) + buffer;
    ymin = bbox([1,3])(min) - buffer;
    ymax = bbox([1,3])(max) + buffer;
  }

  v = triangulate_data(data, mode=mode, verbose=0, maxside=maxside,
    maxarea=maxarea, minangle=minangle);
  data2xyz, data, x, y, z, mode=mode;
  return triangle_grid(x, y, z, v, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax,
    nodata=nodata, cell=cell);
}

func grid_fix_params(x, y, cell, &xmin, &xmax, &ymin, &ymax, &xcount, &ycount) {
/* DOCUMENT grid_fix_params, x, y, cell, xmin, xmax, ymin, ymax, xcount, ycount;
  This is used by the gridding algorithms to determine the appropriate
  parameters to use. The values for xmin, xmax, ymin, ymax, xcount, and ycount
  are determined (where necessary) and fixed to make sense with respect to one
  another (where necessary).
*/
  default, xmin, floor(x(min));
  default, ymin, floor(y(min));
  default, xmax, ceil(x(max));
  default, ymax, ceil(y(max));

  xcount = long(ceil((xmax-xmin)/cell));
  ycount = long(ceil((ymax-ymin)/cell));

  xmax = xmin + xcount * cell;
  ymax = ymin + ycount * cell;
}

func triangle_grid(x, y, z, v, xmin=, xmax=, ymin=, ymax=, cell=, nodata=) {
/* DOCUMENT grid = triangle_grid(x, y, z, v, xmin=, xmax=, ymin=, ymax=, cell=,
  nodata=, progress=)

  Creates a grid for the data x,y,z using the triangulation defined by v.

  NOTE: This function requires C-ALPS.

  Parameters:
    x: Array of known x values
    y: Array of known y values
    z: Array of known z values
    v: A nx3 array of vertices.
  Options:
    xmin= Minimum x value for grid.
    xmax= Maximum x value for grid. (May be adjusted based on xmin and cell.)
    ymin= Minimum y value for grid
    ymax= Maximum y value for grid. (May be adjusted based on ymin and cell.)
    cell= Cell size for grid.
    nodata= Nodata value to use.
*/
  default, nodata, -32767.;
  default, cell, 1.;
  cell = double(cell);

  grid_fix_params, x, y, cell, xmin, xmax, ymin, ymax, xcount, ycount;

  xgrid = ygrid = array(double, xcount, ycount);
  zgrid = array(double(nodata), xcount, ycount);

  // Each point represents a grid square, so we want to actually interpolate
  // for the cell centers.
  hc = 0.5 * cell;
  xgrid(,) = span(xmin+hc, xmax-hc, xcount)(,-);
  ygrid(,) = span(ymin+hc, ymax-hc, ycount)(-,);

  xv = x(v);
  yv = y(v);
  xvmin = xv(,min);
  xvmax = xv(,max);
  yvmin = yv(,min);
  yvmax = yv(,max);
  xv = yv = [];

  status, start, msg="Gridding data...";
  step = 50;
  xvi = indgen(numberof(xvmax));
  for(i = 1; i <= dimsof(zgrid)(2); i += step) {
    ii = min(i+step-1, dimsof(zgrid)(2));

    w = where(xgrid(i,1) <= xvmax(xvi));
    if(!numberof(w)) {
      i = dimsof(zgrid)(2) + 1; // short circuit
      continue;
    }
    xvi = xvi(w);

    w = where(xvmin(xvi) <= xgrid(ii,1));
    if(!numberof(w))
      continue;
    yvi = xvi(w);

    for(j = 1; j <= dimsof(zgrid)(3); j += step) {
      jj = min(j+step-1, dimsof(zgrid)(3));

      w = where(ygrid(1,j) <= yvmax(yvi));
      if(!numberof(w)) {
        j = dimsof(zgrid)(3) + 1; // short circuit
        continue;
      }
      yvi = yvi(w);

      w = where(yvmin(yvi) <= ygrid(1,jj));
      if(!numberof(w))
        continue;
      w = yvi(w);

      xx = xgrid(i:ii,j:jj);
      yy = ygrid(i:ii,j:jj);
      if(!numberof(w))
        continue;
      zgrid(i:ii,j:jj) = triangle_interp(x, y, z, v(w,), xx, yy, nodata=nodata);
    }
    status, progress, ii, dimsof(zgrid)(2);
  }
  status, finished;

  // Check to see if we can safely convert to floats. If the float version
  // agrees with the double version to within 0.5mm, then switch to floats.
  fzgrid = float(zgrid);
  if(abs(fzgrid-zgrid)(*)(max) < 0.0005)
    eq_nocopy, zgrid, fzgrid;

  return ZGRID(xmin=xmin, ymin=ymin, cell=cell, nodata=nodata, zgrid=&zgrid);
}

func triangle_interp(x, y, z, v, xp, yp, nodata=) {
/* DOCUMENT zp = triangle_interp(x, y, z, v, xp, yp, nodata=);
  Interpolates values using triangulation.

  For each point xp,yp, the triangle defined by v is found that contains the
  point. The three vertexes of this triangle define a plane; zp is
  interpolated to its value at xp,yp within that plane.

  NOTE: This function requires C-ALPS.

  Parameters:
    x: Array of known x values.
    y: Array of known y values.
    z: Array of known z values.
    v: A 3xn or nx3 array of indexes into x,y,z that define triangles.
    xp: Array of x values at which to predict.
    yp: Array of y values at which to predict.
  Options:
    nodata= Value to use when no interpolation is possible.
        nodata=-32767.    (default)
*/
  default, nodata, -32767.;

  xyzdims = dimsof(x,y,z);
  if(is_void(xyzdims))
    error, "x, y, and z are not conformable.";
  xyzb = array(0., xyzdims);
  x += xyzb;
  y += xyzb;
  z += xyzb;

  pdims = dimsof(xp,yp);
  if(is_void(pdims))
    error, "xp and yp are not conformable.";
  zp = array(0., pdims);
  xp += zp;
  yp += zp;

  local v1, v2, v3;
  splitary, v, 3, v1, v2, v3;

  nodata = double(nodata);
  _ytriangle_interp, x, y, z, v1, v2, v3, numberof(v1), xp, yp, zp,
    numberof(zp), nodata;

  return zp;
}

func data_radius_grid(data, method, mode=, xmin=, xmax=, ymin=, ymax=, nodata=,
cell=, maxradius=, minpoints=, wtpower=, verbose=) {
/* DOCUMENT data_radius_grid(data, method, mode=, xmin=, xmax=, ymin=, ymax=,
  nodata=, cell=, maxradius=, minpoints=, wtpower=, verbose=)

  Grids an array of EAARL data using radius_grid. See radius_grid for details.
*/
  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;
  return radius_grid(x, y, z, method, xmin=xmin, xmax=xmax, ymin=ymin,
    ymax=ymax, nodata=nodata, cell=cell, maxradius=maxradius,
    minpoints=minpoints, wtpower=wtpower, verbose=verbose);
}

func radius_grid(x, y, z, method, xmin=, xmax=, ymin=, ymax=, cell=, nodata=,
maxradius=, minpoints=, wtpower=, verbose=) {
/* DOCUMENT grid = radius_grid(x, y, z, method, xmin=, xmax=, ymin=, ymax=,
  cell=, nodata=, maxradius=, minpoints=, wtpower=)

  Creates a grid for the data x,y,z using one of two radius-based methods:
  invdist or average.

  Parameters:
    x: Array of known x values
    y: Array of known y values
    z: Array of known z values
    method: Method of interpolation to use. Two possible values:
      "invdist"   Use inverse distance weighting. (default)
      "average"   Use averaging.
  Options:
    xmin= Minimum x value for grid.
    xmax= Maximum x value for grid. (May be adjusted based on xmin and cell.)
    ymin= Minimum y value for grid
    ymax= Maximum y value for grid. (May be adjusted based on ymin and cell.)
    cell= Cell size for grid.
    nodata= Nodata value to use.
    maxradius= Search radius to use.
    minpoints= Minimum points that must be found to perform interpolation.
    wtpower= Weighting power ("invdist" only).
    verbose= Specifies how chatty to be, default is verbose=1.
*/
  default, nodata, -32767.;
  default, cell, 1.;
  cell = double(cell);
  default, maxradius, sqrt(cell*cell)*0.5;
  default, minpoints, 1;
  default, wtpower, 2;
  default, method, "invdist";
  default, verbose, 1;

  grid_fix_params, x, y, cell, xmin, xmax, ymin, ymax, xcount, ycount;

  xgrid = ygrid = array(double, xcount, ycount);
  zgrid = array(double(nodata), xcount, ycount);

  // Each point represents a grid square, so we want to actually interpolate
  // for the cell centers.
  hc = 0.5 * cell;
  xgrid(,) = span(xmin+hc, xmax-hc, xcount)(,-);
  ygrid(,) = span(ymin+hc, ymax-hc, ycount)(-,);

  t0 = array(double, 3);
  timer, t0;
  step = 50;
  if(verbose)
    write, format="Need to grid for %d rows...\n", dimsof(zgrid)(2);
  xi = indgen(numberof(x));
  for(i = 1; i <= dimsof(zgrid)(2); i += step) {
    ii = min(i+step-1, dimsof(zgrid)(2));
    if(verbose)
      write, format="Gridding for %d:%d\n", i,ii;

    w = where(xgrid(i,1) - maxradius <= x(xi));
    if(!numberof(w)) {
      i = dimsof(zgrid)(2) + 1; // short circuit
      continue;
    }
    xi = xi(w);

    w = where(x(xi) <= xgrid(ii,1) + maxradius);
    if(!numberof(w))
      continue;
    yi = xi(w);

    for(j = 1; j <= dimsof(zgrid)(3); j += step) {
      jj = min(j+step-1, dimsof(zgrid)(3));

      w = where(ygrid(1,j) - maxradius <= y(yi));
      if(!numberof(w)) {
        j = dimsof(zgrid)(3) + 1; // short circuit
        continue;
      }
      yi = yi(w);

      w = where(y(yi) <= ygrid(1,jj) + maxradius);
      if(!numberof(w))
        continue;
      w = yi(w);

      xx = xgrid(i:ii,j:jj);
      yy = ygrid(i:ii,j:jj);

      if(method == "invdist")
        zgrid(i:ii,j:jj) = invdist_interp(x(w), y(w), z(w), xx, yy,
          maxradius, minpoints, wtpower, nodata=nodata);
      else if(method == "average")
        zgrid(i:ii,j:jj) = moveavg_interp(x(w), y(w), z(w), xx, yy,
          maxradius, minpoints, nodata=nodata);
      else
        error, "Unknown method";
    }
    if(verbose)
      timer_remaining, t0, ii, dimsof(zgrid)(3);
  }
  if(verbose)
    timer_finished, t0;

  // Check to see if we can safely convert to floats. If the float version
  // agrees with the double version to within 0.5mm, then switch to floats.
  fzgrid = float(zgrid);
  if(abs(fzgrid-zgrid)(*)(max) < 0.0005)
    eq_nocopy, zgrid, fzgrid;

  return ZGRID(xmin=xmin, ymin=ymin, cell=cell, nodata=nodata, zgrid=&zgrid);
}

func moveavg_interp(x, y, z, xp, yp, mrad, minpts, nodata=) {
/* DOCUMENT zp = moveavg_interp(x, y, z, xp, yp, mrad, minpts, nodata=)
  Interpolates data using a moving average approach.

  For each point xp,yp, all points x,y,z are found that are within mrad
  distance. If there are at least minpts points found, then zp is set to the
  average z value of the found points.

  Parameters:
    x: Array of known x values
    y: Array of known y values
    z: Array of known z values
    xp: Array of x values at which to predict
    yp: Array of y values at which to predict
    mrad: Search radius around xp,yp to look for points
    minpts: Minimum number of points that must be found to perform
      interpolation
  Option:
    nodata= The nodata value to use, when interpolation not possible.
        nodata=-32767.    (default)
*/
  default, nodata, -32767.;
  zp = array(double(nodata), dimsof(xp));
  for(i = 1; i <= numberof(xp); i++) {
    idx = find_points_in_radius(xp(i), yp(i), x, y, radius=mrad);
    if(numberof(idx) >= minpts)
      zp(i) = z(idx)(avg);
  }
  return zp;
}

func invdist_interp(x, y, z, xp, yp, mrad, minpts, wp, nodata=) {
/* DOCUMENT zp = invdist_interp(x, y, z, xp, yp, mrad, minpts, wp, nodata=)
  Interpolates data using a inverse distance power approach.

  For each point xp,yp, all points x,y,z are found that are within mrad
  distance. If there are at least minpts points found, then zp is set to a
  weighted average of the z values of the found points. The weighting factor
  for each point is the reciprocal of its distance raised to the wp power.

  Parameters:
    x: Array of known x values
    y: Array of known y values
    z: Array of known z values
    xp: Array of x values at which to predict
    yp: Array of y values at which to predict
    mrad: Search radius around xp,yp to look for points
    minpts: Minimum number of points that must be found to perform
      interpolation
    wp: Weighting power to use
  Option:
    nodata= The nodata value to use, when interpolation not possible.
        nodata=-32767.    (default)
*/
  default, nodata, -32767.;
  zp = array(double(nodata), dimsof(xp));
  for(i = 1; i <= numberof(xp); i++) {
    idx = find_points_in_radius(xp(i), yp(i), x, y, radius=mrad);
    if(numberof(idx) >= minpts) {
      dist = ppdist([x(idx), y(idx)], [xp(i), yp(i)], tp=1);
      if(anyof(!dist)) {
        w = where(!dist);
        zp(i) = z(idx(w))(avg);
      } else {
        wt = 1./(dist^wp);
        zp(i) = ((z(idx)*wt)(sum))/(wt(sum));
      }
    }
  }
  return zp;
}

func data_cell_grid(data, method=, mode=, xmin=, xmax=, ymin=, ymax=, cell=,
nodata=) {
/* DOCUMENT data_cell_grid(data, method=, mode=, xmin=, xmax=, ymin=, ymax=,
   cell=, nodata=)

  Grids an array of EAARL data using cell_grid. See cell_grid for details.
*/
  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;
  return cell_grid(x, y, z, method=method, xmin=xmin, xmax=xmax, ymin=ymin,
    ymax=ymax, nodata=nodata, cell=cell);
}

func cell_grid(x, y, z, method=, xmin=, xmax=, ymin=, ymax=, cell=, nodata=) {
/* DOCUMENT grid = radius_grid(x, y, z, method=, xmin=, xmax=, ymin=, ymax=,
  cell=, nodata=)

  Creates a grid for the data x,y,z using a cell-based algorithm.

  Parameters:
    x: Array of known x values
    y: Array of known y values
    z: Array of known z values
  Options:
    method= Method of interpolation to use. Three possible values:
      "last"      Use last value found in cell (per ordering of x,y,z).
      "average"   Use average of values in cell.
      "median"    Use median of values in cell. (default)
    xmin= Minimum x value for grid.
    xmax= Maximum x value for grid. (May be adjusted based on xmin and cell.)
    ymin= Minimum y value for grid
    ymax= Maximum y value for grid. (May be adjusted based on ymin and cell.)
    cell= Cell size for grid.
    nodata= Nodata value to use.
*/
  default, nodata, -32767.;
  default, cell, 1.;
  cell = double(cell);
  default, method, "median";

  grid_fix_params, x, y, cell, xmin, xmax, ymin, ymax, xcount, ycount;

  // Restrict data to bounds (cell-based algorithm only uses data in each cell)
  w = data_box(x, y, xmin, xmax, ymin, ymax);
  x = x(w);
  y = y(w);
  z = z(w);

  // Grid storage
  zgrid = array(double(nodata), xcount, ycount);

  // Grid position for each point
  xc = min(xcount, (x-xmin)/cell + 1);
  yc = min(ycount, (y-ymin)/cell + 1);

  // Index into zgrid for z points
  zi = (long(yc) - 1) * xcount + long(xc);

  // last method is simple: just assign them all in, and the last one wins per
  // how Yorick interprets the syntax
  if(method == "last") {
    zgrid(zi) = z;
    goto FINISH;
  }

  // Sort by grid cell so that things are clustered together.
  srt = sort(zi);
  x = x(srt);
  y = y(srt);
  z = z(srt);
  xc = xc(srt);
  yc = yc(srt);
  zi = zi(srt);

  // Start/stop indexes for each run of ZI
  bounds = grow(0, where(zi(dif)), numberof(zi));
  nb = numberof(bounds);

  if(method == "average") {
    for(i = 1; i < nb; i++) {
      zgrid(zi(bounds(i+1))) = z(bounds(i)+1:bounds(i+1))(avg);
    }
  } else if(method == "median") {
    for(i = 1; i < nb; i++) {
      zgrid(zi(bounds(i+1))) = median(z(bounds(i)+1:bounds(i+1)));
    }
  } else {
    error, "invalid method";
  }

FINISH:
  // Check to see if we can safely convert to floats. If the float version
  // agrees with the double version to within 0.5mm, then switch to floats.
  fzgrid = float(zgrid);
  if(abs(fzgrid-zgrid)(*)(max) < 0.0005)
    eq_nocopy, zgrid, fzgrid;

  return ZGRID(xmin=xmin, ymin=ymin, cell=cell, nodata=nodata, zgrid=&zgrid);
}

func batch_write_arc_grid(dir, searchstr=, outdir=) {
/* DOCUMENT batch_write_arc_grid, searchstr=, outdir=
  Batch creates ARC ASCII grid files.

  Parameter:
    dir: The directory in which to find the PBD files with ZGRID data.
  Options:
    searchstr= Search string to use.
        searchstr="*_grid.pbd" (default)
    outdir= Output directory to create files in. By default, files are
      created alongside the PBD files.

  Output file names will match the input file names, but will change the
  extension to .asc.
*/
  default, searchstr, "*_grid.pbd";
  files = find(dir, searchstr=searchstr);

  t0 = array(double, 3);
  timer, t0;
  tp = t0;
  for(i = 1; i <= numberof(files); i++) {
    write, format="%d/%d: %s\n", i, numberof(files), file_tail(files(i));
    data = pbd_load(files(i));
    if(!structeq(structof(data), ZGRID)) {
      write, "  -- Skipping, not in ZGRID structure.";
      continue;
    }
    ofn = file_rootname(files(i))+".asc";
    if(!is_void(outdir))
      ofn = file_join(outdir, file_tail(ofn));
    write_arc_grid, data, ofn;
    data = [];
    timer_remaining, t0, i, numberof(files), tp, interval=15;
  }
  timer_finished, t0;
}

func write_arc_grid(data, fn) {
/* DOCUMENT write_arc_grid, data, fn;
  Creates an ARC ASCII grid file for the given data.

  Parameters:
    data: Must be a scalar ZGRID value.
    fn: Filename for the ARC ASCII grid file to create.
*/
  z = *(data.zgrid);

  if(is_func(_ywrite_arc_grid)) {
    _ywrite_arc_grid, dimsof(z)(2), dimsof(z)(3), data.xmin, data.ymin,
      data.cell, data.nodata, z, strchar(fn);
    return;
  }

  f = open(fn, "w");
  write, f, format="ncols         %d\n", dimsof(z)(2);
  write, f, format="nrows         %d\n", dimsof(z)(3);
  write, f, format="xllcorner     %.3f\n", data.xmin;
  write, f, format="yllcorner     %.3f\n", data.ymin;
  write, f, format="cellsize      %.3f\n", data.cell;
  write, f, format="nodata_value  %.3f\n", data.nodata;

  for(i = dimsof(z)(3); i >= 1; i--) {
    for(j = 1; j < dimsof(z)(2); j++)
      write, f, format="%.3f ", z(j,i);
    write, f, format="%.3f\n", z(0,i);
  }

  close, f;
}

func display_grid(data, cmin=, cmax=) {
/* DOCUMENT display_grid, data, cmin=, cmax=
  Plots gridded data.

  Parameter:
    data: Data in ZGRID struct. May be scalar or array.
  Options:
    cmin= Minimum value for colorbar. Defaults to minimum z value.
    cmax= Maximum value for colorbar. Defaults to maximum z value.

  Note: If data is an array and cmin/cmax are not specified, they will be
  independently determined for each array element. This means each input
  element will receive a different colorbar.
*/
  if(numberof(data) > 1) {
    for(i = 1; i <= numberof(data); i++)
      display_grid, data(i), cmin=cmin, cmax=cmax;
    return;
  }

  z = *(data.zgrid);

  x = data.xmin + indgen(0:dimsof(z)(2)) * data.cell;
  y = data.ymin + indgen(0:dimsof(z)(3)) * data.cell;

  dims = [2, numberof(x), numberof(y)];

  xx = array(0, dims) + x(,-);
  yy = array(0, dims) + y(-,);

  ireg = array(0, dims);
  ireg(2:,2:) = z != data.nodata;

  plf, z, yy, xx, ireg, cmin=cmin, cmax=cmax;
}

func downsample_grid(data, factor) {
/* DOCUMENT newgrid = downsample_grid(grid, factor)
  Increases the cell size of a grid, downsampling it. Each output cell is
  defined using the average elevation across the input cells it replaces.

  Parameters:
    data: A scalar ZGRID value.
    factor: An integer factor to downsample by. The grid's row and column
      count must both be evenly divisible by this or you will get an error.

  Returns:
    A new ZGRID value.
*/
  z = *(data.zgrid);
  dims = dimsof(z)/[1,factor,factor];
  zp = array(double(0), dims);
  count = long(zp);
  for(i = 1; i <= factor; i++) {
    for(j = 1; j <= factor; j++) {
      cur = z(i::factor, j::factor);
      w = where(cur != data.nodata);
      if(!numberof(w))
        continue;
      count(w)++;
      zp(w) += cur(w);
    }
  }
  w = where(count);
  if(numberof(w))
    zp(w) /= double(count(w));
  w = where(!count);
  if(numberof(w))
    zp(w) = data.nodata;
  newdata = (data);
  newdata.cell *= factor;
  newdata.zgrid = &(structof(z)(zp));
  return newdata;
}

func pip_grid_mask(data, ply) {
/* DOCUMENT pip_grid_mask(data, ply)
  Returns a mask for data for the grid cells that are within the given polygon.

  Parameters:
    data: A scalar ZGRID value.
    ply: A polygon.

  Returns:
    An array of char with dims matching ZGRID's grid, where 1 is cells inside
    the poly and 0 is cells not inside the poly.
*/
  eq_nocopy, z, *data.zgrid;
  x = y = array(double, dimsof(z));
  xmax = data.xmin + dimsof(x)(2) * data.cell;
  ymax = data.ymin + dimsof(y)(3) * data.cell;
  hc = 0.5 * data.cell;
  x(,) = span(data.xmin+hc, xmax-hc, dimsof(x)(2))(,-);
  y(,) = span(data.ymin+hc, ymax-hc, dimsof(y)(3))(-,);
  idx = testPoly(ply, x(*), y(*));
  x = y = [];
  mask = array(char(0), dimsof(z));
  mask(idx) = 1;
  return mask;
}

func batch_convert_arcgrid2geotiff(dir, searchstr=, outdir=, compress=,
predictor=, tiled=, usetcl=) {
/* DOCUMENT batch_convert_arcgrid2geotiff, dir, searchstr=, outdir=, compress=,
  predictor=, tiled=, usetcl=;

  Uses GDAL to batch convert ARC ASCII grids into GeoTIFFs.

  NOTE: This function requires GDAL.

  Parameter:
    dir: The directory in which to find the ARC ASCII grid files.

  Options:
    searchstr= Search string to use to find the files.
        searchstr="*.asc" (default)
    outdir= Output directory to create GeoTIFFs in. If not provided, files
      will be created alongside the ARC ASCII files.
    compress= Specifies whether GDAL should use compression within the
      GeoTIFF.
        compress=0  No compression (default)
        compress=1  Uses DEFLATE compression
    predictor= Specifies which "predictor" to use for the compression
      algorithm. By default, no predictor is used.
        predictor=0    Implicitly use no predictor. (default)
        predictor=1    Explicitly use no predictor. (same as using 0)
        predictor=2    Use horizontal differencing.
        predictor=3    Use floating point prediction.
    tiled= Specifies whether stripped or tiled TIFF files should be created.
        tiled=0  Create stripped TIFF files. (default)
        tiled=1  Create tiled TIFF files.
    usetcl= Specifies whether Yorick should fork calls to gdal_translate, or
      whether it should ask Tcl to do so instead. Only use this if you're
      having problems doing it under Yorick.
        usetcl=0    Uses Yorick (default)
        usetcl=1    Uses Tcl
*/
  default, searchstr, "*.asc";
  files = find(dir, searchstr=searchstr);
  t0 = array(double, 3);
  timer, t0;
  tp = t0;
  for(i = 1; i <= numberof(files); i++) {
    tiff = is_void(outdir) ? files(i) : file_join(outdir, file_tail(files(i)));
    tiff = file_rootname(tiff) + ".tif";
    write, format="%d/%d: %s\n", i, numberof(files), file_tail(tiff);
    convert_arcgrid2geotiff, files(i), tiff, compress=compress,
      predictor=predictor, tiled=tiled, usetcl=usetcl;
    timer_remaining, t0, i, numberof(files), tp, interval=15;
    write, format="%s", "\n";
  }
  timer_finished, t0;
}

func convert_arcgrid2geotiff(arcfn, tiffn, compress=, predictor=, tiled=,
usetcl=) {
/* DOCUMENT convert_arcgrid2geotiff, arcfn, tiffn, compress=, predictor=,
  tiled=, usetcl=;

  Uses GDAL to convert an ARC ASCII grid into a GeoTIFF.

  NOTE: This function requires GDAL.

  Parameters:
    arcfn: Path to input ARC ASCII file.
    tiffn: Path to output GeoTIFF file.

  Options:
    See batch_convert_arcgrid2geotiff.
*/
  extern _ytk;
  default, compress, 0;
  default, predictor, 0;
  default, tiled, 0;
  default, usetcl, 0;
  args = ["-of", "GTiff"];
  if(compress)
    grow, args, "-co", "COMPRESS=DEFLATE", "-co", "ZLEVEL=9";
  if(predictor)
    grow, args, "-co", swrite(format="PREDICTOR=%d", int(predictor));
  if(tiled)
    grow, args, "-co", "TILED=YES";
  args = strjoin(args, " ");
  if(_ytk && usetcl) {
    cmd = swrite(
      format="eval exec [auto_execok {%s}] [list %s {%s} {%s} >@ stdout 2>@1]",
      file_join(alpsrc.gdal_bin, "gdal_translate"), args, arcfn, tiffn);
    tkcmd, cmd, async=0;
    write, format="%s", "\n";
  } else {
    cmd = swrite(format="'%s' %s '%s' '%s'",
      file_join(alpsrc.gdal_bin, "gdal_translate"), args, arcfn, tiffn);
    system, cmd;
  }
}

func idl_batch_grid(dir, outdir=, searchstr=, cell=, mode=, maxarea=, maxside=,
tilemode=, nodata=, datum=, zone=, buffer=) {
/* DOCUMENT idl_batch_grid, dir, outdir=, searchstr=, cell=, mode=, maxarea=,
  maxside=, tilemode=, nodata=, datum=, zone=, buffer=

  Uses IDL to run batch_grid.

  Parameter:
    dir: The directory where the edf files can be found.
  Options:
    outdir= Output directory to put tiffs in. Defaults to same directory edf
      file is found in.
    searchstr= Search string for edfs to process.
        searchstr="*.edf" (default)
    cell= Cell size to use, in meters.
        cell=1.00         (default)
    mode= Mode of data to use. Must be one of the following:
        mode="fs"         First surface (default)
        mode="ba"         Bathy
        mode="be"         Bare earth
    maxarea= Maximum area threshold for triangles, in square meters.
        maxarea=200.      (default)
    maxside= Maximum triangle leg length threshold, in meters.
        maxside=50.       (default)
    tilemode= Tiling mode to use. Must be one of the following:
        tilemode=1        Use all data (no tiles)
        tilemode=2        Constrain to 2km data tile boundaries (default)
        tilemode=3        Constrain to 10km index tile boundaries
    nodata= Value to use for no data values. Default is to let IDL decide,
      which is currently -32767.
    datum= Datum value to use. Must be one of the following:
        datum=1           NAD83/NAVD88 (default)
        datum=2           WGS84/ITRF
        datum=3           NAD83/ITRF
    zone= UTM zone of the data. By default, will use curzone.
    buffer= add buffer (in meters) around tiled gridded data. Ignored if 
	tilemode=1.
*/
  extern curzone;
  default, outdir, [];
  default, searchstr, "*.edf";
  default, cell, 1.00;
  default, mode, "fs";
  default, maxarea, 200.; //area_threshold
  default, maxside, 50.; //dist_threshold
  default, tilemode, 2; // datamode
  default, nodata, [];
  default, datum, 1;
  default, zone, curzone;

  mode = where(mode == ["fs", "ba", "be"]);
  if(numberof(mode) != 1) {
    error, "Invalid mode, must be \"fs\", \"ba\", or \"be\".";
  } else {
    mode = mode(1);
  }

  cmd = swrite(format="batch_grid, \"%s\", write_geotiffs=1", dir);
  if(!is_void(outdir))
    cmd += ", outdir=\"" + fix_dir(outdir) + "\"";
  cmd += swrite(format=", searchstr=\"%s\"", searchstr);
  cmd += swrite(format=", cell=%.4f", double(cell));
  cmd += swrite(format=", mode=%d", mode);
  cmd += swrite(format=", area_threshold=%.4f", double(maxarea));
  cmd += swrite(format=", dist_threshold=%.4f", double(maxside));
  cmd += swrite(format=", datamode=%d", long(tilemode));
  if(!is_void(buffer))
    cmd += swrite(format=", buffer=%d", long(buffer));
  if(!is_void(nodata))
    cmd += swrite(format=", missing=%.4f", double(nodata));
  cmd += swrite(format=", datum_type=%d", long(datum));
  cmd += swrite(format=", utmzone=%d", long(zone));

  f = popen("cd ../idl; idl", 1);
  write, f, ".COMPILE batch_grid.pro, grid_eaarl_data.pro";
  write, f, cmd;
  write, f, "exit";
  close, f;
}

func qqtiff_gms_prep(tif_dir, pbd_dir, mode, outfile, tif_glob=, pbd_glob=) {
/* DOCUMENT qqtiff_gms_prep, tif_dir, pbd_dir, mode, outfile, tif_glob=, pdb_glob=

  Creates a data tcl file that can be used by gm_tiff2ktoqq.tcl to generate a
  Global Mapper script that can be used to convert 2k data tile geotiffs into
  quarter quad geotiffs.

  Parameters:

    tif_dir: The directory containing the 2k tiled geotiffs.

    pbd_dir: The directory containing quarter quad pbds that contain the same
      source data points used to make the 2k data tiles repartitioned.

    mode: The type of EAARL data being used. Can be any value valid for
      data2xyz.
        mode="fs"   First surface
        mode="be"   Bare earth
        mode="ba"   Bathymetry

    outfile: The full path and filename to the output file to generate. This
      will be taken to Windows for use with gm_tiff2ktoqq.tcl.

  Options:

    tif_glob= A file glob that can be used to more specifically select the
      tiff files from their directory. Default is *.tif.

    pbd_glob= A file glob that can be used to more specifically select the
      pbd files from their directory. Default is *.pbd.
*/
  local e, n;
  fix_dir, tif_dir;
  fix_dir, pbd_dir;

  default, tif_glob, "*.tif";
  default, pbd_glob, "*.pbd";

  // Source files
  files = find(tif_dir, searchstr=tif_glob);

  // Scan pbds for exents
  extents = calculate_qq_extents(pbd_dir, mode=mode, searchstr=pbd_glob);

  qqcodes = h_new();

  // Iterate over the source files to determine the qq tiles
  write, "Scanning source files to generate list of QQ tiles...";
  for(i = 1; i<= numberof(files); i++) {
    basefile = file_tail(files(i));
    bbox = dt2utm(basefile, bbox=1);

    // Get four-corner qqcodes
    tile_qqcodes = utm2qq_names(bbox([2,2,4,4]), bbox([1,3,1,3]),
      bbox([5,5,5,5]));

    // Only keep qqcodes that are in extents
    tile_qqcodes = set_intersection(tile_qqcodes, h_keys(extents));

    for(j = 1; j <= numberof(tile_qqcodes); j++) {
      qlist = [];
      if(h_has(qqcodes, tile_qqcodes(j))) {
        qlist = grow(qqcodes(tile_qqcodes(j)), basefile);
      } else {
        qlist = [basefile];
      }
      h_set, qqcodes, tile_qqcodes(j), qlist;
    }
  }

  write, "Creating TCL input...";
  qqkeys = h_keys(qqcodes);
  f = open(outfile, "w");
  write, f, format="%s\n", "set ::qqtiles {";
  for(i = 1; i <= numberof(qqkeys); i++) {
    bbox = h_get(extents, qqkeys(i));
    write, f, format="  { {%s}\n", qqkeys(i);
    write, f, format="    {%.10f,%.10f,%.10f,%.10f}\n",
      bbox.w, bbox.s, bbox.e, bbox.n;
    for(j = 1; j <= numberof(qqcodes(qqkeys(i))); j++) {
      write, f, format="    {%s}\n", qqcodes(qqkeys(i))(j);
    }
    write, f, format="  }%s", "\n";
  }
  write, f, format="%s\n", "}";
}
