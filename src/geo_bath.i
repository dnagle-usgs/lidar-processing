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
  long raster(120); 	//contains raster number
  long north(120);	//northing value
  long east(120); 	//easting value
  short depth(120);	//water depth in meters
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);	//scan angle
};

func display_bath (d, rrr, cmin =, cmax=, size=, win=, correct= ) {

//need to define geobath array
// d is the depth array from bathy.i
// rrr is the topo array from surface_topo.i
if ( is_void(win) )
        win = 5;
 if ( is_void( cmin )) cmin = -15;
 if ( is_void( cmax )) cmax = 0;
 if ( is_void( size )) size = 1.4;

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

geodepth = array(GEOBATH, len);

for (i=1; i<=len; i=i+1) {
  geodepth(i).raster = rrr(i).raster;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
  geodepth(i).depth = -d(,i).idx * CNSH2O2X
  geodepth(i).sa = d(,i).sa
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  if (correct == 1) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -4000); 
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
       }

     indx = where(rrr(i).elevation > -2000);
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
       }
  }   
}

j = len;
for ( i=1; i<j; i++ ) {
  plcm, geodepth(i).depth, geodepth(i).north/100, geodepth(i).east/100,
        msize=size,cmin=cmin, cmax=cmax;
  }

write,format="Draw complete. %d rasters drawn. %s", j-i, "\n"
return geodepth;
}

func write_geobath (geodepth, opath=, ofname=, type=) {

//this function writes a binary file containing georeferenced bathymetric data.
// input parameter geodepth is an array of structure GEOBATH, defined by the display_bath function.
// amar nayegandhi 02/15/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

nwpr = long(4);

if (is_void(type)) type = 1;

rec = array(long, 6);
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
num_rec = 0;


/* now look through the geodepth array of structures and write out only valid points */
len = numberof(geodepth);

for (i=1;i<=len;i++) {
  indx = where(geodepth(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geodepth(i).raster(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).depth(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}
