/*
   $Id$
*/

require, "edb_access.i"
require, "eaarl_constants.i"

#include "centroid-1.i"
load_edb


start = 38780
stop  = 47000
nrast = stop - start + 1;

range = array( float, 6, nrast); 
n = 50;

window,0
limits,0,60,0,512

incr = 1

func sh( i ) {
  window,0
  ctx = cent( *z.tx(n) ) ;


/*
   Begin with the most sensitive channel, and check the number of
   off-scale values in the surface return region. If more than 2 
   samples are off-scale, then bother computing a centroid with this
   waveform, and move to the next waveform and repeat the process
   until we find on which is either not saturated, or we're out of
   waveforms.  Once a suitable waveform is found, compute the centroid
   and then adjust the computed centroid for differential cable 
   delay, and also add an offset to the detected power so we can tell
   which waveform was used in the computations.
*/
  if ( numberof(where(  ((*z.rx(n,1))(1:12)) == 0 )) <= 2 ) {
     cv = cent( *z.rx(n, 1 ) );
  } else if ( numberof(where(  ((*z.rx(n,2))(1:12)) == 0 )) <= 2 ) {
     cv = cent( *z.rx(n, 2 ) ) + 0.36;
     cv(3) += 300;
  } else {
     cv = cent( *z.rx(n, 3 ) ) + 0.23;
     cv(3) += 600;
  }

// Now compute the actual range value in NS
  range(1,j) = float(z.irange(n)) - ctx(1) + cv(1);
  range(2, j) = cv(3);
  range(4, j) = i;

  write,format="%5d %5d %6.3f %4.0f\n", 
    i, z.irange(n), range(1,j), range(2,j);
  plg, *z.rx(n,1); 
  plmk, *z.rx(n,1), msize=.2; 
  plg, *z.rx(n,2),color="red"; 
  plg, *z.rx(n,3),color="blue"; 
  plg, -*z.tx(n)+255; 
}



animate,1
for ( j=1, i = 38780; i<47000; i += incr ) { 
  r = get_erast(rn=i); 
  z=decode_raster(r); 
  fma; 
 mdv = abs((-*z.tx(n))(dif)) (max); 
 if ( ( z.irange(n) > 0 ) && ( z.irange(n) < 16384 ) && (mdv < 160 ) ) {
  sh,i;
  j++;
 }
}
animate,0
