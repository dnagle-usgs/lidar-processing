// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#ifndef SORT_ASC

#include "yapi.h"
#include <math.h>
#include <stdio.h>
#define PI 3.141592653589793238462643383279502884197
#define DEG2RAD (PI/180.)
#define RAD2DEG (180./PI)

static double interp_ratio(double *y, double *x, double xp, long b1, long b2,
  long *lastb);

#define SORT_ASC 1
#include __FILE__
#undef SORT_ASC

#define SORT_ASC 0
#include __FILE__
#undef SORT_ASC

// interp_angles(ang, x, xp, rad=)
#define INTERP_ANGLES_KEYCT 1
void Y_interp_angles(int nArgs)
{
  static char *knames[INTERP_ANGLES_KEYCT+1] = {"rad", 0};
  static long kglobs[INTERP_ANGLES_KEYCT+1];

  double *y, *x, *xp, *yp;
  long count, countp;
  int rad;

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
    y = ygeta_d(iarg_y, &num_y, 0);
    x = ygeta_d(iarg_x, &num_x, 0);
    if(num_y != num_x) y_error("X and Y must have same dimensions");
    count = num_x;

    long num_xp, dims[Y_DIMSIZE];
    xp = ygeta_d(iarg_xp, &num_xp, dims);
    countp = num_xp;

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

  // Determine whether reference data is ascending or descending so that we
  // know how to make comparisons
  // int asc = x[0] < x[count-1];

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
}

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

static int INTERP_SORTED(double *y, double *x, double *xp, double *yp,
  long count, long countp, long *start, long *stop);
static void INTERP_BISECT(double *y, double *x, double *xp, double *yp,
  long count, long start, long stop);

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
