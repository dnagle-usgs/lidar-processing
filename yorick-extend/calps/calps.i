// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
plug_in, "calps";

// *** defined in triangle_y.c ***
// Supported by triangle.c and triangle.h

extern _ytriangulate;
/* DOCUMENT _ytriangulate(options, x, y)
   Lower-level interface to triangulation routine. Do not use directly. Use
   triangulate instead.
*/

func triangulate(x, y, verbose=) {
/* DOCUMENT v = triangulate(x, y, verbose=, maxarea=)
   Performs a Delaunay triangulation over the input x and y coordinates. All
   coordinates should be unique. Returns an array of indices into x and y for
   the coordinates for each triangle's vertices in the triangulation.

   The return result v will be a Nx3 array, where N is the number of triangles.
   Thus, v(1,) is the three vertices for the first triangle; v(,1) is an array
   of all the first vertexes for all the triangles.

   By default, triangulate operates silently. Using verbose= will provide
   output to the console. There are five levels of verbosity:
      verbose=1  Very basic summary
      verbose=2  More detailed summary and statistics
      verbose=3  Provides vertex-by-vertex details; runs VERY slowly
      verbose=4  Even more information, including per-vertex memory info, etc.
      verbose=5  Even MORE information...
   You probably won't want to use a verbosity above 2.
*/
   if(is_void(verbose)) verbose=0;

   // Core options needed:
   //    S: Disables Steiner points
   //    B: Suppresses boundary markers in output
   opts = "SB";

   if(!verbose)
      opts += "Q";
   else if(verbose > 1)
      opts += array("V", verbose-1)(sum);

   // Blow up if input not conformable and 1-dimensional
   if(dimsof(x)(1) != 1 || dimsof(y)(1) != 1 || numberof(x) != numberof(y))
      error, "Input x and y must be one-dimensional and must be the same length.";

   return _ytriangulate(strchar(opts), x, y);
}

// *** defined in gridding.c ***

// func det in mathop.i makes use of this, if it's available
extern _ydet;
/* PROTOTYPE
   double det(double *A, long len)
*/

extern _yplanar_params_from_pts;
/* PROTOTYPE
   void planar_params_from_pts(double x1, double y1, double z1, double x2,
   double y2, double z2, double x3, double y3, double z3, double *A, double *B,
   double *D)
*/

extern _ycross_product_sign;
/* PROTOTYPE
   void _ycross_product_sign(double *x1, double *y1, double *x2, double *y2,
   double *x3, double *y3, double *result, long count)
*/

extern _yin_triangle;
/* PROTOTYPE
   void _yin_triangle(double *x1, double *y1, double *x2, double *y2,
   double *x3, double *y3, double *xp, double *yp, short *result, long count)
*/

extern _ytriangle_interp;
/* PROTOTYPE
   void _ytriangle_interp(double *x, double *y, double *z, long *v1, long *v2,
   long *v3, long nv, double *xp, double *yp, double *zp, long np,
   double nodata)
*/

extern _ywrite_arc_grid;
/* PROTOTYPE
   void write_arc_grid(long ncols, long nrows, double xmin, double ymin,
   double cell, double nodata, double *zgrid, char *fn)
*/

// *** defined in region.c ***

extern _yin_box;
/* PROTOTYPE
   void in_box(double *x, double *y, double xmin, double xmax, double ymin,
   double ymax, short *in, long count)
*/

// *** defined in lines.c ***

extern _ylevel_short_dips;
/* PROTOTYPE
   void level_short_dips(double *seq, double *dist, double thresh, long count)
*/
