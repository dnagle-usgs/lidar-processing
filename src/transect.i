/*

   $Id$

   Transect.i
   Original W. Wright 9/21/2003


*/

write, "$Id$"

func mtransect( fs, win=, w=, connect= ) {
/* DOCUMENT mtransect( fs, win=, w= )

  mtransect allows you to "drag out" a line wihin an ALPS topo display
window and then create a new grah of all of the points near the line. 
The w= option lets you set the "search distance in meters" from the line.
The win= option is used to designate the window (default=5), and the 
connect= option specifies drawing lines to connect the points (default is
off).


   Mouse selected transect. 
   fs       fs_all structure.
   win=     desired Yorick graph window.
   w=       search distance from line in centimeters.
  connect=  set to 1 to connect the points.

See also: transect.

*/

 extern mouse_transects;

 if ( is_void(w))             w = 150;
 if ( is_void(connect)) connect = 0;
 if ( is_void(win))         win = 5;
 if ( is_void(msize))         msize = 0.1;
 window,win
// get the line coords with the mouse and convert to cm
  l = mouse(1, 2)(1:4)*100.0;
  glst = transect( fs, l, connect=connect);
  grow, mouse_transects, [l]
  return glst;
}

func transect( fs, l, lw=, connect=, xtime=, msize=, xfma=, win=, color= ) {
/* DOCUMENT transect( fs, line, lw=)

   fs   fs_all structure where you drew the line.
   line the line.
   lw=      search distance either side of the line in centimeters.
   xtime=   1 to plot against time (soe)
   xfma=    set to clear screen
   win=     output window
   color=   0-7 

*/

 if ( is_void(lw)    )    lw = 150;		// search width, cm
 if ( is_void(color) ) color = 0;		// 0 is first color
 if ( is_void(win)   )   win = 3;
 window, win;
 if ( !is_void(xfma) ) fma; 

// determine the bounding box n,s,e,w coords
  n = l(2:4:2)(max);
  s = l(2:4:2)(min);
  w = l(1:3:2)(min);
  e = l(1:3:2)(max);

// compute the rotation angle needed to make the selected line
// run east west
  angle = atan( (l(2)-l(4)) / (l(1)-l(3)) ) ;
  angle ;
  [n,s,e,w]


// build a matrix to select only the data withing the bounding box
  good = (fs.north(*) < n)  & ( fs.north(*) > s ) & (fs.east(*) < e ) & ( fs.east(*) > w );

// rotation:  x' = xcos - ysin
//            y' = ycos + xsin

/* Steps:
        1 translate data and line to 0,0
        2 rotate data and line 
        3 select desired data
*/

  glst = where(good);

  y = fs.north(*)(glst) - l(2);
  x = fs.east(*)(glst)  - l(1);

  ca = cos(-angle); sa = sin(-angle);

  rx = x*ca - y*sa
  ry = y*ca + x*sa

  llst = where( abs(ry) < lw );

  window,3
///  fma
  segs = where( abs(fs.soe(glst(llst))(dif)) > 5.0 );
 nsegs = numberof(segs)+1;
 ss = [0];
 nsegs
 if ( nsegs > 1 ) { 
   grow, ss,segs,[0]
   ss

//            1      2       3        4          5         6       7
  clr = ["black", "red", "blue", "green", "magenta", "yellow", "cyan" ];
   for (i=1; i<numberof(ss); i++ ) {
     c = (color+i)&7;
     tb = fs.soe(*)(glst(llst)(ss(i)+1))%86400;
     te = fs.soe(*)(glst(llst)(ss(i+1)))%86400;
     td = abs(te - tb);
     hms = sod2hms( tb );
     write, format="soe = %6.2f:%-10.2f(%-4.2f) hms=%2d:%02d:%02d utc\n", 
                          tb, te, td, hms(1,), hms(2,), hms(3,);
     if ( xtime ) {
     plmk, fs.elevation(*)(glst(llst)(ss(i)+1:ss(i+1)))/100.0, 
           fs.soe(*)(llst)(ss(i)+1:ss(i+1))/100.0,color=clr(c), msize=msize
     if ( connect ) plg, fs.elevation(*)(glst(llst)(ss(i)+1:ss(i+1)))/100.0, 
                fs.soe(*)(llst)(ss(i)+1:ss(i+1))/100.0,color=clr(c)
     } else {
     plmk, fs.elevation(*)(glst(llst)(ss(i)+1:ss(i+1)))/100.0, 
           rx(llst)(ss(i)+1:ss(i+1))/100.0,color=clr(c), msize=msize
     if ( connect ) plg, fs.elevation(*)(glst(llst)(ss(i)+1:ss(i+1)))/100.0, 
                rx(llst)(ss(i)+1:ss(i+1))/100.0,color=clr(c)
    }
   }
 } else {
  plmk, fs.elevation(*)(glst(llst))/100.0, rx(llst)/100.0
 }



///  limits,rx(llst)(min),rx(llst)(max),-4500,-2500

  return glst(llst);
}


