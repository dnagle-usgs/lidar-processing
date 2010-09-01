/******************************************************************************\
* This file was moved to the attic on 2010-09-01. It has not been used for     *
* years and appears to be a precursor to the functionality in bathy.i and      *
* geo_bath.i.                                                                  *
\******************************************************************************/

func find_bottom( r ) {
 extern tay;
 bathpeakposition = array(int,120);
 a = array(float, 256, 120, 4);	// 4 waveforms, 120 pixels, and 256ns/pixel/waveform
 rp = decode_raster( r ); 

 for (i=1; i<rp.npixels(1); i++ ) {

// Remove bias and convert to a constat width floating array
    n = numberof(*rp.rx(i, 1));
    w = *rp.rx(i, 1);  a(1:n, i) = float( (~w+1) - (~w(1)+1) );
    da = a(,i,1) - tay;
    x_max_pos = da(mxx);
    x_max_value = da(x_max_pos);
   if ( x_max_value > 0.0 ) {
      bathpeakposition(i) = x_max_pos;
   } else {
      bathpeakposition(i) = 0; 
   }
 }
 return bathpeakposition;
}
