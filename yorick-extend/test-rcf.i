

/*

   $Id$

*/


   t0 = t1  = array(double, 3);		// timing array

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
   
   w = 2.0;
write,format="\nFloating point test: w=%f n=%d", w, numberof(a);

    timer,t0;
   junk = rcf(a,w, mode=1);
    timer,t1;
write,format="Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);
   
    timer,t0;
   junk = rcf(a,w);
    timer,t1;

write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//    timer,t0;
//   junk = rcf(a,w, mode=-1);
//    timer,t1;

//write,format="Mode 0: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);

//    timer,t0;
//   junk = rcf(a,w, mode=5);
//    timer,t1;

//write,format="Mode 5: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);


    timer,t0;
   junk = rcf(a,int(2), mode=1);
    timer,t1;

write,format="Int w: Result= [%f,%f] time=%6.4f secs\n",junk(1), junk(2), t1(1)-t0(1);


