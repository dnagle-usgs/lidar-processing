

/* 
   $Id$

*/

require, "pnm.i"

func dgrid(w, ll, d, c, wd) {
  x0 = ll(1);
  x1 = ll(2);
  for ( y=ll(3); y<=ll(4); y+=d ) {
   pldj, x0,y,x1,y,color=c,width=wd;
  }

  y0 = ll(3);
  y1 = ll(4);
  for ( x=x0; x<=x1; x+=d ) {
   pldj, x,y0,x,y1,color=c,width=wd;
  }
}

func draw_grid( w ) {
 c = [200,200,200];
  if ( is_void(w) ) w = 5;
  ll = int(limits()/2000) * 2000;
  ll(2) +=2000;
  ll(4) += 2000;
   dgrid, w, ll, 250, [200,200,200],1
   dgrid, w, ll, 1000,[150,150,150],1
   dgrid, w, ll, 2000,[250,140,140],5
}

func show_grid_location(w,m) {
/* DOCUMENT show_grid_location(w,m)

   Draw a UTM grid on windw "w" centered on mouse position "m".
   If "m" is not given, this function will wait for a mouse click
   in window "w".  Defaults to window 5.  The standard block divisions
    are the tile, quad, and cell.  A tile is always 2x2km, a quad
    1x1km and each tile contains 4 quads.  There are 16 cells in each
    quad and each cell is 250x250 meters. Nothing smaller than a 
   tile is saves in disk files.
   

   Returns:
      An array describing the location as follows:

 Given the input array from mouse(): 
 [ 485913,4.23174e+06,
   485913, 4.23174e+06,
   0.552432,0.653899,
   0.552432,0.653899,
   1,1, 0
  ]

 It will return the following array containing the tile north,
 and east, the block north and east index, and the cell north
 and east index within the block.

  [4230000,484000,2,2,3,4]

 See also: draw_grid, show_grid_location, dgrid

  
*/
  if ( is_void(w) ) w = 5;
  ltr = [["A","B"],["C","D"]];
  cells =[
          [1 , 2,  3,  4],
          [ 5, 6,  7,  8],
          [9, 10, 11, 12],
          [13,14, 15, 16]
         ];
  if ( is_void(m) ) 
      m = mouse();
  im = int(m);
  tilen = int(m)(2) / 2000 * 2000;
  tilee = int(m)(1) / 2000 * 2000;
  blockn = ((int(m)(2) - tilen ) / 1000 + 1);
  blocke = ((int(m)(1) - tilee ) / 1000 + 1);
  celln =  ((im(2) - tilen - (blockn*1000 - 1000)) )/250 + 1;
  celle =  ((im(1) - tilee - (blocke*1000 - 1000)) )/250 + 1;
  write,format="Tile: N%d E%d Quad:%s Cell:%d\n", 
      (tilen+2000)/1000,
      tilee/1000, 
      ltr(blocke,3-blockn), 
      cells(celle,5-celln);
  return [tilen,tilee,blockn,blocke,celln,celle];
}

func slimits(w) {
  if ( is_void(w) ) w = 5;
  
}


/* DOCUMENT gridr(r)

   Bin and grid eaarl data.

   Inputs:
	&r	an "R" array.

   Returns:
	An array of pointers (img) where *img(1) contains the 
        utm coords. for the lower left corner and the upper right
        corner of the selection window. img(2) contains and array

   1) Requires and eaarl "point cloud" in window 5
   2) Click and drag out a rectangle in window 5 that you want
      to grid.

   See also:  fillin.i

   Original by W. Wright 6/7/2002
*/


func sel_grid_area( r ) {
/* DOCUMENT sel_grid_area( r ) 
*/
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
  q = where( (r).east > ll(1)*100 );
 qq = where( (r).east(q) < ur(1)*100 );
  q = q(qq);
 qq = where( (r).north(q) > ll(2)*100 );
  q = q(qq);
 qq = where( (r).north(q) < ur(2)*100 );
  q = q(qq);

// q now holds a list of all elements within the selection box

  x = int( (r).east(q)+50)/100 + 1;  	// add 50cm, then convert from cm to m
  y = int((r).north(q)+50)/100 + 1;
  z = (r).elevation(q); 
 
z(max)
z(avg)
z(min)

// insert elevations into the grid array 
  for (i=1; i<=numberof(x); i++ ) { 
    img( x(i)-ll(1), y(i)-ll(2)) = z(i); 
    if ( (i % 1000) == 0 ) write, format="%d of %d\r", i, numberof(x) ;
  }


  window,w
  return [&ll, &ur, &img ]

}





