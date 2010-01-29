
/* DOCUMENT PointsInPolygon.i
	************************** Points In Polygon ********************************
	This program creates a polygon used to define an area of interest. Then
	a subset of points from a given set is tested against this area of interest.
	The program determines which points from the set are inside the polygon. The 
	program also creates a bound box that wraps around the polygon and defines the
	subset of points inside the bound box.

       _ply is a global var set to the most recent polygon.
	
	Original: Enils Bashi	
	Last Modified: June 12, 2002
*********************************************************************************/

func getPoly(void)
/* DOCUMENT function getPoly
This function draws a polygon on the Yorick window Start 
by clicking in the current Yorick graphics window. 
To close the polygon and stop clicking points use 
Ctrl-left mouse button at the same time.
Parameters: none
Returns:    ply - array of polygon vertices
*/
{ 
 extern _ply;	// global copy of most recently defined ply
 prompt = "Left mouse generates a vertex. Ctl-Left or middle mouse click to end and close polygon."
	ply = array(float, 2, 1)     // array that contains polygon vertices
  	result = mouse(1, 0, prompt)
  	ply(1, 1) = result(1)	     // x coordinate of the first vertex
  	ply(2, 1) = result(2)	     // y coordinate of the first vertex
  	//fma;
 	plmk, ply(2, 0), ply(1, 0), marker = 4, msize = .4, width = 10, color="red"
		
        prompt = swrite("Ctl-left or middle mouse click to close polygon.");
 	write, prompt;
  	while((!((result(10)== 1)   && 
                 (result(11)== 4))) && 
                 (!(result(10)==2))) 	// while !(CTRL && left mouse) loop
  	{		
   	 	result = mouse(1, 2,"")		
    	grow, ply, result(3:4)				// make room for new vertex
    	plmk, ply(2, 0), ply(1, 0), marker = 4, msize = .3, width = 10
    	plg, [ply(2,-1), ply(2,0)],  
             [ply(1,-1), ply(1,0)], marks = 0; //connect current and previous						
  	}
	write, "PIP region selected.  Please wait..."
  	plg, [ply(2,1), ply(2,0)],  
             [ply(1,1), ply(1,0)], marks = 0;  //connect first and last vertex
        _ply = ply;
  	return ply								
}

func plotPoly(pl, oututm=, color=)
/* DOCUMENT function plotPoly
    This function redraws the polygon or polygon vertices on the yorick window.
	plotPoly can be used after a fma command.
	Parameters: pl - array of polygon vertices
	Return:	    pl - array of polygon vertices
*/	
{
        if (oututm) {
   	    pl1 = ((fll2utm(pl(2,), pl(1,)))(1:2,));
	    pl = transpose ([pl1(2,), pl1(1,)]);
        }
	if (!color) color="black"
	plmk,pl(2,), pl(1,) , marker = 4, msize = .5, width = 10, color=color;
	plg, pl(2,), pl(1,), marks = 0, color=color;
	plg, [pl(2,1), pl(2,0)], [pl(1,1), pl(1,0)], marks = 0, color=color;
	return pl
}

func testPoly(pl, ptx, pty) {
/* DOCUMENT idx = testPoly(pl, ptx, pty)
   This function determines whether points from a given set are inside or
   outside the polygon. The algorithm used calculates the sum of the angles
   between two vectors that start at any point and end at two consecutive
   polygon vertices. If the sum of angles is less then 2Pi the point is
   outside the polygon; otherwise, it is inside.

   Parameters:
      pl: 2-dimensional array containing verticies of the polygon (dimsof(pl)
         should be [2,2,?])
      ptx: 1-dimensional array containing x-coordinates of points to be tested
      pty: 1-dimensional array containing y-coordinates of points to be tested

   ptx and pty must be conformable.

   Returns:
      Array of indices into ptx/pty for the points within the polygon.

   See also: testPoly2 _testPoly
*/
   if(is_void(pl) || is_void(ptx) || is_void(pty)) return [];
   w = data_box(ptx, pty, pl(1,min), pl(1,max), pl(2,min), pl(2,max));
   if(numberof(w)) {
      idx = _testPoly(unref(pl), unref(ptx)(w), unref(pty)(w));
      return w(idx);
   } else {
      return [];
   }
}

func _testPoly(pl, ptx, pty) {
/* DOCUMENT idx = _testPoly(pl, ptx, pty)
   This function is called by testPoly to do most of its work. The only thing
   testPoly does that this does not is that testPoly first filters the points
   to the bounding box of the polygon. In cases where there are lots of points,
   this provides a huge performance increase.

   See testPoly for further description of what the function does.

   See also: testPoly testPoly2
*/
/*
   The algorithm used calculates the sum of the angles between two vectors that
   start at any point and end at two consecutive polygon vertices. If the sum
   of angles is less then 2Pi the point is outside the polygon or inside
   otherwise.  The algorithm uses the cross and dot product to determine the
   inverse tangent which will equal the angle between vectors.
*/
   if(is_void(pl) || is_void(ptx) || is_void(pty)) return [];

   // array of angle sums between vectors	
   theta = array(double(0), dimsof(ptx));

   // Loop n-times where n = number of vertices
   for(i = 1; i < (dimsof(pl)(3)); i++) {
      // Calculate the delta for each vector in both x and y
      dx1 = pl(1,i) - ptx;
      dy1 = pl(2,i) - pty;
      dx2 = pl(1,i+1) - ptx;
      dy2 = pl(2,i+1) - pty;

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

   Input: pl - 2xn array of polygon vertices
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

   // Short circuit if anything isn't defined
   if(is_void(pl))
      return [];
   if(is_void(ptx))
      return [];
   if(is_void(pty))
      return [];

   // It's fast and cheap to figure out which are within a bounding box, so
   // we restrict our search to those points.
   in_bbox = (pl(1,min) <= ptx) & (ptx <= pl(1,max)) &
             (pl(2,min) <= pty) & (pty <= pl(2,max));
   
   if(!numberof(where(in_bbox)))
      return [];

   idx = where(in_bbox);

   inpoly = array(short(0), dimsof(ptx));
   if(!is_void(includevertices))
      isvertex = array(short(0), dimsof(ptx));

   // idx never (or rarely) changes; thus, we get a speed-up by indexing ptx
   // once instead of on every loop iteration
   ptxi = ptx(idx);
   for(i = 1; i <= dimsof(pl)(3); i++) {
      // rather than repeatedly indexing into pl for its x-coordinates, we do
      // it just once per point per iteration
      plx1 = pl(1,i);
      plx0 = pl(1,i-1);

      // test for vertex match
      if(!is_void(includevertices)) {
         w = where( plx1 == ptxi & pl(2,i) == pty(idx) );
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
               pl(2,i) +
               (ptxi(wx) - plx1) / (plx0 - plx1) *
               (pl(2,i-1) - pl(2,i))
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
