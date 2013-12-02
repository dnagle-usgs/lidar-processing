// vim: set ts=2 sts=2 sw=2 ai sr et:
plug_in, "calps";

func calps_compatibility(nil) {
/* DOCUMENT calps_compatibility()
  Returns an integer that can be used for comptability checks. If any of the
  functions implemented in C-ALPS change in a way that breaks compatibility
  with the previous version of that function, the number returned by this
  function will be incremented and the change will be documented here.

  Version 1
    Base version.

  Version 2
    Fixed unique to handle null strings properly. Version 1 seg faulted when
    encountering string(0).

  Version 3
    Fixed compatibility issue that caused wf_centroid to seg fault on some
    systems when called as a subroutine.

  This version of calps_compatibility returns 3.
*/
  return 3;
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

// *** defined in interp_angles.c ***

extern interp_angles;
/* DOCUMENT interp_angles(ang, i, ip, rad=)

  This performs linear interpolation on a sequence of angles. This is designed
  to accept arguments similar to interp. It circumvents problems at the
  boundaries of the cycle by breaking the angle into its component pieces
  (using trigonometric functions).

  Parameters:
    ang: The known angles around which to interpolate.
    i: The reference values corresponding to the known values. Must be
      strictly monotonic.
    ip: The reference values for which you want to interpolate values.

  Options:
    rad= Set to 1 if the angles are in radians. By default, this assumes
      degrees.
*/
// If you change this documentation, be sure to also change the documentation
// in core ALPS.

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

extern level_short_dips;
/* DOCUMENT leveled = level_short_dips(seq, dist=, thresh=)
  Removes short "dips" in a data array, smoothing out some of its "noise".

  seq should be a 1-dimensional array of numerical values. For example:
    seq=[4,4,4,3,3,4,4,4,5,5,5,6,5,5]

  The sequnce of "3,3" in the above is a short "dip". This function is
  intended to smooth that sort of thing out:
    leveled=[4,4,4,4,4,4,4,4,5,5,5,6,5,5]

  Short peaks will be left alone; only short dips will be leveled.

  Parameter:
    seq: An array of numbers with values to be smoothed out.

  Options:
    dist= If provided, this must be the same length of seq. It defaults to
      [1,2,3...numberof(seq)]. This is used with thresh to determine which
      items on either side of a value are used for comparisons. This array
      is the cummulative differences of distances from point to point. (So
      the default assumes they are equally spaced.)
    thresh= The threshold for how far on either side of a value the algorithm
      should look for determining whether it's a dip. Default is 10.

  Examples:
    > seq = [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
    > seq
    [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
    > level_short_dips(seq, thresh=2)
    [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
    > level_short_dips(seq, thresh=4)
    [2,2,1,1,1,1,1,1,1,2,2,2,2,2,2,3]
    > level_short_dips(seq, thresh=5)
    [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3]
    > dist = [2,1,1,2,1,1,2,1,1,2,1,1,2,1,1](cum)
    > dist
    [0,2,3,4,6,7,8,10,11,12,14,15,16,18,19,20]
    > level_short_dips(seq, thresh=4, dist=dist)
    [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
*/
// If you change this documentation, be sure to also change the documentation
// in core ALPS.

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

// *** defined in unique.c ***

extern unique;
/* DOCUMENT unique(x)
  Returns an array of longs such that X(sort(X)) is a monotonically increasing
  array of the unique values of X. X can contain integer, real, or string
  values. X may have any dimensions, but the return result will always be
  one-dimensional. If multiple elements have the same value, the index of the
  first value will be used.
*/

// *** defined in linux.c ***
extern get_pid;
/* DOCUMENT get_pid()
  Returns the process ID for the current Yorick process.
*/

// *** defined in profiler.c ***

extern profiler_init;
/* DOCUMENT profiler_init, places
  Initializes the profiler ticker. PLACES is an integer between 0 and 9 and
  specifies how many sub-second places to include. 0 means that profiler_ticks
  will report values in seconds. 9 means that profiler_ticks will report values
  in nanoseconds. Users on 32-bit systems will need to use lower values for
  places to avoid overflowing the size of long integers.

  This also resets the offset used, just as with profiler_reset.

  If not called, then by default PLACES=0.
*/

extern profiler_lastinit;
/* DOCUMENT profiler_lastinit()
  Returns the value specified for the last call to profiler_init.
*/

extern profiler_reset;
/* DOCUMENT profiler_reset
  Resets the profiler ticker. The "time" returned by profiler_ticks subtracts
  an offset that is set by profiler_reset to help avoid overflowing the time
  result. So profiler_reset should be called prior to profiling.
*/

extern profiler_ticks;
/* DOCUMENT profiler_ticks()
  Returns an integer time value. This time value has meaning as defined via
  profiler_init and profiler_reset. However, it should be treated as an
  arbitrary time measurement used for interval comparison, as in profiling.

  The time measured is wall time.
*/

// *** defined in eaarl_decode_fast.c ***

extern eaarl_decode_fast;
/* DOCUMENT result = eaarl_decode_fast(fn, start, stop)
  Decodes the data in the specified TLD file from offset START through offset
  STOP. START and STOP must each be scalar integers.
        
  This performs a faster decode than alternative functions because it pulls
  only the data typically needed during processing.
      
  Parameters:
    fn: Should be a full path to a TLD file.
    start: The byte addres (1-based) where the first raster to decode starts.
    stop: The byte address (1-based) where the last raster to decode ends. This
      may also be 0, which means to decode to the end of the file.

  Options:
    rnstart= Starting raster number. If provided, then the raster field will be
      added, treating the raster found at START as raster RNSTART and numbering
      the ones that follow sequentially.
    raw= Specifies whether raw data is desired.
      raw=0   Default; soe will be updated using eaarl_time_offset
      raw=1   All data returned as it was in the file
    wfs= By default, waveforms are included. Use wfs=0 to disable, which will
      omit the rx and tx fields.

  Returns:
    An oxy group object containing the following array members:
      digitizer - int8_t
      dropout - int8_t 
      pulse - int8_t 
      irange - int16_t
      scan_angle - int16_t
      raster - int32_t (if rnstart!=0)
      soe - double
      tx - pointer (if wfs=1)
      rx - pointer x 4 (if wfs=1)
    All arrays have the same size and dimensions, except for RX which has an
    extra dimension of size 4.
*/

// *** defined in wf_centroid.c ***

extern wf_centroid;
/* DOCUMENT position = wf_centroid(wf, lim=)
  -or- wf_centroid, wf, position, intensity, lim=

  Returns the centroid index for a waveform.

  Parameter:
    wf: Should be a vector of intensity values, with 0 representing "no power".

  Output parameters:
    position: The floating-point position into WF where the centroid is
      located. Note that the centroid's location may actually be outside the
      bounds of WF, particularly if WF contains negative values. If WF is [],
      then POSITION is set to 1e1000 (inf) to represet the invalid condition.
    intensity: The floating-point intensity value found at POSITION,
      interpolated. Points outside of range will receive the intensity of the
      first or last sample (whichever is closer).

  Options:
    lim= Limit number of points considered. If omitted, the whole waveform is
      considered. If provided, only the first LIM energy values are used.
      (In other words, wf(:lim) is used.) Must be a non-negative integer if
      provided.

  Returns:
    The same value as POSITION above.

  If wf=[], then will return inf.
*/

extern cent;
/* DOCUMENT cent(wf, lim=)
  Compute the centroid of "wf" using the first LIM points. If wf is an array
  of type char, it will first be inverted, converted to long, and have bias
  removed using the first point. Otherwise, the wf will be used as is.

  lim= Limit number of points considered. If omitted, only the first 12
     points are considered. Must be a non-negative integer if provided.

  Return result is array(double, 3):
    result(1) = centroid range
    result(2) = peak range
    result(3) = peak power

  If the waveform has fewer than 2 samples, the result will be [0,0,0].

  If a centroid cannot be calculated, then result(1) will be 10000 to indicate
  an error.
*/

// *** Defined in fs_rx.c ***

extern eaarl_fs_rx_cent_eaarlb;
/* DOCUMENT eaarl_fs_rx_cent_eaarlb, pulses
  Updates the given pulses oxy group object with first return info using the
  centroid from the specified channel. The following fields are added to
  pulses:
    frx - Location in waveform of first return
    fint - Peak intensity value of first return
    fchannel - Channel used (=channel except for chan 4, which uses 2)
    fbias - The channel range bias (ops_conf.chn%d_range_bias)
*/

__calps_backup = save(
  calps_compatibility,
  _ytriangulate, triangulate,
  interp_angles,
  _ydet, _yplanar_params_from_pts,
  _ycross_product_sign, _yin_triangle,
  _ytriangle_interp, _ywrite_arc_grid,
  _yin_box, _ylevel_short_dips,
  _yll2utm, _yutm2ll,
  calps_n88_interp_qfit2d, calps_n88_interp_spline2d,
  _yset_intersect_long, _yset_intersect_double,
  unique,
  get_pid,
  profiler_init, profiler_lastinit, profiler_reset, profiler_ticks,
  eaarl_decode_fast,
  wf_centroid, cent,
  eaarl_fs_rx_cent_eaarlb
);

