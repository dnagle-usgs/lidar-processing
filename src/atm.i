#include "plcm.i"
#include "sel_file.i"

/*
    atm.i	C. W. Wright 
 $Id$
		http://lidar.wff.nasa.gov

    Yorick functions to display atm data.
*/


func load {
/* DOCUMENT load
*/
 extern fn, f, lat,lon, ilat,ilon, iz, z
 fn = sel_file(ss="*.pbd") (1)			// select the data file
 f = openb(fn);					// open selected file
 show,f						// display vars in file
 restore,f					// load the data to ram
 write,format="%s loaded %d points\n", fn, numberof(ilat);
 lat = ilat / 1.0e6;				// make a floating pt lat
 lon = ilon / 1.0e6 - 360.0;			// make fp lon 
}

func show_all( sz=)  {
/* DOCUMENT show_all

   Display an entire atm data file as sequencial images false color
   coded elevation maps.

 */
b = 1				// starting record number
inc = 50000			// number to adjust start pt by
n = 50000			// number of points to display/image 
// animate,1			// uncomment to only see completed images
 if ( is_void(sz) ) 		// if sz not set, use 0.001 for default
        sz = 0.001;
 for (b = 1; b< numberof(lat)-inc-1; b+= inc ) {	// loop thru file
  fma; 							// advance display frame
  write,format="%8d %8.4f %8.4f\n", b, lat(b), lon(b)	// print some stuff
  plcm,iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=-41000, cmax=-30000, marker=1,msize=1.0 
//  plcm,ipz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=0, cmax=1000, shape=1, sz=sz
 }
// animate,0			// uncoment if animate,1 above is used
}


func show_frame (b, n, cmin=, cmax=, marker=, msize= ){
/* DOCUMENT show_all

    display a single atm display frame
 */
  if ( is_void( cmin) )
        cmin = -42000;
  if ( is_void(cmax) ) 
        cmax = -22000;
  if ( is_void( sz ) )
        sz = 0.0015
  if ( is_void(msize) )
        msize = 1.0;
  fma; 
  write,format="%8d %8.4f %8.4f\n", b, lat(b), lon(b)
  plcm,iz(b:b+n), lat(b:b+n), lon(b:b+n), cmin=cmin, cmax=cmax, marker=1,msize=msize
}


