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
  long rn (120); 	//contains raster number
  long north(120);	//northing value
  long east(120); 	//easting value
  short depth(120);	//water depth in centimeters
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);	//scan angle
};

struct GEOBATH {
  long rn (120);     //contains raster number
  long north(120);      //northing value
  long east(120);       //easting value
  long bath(120);     //water bathymetry in centimeters 
  short depth(120);	//water depth in centimeters
  short bottom_peak(120); //peak amplitude of return signal
  short sa(120);        //scan angle
};

struct GEOALL {
  long rn (120); 	//contains raster value
  long north(120); 	//surface northing
  long east(120);	//surface east
  long sr2(120);	//slant range from the first to the last return as if in air in centimeters
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  short bottom_peak(120);//peak amplitude of the return signal
  short first_peak(120);//peak amplitude of the first surface return signal
  long bath(120);	//water bathymetry in centimeters
  short depth(120);	//water depth in centimeters
  short sa(120);        //scan angle
  }

func display_bath (d, rrr, cmin =, cmax=, size=, win=, correct=, bathy=, write_all=,bcmin=, bcmax=, bottom_peak= ) {
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
   write_all = set this keyword to write an array containing all information (include mirror point etc.)
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
if ( is_void( cmin ) && !(bottom_peak)) cmin = -10;
if ( is_void( cmax ) && !(bottom_peak)) cmax = 0;
if ( is_void( size )) size = 1.4;
bmin = 10000;
bmax = -10000;

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

if (is_void(write_all)) {
  if (is_void(bathy)) {
    geodepth = array(GEODEPTH, len); 
  } else geodepth = array(GEOBATH, len);
} else geodepth = array(GEOALL, len);

for (i=1; i<=len; i=i+1) {
  geodepth(i).rn = rrr(i).raster;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
  if ((is_void(bathy)) || (is_void(write_all))) {
  geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
  } else {
   geodepth(i).bath = long((-d(,i).idx * CNSH2O2X *100) + rrr(i).elevation);
   geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
  }
  geodepth(i).sa = d(,i).sa
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  if (write_all) {
    geodepth(i).mnorth = rrr(i).mnorth
    geodepth(i).meast = rrr(i).meast
    geodepth(i).melevation = rrr(i).melevation;
    geodepth(i).sr2 =long(-d(,i).idx * NS2MAIR*100); 
  }
  if (correct == 1) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -10000); 
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
     }

     indx = where(rrr(i).elevation >  10000); //changed
     // these are values above any defined reference plane and will mostly be the erroneous points defined at the height of the aircraft.
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
     }
     if ((bathy) && (!bcmin || !bcmax)) {
       indx = where((rrr(i).elevation > -5000) & (rrr(i).elevation < 1000));
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

if (bathy) {
  if (!bcmin) bcmin = bmin/100 + cmin;
  if (!bcmax) bcmax = bmax/100 + cmax;
}
   

if (bottom_peak) {
  if (!(cmin)) cmin = min(d.bottom_peak)
  if (!(cmax)) cmax = max(d.bottom_peak)
  }
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
   } else if (bottom_peak) {
    plcm, (geodepth(i).bottom_peak(indx1)), (geodepth(i).north(indx1))/100, (geodepth(i).east(indx1))/100, 
    msize=size,cmin=cmin,cmax=cmax;
    }
     else {
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

func write_geodepth (geodepth, opath=, ofname=, type=) {

//this function writes a binary file containing georeferenced depth data.
// input parameter geodepth is an array of structure GEODEPTH, defined by the display_bath function.
// amar nayegandhi 02/15/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

nwpr = long(4);

if (is_void(type)) type = 1;

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
num_rec = 0;


/* now look through the geodepth array of structures and write out only valid points */
len = numberof(geodepth);

for (i=1;i<=len;i++) {
  indx = where(geodepth(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geodepth(i).rn(indx(j));
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

func write_geobath (geobath, opath=, ofname=, type=) {

//this function writes a binary file containing georeferenced bathymetric data.
// input parameter geodepth is an array of structure GEOBATH, defined by the display_bath function.
// amar nayegandhi 02/15/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

if (is_void(type)) type = 3;
nwpr = long(6);

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
num_rec = 0;


/* now look through the geobath array of structures and write out only valid points */
len = numberof(geobath);

for (i=1;i<=len;i++) {
  indx = where(geobath(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geobath(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).bath(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).depth(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geobath(i).bottom_peak(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}


func write_topo(geodepth, rrr, opath=, ofname=, type=) {

//this function writes a binary file containing georeferenced topo data.
// amar nayegandhi 03/29/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

nwpr = long(4);

if (is_void(type)) type = 2;

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
num_rec = 0;


/* now look through the geodepth array of structures and write out only valid points */
len = numberof(rrr);

for (i=1;i<len;i++) {
  indx = where(rrr(i).elevation <  0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, rrr(i).raster(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, rrr(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, rrr(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, rrr(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}

func write_geoall (geoall, opath=, ofname=, type=) {

//this function writes a binary file containing georeferenced EAARL data.
// input parameter geoall is an array of structure GEOALL, defined by the display_bath function.
// amar nayegandhi 05/07/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");

if (is_void(type)) type = 4;
nwpr = long(12);

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
num_rec = 0;


/* now look through the geoall array of structures and write out only valid points */
len = numberof(geoall);

for (i=1;i<=len;i++) {
  indx = where(geoall(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geoall(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).sr2(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).mnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).meast(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).melevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).bottom_peak(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geoall(i).first_peak(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geoall(i).bath(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).depth(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}
