/*

  $Id$

  Wrapper file for rcf
 
  Use

     yorick -batch make.i rcf_yorick rcf.i

  to build a Makefile for this package.

     yorick -batch make.i

  checks the existing Makefile to be sure it has the correct MAKE_TEMPLATE
  for this platform -- you can do this when you move this package from one
  platform to another to avoid reconstructing the Makefile.

     make

  builds a custom version of yorick called "rcf_yorick".  The function 
  rcf can be called from the interpreter.

  Try including make.i and typing "help, make" for more information.
*/

/* MAKE-INSTRUCTIONS
SRCS = rcf.c
*/


func rcf(jury, w, mode=)
/* DOCUMENT rcf( jury, w, mode= )
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
        rcf(a, w) and Enter
        The result printed on the screen will be the following:
        [98, 10] where 98 is the minimum value of the points in the window

        Mode 1
        rcf(a, w, mode= 1) and Enter
        The result printed on the screen will be:
        [100.1, 10] where 100.1 is the average value within the window
        and 10 is the number of points within that window range.

        Mode 2
        rcf(a, w, mode= 2) and Enter
        The result printed on the screen will be:
        10                      number of points within the window
        [1,2,3,4,5,6,7,8,9,10]   kwinners array
        4                     vote
        [0x81121bc,0x814d9bc]   location in memory of sorted list of kwinners
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

{ 
  b = float(array(0,2));	//Return array
  if ( is_void(mode) )		//Ensure a mode value
        mode = 0;

  fcount = y_rcf(jury, w, mode, b);	//Call the yorick version of the "C" rcf functions

 if (mode== 2)
 {
   c = int(array(0,fcount));

   y_fillarray, c;

   return [&c, &fcount]
 }
 return b;
}

extern y_rcf;
/* PROTOTYPE
int c_rcf (float array a, float w, int mode, float array b)
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
