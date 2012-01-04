/******************************************************************************\
* This file was moved to the attic on 2010-01-29. It was replaced by file      *
* plcm.i a long time ago.                                                      *
\******************************************************************************/

func plcm( z, y, x, cmin=, cmax=, sz=, shape= ) {
/* DOCUMENT plmc   Plot markers z,y,x where z will be color coded

   Plots a scatter plot where z determines the color of the marker. 
   z,y, and x must all be the same size. sz= the size in NDC coords of the
   marker.  If shape= is defined as anything it will cause plcm to 
   generate squares.  If shape= is not defined plcm will generate triangles.

   This function is useful for plotting data that's a function of three 
   variables.  In my case, it's frequently latitude, longitude, and 
   elevation where elevation variations are shown as varying colors.

   C. W. Wright 11/7/1999  wright@web-span.com

   11/15/99 Fixed problem wher z values were shifted from the x/y
            values.
*/
 local xx,yy,zz,nn;             // 

 if ( is_void(sz) ) {
   sz = 0.001;
 }
 if ( is_void(shape) ) {
   px = [0,-sz,sz];             // define a triangle
   py = [sz,-sz,-sz];
 } else {
   px = [sz,-sz,-sz,sz];        // define a square
   py = [sz,sz,-sz,-sz];
 }
 
 n = array(1, numberof(z) );    // Use special case
 n(1) = numberof(px);           // a triangle (3 corners)
 grow, xx, px, x                // glue the triangle to the
 grow, yy, py, y                // front of the data
 grow, zz, array(0, 1) , z    // 
 grow, zz, array(0, numberof(px) - 1 );
 grow, nn, n, array(0, numberof(px))    // 
  nn(0) = 1;
 plfp, zz,yy,xx, nn, cmin=cmin, cmax=cmax, edges=0
}



