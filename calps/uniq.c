// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#ifndef _CALPS_SETUNIQ_C
#define _CALPS_SETUNIQ_C 1

#include <string.h>
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

/*  The unique string code implements uses a variation of the three-way radix
 *  quicksort to find unique strings.
 *
 *  Wikipedia has a short description of this sort here:
 *  http://en.wikipedia.org/w/index.php?title=Quiksort&oldid=546631116#Variants
 *
 *  Much of the code was adapted from a Dr. Dobbs article:
 *  http://www.drdobbs.com/database/sorting-strings-with-three-way-radix-qui/184410724
 *
 *  To simplify code, a few variables are consistently named as thus:
 *    char **data: Array of strings we want to find unique values from
 *    long *list: Array of indices into data (which we're sorting/uniquing)
 *    long depth: A depth in the string at which to compare from
 */

// Return the minimum of two values
#define MIN(a,b) ((a)<=(b) ? (a) : (b))

// Returns the character (at the current depth) at index i (where i is a value
// in list, which indirectly indexes into data)
#define CH(i) ((unsigned char)(data[list[i]][depth]))
// Returns the (sub)string (starting from the current depth) at index i (where
// i is a value in list, which indirectly indexes into data)
#define STR(i) (data[list[i]]+depth)

// Median-of-3 algorithm. Given three indexes into list, returns the one with
// the median value in data.
static long med3(char **data, long *list, long ia, long ib, long ic, long depth)
{
  char va, vb, vc;

  va = CH(ia);
  vb = CH(ib);
  if(va == vb) return ia;

  vc = CH(ic);
  if(va == vc || vb == vc) return ic;

  return va < vb
      ? (vb < vc ? ib : (va < vc ? ic : ia))
      : (vb > vc ? ib : (va < vc ? ia : ic));
}
// Convenience macro to avoid providing data, list, and depth
#define MED3(a,b,c) med3(data, list, a, b, c, depth)

// Selects a suitable pivot from the range a..c
static long select_pivot(char **data, long *list, long a, long c, long depth)
{
  long n = c - a + 1;
  // If less than 3 items, then return the smaller of the one/two items
  if(n < 3) return a < c ? a : c;

  long b = (a + c) / 2;

  // If there are 50 or fewer items, then a simple median-of-3 is performed
  // over the first, last, and middle items. If there are more than 50 items,
  // then 9 values are picked at even intervals; a median-of-three is done on
  // each set of three; then a median-of-three is done on the resulting set of
  // three. This broadens our chances of finding a good pivot value.

  if(n > 50) {
    long d = n/8;
    a = MED3(a, a+d, a+d+d);
    b = MED3(b-d, b, b+d);
    c = MED3(c-d-d, c-d, c);
  }

  return MED3(a, b, c);
}

// Swap two indices in list
static void swap(long *list, long a, long b)
{
  long t = list[a];
  list[a] = list[b];
  list[b] = t;
}
// Convenience macro to avoid providing list
#define SWAP(a,b) swap(list, a, b)

// Swap two chunks of list. a and b are the indices into list where the chunks
// start, and count is the length of the chunks.
static void vecswap(long *list, long a, long b, long count)
{
  while(count--) SWAP(a++, b++);
}
// Convenience macro to avoid providing list
#define VECSWAP(a,b,c) vecswap(list,a,b,c);

// This function requires that all items in the range start..stop are the same
// string. It then scans through those values and finds the smallest index
// value, puts it at index out, then increments out. So this effectively
// removes a series of equal values and stores a single value in the output
// position.
static void assign_first(long *list, long start, long stop, long *out)
{
  list[*out] = list[start];
  // reuse "start" variable as loop iterator
  for(start++; start <= stop; start++) {
    if(list[start] < list[*out]) SWAP(start, *out);
  }
  *out = *out + 1;
}

// This is a variant of the insertion sort that finds unique values. Its call
// signature is the same as quick_uniq. Unique values are sorted starting at 
static void ins_uniq(char **data, long *list, long start, long stop, long *out,
  long depth)
{
  long h, i, j, k, cmp;
  k = *out;
  list[k] = list[start];
  for(i = start + 1; i <= stop; i++) {
    for(j = k; j >= *out; j--) {
      cmp = strcmp(STR(i), STR(j));
      if(cmp > 0) break;
      if(cmp == 0) {
        if(list[i] < list[j]) SWAP(i, j);
        goto next_i;
      }
    }
    k++;
    j++;
    list[k] = list[i];
    for(h = k; h > j; h--) SWAP(h, h-1);
    next_i: ;
  }
  *out = k + 1;
}

// This is the main work function -- the variation on quick sort for finding
// unique values.
//
// Parameters:
//  char **data - array of strings
//  long *list - array of indices into **data
//  The items to sort in *list are start .. stop
//  The next unique item should go into index *out (out <= start)
//  At the end, *out is updated to the next index to use for future unique
//  items.
//  long depth - depth in string to consider (characters before this are
//    identical for this range of items)
void quick_uniq(char **data, long *list, long start, long stop, long *out,
  long depth)
{
  // If there are 10 or fewer items, fall back to the insertion sort
  if(stop - start < 10) {
    ins_uniq(data, list, start, stop, out, depth);
    return;
  }

  unsigned char pval;
  long le;
  long depth0 = depth;
  for(;;) {
    // Find a pivot and move it to the front. Then get its value.
    SWAP(start, select_pivot(data, list, start, stop, depth));
    pval = CH(start);

    // Scan through to find all equal items at beginning. This optimization
    // also lets us quickly handle the common case where all strings are equal
    // at this position.
    le = start + 1;
    while(le <= stop && CH(le) == pval) le++;

    // If ALL items are equal...
    if(le > stop) {
      if(pval != 0) {
        // If it's not the end of the string, increase depth and try again
        depth++;
        continue;
      } else {
        // End of string means all strings equal, just grab the first
        assign_first(list, start, stop, out);
        return;
      }
    }

    break;
  }

  long ge = stop;
  {
    // Using a local scope so that gt, lt do not accummulate on the recursion
    // call stack to save a bit of memory
    long lt = le;
    long gt = ge;

    // Sort the items into four bins:
    // EQUAL | LESS | GREATER | EQUAL
    for(;;) {
      for( ; lt <= gt && CH(lt) <= pval; lt++) {
        if(CH(lt) == pval) SWAP(le++, lt);
      }
      for( ; lt <= gt && CH(gt) >= pval; gt--) {
        if(CH(gt) == pval) SWAP(gt, ge--);
      }
      if(lt > gt) break;
      SWAP(lt++, gt--);
    }

    // Swap the EQUAL portions to the center so that there are three bins:
    // LESS | EQUAL | GREATER
    {
      // Using a local scope so that "r" doesn't accummulate in the recursion
      // call stack, minor savings in memory
      long r;
      r = MIN(le-start, lt-le);
      VECSWAP(start, lt-r, r);
      r = MIN(ge-gt, stop-ge);
      VECSWAP(lt, stop-r+1, r);
    }

    // Change le and ge to bounds of EQUAL region
    le = start + (lt - le);
    ge = stop - (ge - gt);
  }

  // LESS: start .. le-1
  // EQUAL: le .. ge
  // GREATER: ge+1 .. stop

  // Process LESS section
  if(start < le) {
    quick_uniq(data, list, start, le-1, out, depth);
  }

  // Process EQUAL section
  if(pval == 0) {
    assign_first(list, le, ge, out);
  } else {
    quick_uniq(data, list, le, ge, out, depth+1);
  }

  // Process GREATER section
  if(ge < stop) {
    quick_uniq(data, list, ge+1, stop, out, depth);
  }
}

void Y_uniq(int nArgs)
{
  if(nArgs != 1)
    y_error("uniq accepts exactly one argument");

  if(yarg_nil(0) || yarg_rank(0) == -1)
    y_error("uniq only accepts numeric and string arrays");

  long count, dims[Y_DIMSIZE], *list, i, new_count;

  if(yarg_string(0)) {
    ystring_t *data = ygeta_q(0, &count, dims);
    list = ypush_l(dims);
    for(i = 0; i < count; i++) list[i] = i;
    new_count = 0;
    quick_uniq(data, list, 0, count-1, &new_count, 0);

    if(new_count < count) {
      // drop strings, no longer needed; this might free up space (only useful
      // if we'll be allocating more)
      yarg_swap(0,1);
      yarg_drop(1);
    }
  } else if(yarg_number(0) == 1) {
    long *data = ygeta_l(0, &count, dims);
    list = ypush_l(dims);
    new_count = count;
    mergeuniq_L(data, list, &new_count);
  } else if(yarg_number(0) == 2) {
    double *data = ygeta_d(0, &count, dims);
    list = ypush_l(dims);
    new_count = count;
    mergeuniq_D(data, list, &new_count);
  } else {
    y_error("invalid input");
  }

  if(new_count < count) {
    ypush_check(1);
    dims[0] = 1;
    dims[1] = new_count;
    long *result = ypush_l(dims);
    for(i = 0; i < new_count; i++)
      result[i] = list[i]+1;
  } else {
    for(i = 0; i < count; i++) list[i]++;
  }

}

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
static void MERGE(value_t *data, long *src1, long len1, long *src2, long len2,
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

  // Copy indices from SRC to LIST if they aren't the same array
  if(list != src) for(i = 0; i < *len; i++) list[i] = src[i];

  // Drop the two scratch arrays
  yarg_drop(2);
}

#endif    /* MERGEUNIQ */
