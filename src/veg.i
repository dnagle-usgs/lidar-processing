
/*

    $Id$
   
    W. Wright 

 test..

 */

 write,"$Id$" 

require, "ytime.i"
require, "rlw.i"
require, "string.i"
require, "sel_file.i"
require, "eaarl_constants.i"
require, "colorbar.i"

struct VEGPIX {
  int rastpix;		// raster + pulse << 24
  short sa;		// scan angle  
  short mx1;		// first pulse index
  short mv1;		// first pulse peak value
  short mx0;		// last pulse index
  short mv0;		// last pulse peak value
  char  nx;		// number of return pulses found
};

struct VEGPIXS {
  int rastpix;		// raster + pulse << 24
  short sa;		// scan angle  
  short mx(10);		// range in ns of all return peaks from irange
  short mv(10);		// intensities of all return peaks (max 10)
  char  nx;		// number of return pulses found
};

struct VEGALL {
  long rn(120);		// raster + pulse << 24
  long north(120); 	//surface northing in centimeters
  long east(120);	//surface easting in centimeters
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  short felv(120);	// first pulse index
  short fint(120);	// first pulse peak value
  short lelv(120);	// last pulse index
  short lint(120);	// last pulse peak value
  char  nx(120);	// number of return pulses found
  double soe(120);	// Seconds of the epoch
};

struct VEG_ALL {
  long rn(120);		// raster + pulse << 24
  long north(120); 	//surface northing in centimeters
  long east(120);	//surface easting in centimeters
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  long felv(120);	// irange value in ns 
  short fint(120);	// first pulse peak value
  long lelv(120);	// last return in centimeters
  short lint(120);	// last return pulse peak value
  char  nx(120);	// number of return pulses found
  double soe(120);	// Seconds of the epoch
};

// this structure below (VEG_ALL_)introduced on 03/08/03 to include the first surface easting, northing as well as the llast surface (bare earth) easting/northing.
struct VEG_ALL_ {
  long rn(120);		// raster + pulse << 24
  long north(120); 	//surface northing in centimeters
  long east(120);	//surface easting in centimeters
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  long lnorth(120); 	//bottom northing in centimeters
  long least(120);	//bottom easting in centimeters
  long lelv(120);	// last return in centimeters
  short fint(120);	// first pulse peak value
  short lint(120);	// last return pulse peak value
  char  nx(120);	// number of return pulses found
  double soe(120);	// Seconds of the epoch
};

struct CVEG_ALL {
  long rn;	// raster + pulse << 24
  long north; 	//target northing in centimeters
  long east;	//target easting in centimeters
  long elevation; //target elevation in centimeters
  long mnorth;	//mirror northing
  long meast;	//mirror easting
  long melevation;//mirror elevation
  short intensity;// pulse peak intensity value
  char  nx;	// number of return pulses found
  double soe;	// Seconds of the epoch
};

// 94000
func veg_winpix( m ) {
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


func run_veg( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=, use_centroid=,use_peak= ) {
// depths = array(float, 3, 120, len );
  if (is_void(graph)) graph=0;

 if ( is_void(rn) || is_void(len) ) {
    if (!is_void(center) && !is_void(delta)) {
       rn = center - delta;
       len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
             rn = start-1;
	     len = stop - start+1;
    } else {
	     write, "Input parameters not correctly defined.  See help, run_veg.  Please start again.";
	     return 0;
    }
 }


     
   
 depths = array(VEGPIX, 120, len );
  if ( _ytk ) {
    tkcmd,"destroy .veg; toplevel .veg; set progress 0;"
    tkcmd,swrite(format="ProgressBar .veg.pb \
	-fg yellow \
	-troughcolor blue \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", len );
    tkcmd,"pack .veg.pb; update; center_win .veg;"
  }
 if ( graph != 0 ) 
	animate,1;

 if ( is_void(last) ) 
	last = 250;
 if ( is_void(graph) ) 
	graph = 0;
   for ( j=1; j< len; j++ ) {
     if (_ytk) 
       tkcmd, swrite(format="set progress %d", j)
     else {
     if ( (j % 10)  == 0 ) 
        write, format="   %d of %d   \r", j,  len
     }
     for (i=1; i<119; i++ ) {
       depths(i,j) = ex_veg( rn+j, i, last = last, graph=graph, use_centroid=use_centroid,use_peak=use_peak);
       if ( !is_void(pse) ) 
	  pause, pse;
     }
   }
 if ( graph != 0 ) 
	animate,0;
 if (_ytk) {
   tkcmd, "destroy .veg"
   } else write, "\n"; 
  return depths;
}


func ex_veg( rn, i,  last=, graph=, win=, use_centroid=, use_peak=, pse= ) {
/* DOCUMENT ex_veg(raster_number, pulse_index)


 see run_veg 


 This function returns an array of VEGPIX structures. 

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
    nsat 	      A list of saturated pixels in this waveform
    numsat	      Number of saturated pixels in this waveform
    last_surface_sat  The last pixel saturated in the surface region of the
                      Waveform.
    escale	      The maximum value of the exponential pulse decay. 
    laser_decay	      The primary exponential decay array which mostly describes
                      the surface return laser event.
    da                The return waveform with the computed exponentials 
                      substracted
    db                The return waveform equalized by agc and tilted by bias.

*/

 extern ex_bath_rn, ex_bath_rp, a, irg_a, _errno
  _errno = 0;		// If not specifically set, preset to assume no errors.
  if ( (rn == 0 ) && ( i == 0 ) ) {
     write,format="Are you clicking in window %d?,  No data was found.\n",win
     _errno = -1;
     return ;
  }
  irange = irg_a(where(rn==irg_a.raster)).irange(i);
  intensity = irg_a(where(rn==irg_a.raster)).intensity(i);
  rv = VEGPIX();			// setup the return struct
  rv.rastpix = rn + (i<<24);
  if (irange < 0) return rv;
  if ( is_void( ex_bath_rn )) 
	ex_bath_rn = -1;

  if ( is_void(aa) )
    aa  = array(float, 256, 120, 4);

  if ( ex_bath_rn != rn ) {  // simple cache for raster data
     r = get_erast( rn= rn );
    rp = decode_raster( r );
    ex_bath_rn = rn;
    ex_bath_rp = rp;
  } else {
   rp = ex_bath_rp;
  }

  ctx = cent(*rp.tx(i));

  n  = numberof(*rp.rx(i, 1)); 
  rv.sa = rp.sa(i);
  if ( n == 0 ) {
	_errno = -1;
	return rv;
  }

  w  = *rp.rx(i, 1);  aa(1:n, i) = float( (~w+1) - (~w(1)+1) );
///////  w2 = *rp.rx(i, 2);  aa(1:n, i,2) = float( (~w2+1) - (~w2(1)+1) );

 if (!(use_centroid)) {
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
   } else { // surface not saturated
          wflen = numberof(w);
          if ( wflen > 12 ) wflen = 12;
	  last_surface_sat =  w(1:wflen) (mnx) ;
          escale = 255 - w(1:wflen) (min);
   }

 }

  da = aa(1:n,i,1);
  dd = aa(1:n, i, 1) (dif);

/******************************************
   xr(1) will be the first pulse edge
   and xr(0) will be the last
*******************************************/
  thresh = 4.0
//  xr = where( dd  > thresh ) ;	// find the hits
  xr = where(  ((dd >= thresh) (dif)) == 1 ) 	//
  nxr = numberof(xr);

if (is_void(win)) win = 4;
if ( graph ) {
window,win; fma;
//limits
plmk, aa(1:n,i,1), msize=.2, marker=1, color="black";
plg, aa(1:n,i,1);
plmk, da, msize=.2, marker=1, color="black";
plg, da;
plg, dd-100, color="red"
write, format="rn=%d; i = %d\n",rn,i
///if ( nxr > 0 ) 
///	plmk, a( xr(0),i,1), xr(0),msize=.3,marker=3
}

  if ( is_void(last) ) 		// see if user specified the max veg
	last = n;

  if ( n > last ) 		
	n = last;


  if ( numberof(xr) > 0  ) {
    if (use_centroid || use_peak) {
       //assume 12ns to be the longest duration for a complete bottom return
       retdist = 12;
       ai = 1; //channel number
       if (xr(0)+retdist+1 > n) retdist = n - xr(0)-1;
       // check for saturation
       if ( numberof(where((w(xr(0):xr(0)+retdist)) == 0 )) >= 2 ) {
           // goto second channel
            ai = 2;
           // write, format="trying channel 2, rn = %d, i = %d\n",rn, i
            w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
            da = aa(1:n,i,ai);
            dd = aa(1:n, i, ai) (dif);
            if ( numberof(where((w(xr(0):xr(0)+retdist)) == 0 )) >= 2 ) {
              // goto third channel
            //  write, format="trying channel 3, rn = %d, i = %d\n",rn, i
              ai = 3;
              w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
              da = aa(1:n,i,ai);
              dd = aa(1:n, i, ai) (dif);
              if ( numberof(where((w(xr(0):xr(0)+retdist)) == 0 )) >= 2 ) {
                 write, format="all 3 channels saturated... giving up!, rn=%d, i=%d\n",rn,i
                 ai = 0;
              }
	    }
	}

       if (retdist < 5) ai = 0; // this eliminates possible noise pulses.
       if (!ai) {
        rv.sa = rp.sa(i);
   	rv.mx0 = -1;
	rv.mv0 = -10;
   	rv.mx1 = -1;
	rv.mv1 = -11;
	rv.nx  = -1;
	_errno = 0;
        return rv
       }
       if (pse) pause, pse;

       if ( graph && ai >= 2) {
         //window,4; fma
         plmk, aa(1:n,i,ai), msize=.2, marker=1, color="yellow";
         plg, aa(1:n,i,ai), color="yellow";
         plmk, da, msize=.2, marker=1, color="yellow";
         plg, da, color="yellow";
         plg, dd-100, color="blue"
	 pltit = swrite(format="ai = %d\n", ai);
	 pltitle, pltit;
       }
       
     if (use_centroid && !use_peak) {

      
       // find where the bottom return pulse changes direction after its trailing edge
       idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
       idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
       if (is_array(idx1) && is_array(idx)) {
        if (idx(0) > idx1(1)) {
         //take length of  return at this point
	 //write, format="this happens!! rn = %d; i = %d\n",rn,i;
         retdist = idx(0);
        }
       } else 
       write, format="idx/idx1 is nuller for rn=%d, i=%d    \r",rn, i  
       //now check to see if it it passes intensity test
       mxmint = aa(xr(0)+1:xr(0)+retdist,i,ai)(max);
       if (abs(aa(xr(0)+1,i,ai) - aa(xr(0)+retdist,i,ai)) < 0.2*mxmint) {
           // this return is good to compute centroid
           b = aa(int(xr(0)+1):int(xr(0)+retdist),i,ai); // create array b for retdist returns beyond the last peak leading edge.
           //compute centroid
          if (b(sum) != 0) {
           c = float(b*indgen(1:retdist)) (sum) / (b(sum));
           mx0 = xr(0)+c;
           if (ai == 1) mv0 = aa(int(mx0),i,ai);
           if (ai == 2) {
	       mx0 = mx0 + 0.36;
	       mv0 = aa(int(mx0),i,ai)+300;
	   }
           if (ai == 3) {
	       mx0 = mx0 + 0.23;
	       mv0 = aa(int(mx0),i,ai)+600;
	   }
          } else {
           mx0 = -10;
           mv0 = -10;
          }
       } else {
          // for now, discard this pulse
          mx0 = -10;
          mv0 = -10;
       } 
    }
    
    if (!use_centroid && use_peak) {
       // if within 3 ns from xr(0) we find a peak, we can assume this to be noise related and try again using xr(0) from the first positive difference after the last negative difference.
       nidx = where(dd(xr(0):xr(0)+3) < 0);
       if (is_array(nidx)) {
         xr(0) = xr(0) + nidx(1);
	 if (xr(0)+retdist+1 > n) retdist = n - xr(0)-1;
       }
      // using trailing edge algorithm for bottom return
       // find where the bottom return pulse changes direction after its trailing edge
       idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
       idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
       if (is_array(idx1) && is_array(idx)) {
        //write, idx;
        //write, idx1;
        if (idx(0) > idx1(1)) {
         //take length of  return at this point
	 //write, format="this happens!! rn = %d; i = %d\n",rn,i;
         retdist = idx(0);
        }
       }
       if (is_array(idx1)) {
	ftrail = idx1(1);
	ltrail = retdist;
	//halftrail = 0.5*(ltrail - ftrail);
	mx0 = irange+xr(0)+idx1(1)-ctx(1);
	mv0 = aa(int(xr(0)+idx1(1)),i,ai);
       } else {
        mx0 = -10;
	mv0 = -10;
       }
    }

   } else { //donot use centroid or trailing edge
     mvx =  aa( xr(0):xr(0)+5, i, 1)(mxx);
     mx0 = irange+aa( xr(0):xr(0)+5, i, 1)(mxx) + xr(0) - 1;	  // find bottom peak now
      mv0 = aa( mvx, i, 1);	          
    }
    // stuff below is for mx1 (first surface in veg).

    if (use_centroid || use_peak) {
       np = numberof ( *rp.rx(i,1) );      // find out how many waveform points
                                        // are in the primary (most sensitive)
                                        // receiver channel.

       if ( np < 2 ) {                         // give up if there are not at
	      _errno = -1;
              return;                            // least two points.
       }

       if ( np > 12 ) np = 12;               // use no more than 12
       if ( numberof(where(  ((*rp.rx(i,1))(1:np)) == 0 )) <= 2 ) {
         cv = cent( *rp.rx(i, 1 ) );
       } else if ( numberof(where(  ((*rp.rx(i,2))(1:np)) == 0 )) <= 2 ) {
         cv = cent( *rp.rx(i, 2 ) ) + 0.36;
         cv(3) += 300;
       } else {
         cv = cent( *rp.rx(i, 3 ) ) + 0.23;
         cv(3) += 600;
       }

       if (cv(1) < 10000) {
          mx1 = irange+cv(1)-ctx(1);
       } else {
          mx1 = -10;
       }
       mv1 = cv(3);
    } else {
      mx1 = aa( xr(1):xr(1)+5, i, 1)(mxx) + xr(1) - 1;	  // find surface peak now
      mv1 = aa( mx1, i, 1);	          
    }

    // make mx1 be the irange value and mv1 be the intensity value from variable 'a'
    // edit out tx/rx dropouts
    el = (int(irange) & 0xc000 ) == 0 ;
    irange *= el;
    //mx1 = irange;
    //mv1 = intensity;
    if ( graph ) {
         plmk, mv1, mx1, msize=.5, marker=7, color="blue", width=1
         plmk, mv0, mx0, msize=.5, marker=7, color="red", width=1
    }
    if (pse) pause, pse;
        rv.sa = rp.sa(i);
   	rv.mx0 = mx0;
	rv.mv0 = mv0;
   	rv.mx1 = mx1;
	rv.mv1 = mv1;
	rv.nx  = numberof(xr);
	_errno = 0;
	return rv;
  }
  else {
        rv.sa = rp.sa(i);
   	rv.mx0 = -1;
	rv.mv0 = aa(max,i,1);
   	rv.mx1 = -1;
	rv.mv1 = rv.mv0;
	rv.nx  = numberof(xr);
	_errno = 0;
	return rv;
  }
}



func display_veg(veg_arr, felv=, lelv=,  fint=, lint=, cmin=, cmax=, size=, win=, dofma=, edt=, cht=, marker=, skip= ) {
  /* DOCUMENT display_veg(veg_arr, fr=, lr=,  cmin=, cmax=, size=, win=, dofma=, edt=, marker= )
 This function displays a veg plot using the veg array from functin run_veg, 
 and the georeferencing from the first_surface function.   If fr = 1, the 
 first surface return is plotted.  If lr = 1, the last returns are plotted 
 (bald earth).  If fr=lr=1, the canopy height is plotted.

  */
  extern elv;
  if ( is_void(win) )
      win = 5;
	    
  window,win; 
  if ( !is_void( dofma ) )
      fma;
  write,"Please wait while drawing..........\r"
  if ( is_void( size )) size = 1.4;
  len = numberof(veg_arr);
  if (felv) {
     elv = veg_arr.elevation/100.;
     if ( is_void( cmin )) cmin = min(veg_all.elevation)/100.;
     if ( is_void( cmax )) cmax = max(veg_all.elevation)/100.;
  }
  if (lelv) {
     elv = veg_arr.lelv/100.
     if ( is_void( cmin )) cmin = min(veg_all.lelv)/100.;
     if ( is_void( cmax )) cmax = max(veg_all.lelv)/100.;
  }
  if (cht) {
     elv = (veg_arr.lelv-veg_arr.elevation)/100.;
     if ( is_void( cmin )) cmin = min(veg_all.lelv-veg_all.elevation)/100.;
     if ( is_void( cmax )) cmax = max(veg_all.lelv-veg_all.elevation)/100.;
  }
  if (fint) {
     elv = veg_arr.fint;
     if ( is_void( cmin )) cmin = min(veg_all.fint);
     if ( is_void( cmax )) cmax = max(veg_all.fint);
  }
  if (lint) {
     elv = veg_arr.lint;
     if ( is_void( cmin )) cmin = min(veg_all.lint);
     if ( is_void( cmax )) cmax = max(veg_all.lint);
  }

  if (is_void(marker)) 
	marker = 4;
  
  if (((dimsof(elv))(1)) == 2) {
   for ( i=1; i<len; i++ ) {
    //write, format="i = %d\r",i
    q = where( (veg_arr(i).north) );
    if ( numberof(q) >= 1) {
       if (lelv || lint) {
         plcm, elv(q,i)(1:0:skip), veg_arr(i).lnorth(q)(1:0:skip)/100.0, veg_arr(i).least(q)(1:0:skip)/100.0,
            msize=size,cmin=cmin, cmax=cmax, marker=marker;
       } else {
         plcm, elv(q,i)(1:0:skip), veg_arr(i).north(q)(1:0:skip)/100.0, veg_arr(i).east(q)(1:0:skip)/100.0,
            msize=size,cmin=cmin, cmax=cmax, marker=marker
       }
    }
   }
  } else {
   q = where( (veg_arr.north) );
   if (numberof(q) >= 1) {
      if (lelv || lint) {
        plcm, elv(q)(1:0:skip), veg_arr.lnorth(q)(1:0:skip)/100.0, veg_arr.least(q)(1:0:skip)/100.0,
           msize=size,cmin=cmin, cmax=cmax, marker=marker;
      } else {
        plcm, elv(q)(1:0:skip), veg_arr.north(q)(1:0:skip)/100.0, veg_arr.east(q)(1:0:skip)/100.0,
           msize=size,cmin=cmin, cmax=cmax, marker=marker;
      }
       
   }
  }

  //colorbar, cmin, cmax;
  write,format="Draw complete. %d rasters drawn. %s", len, "\n"
}

func make_fs_veg (d, rrr) {  
/* DOCUMENT make_fs_veg (d, rrr) 

 This function makes a veg data array using the 
 georectification of the first surface return.  The parameters are as 
 follows:

 d	Array of structure VEGPIX  containing veg information.  
        This is the return value of function run_bath.

 rrr    Array of structure R containing first surface information.  
        This the is the return value of function first_surface.


 The return value veg is an array of structure VEGALL. The array 
 can be written to a file using write_geoall  

   See also: first_surface, run_veg, write_vegall
*/


// d is the veg array from veg.i
// rrr is the topo array from surface_topo.i

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

geoveg = array(VEG_ALL_, len);

for (i=1; i<=len; i=i+1) {
  geoveg(i).rn = rrr(i).rn;
  geoveg(i).north = rrr(i).north;
  geoveg(i).east = rrr(i).east;
  geoveg(i).elevation = rrr(i).elevation;
  geoveg(i).mnorth = rrr(i).mnorth
  geoveg(i).meast = rrr(i).meast
  geoveg(i).melevation = rrr(i).melevation;
  geoveg(i).soe = rrr(i).soe;
  geoveg(i).fint = d(,i).mv1;
 // find actual ground surface elevation using simple trig (similar triangles)
  elvdiff = rrr(i).melevation - rrr(i).elevation;
  ndiff = rrr(i).mnorth - rrr(i).north;
  ediff = rrr(i).meast - rrr(i).east;

  eindx = where(d(,i).mx1 > 0 & d(,i).mx0 > 0);
  if (is_array(eindx)) {
   eratio = float(d(,i).mx0(eindx))/float(d(,i).mx1(eindx));
   geoveg(i).lelv(eindx) = int(rrr(i).melevation(eindx) - eratio * elvdiff(eindx));
   geoveg(i).lnorth(eindx) = int(rrr(i).mnorth(eindx) - eratio * ndiff(eindx));
   geoveg(i).least(eindx) = int(rrr(i).meast(eindx) - eratio * ediff(eindx));
  } else {
   geoveg(i).lelv = 0;
  }
  geoveg(i).lint = d(,i).mv0;
  geoveg(i).nx = d(,i).nx;

} /* end for loop */

   
//write,format="Processing complete. %d rasters drawn. %s", len, "\n"
return geoveg;
}

func make_veg(latutm=, q=, ext_bad_att=, ext_bad_veg=, use_centroid=, use_peak=, use_highelv_echo=, multi_peaks=) {
/* DOCUMENT make_veg(opath=,ofname=,ext_bad_att=, ext_bad_veg=)

 This function allows a user to define a region on the gga plot 
of flightlines (usually window 6) to  process data using the 
Vegetation algorithm.

Inputs are: 

 ext_bad_att  	Extract bad first return points (those points that 
                were termed 'bad' in the first surface return function) 
                and writes it out to an array.

 ext_bad_veg    Extract the points that failed to show any veg using 
                the run_veg function and write these points to an array 

Returns:
 veg_arr        This function returns the array veg_arr.

**Note:      
 Check to see if the tans and pnav data have been loaded before 
 executing make_veg.  See rbpnav() and rbtans() for details.

      See also: first_surface, run_veg, make_fs_veg 
*/
   
   extern edb, soe_day_start, tans, pnav, utm, veg_all, rn_arr, rn_arr_idx, ba_veg, bd_veg;
   veg_all = [];
   if (use_centroid == 1) {
           use_centroid = 0;
	   use_peak = 1;
   }

   if (use_peak) write, "Using peak of last return to find bare earth...";
   
   
   /* check to see if required parameters have been initialized */

   if (!is_array(tans)) {
     write, "TANS information not loaded.  Running function rbtans() ... \n";
     tans = rbtans();
     write, "\n";
   }
   write, "TANS information LOADED. \n";
   if (!is_array(pnav)) {
     write, "Precision Navigation (PNAV) data not loaded."+ 
            "Running function rbpnav() ... \n";
     pnav = rbpnav();
   }
   write, "PNAV information LOADED. \n"
   write, "\n";

   if (!is_array(q)) {
    /* select a region using function gga_win_sel in rbgga.i */
    q = gga_win_sel(2, latutm=latutm, llarr=llarr);
   }

  /* find start and stop raster numbers for all flightlines */
   rn_arr = sel_region(q);


  if (is_array(rn_arr)) {
     no_t = numberof(rn_arr(1,));

   /* initialize counter variables */
   tot_count = 0;
   ba_count = 0;
   bd_count = 0;
   fcount = 0;

    for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
       fcount ++;
       write, "Processing for first_surface...";
       if (use_peak) use_centroid = 1;
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=use_centroid, use_highelv_echo=use_highelv_echo); 
       if (use_peak) use_centroid = 0;
       write, format="Processing segment %d of %d for vegetation\n", i, no_t;
       if (!multi_peaks) {
         d = run_veg(start=rn_arr(1,i), stop=rn_arr(2,i),use_centroid=use_centroid,use_peak=use_peak);
         a=[];
         write, "Using make_fs_veg for vegetation...";
         veg = make_fs_veg(d,rrr);
         grow, veg_all, veg;
         tot_count += numberof(veg.elevation);
       } else {
         d = run_veg_all(start=rn_arr(1,i), stop=rn_arr(2,i),use_peak=use_peak);
 	 a = [];
	 write, "Using make_fs_veg_all (multiple peaks!) for vegetation..."
	 veg = make_fs_veg_all(d, rrr);
 	 grow, veg_all, veg;
 	 tot_count += numberof(veg.elevation);
	}
     }
    }

    /* if ext_bad_att is set, find all points having elevation = ht 
        of airplane 
    */
    if ((ext_bad_att==1) && (is_array(veg_all))) {
        write, "Extracting and writing false first points";
        /* compare veg.elevation within 20m of veg.melevation */
	elv_thresh = (veg_all.melevation-2000);
        ba_indx = where(veg_all.elevation > elv_thresh);
	ba_count += numberof(ba_indx);
	ba_veg = veg_all;
	deast = veg_all.east;
   	if ((is_array(ba_indx))) {
	  deast(ba_indx) = 0;
        }
	 dnorth = veg_all.north;
   	if ((is_array(ba_indx))) {
	 dnorth(ba_indx) = 0;
	}
	veg_all.east = deast;
	veg_all.north = dnorth;

	/* compute array for bad attitude (ba_veg) to write to a file */
	ba_indx_r = where(ba_veg.elevation < elv_thresh);
	bdeast = ba_veg.east;
   	if ((is_array(ba_indx_r))) {
	 bdeast(ba_indx_r) = 0;
 	}
	bdnorth = ba_veg.north;
   	if ((is_array(ba_indx_r))) {
	 bdnorth(ba_indx_r) = 0;
	}
	ba_veg.east = bdeast;
	ba_veg.north = bdnorth;

      } 

      /* if ext_bad_veg is set, find all points having veg = 0 
      */
      if ((ext_bad_veg==1) && (is_array(veg_all)))  {
        write, "Extracting false bald earth returns ";
        /* compare veg_all.lelv with 0 */
        bd_indx = where(veg_all.lelv == 0);
	bd_count += numberof(ba_indx);
	bd_veg = veg_all;
	deast = veg_all.east;
	deast(bd_indx) = 0;
	dnorth = veg_all.north;
	dnorth(bd_indx) = 0;

	/* compute array for bad veg (bd_veg) */
	bd_indx_r = where(bd_veg.lelv != 0);
        if (is_array(bd_indx_r)) {
	  bdeast = bd_veg.east;
	  bdeast(bd_indx_r) = 0;
	  bdnorth = bd_veg.north;
	  bdnorth(bd_indx_r) = 0;
	  bd_veg.east = bdeast;
	  bd_veg.north = bdnorth;
        }  

      } 


    write, "\nStatistics: \r";
    write, format="Total number of records processed = %d\n",tot_count;
    write, format="Total number of records with false first "+
                   "returns data = %d\n",ba_count;
    write, format = "Total number of records with false veg data = %d\n",
                    bd_count;
    write, format="Total number of GOOD data points = %d \n",
                   (tot_count-ba_count-bd_count);

    if ( tot_count != 0 ) {
       pba = float(ba_count)*100.0/tot_count;
       write, format = "%5.2f%% of the total records had "+
                       "false first returns! \n",pba;
    } else 
	write, "No good returns found"

    if ( ba_count > 0 ) {
      pbd = float(bd_count)*100.0/(tot_count-ba_count);
      write, format = "%5.2f%% of total records with good "+
                      "first returns had false veg data! \n",pbd; 
    } else 
	write, "No veg records found"
    no_append = 0;
    if (numberof(rn_arr)>2) {
      rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);	

      tkcmd, swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))
    }

    return veg_all;
  } else write, "No record numbers found for selected flightline."

}

func write_vegall (vegall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_vegall (vegall, opath=, ofname=, type=, append=) 

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure VEGALL to a binary file.  
 Input parameter vegall is an array of structure VEGALL, defined by the 
 make_fs_veg function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   vegall	Array of structure VEGALL as returned by function 
                make_fs_veg;

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file.

   append=	Set this keyword to append to existing file.


   See also: make_fs_veg, make_veg

*/

fn = opath+ofname;
num_rec=0;

if (is_void(append)) {
  /* open file to read/write if append keyword not 
    set(it will overwrite any previous file with same name) */
  f = open(fn, "w+b");
} else {
  /*open file to append to existing file.  Header information 
  will not be written.*/
  f = open(fn, "r+b");
}

if (is_void(append)) {
  /* write header information only if append keyword not set */
  if (is_void(type)) {
     if (vegall.soe(1) == 0) {
        type = 8
        nwpr = long(13);
     } else {
        type = 103;
        nwpr = long(14);
     }
  } else {
        nwpr = long(14);
  }

  rec = array(long, 4);
  /* the first word in the file will decide the endian system. */
  rec(1) = 0x0000ffff;
  /* the second word defines the type of output file */
  rec(2) = type;
  /* the third word defines the number of words in each record */
  rec(3) = nwpr;
  /* the fourth word will eventually contain the total number of records.  
     We don't know the value just now, so will wait till the end. */
  rec(4) = 0;

  _write, f, 0, rec;

  byt_pos = 16; /* 4bytes , 4words */
} else {
  byt_pos = sizeof(f);
}
num_rec = 0;

vegall = clean_veg(vegall);

/* now look through the vegall array of structures and write 
 out only valid points 
*/
len = numberof(vegall);

for (i=1;i<=len;i++) {
  indx = where(vegall(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, vegall(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).mnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).meast(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).melevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).lnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).least(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).lelv(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, vegall(i).fint(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, vegall(i).lint(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, vegall(i).nx(indx(j));
     byt_pos = byt_pos + 1;
     if (type == 103) {
      _write, f, byt_pos, vegall(i).soe(indx(j));
      byt_pos = byt_pos + 8;
     }
     if ((i%1000)==0) write, format="%d of %d\r", i, len;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element 
  of the header array 
*/
if (is_void(append)) {
  _write, f, 12, num_rec;
  write, format="Number of records written = %d \n", num_rec
} else {
  num_rec_old = 0L
  _read, f, 12, num_rec_old;
  num_rec = num_rec + num_rec_old;
  write, format="Number of old records = %d \n",num_rec_old;
  write, format="Number of new records = %d \n",(num_rec-num_rec_old);
  write, format="Total number of records written = %d \n",num_rec;
  _write, f, 12, num_rec;
}

close, f;
}

func write_veg(opath, ofname, veg_all, ba_veg=, bd_veg=) {
  /* DOCUMENT write_veg(opath, ofname, veg_all, ba_veg=, bd_veg=)
    This function writes bathy data to a file.
    amar nayegandhi 10/17/02.
  */
  if (is_array(ba_veg)) {
	ba_ofname_arr = strtok(ofname, ".");
	ba_ofname = ba_ofname_arr(1)+"_bad_fr."+ba_ofname_arr(2);
	write, format="Writing array ba_veg to file: %s\n", ba_ofname;
        write_geoall, ba_veg, opath=opath, ofname=ba_ofname;
  }

  if (is_array(bd_veg)) {
	bd_ofname_arr = strtok(ofname, ".");
	bd_ofname = bd_ofname_arr(1)+"_bad_veg."+bd_ofname_arr(2);
	write, "now writing array bad_veg  to a file \r";
        write_geoall, bd_veg, opath=opath, ofname=bd_ofname;
  }


  write_vegall, veg_all, opath=opath, ofname=ofname;

}


func test_veg(veg_all,  fname=, pse=, graph=) {
  // this function can be used to process for vegetation for only those pulses that are in data array veg_all or  those that are in file fname.
  // amar nayegandhi 11/27/02.

  if (fname) {
    ofn = split_path(fname,0);
    data_ptr = read_yfile(ofn(1), fname_arr = ofn(2));
    veg_all = *data_ptr(1);
  } 

  rasternos = veg_all.rn;
   

  rasters = rasternos & 0xffffff;
  pulses = rasternos / 0xffffff;
  tot_count = 0;

  for (i = 1; i <= numberof(rasters); i++) {
    depth = ex_veg(rasters(i), pulses(i),last=250, graph=graph, use_peak=1, pse=pse)    
    if (veg_all(i).rn == depth.rastpix) {
      if (depth.mx1 == -10) {
       veg_all(i).felv = -10;
       write, format="yo! rn=%d; i=%d\n",rasters(i), pulses(i);
      } else {
        veg_all(i).felv = depth.mx1*NS2MAIR*100;
      }
      veg_all(i).fint = depth.mv1;
      if (depth.mx0 == -10) {
       veg_all(i).lelv = -10;
       //write, format="lyo! rn=%d; i=%d\n",rasters(i), pulses(i);
      } else {
        veg_all(i).lelv = depth.mx0*NS2MAIR*100;
      }
      veg_all(i).lint = depth.mv0;
      veg_all(i).nx = depth.nx;
    } else {
     write, "ooooooooops!!!"
    }
  }


  return veg_all

}

func clean_veg(veg_all, rcf_width=, type=) {
  /* DOCUMENT clean_veg(veg_all, rcf_width=)
   this function cleans the veg_all array
   amar nayegandhi 12/20/02
   Input: veg_all    Initial data array of structure VEG__ or VEG_ALL_
          rcf_width  The elevation width (m) to be used for the RCF 
                     filter.  If not set, rcf is not used.

	  type=      3 = structure VEG__.
	  	     5 = strucutre VEG_.

   Output: Cleaned data array of type VEG_ or VEG__
   modified AN 3/8/03 to add rcf_width= option and other changes
   modified AN 3/14/03 to make this function work for data of old type
  */

  if (!type) type = 3;
  if (numberof(veg_all) != numberof(veg_all.north)) {
      if (type == 3) {
       // convert VEG_ALL_ to VEG__
       write, "converting raster structure (VEG_ALL_) to point structure (VEG__)";
       veg_all = veg_all__to_veg__(veg_all);
      }
      if (type == 5) {
        // convert VEG_ALL to VEG_
        write, "converting raster structure (VEG_ALL) to point structure (VEG_)";
       veg_all = veg_all_to_veg_(veg_all);
      }
  }
  
  write, "cleaning data...";

  // remove pts that had bare earth elevations assigned to 0
  indx = where(veg_all.lelv != 0);
  if (is_array(indx)) {
    veg_all = veg_all(indx);
  } else {
    veg_all = [];
    return veg_all
  }

  // remove pts that had north and lnorth values assigned to 0
  indx = where(veg_all.north != 0);
  if (is_array(indx)) {
     veg_all = veg_all(indx);
  } else {
      veg_all = [];
      return veg_all
  }

  if (type == 3) {
   indx = where(veg_all.lnorth != 0);
   if (is_array(indx)) {
     veg_all = veg_all(indx);
   } else {
      veg_all = [];
      return veg_all
   }
  }

  // remove points that have been assigned mirror elevation values
  indx = where(veg_all.elevation < (0.75*veg_all.melevation))
  if (is_array(indx)) {
    veg_all = veg_all(indx);
  } else {
    veg_all = [];
    return veg_all
  }

  if (is_array(rcf_width)) {
    write, "using rcf filter to clean veg data..."
    //run rcf on the entire data set
    ptr = rcf(veg_all.elevation, rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
        veg_all = veg_all(*ptr(1));
    } else {
        veg_all = [];
    }
  }


  write, "cleaning completed";
  return veg_all
}



func ex_veg_all( rn, i,  last=, graph=, use_centroid=, use_peak=, pse= ) {
/* DOCUMENT ex_veg(raster_number, pulse_index)


 see run_veg 


 This function returns an array of VEGPIX structures. 

	[ rp.sa(i), mx, a(mx,i,1) ];
 
*/

/*
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
    da                The return waveform with the computed exponentials substracted
*/

  extern ex_bath_rn, ex_bath_rp, a
  irange = a(where(rn==a.raster)).irange(i);
  //irange=0;
  //intensity = a(where(rn==a.raster)).intensity(i);
  rv = VEGPIXS();			// setup the return struct
  rv.rastpix = rn + (i<<24);
  if (irange < 1) return rv;
  if ( is_void( ex_bath_rn )) 
	ex_bath_rn = -1;

  if ( is_void(aa) )
    aa  = array(float, 256, 120, 4);

  if ( ex_bath_rn != rn ) {  // simple cache for raster data
    r = get_erast( rn= rn );
    rp = decode_raster( r );
    ex_bath_rn = rn;
    ex_bath_rp = rp;
  } else {
   rp = ex_bath_rp;
  }

  ctx = cent(*rp.tx(i));

  n  = numberof(*rp.rx(i, 1)); 
  rv.sa = rp.sa(i);
  if ( n == 0 ) 
	return rv;

  w  = *rp.rx(i, 1);  aa(1:n, i) = float( (~w+1) - (~w(1)+1) );

 if (!(use_centroid) && !(use_peak)) {
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
   } else { // surface not saturated
          wflen = numberof(w);
          if ( wflen > 12 ) wflen = 12;
	  last_surface_sat =  w(1:wflen) (mnx) ;
          escale = 255 - w(1:wflen) (min);
   }

 }

  da = aa(1:n,i,1);
  dd = aa(1:n, i, 1) (dif);

/******************************************
   xr(1) will be the first pulse edge
   and xr(0) will be the last
*******************************************/
  thresh = 4.0
//  xr = where( dd  > thresh ) ;	// find the hits
  xr = where(  ((dd >= thresh) (dif)) == 1 ) 	//
  nxr = numberof(xr);

  if ( graph ) {
    window,4; fma;limits
    plmk, aa(1:n,i,1), msize=.2, marker=1, color="black";
    plg, aa(1:n,i,1);
    plmk, da, msize=.2, marker=1, color="black";
    plg, da;
    plg, dd-100, color="red"
    write, format="rn=%d; i = %d\n",rn,i
    ///if ( nxr > 0 ) 
    ///	plmk, a( xr(0),i,1), xr(0),msize=.3,marker=3
  }

  if ( is_void(last) ) 		// see if user specified the max veg
	last = n;

  if ( n > last ) 		
	n = last;


  rv.nx = nxr;
  if (nxr > 10) nxr = 10; //maximum number of peaks is limited to 10
  for (j=1;j<=nxr;j++) {
    if (use_centroid || use_peak) {
       //assume 12ns to be the longest duration for a complete return
       retdist = 12;
       ai = 1; //channel number
       if (xr(j)+retdist+1 > n) retdist = n - xr(j)-1;


     /* //not checking for saturation as of now!!
       // check for saturation
       if ( numberof(where((w(xr(i):xr(i)+retdist)) == 0 )) >= 2 ) {
           // goto second channel
            ai = 2;
           // write, format="trying channel 2, rn = %d, i = %d\n",rn, i
            w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
            da = aa(1:n,i,ai);
            dd = aa(1:n, i, ai) (dif);
            if ( numberof(where((w(xr(i):xr(i)+retdist)) == 0 )) >= 2 ) {
              // goto third channel
            //  write, format="trying channel 3, rn = %d, i = %d\n",rn, i
              ai = 3;
              w  = *rp.rx(i, ai);  aa(1:n, i,ai) = float( (~w+1) - (~w(1)+1) );
              da = aa(1:n,i,ai);
              dd = aa(1:n, i, ai) (dif);
              if ( numberof(where((w(xr(0):xr(0)+retdist)) == 0 )) >= 2 ) {
                 write, format="all 3 channels saturated... giving up!, rn=%d, i=%d\n",rn,i
                 ai = 0;
              }
	    }
           
            if ( numberof(where((w(xr(i):xr(i)+retdist)) == 0 )) >= 2 ) {
                 write, format="all 3 channels saturated... giving up!, rn=%d, i=%d\n",rn,i
                 ai = 0;
            }
	}
      */

       //if ( numberof(where((w(xr(j):xr(j)+retdist)) == 0 )) >= 2 ) {
 //		write, format="Channel 1 saturated for this peak, rn = %d, i = %d\n", rn, i;
  //	        ai = 0;
   //    }

       if (retdist < 5) ai = 0; // this eliminates possible noise pulses.

       if (ai > 0) {
         //write, format="ai = %d\n", ai;
         
         if (pse) pause, pse;

         if ( graph && ai >= 2) {
         //window,4; fma
         plmk, aa(1:n,i,ai), msize=.2, marker=1, color="yellow";
         plg, aa(1:n,i,ai), color="yellow";
         plmk, da, msize=.2, marker=1, color="yellow";
         plg, da, color="yellow";
         plg, dd-100, color="blue"
	 pltit = swrite(format="ai = %d\n", ai);
	 pltitle, pltit;
         }
       
       /*
        if (use_centroid && !use_peak) {

      
       // find where the bottom return pulse changes direction after its trailing edge
       idx = where(dd(xr(0)+1:xr(0)+retdist) > 0);
       idx1 = where(dd(xr(0)+1:xr(0)+retdist) < 0);
       if (is_array(idx1) && is_array(idx)) {
        if (idx(0) > idx1(1)) {
         //take length of  return at this point
	 //write, format="this happens!! rn = %d; i = %d\n",rn,i;
         retdist = idx(0);
        }
       } else 
       write, format="idx/idx1 is nuller for rn=%d, i=%d    \r",rn, i  
       //now check to see if it it passes intensity test
       mxmint = aa(xr(0)+1:xr(0)+retdist,i,ai)(max);
       if (abs(aa(xr(0)+1,i,ai) - aa(xr(0)+retdist,i,ai)) < 0.2*mxmint) {
           // this return is good to compute centroid
           b = aa(int(xr(0)+1):int(xr(0)+retdist),i,ai); // create array b for retdist returns beyond the last peak leading edge.
           //compute centroid
          if (b(sum) != 0) {
           c = float(b*indgen(1:retdist)) (sum) / (b(sum));
           mx0 = xr(0)+c;
           if (ai == 1) mv0 = aa(int(mx0),i,ai);
           if (ai == 2) {
	       mx0 = mx0 + 0.36;
	       mv0 = aa(int(mx0),i,ai)+300;
	   }
           if (ai == 3) {
	       mx0 = mx0 + 0.23;
	       mv0 = aa(int(mx0),i,ai)+600;
	   }
          } else {
           mx0 = -10;
           mv0 = -10;
          }
       } else {
          // for now, discard this pulse
          mx0 = -10;
          mv0 = -10;
       } 
    }
    */
    
    if (!use_centroid && use_peak) {
       // if within 3 ns from xr(j) we find a peak, we can assume this to be noise related and try again using xr(j) from the first positive difference after the last negative difference.
       nidx = where(dd(xr(j):xr(j)+3) < 0);
       if (is_array(nidx)) {
         xr(j) = xr(j) + nidx(1);
	 if (xr(j)+retdist+1 > n) retdist = n - xr(j)-1;
       }
       // find where the bottom return pulse changes direction after its trailing edge
       idx = where(dd(xr(j)+1:xr(j)+retdist) > 0);
       idx1 = where(dd(xr(j)+1:xr(j)+retdist) < 0);
       if (is_array(idx1) && is_array(idx)) {
        //write, idx;
        //write, idx1;
        if (idx(0) > idx1(1)) {
         //take length of  return at this point
	 //write, format="this happens!! rn = %d; i = %d\n",rn,i;
         retdist = idx(0);
        }
       }
       if (is_array(idx1)) {
	ftrail = idx1(1);
	ltrail = retdist;
	//halftrail = 0.5*(ltrail - ftrail);
	mx = irange+xr(j)+idx1(1)-ctx(1);
	mv = aa(int(xr(j)+idx1(1)),i,ai);
        if ( graph ) {
         plmk, mv, xr(j)+idx1(1), msize=.5, marker=7, color="blue", width=1
        }
       } else {
       mx = -1000;
       mv = -1000; 
       }
    }

    } else {
       write, format="because ai = 0 for %d\n",j
       mx = -1000;
       mv = -1000;
    }
   } else { //donot use centroid or trailing edge
      mx = irange+aa( xr(j):xr(j)+5, i, 1)(mxx) + xr(0) - 1;	  // find bottom peak now
      mv = aa( mx(j), i, 1);	          
   }


    if (pse) pause, pse;
    rv.mx(j) = mx;
    rv.mv(j) = mv;
  }
 return rv
}

func run_veg_all( rn=, len=, start=, stop=, center=, delta=, last=, graph=, pse=, use_centroid=,use_peak= ) {
// depths = array(float, 3, 120, len );
  if (is_void(graph)) graph=0;

 if ( is_void(rn) || is_void(len) ) {
    if (!is_void(center) && !is_void(delta)) {
       rn = center - delta;
       len = 2 * delta;
    } else if (!is_void(start) && !is_void(stop)) {
             rn = start-1;
	     len = stop - start+1;
    } else {
	     write, "Input parameters not correctly defined.  See help, run_veg.  Please start again.";
	     return 0;
    }
 }


     
   
 depths = array(VEGPIXS, 120, len );
  if ( _ytk ) {
    tkcmd,"destroy .veg; toplevel .veg; set progress 0;"
    tkcmd,swrite(format="ProgressBar .veg.pb \
	-fg yellow \
	-troughcolor blue \
	-relief raised \
	-maximum %d \
	-variable progress \
	-height 30 \
	-width 400", len );
    tkcmd,"pack .veg.pb; update; center_win .veg;"
  }
 if ( graph != 0 ) 
	animate,1;

 if ( is_void(last) ) 
	last = 255;
 if ( is_void(graph) ) 
	graph = 0;
   for ( j=1; j<= len; j++ ) {
     if (_ytk) 
       tkcmd, swrite(format="set progress %d", j)
     else {
     if ( (j % 10)  == 0 ) 
        write, format="   %d of %d   \r", j,  len
     }
     for (i=1; i<=120; i++ ) {
       depths(i,j) = ex_veg_all( rn+j, i, last = last, graph=graph, use_centroid=use_centroid,use_peak=use_peak);
       if ( !is_void(pse) ) 
	  pause, pse;
     }
   }
 if ( graph != 0 ) 
	animate,0;
 if (_ytk) {
   tkcmd, "destroy .veg"
   } else write, "\n"; 
  return depths;
}

func make_fs_veg_all (d, rrr) {  
/* DOCUMENT make_fs_veg_all (d, rrr) 

   This function makes a veg data array using the 
   georectification of the first surface return.  The parameters are as 
   follows:

 d		Array of structure VEGPIX  containing veg information.  
                This is the return value of function run_bath.

 rrr		Array of structure R containing first surface information.  
                This the is the return value of function first_surface.


   The return value veg is an array of structure VEGALL. The array 
   can be written to a file using write_geoall  

   See also: first_surface, run_veg, write_vegall
*/


// d is the veg array from veg.i
// rrr is the topo array from surface_topo.i

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

geoveg = array(CVEG_ALL, len*120*10);

ccount = 0;
for (i=1; i<=len; i++) {
  elvdiff = rrr(i).melevation - rrr(i).elevation;
  ndiff = rrr(i).mnorth - rrr(i).north;
  ediff = rrr(i).meast - rrr(i).east;
  for (j=1; j<=120; j++) {
   mindx = where(d(j,i).mx > 0);
   if (is_array(mindx)) {
    for (k=1;k<=numberof(mindx);k++) {
      ccount++;
      geoveg.rn(ccount) = rrr(i).rn(j);
      geoveg.mnorth(ccount) = rrr(i).mnorth(j);
      geoveg.meast(ccount) = rrr(i).meast(j);
      geoveg.melevation(ccount) = rrr(i).melevation(j);
      geoveg.soe(ccount) = rrr(i).soe(j);
      geoveg.nx(ccount) = char(k);
      // find actual ground surface elevation using simple trig (similar triangles)

      if ((d(j,i).mx(1) > 0) && (rrr(i).melevation(j) > 0)) {
       eratio = float(d(j,i).mx(k))/float(d(j,i).mx(1));
       geoveg.elevation(ccount) = int(rrr(i).melevation(j) - eratio * elvdiff(j));
       geoveg.north(ccount) = int(rrr(i).mnorth(j) - eratio * ndiff(j));
       geoveg.east(ccount) = int(rrr(i).meast(j) - eratio * ediff(j));
       geoveg.intensity(ccount) = d(j,i).mv(k);
      } 
    }
   }
  }

} /* end for loop */

geoveg = geoveg(1:ccount);
   
//write,format="Processing complete. %d rasters drawn. %s", len, "\n"
return geoveg;
}

func write_multipeak_veg (vegall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_vegall (vegall, opath=, ofname=, type=, append=) 

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure CVEG_ALL to a binary file.  
 Input parameter vegall is an array of structure CVEG_ALL, defined by the 
 make_fs_veg function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   vegall	Array of structure CVEG_ALL as returned by function 
                make_veg with multipeaks keyword set;

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file, currently type = 7 is supported 
                for multipeaks veg data.

   append=	Set this keyword to append to existing file.


   See also: make_veg, make_fs_veg_all, run_veg_all, ex_veg_all

*/

fn = opath+ofname;
num_rec=0;

if (is_void(append)) {
  /* open file to read/write if append keyword not set(it will overwrite any previous file with same name) */
  f = open(fn, "w+b");
} else {
  /*open file to append to existing file.  Header information will not be written.*/
  f = open(fn, "r+b");
}

if (is_void(append)) {
  /* write header information only if append keyword not set */
  if (is_void(type)) {
      if (vegall.soe(1) == 0) {
         type = 7;
         nwpr = long(9);
      } else {
         type = 104;
 	 nwpr = long(10);
      }
  } else {
	nwpr = 10;
  }

  rec = array(long, 4);
  /* the first word in the file will decide the endian system. */
  rec(1) = 0x0000ffff;
  /* the second word defines the type of output file */
  rec(2) = type;
  /* the third word defines the number of words in each record */
  rec(3) = nwpr;
  /* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
  rec(4) = 0;

  _write, f, 0, rec;

  byt_pos = 16; /* 4bytes , 4words */
} else {
  byt_pos = sizeof(f);
}
num_rec = 0;


/* now look through the vegall array of structures and write 
 out only valid points 
*/

/* call function clean_cveg_all to remove erroneous data. */
write, "Cleaning data ... ";
vegall = clean_cveg_all(vegall);
write, "Writing data to file... ";
len = numberof(vegall);

for (i=1;i<=len;i++) {
   _write, f, byt_pos, vegall(i).rn;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).north;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).east;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).elevation;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).mnorth;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).meast;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).melevation;
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, vegall(i).intensity;
   byt_pos = byt_pos + 2;
   _write, f, byt_pos, vegall(i).nx;
   byt_pos = byt_pos + 1;
   if (type == 104) {
    _write, f, byt_pos, vegall(i).soe;
    byt_pos = byt_pos + 8;
   }
   if ((i%1000)==0) write, format="%d of %d\r", i, len;

   num_rec++;
}

/* now we can write the number of records in the 3rd element 
  of the header array 
*/
if (is_void(append)) {
  _write, f, 12, num_rec;
  write, format="Number of records written = %d \n", num_rec
} else {
  num_rec_old = 0L
  _read, f, 12, num_rec_old;
  num_rec = num_rec + num_rec_old;
  write, format="Number of old records = %d \n",num_rec_old;
  write, format="Number of new records = %d \n",(num_rec-num_rec_old);
  write, format="Total number of records written = %d \n",num_rec;
  _write, f, 12, num_rec;
}

close, f;
}

func clean_cveg_all(vegall, rcf_width=) {
  /* DOCUMENT clean_cveg_all(vegall)
     This function cleans the multi-peak veg data.  
     Input: vegall:  data array (with structure CVEG_ALL)
     Output: cleaned data array (with structure CVEG_ALL)
     Original Author: amar nayegandhi 02/12/03.
  */

  new_vegall = vegall;

  indx = where(new_vegall.north != 0);

  if (is_array(indx)) 
    new_vegall = new_vegall(indx);

  indx = where(new_vegall.elevation < 0.75*new_vegall.melevation);
  if (is_array(indx))
    new_vegall = new_vegall(indx);

  indx = where(new_vegall.elevation > -100000); // assuming that no elevation will be lower than 1000m

  if (is_array(indx)) 
    new_vegall = new_vegall(indx);

  if (rcf_width) {
    ptr = rcf(new_vegall.elevation, rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
	new_vegall = new_vegall(*ptr(1));
    } else {
        new_vegall = 0
    }
  }

  return new_vegall;
}
  
func hist_veg( veg_all, binsize=, win=, dofma=, color=, normalize=, lst=, width=, multi=, type= ) {
/* DOCUMENT hist_veg(fs)

   Return the histogram of the good elevations in veg.  The input veg elevation
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs: 
	veg_all		An array of "VEG_ALL_" or "CVEG_ALL" structures.  
	binsize=	Binsize in centimeters from 1.0 to 200.0  
	win=		Defaults to 0.
	dofma=		Defaults to 1 (Yes), Set to zero if you don't want 
                        an fma.
	color=		Set graph color
	width=		Set line width
	normalize=	Defaults to 0 (not normalized),  Set to 1  to cause 
                        it to normalize to one.  This is very useful in case 
                        you are plotting multiple histograms where you actually 
                        want to compare their peak value.
        lst=            An optional externally generated "where" filter list.
        multi=		Set to 1 if using Multipeak vegetation algorithm
	type = 		Set to 1 for First Return Topography only
			       2 for Bare Earth Topography only (only when 
                                 multi = 0)
			       3 for considering all returns 
	

  Outputs:
	A histogram graphic in Window 0

  Returns:
	An 2xn array of x values and counts found at those values.

 Orginal: Amar Nayegandhi 02/20/03.  Adapted from hist_fs by WW.

See also: VEG_ALL_, CVEG_ALL
*/

  if ( is_void(binsize))
	binsize = 100.0;

  if ( is_void(win) ) 
	win = 0;
  if (numberof(where(veg_all.north == 0)) > 0) {
      if (multi == 1) 
	veg_all = clean_cveg_all(veg_all);
  }
  if (!type) type = 2;

  if ( is_void(lst)) {
     if (type == 1) {
      if (multi == 0) {
       lst = where(veg_all.elevation);
      } else {
       lst = where(veg_all.nx == 1)
       if (is_array(lst)) {
         ilst = where(veg_all.elevation(lst))
         if (is_array(ilst))
          lst = lst(ilst);
       }
      }
      elev = veg_all.elevation(lst);
     }
     if (type == 2) {
	lst = where(veg_all.lelv);
        elev = veg_all.lelv(lst);
     }
     if (type == 3) {
      if (multi == 0) {
	lst = where(veg_all.elevation);
        if (is_array(lst)) {
	  ilst = where(veg_all.lelv(lst));
          if (is_array(ilst))
            lst = lst(ilst);
 	}
      } else lst = where(veg_all.elevation);
      elev = veg_all.elevation(lst);
    }
  } else {
      elev = veg_all.elevation(lst);
  }

 if (multi == 0) {
  // clean the array only if multi = 0.  
  melev = veg_all.melevation(lst);
  // build an edit array indicating where values are between -60 meters
  // and 3000 meters.  Thats enough to encompass any EAARL data than
  // can ever be taken.
  gidx = (elev > -6000) | (elev <300000);  

  // Now kick out values which are within 1-meter of the mirror. Some
  // functions will set the elevation to the mirror value if they cant
  // process it.
  gidx &= (elev < (melev-1));


  // Now generate a list of where the good values are.
  q = where( gidx )
  elev = elev(q);
 }
  

 // now find the minimum 
 minn = elev(min);
 maxx = elev(max);

 fsy = elev - minn ;

 minn /= 100.0
 maxx /= 100.0


 // make a histogram of the data indexed by q.
 h = histogram( (fsy / int(binsize)) + 1 );
 zero_list = where( h == 0 ) 
 if ( numberof(h) < 2 ) {
   h = [1,h(1),1];   
 }
 if ( numberof(zero_list) )
 	h( zero_list ) = 1;
  e = span( minn, maxx, numberof(h) )  ; 
  w = window();
  window,win; 
  if ( dofma ) 
  	fma; 
  if ( normalize ) {
	h = float(h-1);
        if ((h(max)) > 0) {
	  h = h/(h(max));
        } else {
          h = [0];
        }
        
  	plg,h,e, color=color, width=width;
  	plmk, h, e, marker=4, msize=0.4, width=10, color="red";
   } else {
        h = h-1
  	plg,h,e, color=color, width=width;
  	plmk, h, e, marker=4, msize=0.4, width=10, color="red";
   }
  pltitle, swrite( format="Elevation Histogram %s", data_path);
  xytitles,"Elevation (meters)", "Number of measurements"
  //limits
  hst = [e,h];
  window, win; limits,,,,hst(max,2) * 1.5
  window, w;
  return hst;
}

func veg_all__to_veg__(data) {
/* DOCUMENT veg_all__to_veg__(data)
      This function converts the data array from the raster structure 
      (VEG_ALL_) to the VEG__ structure in point format.
      amar nayegandhi
     03/08/03
   */

 if (numberof(data) != numberof(data.north)) {
                    data_new = array(VEG__, numberof(data)*120);
                        indx = where(data.rn >= 0);
                 data_new.rn = data.rn(indx);
              data_new.north = data.north(indx);
               data_new.east = data.east(indx);
          data_new.elevation = data.elevation(indx);
             data_new.mnorth = data.mnorth(indx);
              data_new.meast = data.meast(indx);
         data_new.melevation = data.melevation(indx);
             data_new.lnorth = data.lnorth(indx);
              data_new.least = data.least(indx);
               data_new.lelv = data.lelv(indx);
               data_new.fint = data.fint(indx);
               data_new.lint = data.lint(indx);
                 data_new.nx = data.nx(indx);
                data_new.soe = data.soe(indx);
  } else data_new = data;

  return data_new
}

func veg_all_to_veg_(data) {
/* DOCUMENT veg_all_to_veg_(data)
      this function converts the data array from the raster structure (VEG_ALL) 
      to the VEG_ structure in point format. Note this structure is of the OLD 
      format.

      amar nayegandhi 03/14/03
   */

 if (numberof(data) != numberof(data.north)) {
                    data_new = array(VEG_, numberof(data)*120);
                        indx = where(data.rn >= 0);
                 data_new.rn = data.rn(indx);
              data_new.north = data.north(indx);
               data_new.east = data.east(indx);
          data_new.elevation = data.elevation(indx);
             data_new.mnorth = data.mnorth(indx);
              data_new.meast = data.meast(indx);
         data_new.melevation = data.melevation(indx);
             data_new.felv = data.felv(indx);
              data_new.fint = data.fint(indx);
               data_new.lelv = data.lelv(indx);
               data_new.lint = data.lint(indx);
                 data_new.nx = data.nx(indx);
                data_new.soe = data.soe(indx);
  } else data_new = data;

  return data_new
}

