// vim: set ts=2 sts=2 sw=2 ai sr et:

/* multidata provides a framework for interacting with multiple parallel
 * arrays. It is primarily intended for sorting, but may have other uses. A few
 * related utility functions are also included.
 *
 * Given a series of data arrays on the stack, you can use mlutidata_collate to
 * create a multidata_t struct instance that captures the data's information.
 * This struct contains references to each data array (omitting void items),
 * information about whether they are long, double, or string, and an index
 * array that maps into them. The index array is initialized as 0 .. count-1.
 *
 * multidata_compare allows you to compare two indicies. These are indices
 * directly into the data arrays; if you are using the index, you will want to
 * pass your indices through it first (data->index[A] instead of A).
 *
 * unfold_stack_obj is a utility function that unrolls an oxy group object into
 * a bunch of data items on the stack. This is primarily intended for making
 * wrappers that allow you to call func(save(a,b,..)) instead of func(a,b,..).
 *
 * multidata_sortedness provides an estimation for how "sorted" an array is.
 *
 * Two Yorick functions are made available as well: Y_sortedness and
 * Y_sortedness_obj. These provide Yorick access to the multidata_sortedness
 * function.
 */

#ifndef MULTIDATA_H
#define MULTIDATA_H

// disable assertions (only enable while testing)
#define NDEBUG
// assert
#include <assert.h>

// memmove, memcpy, strcmp
#include <string.h>

// for: ystring_t
#include "yapi.h"

typedef struct multidata_t {
  // Index into data arrays, which is what we're actually sorting.
  long *index;
  // Number of items in index (and in data arrays)
  long count;

  // Number of items being sorted against
  long stack;
  // Specifies type of each stack position.
  // Should be Y_LONG, Y_DOUBLE, or Y_STRING at each position.
  int *type;
  // Data arrays being sorted against
  long **l;
  double **d;
  ystring_t **q;
} multidata_t;

// Maximum "depth" that sortedness metric will go. Higher values mean it will
// run slower on big ararys, but will give more accurate results.
#define SORTEDNESS_MAX_DEPTH 10

// Minimum "chunk" size used in sortedness metric.
#define SORTEDNESS_MIN_CHUNK 16

// Minimum samples wanted in sortedness metric. If fewer, will attempt to add
// some more.
#define SORTEDNESS_MIN_SAMPLE 32

/* result = multidata_compare(data, a, b, stable);
 * Compares data at A and B and returns 0 if they are equal, something less
 * than 0 if A < B, and something greater than 0 if A > B.
 *
 * data - should be a pointer to a populated instance of multidata_t, as
 *    returned by multidata_collate
 * a, b - two array indices into the data to compare; these must be different
 * stable - whether to make it a stable comparison. If set to 1 and both are
 *    fully equal, ties are broken by comparing the indices. This prevents
 *    equality from happening. Use 0 if you want the possibility of equality.
 *
 * Returns: a double with unrestricted range whose sign signifies how a and b
 * compare.
 */
double multidata_compare(multidata_t *data, long a, long b, int stable);

/* data = multidata_collate(start, nstack);
 * Scans the data arrays found on the stack and populates a data stuct with
 * them to be used by the various sorting algorithms. Also initializes the
 * index array (with 0-based indices).
 *
 * stack - The position in the Yorick stack of the first data item.
 * nstack - The number of items in the Yorick stack being considered.
 *
 * Note that the stack will be scanned in reverse order. That is, if stack is 5
 * and nstack is 3, then the stack items that will be used are at 5, 4, and 3.
 *
 * This pushes several items onto the stack. However, it makes sure that the
 * top item on the stack is the index array, so that it is well positioned to
 * be returned to the caller. (Unless all of the data arrays are void, in which
 * case void is left on top of the stack instead.)
 *
 * Returns: a pointer to a populated instance of multidata_t.
 */
multidata_t *multidata_collate(int start, int nstack);

/* count = unfold_stack_obj(i);
 * Pushes all object members found in the object at stack location i onto the
 * stack. Returns the number of members that were pushed onto the stack.
 */
long unfold_stack_obj(int i);

double multidata_sortedness(multidata_t *data);

// sortedness(a, b, c, ...)
// Returns the sortedness metric of its arguments.
void Y_sortedness(int nArgs);

// sortedness_obj(obj)
// Returns the sortedness metric of the members of obj.
void Y_sortedness_obj(int nArgs);

void Y_target_sortedness(int nArgs);

#endif // MULTIDATA_H
