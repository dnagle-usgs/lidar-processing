
/*
   $Id$
*/
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

write, "$Id$"

func getPoly(void)
/* DOCUMENT function getPoly
	This function draws a polygon on the Yorick window
	Start by cli
	cking on the Yorick	window. To close the
	polygon or to stop clicking points hit Ctrl and click 
	the left mouse button at the same time.
	Parameters: none
	Returns:    ply - array of polygon vertices
*/
{ 
 extern _ply;	// global copy of most recently defined ply
	ply = array(float, 2, 1)     // array that contains polygon vertices
  	prompt = "Click"	     // prompt for each vertex	
  	result = mouse(1, 0, prompt)
  	ply(1, 1) = result(1)	     // x coordinate of the first vertex
  	ply(2, 1) = result(2)	     // y coordinate of the first vertex
  	//fma;
 	plmk, ply(2, 0), ply(1, 0), marker = 4, msize = .5, width = 10
		
  	while((!((result(10)== 1)   && 
                 (result(11)== 4))) && 
                 (!(result(10)==2))) 	// while !(CTRL && left mouse) loop
  	{		
   	 	result = mouse(1, 2, prompt)		
    	grow, ply, result(3:4)				// make room for new vertex
    	plmk, ply(2, 0), ply(1, 0), marker = 4, msize = .5, width = 10
    	plg, [ply(2,-1), ply(2,0)],  
             [ply(1,-1), ply(1,0)], marks = 0; //connect current and previous						
  	}
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

func testPoly(pl, ptx, pty)
/* DOCUMEMT function test
   	This function determines whether points from a given set
	are inside or outside the polygon. The algorithm used calculates
	the sum of the angles between two vectors that start at any point
	and end at two consecutive polygon vertices. If the sum of angles 
	is less then 2Pi the point is outside the polygon or inside otherwise.
	The algorithm uses the cross and dot product to determine the inverse
	tangent which will equal the angle between vectors. The angles are 
	stored in a n x m array, where n = polygon vertices and m = points
	
	Parameters: pl - 2 x n array, contains vertices of the polygon
		        ptx - 1 x n array, contains x-coordinates of points to be tested
		        pty - 1 x n array, contains y-coordinates of points to be tested
	 
	Returns:    array of indexes of points that are inside the polygon
*/
{
  if ((is_void(ptx)) || (is_void(pty))) return [];
 // array of angles between vectors	
  theta = array(float, dimsof(pl)(3), dimsof(ptx)(2)) 
	
 // Loop n-times where n = number of vertices
  for (i = 1; i < (dimsof(pl)(3)); i++)	{ 	
    v1x0 = ptx	    // x-coordinate of beginning point of v1
    v1y0 = pty	    // y-coordinate of beginning point of v1
    v1x1 = pl(1,i)  // x-coordinate of ending point of v1
    v1y1 = pl(2, i) // y-coordinate of ending point of v1
    v2x0 = ptx	    // x-coordinate of beginning point of v2
    v2y0 = pty	    // y-coordinate of beginning point of v2
    v2x1 = pl(1,i+1) // x-coordinate of ending point of v2
    v2y1 = pl(2,i+1) // y-coordinate of ending point of v2
    v1x = v1x1 - v1x0 // x - coordinate of v1		
    v1y = v1y1 - v1y0 // y - coordinate of v1
    v2x = v2x1 - v2x0 // x - coordinate of v2
    v2y = v2y1 - v2y0 // y - coordinate of v2
		
    dp = ((v1x * v2x) + (v1y * v2y))	// Dot-Product
    cp = ((v1x * v2y) - (v1y * v2x))	// Cross-Product
    theta(i, ) = atan(cp, dp)		// Theta equals tangent inverse
  }
  inout =(abs( theta(sum, )) < pi )
  return ( where ( inout == 0 ) );
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
 xl = box(1 ,min) // x-lower bound of box
 xh = box(1, max) // x-upper bound of box
 yl = box(2, min) // y-lower bound of box					
 yh = box(2, max) // x-upper bound of box

 area = ((x > xl) & (x < xh) & (y > yl) & (y < yh)) 

 pts = numberof(where(area)) // points within area
 return (where(area))	    // array of indexes to points in area
}
