/*
   $Id$
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
  short sr2(120);	//slant range from the first to the last return as if in air in centimeters
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
  if ((is_void(bathy))) {
    geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
    if (write_all) geodepth(i).bath = long((-d(,i).idx * CNSH2O2X *100) + rrr(i).elevation);
  } else {
   geodepth(i).bath = long((-d(,i).idx * CNSH2O2X *100) + rrr(i).elevation);
   geodepth(i).depth = short(-d(,i).idx * CNSH2O2X *100);
  }
  geodepth(i).sa = d(,i).sa
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  geodepth(i).first_peak = d(,i).bottom_peak;
  if (write_all) {
    geodepth(i).elevation = rrr(i).elevation;
    geodepth(i).mnorth = rrr(i).mnorth
    geodepth(i).meast = rrr(i).meast
    geodepth(i).melevation = rrr(i).melevation;
    geodepth(i).sr2 =short(d(,i).idx); 
  }
  if (correct == 1) {
     // search for erroneous elevation values
     indx = where(rrr(i).elevation < -10000); 
     if (is_array(indx) == 1) {
       geodepth(i).north(indx) = 0;
       geodepth(i).east(indx) = 0;
     }

     indx = where(rrr(i).elevation >  10000); 
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

func write_geoall (geoall, opath=, ofname=, type=, append=, correct=) {

//this function writes a binary file containing georeferenced EAARL data.
// input parameter geoall is an array of structure GEOALL, defined by the display_bath function.
// amar nayegandhi 05/07/02.
fn = opath+ofname;

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
     _write, f, byt_pos, geoall(i).bath(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).depth(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
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

      // now define H, the laser slant range using 3D version of Pytagorean Theorem
      H= sqrt((data.mnorth - data.north)^2 + (data.meast - data.east)^2 + (data.melevation - data.elevation)^2); 

      // the angle of incidence that the laser intercepts the surface is:
      phi_air = acos(pa/H);

      // using Snells law:
      phi_water = asin(sin(phi_air)/KH2O);
      // where KH20 is the index of refraction at the operating wavelength of 532nm.

      // finally, depth D is given by:
      D = -(data.sr2*CNSH2O2X*100)*cos(phi_water);
      //overwrite existing depths with newly calculated depths
      data.depth = D;
      data.bath = D+data.elevation;
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

func make_bathy(edb, soe_day_start, opath=,ofname=) {
   /* this function allows a user to define a region on the gga plot of flightlines
      and makes bathymetric plots defined in that region.
      */
   
   /* select a region using function gga_win_sel in rbgga.i */
   q = gga_win_sel(2);

   /* find the start and stop times using gga_find_times in rbgga.i */
   t = gga_find_times(q);

   write,format="%6.2f total seconds selected\n", (t(dif, )) (,sum);

   /* now loop through the times and find corresponding start and stop raster numbers */
   no_t = numberof(t(1,));
   write, format="Total flightlines selected = %d \n", no_t;
   rn_arr = array(int,2,no_t);
   for (i=1;i<=numberof(t(1,));i++) {
       rn_indx_start = where(((edb.seconds - soe_day_start) ) == int(t(1,i)));
       rn_indx_stop = where(((edb.seconds - soe_day_start) ) == ceil(t(2,i)));
       if (!is_array(rn_indx_start) || !is_array(rn_indx_stop)) {
          write, format="Corresponding Rasters for flightline %d not found.  Omitting flightline ... \n",i;
	  rn_start = 0;
	  rn_stop = 0;
       } else {
          rn_start = rn_indx_start(1);
          rn_stop = rn_indx_stop(0);
       }

       rn_arr(,i) =  [rn_start, rn_stop];
   }
    write,format="%6d total rasters selected\n", (rn_arr(dif, )) (,sum); 

   /* now call run_bath from bathy.i and first_surface from surface_topo.i to extract bathy/topo information for each sequence of rasters in rn_arr. */

   if (!(opath)) opath="~/";
   if (!(ofname)) ofname = "geoall_rgn_l1.bin";
   if (!win) win = 5;
   window, win; fma;

    for (i=1;i<=no_t;i++) {
      if (rn_arr(1,i) != 0) {
       write, format="processing using bathymetry algorithm for flightline %d ... \n", i;
       d = run_bath(start=rn_arr(1,i), stop=rn_arr(2,i));
       write, format="processing using first_surface algorithm for flightline %d ... \n", i;
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i)); 
       a=[];
       write, format="processing using display_bath to provide submerged topography for flightline %d ...\n", i;
       depth = display_bath(d,rrr,write_all=1, correct=1, cmin=-6, cmax=0);
       write, format="writing data from structure geoall to output file for flightline %d ... \n", i;
       if (i==1) {
         write_geoall, depth, opath=opath, ofname=ofname;
       } else {
         write_geoall,  depth, opath=opath, ofname=ofname, append=1;
       }
      }
    } 

}



func raspulsearch(data,win=,buf=) {
 /* this function uses a mouse click on a bathy/depth plot and finds the associated rasters
    amar nayegandhi 06/11/02
    */

 /* use mouse function to click on the reqd point */
 extern wfa;
 if (!(win)) win = 5;
 window, win;

 if (typeof(data)=="pointer") data=*data(1);

 if (!buf) buf=100; /*100 centimeters is the buffer to look for the point */

 spot = mouse(1,1,"Please click in window");

 plg, spot(2),spot(1),marker=3,msize=2.0, color="black",type=0;

 write, format="Searching for data within %d centimeters from selected point \n",buf;

 indx = where(((data.east >= spot(1)*100-buf) & (data.east <= spot(1)*100+buf)) & ((data.north >= spot(2)*100-buf) & (data.north <= spot(2)*100+buf)));

 if (is_array(indx)) {
    write, format="%d points found \n",numberof(indx);
    print, data(indx);
    rn = data(indx).rn;
    rasterno = rn&0xffffff;
    pulseno = rn/0xffffff;

    print, "The following points were found: \n";
    write, format="Raster number %d and Pulse number %d \n",rasterno, pulseno;
    write, format="Plotting raster and waveform with Raster number %d and Pulse number %d \n",rasterno(1), pulseno(1);
    if (_ytk) {
      ytk_rast, rasterno(1);
      window, 0;
      show_wf(*wfa, pulseno(1), win=0, cb=7);
    } 
 } else {
   print, "No points found!  Please try again... \n";
   }
      
}



