
require, "eaarl_constants.i"

/*
   $Id$
*/



// Compute waveform centroid
func cent( a ) {
/* DOCUMENT cent(a)
  
   Compute the centroid of "a" using the no more than the
 first 12 points.  This function considers the entire pulse
 and is probably only good for solid first-return targets or
 bottom pulses.  

*/
  n = numberof(a);	// determine number of points in waveform
  if ( n < 2 ) 
	return [ 0,0,0];
  if ( n > 12 ) n = 12; // if more than 12, only use the first 12
  r = 1:n;		// set the range we will consider 
   a = -short(a);	// flip it over and convert to signed short
   a -= a(1);		// remove bias using first point of wf
  mv = a (max);		// find the maximum value
  mx = a (mxx);		// find the index of the maximum
  s =  a(r)(sum);	// compute the sum of all the samples
  if ( s != 0.0 ) {
    c = float(  (a(r) * indgen(r)) (sum) ) / s;
  } else {
    c = 10000.0;
    write,"********* centroid-1.i  cent()  Reject"
  }

//      centriod peak     average
//        range  range    power
//  return [ c, mx, (a(r)(avg)) ];
  return [ c, mx, mv ];
}


