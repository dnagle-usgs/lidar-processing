// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#ifndef _CALPS_SETUNIQ_C
#define _CALPS_SETUNIQ_C 1

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "yapi.h"

#define DATA_LT(X, Y) data[X] < data[Y]

#define value_t const long
#define MERGE mu_merge_L
#define MERGEUNIQ mergeuniq_L
#include __FILE__

#undef value_t
#undef MERGE
#undef MERGEUNIQ

#define value_t const double
#define MERGE mu_merge_D
#define MERGEUNIQ mergeuniq_D
#include __FILE__

#undef DATA_LT
#undef value_t
#undef MERGE
#undef MERGEUNIQ

#endif   /* _CALPS_SETUNIQ_C */

#ifdef MERGEUNIQ

/* 
 * Merges the unique elements from two lists.
 *    data - Data array, into which src1, src2, and dst index
 *    src1 - First list of indices; must be sorted
 *    len1 - Length of src1
 *    src2 - Second list of indices; must be sorted
 *    len2 - Length of src2
 *    dst - Output list of indices; will receive sorted unique values
 *    len - Length of output list
 * Only dst and len are modified.
 */
void MERGE(value_t *data, long *src1, long len1, long *src2, long len2,
long *dst, long *len)
{
  long i1, i2, j;
  i1 = i2 = j = 0;

  // Initialize dst array with first item, so comparisons can be made for
  // uniqueness.
  if(DATA_LT(src2[i2], src1[i1]))
  {
    dst[j] = src2[i2];
    i2++;
  }
  else
  {
    dst[j] = src1[i1];
    i1++;
  }
  j++;

  // Process both arrays, pulling smallest from each and skipping duplicates
  while(i1 < len1 && i2 < len2) {
    if(DATA_LT(src2[i2], src1[i1]))
    {
      if(DATA_LT(dst[j-1], src2[i2]))
      {
        dst[j] = src2[i2];
        j++;
      }
      i2++;
    }
    else
    {
      if(DATA_LT(dst[j-1], src1[i1]))
      {
        dst[j] = src1[i1];
        j++;
      }
      i1++;
    }
  }

  // Grab remaining uniques from first array
  while(i1 < len1)
  {
    if(DATA_LT(dst[j-1], src1[i1]))
    {
      dst[j] = src1[i1];
      j++;
    }
    i1++;
  }

  // Grab remaining uniques from second array
  while(i2 < len2)
  {
    if(DATA_LT(dst[j-1], src2[i2]))
    {
      dst[j] = src2[i2];
      j++;
    }
    i2++;
  }

  // j is pointing to the next dst index to fill, which means it's also the
  // length for what we have finished.
  *len = j;
}

void MERGEUNIQ(value_t *data, long *list, long *len)
{
  long *src, *dst, *lens, *temp;
  long i, size, i1, i2, n;

  src = list;
  dst = ypush_scratch(sizeof(long)*(*len), 0);
  lens = ypush_scratch(sizeof(long)*(*len), 0);

  // initialize
  for(i = 0; i < *len; i++) {
    src[i] = i;
    lens[i] = 1;
  }

  for(size = 1; size < *len; size *= 2)
  {
    for(i1 = 0; i1 < *len; i1 += (size * 2))
    {
      i2 = i1 + size;

      // In case we don't have a second section to merge against, just copy
      if(i2 >= *len)
      {
        n = i1+lens[i1];
        for(i = i1; i < n; i++)
          dst[i] = src[i];
      }
      else
      {
        // merge
        MERGE(data, &src[i1], lens[i1], &src[i2], lens[i2], &dst[i1],
          &lens[i1]);
      }
    }

    // Swap src and dst
    temp = src;
    src = dst;
    dst = temp;
  }

  // Update len to reflect the length of the merged array
  *len = lens[0];

  // Copy indices from SRC to LIST (they may or may not be the same array) and
  // convert to 1-based indices instead of 0-based indices.
  for(i = 0; i < *len; i++)
    list[i] = src[i] + 1;

  // Drop the two scratch arrays
  yarg_drop(2);
}

#endif    /* MERGEUNIQ */
