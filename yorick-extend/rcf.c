/*

  $Id$

    This file contains the c functions to implement the rcf.
    c_compfunc is a comparing function required by qsort.

    Original rcf.i by W. Wright, 
    Converted to "C" by Conan Noronha


*/


#include "bcast.h"
#include "yio.h"
#include "defmem.h"
#include "pstdlib.h"
#include "play.h"
#include <string.h>
#include <stdio.h>

#include <errno.h>

int float_compfunc(const void *x, const void *y)
{
   float pp,qq;
   int t;

   pp = (float)(*(float *)x);
   qq = (float)(*(float *)y);

   if (pp < qq) t = -1;
   else
   if (pp == qq) t = 0;
   else  t = 1;
   return t;
}

static Member type;

static DataBlock *XGetInfo(Symbol *s)
{
  DataBlock *db= 0;
  for (;;) {
    if (s->ops==&doubleScalar) {
      type.base= &doubleStruct;
      type.dims= 0;
      type.number= 1;
      break;
    } else if (s->ops==&longScalar) {
      type.base= &longStruct;
      type.dims= 0;
      type.number= 1;
      break;
    } else if (s->ops==&intScalar) {
      type.base= &intStruct;
      type.dims= 0;
      type.number= 1;
      break;
    } else if (s->ops==&dataBlockSym) {
      db= s->value.db;
      if (db->ops==&lvalueOps) {
        LValue *lvalue= (LValue *)db;
        type.base= lvalue->type.base;
        type.dims= lvalue->type.dims;
        type.number= lvalue->type.number;
      } else if (db->ops->isArray) {
        Array *array= (Array *)db;
        type.base= array->type.base;
        type.dims= array->type.dims;
        type.number= array->type.number;
      } else {
        type.base= 0;
        type.dims= 0;
        type.number= 0;
      }
      break;
    } else if (s->ops==&referenceSym) {
      s= &globTab[s->index];
    } else {
      YError("unexpected keyword argument");
    }
  }
  return type.base? 0 : db;
}

void c_rcf (float* c, float w, int mode, float *b)
{
  int i, j, counter;
  float tmp, *a;
  DataBlock *db;
  unsigned int number_elems;

#define MAX_MODE 2

  if ( (mode<0) || (mode> MAX_MODE) )
    YError("mode must be 0, 1 or 2");
  if (w<=0.0)
    YError("Window size must be positive");

  db = XGetInfo(sp-3);
  if (!db) number_elems= (unsigned int)type.number;
    else number_elems= 0;

  printf ("\n num = %d\n",number_elems);

  a = (float *) malloc ((sizeof(float))*number_elems);
  memcpy((void *)a, (void *)c, ((sizeof(float))*number_elems));
  
  qsort(a, number_elems, sizeof(float), float_compfunc);

  for (i=0; i<number_elems-1; i++)
  {
    counter=1;
    tmp =a[i];

    for (j=i+1; j< number_elems;j++)
      if (a[j] <= a[i]+w)
      {
        counter++;
        if (mode == 1)
        {
          tmp += a[j];
        }
      }
      else
        break;

    if (b[1] < counter)
    {
      b[1] = counter;

      if (mode == 1 )
         b[0] = tmp/counter;
      else
         b[0] = a[i];
    }

    if (a[number_elems-1] <= a[i]+w)
      break;

  }
  
  free (a);
}
