

/*

   $Id$

   Test Suite for rcf development in "C"

*/

   #include "oldrcf.i"
   t0 = t1  = array(double, 3);		// Timing array

/* FLOAT TESTS */

//Tests with a small array for each mode

//   a = float([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
//   timer, t0;
//   junk = frcf(a, 6);
//   timer, t1
//   write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = frcf(a, 6, mode=1);
//   timer, t1
//   write,format="Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = frcf(a, 6, mode=2);
//   timer, t1
//   write,format="Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

//Test for Null array
//   a = []
//   w = 1.0;
//   junk = rcf(a,w);

// Test with  20k elements
//   a = float(span(10000., -10000, 20000));
//   a(800:900) = a(100);
//   w=2;

//Check for comparison between results of oldrcf and new frcf
//   timer, t0;
//   junk = oldrcf(a,w, mode=1);
//   timer, t1;
//   write,format="Oldrcf Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = frcf(a,w,mode=1);
//   timer, t1;
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for error conditions on w

//   w = -1.0;	//Negative window
//   junk = frcf(a,w,mode=1);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   w = 0.0;	//0 window
//   write,format="\n bad window  test: w=%f n=%d", w, numberof(a);
//   junk = frcf(a,w,mode=1);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2.0;	//Float window
//   timer,t0;
//  junk = f`rcf(a,w, mode=1);
//   timer,t1;
//   write,format="Float w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2;	//Int window
//   timer,t0;
//   junk = frcf(a,int (w), mode=1);
//   timer,t1;
//   write,format="Int w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer,t0;	//Invalid mode
//   junk = frcf(a,w, mode=5);
//   timer,t1;
//   write,format="Mode 5: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for mode = 0
//   timer,t0;
//   junk = frcf(a,w);
//   timer,t1;
//   write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode = 1
//   timer,t0;
//   junk = frcf(a,w, mode=-1);
//   timer,t1;
//   write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2
//   w=1.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test to find time of response  of oldrcf. Remember to #include "oldrcf.i"
//   timer,t0;
//   junk = oldrcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);


//   a(600:700) = a(200);

//Test for mode =2
//   w=2.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   a(700:800) = a(500);

//Test for mode =2 with changed a
//   w=1.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 multiple calls
//   w=3.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 with int window
//   w=2;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for multiple calls
//   w=2;
//   for (i=0; i<1000; i++)
//   {
//     timer,t0;
//     junk = frcf(a,w, mode=2);
//     timer,t1;
//     write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);
//   }




/* LONG TESTS -- NOTE: Window must be long or int here*/

//Tests with a small array for each mode

//   a = ([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
//   timer, t0;
//   junk = lrcf(a, 6);
//   timer, t1
//   write,format="Mode 0: Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = lrcf(a, 6, mode=1);
//   timer, t1
//   write,format="Mode 1: Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = lrcf(a, 6, mode=2);
//   timer, t1
//  write,format="Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


//Test for Null array
//   a = []
//   w = 1.0;
//   junk = lrcf(a,w);

// Test with  20k elements
   a = long(span(10000, -10000, 20001));
   a(800:900) = a(100);
   w=2;

//Check for comparison between results of oldrcf and new lrcf

//   timer, t0;
//   junk = lrcf(a,w,mode=0);
//   timer, t1;
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = oldrcf(a,w, mode=0);
//   timer, t1;
//   write,format="Oldrcf Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for error conditions on w

//   w = -6;	//Negative window
//   junk = lrcf(a,w,mode=1);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   w = 0;	//0 window
//   write,format="\n bad window  test: w=%d n=%d", w, numberof(a);
//   junk = lrcf(a,w,mode=1);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2.0;	//Float window
//   timer,t0;
//   junk = lrcf(a,w);
//   timer,t1;
//   write,format="Float w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2;	//Int window
//   timer,t0;
//   junk = lrcf(a,int (w), mode=1);
//   timer,t1;
//   write,format="Int w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer,t0;	//Invalid mode
//   junk = lrcf(a,w, mode=5);
//   timer,t1;
//   write,format="Mode 5: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for mode = 0
//   timer,t0;
//   junk = lrcf(a,w);
//   timer,t1;
//   write,format="Mode 0: Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
//Test for mode = 1
//   timer,t0;
//   junk = lrcf(a,w, mode=1);
//   timer,t1;
//   write,format="Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2
//   timer,t0;
//  junk = lrcf(a,w, mode=2);
//   timer,t1;
//   write,format="*Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//  a(600:700) = a(200);

//Test for mode =2
//   w=2.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   a(700:800) = a(500);

//Test for mode =2 with changed a
//   w=1.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 multiple calls
//   w=3.0;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 with int window
//   w=4;
//   timer,t0;
//   junk = frcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for multiple calls
   w=2;
   for (i=0; i<1; i++)
   {
     timer,t0;
     junk = lrcf(a,w, mode=2);
     timer,t1;
     write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);
   }

