

/*

   $Id$

*/


   t0 = t1  = array(double, 3);		// timing array

   a = float([ 100,101,100,99,60,98,99,101,105,103,30,88,99,110,101,150]);
   
   timer, t0;
   junk = rcf(a, 6);
   timer, t1
   write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = rcf(a, 6, mode=1);
   timer, t1
   write,format="Mode 1: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   timer, t0;
   junk = rcf(a, 6, mode=2);
   timer, t1
   write,format="Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2),t1(1)-t0(1);

//  a = []
//  w = 1.0;
//  junk = rcf(a,w);


   a = float(span(100., -100, 20000));	// generate 20k elements
   a(800:900) = a(100);

// Test error conditions on w
// w = -1.0;
//write,format="\n bad window  test: w=%f n=%d", w, numberof(a);
//   junk = rcf(a,w,mode=1);
//write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
// w = 0.0;
//write,format="\n bad window  test: w=%f n=%d", w, numberof(a);
//   junk = rcf(a,w,mode=1);
//write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//   w = 2.0;
//write,format="\nFloating point test: w=%f n=%d", w, numberof(a);

//    timer,t0;
//   junk = rcf(a,w, mode=1);
//    timer,t1;
//write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
//    timer,t0;
//   junk = rcf(a,w);
//    timer,t1;

//write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//    timer,t0;
//   junk = rcf(a,w, mode=-1);
//    timer,t1;

//write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//    timer,t0;
//   junk = rcf(a,w, mode=5);
//    timer,t1;

//write,format="Mode 5: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);


//    timer,t0;
//   junk = rcf(a,int(2), mode=1);
//    timer,t1;

//write,format="Int w: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

   w=2.0;
   timer,t0;
   junk = rcf(a,w, mode=2);
    timer,t1;

write,format="Mode 2: Result= [%p,%p] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
