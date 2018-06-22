// vim: set ts=2 sts=2 sw=2 ai sr et:

// Comment this out to enable assertions (only during testing)
#define NDEBUG
// for: assert
#include <assert.h>

// for: strcmp
#include <string.h>

// for Yorick stuff
#include "yapi.h"

#include "multidata.h"

double multidata_compare(multidata_t *data, long a, long b, int stable)
{
  assert(a != b);
  assert(0 <= a);
  assert(0 <= b);
  assert(a < data->count);
  assert(b < data->count);

  double result = 0.;
  long depth;

  for(depth = 0; depth < data->stack; depth++) {
    switch(data->type[depth]) {
      case Y_LONG:
        result = data->l[depth][a] - data->l[depth][b];
        break;

      case Y_DOUBLE:
        result = data->d[depth][a] - data->d[depth][b];
        break;

      case Y_STRING:
        result = strcmp(data->q[depth][a], data->q[depth][b]);
        break;

#ifndef NDEBUG
      default:
        y_error("hit unexpected case in multidata_compare");
        break;
#endif
    }

    if(result != 0) return result;
  }

  // Tie breaker, use indices
  if(stable) return a - b;
  return 0.;
}

multidata_t *multidata_collate(int start, int nstack)
{
  long i, dims[Y_DIMSIZE];
  ypush_check(6);

  multidata_t *data = ypush_scratch(sizeof(multidata_t), 0);
  start++;

  data->count = -1;
  int count_l = 0, count_d = 0, count_q = 0;
  for(i = start; i > start - nstack; i--) {
    if(yarg_nil(i)) continue;
    if(yarg_dims(i, dims, 0) == -1) y_error("non-array encountered");
    if(dims[0] > 1) y_error("multi-dimensional array encountered");
    if(data->count == -1) {
      data->count = dims[1];
    } else if(data->count != dims[1]) {
      y_error("array size mis-match");
    }

    if(yarg_number(i) == 1) {
      count_l++;
    } else if(yarg_number(i) == 2) {
      count_d++;
    } else if(yarg_string(i)) {
      count_q++;
    } else {
      y_error("invalid array type");
    }
  }

  if(data->count == -1) {
    ypush_nil();
    return data;
  }

  data->stack = count_l + count_d + count_q;
  assert(data->stack > 0);

  dims[0] = 1;
  dims[1] = data->stack;
  data->type = ypush_i(dims);
  start++;

  if(count_l) {
    data->l = ypush_scratch(sizeof(long **) * data->stack, 0);
    start++;
  }
  if(count_d) {
    data->d = ypush_scratch(sizeof(double **) * data->stack, 0);
    start++;
  }
  if(count_q) {
    data->q = ypush_scratch(sizeof(ystring_t **) * data->stack, 0);
    start++;
  }

  int j = 0;
  for(i = start; i > start - nstack; i--)  {
    if(yarg_nil(i)) continue;
    if(yarg_number(i) == 1) {
      data->type[j] = Y_LONG;
      data->l[j] = ygeta_l(i, 0, 0);
    } else if(yarg_number(i) == 2) {
      data->type[j] = Y_DOUBLE;
      data->d[j] = ygeta_d(i, 0, 0);
    } else {
      data->type[j] = Y_STRING;
      data->q[j] = ygeta_q(i, 0, 0);
    }
    j++;
  }
  assert(j == data->stack);

  // index gets pushed last so that it's on the top of the stack
  dims[1] = data->count;
  data->index = ypush_l(dims);
  for(i = 0; i < data->count; i++) data->index[i] = i;

  return data;
}

double multidata_sortedness(multidata_t *data)
{
  long chunk, n, m, i;
  long gt = 0, lt = 0, eq = 0;
  double cmp, total;
  int depth;
  long *index = data->index;
  long count = data->count;

  for(
    depth = 0, chunk = count;
    depth < SORTEDNESS_MAX_DEPTH && chunk >= SORTEDNESS_MIN_CHUNK;
    depth++, chunk /= 2
  ) {
    n = chunk/3;
    for(i = n; i+n < count; i += chunk) {
      cmp = multidata_compare(data, index[i], index[i+n], 0);
      if(cmp > 0) {
        gt++;
      } else if(cmp < 0) {
        lt++;
      } else {
        eq++;
      }
    }
  }
  total = gt + lt + eq;

  if(total < SORTEDNESS_MIN_SAMPLE) {
    n = data->count / (SORTEDNESS_MIN_SAMPLE - total);
    if(n < 1) n = 1;
    m = n/2;
    if(m < 1) m = 1;

    for(i = 0; i < data->count; i += n) {
      cmp = multidata_compare(data, index[i], index[i+m], 0);
      if(cmp > 0) {
        gt++;
      } else if(cmp < 0) {
        lt++;
      } else {
        eq++;
      }
    }
    total = gt + lt + eq;
  }

  if(gt > lt) {
    return ((gt + eq) / total - .5) * -2;
  } else {
    return ((lt + eq) / total - .5) * 2;
  }
}

long unfold_stack_obj(int i)
{
  yo_ops_t *ops;
  void *obj = yo_get(i, &ops);
  long fields = ops->count(obj);
  ypush_check(fields);

  // Parameter i was the position in stack. We no longer need it, so re-use it
  // for the loop iterator.
  for(i = 1; i <= fields; i++) ops->get_i(obj, i);

  return fields;
}

void Y_sortedness(int nArgs)
{
  if(nArgs < 1) y_error("invalid call");
  multidata_t *data = multidata_collate(nArgs - 1, nArgs);
  ypush_double(multidata_sortedness(data));
}

void Y_sortedness_obj(int nArgs)
{
  if(nArgs != 1) y_error("invalid call");
  Y_sortedness(unfold_stack_obj(0));
}
