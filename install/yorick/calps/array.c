// vim: set ts=2 sts=2 sw=2 ai sr et:
#include "yapi.h"

static void mnxmxx(int iarg, long *mnx, long *mxx)
{
  int number = yarg_number(iarg);
  // 0 = not a number, 3 = complex
  if(number == 0 || number == 3) y_error("invalid input");

  *mnx = 0;
  *mxx = 0;

  // Scalar input
  if(!yarg_rank(iarg)) return;

  long count = 0, i = 0, index = 0;

  #define WORK(TYPE, FUNC) \
  do { \
    TYPE *data = FUNC(iarg, &count, 0); \
    for(i = 1; i < count; i++) { \
      if(data[i] > data[*mxx]) *mxx = i; \
      else if(data[i] < data[*mnx]) *mnx = i; \
    } \
  } while(0)

  switch(yarg_typeid(iarg)) {
    case Y_CHAR:
      WORK(char, ygeta_c);
      break;
    case Y_SHORT:
      WORK(short, ygeta_s);
      break;
    case Y_INT:
      WORK(int, ygeta_i);
      break;
    case Y_LONG:
      WORK(long, ygeta_l);
      break;
    case Y_FLOAT:
      WORK(float, ygeta_f);
      break;
    case Y_DOUBLE:
      WORK(double, ygeta_d);
      break;
    default:
      y_error("invalid type");
      break;
  }

  #undef WORK
}

void Y_mnxmxx(int nArgs)
{
  long mnx = 0, mxx = 0, index = 0;

  if(nArgs < 1 || nArgs > 3) y_error("invalid parameter count");

  mnxmxx(nArgs-1, &mnx, &mxx);

  if(nArgs > 1) {
    index = yget_ref(nArgs-2);
    ypush_long(mnx+1);
    yput_global(index, 0);
    yarg_drop(1);
  }
  if(nArgs > 2) {
    index = yget_ref(nArgs-3);
    ypush_long(mxx+1);
    yput_global(index, 0);
    yarg_drop(1);
  }

  if(yarg_subroutine()) return;

  long dims[Y_DIMSIZE];
  dims[0] = 1;
  dims[1] = 2;
  long *result = ypush_l(dims);
  result[0] = mnx+1;
  result[1] = mxx+1;
}

void Y_minmax(int nArgs)
{
  long mnx = 0, mxx = 0, index = 0;

  if(nArgs < 1 || nArgs > 3) y_error("invalid parameter count");

  mnxmxx(nArgs-1, &mnx, &mxx);

  long dims[Y_DIMSIZE];

  #define WORK(TYPE, YGET, YPUSH) \
  do { \
    TYPE *data = YGET(nArgs-1, 0, 0); \
    \
    if(nArgs > 1) { \
      index = yget_ref(nArgs-2); \
      dims[0] = 0; \
      TYPE *tmp = YPUSH(dims); \
      tmp[0] = data[mnx]; \
      yput_global(index, 0); \
      yarg_drop(1); \
    } \
    \
    if(nArgs > 2) { \
      index = yget_ref(nArgs-3); \
      dims[0] = 0; \
      TYPE *tmp = YPUSH(dims); \
      tmp[0] = data[mxx]; \
      yput_global(index, 0); \
      yarg_drop(1); \
    } \
    \
    if(!yarg_subroutine()) { \
      dims[0] = 1; \
      dims[1] = 2; \
      TYPE *result = YPUSH(dims); \
      result[0] = data[mnx]; \
      result[1] = data[mxx]; \
    } \
  } while(0)

  switch(yarg_typeid(nArgs-1)) {
    case Y_CHAR:
      WORK(char, ygeta_c, ypush_c);
      break;
    case Y_SHORT:
      WORK(short, ygeta_s, ypush_s);
      break;
    case Y_INT:
      WORK(int, ygeta_i, ypush_i);
      break;
    case Y_LONG:
      WORK(long, ygeta_l, ypush_l);
      break;
    case Y_FLOAT:
      WORK(float, ygeta_f, ypush_f);
      break;
    case Y_DOUBLE:
      WORK(double, ygeta_d, ypush_d);
      break;
    default:
      y_error("invalid type");
      break;
  }

  #undef WORK
}
