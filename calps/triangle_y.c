// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
/*
  This file provides a Yorick wrapper around the functionality in triangle.c
  and triangle.h.

  The triangle.c and triangle.h files are copied from the Triangle program:
    Triangle
    A Two-Dimensional Quality Mesh Generator and Delaunay Triangulator.
    Version 1.6

  Downloaded from:
    http://www.cs.cmu.edu/~quake/triangle.html

  If a new release of Triangle comes out, it should be safe to replace the 1.6
  files with the corresponding files from the new release. However, you will
  have to make one small change to triangle.c in order for it to work with this
  wrapper. Search for the string '#define TRILIBRARY' in triangle.c. It will be
  commented out. You must define this symbol so that the software compiles as a
  callable object library.
*/

#define REAL double
#include <stdlib.h>
#include "triangle.h"
#include "yapi.h"

// This will show up in Yorick as _ytriangulate.
// It expects three arguments: char* opts, double *x, double *y
// It returns: long *v
void Y__ytriangulate(int argc)
{
  long xcount, ycount, dimsv[3], vcount, *v;
  double *x, *y;
  struct triangulateio in, out;
  int i, j, k;
  char *opts;

  if(argc != 3)
    y_error("triangulate requires exactly three arguments");

  // Grab the input from the stack
  opts = ygeta_c(argc-1, 0, 0);
  x = ygeta_d(argc-2, &xcount, 0);
  y = ygeta_d(argc-3, &ycount, 0);

  // Initialize input to triangulate
  in.numberofpoints = xcount;
  in.numberofpointattributes = 0;
  in.pointlist = (REAL *) malloc(in.numberofpoints * 2 * sizeof(REAL));
  in.pointattributelist = (REAL *) NULL;
  in.pointmarkerlist = (int *) NULL;
  in.numberofsegments = 0;
  in.numberofholes = 0;
  in.numberofregions = 0;
  in.regionlist = (REAL *) NULL;

  j = 0;
  for(i = 0; i < xcount; i++) {
    in.pointlist[j++] = x[i];
    in.pointlist[j++] = y[i];
  }

  // Initialize output from triangulate
  out.pointlist = (REAL *) NULL;
  out.pointattributelist = (REAL *) NULL;
  out.pointmarkerlist = (int *) NULL;
  out.trianglelist = (int *) NULL;
  out.triangleattributelist = (REAL *) NULL;

  // Call triangulate, from triangle.i
  triangulate(opts, &in, &out, (struct triangulateio *) NULL);

  // Extract output and stuff in Yorick format
  dimsv[0] = 2;
  dimsv[1] = out.numberoftriangles;
  dimsv[2] = out.numberofcorners;
  vcount = out.numberoftriangles * out.numberofcorners;

  v = ypush_l(dimsv);
  k = 0;
  for(i = 0; i < out.numberofcorners; i++)
    for(j = i; j < vcount; j += out.numberofcorners)
      v[k++] = out.trianglelist[j];

  // Free the memory we consumed
  free(in.pointlist);
  free(out.pointlist);
  free(out.pointattributelist);
  free(out.pointmarkerlist);
  free(out.trianglelist);
  free(out.triangleattributelist);
}
