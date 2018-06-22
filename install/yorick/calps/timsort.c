// vim: set ts=2 sts=2 sw=2 ai sr et:

// Comment this out to enable assertions (only during testing)
#define NDEBUG
// for: assert
#include <assert.h>

// for: memmove
#include <string.h>

// for Yorick stuff
#include "yapi.h"

#include "multidata.h"
#include "timsort.h"

#define LT(A, B) (multidata_compare(state->data, A, B, 1) < 0)
#define LTE(A, B) (multidata_compare(state->data, A, B, 1) <= 0)
#define GT(A, B) (multidata_compare(state->data, A, B, 1) > 0)
#define GTE(A, B) (multidata_compare(state->data, A, B, 1) >= 0)

static long min_run_length(long num);

static void reverse_range(long *index, long low, long high);

static long count_run_and_make_ascending(timstate_t *state,
    long *index, long low, long high);

static long gallop_right(timstate_t *state, long key,
    long *index, long base, long len, long hint);

static long gallop_left(timstate_t *state, long key,
    long *index, long base, long len, long hint);

static void push_run(timstate_t *state, long base, long len);

static void merge_force_collapse(timstate_t *state);

static void merge_at(timstate_t *state, long i);

static void merge_low(timstate_t *state, long base1, long len1,
    long base2, long len2);

static void merge_high(timstate_t *state, long base1, long len1,
    long base2, long len2);

// reference:
// http://bugs.python.org/file4451/timsort.txt
// http://svn.python.org/projects/python/trunk/Objects/listsort.txt
// http://svn.python.org/projects/python/trunk/Objects/listobject.c
// http://stromberg.dnsalias.org/svn/sorts/compare/trunk/timsort_reimp.m4
// http://jeffreystedfast.blogpsot.com/2011/04/optimizing-merge-sort.html


// Returns the minimum acceptable run length for an array of the specified
// size. Natural runs shorter will be extended with binary sort.
//
// If num < MIN_MERGE, use num as is (too small to bother)
//
// If num is power of 2, return MIN_MERGE/2
// 
// Otherwise, return k such that MIN_MERGE/2 <= k <= MIN_MERGE and num/k is
// close to but strictly less than a power of 2.
long min_run_length(long num)
{
  assert(num >= 0);

  // low_bit becomes 1 if any 1 bits are shifted off
  int low_bit = 0;

  while(num >= MIN_MERGE) {
    low_bit |= (num & 1);
    num >>= 1;
  }
  return num + low_bit;
}

// Reverses the items in data within the range low..high-1.
void reverse_range(long *data, long low, long high)
{
  long tmp;
  high--;
  while(low < high) {
    tmp = data[low];
    data[low] = data[high];
    data[high] = tmp;
    low++;
    high--;
  }
}

// Returns the length of the run beginning at the specified position in the
// specified array and reverses the run if it is descending.
//
// A run is the longest ascending sequence with:
//  data[low] <= data[low+1] <= data[low+2] <= ...
//
// Or the longest descending sequence with:
//  data[low] > data[low+1] > data[low+2] > ...
//
// The strictness in descending is necessary to avoid violating sort stability.

// Determines the length of the leading ascending or descending run. If
// descending, flips it to ascending. Returns run length.
//
// In order to maintain stable sort (and avoid extra work), ascending is <=
// while descending is >.
//
// low is index to start looking for run
// high is index after last element to consider for run
//
// Returns length of the run beginning at low
long count_run_and_make_ascending(timstate_t *state,
    long *index, long low, long high)
{
  assert(low < high);
  long run_high = low + 1;
  if(run_high == high) return 1;

  if(LT(index[run_high], index[low])) {
    run_high++;
    while(run_high < high && LT(index[run_high], index[run_high-1])) {
      run_high++;
    }
    reverse_range(index, low, run_high);
  } else {
    run_high++;
    while(run_high < high && GTE(index[run_high], index[run_high-1])) {
      run_high++;
    }
  }

  return run_high - low;
}

// Locates position at which to insert the specified key into the specified
// sorted range. If range contains an element equal to key, returns the index
// after the rightmost equal element.
//
// key: key whose insertion point to search for
// index: array in which to search
// base: first element in range to search
// len: length of range, > 0
// hint: index at which to start search, 0 <= hint < len
//
// The closer hint is to the result, the faster this will complete.
//
// Returns k such that 0 <= k <= len such that index[b+k-1] < key <=
// index[b+k], pretending that index[b-1] is minus infinity and index[b+len] is
// infinity.
//
// Algorithm has two phases:
// 1. Jump forward at increasingly large steps to try to find interval where
//    key should go.
// 2. Use binary search to find exact location in interval for key.
long gallop_right(timstate_t *state, long key,
    long *index, long base, long len, long hint)
{
  assert(len > 0);
  assert(hint >= 0);
  assert(hint < len);

  long max_offset, tmp, midpoint;
  long last_offset = 0;
  long offset = 1;

  if(LT(key, index[base+hint])) {
    // Gallop left until [b+hint-offset] <= key < [b+hint-last_offset]
    max_offset = hint + 1;
    while(offset < max_offset && LT(key, index[base + hint - offset])) {
      last_offset = offset;
      offset = (offset << 1) + 1;
      if(offset <= 0) offset = max_offset;
    }
    if(offset > max_offset) offset = max_offset;

    // Make relative to base
    tmp = last_offset;
    last_offset = hint - offset;
    offset = hint - tmp;
  } else {
    // Gallop right until [b+hint+last_offset] <= key < [b+hint+offset]
    max_offset = len - hint;
    while(offset < max_offset && GTE(key, index[base + hint + offset])) {
      last_offset = offset;
      offset = (offset << 1) + 1;
      if(offset <= 0) offset = max_offset;
    }
    if(offset > max_offset) offset = max_offset;

    // Make relative to base
    last_offset += hint;
    offset += hint;
  }

  assert(-1 <= last_offset);
  assert(last_offset < offset);
  assert(offset <= len);

  last_offset++;
  while(last_offset < offset) {
    midpoint = last_offset + ((offset - last_offset) / 2);
    if(LT(key, index[base+midpoint])) {
      offset = midpoint;
    } else {
      last_offset = midpoint + 1;
    }
  }

  assert(last_offset == offset);
  return offset;
}

// As gallop_right, except if equal elements are found, returns index of
// leftmost.
long gallop_left(timstate_t *state, long key,
    long *index, long base, long len, long hint)
{
  assert(len > 0);
  assert(hint >= 0);
  assert(hint < len);

  long max_offset, tmp, midpoint;
  long last_offset = 0;
  long offset = 1;

  if(GT(key, index[base+hint])) {
    // Gallop right until [b+hint+last_offset] <= key < [b+hint+offset]
    max_offset = len - hint;
    while(offset < max_offset && GT(key, index[base + hint + offset])) {
      last_offset = offset;
      offset = (offset << 1) + 1;
      if(offset <= 0) offset = max_offset;
    }
    if(offset > max_offset) offset = max_offset;

    // Make relative to base
    last_offset += hint;
    offset += hint;
  } else {
    // Gallop left until [b+hint-offset] <= key < [b+hint-last_offset]
    max_offset = hint + 1;
    while(offset < max_offset && LTE(key, index[base + hint - offset])) {
      last_offset = offset;
      offset = (offset << 1) + 1;
      if(offset <= 0) offset = max_offset;
    }
    if(offset > max_offset) offset = max_offset;

    // Make relative to base
    tmp = last_offset;
    last_offset = hint - offset;
    offset = hint - tmp;
  }

  assert(-1 <= last_offset);
  assert(last_offset < offset);
  assert(offset <= len);

  last_offset++;
  while(last_offset < offset) {
    midpoint = last_offset + ((offset - last_offset) / 2);
    if(GT(key, index[base+midpoint])) {
      last_offset = midpoint + 1;
    } else {
      offset = midpoint;
    }
  }

  assert(last_offset == offset);
  return offset;
}

// Temporary convenience macros
#define A state->len[number-1]
#define B state->len[number]
#define C state->len[number+1]

// Pushes a run starting at BASE with length LEN onto the stack in STATE.
// Then auto-merges as necessary.
void push_run(timstate_t *state, long base, long len)
{
  long number;

  state->base[state->size] = base;
  state->len[state->size] = len;
  state->size++;

  // Always leave room for at least one more
  if(state->size == MAX_MERGE_PENDING) {
    number = state->size - 2;
    if(number > 0 && A < C) number--;
    merge_at(state, number);
  }

  // Examines the stack of runs waiting to be merged and merges adjacent runs
  // until the stack invariants are re-established:
  //
  //  A > B + C
  //  B > C
  //
  // Where A, B, C are the lengths of three consecutive runs.

  while(state->size > 1) {
    number = state->size - 2;
    if(number > 0 && A <= B + C) {
      if(A < C) number--;
      merge_at(state, number);
    } else if(B <= C) {
      merge_at(state, number);
    } else {
      break;
    }
  }
}

// Merges all remaining pending runs until only one remains. This gets called
// once, to complete the sort.
void merge_force_collapse(timstate_t *state)
{
  long number;
  while(state->size > 1) {
    number = state->size - 2;
    if(number > 0 && A < C) number--;
    merge_at(state, number);
  }
}

#undef A
#undef B
#undef C

// Merges the two runs at stack indices i and i+1. Run i must be the 2nd or 3rd
// to last run on the stack.
void merge_at(timstate_t *state, long i)
{
  assert(state->size >= 2);
  assert(i >= 0);
  assert(i == state->size - 2 || i == state->size - 3);

  long *index = state->data->index;

  long base1 = state->base[i];
  long len1 = state->len[i];
  long base2 = state->base[i+1];
  long len2 = state->len[i+1];

  assert(len1 > 0);
  assert(len2 > 0);
  assert(base1 + len1 == base2);

  // Update the stack info
  state->len[i] = len1 + len2;
  if(i == state->size - 3) {
    state->base[i+1] = state->base[i+2];
    state->len[i+1] = state->len[i+2];
  }
  state->size--;

  // Find where the first element of run2 goes in run 1. Prior elements of run1
  // can be ignored (already in place).
  long k = gallop_right(state, index[base2], index, base1, len1, 0);
  assert(k >= 0);
  base1 += k;
  len1 -= k;
  if(len1 == 0) return;

  // Find where the last element of run1 goes in run2. Subsequent elements in
  // run2 can be ignored (already in place).
  len2 = gallop_left(state, index[base1+len1-1], index, base2, len2, len2 - 1);
  assert(len2 >= 0);
  if(len2 == 0) return;

  // Merge remaining runs
  if(len1 <= len2) {
    merge_low(state, base1, len1, base2, len2);
  } else {
    merge_high(state, base1, len1, base2, len2);
  }
}

// Merge two adjacent runs in place, in a stable fashion. The first element of
// the first run must be greater than the first element of the second run, and
// the last element of the first run must be greater than all elements of the
// second run.
//
// This should only be called when len1 <= len2. Use merge_high when len1 >=
// len2. If len1==len2, either can be used.
//
// base1 - index of first element in first run to merge
// len1 - length of first run (must be > 0)
// base2 - index of first element in second run to merge (must be base1 + len1)
// len2 - length of second run (must be > 0)
void merge_low(timstate_t *state, long base1, long len1,
    long base2, long len2)
{
  assert(len1 > 0);
  assert(len2 > 0);
  assert(base1 + len1 == base2);
  assert(len1 <= len2);


  long *tmp = state->scratch;
  long *index = state->data->index;
  long min_gallop = state->min_gallop;
  long loops_done = 0;
  long count1, count2;

  // Copy first run into temp area
  memmove(tmp, index + base1, sizeof(long) * len1);

  // Index into tmp
  long cursor1 = 0;
  // Index into index where we are copying from
  long cursor2 = base2;
  // Index into index where we are copying to
  long dest = base1;

  index[dest] = index[cursor2];
  dest++;
  cursor2++;
  len2--;
  if(len2 == 0) {
    memmove(index+dest, tmp+cursor1, sizeof(long) * len1);
    return;
  }
  if(len1 == 1) {
    memmove(index+dest, index+cursor2, sizeof(long) * len2);
    index[dest+len2] = tmp[cursor1];
    return;
  }

  while(1) {
    // Number of times in a row that the first run won
    count1 = 0;
    // Number of times in a row that the second run won
    count2 = 0;

    // Do straightfoward thing until (if ever) one run starts winning
    // consistently.
    while(1) {
      assert(len1 > 1);
      assert(len2 > 0);
      if(LT(index[cursor2], tmp[cursor1])) {
        index[dest] = index[cursor2];
        dest++;
        cursor2++;
        count2++;
        count1 = 0;
        len2--;
        if(len2 == 0) {
          loops_done = 1;
          break;
        }
      } else {
        index[dest] = tmp[cursor1];
        dest++;
        cursor1++;
        count1++;
        count2 = 0;
        len1--;
        if(len1 == 1) {
          loops_done = 1;
          break;
        }
      }

      if(count1 >= min_gallop || count2 >= min_gallop) break;
    }

    if(loops_done) break;

    // One run is winning so consistently that galloping may be a huge win. So
    // try that, and continue galloping until (if ever) neither run appears to
    // be winning consistently anymore.
    while(1) {
      assert(len1 > 1);
      assert(len2 > 0);

      count1 = gallop_right(state, index[cursor2], tmp, cursor1, len1, 0);
      if(count1 != 0) {
        memmove(index+dest, tmp+cursor1, sizeof(long) * count1);
        dest += count1;
        cursor1 += count1;
        len1 -= count1;
        if(len1 <= 1) {
          loops_done = 1;
          break;
        }
      }
      index[dest] = index[cursor2];
      dest++;
      cursor2++;
      len2--;
      if(len2 == 0) {
        loops_done = 1;
        break;
      }

      count2 = gallop_left(state, tmp[cursor1], index, cursor2, len2, 0);
      if(count2 != 0) {
        memmove(index+dest, index+cursor2, sizeof(long) * count2);
        dest += count2;
        cursor2 += count2;
        len2 -= count2;
        if(len2 == 0) {
          loops_done = 1;
          break;
        }
      }
      index[dest] = tmp[cursor1];
      dest++;
      cursor1++;
      len1--;
      if(len1 == 1) {
        loops_done = 1;
        break;
      }

      min_gallop--;

      if(count1 < INITIAL_MIN_GALLOP && count2 < INITIAL_MIN_GALLOP) {
        break;
      }
    }
    if(loops_done) break;

    if(min_gallop < 0) min_gallop = 0;
    // Penalize for leaving gallop mode
    min_gallop += 2;
  }

  state->min_gallop = (min_gallop < 1) ? 1 : min_gallop;

  if(len1 == 1) {
    assert(len2 > 0);
    memmove(index+dest, index+cursor2, sizeof(long) * len2);
    index[dest+len2] = tmp[cursor1];
  } else if(len1 == 0) {
    y_error("comparison function did something wrong!");
  } else {
    assert(len2 == 0);
    assert(len1 > 1);
    memmove(index+dest, tmp+cursor1, sizeof(long) * len1);
  }
}

// Like merge_low, but for len1 >= 2.
//
// base1 - index of first element in first run to merge
// len1 - length of first run (must be > 0)
// base2 - index of first element in second run to merge (must be base1 + len1)
// len2 - length of second run (must be > 0)
void merge_high(timstate_t *state, long base1, long len1,
    long base2, long len2)
{
  assert(len1 > 0);
  assert(len2 > 0);
  assert(base1 + len1 == base2);


  long *tmp = state->scratch;
  long *index = state->data->index;
  long min_gallop = state->min_gallop;
  long loops_done = 0;
  long count1, count2;

  // Copy second run into temp area
  memmove(tmp, index + base2, sizeof(long) * len2);

  // Index into list
  long cursor1 = base1 + len1 - 1;
  // Index into tmp where we are copying from
  long cursor2 = len2 - 1;
  // Index into index where we are copying to
  long dest = base2 + len2 - 1;

  index[dest] = index[cursor1];
  dest--;
  cursor1--;
  len1--;
  if(len1 == 0) {
    memmove(index+dest-(len2-1), tmp, sizeof(long) * len2);
    return;
  }
  if(len2 == 1) {
    dest -= len1;
    cursor1 -= len1;
    memmove(index+dest+1, index+cursor1+1, sizeof(long) * len1);
    index[dest] = tmp[cursor2];
    return;
  }

  while(1) {
    // Number of times in a row that the first run won
    count1 = 0;
    // Number of times in a row that the second run won
    count2 = 0;

    // Do straightfoward thing until (if ever) one run starts winning
    // consistently.
    while(1) {
      assert(len1 > 0);
      assert(len2 > 1);
      if(LT(tmp[cursor2], index[cursor1])) {
        index[dest] = index[cursor1];
        dest--;
        cursor1--;
        count1++;
        count2 = 0;
        len1--;
        if(len1 == 0) {
          loops_done = 1;
          break;
        }
      } else {
        index[dest] = tmp[cursor2];
        dest--;
        cursor2--;
        count2++;
        count1 = 0;
        len2--;
        if(len2 == 1) {
          loops_done = 1;
          break;
        }
      }

      if(count1 >= min_gallop || count2 >= min_gallop) break;
    }

    if(loops_done) break;

    // One run is winning so consistently that galloping may be a huge win. So
    // try that, and continue galloping until (if ever) neither run appears to
    // be winning consistently anymore.
    while(1) {
      assert(len1 > 0);
      assert(len2 > 1);

      count1 = len1 - gallop_right(state, tmp[cursor2], index, base1, len1, len1-1);
      if(count1 != 0) {
        dest -= count1;
        cursor1 -= count1;
        len1 -= count1;
        memmove(index+dest+1, index+cursor1+1, sizeof(long) * count1);
        if(len1 == 0) {
          loops_done = 1;
          break;
        }
      }
      index[dest] = tmp[cursor2];
      dest--;
      cursor2--;
      len2--;
      if(len2 == 1) {
        loops_done = 1;
        break;
      }

      count2 = len2 - gallop_left(state, index[cursor1], tmp, 0, len2, len2-1);
      if(count2 != 0) {
        dest -= count2;
        cursor2 -= count2;
        len2 -= count2;
        memmove(index+dest+1, tmp+cursor2+1, sizeof(long) * count2);
        if(len2 <= 1) {
          loops_done = 1;
          break;
        }
      }
      index[dest] = index[cursor1];
      dest--;
      cursor1--;
      len1--;
      if(len1 == 0) {
        loops_done = 1;
        break;
      }

      min_gallop -= 1;

      if(count1 < INITIAL_MIN_GALLOP && count2 < INITIAL_MIN_GALLOP) {
        break;
      }
    }
    if(loops_done) break;

    if(min_gallop < 0) min_gallop = 0;
    // Penalize for leaving gallop mode
    min_gallop += 2;
  }

  state->min_gallop = (min_gallop < 1) ? 1 : min_gallop;

  if(len2 == 1) {
    assert(len1 > 0);
    dest -= len1;
    cursor1 -= len1;
    memmove(index+dest+1, index+cursor1+1, sizeof(long) * len1);
    index[dest] = tmp[cursor2];
  } else if(len2 == 0) {
    y_error("comparison function did something wrong!");
  } else {
    assert(len1 == 0);
    assert(len2 > 0);
    memmove(index+dest-(len2-1), tmp, sizeof(long) * len2);
  }
}

void multidata_timsort(multidata_t *data)
{
  if(data->count < 2) return;
  long drop = 0;

  timstate_t *state = ypush_scratch(sizeof(timstate_t), 0);
  drop++;

  long dims[Y_DIMSIZE];
  dims[0] = 1;
  dims[1] = data->count/2;
  state->scratch = ypush_l(dims);
  drop++;

  state->data = data;
  state->size = 0;
  state->min_gallop = INITIAL_MIN_GALLOP;

  long min_run, run_len, force;
  long num_remaining = data->count;
  long low = 0;
  long high = data->count;

  // No need to sort a single item
  if(num_remaining < 2) return;

  // Small array? Simplify by finding run then using binary sort.
  if(num_remaining < MIN_MERGE) {
    run_len = count_run_and_make_ascending(state, state->data->index, low, high);
    multidata_bisort(state->data, low, high-1, run_len);

    // Drop the stuff we pushed on the Yorick stack
    yarg_drop(drop);
    return;
  }

  min_run = min_run_length(num_remaining);
  while(num_remaining > 0) {
    run_len = count_run_and_make_ascending(state, state->data->index, low, high);
    if(run_len < min_run && low + run_len < high) {
      force = num_remaining <= min_run ? num_remaining : min_run;
      multidata_bisort(state->data, low, low+force-1, low+run_len);
      run_len = force;
    }

    push_run(state, low, run_len);
    
    low += run_len;
    num_remaining -= run_len;
  }

  assert(low == high);
  merge_force_collapse(state);
  assert(state->size == 1);

  // Drop the stuff we pushed on the Yorick stack
  yarg_drop(drop);
}

void Y_timsort(int nArgs)
{
  if(nArgs < 1) y_error("invalid call");

  // multidata_collate leaves index on top of stack (unless all data items are
  // void, in which case nil() is left on top).
  multidata_t *data = multidata_collate(nArgs - 1, nArgs);

  // If count is < 1, then collate left nil() on top of stack; return
  if(data->count < 1) {
    return;
  }

  // If count == 1, then force index to 1-based and return
  if(data->count == 1) {
    data->index[0] = 1;
    return;
  }

  // Invoke sort. This function returns the stack to its current condition
  // prior to exiting.
  multidata_timsort(data);

  // Update index to 1-based array indices
  long i;
  for(i = 0; i < data->count; i++) data->index[i]++;
}

void Y_timsort_obj(int nArgs)
{
  if(nArgs != 1) y_error("invalid call");
  Y_timsort(unfold_stack_obj(0));
}

// Sorts the specified range of the array using binary insertion sort, which is
// effective on small numbers of elements.
//
// This takes advantage of initial sorting by assuming that low...start-1 are
// already sorted.
//
// low: low index of range to sort
// high: high index of range to sort
// start: first element in range not known to be sorted
void multidata_bisort(multidata_t *data, long low, long high, long start)
{
  long left, right, mid, pivot;
  long *index = data->index;

  assert(low <= start);
  assert(start <= high);

  if(start == low) start++;

  for(/* start = start */; start <= high; start++) {
    pivot = index[start];

    left = low;
    right = start;
    assert(left <= right);

    // [low, left) <= pivot < [right, start)
    while(left < right) {
      mid = left + ((right - left) / 2);
      if(multidata_compare(data, pivot, index[mid], 1) < 0) {
        right = mid;
      } else {
        left = mid + 1;
      }
    }
    assert(left == right);

    if(left < start) {
      memmove(index + left + 1, index + left, sizeof(long) * (start - left));
      index[left] = pivot;
    }
  }
}
