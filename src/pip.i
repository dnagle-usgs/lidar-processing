// vim: set ts=2 sts=2 sw=2 ai sr et:

func getPoly(void, closed=, win=) {
/* DOCUMENT getPoly(closed=, win=)
  DEPRECATED! Use get_poly instead.
*/
// Deprecated 2013-04-10
  write, "WARNING: called deprecated function getPoly; use get_poly instead";
  return get_poly(closed=closed, win=win);
}

func get_poly(void, closed=, win=) {
/* DOCUMENT ply = get_poly(closed=, win=)

  Prompts the user to click on the current window to draw a polygon. The
  polygon is then returned to the caller as array(double,2,N) containing
  vertices as [x,y] pairs.

  Option:
    closed= If set to 1, then the first point will be duplicated as the last
      point to make an explicitly-closed polygon. This is off by default. Many
      things in Yorick do not differentiate between a polygon and a polyline,
      so this setting usually isn't needed.
    win= Window to use. By default, uses current window. If provided, the
      currently selected window will be restored when the function finishes.
*/
  default, closed, 0;
  default, win, window();

  wbkp = current_window();
  window, win;

  write, format=
    " Window %d: Left click to add vertex; ctrl-left or middle click to\n" +
    " add and finish; right click to finish. Shift-left click to abort.\n", win;

  ply = [];
  first = 1;
  more = 1;

  while(more) {
    spot = mouse(1, 0, "");

    more = mouse_click_is("left", spot);
    if(more || mouse_click_is(["ctrl+left","middle"], spot)) {
      grow, ply, [spot(1:2)];

      if(first) {
        plmk, ply(2,0), ply(1,0), marker=4, msize=.4, width=10, color="red";
        first = 0;
      } else {
        plmk, ply(2,0), ply(1,0), marker=4, msize=.3, width=10;
        plg, ply(2,-1:0), ply(1,-1:0), marks=0;
      }
    } else if(!mouse_click_is("right", spot)) {
      ply = [];
    }
  }
  n = numberof(ply)/2;
  if(n > 1) {
    plg, ply(2,[1,n]), ply(1,[1,n]), marks=0;
    if(closed) {
      grow, ply, ply(,1);
    }
  }

  window_select, wbkp;
  return ply;
}

func testPoly(pl, ptx, pty) {
/* DOCUMENT idx = testPoly(pl, ptx, pty)
  This function determines whether points from a given set are inside or
  outside the polygon. The algorithm used calculates the sum of the angles
  between two vectors that start at any point and end at two consecutive
  polygon vertices. If the sum of angles is less then 2Pi the point is
  outside the polygon; otherwise, it is inside.

  Parameters:
    pl: 2-dimensional array containing vertices of the polygon, as 2xn or nx2
    ptx: 1-dimensional array containing x-coordinates of points to be tested
    pty: 1-dimensional array containing y-coordinates of points to be tested

  ptx and pty must be conformable.

  Returns:
    Array of indices into ptx/pty for the points within the polygon.

  SEE ALSO: testPoly2 _testPoly
*/
  local plx, ply;
  if(is_void(pl) || is_void(ptx) || is_void(pty)) return [];
  splitary, unref(pl), plx, ply;
  w = data_box(ptx, pty, plx(min), plx(max), ply(min), ply(max));
  if(numberof(w)) {
    idx = _testPoly(unref(plx), unref(ply), unref(ptx)(w), unref(pty)(w));
    return w(idx);
  } else {
    return [];
  }
}

func _testPoly(plx, ply, ptx, pty) {
/* DOCUMENT idx = _testPoly(plx, ply, ptx, pty)
  This function is called by testPoly to do most of its work. The only thing
  testPoly does that this does not is that testPoly first filters the points
  to the bounding box of the polygon. In cases where there are lots of points,
  this provides a huge performance increase.

  See testPoly for further description of what the function does.

  SEE ALSO: testPoly testPoly2
*/
/*
  The algorithm used calculates the sum of the angles between two vectors that
  start at any point and end at two consecutive polygon vertices. If the sum
  of angles is less then 2Pi the point is outside the polygon or inside
  otherwise.  The algorithm uses the cross and dot product to determine the
  inverse tangent which will equal the angle between vectors.
*/
  // array of angle sums between vectors
  theta = array(double(0), dimsof(ptx));

  // Loop n-times where n = number of vertices
  for(i = 1; i < numberof(plx); i++) {
    // Calculate the delta for each vector in both x and y
    dx1 = plx(i) - ptx;
    dy1 = ply(i) - pty;
    dx2 = plx(i+1) - ptx;
    dy2 = ply(i+1) - pty;

    // Calculate dot product and cross product
    dp = dx1 * dx2 + dy1 * dy2;
    cp = unref(dx1) * unref(dy2) - unref(dy1) * unref(dx2);

    // Theta is inverse tangent (keep a running sum)
    theta += atan(unref(cp), unref(dp));
  }

  return where(abs(theta) >= pi);
}

func testPoly2(pl, ptx, pty, includevertices=) {
/* DOCUMENT testPoly2(pl, ptx, pty, includevertices=)
  This function determines whether points from a given set (defined by ptx
  and pty) are inside or outside of a polygon (defined by pl).

  The function uses the ray casting algorithm, which counts how many times a
  ray starting at the point crosses polygonal boundaries as it extends to
  infinity. If it crosses an odd number of times, the source point is within
  the polygon. Otherwise, it is not.

  By default, points that coincide with vertices have no well-defined
  behavior; some will qualify as "inside" and others as "outside". If their
  behavior matters, use the includevertices option. If includevertices=1,
  then points that coincide with vertices will be considered to be inside
  the polygon. If includevertices=0, then those points will be considered to
  be outside the polygon.

  Points that fall upon non-vertex boundaries of the polygon have no
  well-defined behavior; some will qualify as "inside" an dothers as
  "outside". At present, this function gives no means by which to
  discriminate between them.

  Caveat: On complex polygons, areas of self-intersection may or may not
  count as "inside" the polygon, depending on the number of times it
  self-intersects over that point. If you need to consider all such points
  as "inside" the polygon, then use testPoly.

  For very large polygons and very large sets of x/y, testPoly2 is several
  magnitudes of order faster than testPoly.

  Input: pl - 2xn or nx2 array of polygon vertices
       ptx - 1xn array of x-coordinates for points to test
       pty - 1xn array of y-coordinates for points to test

  Returns: Array of indexes into the points specifying which are within the
  polygon.
*/
// Original David B. Nagle 2009-03-12
// Algorithm is adapted from this page:
// http://dawsdesign.com/drupal/google_maps_point_in_polygon
// Also using info on the ray casting algorithm found on wikipedia:
// http://en.wikipedia.org/w/index.php?title=Point_in_polygon&oldid=270279744
  local plx, ply;

  // Short circuit if anything isn't defined
  if(is_void(pl) || is_void(ptx) || is_void(pty))
    return [];

  splitary, pl, plx, ply;

  // It's fast and cheap to figure out which are within a bounding box, so
  // we restrict our search to those points.
  in_bbox = (plx(min) <= ptx) & (ptx <= plx(max)) &
         (ply(min) <= pty) & (pty <= ply(max));

  if(noneof(in_bbox))
    return [];

  idx = where(in_bbox);

  inpoly = array(short(0), dimsof(ptx));
  if(!is_void(includevertices))
    isvertex = array(short(0), dimsof(ptx));

  // idx never (or rarely) changes; thus, we get a speed-up by indexing ptx
  // once instead of on every loop iteration
  ptxi = ptx(idx);
  for(i = 1; i <= numberof(plx); i++) {
    // rather than repeatedly indexing into pl for its x-coordinates, we do
    // it just once per point per iteration
    plx1 = plx(i);
    plx0 = plx(i-1);

    // test for vertex match
    if(!is_void(includevertices)) {
      w = where( plx1 == ptxi & ply(i) == pty(idx) );
      if(numberof(w)) {
        isvertex(idx(w)) = 1;
        // if it's a vertex, we no longer need to test it
        in_bbox(idx(w)) = 0;
        idx = where(in_bbox);

        ptxi = ptx(idx);
      }
      if(!numberof(idx))
        break;
    }

    wx = [];
    if(plx1 <= plx0)
      wx = where(plx1 < ptxi & ptxi <= plx0);
    else
      wx = where(plx0 < ptxi & ptxi <= plx1);

    if(numberof(wx)) {
      // Flip the bit if we're crossing a boundary
      inpoly(idx(wx)) ~= (
          ply(i) +
          (ptxi(wx) - plx1) / (plx0 - plx1) *
          (ply(i-1) - ply(i))
        ) < pty(idx(wx));
    }
  }

  if(!is_void(includevertices)) {
    if(includevertices)
      inpoly |= isvertex;
    else
      inpoly &= ! isvertex;
  }

  return where(inpoly);
}

func data_in_poly(data, ply, mode=, idx=) {
/* DOCUMENT data_in_poly(data, ply, mode=, idx=)
  Wrapper around data2xyz and testPoly. Returns all DATA that falls within the
  polygon PLY. MODE= should be one of "fs", "be", "ba", etc. Set IDX=1 to get
  an index list instead of the data.
*/
  local x, y, z;
  if(!numberof(data) || !numberof(ply))
    return [];
  data2xyz, data, x, y, z, mode=mode;
  w = testPoly(ply, x, y);
  if(!numberof(w))
    return [];
  return idx ? w : data(w,..);
}

func boundBox(pl, noplot=)
/* DOCUMENT function boundBox
  This function creates a bound rectangular box that wraps around the polygon
  Parameters: pl - polygon of array vertices
  Returns:    box - array of vertices of rectangle box
*/
{

  box = array(float, 2, 4)	  // contains the box vertices
  box(1,1) = box(1,4) = pl(1, min)  // bottom left vertex
  box(2,1) = box(2,2) = pl(2, min)  // bottom right vertex
  box(1,2) = box(1,3) = pl(1, max)  // upper right vertex
  box(2,3) = box(2,4) = pl(2, max)  // upper left vertex

  if (!noplot) {
    plg, box(2,), box(1,), color = "cyan", marks = 0
    plg, [box(2,1), box(2,0)],  [box(1,1), box(1,0)], color = "cyan", marks = 0
  }
  return box
}

func ptsInBox(box, x, y)
/* DOCUMENT testbox
  This function determines a set of points that are inside the bound box
  Parameters: box - bound box of a polygon, x and y coordinates
  of the each point from the given dataset
  Returns: array of indexes of the points that are inside the
  bound box for a specific polygon.

*/
{
  xl = box(1, min); // x-lower bound of box
  xh = box(1, max); // x-upper bound of box
  yl = box(2, min); // y-lower bound of box
  yh = box(2, max); // x-upper bound of box
  return data_box(unref(x), unref(y), xl, xh, yl, yh);
}
