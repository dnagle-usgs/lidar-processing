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
require, "drast.i"

/* 
  This program is used to process bathymetry data  using the 
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

func make_fs_bath (d, rrr) {  
/* DOCUMENT make_fs_bath (d, rrr) 

   This function makes a depth or bathymetric image using the 
   georectification of the first surface return.  The parameters are as 
   follows:

 d		Array of structure BATHPIX  containing depth information.  
                This is the return value of function run_bath.

 rrr		Array of structure R containing first surface information.  
                This the is the return value of function first_surface.


   The return value depth is an array of structure GEOALL. The array 
   can be written to a file using write_geoall  

   See also: first_surface, run_bath, write_geoall
*/


// d is the depth array from bathy.i
// rrr is the topo array from surface_topo.i

if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

geodepth = array(GEOALL, len);
bath_arr = array(long,120,len);

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


} /* end for loop */

   
//write,format="Processing complete. %d rasters drawn. %s", len, "\n"
return geodepth;
}


func write_geodepth (geodepth, opath=, ofname=, type=) {
/* DOCUMENT write_geodepth (geodepth, opath=, ofname=, type=)

This function writes a binary file containing georeferenced depth data.
input parameter geodepth is an array of structure GEODEPTH, defined 
by the make_fs_bath function.

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
structure GEOBATH, defined by the make_fs_bath function.

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



func write_geoall (geoall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_geoall (geoall, opath=, ofname=, type=, append=) 

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure GEOALL to a binary file.  
 Input parameter geoall is an array of structure GEOALL, defined by the 
 make_fs_bath function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   geoall	Array of structure geoall as returned by function 
                make_fs_bath;

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file, currently only type = 4 is supported.

   append=	Set this keyword to append to existing file.


   See also: make_fs_bath, make_bathy

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

See also: make_fs_bath, write_geoall, read_yfile, make_bathy

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

      a = double((data.mnorth - data.north))^2;
      b = double((data.meast - data.east))^2;
      c = double((data.melevation - data.elevation))^2;
      H= sqrt(a + b + c);

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

func make_bathy(latutm=, q=, ext_bad_att=, ext_bad_depth=) {
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
This function returns the array depth_arr.
      
 Please ensure that the tans and pnav data have been loaded before 
executing make_bathy.  See rbpnav() and rbtans() for details.
The structure BATH_CTL must be initialized as well.  
See define_bath_ctl()

      See also: first_surface, run_bath, make_fs_bath 
*/
   
   extern edb, soe_day_start, bath_ctl, tans, pnav, type, utm, depth_all, rn_arr, rn_arr_idx, ba_depth, bd_depth;
   depth_all = [];
   
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
     cmax = -0.5;
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

  /* find start and stop raster numbers for all flightlines */
   rn_arr = sel_region(q);


   no_t = numberof(rn_arr(1,));

   /* initialize counter variables */
   tot_count = 0;
   ba_count = 0;
   bd_count = 0;
   fcount = 0;

    for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
       fcount ++;
       write, format="Processing segment %d of %d for bathymetry\n", i, no_t;
       d = run_bath(start=rn_arr(1,i), stop=rn_arr(2,i));
       write, "Processing for first_surface...";
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i)); 
       a=[];
       write, "Using make_fs_bath for submerged topography...";
       depth = make_fs_bath(d,rrr);
       //limits,square=1; limits


       //make depth correction using compute_depth
       write, "Correcting water depths for Snells law...";
       cdepth_ptr = compute_depth(data_ptr=&depth); 
       depth = *cdepth_ptr(1);
       grow, depth_all, depth;
       tot_count += numberof(depth.elevation);
      }
    }

    /* if ext_bad_att is set, find all points having elevation = ht 
        of airplane 
    */
    if (ext_bad_att) {
        write, "Extracting and writing false first points";
        /* compare depth.elevation with 70% of depth.melevation */
	elv_thresh = 0.7*(avg(depth_all.melevation));
        ba_indx = where(depth_all.elevation > elv_thresh);
	ba_count += numberof(ba_indx);
	ba_depth = depth_all;
	deast = depth_all.east;
   	if ((is_array(ba_indx))) {
	  deast(ba_indx) = 0;
        }
	 dnorth = depth_all.north;
   	if ((is_array(ba_indx))) {
	 dnorth(ba_indx) = 0;
	}
	depth_all.east = deast;
	depth_all.north = dnorth;

	/* compute array for bad attitude (ba_depth) to write to a file */
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

      } 

      /* if ext_bad_depth is set, find all points having depth 
         and bath = 0  
      */
      if (ext_bad_depth) {
        write, "Extracting false depths ";
        /* compare depth.depth with 0 */
        bd_indx = where(depth_all.depth == 0);
	bd_count += numberof(ba_indx);
	bd_depth = depth_all;
	deast = depth_all.east;
	deast(bd_indx) = 0;
	dnorth = depth_all.north;
	dnorth(bd_indx) = 0;
	//depth_all.east = deast;
	//depth_all.north = dnorth;

	/* compute array for bad depth (bd_depth) to write to a file */
	bd_indx_r = where(bd_depth.depth != 0);
	bdeast = bd_depth.east;
	bdeast(bd_indx_r) = 0;
	bdnorth = bd_depth.north;
	bdnorth(bd_indx_r) = 0;
	bd_depth.east = bdeast;
	bd_depth.north = bdnorth;

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
    no_append = 0;
    rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);	

    tkcmd, swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))
    return depth_all;

}

func write_bathy(opath, ofname, depth_all, ba_depth=, bd_depth=) {
  /* DOCUMENT write_bathy(opath, ofname, depth_all, ba_depth=, bd_depth=)
    This function writes bathy data to a file.
    amar nayegandhi 09/17/02.
  */
  if (is_array(ba_depth)) {
	ba_ofname_arr = strtok(ofname, ".");
	ba_ofname = ba_ofname_arr(1)+"_bad_fr."+ba_ofname_arr(2);
	write, format="Writing array ba_depth to file: %s\n", ba_ofname;
        write_geoall, ba_depth, opath=opath, ofname=ba_ofname;
  }

  if (is_array(bd_depth)) {
	bd_ofname_arr = strtok(ofname, ".");
	bd_ofname = bd_ofname_arr(1)+"_bad_depth."+bd_ofname_arr(2);
	write, "now writing array bad_depth  to a file \r";
        write_geoall, bd_depth, opath=opath, ofname=bd_ofname;
  }


  write_geoall, depth_all, opath=opath, ofname=ofname;

}

func plot_bathy(depth_all, fs=, ba=, de=, fint=, lint=, win=, cmin=, cmax=, msize=) {
  /* DOCUMENT plot_bathy(depth_all, fs=, ba=, de=, int=, win=)
     This function plots bathy data in window, "win" depending on which variable is set.
     If fs = 1, first surface returns are plotted referenced to NAD83.
     If ba = 1, subaqueous topography is plotted referenced to NAD83.
     If de = 1, water depth in meters is plotted.
     If int = 1, intensity values are plotted.

  */
  if (is_void(win)) win = 5;
  window, win;fma;
  if (fs) {
     indx = where(depth_all.north != 0);
     plcm, depth_all.elevation(indx)/100., depth_all.north(indx)/100., depth_all.east(indx)/100., cmin=cmin, cmax=cmax, msize = msize;
  } else if (ba) {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, (depth_all.elevation(indx) + depth_all.depth(indx))/100., depth_all.north(indx)/100., depth_all.east(indx)/100., cmin = cmin, cmax = cmax, msize = msize;
  } else if (fint) {
    indx = where(depth_all.north != 0);
    plcm, depth_all.first_peak(indx), depth_all.north(indx)/100., depth_all.east(indx)/100., cmin = cmin, cmax = cmax, msize = msize;
  } else if (lint) {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, depth_all.bottom_peak(indx), depth_all.north(indx)/100., depth_all.east(indx)/100., cmin = cmin, cmax = cmax, msize = msize;
  } else {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, depth_all.depth(indx)/100., depth_all.north(indx)/100., depth_all.east(indx)/100., cmin = cmin, cmax = cmax, msize = msize;
  }
  colorbar, cmin, cmax;
}

 
 


func raspulsearch(data,win=,buf=, cmin=, cmax=, msize=, disp_type=) {
 /* This function uses a mouse click on a bathy/depth plot and 
    finds the associated rasters

    Amar Nayegandhi 06/11/02
    */

 /* use mouse function to click on the reqd point */
 extern wfa;
 extern _last_rastpulse_elevation
 if ( is_void(_last_rastpulse_elevation ) )
	_last_rastpulse_elevation = 0.0;
 if (!(win)) win = 5;
 window, win;
 if (!(disp_type)) disp_type = 0; //default to first surface topo
 if (!(msize)) msize = 1.0

 if (typeof(data)=="pointer") data=*data(1);

 if (numberof(data) != numberof(data.north)) {
     if ((disp_type == 1) || (disp_type == 2) || (disp_type == 5)) {
 	//convert data from GEOALL into GEO structure
	data_new = array(GEO, numberof(data)*120);
	indx = where(data.rn >= 0);
	data_new.rn = data.rn(indx);
	data_new.north = data.north(indx);
	data_new.east = data.east(indx);
	data_new.sr2 = data.sr2(indx);
	data_new.elevation = data.elevation(indx);
	data_new.mnorth = data.mnorth(indx);
	data_new.meast = data.meast(indx);
	data_new.melevation = data.melevation(indx);
	data_new.bottom_peak = data.bottom_peak(indx);
	data_new.first_peak = data.first_peak(indx);
	data_new.depth = data.depth(indx);

	data = data_new
     }
     if (disp_type == 0) {
        //convert data from R into FS structure 
	data_new = array(FS, numberof(data)*120);
	indx = where(data.raster >= 0);
	data_new.rn = data.raster(indx);
	data_new.north = data.north(indx);
	data_new.east = data.east(indx);
	data_new.elevation = data.elevation(indx);
	data_new.mnorth = data.mnorth(indx);
	data_new.meast = data.meast(indx);
	data_new.melevation = data.melevation(indx);

	data = data_new
     }
 }

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

    write, format="Nearest point: %5.3fm\n", mindist;
    write, format="       Raster: %6d    Pulse: %d\n",rasterno, pulseno;
    write, format="Plot   raster: %6d waveform: %d\n",rasterno(1), pulseno(1);
    if (_ytk) {
      window,1,wait=1
      ytk_rast, rasterno(1);
      window, 0, wait=1; redraw;
      tkcmd, swrite(format="set rn %d", rasterno(1))
      show_wf, *wfa, pulseno(1), win=0, cb=7;
      if (is_void(cmin) || is_void(cmax)) {
        window, win; plmk, mindata.north/100., 
                           mindata.east/100., 
                           msize = 0.4, marker = 1, color = "red";
      } else {
        if (disp_type == 0) {
          window, win; plcm, mindata.elevation/100., 
                             mindata.north/100., 
                             mindata.east/100., 
                             msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, 
                             marker=4
	}
        if (disp_type == 1) {
	  a = [];
          ex_bath, rasterno, pulseno, graph=1;
          window, win; plcm, (mindata.elevation+mindata.depth)/100., 
                             mindata.north/100., mindata.east/100., 
                             msize = msize*1.5, cmin= cmin, cmax = cmax, 
                             marker=4
	}
        if (disp_type == 2) {
	  a = [];
          ex_bath, rasterno, pulseno, graph=1;
          window, win; plcm, mindata.depth/100., mindata.north/100., 
                             mindata.east/100., msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, marker = 4
	}
      }
      //write, format="minindx = %d\n",minindx;
    } 
 } else {
   print, "No points found!  Please try again... \n";
 }
 write,format=" Raster nbr: %d\n", mindata.rn
 write,format="Scanner Elev: %7.2fm\n", mindata.melevation/100.0
 write,format="Surface elev: %7.2fm Delta: %7.2fm\n",
               mindata.elevation/100.0,
               mindata.elevation/100.0 - _last_rastpulse_elevation/100.0

 _last_rastpulse_elevation = mindata.elevation;
  
 return mindata;
      
}


func hist_depth( depth_all, win=, dtyp= ) {
/* DOCUMENT hist_depth(depth_all)

   Return the histogram of the good depths.  The input depth_all 
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs: 
	depth_all   An array of "GEOALL" structures.  
	dytp = display type (water surface or bathymetry)

 amar nayegandhi 10/6/2002.  similar to hist_fs by W. Wright

See also: GEOALL
*/


  if ( is_void(win) ) 
	win = 7;

// build an edit array indicating where values are between -60 meters
// and 3000 meters.  That's enough to encompass any EAARL data than
// can ever be taken.
  gidx = (depth_all.elevation > -6000) | (depth_all.elevation <300000);  

// Now kick out values which are within 1-meter of the mirror and depth = 0. Some
// functions will set the elevation to the mirror value if they can't
// process it.
  gidx &= ((depth_all.elevation < (depth_all.melevation-1) & (depth_all.depth != 0)));

// Now generate a list of where the good elevation values are.
  q = where( gidx )
  
// now find the minimum 
minn = (depth_all.elevation(q)+depth_all.depth(q))(min);
maxx = (depth_all.elevation(q)+depth_all.depth(q))(max);

 depthy = (depth_all.elevation(q) + depth_all.depth(q))- minn ;
 minn /= 100.0
 maxx /= 100.0;


// make a histogram of the data indexed by q.
  h = histogram( (depthy / 100) + 1 );
  h( where( h == 0 ) ) = 1;
  e = span( minn, maxx, numberof(h) ) + 1 ; 
  w = window();
  window,win; fma; plg,h,e;
  pltitle(swrite( format="Depth Histogram %s", data_path));
  xytitles,"Depth Elevation (meters)", "Number of measurements"
  window(w);
  return [e,h];
}

