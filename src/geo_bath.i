/*
   $Id$
*/
write, "$Id$"
require, "surface_topo.i"
require, "bathy.i"
require, "eaarl_constants.i"

/* 
  This program is used to display a bathymetric image using the 
  topographic georectification.
*/

/*
 Define struct GEOBATH to contain the georectification of topo image
 and pixel value of using bathy.i
*/

struct GEOBATH {
  int raster(120); 	//contains raster number
  double north(120);	//northing value
  double east(120); 	//easting value
  short idx(120);	//bottom index
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);	//scan angle
};

func display_bath (d, rrr, cmin =, cmax=, size=, win=, correct= ) {

//need to define geobath array
// d is the depth array from bathy.i
// rrr is the topo array from surface_topo.i
if ( is_void(win) )
        win = 5;
 if ( is_void( cmin )) cmin = -1;
 if ( is_void( cmax )) cmax = 251;
 if ( is_void( size )) size = 1.4;

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

geodepth = array(GEOBATH, len);

for (i=1; i<=len; i=i+1) {
  geodepth(i).raster = rrr(i).raster;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
  geodepth(i).idx = -d(,i).idx * CNSH2O2X
  geodepth(i).sa = d(,i).sa
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  if (correct == 1) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -40.0); 
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
       }

     indx = where(rrr(i).elevation > -20.0);
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
       }
  }   
}

j = len;
for ( i=1; i<j; i++ ) {
  plcm, geodepth(i).idx, geodepth(i).north, geodepth(i).east,
        msize=size,cmin=cmin, cmax=cmax;
  }

write,format="Draw complete. %d rasters drawn. %s", j-i, "\n"
return geodepth;
}

