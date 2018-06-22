// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"
#include <math.h>

#ifndef MAX
#define MAX( a, b ) ( ((a) > (b)) ? (a) : (b) )
#endif
#ifndef MIN
#define MIN( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif

// Defines the maximum size for a spline neighborhood.
#define MAXSPLINE 6

double n88_qfit(double x, double *f) {
  double t1, x2, t2;
  t1 = f[1] - f[0];
  x2 = 0.5 * x * (x-1);
  t2 = f[2] - 2 * f[1] + f[0];
  return f[0] + x * t1 + x2 * t2;
}

void n88_interp_qfit2d(
  double *result, double *x, double *y, long count,
  double *f, long fxcount, long fycount)
{
  double xc, yc, xp, yp;
  double interim[3];
  long i, xi, yi, offset;

  for(i = 0; i < count; i++) {
    // Convert Yorick 1-based values into C 0-based values
    xc = x[i] - 1;
    yc = y[i] - 1;

    // Determine index for corner of 3x3 matrix to use
    xi = MAX(MIN((long)xc, fxcount - 3), 0);
    yi = MAX(MIN((long)yc, fycount - 3), 0);

    // Determine position within sub matrix
    xp = xc - xi;
    yp = yc - yi;

    // Convert corner location into offset
    offset = xi + yi * fxcount;

    // Interim results
    interim[0] = n88_qfit(xp, f+offset);
    offset += fxcount;
    interim[1] = n88_qfit(xp, f+offset);
    offset += fxcount;
    interim[2] = n88_qfit(xp, f+offset);

    result[i] = n88_qfit(yp, interim);
  }
}

double n88_splinefit(double x, double *f, long size) {
  long j, k;
  double p, xx, result;
  double q[MAXSPLINE], r[MAXSPLINE];

  // Initialize spline moments, q
  q[0] = r[0] = 0.;
  for(k = 1; k < size-1; k++) {
    p = q[k-1]/2 + 2;
    q[k] = -0.5/p;
    r[k] = (3.0*(f[k+1] - 2.0*f[k] + f[k-1]) - r[k-1]/2.0)/p;
  }
  r[size-1] = 0.0;
  for(k = size - 2; k > 0; k--) {
    r[k] += q[k] * r[k+1];
  }

  if(x < 1) {
    result = f[0] + (x-2) * (f[1] - f[0] - r[1]/6.);
  } else if(x >= size) {
    result = f[size-1] + (x-size-1) * (f[size-1] - f[size-2] + r[size-2]/6.);
  } else {
    j = (long)x;
    xx = x - j;
    result = f[j-1] + xx * ((f[j]-f[j-1]-r[j-1]/3.-r[j]/6.)
                    + xx * (r[j-1]/2.
                    + xx * (r[j]-r[j-1])/6.));
  }

  return(result);
}

void n88_interp_spline2d(
  double *result, double *x, double *y, long count,
  double *f, long fxcount, long fycount)
{
  long i, j, offset, size, thresh, xi, yi;
  double dist, xp, yp;
  double interim[MAXSPLINE];

  for(i = 0; i < count; i++) {
    dist = MIN(MIN(x[i], y[i]), MIN(fxcount - x[i], fycount - y[i]));
    for(size = MAXSPLINE; size > 0; size -= 2) {
      thresh = (size/2) - 1;
      if(thresh > 0 && dist <= thresh)
        continue;

      xi = MAX(MIN((long)(x[i]-thresh), fxcount - size), 0);
      yi = MAX(MIN((long)(y[i]-thresh), fycount - size), 0);

      xp = x[i] - xi;
      yp = y[i] - yi;

      offset = xi + yi * fxcount;

      for(j = 0; j < size; j++)
        interim[j] = n88_splinefit(xp, f + offset + fxcount * j, size);

      result[i] = n88_splinefit(yp, interim, size);
      size = -1;
    }
  }
}
