
require, "eaarl_constants.i"

/*
   $Id$

  Orginal W. Wright

  9/20/02 Added pcr function.
*/




func pcr(rast, n) {
/* DOCUMENT pcr(rast,n)

  This function computes the centroid of the transmit and return pulses
 and then computes a range value corrected for signal level range walk.  It
 returns a 4 element array consisting of: 
 1) the controid corrected range,
 2) the peak return power in digital counts, 
 3) the cooresponding irange value,  
 4) the number of pixels saturated in the transmit waveform.  

 This function determines which return waveform is not saturated or off-scale,
and then calls the "cent" function to compute the actual pulse centroid.

 **Important** The centroid calculations do not include corrections for 
range_bias.

 Inputs: 
   rast	A raster array of type RAST.
   n	The pixel within the raster to apply centroid corrections to.

 Returns:
   array(float,4) where:
     1	Centroid corrected irange value
     2  Return peak power.
     3  Uncorrected irange value.
     4  Number of transmit pulse digitizer bins which are offscale.

 Element 2, return power, contains values ranging from 0 to 900 digital 
counts. The values are contained in three discrete ranges and each range
cooresponds to a return channel.  Values from 0-255 are from channel 1,
from 300-555 are from channel 2, and from 600-855 are from channel 3. 
Channel 1 is the most sensitive and channel 3 the least.


See also: RAST, cent  
*/


 rv = array(float,4);			// return values
  np = numberof ( *rast.rx(n,1) );      // find out how many waveform points
                                        // are in the primary (most sensitive)
                                        // receiver channel.

  if ( np < 2 )                         // give up if there are not at
     return;                            // least two points.

  if ( np > 12 ) np = 12;               // use no more than 12

  if ( numberof( *rast.tx(n) ) > 0 )
	rv(4) = (*rast.tx(n) == 0 )(sum);
  ctx = cent( *rast.tx(n) ) ;              // compute transmit centroid


/**********************************************************************
 Now examine all three receiver waveforms for saturation, and use the
 one thats next to the channel thats offscale. 
 First check the most sensitive channel (1), and if it's offscale,
 then check (2), and then (3).  A channel is considered offscale if
 more than 2 pixels are equal to zero.  Signals are inverted, which
 means the base line is around 240 counts and signal strength goes 
 toward zero.  An offscale pixel value would equal zero. 

**********************************************************************/
  if ( numberof(where(  ((*rast.rx(n,1))(1:np)) == 0 )) <= 2 ) {
     cv = cent( *rast.rx(n, 1 ) );
     if ( cv(3) < -90 ) {	   // Must be water column only return.  
        slope = 0.029625
        x = cv(3)  - 90;
        y = slope * x;
        cv(1) += y;
     }
  } else if ( numberof(where(  ((*rast.rx(n,2))(1:np)) == 0 )) <= 2 ) {
     cv = cent( *rast.rx(n, 2 ) ) + 0.36;
     cv(3) += 300;
  } else {
     cv = cent( *rast.rx(n, 3 ) ) + 0.23;
     cv(3) += 600;
  }

// Now compute the actual range value in NS
  rv(1) = float(rast.irange(n)) - ctx(1) + cv(1);
  rv(2) = cv(3);
  rv(3) = rast.irange(n);
 return rv;
}




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
//////     write,"********* centroid-1.i  cent()  Reject: Sum was zero"
  }

//      centroid peak     average
//        range  range    power
//  return [ c, mx, (a(r)(avg)) ];
  return [ c, mx, mv ];
}





func let(rast, n) {
/* DOCUMENT pcr(rast,n)

  This function computes the centroid of the transmit and return pulses
 and then computes a range value corrected for signal level range walk.  It
 returns a 4 element array consisting of: 
 1) the controid corrected range,
 2) the peak return power in digital counts, 
 3) the cooresponding irange value,  
 4) the number of pixels saturated in the transmit waveform.  

 This function determines which return waveform is not saturated or off-scale,
and then calls the "cent" function to compute the actual pulse centroid.

 **Important** The centroid calculations do not include corrections for 
range_bias.

 Inputs: 
   rast	A raster array of type RAST.
   n	The pixel within the raster to apply centroid corrections to.

 Returns:
   array(float,4) where:
     1	Centroid corrected irange value
     2  Return peak power.
     3  Uncorrected irange value.
     4  Number of transmit pulse digitizer bins which are offscale.

 Element 2, return power, contains values ranging from 0 to 900 digital 
counts. The values are contained in three discrete ranges and each range
cooresponds to a return channel.  Values from 0-255 are from channel 1,
from 300-555 are from channel 2, and from 600-855 are from channel 3. 
Channel 1 is the most sensitive and channel 3 the least.


See also: RAST, cent  
*/


 rv = array(float,4);			// return values
  np = numberof ( *rast.rx(n,1) );      // find out how many waveform points
                                        // are in the primary (most sensitive)
                                        // receiver channel.

  if ( np < 2 )                         // give up if there are not at
     return;                            // least two points.

  if ( np > 12 ) np = 12;               // use no more than 12

  if ( numberof( *rast.tx(n) ) > 0 )
	rv(4) = (*rast.tx(n) == 0 )(sum);
  ctx = cent( *rast.tx(n) ) ;              // compute transmit centroid


     cv = [ 0.0, 0.0, 0.0 ];
     a = -float(*rast.rx(n,1));
     if ( numberof ( a ) >= 8 ) {
       bias = a(1:5)(avg);
       a  -= bias;
       cv(1) = 0.0;
//       cv(3) = ((1000.0*(a(7)*7 + a(8)*8 ))  / float(a(7) + a(8) ) ) - 6500.0;
//       cv(1) = cv(3) / 140.0  +  -0.0;
         cv(3) = a(7) + a(8);
     }


// Now compute the actual range value in NS
  rv(1) = float(rast.irange(n)) - ctx(1) + cv(1)   ;
  rv(2) = cv(3);
  rv(3) = rast.irange(n);
 return rv;
}
