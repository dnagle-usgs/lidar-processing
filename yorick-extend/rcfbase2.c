/*
 * $Id$
 *
 * This file contains the base code to implement the rcf algorithm
 * It is used by the mkrcf.sh script, to generate 4 versiions of 
 * the code below. ie one version each for float, double, long and 
 * int type data.
 *
 * Original rcf.i by C.W.Wright
 * Converted to "C" by Conan Noronha
 *
 */

static TYPE  * COPY;		//Global pointer to the jury

/* Function to compare index values of the jury, based on the contents of
 * that indexed location. 
 * Used by qsort for float jury. Returns -1, 0 or 1
 */

int CNAME (const void *x, const void *y)
{
   unsigned int pp,qq;
   int t;

   pp = (unsigned int)(*(unsigned int *)x);
   qq = (unsigned int)(*(unsigned int *)y);

   if (COPY[pp] < COPY[qq]) t = -1;
   else
   if (COPY[pp] == COPY[qq]) t = 0;
   else  t = 1;
   return t;
}


/* rcf algorithm for mode0.
 * Returns array b
 */

void FNAME0 (TYPE* a, TYPE w, TYPE* b)
{

  unsigned int i, j, number_elems, counter, *idx;
  DataBlock *db;
 
  if (w<=(TYPE)0)
    YError("Window size must be positive");

  db = XGetInfo(sp-2);				//stack pointer-3 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;

  if (number_elems <= TBUFSIZE)
	  flag = 0;
  else
	  flag =1;

  if (!flag)					//Use arrays if number_elems is less than array size
  {
	idx = tidx;
  }
  else
  { 
  	idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);
  }

  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  COPY = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), CNAME);//Sort the copy

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] < a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
      }
      else
         break;					//Break since the array is sorted

    if (b[1] <= (TYPE)counter)			//Refresh the return array b, if necessary
    {
       b[1] = (TYPE)counter;
      
       b[0] = a[idx[i]];
    }

    if (a[idx[number_elems-1]] < a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
  if (flag)
     free (idx);					//idx array is also not needed now
}

/* rcf algorithm for mode 1.
 * Returns array b
 */

void FNAME1  (TYPE *a, TYPE w, float *b)
{

  unsigned int i, j, number_elems, counter, *idx;
  TYPE tmp;
  DataBlock *db;
 
  if (w<=(TYPE)0)
    YError("Window size must be positive");

  db = XGetInfo(sp-2);				//stack pointer-3 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;

  if (number_elems <= TBUFSIZE)
	  flag = 0;
  else
	  flag =1;

  if (!flag)					//Use arrays if number_elems is less than array size
  {
	idx = tidx;
  }
  else
  { 
  	idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);
  }

  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  COPY = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), CNAME);//Sort the copy

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;
    tmp =a[idx[i]];				//The element itself will always be in the window

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] < a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
        tmp += a[idx[j]];
      }
      else
         break;					//Break since the array is sorted

    if (b[1] <= (float)counter)			//Refresh the return array b, if necessary
    {
       b[1] = (float)counter;
      
       b[0] = tmp/(float)counter;			//Mode 1, requests a mean
    }

    if (a[idx[number_elems-1]] < a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
  if (flag)
      free (idx);					//idx array is also not needed now

}

/* rcf algorithm for mode 2.
 * Returns the number of winners
 */

unsigned int  FNAME2 (TYPE* a, TYPE w)
{
  unsigned int i, j, number_elems, counter, *idx;
  DataBlock *db;
 
  if (w<=(TYPE)0)
    YError("Window size must be positive");

  db = XGetInfo(sp-1);				//stack pointer-3 is the source array 
  if (!db) 
     number_elems= (unsigned int)type.number;	//Get the number of elements in the source array
  else
     number_elems= 0;
 
  if (number_elems <= TBUFSIZE)
	  flag = 0;
  else
	  flag =1;

  if (!flag)					//Use arrays if number_elems is less than array size
  {
	idx = tidx;
	winners = twinners;
	fwinners = tfwinners;
  }
  else
  {
  	idx = (unsigned int*)malloc((sizeof(unsigned int))*number_elems);
        winners = (unsigned int *) malloc ((sizeof(unsigned int))*number_elems);
        fwinners = (unsigned int *) malloc ((sizeof(unsigned int))*number_elems);
  }

  for (i=0; i<number_elems; i++)
	  idx[i]=i;
  
  COPY = a;					//Make the jury gloabally accessible

  qsort(idx, number_elems, sizeof(unsigned int), CNAME);//Sort the copy

  fcounter = 0;

  for (i=0; i<number_elems-1; i++)		//For each element in the copy
  {
    counter=1;

    winners[counter-1] = idx[i]+1;		//So add its index to winners...increment for yorick

    for (j=i+1; j< number_elems;j++)		//For each subsequent element
      if (a[idx[j]] < a[idx[i]]+w)		//If it lies in the window
      {
        counter++;				//Count it
        winners[counter-1] = idx[j]+1;	//In yorick, indexing starts from 1
      }
      else
         break;					//Break since the array is sorted

    if (fcounter <= counter)			//Refresh the return array b, if necessary
    {
       fcounter = counter;			//Remember the counter value
      
       						//For mode 2, store the winners 
       memcpy ((void *)fwinners, (void *)winners, ((sizeof(unsigned int))*fcounter));
    }

    if (a[idx[number_elems-1]] < a[idx[i]]+w)	//Break the whole process when the last element in 
      break;					//the sorted copy falls in a window of some element
  }
 
  if (flag)
  {
	  free (winners);				//Dont need winners anymore...they are in fwinners
          free (idx);					//idx array is also not needed now
  }
  return fcounter;
}

