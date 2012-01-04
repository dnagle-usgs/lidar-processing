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

      mode=1
        Returns an array consisting of two elements where the first is the
        average value in the window and the second is the number of votes.

        For example:

          > rcf(jury, w, mode=1)
          [100.1, 10]

        100.1 is the average value in the window; 10 points voted for that
        window.

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
// Original: C. W. Wright 6/15/2002 wright@lidar.wff.nasa.gov
// Rewritten in linear time David Nagle 2009-12-21
  default, mode, 0;
  jsrt = jury(sort(jury));
  jurysize = numberof(jury);
  bestvote = besti = bestj = 0;
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
  } else if(mode == 1) {
    return [jsrt(lower:upper)(avg), bestvote];
  } else if(mode == 2) {
    idx = where(jury >= jsrt(lower) & jury <= jsrt(upper));
    return [&idx, &bestvote];
  }
}

func moving_rcf(yy, fw, n) {
/* DOCUMENT moving_rcf(yy, fw, n)
  This function filters a vector of data (yy) with rcf using a filter width of
  (fw) and a jury of +/-(n). It returns an index list to yy of the points
  within the filter. This is used in transect.i.

  SEE ALSO: rcf, transect, mtransect
  Original:  W. Wright 9/30/2003
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

func gridded_rcf(x, y, z, w, buf, n) {
/* DOCUMENT idx = gridded_rcf(x, y, z, w, buf, n)
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
      if(*result(2) < n)
        continue;

      keep(idx(*result(1))) = 1;
    }
  }

  return where(keep);
}

func rcf_filter_eaarl(eaarl, mode=, clean=, rcfmode=, buf=, w=, n=, idx=) {
/* DOCUMENT filtered = rcf_filter_eaarl(data, mode=, clean=, rcfmode=, buf=,
  w=, n=, idx=)
  Applies an RCF filter to eaarl data.

  Parameter:
    eaarl: An array of data in an ALPS data structure.

  Options:
    mode= Specifies which data mode to use for the data. Can use any setting
      valid for data2xyz.
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathymetry (submerged topo)

    clean= Specifies whether the data should be cleaned first using
      test_and_clean. Settings:
        clean=0     Do not clean the data
        clean=1     Clean the data (default)

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 500 cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 30 cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.

    idx= Specifies that the index into the data should be returned instead of
      the filtered data itself. Note that this setting is incompatible with
      clean=1 and will cause it to default to clean=0. Forcibly setting
      idx=1 and clean=1 is an error. Settings:
        idx=0    Return the filtered data (default)
        idx=1    Return the index into the data
*/
  local x, y, z;

  default, buf, 500;
  default, w, 30;
  default, n, 3;
  default, rcfmode, "grcf";
  default, idx, 0;
  default, clean, !idx;

  if(clean && idx)
    error, "You cannot set clean=1 and idx=1 together.";

  if(clean)
    eaarl = test_and_clean(unref(eaarl));

  data2xyz, eaarl, x, y, z, mode=mode;

  buf /= 100.;
  w /= 100.;

  keep = [];

  if(rcfmode == "grcf")
    keep = gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else if(rcfmode == "rcf")
    keep = old_gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else
    error, "Please specify a valid rcfmode=.";

  if(idx)
    return keep;

  return numberof(keep) ? eaarl(keep) : [];
}

func rcf_filter_eaarl_file(file_in, file_out, mode=, clean=, rcfmode=, buf=,
w=, n=, prefilter_min=, prefilter_max=, verbose=) {
/* DOCUMENT rcf_filter_eaarl_file(file_in, file_out, mode=, clean=, rcfmode=,
  buf=, w=, n=, prefilter_min=, prefilter_max=, verbose=)

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

    clean= Specifies whether the data should be cleaned first using
      test_and_clean. Settings:
        clean=0     Do not clean the data.
        clean=1     Clean the data. (default)

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

    verbose= Specifies how talkative the function should be as it runs. Valid
      settings:
        verbose=1   Shows progress as the file is filtered (default)
        verbose=0   Be completely silent
*/
  default, verbose, 1;
  default, buf, 700;
  default, w, 200;
  default, n, 3;
  default, clean, 1;
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

  if(clean) {
    if(verbose)
      write, format=" %s", "cleaning...";
    data = test_and_clean(unref(data));
  }

  if(verbose)
    write, format=" %s", "filtering...";

  // Apply prefiltering, if relevant
  if(!is_void(prefilter_min) || !is_void(prefilter_max))
    data = filter_bounded_elv(unref(data), lbound=prefilter_min,
        ubound=prefilter_max, mode=mode);

  // Apply rcf filter
  data = rcf_filter_eaarl(unref(data), buf=buf, w=w, n=n, mode=mode,
      rcfmode=rcfmode);

  if(is_void(data)) {
    if(verbose)
      write, "all points eliminated";
      return;
  }

  if(verbose)
    write, format=" %s", "saving...";
  vname = regsub("_(v|b)$", vname, "");
  vname += swrite(format="_%s_%s", mode, rcfmode);
  pbd_save, file_out, vname, data;

  if(verbose)
    write, "done";
}

func rcf_classify(data, class, select=, rcfmode=, buf=, w=, n=) {
/* DOCUMENT rcf_classify, data, class, select=, rcfmode=, buf=, w=, n=
  Classify data using an RCF filter.

  Parameters:
    data: A pcobj object.

    class: The classification string to apply to the found points.

  Options:
    select= A class query to use to only apply RCF filter to subset of
      points. Example:
        select="first_return"      Only filter first returns

    rcfmode= Specifies which rcf filter function to use. Possible settings:
        rcfmode="grcf"    Use gridded_rcf (default)
        rcfmode="rcf"     Use old_gridded_rcf (deprecated)

    buf= Defines the size of the x/y neighborhood the filter uses, in
      centimeters. Default is 500 cm.

    w= Defines the size of the vertical (z) window the filter uses, in
      centimeters. Default is 30 cm.

    n= Defines the minimum number of points that are required in a window in
      order to count as successful. Default is 3.
*/
  local x, y, z, keep;
  default, rcfmode, "grcf";
  default, buf, 500;
  default, w, 30;
  default, n, 3;
  default, idx, 0;

  consider = (is_void(select) ? indgen(data(count,)) :
    data(class, where, select));
  if(!numberof(consider))
    return;

  splitary, data(xyz,consider), 3, x, y, z;
  buf *= .01;
  w *= .01;

  if(rcfmode == "grcf")
    keep = gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else if(rcfmode == "rcf")
    keep = old_gridded_rcf(unref(x), unref(y), unref(z), w, buf, n);
  else
    error, "Please specify a valid rcfmode=.";

  if(numberof(keep))
    data, class, apply, class, consider(keep);
}

func rcf_2d(z, w, buf, n, nodata=, mask=, action=) {
/* DOCUMENT rcf_2d(z, w, buf, n, nodata=, mask=, action=)
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
