// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include "yapi.h"

// Finds the determinant of a matrix. Only valid for 4 and 9 element arrays
// (2x2 and 3x3 matrices). Available in Yorick as _ydet.
double det(double *A, long len)
{
  double result;
  
  if(len == 4)
    return A[0]*A[3]-A[1]*A[2];

  if(len == 9)
    return A[0]*(A[4]*A[8]-A[5]*A[7]) +
      A[1]*(A[5]*A[6]-A[3]*A[8]) +
      A[2]*(A[3]*A[7]-A[4]*A[6]);

  y_error("Invalid call to internal function det");
}

// Finds the planar parameters for a set of points. Given three points
// (x1,y1,z1), (x2,y2,z2), and (x3,y3,z3), this finds the constants for the
// equation:
//    Ax + By + Cz + D = 0
// It then normalizes C to 1 so that we can juggle things around to solve for
// z, yielding:
//    z = Ax + By + D
// This is available in Yorick as _yplanar_params_from_pts.
// Arguments *A, *B, and *D are modified.
void planar_params_from_pts(double x1, double y1, double z1,
      double x2, double y2, double z2,
      double x3, double y3, double z3,
      double *A, double *B, double *D)
{
  double mA[9], mB[9], mC[9], mD[9];
  mA[0] = mA[3] = mA[6] = 1;
  mB[1] = mB[4] = mB[7] = 1;
  mC[2] = mC[5] = mC[8] = 1;
  mB[0] = mC[0] = mD[0] = x1;
  mB[3] = mC[3] = mD[3] = x2;
  mB[6] = mC[6] = mD[6] = x3;
  mA[1] = mC[1] = mD[1] = y1;
  mA[4] = mC[4] = mD[4] = y2;
  mA[7] = mC[7] = mD[7] = y3;
  mA[2] = mB[2] = mD[2] = z1;
  mA[5] = mB[5] = mD[5] = z2;
  mA[8] = mB[8] = mD[8] = z3;

  double C = -det(mC, 9);
  *A = det(mA, 9) / C;
  *B = det(mB, 9) / C;
  *D = -det(mD, 9) / C;
}

// Returns a value whose sign indicates the handedness of the cross product.
// The magnitude is meaningless; only the sign (positive, negative, or zero) is
// meaningful.
double cross_product_sign(double x1, double y1, double x2, double y2,
      double x3, double y3)
{
  return (x2-x1)*(y3-y1) - (y2-y1)*(x3-x1);
}

// Yorick interface to cross_product_sign.
// Argument *result is modified.
void _ycross_product_sign(double *x1, double *y1, double *x2, double *y2,
      double *x3, double *y3, double *result, long count)
{
  long i;
  for(i = 0; i < count; i++)
    result[i] = cross_product_sign(x1[i], y1[i], x2[i], y2[i], x3[i], y3[i]);
}

// Tests to see if point (xp,yp) is in the triangle defined by (x1,y1),
// (x2,y2), (x3,y3). Returns 1 if it is, 0 if it is not.
short in_triangle(double x1, double y1, double x2, double y2,
      double x3, double y3, double xp, double yp)
{
  double AB, BC, CA;
  double mn, mx;

  // Check x bounds
  if(x1 < x2) {
    mn = x1;
    mx = x2;
  } else {
    mn = x2;
    mx = x1;
  }
  if(x3 < mn)
    mn = x3;
  else if(x3 > mx)
    mx = x3;

  if(xp < mn || xp > mx)
    return 0;

  // Check y bounds
  if(y1 < y2) {
    mn = y1;
    mx = y2;
  } else {
    mn = y2;
    mx = y1;
  }
  if(y3 < mn)
    mn = y3;
  else if(y3 > mx)
    mx = y3;

  if(yp < mn || yp > mx)
    return 0;

  AB = cross_product_sign(x1,y1,x2,y2,xp,yp);
  BC = cross_product_sign(x2,y2,x3,y3,xp,yp);
  CA = cross_product_sign(x3,y3,x1,y1,xp,yp);

  if((AB >= 0) && (BC >= 0) && (CA >= 0))
    return 1;
  if((AB <= 0) && (BC <= 0) && (CA <= 0))
    return 1;

  return 0;
}

// Yorick interface to in_triangle.
// Argument *result is modified.
void _yin_triangle(double *x1, double *y1, double *x2, double *y2,
      double *x3, double *y3, double *xp, double *yp, short *result, long count)
{
  long i;
  for(i = 0; i < count; i++)
    result[i] = in_triangle(x1[i], y1[i], x2[i], y2[i], x3[i], y3[i], xp[i], yp[i]);
}

// Interpolates the value for a single point, using the given triangulation.
double triangle_interp_single(double *x, double *y, double *z,
      long *v1, long *v2, long *v3, long nv,
      double xp, double yp, double nodata)
{
  short found = 0;
  long i;
  double x1, x2, x3, y1, y2, y3, z1, z2, z3;
  double A, B, C, result;
  // Find triangle that contains xp, yp
  for(i = 0; i < nv; i++) {
    x1 = x[v1[i]-1];
    x2 = x[v2[i]-1];
    x3 = x[v3[i]-1];
    y1 = y[v1[i]-1];
    y2 = y[v2[i]-1];
    y3 = y[v3[i]-1];
    if(in_triangle(x1,y1,x2,y2,x3,y3,xp,yp)) {
      found = 1;
      z1 = z[v1[i]-1];
      z2 = z[v2[i]-1];
      z3 = z[v3[i]-1];
      break;
    }
  }

  if(!found)
    return nodata;

  planar_params_from_pts(x1, y1, z1, x2, y2, z2, x3, y3, z3, &A, &B, &C);
  return A * xp + B * yp + C;
}

// Interpolates the value for a set of points. Available in Yorick as
// _ytriangle_interp.
// Argument zp is modified.
void _ytriangle_interp(double *x, double *y, double *z,
      long *v1, long *v2, long *v3, long nv,
      double *xp, double *yp, double *zp, long np,
      double nodata)
{
  long i;
  for(i = 0; i < np; i++) {
    zp[i] = triangle_interp_single(x,y,z,v1,v2,v3,nv,xp[i],yp[i],nodata);
  }
}

// Creates an ARC ASCII grid file. Available in Yorick as _ywrite_arc_grid.
void write_arc_grid(long ncols, long nrows,
  double xmin, double ymin, double cell, double nodata,
  double *zgrid, char *fn)
{
  FILE *fp;
  long i, j;

  fp = fopen(fn, "w");

  fprintf(fp, "ncols         %d\n", ncols);
  fprintf(fp, "nrows         %d\n", nrows);
  fprintf(fp, "xllcorner     %.3f\n", xmin);
  fprintf(fp, "yllcorner     %.3f\n", ymin);
  fprintf(fp, "cellsize      %.3f\n", cell);
  fprintf(fp, "nodata_value  %.3f\n", nodata);

  for(i = nrows-1; i >= 0; i--) {
    for(j = 0; j < ncols-1; j++)
      fprintf(fp, "%.3f ", zgrid[i*ncols+j]);
    fprintf(fp, "%.3f\n", zgrid[i*ncols+ncols-1]);
  }

  fclose(fp);
}
