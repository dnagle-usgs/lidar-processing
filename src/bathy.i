
/*

    $Id$
   
    W. Wright 


    5-14-02  
	Added bath_ctl structure
	Changed thresh from fixed for all waveforms to self adjusting
	based on how many surface pixels are saturated.  This is because
	the subsurface noise goes up significantly when the surface is 
	driven far into saturation.  The function needs to be carefully
	evaluated to determine the exact relationship between noise level
	changes and the required threshold change.

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

// 94000
func bath_winpix( m ) {
extern depth_display_units;
extern rn;
  window,3;
  idx = int( mouse() (1:2) );
idx
// ******* IMPORTANT! The *2 below is there cuz we usually only look at
// every other raster. 
  rn  = m(idx(1), idx(2)*2).rastpix;  	// get the *real* raster number.
rn
  pix = rn / 2^24;
  rn  &= 0xffffff;
   r = get_erast( rn= rn );	
   rp = decode_raster(r);
  window,1; fma;
  aa = ndrast( rp, units=depth_display_units  ) 
//  show_wf( aa, pix, win=0 )
pix
rn
}


func run_bath( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse= ) {
// depths = array(float, 3, 120, len );

 if ( is_void(rn) || is_void(len) ) {
    if (!is_void(center) && !is_void(delta)) {
       rn = center - delta;
       len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
             rn = start-1;
	     len = stop - start;
    } else {
	     write, "Input parameters not correctly defined.  See help, run_bath.  Please start again.";
	     return 0;
    }
 }


    
     
 depths = array(BATHPIX, 120, len );
 //if ( graph != 0 ) 
//	animate,1;

 if ( is_void(last) ) 
	last = 250;
 if ( is_void(graph) ) 
	graph = 0;
   for ( j=1; j<= len; j++ ) {
     if (!(j%25)) write, format="%5d of %5d rasters completed \r",j,len;
     if (j == len) write, format= "%5d of %5d rasters completed \r",j,len;
     for (i=1; i<119; i++ ) {
       depths(i,j) = ex_bath( rn+j, i, last = last, graph=graph);
       if ( !is_void(pse) ) 
	  pause, pse;
     }
   }
 //if ( graph != 0 ) 
//	animate,0;

  write,"\n"
 
  return depths;
}

struct BATH_CTL{
  float laser;		// system exponential decay  ( -1.5 )
  float water;		// water column exponential decay ( -0.3 )
  float agc;		// exponential equalizer ( -5 )
  float thresh;		// threshold value ( 3 )
  int   last;		// last nanosecond to consider (maxdepth in ns)  ( 150 )
} ;

extern bath_ctl;
/* DOCUMENT extern struct bath_ctl 

   laser	water	agc	thresh 
   -2.4       -1.5    -3.0	4.0	tampa and keys laser decay
   -2.4	      -0.6    -0.3	4.0	keys
   -2.4       -7.5    -5.0	4.0	wva

  Do this to set the values:

  bath_ctl.laser = -1.5
  bath_ctl.water = -0.6
  bath_ctl.agc   = -5.0
  bath_ctl.thresh=  4.0


*/

 if ( is_void( bath_ctl ) ) {
   bath_ctl = BATH_CTL();
 }

func define_bath_ctl(junk,type=) {
  /* this function defines the structure bath_ctl depending on the type.  As of now, type can be, "keys", "tampabay", "wva" */
  /* amar nayegandhi 06/05/2002 */
  if (!type) {
    type = rdline(prompt="Enter type of data set ('keys', 'tampabay' or 'wva'): ");
  }
    
  if (type == "keys") {
     bath_ctl.laser = -2.4;
     bath_ctl.water = -0.6;
     bath_ctl.agc = -0.3;
     bath_ctl.thresh = 4.0;
  } 
  if (type == "tampabay") {
     bath_ctl.laser = -2.4;
     bath_ctl.water = -1.5;
     bath_ctl.agc = -3.0;
     bath_ctl.thresh = 4.0;
  }
  if (type == "wva") {
     bath_ctl.laser = -2.4;
     bath_ctl.water = -7.5;
     bath_ctl.agc = -5.0;
     bath_ctl.thresh = 4.0;
  }
  return type;

}

func ex_bath( rn, i,  last=, graph= ) {
/* DOCUMENT ex_bath(raster_number, pulse_index)

  See run_bath for details on usage.


 This function returns a BATHPIX structure element

 For the turbid key areas use:
  bath_ctl = BATH_CTL(laser=-1.5,water=-0.4,agc=-0.3,thresh=3)

 For the clear areas:
  bath_ctl = BATH_CTL(laser=-2.5,water=-0.3,agc=-0.3,thresh=3)

 
*/




/*
 The following developed using 7-14-01 data at rn = 46672 data. (sod=70510)
 Check waveform samples to see how many samples are
 saturated. 
 At this time, this function checks only for the following conditions:
  1) Saturated surface return - locates last saturated sample
  2) Non-saturated surface with saturated bottom signal
  3) Non saturated surface with non-saturated bottom
  4) Bottom signal above specified threshold
 We'll used this infomation to develope the threshold
 array for this waveform.
 We come out of this with the last_surface_sat set to the last
 saturated value of surface return.
 The 12 represents the last place a surface can be found

 Controls:

    See bath_ctl structure.

    last              160    1:300     The last point in the waveform to consider.
     laser	      -3.0  -1:-5.0    The exponent which describes the laser decay rate
     water         -2.0  -0.1:-10.0 The exponent which best describes this water column
       agc         -0.3  -0.1:-10.0 Agc scaling exponent.
    thresh	    4.0   1:50      bottom peak value threshold

 Variables: 
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

  if ( is_void( bath_ctl) ) {
    write, "You havn't defined a bath_ctl structure.  type help, bath_ctl for details"
    return;
  }

    if ( bath_ctl.laser == 0.0 ) {
    write, "You havn't defined a bath_ctl structure.  type help, bath_ctl for details"
    return;
   }

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
  rv.sa = rp.sa(i);
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
          if ( wflen > 18 ) wflen = 18;
	  last_surface_sat =  w(1:wflen) (mnx) ;
          escale = 255 - w(1:wflen) (min);
   }



   laser_decay     = exp( bath_ctl.laser * attdepth) * escale;  
   secondary_decay = exp( bath_ctl.water * attdepth) * escale; 

   laser_decay(last_surface_sat:0) = laser_decay(1:0-last_surface_sat+1) + 
					secondary_decay(1:0-last_surface_sat+1)*.25;
   laser_decay(1:last_surface_sat) = escale;

   agc     = 1.0 - exp( bath_ctl.agc * attdepth) ;	
   agc(last_surface_sat:0) = agc(1:0-last_surface_sat+1); 
   agc(1:last_surface_sat) = 0.0;
   
   bias = (1-agc) * -5.0  ;
   

  da = a(,i,1) - laser_decay;
  db = da*agc + bias;


  thresh = bath_ctl.thresh;
  if ( numsat > 14 ) {
    thresh = thresh * (numsat-13)*0.65;
  }


if ( graph ) {
window,4; fma
plg,[thresh,thresh],[1,n],marks=0, color="red"
plmk, a(,i,1), msize=.2, marker=1, color="black";
plg, a(,i,1);
plmk, da, msize=.2, marker=1, color="black";
plg, da;
plmk, db, msize=.2, marker=1, color="blue";
plg, db, color="blue";
plg, laser_decay, color="magenta" 
plg,agc*40
}


  if ( is_void(last) ) 		// see if user specified the max depth as input to this func
	last = n;

  if ( n > last ) 		
	n = last;

  mv = db(1:n)(max);		// find peak value
  mvi = db(1:n)(mxx);		// find peak position

// test pw with 9-6-01:17673:50
  if ( mv > thresh ) {		// check to see if above thresh
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



