/*
  You must download the triangle library from:
  https://www.cs.cmu.edu/~quake/triangle.com
  Then put triangle.c and triangle.h in this directory.
*/
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

/* MAKE-INSTRUCTIONS
SRCS = \
        triangle.c \
 	triangle.h
*/

/* If there are many SRCS, you can place a \ at the end of each line
   to continue the space delimited list to the next line.
   The LIB keyword is optional; if not present (you can put a # on that
     line to comment it out) you will not get a libyerf.a and this
     cerfc.i package cannot be included as an "old package" in future
     builds.
   The DEPLIBS and NO-WRAPPERS keywords are not needed here.
 */


func ytriangle(nsites1, points) {
/*DOCUMENT ytriangle(nsites1, points)
This function performs Delaunay Triangulation using the 'triangle' function
in C.  

Input: nsites1: Number of points to be triangulated.
       points: array containing the nodes to be triangulated

Output: An array containing the indices to the nodes that form the 3 vertices of a triangle.

amar nayegandhi 04/05/04
*/

  
  //write points out to a temp file in /tmp
  file = "/tmp/triangle.node";
  idx = long(span(1,nsites1, nsites1));
  f = open(file,"w");
  write, f, format="%d 2 %d 0\n",nsites1, numberof(points(,1))-2;
  write, f, format="%d %10.2f %10.2f %6.2f\n",idx, points(1,), points(2,), points(3,);
  close, f;
  a = int(2);
  fp = pointer(file);
  file1 = *fp(1);
  raw_triangle_main, a, file1;
  // now open the file created in /tmp dir to read
  f = open("/tmp/triangle.1.ele","r");
  ntri = nwd1 = nwd2 = 0;
  read, f, format="%d %d %d\n", ntri, nwd1, nwd2;
  idx1 = array(long, ntri);
  idx2 = array(long, ntri);
  idx3 = array(long, ntri);
  idx4 = array(long, ntri);
  read, f, format="%d %d %d %d\n",idx1, idx2, idx3, idx4;
  triidx = transpose([idx2, idx3, idx4]);
  close, f;
  f = popen("/bin/rm /tmp/triangle.node /tmp/triangle.1.node /tmp/triangle.1.ele", 0);
  close, f;
  return triidx;
}

extern raw_triangle_main;
/* PROTOTYPE
   void triangle_main(int argc, char array argv);
 */

/* The PROTOTYPE comment:
   (1) attaches the compiled function triangulate to the interpreted function
       voronoi
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
