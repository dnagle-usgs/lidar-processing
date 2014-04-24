// vim: set ts=2 sts=2 sw=2 ai sr et:

/* This implements a function for interpolating angles. The call signature of
 * the function in Yorick is:
 *
 *    yp = interp_angles(y, x, xp, rad=)
 *
 * Array X must be monotonic, either ascending or descending. In order to
 * accommodate both sorting orders without an impact to performance, this file
 * does some fancy #include calls to implement two versions (ascending and
 * descending) of the functions that do all the interpolation work.
 *
 * If XP is sorted (ascending only), then the complexity of this algorithm is
 * linear: O(N+M) (where N is numberof(xp) and M is numberof(x). If XP is not
 * sorted (or is descending), then the complexity of the algorithm is
 * log-linear: O(N log M).
 */

#ifndef SORT_ASC

#include "constants.h"
#include "yapi.h"
#include <math.h>

static int interp_sorted_desc(double *y, double *x, double *xp, double *yp,
  long count, long countp, long *start, long *stop);
static void interp_bisect_desc(double *y, double *x, double *xp, double *yp,
  long count, long start, long stop);

static int interp_sorted_asc(double *y, double *x, double *xp, double *yp,
  long count, long countp, long *start, long *stop);
static void interp_bisect_asc(double *y, double *x, double *xp, double *yp,
  long count, long start, long stop);

static double interp_ratio(double *y, double *x, double xp, long b1, long b2,
  long *lastb);

// interp_angles(yp, x, xp, rad=)
#define INTERP_ANGLES_KEYCT 1
void Y_interp_angles(int nArgs)
{
  static char *knames[INTERP_ANGLES_KEYCT+1] = {"rad", 0};
  static long kglobs[INTERP_ANGLES_KEYCT+1];

  double *y, *x, *xp, *yp;
  long count, countp;
  int rad, scalar;

  {
    int kiargs[INTERP_ANGLES_KEYCT];

    yarg_kw_init(knames, kglobs, kiargs);

    // First argument is y, an array of known angles
    int iarg_y = yarg_kw(nArgs-1, kglobs, kiargs);
    if(iarg_y == -1) y_error("must provide 3 arguments");
    // Second argument is i, an array of known reference values (must be
    // strictly monotonic)
    int iarg_x = yarg_kw(iarg_y-1, kglobs, kiargs);
    if(iarg_x == -1) y_error("must provide 3 arguments");
    // Third argument is ip, reference values to interpolate for
    int iarg_xp = yarg_kw(iarg_x-1, kglobs, kiargs);
    if(iarg_xp == -1) y_error("must provide 3 arguments");
    // soak up any remaining keywords
    if(yarg_kw(iarg_xp-1, kglobs, kiargs) != -1)
      y_error("must provide only 3 argmuments");

    // Are we using radians? By default, no
    rad = (kiargs[0] == -1) ? 0 : yarg_true(kiargs[0]);

    if(yarg_rank(iarg_y) != yarg_rank(iarg_x))
      y_error("ANG and X must have same dimensions");

    long num_y, num_x;
    if(yarg_rank(iarg_y) != yarg_rank(iarg_x))
      y_error("X and Y must have same dimensionality");
    y = ygeta_d(iarg_y, &num_y, 0);
    x = ygeta_d(iarg_x, &num_x, 0);
    if(num_y != num_x)
      y_error("X and Y must have same size");
    count = num_x;

    // If it's a scalar and we retrieve it with ygeta_d, Yorick gets confused.
    // So note if it's a scalar and instead copy it to a temporary array.
    scalar = yarg_rank(iarg_xp) == 0;
    long dims[Y_DIMSIZE];
    if(scalar) {
      dims[0] = dims[1] = countp = 1;
      xp = ypush_d(dims);
      xp[0] = ygets_d(iarg_xp+1);
      yarg_swap(0, iarg_xp+1);
      yarg_drop(1);
    } else {
      xp = ygeta_d(iarg_xp, &countp, dims);
    }

    if(!rad) {
      long i;
      if(yarg_scratch(iarg_y)) {
        for(i = 0; i < num_y; i++)
          y[i] *= DEG2RAD;
      } else {
        double *tmp = ypush_d(dims);
        for(i = 0; i < num_y; i++)
          tmp[i] = y[i] * DEG2RAD;
        y = tmp;
        yarg_swap(0, iarg_y+1);
        yarg_drop(1);
      }
    }

    // This is put on the top of the stack and will be the return value
    yp = ypush_d(dims);
  }

  long start = 0, stop = 0;
  if(x[0] < x[count-1]) {
    if(!interp_sorted_asc(y, x, xp, yp, count, countp, &start, &stop)) {
      interp_bisect_asc(y, x, xp, yp, count, start, stop);
    }
  } else {
    if(!interp_sorted_desc(y, x, xp, yp, count, countp, &start, &stop)) {
      interp_bisect_desc(y, x, xp, yp, count, start, stop);
    }
  }

  // Convert back to degrees if necessary
  if(!rad) {
    long i;
    for(i = 0; i < countp; i++)
      yp[i] *= RAD2DEG;
  }

  // If input xp was scalar, then be sure to return a scalar.
  if(scalar) {
    ypush_double(yp[0]);
  }
}

// interp_ratio
//
// Once interp_sorted_* or interp_bisect_* have determined which two entries in
// X a given XP fall between, this function is used to calculate the
// corresponding YP.
//
// Parameters:
//  *y, *x - The input arrays as provided to Y_interp_angles
//  xp - A specific value to interpolate for
//  b1, b2 - The upper and lower bound around this xp. It should always be the
//    case that b1 == b2 - 1.
//  *lastb - This is used for caching. If trigonometric functions are used,
//    their values are cached and the corresponding b1 value is stashed in
//    *lastb. If the next call uses the same value for b1, the trig values
//    won't need to be re-calculated.
//
// Returns: Double value for yp.
static double interp_ratio(double *y, double *x, double xp, long b1, long b2,
  long *lastb)
{
  static double cosp, sinp, cos1 = 0., cos2 = 0., sin1 = 0., sin2 = 0.;
  double ratio = (xp - x[b1]) / (x[b2] - x[b1]);

  // We only need to use trigonometry if the difference between the two
  // angles is greater than pi. We use a constant slightly smaller than
  // pi, which means we rarely use trig when we don't need to (but it's
  // good enough, no need to over-optimize).
  //
  // Notably, the difference between the two angles will be greater than
  // pi when they are near to but on opposite sides of the "rollover"
  // point: just above zero and just below 2pi.
  if(fabs(y[b1] - y[b2]) > PI) {

    // Simple caching. In practice, we're very likely to encounter series
    // of angles to interpolate within the same pair of adjacent angles.
    // An extra comparison + assignment is cheap, whereas repeated sets
    // of 4 trigonometric operations are expensive.
    if(b1 != *lastb) {
      cos1 = cos(y[b1]);
      cos2 = cos(y[b2]);
      sin1 = sin(y[b1]);
      sin2 = sin(y[b2]);
      *lastb = b1;
    }

    cosp = cos1 + ratio * (cos2 - cos1);
    sinp = sin1 + ratio * (sin2 - sin1);

    return atan2(sinp, cosp);
  } else {
    return y[b1] + ratio * (y[b2] - y[b1]);
  }
}

// This defines interp_sorted_asc and interp_bisect_asc
#define SORT_ASC 1
#include __FILE__
#undef SORT_ASC

// This defines interp_sorted_desc and interp_bisect_desc
#define SORT_ASC 0
#include __FILE__
#undef SORT_ASC

#else

#if SORT_ASC == 1
#  define INTERP_SORTED interp_sorted_asc
#  define INTERP_BISECT interp_bisect_asc
#  define LT(X,Y) ((X) < (Y))
#  define LTE(X,Y) ((X) <= (Y))
#else
#  define INTERP_SORTED interp_sorted_desc
#  define INTERP_BISECT interp_bisect_desc
#  define LT(X,Y) ((X) > (Y))
#  define LTE(X,Y) ((X) >= (Y))
#endif

// interp_sorted_asc and interp_sorted_desc
//
// This function assumes that XP is in ascending sorted order and attempts to
// use the linear algorithm for interpolation. If it succeeds, then it returns
// 1. If it discovers that XP is not sorted, it returns 0.
//
// Even if XP is not sorted, this will still generally take care of at least
// some of the calculations. In particular, if leading values are below xp[0]
// and trailing values are above xp[countp-1], those values are all taken care
// of (even if they're not sorted, provided they're out of bounds). Then
// whatever series of values are actually sorted at the beginning of xp are
// handled as well, until a non-sorted entry is found. At that point, *start
// and *stop are set to the bounds of the data that still need to be sorted and
// 0 is returned.
//
// Parameters:
//  *y, *x, *xp - Input as provided to Y_interp_angles.
//  *yp - Return value for Y_interp_angles.
//  count, countp - Lengths of x and xp, respectively
//  *start, *stop - The start and stop bounds of what needs to be processed
//    yet, if everything isn't sorted.
//
// Returns: 1 if everything was handled, 0 if anything wasn't handled
static int INTERP_SORTED(double *y, double *x, double *xp, double *yp,
  long count, long countp, long *start, long *stop)
{
  long i, b1 = 0, b2 = 0, lastb = -1;
  // Last valid index into x and y
  long last = count-1;

  // Assign everything that's below bounds
  i = 0;
  while(i < countp && LTE(xp[i], x[0])) {
    yp[i++] = y[0];
  }
  *start = i;

  // Assign everything that's above bounds
  i = countp-1;
  while(i >= *start && LTE(x[last], xp[i])) {
    yp[i--] = y[last];
  }
  *stop = i;

  // If stop < start, then the two above handled everything
  if(*stop < *start) {
    return 1;
  }

  // Scan through what remains
  i = *start;
  b2 = 0;
  while(i < *stop && b2 < count) {
    // Advance b2 beyond xp[i]
    while(LT(x[b2], xp[i]) && b2 < last) {b2++;}
    b1 = b2 - 1;

    while(i < *stop && LT(xp[i], x[b2])) {
      if(xp[i] == x[b2]) {
        yp[i] = y[b2];
      } else {
        yp[i] = interp_ratio(y, x, xp[i], b1, b2, &lastb);
      }

      if(LT(xp[i+1], xp[i])) {
        // Not sorted! Abort!
        *start = i+1;
        return 0;
      }

      i++;
    }
    b2++;
  }
  *start = i;

  return *stop < *start;
}

// interp_bisect_asc and interp_bisect_desc
//
// This performs a bisection search to find the appropriate elements to
// interpolate between for each value in xp. Unlike interp_sorted_*, this is
// guaranteed to handle all values between *start and *stop.
//
// Parameters:
//  *y, *x, *xp - Input as provided to Y_interp_angles.
//  *yp - Return value for Y_interp_angles.
//  count - Length of x
//  start, stop - The start and stop bounds of what needs to be processed.
//
// Returns: 1 if everything was handled, 0 if anything wasn't handled
static void INTERP_BISECT(double *y, double *x, double *xp, double *yp,
  long count, long start, long stop)
{
  long i, b1 = 0, b2 = count-1, bp, lastb = -1;
  for(i = start; i <= stop; i++) {
    if(LT(xp[i], x[0])) {
      // below bounds
      yp[i] = y[0];
    } else if(LT(x[count-1], xp[i])) {
      // above bounds
      yp[i] = y[count-1];
    } else {
      // in bounds

      b1 = 0;
      b2 = count-1;

      while(b2 - b1 > 1) {
        bp = (b1 + b2)/2;
        if(LT(x[bp], xp[i])) {
          b1 = bp;
        } else {
          b2 = bp;
        }
      }

      if(xp[i] == x[b1]) {
        yp[i] = y[b1];
      } else if(xp[i] == x[b2]) {
        yp[i] = y[b2];
      } else {
        yp[i] = interp_ratio(y, x, xp[i], b1, b2, &lastb);
      }
    }
  }
}

#undef INTERP_SORTED
#undef INTERP_BISECT
#undef LT
#undef LTE

#endif
