/*
   $Id$
*/
write, "$Id$"
require, "surface_topo.i"
require, "bathy.i"
require, "eaarl_constants.i"
require, "colorbar.i"

/* 
  This program is used to display a bathymetric image using the 
  topographic georectification.
*/

/*
 Define struct GEODEPTH & GEOBATH to contain the georectification of topo image
 and pixel value of using bathy.i
*/

struct GEODEPTH {
  long raster(120); 	//contains raster number
  long north(120);	//northing value
  long east(120); 	//easting value
  short depth(120);	//water depth in centimeters
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);	//scan angle
};

struct GEOBATH {
  long raster(120);     //contains raster number
  long north(120);      //northing value
  long east(120);       //easting value
  long bath(120);     //water bathymetry in centimeters
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);        //scan angle
};
func display_bath (d, rrr, cmin =, cmax=, size=, win=, correct=, bathy=, bcmin=, bcmax= ) {
/* DOCUMENT display_bath (d, rrr, cmin =, cmax=, size=, win=, correct=, bathy=, bcmin=, bcmax= ) 

   This function displays a depth or bathymetric image using the georectification of the first surface return.  The parameters are as follows:
   d = array of structure BATHPIX  containing depth information.  This is the return value of function run_bath.
   rrr = array of structure R containing first surface information.  This the is the return value of function first_surface.
   cmin = Deepest point in meters (default is -5m)
   cmax = Highest point in meters (default is 0m)
   size = Screen size of each point.  
   win =  graphics window to be used for plotting image (default is window 5).
   correct = set this keyword if you would like to correct the image to exclude points with incorrect first surface returns.  Highly recommended.
   bathy = set this keyword for producing bathymetric image.  Default produces depth image.
   bcmin = Deepest point in meters for bathymetric image (default is calculated by function).
   bcmax = Highest point in meters for bathymetric image (default is calculated by function).

   The return value depth is an array of structure; if bathy=1, it returns an array of structure GEOBATH, else it returns array of structure GEODEPTH.  This returned array can be written out to a file using function write_geobath.

   see also: first_surface, run_bath, write_geobath
   */


//need to define geodepth array
// d is the depth array from bathy.i
// rrr is the topo array from surface_topo.i
if ( is_void(win) )
        win = 5;
window, win
if ( is_void( cmin )) cmin = -5;
if ( is_void( cmax )) cmax = 0;
if ( is_void( size )) size = 1.4;
bmin = 10000;
bmax = -10000;

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

if (is_void(bathy)) {
    geodepth = array(GEODEPTH, len); 
    } else geodepth = array(GEOBATH, len);

for (i=1; i<=len; i=i+1) {
  geodepth(i).raster = rrr(i).raster;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
  if (is_void(bathy)) {
  geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
  } else {
   geodepth(i).bath = long((-d(,i).idx * CNSH2O2X *100) + rrr(i).elevation);
  }
  geodepth(i).sa = d(,i).sa
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  if (correct == 1) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -4000); 
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
     }

     indx = where(rrr(i).elevation > 1000);
     // these are values above any defined reference plane and will mostly be the erroneous points defined at the height of the aircraft.
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
     }
     if ((bathy) && (!bcmin || !bcmax)) {
       indx = where((rrr(i).elevation > -4000) & (rrr(i).elevation < 1000));
       if (is_array(indx)) {
	if (is_void(bcmin)) {
           if (min(rrr(i).elevation(indx)) < bmin) bmin = min(rrr(i).elevation(indx));
	}
	if (is_void(bcmax)) {
           if (max(rrr(i).elevation(indx)) > bmax) bmax = max(rrr(i).elevation(indx));
	}
       }
     }
  }   
}

if (!bcmin) bcmin = bmin/100 + cmin;
if (!bcmax) bcmax = bmax/100 + cmax;
   

if (bathy) {
print, "bcmin = ",bcmin; print, "bcmax = ",bcmax
} else {
print, "cmin = ",cmin; print, "cmax = ",cmax
}

j = len;
for ( i=1; i<j; i++ ) {
 //if correct is set then plcm only non-zero north, east values
  indx1 = where(geodepth(i).north != 0);
  if (is_array(indx1) == 1) {
   if (bathy) {
    plcm, (geodepth(i).bath(indx1))/100, (geodepth(i).north(indx1))/100, (geodepth(i).east(indx1))/100,        msize=size,cmin=bcmin, cmax=bcmax;
   } else {
    plcm, (geodepth(i).depth(indx1))/100, (geodepth(i).north(indx1))/100, (geodepth(i).east(indx1))/100,	msize=size,cmin=cmin,cmax=cmax;
    }
  }
}

if (bathy) {
   colorbar(bcmin,bcmax);
   } else {
   colorbar(cmin, cmax);
   }

write,format="Draw complete. %d rasters drawn. %s", len, "\n"
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
