/*
   $Id$
*/

require, "fillin.i"

write,"jb.i as of 12/9/01"

CNSH2O2X = 0.11270393157;


func cp ( cmin=, cmax=, contours=) {
/* DOCUMENT cp, cmin=, cmax=, contours=

   Draws a contour plot.  Examples:

 cp		              Use defaults and contour the data
 cp,cmin=-5.5                 Set deepest to -5.5 meters
 cp,cmin=-5.5,cmax=-1.7       Deepest to -5.5, and shallowest at -1.7meters
 cp,contours=5                Use 5 contour levels.

 **You can combine cmin, cmax and contours by separating with a ","

 To scroll the graph around, hold down the middle-mouse button while 
 you move around the image.  Zoom in/out witht the left/right mouse
 buttons.
 
 See also: cp, pix, mslice

*/
fma; 
  if ( is_void(cmin) ) cmin = -8.0
  if ( is_void(cmax) ) cmax = -1.4
  if ( is_void(contours) ) contours = 7 
  plfc, bytscl(fillall(z), cmin= cmin ,cmax= cmax ),y,x,levs=span(1,200,23)
  plc, bytscl(fillall(z), cmin= cmin ,cmax= cmax ),y,x, 
           levs=span(10,200,contours)
}

func pix (fill=, cmin=, cmax=) {
/* DOCUMENT pix, cmin=, cmax=, fill=

 pix, cmin=-5.5,cmax=-1.7,fill=1         Set depth range 1.7 to 5.5 meters
                                         and fill in missing data.
 pix                                     Use defaults

 **You can combine cmin, cmax and fill by separating with a ","

 To scroll the graph around, hold down the middle-mouse button while 
 you move around the image.  Zoom in/out witht the left/right mouse
 buttons.

 See also: cp, pix, mslice
*/
  if ( fill ) z = fillall(z); 
  if ( is_void(cmin) ) cmin = -8.0
  if ( is_void(cmax) ) cmax = -1.4
  fma; pli, bytscl(z, cmin= cmin ,cmax= cmax)
} 

func mslice  {
/* DOCUMENT mslice

   Use the mouse to select raster values from window 0 and
  then display the selected raster of depths in window 1.

 See also: cp, pix, mslice
*/
// be sure we're in the surface image window
 while (1) { 
// select an area to "slice."  
  window,0; 
  click = mouse(,,"Left button selects raster, right button quits mslice")
  if ( click(10) == 3 ) break;
  pixn = int(click(2)  + 0.5 ); 
  window,1; 
  fma; 
  plmk,z(, pixn),msize=.3, marker=1; pixn
 }
}



f = openb("7-14-01-rn-46672-47672-sod-70513.pbd");
restore,f
show,f

x = span(1,120,120) (, -:1:500)
y = span(1,500,500) (-:1:120,)
window,0
limits,-26,150,60,-2;

z = -z * CNSH2O2X;
cp

write,"Type:   help, cp  or  help, pix  or help, mslice"


