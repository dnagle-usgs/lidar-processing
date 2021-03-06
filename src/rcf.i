// vim: set ts=2 sts=2 sw=2 ai sr et:

func rcf(jury, w, mode=) {
/* DOCUMENT result = rcf(jury, w, mode=)
  Generic random consensus filter. The jury is the array to test for
  consensus, and w is the window range which things can vary within.

  Parameters:
    jury: An array of points within which to find a consensus.
    w: The window width to search with.

  Options:
    mode= This specifies what kind of output you would like to receive. There
      are three options.

      For each mode, we'll use this as example data to illustrate:
        jury = double([100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150])
        w = 6

      mode=0 (default)
        Returns an array consisting of two elements where the first is the
        minimum value in the window and the second is the number of votes.

        For example:

          > rcf(jury, w)
          [98, 10]

        98 is the minimum value in the consensus window; 10 points voted
        for that window.

      mode=2
        Returns an array consisting of two pointers where the first points
        to an index list into jury for the points in the window and the
        second points to the number of votes.

        For example:

          > result = rcf(jury, w, mode=2)
          > result
          [0x835ec0,0x659b18]
          > *result(1)
          [1,2,3,4,6,7,8,10,13,15]
          > *result(2)
          10

        Points 1,2,3,4,6,7,8,10,13,15 in jury were in the window, which is
        a total of 10 points.

  References:
    Martin A. Fischler and Robert C. Bollese (June 1981). "Random Sample
      Consensus: A Paradigm for Model Fitting with Applications to Image
      Analysis and Automated Cartography". Communications of the ACM 25:
      381-395. http://dx.doi.org/10.1145/358669.358692
*/
  default, mode, 0;
  jsrt = jury(sort(jury));
  jurysize = numberof(jury);
  bestvote = besti = 0;
  // Iterate over each point in the jury treating it as the lower bound for
  // search window.
  for(i = 1, j = 1; j <= jurysize; i++) {
    upper = jsrt(i) + w;
    // For the point, determine where the upper bound of the window falls.
    // j actually is the index above the upper bound (which may be outside
    // the range of our data)
    while(j <= jurysize && jsrt(j) < upper)
      j++;
    // Calculate the number of votes in this window. If it's better than our
    // recorded best, make it our new best.
    vote = j - i;
    if(vote >= bestvote) {
      bestvote = vote;
      besti = i;
    }
  }
  // Use the best vote found to define the upper and lower bounds, then return
  // whatever the user requested.
  lower = besti;
  upper = besti + bestvote - 1;
  if(mode == 0) {
    return [jsrt(lower), bestvote];
  } else if(mode == 2) {
    idx = where(jury >= jsrt(lower) & jury <= jsrt(upper));
    return [&idx, &bestvote];
  } else {
    error, "invalid mode";
  }
}

func rcf_2d(x, z, buf, fw) {
/* DOCUMENT idx = rcf_2d(x, z, buf, fw)
  Two-dimensional RCF. Each point (x,z) looks at a neighborhood of points
  within a window of size BUF along the x-axis to see if the z coordinate falls
  within the winning jury selected using RCF against the Z coordiantes using a
  filter width of FW.

  Parameters:
    x: Coordinates along x-axis
    z: Coordinates along z-axis
    buf: Buffer size along x-axis. (Points within +/-(buf/2) of x coordinate
      considered for jury.)
    fw: Filter width. This is the width along the z-axis that the RCF searched
      for a winning jury.

  Returns:
    idx, an index into X and Z of the points that passed the filter
*/
  // Edge cases
  if(!numberof(x)) return [];
  if(numberof(x) == 1) return [1];

  if(numberof(x) != numberof(z) || dimsof(x)(1) != dimsof(z)(1))
    error, "X and Z input must have matching dimensions and size"

  // Cut buf in half, so that it's +/- point
  buf = buf/2.;

  // Sort input along X-axis for efficiency
  srt = sort(x);
  x = x(srt);
  z = z(srt);

  b0 = b1 = 1;
  count = numberof(x);
  keep = array(short(0), count);
  for(i = 1; i <= count; i++) {
    // Find the bounds along x-axis for this point
    while(x(b0) < x(i) - buf) b0++;
    while(b1 <= count && x(b1) <= x(i) + buf) b1++;
    b1--;

    // Apply RCF filter and see if z-coordinate is in the winning jury window
    zmin = rcf(z(b0:b1), fw, mode=0)(1);
    if(zmin <= z(i) && z(i) <= zmin+fw)
      keep(i) = 1;
  }

  // Need to invert sorting to match original ordering of coordinates
  result = array(short, count);
  result(srt) = keep;
  return where(result);
}

func moving_rcf(yy, fw, n) {
/* DOCUMENT moving_rcf(yy, fw, n)
  This function filters a vector of data (yy) with rcf using a filter width of
  (fw) and a jury of +/-(n). It returns an index list to yy of the points
  within the filter. This is used in transect.i.

  SEE ALSO: rcf, transect
*/
  np = numberof(yy);
  edt = array(0, np);
  for (i=n+1; i<= np-n; i++) {
    rv = rcf(yy(i-n:i+n), fw, mode=0);
    if (rv(2) >= 2) {
      v = yy(i);
      ll = rv(1);
      ul = ll + fw;
      if((v >= ll) && (v <= ul)) {
        edt(i) = 1;
      }
    }
  }
  return where(edt);
}

func old_gridded_rcf(x, y, z, w, buf, n) {
/* DOCUMENT idx = old_gridded_rcf(x, y, z, w, buf, n)
  Returns an index into the x/y/z data for those points that survive the RCF
  filter with the given parameters.

  This filter works by applying a grid to the data. The grid's origins are at
  the minimum x and y value in the point cloud. Grid lines are applied at
  intervals defined by buf. The points in each grid square are then put
  through the rcf filter with the given w parameter; if at least n points vote
  for the winning window, then those points in the window get kept. All other
  points are discarded.

  If a point falls on a grid line, then it gets tested for each of the grid
  squares it touched. If it survives *any* of those squares, it gets kept.

  This filter is effectively identical to the gridded RCF filter used in ALPS
  through the end of 2009 as implemented in rcfilter_eaarl_pts. There are two
  key differences, though:
    - For points that fall on grid boundaries, rcfilter_eaarl_pts will
      include the point multiple times if it survives multiple grid squares.
      This function will only include the point once.
    - The implementation in this function is about twice as fast as the one
      in rcfilter_eaarl_pts.

  This function is deprecated. Please used gridded_rcf instead.
*/
  // Create the grid, using the minimum x/y as our origin
  xmin = x(min);
  xmax = x(max);
  ymin = y(min);
  ymax = y(max);

  ngridx = long(ceil((xmax-xmin)/buf));
  ngridy = long(ceil((ymax-ymin)/buf));

  if(ngridx > 1)
    xgrid = xmin + span(0, buf*(ngridx-1), ngridx);
  else
    xgrid = [xmin];

  if(ngridy > 1)
    ygrid = ymin + span(0, buf*(ngridy-1), ngridy);
  else
    ygrid = [ymin];

  // keep is our result... anything set to 1 gets kept
  keep = array(char(0), dimsof(x));

  // Iterate through grid squares
  for(i = 1; i <= ngridy; i++) {
    q = where(y >= ygrid(i));
    if(numberof(q)) {
      qq = where(y(q) <= ygrid(i)+buf);
      q = numberof(qq) ? q(qq) : [];
    }
    if(!numberof(q))
      continue;

    for(j = 1; j <= ngridx; j++) {
      indx = where(x(q) >= xgrid(j));
      if(numberof(indx)) {
        iindx = where(x(q(indx)) <= xgrid(j)+buf);
        indx = numberof(iindx) ? q(indx(iindx)) : [];
      }
      if(!numberof(indx))
        continue;

      sel_ptr = rcf(z(indx), w, mode=2);

      if(*sel_ptr(2) < n)
        continue;

      keep(indx(*sel_ptr(1))) = 1;
    }
  }

  return where(keep);
}

func query_gridded_rcf(data, buf=, w=, n=, iwin=, owin=, mode=, xp=, yp=,
passpts=, failpts=, boxlines=, relx=) {
/* DOCUMENT query_gridded_rcf, data, buf=, w=, n=, iwin=, owin=, mode=, xp=,
   yp=, passpts=, failpts=, boxlines=
  Enters an interactive mode that lets you click on a point cloud plot to see
  how the gridded RCF performs.

  Parameters:
    data: An array of point cloud data
  Options:
    buf= The horizontal buffer size, in cm.
    w= The vertical window width, in cm.
    n= The minimum number of winners. Default: 3
    iwin= The input window. Default: 5
    owin= The output window. Default: 6
    mode= Data/display mode. Default: "fs"
    xp= Instead of query, show just show as if you clicked for xp
    yp= Instead of query, show just show as if you clicked for yp
    passpts= See plot_gridded_rcf
    failpts= See plot_gridded_rcf
    boxlines= See plot_gridded_rcf
    relx= See plot_gridded_rcf
*/
  default, iwin, 5;
  default, owin, 6;

  local x, y, z;
  data2xyz, data, x, y, z, mode=mode;
  if(xp || yp) {
    plot_gridded_rcf, x, y, z, buf, w, n, xp=xp, yp=yp, win=owin,
      passpts=passpts, failpts=failpts, boxlines=boxlines, relx=relx;
    return;
  }

  wbkp = current_window();
  continue_interactive = 1;
  while(continue_interactive) {
    write, format="\nWindow %d: Left to select Y. Ctrl-Left to select X. Anything else aborts.\n", iwin;

    window, iwin;
    spot = mouse(1, 1, "");

    xp = yp = [];
    if(mouse_click_is("ctrl+left", spot)) {
      write, format="Selected x coordinate of: %.2f\n", spot(1);
      xp = spot(1);
    } else if(mouse_click_is("left", spot)) {
      write, format="Selected y coordinate of: %.2f\n", spot(2);
      yp = spot(2);
    } else {
      continue_interactive = 0;
    }

    if(xp || yp) {
      plot_gridded_rcf, x, y, z, buf, w, n, xp=xp, yp=yp, win=owin,
        passpts=passpts, failpts=failpts, boxlines=boxlines, relx=relx;
    }
  }

  window_select, wbkp;
}

func plot_gridded_rcf(x, y, z, buf, width, n, xp=, yp=, win=, passpts=,
failpts=, boxlines=, relx=) {
/* DOCUMENT plot_gridded_rcf, x, y, z, buf, width, n, xp=, yp=, win=, passpts=,
   failpts=, boxlines=, relx=
  Helper function for query_gridded_rcf. This plots a single row or column from
  the gridded RCF algorithm to show what passed and failed the filter.

  Parameters:
    x, y, z: The point cloud coordinates
    width, buf, n: The gridded RCF parameters (in cm)
      n defaults to 3, the others have no defaults
  Options:
    xp= The coordinate that selects which column to plot
    yp= The coordinate that selects which row to plot.
      NOTE: You must select either xp or yp, but not both.
    win= The window to plot in. Default: 6
    passpts= Styling options for points that pass.
        passpts="square blue 0.2"   Default
    failpts= Styling options for points that fail.
        failpts="square black 0.1"  Default
    boxlines= Styling options for passing buffer box lines.
        boxlines="dot black 1"      Default
    relx= If enabled, the x-axis in the plot will be relative meters instead of
      actual meters.
*/
  default, passpts, "square blue 0.2";
  default, failpts, "square black 0.1";
  default, boxlines, "dot black 1";
  parse_plopts, passpts, ptype, pcolor, psize;
  parse_plopts, failpts, ftype, fcolor, fsize;
  parse_plopts, boxlines, btype, bcolor, bsize;

  default, win, 6;
  default, relx, 0;
  default, n, 3;
  width /= 100.;
  buf /= 100.;

  if(is_void(yp) && !is_void(xp)) {
    yp = xp;
    xp = [];

    tmp = x;
    x = y;
    y = tmp;
    tmp = [];
  }
  if(is_void(yp) || !is_void(xp)) {
    error, "must provide either yp= or xp=";
  }
  w = where(long(y/buf) == long(yp/buf));
  if(is_void(w)) error, "no points match";
  x = x(w);
  z = z(w);

  if(!is_void(win)) {
    wbkp = current_window();
    window, win;
  }
  fma;

  xgrid = long(x/buf);
  xgrid_uniq = set_remove_duplicates(xgrid);
  nxg = numberof(xgrid_uniq);
  offset = relx ? xgrid_uniq(min) * buf : 0;
  for(i = 1; i <= nxg; i++) {
    w = where(xgrid == xgrid_uniq(i));
    zw = z(w);
    xw = x(w) - offset;

    lbound = rcf(zw, width)(1);
    ubound = lbound + width;

    x0 = xgrid_uniq(i) * buf - offset;
    x1 = x0 + buf;

    match = lbound <= zw & zw < ubound;
    w = where(match);
    if(numberof(w) > n) {
      plmk, zw(w), xw(w), msize=psize, marker=ptype, color=pcolor;
      w = where(!match);
      if(numberof(w))
        plmk, zw(w), xw(w), msize=fsize, marker=ftype, color=fcolor;
    } else {
      plmk, zw, xw, msize=fsize, marker=ftype, color=fcolor;
    }

    plg, [ubound, lbound, lbound, ubound, ubound], [x0, x0, x1, x1, x0],
      color=bcolor, type=btype, width=bsize;
  }

  if(!is_void(win)) window_select, wbkp;
}

func gridded_rcf(x, y, z, w, buf, n, progress=, progress_step=, progress_count=) {
/* DOCUMENT idx = gridded_rcf(x, y, z, w, buf, n, progress=)
  Returns an index into the x/y/z data for those points that survive the RCF
  filter with the given parameters.

  This filter works by applying a grid to the data. Grid lines are at
  intervals defined by buf, starting at 0. The point elevations for each grid
  square are then put through the rcf filter with the given w parameter; if at
  least n points vote for the winning window, then those points get kept. All
  other points are discarded.

  This filter is very similar to the gridded RCF filter used in ALPS
  through the end of 2009 as implemented in rcfilter_eaarl_pts.
    - The location of grid lines is determined solely by the buf parameter.
      In the old filter, the grid lines were determined by the minimum x and
      y as well as the buf. Thus, with the new filter you can reconstruct the
      grid used after the fact, whereas with the old one you couldn't (since
      you may have discarded the minimum x and y points).
    - Each point falls in exactly one grid square. In the old filter, some
      points fell in multiple grid squares if they fell exactly on a grid
      line. This allowed them to get multiple chances for inclusion in the
      final result (and also led to duplication of those points in the final
      result).
    - The algorithm used in this function is about five times faster as the
      one in rcfilter_eaarl_pts (and is about twice as fast as
      old_gridded_rcf).

  SEE ALSO: old_gridded_rcf
*/
  if(progress) {
    progress_manage = !is_void(progress_step);
    default, progress_step, 1;
    default, progress_count, 1;
    // Shift from 1-based to 0-based
    progress_step--;
  }

  // We want to ensure that x has a smaller range than y so that we end up
  // doing fewer set_remove_duplicates calls.
  if(x(max) - x(min) > y(max) - y(min))
    swap, x, y;

  // Calculate grid for each point
  xgrid = long(x/buf);
  ygrid = long(y/buf);

  // Figure out how many x-columns we have
  xgrid_uniq = set_remove_duplicates(xgrid);
  xgrid_count = numberof(xgrid_uniq);

  // keep is our result... anything set to 1 gets kept
  keep = array(char(0), dimsof(x));

  if(!progress_manage)
    status, start, msg="Running RCF filter...";

  // iterate over each x-column
  for(xgi = 1; xgi <= xgrid_count; xgi++) {
    // Extract indices for this column; abort if we mysteriously have none
    curxmatch = where(xgrid == xgrid_uniq(xgi));
    if(is_void(curxmatch))
      continue;

    // Figure out how many y-rows we have
    ygrid_uniq = set_remove_duplicates(ygrid(curxmatch));
    ygrid_count = numberof(ygrid_uniq);

    // Iterate over rows
    for(ygi = 1; ygi <= ygrid_count; ygi++) {
      // Extract indices for row+col; abort if we mysteriously have none
      curymatch = where(ygrid(curxmatch) == ygrid_uniq(ygi));
      if(is_void(curymatch))
        continue;
      idx = curxmatch(curymatch);

      // Run RCF on the elevations for this grid square
      result = rcf(z(idx), w, mode=2);

      if(progress)
        status, progress,
          xgi - 1 + double(ygi)/ygrid_count + xgrid_count * progress_step,
          xgrid_count * progress_count;

      if(*result(2) < n)
        continue;

      keep(idx(*result(1))) = 1;
    }
  }
  if(!progress_manage)
    status, finished;

  return where(keep);
}

func multi_gridded_rcf(x, y, z, w, buf, n, factor, progress=) {
/* DOCUMENT idx = multi_gridded_rcf(x, y, z, w, buf, n, factor, progress=)
  Returns an index into the x/y/z data for those points that survive the filter
  with the given parameters.

  This is a wrapper around gridded_rcf. The factor parameter specifies how to
  more evenly distribute the grid. This algorithm is best explained by way of
  example:

    Suppose buf is 1 meter and factor=4. In this case, gridded_rcf will be run
    16 times. Each time it will use a 1 meter grid, but the grid will be offset
    in the x and y directions in 25cm increments. So the first run will be
    offset by 0,0. The second run will be offset by 0,25. The third by 0,50.
    And so on.

  The end result is that each point gets considered in a wider and fairer set
  of contexts that more evenly represent its neighborhood. For a 1 meter cell,
  an ideal point would be in the center so that it will consider points within
  50cm in any direction. However, in practice, gridded_rcf will result in
  points that aren't anywhere near the center. For instance, a point near a
  corner might consider points 10cm in one direction and 90cm in another. In
  the example above, that effect is evened out so that the point would instead
  look 85cm in one direction and 90cm in another (though in separate contexts),
  balancing it out better.

  The run time of this is proportional to the square of the factor. A factor of
  2 will take 4x as long as gridded_rcf. A factor of 10 will take 100x as long
  as gridded_rcf.
*/
  buf = double(buf);
  keep = array(char(0), dimsof(x));
  progress_step = 0;
  progress_count = factor * factor;
  if(progress)
    status, start, msg="Running RCF filter...";
  for(i = 0; i < factor; i++) {
    xshift = buf * i / factor;
    for(j = 0; j < factor; j++) {
      progress_step++;
      yshift = buf * j / factor;
      idx = gridded_rcf(x+xshift, y+yshift, z, w, buf, n, progress=progress,
        progress_step=progress_step, progress_count=progress_count);
      keep(idx) = 1;
    }
  }
  if(progress)
    status, finished;
  return where(keep);
}

func rcf_filter_eaarl(eaarl, mode=, rcfmode=, buf=, w=, n=, factor=, idx=,
progress=) {
/* DOCUMENT filtered = rcf_filter_eaarl(data, mode=, rcfmode=, buf=, w=, n=,
   factor=, idx=, progress=)
  Applies an RCF filter to eaarl data.

  Parameter:
    eaarl: An array of data in an ALPS data structure.

  Options:
    mode= Specifies which data mode to use for the data. Can use any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)
        rcfmode="mgrcf"   Use multi_gridded_rcf (experimental)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 500 cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 30 cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    factor= The meaning of this parameter varies depending on rcfmode=.
      For grcf and rcf, it is ignored. For mgrcf, it is passed through as
      factor. Default varies by rcfmode.
        factor=2      Default for rcfmode="mgrcf"

    idx= Specifies that the index into the data should be returned instead of
      the filtered data itself. Settings:
        idx=0    Return the filtered data (default)
        idx=1    Return the index into the data

    progress= Set to 1 to display progress in the status bar.
*/
  local x, y, z;

  default, buf, 500;
  default, w, 30;
  default, n, 3;
  default, rcfmode, "grcf";
  default, idx, 0;

  if(rcfmode == "mgrcf") default, factor, 2;

  data2xyz, eaarl, x, y, z, mode=mode;

  buf /= 100.;
  w /= 100.;

  keep = [];

  if(rcfmode == "grcf")
    keep = gridded_rcf(x, y, z, w, buf, n, progress=progress);
  else if(rcfmode == "rcf")
    keep = old_gridded_rcf(x, y, z, w, buf, n);
  else if(rcfmode == "mgrcf")
    keep = multi_gridded_rcf(x, y, z, w, buf, n, factor, progress=progress);
  else
    error, "Please specify a valid rcfmode=.";
  x = y = z = [];

  if(idx)
    return keep;

  return numberof(keep) ? eaarl(keep) : [];
}

func rcf_filter_eaarl_file(file_in, file_out, mode=, rcfmode=, buf=, w=, n=,
factor=, prefilter_min=, prefilter_max=, verbose=) {
/* DOCUMENT rcf_filter_eaarl_file(file_in, file_out, mode=, rcfmode=, buf=, w=,
   n=, factor=, prefilter_min=, prefilter_max=, verbose=)

  Applies the RCF filter to a file.

  The variable name in the output file will be the same as in the input file,
  except:
    - any _v or _b suffix is removed
    - the data mode and filter mode are appended
  So a variable name of "example_v" will become "example_fs_grcf" with the
  default settings.

  Parameters:

    file_in: File to load as input.

    file_out: File to create as input. (If it already exists, it will be
      clobbered silently.)

  Options:

    mode= Specifies which data mode to use for the data. Can be any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    prefilter_min= Specifies a minimum value for the elevation values, in
      meters. Points below this value are discarded prior to filtering.

    prefilter_max= Specifies a maximum value for the elevation values, in
      meters. Points above this value are discarded prior to filtering.

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 700cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 200cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    factor= Passed through to rcf alg depending on which rcfmode is used.

    verbose= Specifies how talkative the function should be as it runs. Valid
      settings:
        verbose=1   Shows progress as the file is filtered (default)
        verbose=0   Be completely silent
*/
  default, verbose, 1;
  default, buf, 700;
  default, w, 200;
  default, n, 3;
  default, mode, "fs";
  default, rcfmode, "grcf";

  local vname;
  if(verbose)
    write, format=" %s", "loading...";
  data = pbd_load(file_in, , vname);

  if(is_void(data)) {
    if(verbose)
      write, "no data found";
    return;
  }

  if(verbose)
    write, format=" %s", "filtering...";

  // Apply prefiltering, if relevant
  if(!is_void(prefilter_min) || !is_void(prefilter_max))
    data = filter_bounded_elv(data, lbound=prefilter_min,
        ubound=prefilter_max, mode=mode);

  // Apply rcf filter
  data = rcf_filter_eaarl(data, buf=buf, w=w, n=n, mode=mode,
      rcfmode=rcfmode, factor=factor);

  if(is_void(data)) {
    if(verbose)
      write, "all points eliminated";
      return;
  }

  if(verbose)
    write, format=" %s", "saving...";
  vname = regsub("_(f|v|b)$", vname, "");
  vname += swrite(format="_%s_%s", mode, rcfmode);
  mkdirp, file_dirname(file_out);
  pbd_save, file_out, vname, data;

  if(verbose)
    write, "done";
}

func rcf_grid(z, w, buf, n, nodata=, mask=, action=) {
/* DOCUMENT rcf_grid(z, w, buf, n, nodata=, mask=, action=)
  Runs a gridded RCF filter over a 2-dimensional array of values, an array
  where dimsof(z) is [2,NCOLS,NROWS].

  For each cell in Z, the neighborhood of width/height BUF centered on that
  point are used as an RCF jury. If the point is among the winners for the
  RCF, it is left as is. If it is not among the winners, then the outcome is
  as specified by ACTION.

  When working near the edges of the array, the neighborhood may be smaller
  than the specified BUF as its edges are clipped to Z's extent. (A 5x5
  neightborhood for point 1,2 will be clipped down to a 3x4 neighborhood, for
  instance.)

  Most ACTIONs will yield a result that is a modified form of the input Z.
  When running the filter, all calculations are made on the original Z array.
  So for example, for the default action="avgwin", the average values that
  replace the failed cells does *not* impact the rest of the filtering.

  Parameters:
    z: A two-dimensional array of values.
    w: The RCF window to use. The winners of each jury will fall within a
      window of this size.
    buf: The buffer to use when determining a cell's neighborhood. This must
      be an odd integer. For example, 3 would define a 3x3 neighborhood (one
      cell on each side of the target cell). This can also be provided as a
      two-element array of [col_buf, row_buf] if you want to use different
      size buffers for rows versus columns.
    n: The number of winners required for a successful RCF. If fewer than
      this many winners are found, then the cell is left alone (as if it had
      passed the filter).

  Options:
    nodata= The nodata value used in the Z array. Any cells with this value
      will be disregarded during filtering. If not provided, it is assumed
      that all cells contain valid values. (If not provided and
      action="remove", then the nodata value is the minimum Z value minus
      1.)
    mask= A mask defining which cells should be filtered. This mask should
      match the dimensions of Z and should be 1 where cells should be
      filtered and 0 where they should not. Cells that are not filtered are
      treated much as a nodata= cell is treated.
    action= Specifies what to do with cells that fail the filter.
        action="avgwin"   Replace with the average of the winners (default)
        action="minwin"   Replace with the minimum winner
        action="maxwin"   Replace with the maximum winner
        action="medwin"   Replace with the median of the winners
        action="clampwin" Replace with the winner closest to the cell's value
        action="remove"   Replace with the nodata value
        action="mask"     Return a mask array where 1 represents the failures
*/
  // Validations and defaults

  if(dimsof(z)(1) != 2)
    error, "data must be two-dimensional";

  if(!is_integer(buf))
    error, "buf must be an integer";
  if(numberof(buf) == 1) {
    rbuf = cbuf = buf;
  } else if(numberof(buf) == 2) {
    cbuf = buf(1);
    rbuf = buf(2);
  } else {
    error, "buf must be scalar or two-element array";
  }

  if(rbuf % 2 != 1 || cbuf % 2 != 1)
    error, "buf must be odd value";

  if(is_void(mask))
    mask = array(char(1), dimsof(z));
  if(is_void(nodata))
    nodata = z(*)(min) - 1;
  default, action, "avgwin";

  if(dimsof(mask)(1) != 2 || nallof(dimsof(mask) == dimsof(z)))
    error, "mask= must have same dimensions as input";
  if(!is_integer(mask))
    error, "mask= must be integers";

  // Ensure we have a copy and aren't modifying the original in-place
  z = noop(z);
  result = noop(z);

  if(action=="mask")
    result = array(char(0), dimsof(z));

  // rbuf and cbuf are originally the total buffer width; divide by 2 (and
  // discard remainder) to turn into buffer on either side of the current cell
  rbuf /= 2;
  cbuf /= 2;

  ncol = dimsof(z)(2);
  nrow = dimsof(z)(3);

  for(row = 1; row <= nrow; row++) {
    row0 = max(1, row-rbuf);
    row1 = min(nrow, row+rbuf);
    for(col = 1; col <= ncol; col++) {
      if(!mask(col,row))
        continue;
      if(z(col,row) == nodata)
        continue;

      col0 = max(1, col-cbuf);
      col1 = min(ncol, col+cbuf);

      jury = z(col0:col1,row0:row1);
      idx = where(mask(col0:col1,row0:row1) > 0 & jury != nodata);

      ptr = rcf(jury(idx), w, mode=2);
      if(*ptr(2) < n)
        continue;

      // Note which cells were winners, then determine if that includes the
      // current cell
      keep = array(char(0), dimsof(jury));
      keep(idx(*ptr(1))) = 1;

      jrow = row - row0 + 1;
      jcol = col - col0 + 1;

      if(keep(jcol, jrow))
        continue;

      winners = jury(where(keep));

      if(action == "avgwin")
        result(col,row) = winners(avg);
      else if(action == "minwin")
        result(col,row) = winners(min);
      else if(action == "maxwin")
        result(col,row) = winners(max);
      else if(action == "medwin")
        result(col,row) = median(winners);
      else if(action == "clampwin")
        result(col,row) = median([z(col,row), winners(min), winners(max)]);
      else if(action == "remove")
        result(col,row) = nodata;
      else if(action == "mask")
        result(col,row) = 1;
      else
        error, "invalid action";
    }
  }

  return result;
}

func batch_rcf(dir, searchstr=, automerge=, files=, outdir=, update=, mode=,
prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, factor=, meta=,
makeflow_fn=, norun=) {
/* DOCUMENT batch_rcf, dir, searchstr=, automerge=, files=, outdir=, update=,
   mode=, prefilter_min=, prefilter_max=, rcfmode=, buf=, w=, n=, factor=,
   meta=, makeflow_fn=, norun=

  This iterates over each file in a set of files and applies an RCF filter to
  its data.

  If called as a subroutine, the jobs will be run with Makeflow. If called as a
  function, the configuration that would have been passed to Makeflow is
  returned instead.

  Parameters:
    dir: The directory containing the files you wish to filter.

  Options:
    searchstr= The search string to use to locate the files you with to
      filter. Examples:
        searchstr="*.pbd"    (default)
        searchstr="*_v.pbd"
        searchstr="*n88*_v.pbd"

    automerge= This is a special-case convenience setting that includes a call
      to batch_automerge_tiles. It can only be run if your search string ends
      with _v.pbd or _b.pbd. After running the merge, the search string will
      get updated to replace _v.pbd with _v_merged.pbd and _b.pbd with
      _b_merged.pbd. (So "*_v.pbd" becomes "*_v_merged.pbd", whereas
      "*w84*_v.pbd" becomes "*w84*_v_merged.pbd".) It is an error to use this
      setting with a search string that does not fit these requirements. Note
      that you CAN NOT "skip" the writing of merged files if you want to filter
      merged data. Settings:
        automerge=0     Do not perform an automerge. (default)
        automerge=1     Merge tiles together before filtering.

    files= Manually provides a list of files to filter. This will result in
      searchstr= being ignored and is not compatible with automerge=1.

    outdir= Specify an output directory. By default output files are created
      alongside input files, but outdir= allows you to dump them all in a
      different folder instead.

    update= Specifies that this is an update run and that existing files
      should be skipped. Settings:
        update=0    Overwrite output files if they exist.
        update=1    Skip output files if they exist.

    mode= Specifies which data mode to use for the data. Can be any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    prefilter_min= Specifies a minimum value for the elevation values, in
      meters. Points below this value are discarded prior to filtering.

    prefilter_max= Specifies a maximum value for the elevation values, in
      meters. Points above this value are discarded prior to filtering.

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 700cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 200cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    factor= Passed through to underlying rcf alg depending on which rcfmode is
      used.

    meta= Specifies whether the filter parameters should be included in the
      output filename. Settings:
        meta=0   Do not include the filter parameters in the file name.
        meta=1   Include the filter parameters in the file name. (default)

    makeflow_fn= The filename to use when writing out the makeflow. Ignored if
      called as a function. If not provided, a temporary file will be used then
      discarded.

    norun= Don't actually run makeflow; just create the makeflow file.
        norun=0   Runs makeflow, default
        norun=1   Doesn't run makeflow
*/
  default, searchstr, "*.pbd";
  default, update, 0;
  default, automerge, 0;
  default, buf, 700;
  default, w, 200;
  default, n, 3;
  default, meta, 1;
  default, mode, "fs";
  default, rcfmode, "grcf";
  if(rcfmode == "mgrcf") default, factor, 2;

  t0 = array(double, 3);
  timer, t0;

  conf = save();

  if(automerge) {
    if(!is_void(files))
      error, "You cannot use automerge=1 if you are specifying files=."
    // We can ONLY merge if our searchstr ends with *_v.pbd or *_b.pbd.
    // If it does... then merge, and update our search string.
    if(strlen(searchstr) < 7)
      error, "Incompatible setting for searchstr= with automerge=1. See \
        documentation.";
    sstail = strpart(searchstr, -6:);
    if(sstail == "*_v.pbd") {
      conf = mf_automerge_tiles(dir, searchstr=searchstr, update=update);
    } else if(sstail == "*_b.pbd") {
      conf = mf_automerge_tiles(dir, searchstr=searchstr, update=update);
    } else {
      error, "Invalid setting for searchstr= with automerge=1. See \
        documentation."
    }

    files = array(string, conf(*));
    for(i = 1; i <= conf(*); i++)
      files(i) = conf(noop(i)).output;
  }

  if(is_void(files))
    files = find(dir, searchstr=searchstr);
  count = numberof(files);

  if(!count) {
    return;
  }

  // Variable name -- same as input, but add _rcf (or _grcf, etc.)
  // File name -- same as input, but lop off extension and add rcf settings
  vname = [];
  for(i = 1; i <= count; i++) {
    file_in = files(i);
    file_out = file_rootname(file_in);
    // _fs, _be, _ba
    file_out += "_" + mode;
    // _b700_w50_n3
    if(meta) {
      file_out += swrite(format="_b%d_w%d_n%d", buf, w, n);
      if(rcfmode == "mgrcf")
        file_out += swrite(format="_f%d", factor);
    }
    // _grcf, _ircf, _rcf
    file_out += "_" + rcfmode;
    // _mf
    // .pbd
    file_out += ".pbd";

    if(outdir)
      file_out = file_join(outdir, file_tail(file_out));

    if(file_exists(file_out)) {
      if(update) {
        continue;
      } else {
        remove, file_out;
      }
    }

    options=save(
      string(0), [],
      "file-in", file_in,
      "file-out", file_out,
      mode, rcfmode, factor,
      buf=swrite(format="%d", buf),
      w=swrite(format="%d", w),
      n=swrite(format="%d", n),
      "prefilter-min", prefilter_min,
      "prefilter-max", prefilter_max
    );

    save, conf, string(0), save(
      input=file_in,
      output=file_out,
      command="job_rcf_eaarl",
      options=options
    );
  }

  if(!am_subroutine())
    return conf;

  makeflow_run, conf, makeflow_fn, interval=15, norun=norun;

  timer_finished, t0;
}
