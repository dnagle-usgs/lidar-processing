// vim: set ts=2 sts=2 sw=2 ai sr et:
plug_in, "calps";

func calps_compatibility(nil) {
/* DOCUMENT calps_compatibility()
  Returns an integer that can be used for comptability checks. If any of the
  functions implemented in C-ALPS change in a way that breaks compatibility
  with the previous version of that function, the number returned by this
  function will be incremented and the change will be documented here.

  For example, suppose a function in C-ALPS gets changed to take 6 arguments
  instead of 5. If a user does a CVS update on lidar-processing/src but
  doesn't upgrade their C-ALPS alongside that, then they might run into
  serious problems when their updated Yorick code is trying to use 6 arguments
  but their old C-ALPS code is only accepting 5. The solution is to ensure
  that the Yorick code gets updated to check calps_compatibility() and, if the
  function is the outdated format, adjust behavior accordingly.

  This version of calps_compatibility returns 1.
*/
  return 1;
}

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

// *** defined in geometry.c ***

extern _yinterp_angles;
/* PROTOTYPE
  void interp_angles(double *x, double *y, long xyn,
    double *xp, double *yp, long *xb, long xpypn)
*/

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

// *** defined in ll2utm.c ***

extern _yll2utm;
/* PROTOTYPE
  void ll2utm(double *lat, double *lon, double *north, double *east,
  short *zone, long count, double a, double e2)
*/

extern _yutm2ll;
/* PROTOTYPE
  void utm2ll(double *north, double *east, short *zone, double *lon,
  double *lat, long count, double a, double e2)
*/

// *** defined in navd88.c ***

func calps_n88_interp_qfit2d(x, y, f) {
  result = array(double, dimsof(x));
  _yn88_interp_qfit2d, result, x, y, numberof(result),
    f, dimsof(f)(2), dimsof(f)(3);
  return result;
}

func calps_n88_interp_spline2d(x, y, f) {
  result = array(double, dimsof(x));
  _yn88_interp_spline2d, result, x, y, numberof(result),
    f, dimsof(f)(2), dimsof(f)(3);
  return result;
}

extern _yn88_interp_qfit2d;
/* PROTOTYPE
  void n88_interp_qfit2d(double *result, double *x, double *y, long count,
  double *f, long fxcount, long fycount)
*/

extern _yn88_interp_spline2d;
/* PROTOTYPE
  void n88_interp_spline2d(double *result, double *x, double *y, long count,
  double *f, long fxcount, long fycount)
*/

// *** defined in set.c ***

extern _yset_intersect_long;
/* PROTOTYPE
  void set_intersect_long(long *result, long *A, long An, long *B, long Bn,
  long flag)
*/

extern _yset_intersect_double;
/* PROTOTYPE
  void set_intersect_double(long *result, double *A, long An, double *B,
  long Bn, long flag, double delta)
*/

// *** defined in set_uniq.c ***

extern _ymergeuniq_L;
/* PROTOTYPE
  void mergeuniq_L(long *, long *, long *);
*/

extern _ymergeuniq_D;
/* PROTOTYPE
  void mergeuniq_D(double *, long *, long *);
*/

// *** defined in linux.c
extern get_pid;
/* DOCUMENT get_pid()
  Returns the process ID for the current Yorick process.
*/

__calps_backup = save(
  calps_compatibility,
  _ytriangulate, triangulate,
  _yinterp_angles,
  _ydet, _yplanar_params_from_pts,
  _ycross_product_sign, _yin_triangle,
  _ytriangle_interp, _ywrite_arc_grid,
  _yin_box, _ylevel_short_dips,
  _yll2utm, _yutm2ll,
  calps_n88_interp_qfit2d, calps_n88_interp_spline2d,
  _yset_intersect_long, _yset_intersect_double,
  _ymergeuniq_L, _ymergeuniq_D
);
