// vim: set ts=2 sts=2 sw=2 ai sr et:

func trifilter(data, mode=, maxiter=, radius=, thresh=, verbose=) {
/* DOCUMENT data = trifilter(data, mode=, maxiter=, radius=, thresh=, verbose=)

  EXPERIMENTAL!

  Performs a triangulation filter on the given data. This filter triangulates
  the point cloud. Then it compares each point to the other points on the
  triangles it is a member of (within a specified radius) to see if it is
  within a threshold of their elevation range. Points that pass are kept,
  points that fail are removed. The algorithm will repeat this process until
  either all remaining points pass or until the maximum iterations is hit.

  Options:
    mode= Data mode, such as "be" or "fs". (Default: "fs")
    maxiter= Maximum number of passes to make. This will be bounded to the
      range 1 to 100.
        maxiter=1     Only run one pass
        maxiter=20    Run up to 20 passes (default)
        maxiter=1000  Gets truncated to 100 passes
    radius= Spatial distance in meters about each point within which adjacent
      vertexes are considered.
        radius=5      Adjacent vertexes within 5m (default)
    thresh= Vertical elevation threshold in meters. The elevation of the point
      must be no more than this far outside the elevation range of the adjacent
      points.
        thresh=0.20   20cm (default)
    verbose= Specifies whether the function should provide progress output to
      the console.
        verbose=0     Run silently
        verbose=1     Provide progress output (default)
*/
  t0 = array(double, 3);
  timer, t0;

  default, maxiter, 20;
  maxiter = min(100,max(1,maxiter));
  default, radius, 5;
  default, thresh, 0.20;
  default, verbose, 1;

  // Square the radius
  radius2 = radius * radius;

  // Triangulation requires unique x,y coordinates
  data = uniq_data(data, mode=mode, forcexy=1);

  local x, y, z, v1, v2, v3;
  data2xyz, data, x, y, z, mode=mode;

  iter = 0;
  while(iter < maxiter) {
    iter++;

    v = triangulate(x, y, verbose=0);
    splitary, v, 3, v1, v2, v3;

    n = numberof(x);
    keep = array(1, n);
    status, start, msg=swrite(format="Trifilter, pass %d", iter);
    for(i = 1; i <= n; i++) {
      // Find all adjacent points -- points that are in the same triangle as
      // the target.
      adjacent = array(pointer, 6);
      w = where(v1 == i);
      if(numberof(w)) {
        adjacent(1) = &v2(w);
        adjacent(2) = &v3(w);
      }
      w = where(v2 == i);
      if(numberof(w)) {
        adjacent(3) = &v1(w);
        adjacent(4) = &v3(w);
      }
      w = where(v3 == i);
      if(numberof(w)) {
        adjacent(5) = &v1(w);
        adjacent(6) = &v2(w);
      }
      if(noneof(adjacent)) continue;
      adjacent = set_remove_duplicates(merge_pointers(adjacent));
      // Must have at least two points to surround the target.
      if(numberof(adjacent) < 2) continue;

      // Target point
      tx = x(i);
      ty = y(i);
      tz = z(i);

      // Adjacent points
      ax = x(adjacent);
      ay = y(adjacent);
      az = z(adjacent);

      // Restrict points to the specified radius
      dist2 = (ax - tx)^2 + (ay - ty)^2;
      w = where(dist2 <= radius2);
      // Again, must have at least two points to surround the target.
      if(numberof(w) < 2) continue;
      ax = ax(w);
      ay = ay(w);
      az = az(w);

      // Make sure the adajcent points that remain surround the target.
      //
      // Current logic: if there's at least one point on either side of the
      // target in the x direction and at least one point on either side of the
      // target in the y direction, it is probably surrounded.
      //
      // The current logic here could be improved, since there are cases where
      // it fails to meet the definition of surrounded. For example, if the
      // target point is 1,1, then points at 0,1.01 and 1.01,0 would pass
      // these conditions but wouldn't actually surround the point.
      if(noneof(ax < tx)) continue;
      if(noneof(ax > tx)) continue;
      if(noneof(ay < ty)) continue;
      if(noneof(ay > ty)) continue;

      // Make sure the target is within bounds of the adjacent points'
      // elevations + thresh. If not, discard.
      if(tz < az(min) - thresh || az(max) + thresh < tz) {
        keep(i) = 0;
      }
      status, progress, i, n;
    }
    status, finished;

    if(allof(keep)) {
      if(verbose)
        write, format="Pass %d: all points accepted\n", iter;
      break;
    } else if(noneof(keep)) {
      // This should never happen.
      error, "Somehow lost all points, this is probably an algorithm issue.";
    } else {
      w = where(keep);
      if(verbose) {
        total = numberof(keep);
        remvd = total - numberof(w);
        write, format="Pass %d: removed %d of %d (%.1f%%) points\n",
          iter, remvd, total, double(remvd)/total*100;
      }
      data = data(w);
      x = x(w);
      y = y(w);
      z = z(w);
    }
  }

  timer_finished, t0;
  return data;
}
