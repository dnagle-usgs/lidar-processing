// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func parse_plopts(str, &type, &color, &size) {
/* DOCUMENT parse_plopts, str, type, color, size
   Parses the options in the string STR and stores the values found in TYPE,
   COLOR, and SIZE (which are output parameters).

   Most plotting commands take three values that are frequently used:
      type= or marker=, which indicates a style for the plot
      color=, for the plot's color
      width= or msize=, which indicates the width/size of the plot
   This function allows these three values to be provided by a single string.
   The string should be "TYPE COLOR SIZE", where TYPE and COLOR are strings and
   SIZE is a number.

   TYPE may be any string. However, when the string is one of square, cross,
   triangle, circle, diamond, cross2, or triangle2, it will be converted to the
   corresponding number for that symbol for the plmk command.

   COLOR may be any of the permitted Yorick color names. It may also be a hex
   string in format "#RRGGBB", in which case it will be converted to
   [RR,GG,BB].

   SIZE may be an integer or a decimal value, but it will be returned as a
   double.

   It is permissible to provide a shortened string of "TYPE COLOR" or "TYPE" or
   even "". The omitted values will be set to [].

   Example:
      > parse_plopts, "solid black 1.0", type, color, size
      > plg, y, x, type=type, color=color, width=size
*/
   type = color = string(0);
   size = 0.;
   count = sread(str, type, color, size);
   if(count < 1) type = [];
   if(count < 2) color = [];
   if(count < 3) size = [];
   marker = where(type == ["square", "cross", "triangle", "circle", "diamond",
      "cross2", "triangle2"]);
   if(numberof(marker)) type = marker(1);
   R = G = B = '\0';
   if(color && sread(color, format="#%2x%2x%2x", R, G, B) == 3)
      color = [R,G,B];
}

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
