/*

  $Id$

  Wrapper file for rcf

  Original rcf.i by C.W.Wright
  Converted to "C" by Conan Noronha
 
  Use   yorick -batch make.i rcf_yorick rcf.i   to build a Makefile for this package.

  Then use  make to build a custom version of yorick called "rcf_yorick".

The function frcf can be called from the interpreter.

*/

/* MAKE-INSTRUCTIONS
SRCS = rcf.c
*/



/* DOCUMENT frcf( jury, w, mode= )
Generic Random Consensus filter.  The jury is the
array to test for consensis, and w is the window range
which things can vary within.

jury       The array of points used to reach the consenus.

w          The window width.

Mode=
        0  Returns an array consisting of two elements
           where the first is the minimum value of the
           window and the second element is the number
           of votes.

        1  Returns the average of the winners.

        2  Returns a index list of the winners

        The following is a simple method to test the filter:

        For jury we will use the array a:
    a = float([100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150])
        And lets set the window size to 6: w = 6

        The default mode:
        frcf(a, w) and Enter
        The result printed on the screen will be the following:
        [98, 10] where 98 is the minimum value of the points in the window

        Mode 1
        frcf(a, w, mode= 1) and Enter
        The result printed on the screen will be:
        [100.1, 10] where 100.1 is the average value within the window
        and 10 is the number of points within that window range.

        Mode 2
        frcf(a, w, mode= 2) and Enter
        The result printed on the screen will be:
        10                      number of points within the window
        [1,2,3,4,5,6,7,8,9,10]   winners array
        10                       vote
        [0x81121bc,0x814d9bc]   location in memory of sorted list of winners
        and address of vote.


For a description on this method, see:

Random Sample Consensus - A paradigm for model-fitting with applications 
to image-analysis and automated cartography,

Fischler MA, Bolles RC, Communications of the ACM,
24 (6): 381-395 1981

FISCHLER MA, SRI INT,CTR ARTIFICIAL INTELLIGENCE,MENLO PK,CA 94025

Publisher:
ASSOC COMPUTING MACHINERY, NEW YORK

*/

/*FLOAT*/

func frcf0(jury, w)
{ 
  b = float(array(0,2));	//Return array for mode 0

  y_frcf0, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func frcf1(jury, w)
{ 
  b = float(array(0,2));	//Return array for mode 1

  y_frcf1, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func frcf2(jury, w)
{ 

  fcount = y_frcf2(jury, w);	//Call the yorick version of the "C" rcf function

  c = int(array(0,fcount));
  y_fillarray, c;		//Fill it

  return [&c, &fcount]		//And return the start address & address of winner count
}

extern y_frcf0;
/* PROTOTYPE
void rcf_float_0 (float array a, float w, float array b)
*/

extern y_frcf1;
/* PROTOTYPE
void rcf_float_1 (float array a, float w, float array b)
*/

extern y_frcf2;
/* PROTOTYPE
int rcf_float_2 (float array a, float w)
*/


/*DOUBLE*/

func drcf0(jury, w)
{ 
  b = double(array(0,2));	//Return array for mode 0 

  y_drcf0, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func drcf1(jury, w)
{ 
  b = float(array(0,2));	//Return array for mode  1

  y_drcf1, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func drcf2(jury, w)
{ 

  fcount = y_drcf2(jury, w);	//Call the yorick version of the "C" rcf function

  c = int(array(0,fcount));
  y_fillarray, c;		//Fill it

  return [&c, &fcount]		//And return the start address & address of winner count
}

extern y_drcf0;
/* PROTOTYPE
void rcf_double_0 (double array a, double w, double array b)
*/

extern y_drcf1;
/* PROTOTYPE
void rcf_double_1 (double array a, double w, float array b)
*/

extern y_drcf2;
/* PROTOTYPE
int rcf_double_2 (double array a, double w)
*/

/*LONG*/

func lrcf0(jury, w)
{ 
  b = long(array(0,2));		//Return array for mode 0 

  y_lrcf0, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func lrcf1(jury, w)
{ 
  b = float(array(0,2));	//Return array for mode  1

  y_lrcf1, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func lrcf2(jury, w)
{ 

  fcount = y_lrcf2(jury, w);	//Call the yorick version of the "C" rcf function

  c = int(array(0,fcount));
  y_fillarray, c;		//Fill it

  return [&c, &fcount]		//And return the start address & address of winner count
}

extern y_lrcf0;
/* PROTOTYPE
void rcf_long_0 (long array a, long w, long array b)
*/

extern y_lrcf1;
/* PROTOTYPE
void rcf_long_1 (long array a, long w, float array b)
*/

extern y_lrcf2;
/* PROTOTYPE
int rcf_long_2 (long array a, long w)
*/

/*INT*/

func ircf0(jury, w)
{ 
  b = int(array(0,2));		//Return array for mode 0 

  y_ircf0, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func ircf1(jury, w)
{ 
  b = float(array(0,2));	//Return array for mode  1

  y_ircf1, jury, w, b;		//Call the yorick version of the "C" rcf function

  return b;
}

func ircf2(jury, w)
{ 

  fcount = y_ircf2(jury, w);	//Call the yorick version of the "C" rcf function

  c = int(array(0,fcount));
  y_fillarray, c;		//Fill it

  return [&c, &fcount]		//And return the start address & address of winner count
}

extern y_ircf0;
/* PROTOTYPE
void rcf_int_0 (int array a, int w, int array b)
*/

extern y_ircf1;
/* PROTOTYPE
void rcf_int_1 (int array a, int w, float array b)
*/

extern y_ircf2;
/* PROTOTYPE
int rcf_int_2 (int array a, int w)
*/

extern y_fillarray;
/* PROTOTYPE
void c_fillarray (int array c)
*/

/* The PROTOTYPE comment:

   (1) attaches the compiled function c_rcf to the interpreted 
       function y_rcf
   (2) note that the word "array" replaces the symbol "*" in the
       corresponding ANSI C prototype
       complicated data types should use the interpreted data type
       "pointer" and pass their arguments as "&arg".
 */

