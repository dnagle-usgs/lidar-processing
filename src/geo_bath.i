/*
   $Id$

   Orginal by Amar Nayegandhi


   7/6/02 WW
	Minor changes and additions made to many DOCUMENTS, comments,
        and a couple of divide by zero error checks made.

*/
write, "$Id$"
require, "surface_topo.i"
require, "bathy.i"
require, "eaarl_constants.i"
require, "colorbar.i"
require, "read_yfile.i"
require, "rbgga.i"

/* 
  This program is used to display a bathymetric image using the 
  topographic georectification.

*/


struct GEOALL {
  long rn (120); 	//contains raster value and pulse value
  long north(120); 	//surface northing in centimeters
  long east(120);	//surface easting in centimeters
  short sr2(120);	// Slant range first to last return in nanoseconds
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  short bottom_peak(120);//peak amplitude of the bottom return signal
  short first_peak(120);//peak amplitude of the first surface return signal
  short depth(120);     //water depth in centimeters 
}

func display_bath (d, rrr, cmin=, cmax=, 
        	   size=, win=, correct=, bathy=, bcmin=, bcmax=, 
                   bottom_peak= ) {
/* DOCUMENT display_bath (d, rrr, cmin =, cmax=, size=, win=, 
                          correct=, bathy=, bcmin=, bcmax=, bottom_peak ) 

   This function displays a depth or bathymetric image using the 
   georectification of the first surface return.  The parameters are as 
   follows:

 d		Array of structure BATHPIX  containing depth information.  
                This is the return value of function run_bath.

 rrr		Array of structure R containing first surface information.  
                This the is the return value of function first_surface.

 cmin=		Minimum depth (water column thickness) in 
                meters(default is -10m)

 cmax= 		Maximum depth (water column thickness) in 
                meters(default is 0m)

 size=		Screen size of each point (default 1.2).  

 win=		Graphics window to be used for plotting image 
                (default is window 5).

 correct=	Set this keyword if you would like to correct the image to 
                exclude points with incorrect first surface returns.  
                Highly recommended.

 bathy=		Set this keyword for displaying submerged topography.  
        	Default displays depth image.

 bottom_peak=	Set this keyword to display the amplitude of the 
		bottom return signal.  

 bcmin=		Minimum value for submerged topography in NAD 83 elevations  
		(default is calculated by function).

 bcmax=		Maximum value for submerged topography in NAD 83 elevations  
		(default is calculated by function).


   The return value depth is an array of structure GEOALL. The array 
   can be written to a file using write_geoall  

   See also: first_surface, run_bath, write_geoall
*/


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

geodepth = array(GEOALL, len);
bath_arr = array(long,120,len);
if (correct) {
  cflag = array(short,120,len);
}

for (i=1; i<=len; i=i+1) {
  geodepth(i).rn = rrr(i).raster;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
  geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
  indx = where((-d(,i).idx) != 0); 
  if (is_array(indx)) {
    bath_arr(indx,i) = long((-d(,i).idx(indx) * CNSH2O2X *100) + rrr(i).elevation(indx));
  }
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  geodepth(i).first_peak = 0;
  geodepth(i).elevation = rrr(i).elevation;
  geodepth(i).mnorth = rrr(i).mnorth
  geodepth(i).meast = rrr(i).meast
  geodepth(i).melevation = rrr(i).melevation;
  geodepth(i).sr2 =short(d(,i).idx); 

 if (correct) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -10000); 
     if (is_array(indx)) {
        cflag(indx,i) = 0;
     }

     indx = where(rrr(i).elevation >  20000); 
     // these are values above any defined reference plane and will  be the erroneous points defined (by rrr) at the height of the aircraft.
     if (is_array(indx)) {
       cflag(indx,i) = 0;
     }
  }
  if ((bathy) && (!bcmin || !bcmax)) {
     indx = where((rrr(i).elevation > -5000) & (rrr(i).elevation < 1000));
     if (is_array(indx)) {
	if (is_void(bcmin)) {
           if (min(rrr(i).elevation(indx)) < bmin) 
		bmin = min(rrr(i).elevation(indx));
	}
	if (is_void(bcmax)) {
           if (max(rrr(i).elevation(indx)) > bmax) 
		bmax = max(rrr(i).elevation(indx));
	}
     }
  }
} /* end for loop */

if (bathy) {
  if (!bcmin) bcmin = bmin/100. + cmin;
  if (!bcmax) bcmax = bmax/100. + cmax;
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
    plcm, (bath_arr(indx1,i))/100., (geodepth(i).north(indx1))/100., 
	(geodepth(i).east(indx1))/100., msize=size, cmin=bcmin, cmax=bcmax;
   } else if (bottom_peak) {
    plcm, (geodepth(i).bottom_peak(indx1)), (geodepth(i).north(indx1))/100, 
	(geodepth(i).east(indx1))/100, 
        msize=size,cmin=cmin,cmax=cmax;
    }
     else {
    plcm, (geodepth(i).depth(indx1))/100., (geodepth(i).north(indx1))/100., 
          (geodepth(i).east(indx1))/100., msize=size,cmin=cmin,cmax=cmax;
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
/* DOCUMENT write_geodepth (geodepth, opath=, ofname=, type=)

This function writes a binary file containing georeferenced depth data.
input parameter geodepth is an array of structure GEODEPTH, defined 
by the display_bath function.

Inputs:
 geodepth	Geodepth array.
    opath=	Output data path
   ofname=	Output file name
     type=	Output data type.

Amar Nayegandhi 02/15/02.


*/
fn = opath+ofname;

/* 
   open file to read/write (it will overwrite any previous 
   file with same name) 
*/

f = open(fn, "w+b");
nwpr = long(4);

if (is_void(type)) type = 1;

rec = array(long, 4);

/* The first word in the file will decide the endian system. */
rec(1) = 0x0000ffff;

/* The second word defines the type of output file */
rec(2) = type;

/* The third word defines the number of words in each record */
rec(3) = nwpr;

/* The fourth word will eventually contain the total number 
   of records.  We don't know the value just now, so will wait 
   till the end. 
*/
rec(4) = 0;

_write, f, 0, rec;

byt_pos = 16; /* 4bytes , 4words */
num_rec = 0;


/* Now look through the geodepth array of structures and write 
   out only valid points 
*/
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
/* DOCUMENT write_geobath (geobath, opath=, ofname=, type=)

This function writes a binary file containing georeferenced 
bathymetric data.  Input parameter geodepth is an array of 
structure GEOBATH, defined by the display_bath function.

Amar Nayegandhi 02/15/02.

*/


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
     bath_arr = long((geobath(i).sr2(indx(j)))*CNSH2O2X *100);
     _write, f, byt_pos, bath_arr;
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

func write_geoall (geoall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_geoall (geoall, opath=, ofname=, type=, append=) 

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure GEOALL to a binary file.  
 Input parameter geoall is an array of structure GEOALL, defined by the 
 display_bath function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   geoall	Array of structure geoall as returned by function 
                display_bath;

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file, currently only type = 4 is supported.

   append=	Set this keyword to append to existing file.


   See also: display_bath, make_bathy

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
} else {
  byt_pos = sizeof(f);
}
num_rec = 0;


/* now look through the geoall array of structures and write 
 out only valid points 
*/
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
     byt_pos = byt_pos + 2;
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
     _write, f, byt_pos, geoall(i).depth(indx(j));
     byt_pos = byt_pos + 2;
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

func compute_depth(data_ptr=, ipath=,fname=,ofname=) {
/* DOCUMENT compute_depth(data_ptr=, ipath=,fname=,ofname=)  
This function computes the depth in water using the mirror position 
and the angle of refraction in water.  The input parameters defined 
are as follows: 

data_ptr=	Pointer to data array of structure GEOALL.  
ipath= 		Input (and output) directory. 
fname= 		File name of input file. 
ofname=		File name of output file.  

This function returns the pointer to the data array with 
computed depth.

See also: display_bath, write_geoall, read_yfile, make_bathy

*/
    
    if ((!is_void(ipath)) && (is_void(fname)) && (is_void(data_ptr))) {
       /* extract all data with *.bin extension from directory*/
       data_ptr = read_yfile(ipath);
    }

    if ((!is_void(ipath)) && (!is_void(fname))) {
      /* extract data from file(s) */
      data_ptr = read_yfile(ipath, fname_arr=fname);
    }

    nfiles = numberof(data_ptr);

    for (i=1;i<=nfiles;i++) {
      data = *data_ptr(i);
      // define the altitude for the 3rd point in poi
      pa = data.melevation - data.elevation;

      // now define H, the laser slant range using 3D version of 
      // Pytagorean Theorem


      H= sqrt((data.mnorth - data.north)^2 + 
              (data.meast  - data.east )^2 + 
              (data.melevation - data.elevation)^2); 

      // the angle of incidence that the laser intercepts the surface is:
      phi_air = acos(pa/H);

      // using Snells law:
      phi_water = asin(sin(phi_air)/KH2O);
      // where KH20 is the index of refraction at the operating 
      // wavelength of 532nm.

      // finally, depth D is given by:
      D = -(data.sr2*CNSH2O2X*100)*cos(phi_water);
      //overwrite existing depths with newly calculated depths
      data.depth = D;
      /*Dindx = where(D != 0);
       data1 = data.bath;
      data1(Dindx) = long(D(Dindx)+data.elevation(Dindx));
      data.bath = data1;
      */
      if (!is_void(ofname)) {
        //write current data out to output file ofname
	if (i==1) {
	write_geoall, data, opath=ipath, ofname=ofname;
	} else {
	write_geoall, data, opath=ipath, ofname=ofname, append=1;
	}

      }
	
   }
   return &data
}

func make_bathy(opath=,ofname=,ext_bad_att=, ext_bad_depth=, latutm=, q=) {
/* DOCUMENT make_bathy(opath=,ofname=,ext_bad_att=, ext_bad_depth=, 
            latlon=, llarr=)

 This function allows a user to define a region on the gga plot 
of flightlines (usually window 6) to write out a 'level 1' file 
and plot a depth image defined in that region.  The input parameters 
are: 

 opath 		ouput path where the output file must be written 
 ofname 	output file name 
 ext_bad_att  	Extract bad first return points (those points that 
                were termed 'bad' in the first surface return function) 
                and write these points to a file.
 ext_bad_depth  Extract the points that failed to show any depth using 
                the run_bath function and write these points to a file.

Returns:
This function does not return a value, it writes an output file.
      
 Please ensure that the tans and pnav data have been loaded before 
executing make_bathy.  See rbpnav() and rbtans() for details.
The structure BATH_CTL must be initialized as well.  
See define_bath_ctl()

      See also: first_surface, run_bath, display_bath 
*/
   
   extern edb, soe_day_start, bath_ctl, tans, pnav, type, utm;
   
   /* check to see if required parameters have been initialized */
   if (!(type)) {
    write, "BATH_CTL structure not initialized.  Running define_bath_ctl... \n";
     type=define_bath_ctl(junk);
     write, "\n";
   }
   write, "BATH_CTL initialized to : \r";
   print, bath_ctl;

   /* define cmin and cmax depending on type */
   if (type == "tampabay") {
     cmin = -6;
     cmax = -0.1;
   }
   if (type == "keys") {
     cmin = -18;
     cmax = -2;
   }
   if (type == "wva") {
     cmin = -10;
     cmax = 0;
   }

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

   /* find the start and stop times using gga_find_times in rbgga.i */
   t = gga_find_times(q);

   if (is_void(t)) {
     write, "No flightline found in selected area. Please start again... \r";
     return
   }

   write, "\n";
   write,format="Total seconds of flightline data selected = %6.2f\n", 
         (t(dif, ))(,sum);


   /* now loop through the times and find corresponding start and 
      stop raster numbers 
   */
   no_t = numberof(t(1,));
   write, format="Number of flightlines selected = %d \n", no_t;
   rn_arr = array(int,2,no_t);
   tyes_arr = array(int,no_t);
   tyes_arr(1:0) = 1;
 write,""
   for (i=1;i<=numberof(t(1,));i++) {
      tyes = 1;
      write, format="Processing %d of %d\r", i, numberof(t(1,));
      if ((tans.somd(1) > t(2,i)) || (tans.somd(0) < t(1,i))) {
         write, format="Corresponding TANS data for flightline %d not found."+
                       "Omitting flightline ... \n",i;
	 tyes = 0;
	 tyes_arr(i)=0;
      } else if ((tans.somd(1) > t(1,i)) && (tans.somd(0) >= t(2,i))) {
         t(1,i) = tans.somd(1);
         write, format="Corresponding TANS data for beginning section"+
                       "of flightline %d not found.  Selecting part "+
                       "of flightline ... \n",i;
      } else if ((tans.somd(1) <= t(1,i)) && (tans.somd(0) < t(2,i))) {
         t(2,i) = tans.somd(0);
         write, format="Corresponding TANS data for end section of "+
                       "flightline %d not found.  Selecting part of "+
                       "flightline ... \n",i;
      }
      if (tyes) {
         rn_indx_start = where(((edb.seconds - soe_day_start) ) == int(t(1,i)));
         rn_indx_stop = where(((edb.seconds - soe_day_start) ) == ceil(t(2,i)));
         if (!is_array(rn_indx_start) || !is_array(rn_indx_stop)) {
            write, format="Corresponding Rasters for flightline %d not found."+
                          "  Omitting flightline ... \n",i;
	    rn_start = 0;
	    rn_stop = 0;
         } else {
            rn_start = rn_indx_start(1);
            rn_stop = rn_indx_stop(0);
         }

         rn_arr(,i) =  [rn_start, rn_stop];
      }
   }
   write,format="\nNumber of Rasters selected = %6d\n", (rn_arr(dif, )) (,sum); 

   /* now call run_bath from bathy.i and first_surface from 
      surface_topo.i to extract bathy/topo information for each 
      sequence of rasters in rn_arr. 
   */

   if (!(opath)) opath="~/";
   if (!(ofname)) ofname = "geoall_rgn_l1.bin";
   if (!win) win = 5;
   window, win; fma;
   /* initialize counter variables */
   tot_count = 0;
   ba_count = 0;
   bd_count = 0;

   /* use tyes_arr to decide first valid flightline */
   tindx = where(tyes_arr != 0);
   if (!is_void(tindx)) {
     no_append = min(tindx);
   } 

    for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0) && (tyes_arr(i) != 0)) {
       write, format="Processing segment %d of %d for bathymetry\n", i, no_t;
       d = run_bath(start=rn_arr(1,i), stop=rn_arr(2,i));
       write, "Processing for first_surface...";
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i)); 
       a=[];
       write, "Using display_bath for submerged topography...";
       depth = display_bath(d,rrr, cmin=cmin, cmax=cmax);
       limits,square=1; limits


       //make depth correction using compute_depth
       write, "Correcting water depths for Snells law...";
       cdepth_ptr = compute_depth(data_ptr=&depth); 
       depth = *cdepth_ptr(1);
       tot_count += numberof(depth.elevation);

       /* if ext_bad_att is set, find all points having elevation = ht 
          of airplane 
       */
       if (ext_bad_att) {
         write, "Extracting and writing false first points";
         /* compare depth.elevation with 70% of depth.melevation */
	 elv_thresh = 0.7*(avg(depth.melevation));
         ba_indx = where(depth.elevation > elv_thresh);
	 ba_count += numberof(ba_indx);
	 ba_depth = depth;
	 deast = depth.east;
   	 if ((is_array(ba_indx))) {
	 deast(ba_indx) = 0;
         }
	 dnorth = depth.north;
   	 if ((is_array(ba_indx))) {
	 dnorth(ba_indx) = 0;
	 }
	 depth.east = deast;
	 depth.north = dnorth;

	 /* write array ba_depth to a file */
	 ba_indx_r = where(ba_depth.elevation < elv_thresh);
	 bdeast = ba_depth.east;
   	 if ((is_array(ba_indx_r))) {
	 bdeast(ba_indx_r) = 0;
 	 }
	 bdnorth = ba_depth.north;
   	 if ((is_array(ba_indx_r))) {
	 bdnorth(ba_indx_r) = 0;
	 }
	 ba_depth.east = bdeast;
	 ba_depth.north = bdnorth;

	 ba_ofname_arr = strtok(ofname, ".");
	 ba_ofname = ba_ofname_arr(1)+"_bad_fr."+ba_ofname_arr(2);
	 write, format="Writing array ba_depth to file: %s\n", ba_ofname;
         if (i==no_append) {
           write_geoall, ba_depth, opath=opath, ofname=ba_ofname;
         } else {
           write_geoall,  ba_depth, opath=opath, ofname=ba_ofname, append=1;
         }
       } 

       /* if ext_bad_depth is set, find all points having depth 
          and bath = 0  
       */
       if (ext_bad_depth) {
         write, "Extracting false depths and writing to file",i;
         /* compare depth.depth with 0 */
         ba_indx = where(depth.depth == 0);
	 bd_count += numberof(ba_indx);
	 ba_depth = depth;
	 deast = depth.east;
	 deast(ba_indx) = 0;
	 dnorth = depth.north;
	 dnorth(ba_indx) = 0;
	 depth.east = deast;
	 depth.north = dnorth;

	 /* write array ba_depth to a file */
	 ba_indx_r = where(ba_depth.depth != 0);
	 bdeast = ba_depth.east;
	 bdeast(ba_indx_r) = 0;
	 bdnorth = ba_depth.north;
	 bdnorth(ba_indx_r) = 0;
	 ba_depth.east = bdeast;
	 ba_depth.north = bdnorth;

	 ba_ofname_arr = strtok(ofname, ".");
	 ba_ofname = ba_ofname_arr(1)+"_bad_depth."+ba_ofname_arr(2);
	 write, "now writing array bad_depth  to a file \r";
         if (i==no_append) {
           write_geoall, ba_depth, opath=opath, ofname=ba_ofname;
         } else {
           write_geoall,  ba_depth, opath=opath, ofname=ba_ofname, append=1;
         }
       } 

       write, format="\nWriting data from structure geoall to output "+
                     "file for flightline %d ... \n", i;
       if (i==no_append) {
         write_geoall, depth, opath=opath, ofname=ofname;
       } else {
         write_geoall, depth, opath=opath, ofname=ofname, append=1;
       }
      }
    } 

    write, "\nStatistics: \r";
    write, format="Total number of records processed = %d\n",tot_count;
    write, format="Total number of records with false first "+
                   "returns data = %d\n",ba_count;
    write, format = "Total number of records with false depth data = %d\n",
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
                      "first returns had false depth! \n",pbd; 
    } else 
	write, "No bathy records found"



}



func raspulsearch(data,win=,buf=) {
 /* This function uses a mouse click on a bathy/depth plot and 
    finds the associated rasters

    Amar Nayegandhi 06/11/02
    */

 /* use mouse function to click on the reqd point */
 extern wfa, cmin, cmax;
 if (!(win)) win = 5;
 window, win;

 if (typeof(data)=="pointer") data=*data(1);

 if (!buf) buf=1000; /* 10 meters is the default buffer side to 
                        look for the point 
                      */

 spot = mouse(1,1,"Please click in window");

// plg, spot(2),spot(1),marker=2,msize=2.0, color="black",type=0;

 write, format="Searching for data within %d centimeters from selected point \n",buf;

 indx = where(((data.east >= spot(1)*100-buf)   & 
               (data.east <= spot(1)*100+buf))  & 
               ((data.north >= spot(2)*100-buf) & 
               (data.north <= spot(2)*100+buf)));

 if (is_array(indx)) {
    write, format="%d points found \n",numberof(indx);
    // print, data(indx);
    rn = data(indx(1)).rn;
    mindist = buf*sqrt(2);
    for (i = 1; i < numberof(indx); i++) {
      x1 = (data(indx(i)).east)/100.0;
      y1 = (data(indx(i)).north)/100.0;
      dist = sqrt((spot(1)-x1)^2 + (spot(2)-y1)^2);
      if (dist <= mindist) {
        mindist = dist;
	mindata = data(indx(i));
	minindx = indx(i);
      }
    }
    rasterno = mindata.rn&0xffffff;
    pulseno = mindata.rn/0xffffff;

    write, format="The closest point is at a distance %5.3f meters "+
                  "from the selected point \n", mindist;
    write, format="Raster number %d and Pulse number %d \n",rasterno, pulseno;
    write, format="Plotting raster and waveform with Raster number %d"+
                  " and Pulse number %d \n",rasterno(1), pulseno(1);
    if (_ytk) {
      ytk_rast, rasterno(1);
      window, 0;
      show_wf, *wfa, pulseno(1), win=0, cb=7;
      window, win;
      //window, 5;plcm, mindata.elevation/100., mindata.north/100., mindata.east/100., msize = 3.0, cmin= cmin, cmax = cmax
      //write, format="minindx = %d\n",minindx;
    } 
 } else {
   print, "No points found!  Please try again... \n";
 }

 return mindata;
      
}



