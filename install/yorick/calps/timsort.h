// vim: set ts=2 sts=2 sw=2 ai sr et:

#ifndef TIMSORT_H
#define TIMSORT_H

#include "multidata.h"

// enable testing battery (only while testing)
#define MULTISORT_BATTERY

// Specifies the buffer size to use for the stack of pending merges.
#define MAX_MERGE_PENDING 40

// Specifies the minimum chunk size to use for merging. If a run is smaller
// than this, it will be extended using binary sort.
#define MIN_MERGE 8

// Initial gallop value.
#define INITIAL_MIN_GALLOP 7

typedef struct timstate_t {
  multidata_t *data;

  // base, len, pos are stack for tracking sorted runs to merge
  // base: offset into index where run starts
  // len: length of run
  // size: size of stack
  long base[MAX_MERGE_PENDING];
  long len[MAX_MERGE_PENDING];
  int size;

  // Current min gallop
  int min_gallop;

  // Scratch space to use for merging
  long *scratch;
} timstate_t;

// reference:
// http://bugs.python.org/file4451/timsort.txt
// http://svn.python.org/projects/python/trunk/Objects/listsort.txt
// http://svn.python.org/projects/python/trunk/Objects/listobject.c
// http://stromberg.dnsalias.org/svn/sorts/compare/trunk/timsort_reimp.m4
// http://jeffreystedfast.blogpsot.com/2011/04/optimizing-merge-sort.html

/* multidata_bisort(data, low, high, start);
 * Performs a binary insertion sort on the given data in the range low..high
 * inclusive. This algorithm is efficient for tiny arrays but highly
 * inefficient for large arrays.
 *
 * data - should be a pointer to a populated instance of multidata_t, as
 *    returned by multidata_collate
 * low, high - the starting and stopping indices of the range to sort
 *    (inclusive)
 * start - the first indice in the range low..high that isn't known to be
 *    sorted already; most of the time start=low (or start=low+1), but timsort
 *    optimizes by jumping past the section it knows is already sorted
 */
void multidata_bisort(multidata_t *data, long low, long high, long start);

/* multidata_timsort(data)
 * Performs a timsort on the given data. Timsort is a modified merge sort
 * developed for Python by Tim Peters. It performs excellently on data that has
 * some level of order already. However, it performs an order of magnitude or
 * more worse on random data. (Nonetheless, it always performs much faster than
 * the interpreted msort function.)
 */
void multidata_timsort(multidata_t *data);

// timsort(a, b, c, ...)
// Performs a timsort on its arguments.
void Y_timsort(int nArgs);

// timsort_obj(obj)
// Performs a timsort on the members of obj.
void Y_timsort_obj(int nArgs);

#endif
