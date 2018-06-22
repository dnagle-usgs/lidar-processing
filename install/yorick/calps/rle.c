// vim: set ts=2 sts=2 sw=2 ai sr et:
#include "yapi.h"

#include <stdio.h>

// three arguments: A, vals, reps
// A is input, array of integers
// vals is output, same type as A
// reps is output, various int type
void Y_rle_encode(int nArgs)
{
  if(nArgs != 3) y_error("invalid parameter count");

  int Atype = yarg_typeid(2);
  long Anum = 0;
  long *A = ygeta_l(2, &Anum, 0);

  // Scan to determine output size requirements
  long Rnum = 1, i = 0;
  for(i = 1; i < Anum; i++) if(A[i-1] != A[i]) Rnum++;

  long index_vals = yget_ref(1);
  long index_reps = yget_ref(0);

  // Create output arrays
  long dims[Y_DIMSIZE];
  dims[0] = 1;
  dims[1] = Rnum;
  long *vals = ypush_l(dims);
  long *reps = ypush_l(dims);

  vals[0] = A[0];
  reps[0] = 1;
  long j = 0, Rmax = 0;
  for(i = 1; i < Anum; i++) {
    if(A[i-1] == A[i]) {
      reps[j]++;
    } else {
      if(j > 0 && reps[j-1] > Rmax) {
        Rmax = reps[j-1];
      }
      j++;
      reps[j] = 1;
      vals[j] = A[i];
    }
  }
  if(reps[Rnum-1] > Rmax) Rmax = reps[Rnum-1];

  // Coerce vals to the same type as A
  if(Atype != Y_LONG) {
    long ntot;
    void *tmp = ygeta_any(1, &ntot, dims, 0);
    tmp = ygeta_coerce(1, tmp, ntot, dims, Y_LONG, Atype);
  }

  int Rtype = Y_LONG;
  if(Rmax <= 255) {
    Rtype = Y_CHAR;
  } else if(Rmax <= 32767) {
    Rtype = Y_SHORT;
  } else if(Rmax <= 2147483647) {
    Rtype = Y_INT;
  }

  // Coerce reps to smallest type that will fit
  if(Rtype != Y_LONG) {
    long ntot;
    void *tmp = ygeta_any(0, &ntot, dims, 0);
    tmp = ygeta_coerce(0, tmp, ntot, dims, Y_LONG, Rtype);
  }

  yput_global(index_vals, 1);
  yput_global(index_reps, 0);

  ypush_nil();
}
