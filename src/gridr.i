

/* 
   $Id$
*/

require, "pnm.i"


/* DOCUMENT gridr(r)

   Bin and grid eaarl data.

   Inputs:
	r	an RRR array.

   Returns:
	An array of pointers (img) where *img(1) contains the 
        utm coords. for the lower left corner and the upper right
        corner of the selection window. img(2) contains and array

   1) Requires and eaarl "point cloud" in window 5
   2) Click and drag out a rectangle in window 5 that you want
      to grid.

*/


func sel_grid_area( r ) {
  w = window();
  window,5; 
  res=mouse(, 1);
  x = int(res(1:3:2));
  y = int(res(2:4:2));

  ll = [x(min), y(min)];
  ur = [x(max), y(max)];
 ll
 ur
  img = array( long, ur(1)-ll(1)+1, ur(2)-ll(2)+1 );


// Extract a list containing all the elements in the selection box
  q = where( (*r).east > ll(1)*100 );
 qq = where( (*r).east(q) < ur(1)*100 );
  q = q(qq);
 qq = where( (*r).north(q) > ll(2)*100 );
  q = q(qq);
 qq = where( (*r).north(q) < ur(2)*100 );
  q = q(qq);

// q now holds a list of all elements within the selection box

  x = int( (*r).east(q)+50)/100 + 1;  	// add 50cm, then convert from cm to m
  y = int((*r).north(q)+50)/100 + 1;
  z = (*r).elevation(q); 

// insert elevations into the grid array 
  for (i=1; i<=numberof(x); i++ ) { 
    img( x(i)-ll(1), y(i)-ll(2)) = z(i); 
    if ( (i % 1000) == 0 ) write, format="%d of %d\r", i, numberof(x) ;
  }


  window,w
  return [&ll, &ur, &img ]

}





