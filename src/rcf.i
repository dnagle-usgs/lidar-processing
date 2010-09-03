// vim: set ts=3 sts=3 sw=3 ai sr et:

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

   See also: rcf, rcf.i, transect, mtransect.
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

   See also: old_gridded_rcf
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

func spatial_rcf(x, y, z, w, buf, n) {
/* DOCUMENT idx = spatial_rcf(x, y, z, w, buf, n)
   Returns an index into the x/y/z data for those points that survive the RCF
   filter with the given parameters.

   This filter is currently experimental.

   This filter is in some ways similar to gridded_rcf: points are put through
   the rcf filter using points that fall in a bounding box defined by buf.
   However, this filter does not actually use a grid. Instead, each point is
   assessed based on the points that fall in the bounding box of size buf that
   is centered on that point. If the point is contained within the result of an
   rcf over that area, then it is kept; otherwise, it is discarded.

   The intended benefit is that is each point is assesssed using its own "best"
   neighborhood rather than assessing it based on an arbitrary neighborhood
   that happens to contain it. It is hoped that this will yield better results
   for points that would have fallen near grid square edges under gridded_rcf.

   Since this function iterates over each point individually rather than
   iterating over a grid, it runs much slower than gridded_rcf.
*/
   // We want to ensure that x has a wider range than y so that the inner loop
   // has fewer points to deal with on each pass
   if(x(max) - x(min) < y(max) - y(min))
      swap, x, y;

   // keep is our result... anything set to 1 gets kept
   keep = array(char(0), dimsof(x));

   // Sorted index into x. We need to keep this to allow us to return indices
   // at the end.
   xsrt = sort(x);

   x = x(xsrt);
   y = y(xsrt);
   z = z(xsrt);

   count = numberof(x);

   // Keep track of our current range of candidate points with r1 and r2
   r1 = 1;
   r2 = 1;
   // Iterate through the points
   for(i = 1; i <= count; i++) {
      curx = x(i);
      b1 = curx - buf;
      b2 = curx + buf;

      // Bring the lower bound within range
      while(r1 <= count && x(r1) < b1)
         r1++;

      // Push the upper bound /just/ out of range then bring it back in
      while(r2 <= count && x(r2) <= b2)
         r2++;
      r2--;

      // If too few points are in the x-window, then we might as well move on
      if(r2 - r1 + 1 < n)
         continue;

      idx = indgen(r1:r2);

      // Figure out which points are within our y-window. If we end up with too
      // few, again... move on.
      cury = y(i);
      b1 = cury - buf;
      b2 = cury + buf;

      idx = idx(where(b1 <= y(idx)));
      if(numberof(idx) < n)
         continue;

      idx = idx(where(y(idx) <= b2));
      if(numberof(idx) < n)
         continue;

      // Run RCF on the elevations for this grid square
      result = rcf(z(idx), w, mode=0);
      if(result(2) >= n && result(1) <= z(i) && z(i) <= result(1) + w)
         keep(i) = 1;
   }

   return xsrt(where(keep));
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
            rcfmode="srcf"    Use spatial_rcf (experimental)

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
   else if(rcfmode == "srcf")
      keep = spatial_rcf(unref(x), unref(y), unref(z), w, buf, n);
   else
      error, "Please specify a valid rcfmode=.";

   if(idx)
      return keep;

   return numberof(keep) ? eaarl(keep) : [];
}
