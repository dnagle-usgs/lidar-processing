
/*

    $Id$
   
    W. Wright 

 */

 write,"$Id$" 

require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "sel_file.i"
require, "eaarl_constants.i"

struct VEGPIX {
  int rastpix;		// raster + pulse << 24
  short sa;		// scan angle  
  short mx1;		// first pulse index
  short mv1;		// first pulse peak value
  short mx0;		// last pulse index
  short mv0;		// last pulse peak value
  char  nx;		// number of return pulses found
};

// 94000
func veg_winpix( m ) {
extern depth_display_units;
extern rn;
  window,3;
  idx = int( mouse() (1:2) );
idx
//******* IMPORTANT! The *2 below is there cuz we usually only look at
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


func run_veg( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse= ) {
// depths = array(float, 3, 120, len );

 if ( is_void(rn) || is_void(len) ) {
    if (!is_void(center) && !is_void(delta)) {
       rn = center - delta;
       len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
             rn = start;
	     len = stop - start;
    } else {
	     write, "Input parameters not correctly defined.  See help, run_veg.  Please start again.";
	     return 0;
    }
 }


    
     
 depths = array(VEGPIX, 120, len );
 if ( graph != 0 ) 
	animate,1;

 if ( is_void(last) ) 
	last = 250;
 if ( is_void(graph) ) 
	graph = 0;
   for ( j=1; j< len; j++ ) {
     j;
     for (i=1; i<119; i++ ) {
       depths(i,j) = ex_veg( rn+j, i, last = last, graph=graph);
       if ( !is_void(pse) ) 
	  pause, pse;
     }
   }
 if ( graph != 0 ) 
	animate,0;
 
  return depths;
}


func ex_veg( rn, i,  last=, graph= ) {
/* DOCUMENT ex_veg(raster_number, pulse_index)


 see run_veg 


 This function returns a three element with the following organization:

  Element     Description
	1	Raw scan angle counts
 	2	Bottom location (index) in the waveform 
	3	Bottom peak signal value in first waveform counts

	[ rp.sa(i), mx, a(mx,i,1) ];
 
*/

/*
 The following developed using 8-25-01 data at rn = 239269 data. 
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
    da                The return waveform with the computed exponentials substracted
    db                The return waveform equalized by agc and tilted by bias.
*/

 extern ex_bath_rn, ex_bath_rp, a
  rv = VEGPIX();			// setup the return struct
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
          if ( wflen > 12 ) wflen = 12;
	  last_surface_sat =  w(1:wflen) (mnx) ;
          escale = 255 - w(1:wflen) (min);
   }


  da = a(1:n,i,1);
  dd = a(1:n, i, 1) (dif);

/******************************************
   xr(1) will be the first pulse edge
   and xr(0) will be the last
*******************************************/
  thresh = 4.0
//  xr = where( dd  > thresh ) ;	// find the hits
  xr = where(  ((dd >= thresh) (dif)) == 1 ) 	//
  nxr = numberof(xr);

if ( graph ) {
window,4; fma
plmk, a(1:n,i,1), msize=.2, marker=1, color="black";
plg, a(1:n,i,1);
plmk, da, msize=.2, marker=1, color="black";
plg, da;
plg, dd-100, color="red"
///if ( nxr > 0 ) 
///	plmk, a( xr(0),i,1), xr(0),msize=.3,marker=3
}

  if ( is_void(last) ) 		// see if user specified the max depth
	last = n;

  if ( n > last ) 		
	n = last;


  if ( numberof(xr) > 0  ) {
    mx0 = a( xr(0):xr(0)+5, i, 1)(mxx) + xr(0) - 1;	  // find surface peak now
    mv0 = a( mx0, i, 1);	          
    mx1 = a( xr(1):xr(1)+5, i, 1)(mxx) + xr(1) - 1;	  // find surface peak now
    mv1 = a( mx1, i, 1);	          
    if ( graph ) {
         plmk, mv1, mx1, msize=.5, marker=7, color="blue", width=1
         plmk, mv0, mx0, msize=.5, marker=7, color="red", width=1
    }
        rv.sa = rp.sa(i);
   	rv.mx0 = mx0;
	rv.mv0 = mv0;
   	rv.mx1 = mx1;
	rv.mv1 = mv1;
	rv.nx  = numberof(xr);
	return rv;
  }
  else {
        rv.sa = rp.sa(i);
   	rv.mx0 = -1;
	rv.mv0 = a(max,i,1);
   	rv.mx1 = -1;
	rv.mv1 = rv.mv0;
	rv.nx  = numberof(xr);
	return rv;
  }
}



