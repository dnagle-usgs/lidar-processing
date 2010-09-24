// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func plcm(z, y, x, cmin=, cmax=, marker=, msize=) {
/* DOCUMENT plcm, z, y, x, cmin=, cmax=, marker=, msize=
   Plots a scatter plot where z determines the color of the marker. 
   Z, Y, and X must all be the same dimensions. Useful for plotting data that
   is a functoin of three variables, such as latitude, longitude, and
   elevation.
*/
// Original C. W. Wright 1999-11-07
// Rewritten D. Munro 1999-11-27
   extern _plmk_markers;
   default, cmin, z(min);
   default, cmax, z(max);
   default, marker, 1; // square
   default, msize, 1; // no change in size

   if(is_void(x))
      x = indgen(numberof(y));

   w = where(z >= cmin & z <= cmax);
   if(!numberof(w))
      return;
   x = x(w);
   y = y(w);
   z = z(w);

   // Shrink size by factor of 7 from normal marker
   mark = (*_plmk_markers(marker)) * msize / 7.;
   px = mark(,1);
   py = mark(,2);

   n = array(1, 1+numberof(y));
   n(1) = numberof(px);

   plfp, grow(0., z), grow(py, y), grow(px, x), n, edges=0, cmin=cmin,
      cmax=cmax;
}

func plgrid(y, x, color=, width=, type=) {
/* DOCUMENT plgrid, y, x, color=, width=, type=
   Plots a grid. Lines will be plotted vertically at X and horizontally at Y to
   make a square grid. Keywords COLOR, WIDTH, and TYPE are as defined for plm.
*/
   xx = array(x, numberof(y));
   yy = transpose(array(y, numberof(x)));
   plm, yy, xx, color=color, width=width, type=type;
}
