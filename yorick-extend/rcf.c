/*

  $Id$

    This file contains the c functions to implement the rcf.
    c_compfunc is a comparing function required by qsort.

    Original rcf.i by W. Wright, 
    Converted to "C" by Conan Noronha


*/

#include "bcast.h"		//Include files required for the function
#include "yio.h"
#include "defmem.h"
#include "pstdlib.h"
#include "play.h"
#include <string.h>
#include <stdio.h>
#include <errno.h>

static Member type;

//This function is taken directly from Y_LAUNCH/std0.c to get the number of elements in the source array

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

//Function to compare two float values. Used by qsort. Returns -1, 0 or 1

static float *copy, fcounter;
static unsigned int *winners, *fwinners;		//Store the winners temporarily

int c_compfunc(const void *x, const void *y)		//To sort the jury
{
   unsigned int pp,qq;
   int t;

   pp = (unsigned int)(*(unsigned int *)x);
   qq = (unsigned int)(*(unsigned int *)y);

   if (copy[pp] < copy[qq]) t = -1;
   else
   if (copy[pp] == copy[qq]) t = 0;
   else  t = 1;
   return t;
}

int c_compfunc2(const void *x, const void *y)		//To sort the fwinners array
{
   unsigned int pp,qq;
   int t;

   pp = (unsigned int)(*(unsigned int *)x);
   qq = (unsigned int)(*(unsigned int *)y);

   if (pp < qq) t = -1;
   else
   if (pp == qq) t = 0;
   else  t = 1;
   return t;
}

//Float version of the rcf algorithm

unsigned int  c_rcf (float* a, float w, int mode, float* b)
{
  #define MAX_MODE 2

  unsigned int i, j, number_elems, counter, *idx, q;
  float tmp;
  DataBlock *db;
 
  if ( (mode<0) || (mode> MAX_MODE) )		//Error checking for mode & window variables  
    YError("mode must be 0, 1 or 2");
  if (w<=0.0)
    YError("Window size must be positive");

  db = XGetInfo(sp-3);				//stack pointer-4 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;

  idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);	//Generate an index array of max size
  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  copy = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), c_compfunc);//Sort the copy

  if (mode == 2)
     winners = (unsigned int *) malloc ((sizeof(unsigned int))*number_elems);

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;
    tmp =a[idx[i]];				//The element itself will always be in the window

    if (mode ==2)
      winners[counter-1] = idx[i]+1;		//So add its index to winners...increment for yorick

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] <= a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
        if (mode == 1)				//Add to a total if mode 1
          tmp += a[idx[j]];
        else if (mode == 2)
           winners[counter-1] = idx[j]+1;	//In yorick, indexing form 1 is needed
      }
      else
         break;					//Break since the array is sorted

    if (b[1] < (float)counter)			//Refresh the return array, if necessary
    {
       b[1] = (float)counter;
       fcounter = counter;
      
       if (mode == 1 )
          b[0] = tmp/counter;
       else if (mode == 2)
       {

	  if (fwinners)
	     free(fwinners);
	  
	  fwinners = (unsigned int *) malloc ((sizeof(unsigned int))*fcounter);

	  memcpy ((void *)fwinners, (void *)winners, ((sizeof(unsigned int))*fcounter));
       }
       else	//mode 0
           b[0] = a[idx[i]];

    }

    if (a[number_elems-1] <= a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
  free (winners);				//Dont need winners anymore...they are in fwinners
  return fcounter;
}


void c_fillarray (unsigned int c)
{
   memcpy ((void*)c, (void*)fwinners, ((sizeof(unsigned int))*fcounter));
   qsort(c, fcounter, sizeof(unsigned int), c_compfunc2);//Sort the copy
   free (fwinners);
}
