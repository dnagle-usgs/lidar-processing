

/*

   $Id$

   Test Suite for rcf development in "C"

*/

   #include "oldrcf.i"
   t0 = t1  = array(double, 3);		// Timing array

/* FLOAT TESTS */

//Tests with a small array for each mode

   a = float([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);

   timer, t0;
   junk = frcf0(a, 6);
   timer, t1
   write,format="Float Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = frcf1(a, 6);
   timer, t1
   write,format="Float Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = frcf2(a, 6);
   timer, t1
   write,format="Float Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

   timer, t0;
   junk = frcf3(a, 6);
   timer, t1
   write,format="Float Mode 3: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

//Test for Null array
//   a = []
//   w = 1.0;
//   junk = frcf0(a,w);

// Test with  200k elements
   a = float(span(100000., -100000, 200000));
   a(8000:9000) = a(1000);
   w=20;

//Check for comparison between results of oldrcf and new frcf
//   timer, t0;
//   junk = oldrcf(a,w, mode=1);
//   timer, t1;
//   write,format="Oldrcf Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = frcf2(a,w);
   timer, t1;
   write,format="***Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for error conditions on w

//   w = -1.0;	//Negative window
//   junk = frcf1(a,w);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   w = 0.0;	//0 window
//   write,format="\n bad window  test: w=%f n=%d", w, numberof(a);
//   junk = frcf1(a,w);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2.0;	//Float window
//   timer,t0;
//  junk = frcf1(a,w);
//   timer,t1;
//   write,format="Float w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2;	//Int window
//   timer,t0;
//   junk = frcf1(a,int (w));
//   timer,t1;
//   write,format="Int w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for mode = 0
//   timer,t0;
//   junk = frcf0(a,w);
//   timer,t1;
//   write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode = 1
//   timer,t0;
//   junk = frcf1(a,w);
//   timer,t1;
//   write,format="Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2
//   w=1.0;
//   timer,t0;
//   junk = frcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test to find time of response  of oldrcf. Remember to #include "oldrcf.i"
//   timer,t0;
//   junk = oldrcf(a,w, mode=2);
//   timer,t1;
//   write,format="Mode 2 OLDRCF: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);


//   a(600:700) = a(200);

//Test for mode =2
//   w=2.0;
//   timer,t0;
//   junk = frcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   a(700:800) = a(500);

//Test for mode =2 with changed a
//   w=1.0;
//   timer,t0;
//   junk = frcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 with int window
//   w=2;
//   timer,t0;
//   junk = frcf2(a,w);
//   timer,t1;
//   write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for multiple calls
//   w=2;
//   for (i=0; i<1000; i++)
//   {
//     timer,t0;
//     junk = frcf2(a,w);
//     timer,t1;
//     write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);
//   }




/* LONG TESTS -- NOTE: Window must be long or int here*/

//Tests with a small array for each mode

   a = long([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
   a = long(span(49, 1, 49));
   a(40:49) = a(10);
   timer, t0;
   for (u=0; u<10000; u++)
   {
      junk = lrcf2(a, 6);
   }
   timer, t1
   write,format="10000 Long Mode 0: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   timer, t0;
   junk = lrcf1(a, 6);
   timer, t1
   write,format="Long Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = lrcf2(a, 6);
   timer, t1
  write,format="Long Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


   timer, t0;
   junk = lrcf3(a, 6);
   timer, t1
  write,format="Long Mode 3: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

//Test for Null array
//   a = []
//   w = 1.0;
//   junk = lrcf0(a,w);

// Test with  20k elements
//   a = long(span(10000, -10000, 20001));
//   a(800:900) = a(100);
//   w=2;

//Check for comparison between results of oldrcf and new lrcf

//   timer, t0;
//   junk = lrcf0(a,w);
//   timer, t1;
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   timer, t0;
//   junk = oldrcf(a,w, mode=0);
//   timer, t1;
//   write,format="Oldrcf Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for error conditions on w

//   w = -6;	//Negative window
//   junk = lrcf1(a,w);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   w = 0;	//0 window
//   write,format="\n bad window  test: w=%d n=%d", w, numberof(a);
//   junk = lrcf1(a,w);
//   write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2.0;	//Float window
//   timer,t0;
//   junk = lrcf0(a,w);
//   timer,t1;
//   write,format="Float w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2;	//Int window
//   timer,t0;
//   junk = lrcf1(a,int (w));
//   timer,t1;
//   write,format="Int w Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

// Test for mode = 0
//   timer,t0;
//   junk = lrcf0(a,w);
//   timer,t1;
//   write,format="Mode 0: Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode = 1
//   timer,t0;
//   junk = lrcf1(a,w);
//   timer,t1;
//   write,format="Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2
//   timer,t0;
//  junk = lrcf2(a,w);
//   timer,t1;
//   write,format="*Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//  a(600:700) = a(200);

//Test for mode =2
//   w=2.0;
//   timer,t0;
//   junk = lrcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//   a(700:800) = a(500);

//Test for mode =2 with changed a
//   w=1.0;
//   timer,t0;
//   junk = lrcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for mode =2 with int window
//   w=4;
//   timer,t0;
//   junk = lrcf2(a,w);
//   timer,t1;
//   write,format="Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);

//Test for multiple calls
//   w=2;
//   for (i=0; i<1; i++)
//   {
//     timer,t0;
//     junk = lrcf2(a,w);
//     timer,t1;
//     write,format="**Mode 2: Result= [%p,%p] time=%10.8f secs\n",junk(1), junk(2), t1(1)-t0(1);
//   }
//

/*DOUBLE TESTS*/

//Tests with a small array for each mode

   a = double([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
   timer, t0;
   junk = drcf0(a, 6);
   timer, t1
   write,format="Double Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = drcf1(a, 6);
   timer, t1
   write,format="Double Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = drcf2(a, 6);
   timer, t1
  write,format="Double Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


   timer, t0;
   junk = drcf3(a, 6);
   timer, t1
  write,format="Double Mode 3: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


/*INT TESTS*/


//Tests with a small array for each mode

   a = int([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
   timer, t0;
   junk = ircf0(a, 6);
   timer, t1
   write,format="Int Mode 0: Result= [%d,%d] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = ircf1(a, 6);
   timer, t1
   write,format="Int Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = ircf2(a, 6);
   timer, t1
  write,format="Int Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

   timer, t0;
   junk = ircf2(a, 6);
   timer, t1
  write,format="Int Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


   timer, t0;
   junk = ircf3(a, 6);
   timer, t1
  write,format="Int Mode 3: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

/* Mode 3 test for case where last 2 elements in SORTED jury are identical */

   a = float([ 100,101,100,99,60,98,99,101,150,103,30,88,99,110,101,150]);
   timer, t0;
   junk = frcf3(a, 6);
   timer, t1
  write,format="Mode 3(last 2 elems ==): Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);


/* Mode 3 test for array with all identical elements */

   b = [1,1,1,1,1,1];
   timer, t0;
   junk = lrcf3(b, 6);
   timer, t1
  write,format="Mode 3(all elements ==): Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

