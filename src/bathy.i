require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "sel_file.i"
require, "eaarl_constants.i"



func gen_thresh( k, yscale, xoffsetns, yoffset, nblank ) {
/* DOCUMENT gen_thresh(k, yscale, xoffsetns, yoffset )
   
   nblank	Number of samples to blank out after xoffsetns
   Returns an array of threshold values. 
*/
 tay = yscale*(1.0 / ( exp(1)^(k*2.0*attdepth))) + yoffset; 	// generate the array
 tay(xoffsetns+1:0) = tay(1:-xoffsetns);
 tay(1:xoffsetns+nblank) = 255.0;
 return tay;
}


/*
tay = gen_laser_tail( 2.2,.38, 256 *9, .032, 9, 16 );
 rn     idx     nsat    scale   ch2 max         Comment
89015, 21       10      9.0     226
89015, 35        9      7.0     197
*/


func gen_laser_tail( e1, e2, yscale, ys2, xoffsetns, xoffu ) {
/* DOCUMENT gen_laser_impulse( e1, e2, yscale, xoffsetns )

   Generate the exponential tail of the laser for saturated signals.
*/

 t = yscale*(1.0 / ( exp(1)^(e1*2.0*attdepth))) ;  
 t(xoffsetns+1:0) = t(1:-xoffsetns);
 t(1:xoffsetns) = 255.0;

 u = yscale * ys2 *(1.0 / ( exp(1)^(e2*2.0*attdepth))) ;  
 u(xoffu+1:0) = u(1:-xoffu);
 u(1:xoffu) = u(1);
 graph = 0;
if ( graph ) {
window,4
 plg,t,marks=0,color="red",width=2.0,type=2
 plg,u,marks=0,color="magenta",width=5.0,type=2
}
 tay = t + u;
 return tay;
}

func gen_equalize( et )  {
/* DOCUMENT
  100*(50 - exp( -attdepth * .1)*50)/ 50.0
*/
extern equalize
  equalize = (50 - exp( -attdepth * et )*50)/ 50.0;
  return equalize;
}
 

/*

  all from 7/14/01
  rn = 89015
These done with gen_thresh  
  k = 1.3
  xoffsetns 9
  yoffset 0 
 chn sat yscale  ch2
  89 2 0.5  15
  65 2 0.75 16
  38 2 0.9  17
  33 3 0.9  32
  28 3 0.9  24
  24 3 0.9  15
  61 3 0.75 10
 106 3 0.8  31
  81 3 1.3  29
  76 3 0.9  17
  64 4 1.2  34
  57 4 1.2  33
  46 4 1.05  31
  30 4 1.0  31
  11 4 1.05 27
  25 4 1.05 22
 110 5 1.5  41
  36 5 1.3  41
  74 5 1.3  41
  60 5 1.3  41 
  54 5 1.3  27
  48 5 1.5  35
  47 5 1.65 57 
  19 5 1.3  35
   2 6 1.7  40
  15 6 1.3  45
  98 6 1.7  70
  43 6 1.7  58
  27 6 2.0  53
  51 6 1.7  40
  59 6 1.7  38
   6 7 1.8  96
  29 8 3.1  106
  26 8 3.0  130
  56 8 3    141
  45 8 2.3  80
  44 8 2.3  100
  35 9 4.9  197
 21 10 5.4  227

  k = 1.8
  110 5 1.9  42
  106 3 0.75 31
   98 6 2.1  69
   89 2 0.5  15
   81 3 0.9  29
   76 3 0.9  15
   74 5 1.6  41
   65 2 0.8  16
   64 4 1.4  36
   61 3 0.75 9
   60 5 1.6  41
   59 6 2.4  38
   58 4 1.2  20
   57 4 1.3  34
   56 8 4.7  143
   54 5 1.6  27
   53 3 0.75 17 
   21 10 11.0 228


These generated with gen_laser_tail

e1 2.1    e2 .38  9 16

  21  10  11.0 228
  35   9   9.8 197
  56   8   7.0 143 
   6   7   3.5  96
  59   6   3.0  38
  60   5   2.5  41
  57   4   2.0  34
  61   3   0.8   9
  65   2   0.8  16


ex_bath changed to take rn and pulse index.

tay = gen_laser_tail( 2.2,.38, 256 *9, .032, 9, 16 );
 rn	idx	nsat	scale	ch2 max 	Comment
89015, 21 	10	9.0	226		
89015, 35 	 9	7.0	197		
89015, 56 	 8	6.0	142		
89015,  7 	 7	3.0	 98		
89015, 59 	 6	2.8	 37		
89015, 60 	 5	2.0	 41		
89015, 57 	 4	1.7	 31		
89015, 61 	 3	0.8	  8		

90600, 56	12	9.0	236		Perhaps needs slower e2
89015, 34	-	-	-	Has volumetric surface only


*/



/*
  za holds manually determined values for the laser tail
  eliminator.  The first column is the number of saturated
  surface return samples, and the second column is the scale
  factor to apply in gen_laser_tail.  These are individually
  tweaked to supress the surface return.
 
*/
  extern za
  za = [ 
	 0.7		// 1
	,0.9		// 2
	,1.3
	,1.7
	,2.0		// 5
	,3.2
	,4.8
	,6.0
	,7.0
	,9.0		// 10
	,9.0
	,10.5
	,11.0
	,14.0
	,13.0		// 15
	,14.0		// 16
	,14.0		// 17
	,25.0		// 18
	,19.0		// 19
       ];






func ex_bath( rn, i,  last=, graph= ) {
/* DOCUMENT ex_bath(raster_number, pulse_index)

 for (j=1; j<1000; j++) { 
   j; 
   for (i=1; i<119; i++ ) { 
     qqq(,i,j) = ex_bath( rn+j,i,last=100, graph=1);
   }
 }
 fma; plmk,qqq(2,,j),qqq(1,,j),msize=.3, marker=1; rn 
 z = qqq(2,,2:1000:2)
 pli,z
 
*/
   r = get_erast( rn= rn );
  rp = decode_raster( r );
  a  = array(float, 256, 120, 4);
  n  = numberof(*rp.rx(i, 1)); 
  if ( n == 0 ) return [0,0,0];

  w  = *rp.rx(i, 1);  a(1:n, i) = float( (~w+1) - (~w(1)+1) );
  w2 = *rp.rx(i, 2);  a(1:n, i,2) = float( (~w2+1) - (~w2(1)+1) );


// The following developed using 7-14-01 data at rn = 46672 data. (sod=70510)
// Check waveform samples to see how many samples are
// saturated. 
// The function checks the following conditions so far:
//  1) Saturated surface return - locates last saturated sample
//  2) Non-saturated surface with saturated bottom signal
//  3) Non saturated surface with non-saturated bottom
//  4) Bottom signal above specified threshold
// We'll used this infomation to develope the threshold
// array for this waveform.
// We come out of this with the last_surface_sat set to the last
// saturated value of surface return.
// The 12 represents the last place a surface can be found
// Variables: 
//    last              The last point in the waveform to consider.
//    nsat 		A list of saturated pixels in this waveform
//    numsat		Number of saturated pixels in this waveform
//    last_surface_sat  The last pixel saturated in the surface region of the
//                      Waveform.
//    escale		The maximum value of the exponential pulse decay. 
//    laser_decay	The primary exponential decay array which mostly describes
//                      the surface return laser event.
//    secondary_decay   The exponential decay of the backscatter from within the
//                      water column.
//    agc		An array to equalize returns with depth so near surface 
//                      water column backscatter does't win over a weaker bottom signal.
//    bias              A linear tilt which is subtracted from the waveform to
//                      reduce the likelyhood of triggering on shallow noise.
//    da                The return waveform with the computed exponentials substracted
//    db                The return waveform equalized by agc and tilted by bias.

   nsat = where( w == 0 );			// Create a list of saturated samples 
   numsat = numberof(nsat);			// Count how many are saturated
   if ( (numsat > 1)  && ( nsat(1) < 12)   ) {
      if (  nsat(dif) (max) == 1 ) { 		// only surface saturated
          last_surface_sat = nsat(0);		// so use last one
          escale = 255;				
      } else {					// bottom must be saturated too
          last_surface_sat = nsat(  where(nsat(dif) > 1 ) ) (1);   
          escale = 255;
      }
   } else {
	  last_surface_sat =  w(1:12) (mnx) ;
          escale = 255 - w(1:12) (min);
   }

   laser_decay     = exp( -2.4 * attdepth) * escale;
   secondary_decay = exp( -0.6 * attdepth) * escale;
   laser_decay(last_surface_sat:0) = laser_decay(1:0-last_surface_sat+1) + 
					secondary_decay(1:0-last_surface_sat+1)*.25;
   laser_decay(1:last_surface_sat) = escale;

   agc     = 1.0 - exp( -0.3 * attdepth) ;
   agc(last_surface_sat:0) = agc(1:0-last_surface_sat+1); 
   agc(1:last_surface_sat) = 0.0;
   
   bias = (1-agc) * -5.0  ;
   

  da = a(,i,1) - laser_decay;
  db = da*agc + bias;
if ( graph ) {
plmk, a(,i,1), msize=.2, marker=1;
plg, a(,i,1);
plmk, da, msize=.2, marker=1;
plg, da;
plmk, db, msize=.2, marker=1, color="blue";
plg, db, color="blue";
plg, laser_decay, color="magenta" 
plg,agc*40
}
/***********/

  if ( is_void(last) ) 
	last = n;

  if ( n > last ) n = last;
  if ( db(1:n)(max) > 4.0) {
         mx = db(1:n)(mxx);
	return [ rp.sa(i), mx, a(mx,i,1) ];
  }
  else
 	return  [rp.sa(i), 0,0] ;


}




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

  struct AA { double soe(120); short  irange(120); short  sa(120); };

func irg( b, e ) {
/* DOCUMENT irg(b, e) 
   Returns an array of irange values from record
   b to record e.

   return array:
   a(1, ) = offset_time 
   a(2, ) = irange 
   a(3, ) = sa  (scan angle )
*/
  len = e - b;
//  a = array( float, 3, 120, len+1);
  a = array( AA,  len + 1 );
  "";
  for ( di=1, si=b; si<e; di++, si++ ) {
    rp = decode_raster( get_erast( rn=si )) ;
    a(di).soe = rp.offset_time ;
    a(di).irange = rp.irange;
    a(di).sa  = rp.sa;
    write,format="  %d/%d     \r", di, len
  }
  return a;
}

