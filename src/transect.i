/*

   $Id$

   Transect.i
   Original W. Wright 9/21/2003


*/

func mtransect( fs, win=, w= ) {
/* DOCUMENT mtransect( fs, win=, w= )

   Mouse selected transect. 
   fs   fs_all structure.
   win= desired Yorick graph window.
   w=   search distance from line in centimeters.

*/

 extern mouse_transects;

 if ( is_void(w)) w = 150;

 if ( is_void(win)) win = 5;
 window,win
// get the line coords with the mouse and convert to cm
  l = mouse(1, 2)(1:4)*100.0;
  glst = transect( fs, l);
  grow, mouse_transects, [l]
  return glst;
}

func transect( fs, l, lw= ) {
/* DOCUMENT transect( fs, line, lw=)

   fs   fs_all structure where you drew the line.
   line the line.
   lw=  search distance either side of the line in centimeters.

*/

 if (is_void(lw) ) lw = 150;

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
 ss = [1];
 nsegs
 if ( nsegs > 1 ) { 
   grow, ss,segs,[0]
   ss
  clr = ["black", "red", "blue", "green", "magenta", "yellow", "cyan" ];
   for (i=1; i<numberof(ss); i++ ) {
     plmk, fs.elevation(*)(glst(llst)(ss(i):ss(i+1)))/100.0, 
           rx(llst)(ss(i):ss(i+1))/100.0,color=clr(i&7)
   }
 } else {
  plmk, fs.elevation(*)(glst(llst))/100.0, rx(llst)/100.0
 }



///  limits,rx(llst)(min),rx(llst)(max),-4500,-2500

  return glst(llst);
}


