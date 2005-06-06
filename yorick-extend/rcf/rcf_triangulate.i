/*

  Simple example of a C compiled function callable from Yorick.

     yorick -batch make.i ytri triangulate.i

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

if(!is_void(plug_in)) plug_in, "rcf";
/* MAKE-INSTRUCTIONS
SRCS = triangulate.c
*/

/* If there are many SRCS, you can place a \ at the end of each line
   to continue the space delimited list to the next line.
   The LIB keyword is optional; if not present (you can put a # on that
     line to comment it out) you will not get a libyerf.a and this
     cerfc.i package cannot be included as an "old package" in future
     builds.
   The DEPLIBS and NO-WRAPPERS keywords are not needed here.
 */


func triangulate(nv, pxyz) {
  v = array(long, 3, (numberof(pxyz)-9));
  ntri = long(0);
  raw_Triangulate, nv, pxyz, v, ntri;
  return v; 
}

extern raw_Triangulate;
/* PROTOTYPE
   void Triangulate(long nv, double array pxyz, long array v, long ntri)
 */

/* The PROTOTYPE comment:
   (1) attaches the compiled function triangulate to the interpreted function
       y_triangulate
   (2) generates wrapper code for triangulate that converts the data types
       to those shown in the comment -- for output variables such as
       y in this case, it is the responsibility of the interpreted caller
       (func cerf above) to ensure that no conversion is necessary
       (otherwise the result will go to a temporary array and be discarded)
   (3) note that the word "array" replaces the symbol "*" in the
       corresponding ANSI C prototype
       complicated data types should use the interpreted data type
       "pointer" and pass their arguments as "&arg".
 */
