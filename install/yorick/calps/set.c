// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include <math.h>
#include "yapi.h"

/*
 * The two functions in this file have the following requirements for their
 * input:
 *
 *    - result and A must each be of length An
 *    - B must be of length Bn
 *    - A and B must each be sorted in ascending order
 *    - A and B must each contain only unique values; no duplicates
 *    - result must be initialized to 0 or 1
 *    - flag must be 0 or 1
 *    - result and flag should be different values
 *
 */

// result must be initialized to array(0, An) or array(1, An)
// intersect points will be set to FLAG
void set_intersect_long(long *result, long *A, long An, long *B, long Bn,
long flag)
{
  long Ai, Bi;
  Ai = Bi = 0;
  while(Ai < An && Bi < Bn) {
    if(A[Ai] == B[Bi]) {
      result[Ai] = flag;
      Ai++;
      Bi++;
    } else {
      if(A[Ai] < B[Bi]) {
        Ai++;
      } else {
        Bi++;
      }
    }
  }
}

// result must be initialized to array(0, An) or array(1, An)
// intersect points will be set to FLAG
void set_intersect_double(long *result, double *A, long An, double *B, long Bn,
long flag, double delta)
{
  long Ai, Bi;
  Ai = Bi = 0;
  while(Ai < An && Bi < Bn) {
    if(fabs(A[Ai] - B[Bi]) <= delta) {
      result[Ai] = flag;
      Ai++;
      Bi++;
    } else {
      if(A[Ai] < B[Bi]) {
        Ai++;
      } else {
        Bi++;
      }
    }
  }
}
