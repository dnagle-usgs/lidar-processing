/******************************************************************************\
* This file was created in the attic on 2010-09-13. It contains the function   *
* spatial_rcf that was formerly in rcf.i. This function was an experimental    *
* filter that never made it into actual use. It ran too slowly and provided no *
* actual benefit.                                                              *
\******************************************************************************/

// vim: set ts=3 sts=3 sw=3 ai sr et:

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
