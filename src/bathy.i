
/*

    $Id$

 */

 write,"$Id$" 

require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "sel_file.i"
require, "eaarl_constants.i"

struct BATHPIX {
  int rastpix;		// raster + pulse << 24
  short sa;		// scan angle  
  short idx;		// bottom index
  short bottom_peak;	// peak amplitude of bottom signal
};


func run_bath( rn, len, last=, graph=, pse= ) {
// depths = array(float, 3, 120, len );
 depths = array(BATHPIX, 120, len );
 if ( graph != 0 ) 
	animate,1;

 if ( is_void(last) ) 
	last = 250;
 if ( is_void(graph) ) 
	graph = 0;
   for ( j=1; j< len; j++ ) {
     j;
     for (i=1; i<119; i++ ) {
       depths(i,j) = ex_bath( rn+j, i, last = last, graph=graph);
       if ( !is_void(pse) ) 
	  pause, pse;
     }
   }
 if ( graph != 0 ) 
	animate,0;
 
  return depths;
}


func ex_bath( rn, i,  last=, graph= ) {
/* DOCUMENT ex_bath(raster_number, pulse_index)

 for (j=1; j<1000; j++) { 
   j; 
   for (i=1; i<119; i++ ) { 
     qqq(,i,j) = ex_bath( rn+j,i,last=100, graph=0);
   }
 }
 fma; plmk,qqq(2,,j),qqq(1,,j),msize=.3, marker=1; rn 
 z = qqq(2,,2:1000:2)
 fma;pli,-z,cmin=-22, cmax=-10


 This function returns a three element with the following organization:

  Element     Description
	1	Raw scan angle counts
 	2	Bottom location (index) in the waveform 
	3	Bottom peak signal value in first waveform counts

	[ rp.sa(i), mx, a(mx,i,1) ];
 
*/

/*
 The following developed using 7-14-01 data at rn = 46672 data. (sod=70510)
 Check waveform samples to see how many samples are
 saturated. 
 The function checks the following conditions so far:
  1) Saturated surface return - locates last saturated sample
  2) Non-saturated surface with saturated bottom signal
  3) Non saturated surface with non-saturated bottom
  4) Bottom signal above specified threshold
 We'll used this infomation to develope the threshold
 array for this waveform.
 We come out of this with the last_surface_sat set to the last
 saturated value of surface return.
 The 12 represents the last place a surface can be found
 Variables: 
    last              The last point in the waveform to consider.
    nsat 		A list of saturated pixels in this waveform
    numsat		Number of saturated pixels in this waveform
    last_surface_sat  The last pixel saturated in the surface region of the
                      Waveform.
    escale		The maximum value of the exponential pulse decay. 
    laser_decay	The primary exponential decay array which mostly describes
                      the surface return laser event.
    secondary_decay   The exponential decay of the backscatter from within the
                      water column.
    agc		An array to equalize returns with depth so near surface 
                      water column backscatter does't win over a weaker bottom signal.
    bias              A linear tilt which is subtracted from the waveform to
                      reduce the likelyhood of triggering on shallow noise.
    da                The return waveform with the computed exponentials substracted
    db                The return waveform equalized by agc and tilted by bias.
*/

 extern ex_bath_rn, ex_bath_rp, a
  rv = BATHPIX();			// setup the return struct
  rv.rastpix = rn + (i<<24);
  if ( is_void( ex_bath_rn )) 
	ex_bath_rn = -1;

  if ( is_void(a) )
    a  = array(float, 256, 120, 4);

  if ( ex_bath_rn != rn ) {  // simple cache for raster data
     r = get_erast( rn= rn );
    rp = decode_raster( r );
    ex_bath_rn = rn;
    ex_bath_rp = rp;
  } else {
   rp = ex_bath_rp;
  }

  n  = numberof(*rp.rx(i, 1)); 
  if ( n == 0 ) 
	return rv;

  w  = *rp.rx(i, 1);  a(1:n, i) = float( (~w+1) - (~w(1)+1) );
///////  w2 = *rp.rx(i, 2);  a(1:n, i,2) = float( (~w2+1) - (~w2(1)+1) );


   nsat = where( w == 0 );			// Create a list of saturated samples 
   numsat = numberof(nsat);			// Count how many are saturated
   if ( (numsat > 1)  && ( nsat(1) <= 12)   ) {
      if (  nsat(dif) (max) == 1 ) { 		// only surface saturated
          last_surface_sat = nsat(0);		// so use last one
          escale = 255;				
      } else {					// bottom must be saturated too
          last_surface_sat = nsat(  where(nsat(dif) > 1 ) ) (1);   
          escale = 255;
      }
   } else {
          wflen = numberof(w);
          if ( wflen > 12 ) wflen = 12;
	  last_surface_sat =  w(1:wflen) (mnx) ;
          escale = 255 - w(1:wflen) (min);
   }

   laser_decay     = exp( -2.4 * attdepth) * escale;
   secondary_decay = exp( -1.5 * attdepth) * escale; // for tampa bay water
   secondary_decay = exp( -0.6 * attdepth) * escale; // for keys water
   laser_decay(last_surface_sat:0) = laser_decay(1:0-last_surface_sat+1) + 
					secondary_decay(1:0-last_surface_sat+1)*.25;
   laser_decay(1:last_surface_sat) = escale;

   agc     = 1.0 - exp( -3.0 * attdepth) ;	// for tampa bay water
   agc     = 1.0 - exp( -0.3 * attdepth) ;	// for keys water
   agc(last_surface_sat:0) = agc(1:0-last_surface_sat+1); 
   agc(1:last_surface_sat) = 0.0;
   
   bias = (1-agc) * -5.0  ;
   

  da = a(,i,1) - laser_decay;
  db = da*agc + bias;
if ( graph ) {
window,4; fma
plmk, a(,i,1), msize=.2, marker=1, color="black";
plg, a(,i,1);
plmk, da, msize=.2, marker=1, color="black";
plg, da;
plmk, db, msize=.2, marker=1, color="blue";
plg, db, color="blue";
plg, laser_decay, color="magenta" 
plg,agc*40
}

  if ( is_void(last) ) 		// see if user specified the max depth
	last = n;

  if ( n > last ) 		
	n = last;

  mv = db(1:n)(max);		// find peak value
  mvi = db(1:n)(mxx);		// find peak position
  if ( mv > 4.0) {		// check to see if above thresh
         mx = mvi;

if ( graph ) {
 plmk, a(mx,i,1), mx, msize=1.0, marker=7, color="blue", width=10
}
        rv.sa = rp.sa(i);
   	rv.idx = mx;
	rv.bottom_peak = a(mx,i,1);
	return rv;
  }
  else
   	rv.idx = 0;
	rv.bottom_peak = a(mvi,i,1);
	return rv;
}



