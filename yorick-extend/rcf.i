/*


  $Id$

  This stuff will get hacked into some EAARL specfic "C" functions.  For now
  it serves as a starting place.
  
  rcf.i

  Simple example of a C compiled function callable from Yorick.

     yorick -batch make.i yerf rcf.i

  builds a Makefile for this package.

     yorick -batch make.i

  checks the existing Makefile to be sure it has the correct MAKE_TEMPLATE
  for this platform -- you can do this when you move this package from one
  platform to another to avoid reconstructing the Makefile.

     make

  builds a custom version of yorick called "yerf".  The function cerfc
  can be called from the interpreter.  You can compare the speed of this
  compiled function with the interpreted version of erfc in gamma.i.

  Try including make.i and typing "help, make" for more information.
 */

/* MAKE-INSTRUCTIONS
SRCS = rcf.c
LIB = yerf
*/

/* If there are many SRCS, you can place a \ at the end of each line
   to continue the space delimited list to the next line.
   The LIB keyword is optional; if not present (you can put a # on that
     line to comment it out) you will not get a libyerf.a and this
     cerfc.i package cannot be included as an "old package" in future
     builds.
   The DEPLIBS and NO-WRAPPERS keywords are not needed here.
 */

func cerfc(x)
/* DOCUMENT cerfc(x)
     returns the complementary error function 1-erf with fractional
     error less than 1.2e-7 everywhere.
   SEE ALSO: erfc (in gamma.i)
 */
{
  /* A simple interpreted wrapper can generate additional arguments
     necessary for the compiled function.
     In this case, the result of the calculation is an array, which
     is an input parameter to the compiled function.
     The length and dimensions of the result array are the same as the
     input x array.
   */
  y= array(double, dimsof(x));
  raw_cerfc, y, x, numberof(x);
  return y;
}

extern raw_cerfc;
/* PROTOTYPE
   void cerfc(double array y, double array x, long n)
 */

/* The PROTOTYPE comment:
   (1) attaches the compiled function cerfc to the interpreted function
       raw_cerfc
   (2) generates wrapper code for cerfc that converts the data types
       to those shown in the comment -- for output variables such as
       y in this case, it is the responsibility of the interpreted caller
       (func cerf above) to ensure that no conversion is necessary
       (otherwise the result will go to a temporary array and be discarded)
   (3) note that the word "array" replaces the symbol "*" in the
       corresponding ANSI C prototype
       complicated data types should use the interpreted data type
       "pointer" and pass their arguments as "&arg".
 */
