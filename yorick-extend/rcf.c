/*

  $Id$

    This file contains the c functions to implement the rcf.
    
    c_frcf is the rcf implementation for float type data
    c_fcompfunc is a comparing function required by qsort to sort the float jury
    c_lrcf is the rcf implementation for long type data
    c_lcompfunc is a comparing function required by qsort to sort the long jury

    c_fillarray is used in mode 2, to fill the winners into a yorick type array.
    c_compfunc2 is used by qsort, to sort the array of winners.
    XGetInfo is a function from std0.c, to get information on the array size
    
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

static Member type;

/* This function is taken directly from Y_LAUNCH/std0.c 
 * to get the number of elements in the source array
 */

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

static float *fcopy;					//Global pointer to the float jury
static unsigned int *winners, *fwinners, fcounter;	//Store the winners temporarily & global number of winners count.
static long *lcopy;					//Global pointer to the long jury

/* Function to compare index values of the jury, based on the contents of
 * that indexed location. 
 * Used by qsort for float jury. Returns -1, 0 or 1
 */

int c_fcompfunc(const void *x, const void *y)
{
   unsigned int pp,qq;
   int t;

   pp = (unsigned int)(*(unsigned int *)x);
   qq = (unsigned int)(*(unsigned int *)y);

   if (fcopy[pp] < fcopy[qq]) t = -1;
   else
   if (fcopy[pp] == fcopy[qq]) t = 0;
   else  t = 1;
   return t;
}


/* Function to compare values of the array, to sort fwinners.
 * Used by qsort. Returns -1, 0 or 1
 */
int c_compfunc2(const void *x, const void *y)
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

/* Used to fill a 'Yorick' array with the winners indices
 * This function is called only for mode==2
 */

void c_fillarray (unsigned int c)
{
   memcpy ((void*)c, (void*)fwinners, ((sizeof(unsigned int))*fcounter));	//Copy fwinners into the yorick array
   qsort(c, fcounter, sizeof(unsigned int), c_compfunc2);			//Sort the copy
   free (fwinners);								//fwinners not needed now
}

/* Float version of the rcf algorithm.
 * Returns the number of winners
 */

unsigned int  c_frcf (float* a, float w, int mode, float* b)
{
  #define MAX_MODE 2

  unsigned int i, j, number_elems, counter, *idx, q;
  float tmp;
  DataBlock *db;
 
  if ( (mode<0) || (mode> MAX_MODE) )		//Error checking for mode & window variables  
    YError("mode must be 0, 1 or 2");
  if (w<=0.0)
    YError("Window size must be positive");

  db = XGetInfo(sp-3);				//stack pointer-3 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;

  idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);	//Generate an index array of max size
  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  fcopy = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), c_fcompfunc);//Sort the copy

  if (mode == 2)				//Mode 2 needs to store the winners
     winners = (unsigned int *) malloc ((sizeof(unsigned int))*number_elems);

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;
    tmp =a[idx[i]];				//The element itself will always be in the window

    if (mode ==2)
      winners[counter-1] = idx[i]+1;		//So add its index to winners...increment for yorick

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] < a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
        if (mode == 1)				//Add to a total if mode 1
          tmp += a[idx[j]];
        else if (mode == 2)			//Store its index, if mode 2
           winners[counter-1] = idx[j]+1;	//In yorick, indexing starts from 1
      }
      else
         break;					//Break since the array is sorted

    if (b[1] <= (float)counter)			//Refresh the return array b, if necessary
    {
       b[1] = (float)counter;
       fcounter = counter;			//Remember the counter value
      
       if (mode == 1 )
          b[0] = tmp/counter;			//Mode 1, requests a mean
       else if (mode == 2)
       {					//For mode 2, store the winners in an
	  fwinners = (unsigned int *) malloc ((sizeof(unsigned int))*fcounter);

	  memcpy ((void *)fwinners, (void *)winners, ((sizeof(unsigned int))*fcounter));
       }
       else					//Mode 0, request the actual base winner
           b[0] = a[idx[i]];

    }

    if (a[idx[number_elems-1]] < a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
  if (mode == 2)
     free (winners);				//Dont need winners anymore...they are in fwinners
  free (idx);					//idx array is also not needed now

  return fcounter;
}


/* Function to compare index values of the jury of LONG TYPE
 * , based on the contents of that indexed location. 
 * Used by qsort. Returns -1, 0 or 1
 */

int c_lcompfunc(const void *x, const void *y)
{
   unsigned int pp,qq;
   int t;

   pp = (unsigned int)(*(unsigned int *)x);
   qq = (unsigned int)(*(unsigned int *)y);

   if (lcopy[pp] < lcopy[qq]) t = -1;
   else
   if (lcopy[pp] == lcopy[qq]) t = 0;
   else  t = 1;
   return t;
}


/* Long version of the rcf algorithm.
 * Returns the number of winners
 */

unsigned int  c_lrcf (long* a, long w, int mode, float* b)
{
  #define MAX_MODE 2

  unsigned int i, j, number_elems, counter, *idx, q;
  long tmp;
  DataBlock *db;
 
  if ( (mode<0) || (mode> MAX_MODE) )		//Error checking for mode & window variables  
    YError("mode must be 0, 1 or 2");
  if (w<=0.0)
    YError("Window size must be positive");

  db = XGetInfo(sp-3);				//stack pointer-3 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;

  idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);	//Generate an index array of max size
  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  lcopy = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), c_lcompfunc);//Sort the copy

  if (mode == 2)				//Mode 2 needs to store the winners
     winners = (unsigned int *) malloc ((sizeof(unsigned int))*number_elems);

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;
    tmp =a[idx[i]];				//The element itself will always be in the window

    if (mode ==2)
      winners[counter-1] = idx[i]+1;		//So add its index to winners...increment for yorick

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] < a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
        if (mode == 1)				//Add to a total if mode 1
          tmp += a[idx[j]];
        else if (mode == 2)			//Store its index, if mode 2
           winners[counter-1] = idx[j]+1;	//In yorick, indexing starts from 1
      }
      else
         break;					//Break since the array is sorted

    if (b[1] <= (float)counter)			//Refresh the return array b, if necessary
    {
       b[1] = (float)counter;
       fcounter = counter;			//Remember the counter value
      
       if (mode == 1 )
          b[0] = (float)tmp/counter;			//Mode 1, requests a mean
       else if (mode == 2)
       {					//For mode 2, store the winners in an
	  fwinners = (unsigned int *) malloc ((sizeof(unsigned int))*fcounter);

	  memcpy ((void *)fwinners, (void *)winners, ((sizeof(unsigned int))*fcounter));
       }
       else					//Mode 0, request the actual base winner
           b[0] = (float)a[idx[i]];

    }

    if (a[idx[number_elems-1]] < a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
  if (mode == 2)
     free (winners);				//Dont need winners anymore...they are in fwinners
  free (idx);					//idx array is also not needed now

  return fcounter;
}
