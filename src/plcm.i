/*
   $Id$
*/

write,"$Id$"



/*

$Revision$
$Date$
$Header$
$Author$
$Id$


  Orginal W. Wright wright@lidar.wff.nasa.gov

    
*/

func plcm( z, y, x, cmin=, cmax=, marker=, msize=)
/* DOCUMENT plcm   Plot markers z,y,x where z will be color coded

   Plots a scatter plot where z determines the color of the marker. 
   z,y, and x must all be the same size. sz= the size in NDC coords of the
   marker.  If shape= is non-nil it will cause plcm to  generate squares.
   If shape= is not defined or nil plcm will generate triangles.

   This function is useful for plotting data that's a function of three 
   variables.  In my case, it's frequently latitude, longitude, and 
   elevation where elevation variations are shown as varying colors.
   1=squares, 3=triangles

    1/22/02   Added edges=0 to plfp cuz Yorick 1.5 doesn't seem 
              to default to 0 as 1.4 did.
   11/27/1999 Mostly rewritten by David Munro.
   11/15/99 Fixed problem where z values were shifted from the x/y
            values.

   C. W. Wright 11/7/1999  wright@web-span.com

*/ 


{
  q = where( z > cmin );
  if ( numberof(q) == 0 ) 
     return;
  qq = where( z(q) < cmax );
  z = z( q(qq) );
  x = x( q(qq) );
  y = y( q(qq) );
  if (is_void(marker)) marker= 1;          /* default to squares */
  marker= (*_plmk_markers(marker)) / 7.0;  /* shrink default size */
  if (msize) marker*= msize;
  px= marker(,1);
  py= marker(,2);

  n= array(1, 1+numberof(y));
  n(1)= numberof(py);
  if (is_void(x)) x= indgen(numberof(y));
  plfp, edges=0, grow([0.],z), grow(py,y), grow(px,x), n, 
       cmin=cmin, cmax=cmax;
}



