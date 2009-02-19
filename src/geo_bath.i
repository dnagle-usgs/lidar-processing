require, "l1pro.i";
write, "$Id$";
/*
   Orginal by Amar Nayegandhi

   7/6/02 WW
	Minor changes and additions made to many DOCUMENTS, comments,
        and a couple of divide by zero error checks made.

  This program is used to process bathymetry data using the 
  topographic georectification.
*/


struct GEOALL {
  long rn (120); 	//contains raster value and pulse value
  long north(120); 	//surface northing in centimeters
  long east(120);	//surface easting in centimeters
  short sr2(120);	// Slant range first to last return in nanoseconds*10
			// Modified slant range by a factor of 10 to increase the 
			// the accuracy of the range vector (AN-Jan 2005).
  long elevation(120); //first surface elevation in centimeters
  long mnorth(120);	//mirror northing
  long meast(120);	//mirror easting
  long melevation(120);	//mirror elevation
  short bottom_peak(120);//peak amplitude of the bottom return signal
  short first_peak(120);//peak amplitude of the first surface return signal
  short depth(120);     //water depth in centimeters 
  double soe(120);     //Seconds of the Epoch
}

func make_fs_bath (d, rrr, avg_surf=) {  
/* DOCUMENT make_fs_bath (d, rrr) 

   This function makes a depth or bathymetric image using the 
   georectification of the first surface return.  The parameters are as 
   follows:

 d		Array of structure BATHPIX  containing depth information.  
                This is the return value of function run_bath.

 rrr		Array of structure R containing first surface information.  
                This the is the return value of function first_surface.

avg_surf	Set to 1 if the surface returns should be averaged to the 
		first surface returns at the center of the swath.


   The return value depth is an array of structure GEOALL. The array 
   can be written to a file using write_geoall  

   See also: first_surface, run_bath, write_geoall
*/


// d is the depth array from bathy.i
// rrr is the topo array from surface_topo.i


if (numberof(d(0,,)) < numberof(rrr)) { len = numberof(d(0,,)); } else { 
   len = numberof(rrr);}

if (is_void(avg_surf)) avg_surf = 0;

geodepth = array(GEOALL, len);
bath_arr = array(long,120,len);

offset = array(double, 120);

for (i=1; i<=len; i=i+1) {
  geodepth(i).rn = rrr(i).rn;
  geodepth(i).north = rrr(i).north;
  geodepth(i).east = rrr(i).east;
//
  // code added by AN (Dec 04) to make all surface returns 
  // across a raster to be the average of the fresnel reflections.
  // the surface return is determined from the reflections 
  // that have the first channel saturated and come from
  // close to the center of the swath.  added 12/03/04 by Amar Nayegandhi
  if (avg_surf) {
   iidx = where((rrr(i).intensity > 220) & (rrr(i).rn/0xffffff > 35) & (rrr(i).rn/0xffffff < 85));
   if (is_array(iidx)) {
    elvs = median(rrr(i).elevation(iidx));
    elvsidx = where(abs(rrr(i).elevation(iidx)-elvs) <= 100) 
    elvs = avg(rrr(i).elevation(iidx(elvsidx)));
    old_elvs = rrr(i).elevation;
    //write, format="%5.2f ",elvs/100.;
    indx = where(rrr(i).elevation < (rrr(i).melevation - 5000));
    if (is_array(indx)) rrr(i).elevation(indx) = int(elvs);
    // now rrr.fs_rtn_centroid will change depending on where in time the surface occurs
    // for each laser pulse with respect to where its current surface elevation is.
    // this change is defined by the array offset
    offset = ((old_elvs - elvs)/(CNSH2O2X*100.));
   } else {
    write,format= "No water surface Fresnel reflection in raster rn = %d\n",(rrr(i).rn(1) & 0xffffff);
    offset(*) = 0;
   }
  }
// 
  if (avg_surf) {
      indx = where((d(,i).idx > 0) & (abs(offset) < 100)); 
  } else {
    indx = where((d(,i).idx)); 
  }
  if (is_array(indx)) {
    if (avg_surf) {
      fs_rtn_cent = rrr(i).fs_rtn_centroid(indx)+offset(indx);
      rrr(i).fs_rtn_centroid(indx) += offset(indx);
    } else {
      fs_rtn_cent = rrr(i).fs_rtn_centroid(indx);
    }
    geodepth(i).depth(indx) = short((-d(,i).idx(indx) + fs_rtn_cent ) * CNSH2O2X *100.-0.5);
    bath_arr(indx,i) = long(((-d(,i).idx(indx)+fs_rtn_cent ) * CNSH2O2X *100) + rrr(i).elevation(indx));
    geodepth(i).sr2(indx) =short((d(,i).idx(indx) - fs_rtn_cent)*10); 
  }
  geodepth(i).bottom_peak = d(,i).bottom_peak;
  geodepth(i).first_peak = d(,i).first_peak;

    
  geodepth(i).elevation = rrr(i).elevation;
  geodepth(i).mnorth = rrr(i).mnorth
  geodepth(i).meast = rrr(i).meast
  geodepth(i).melevation = rrr(i).melevation;
  geodepth(i).soe = rrr(i).soe;

  //indx1 = where(geodepth(i).elevation > 0.7*geodepth(i).melevation);
  //if (is_array(indx1))
  //  geodepth(i).north(indx1) = 0;


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
i86_primitives, f;

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
i86_primitives, f;

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
     bath_arr = long((geobath(i).sr2(indx(j)))*CNSH2O2X *10);
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
i86_primitives, f;

if (is_void(append)) {
  /* write header information only if append keyword not set */
  if (is_void(type)) {
    if (geoall.soe(1) == 0) {
      type = 4;
      nwpr = long(11);
    } else {
      type = 102;
      nwpr = long(12);
    }
  } else {
      nwpr = long(12);
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
     if (type == 102) {
       _write, f, byt_pos, geoall(i).soe(indx(j));
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
      // Pythagorean Theorem

      a = double((data.mnorth - data.north))^2;
      b = double((data.meast - data.east))^2;
      c = double((data.melevation - data.elevation))^2;
      H= sqrt(a + b + c);

      // the angle of incidence that the laser intercepts the surface is:
      Hindx = where(H == 0);
      if (is_array(Hindx))
        H(Hindx) = 0.0001;
      phi_air = acos(pa/H);

      // using Snells law:
      phi_water = asin(sin(phi_air)/KH2O);
      // where KH20 is the index of refraction at the operating 
      // wavelength of 532nm.

      // finally, depth D is given by:
      D = -(data.sr2*CNSH2O2X*10)*cos(phi_water);
      //overwrite existing depths with newly calculated depths
      data.depth = D;
      /*Dindx = where(D != 0);
       data1 = data.bath;
      data1(Dindx) = long(D(Dindx)+data.elevation(Dindx));
      data.bath = data1;
      */
      
    

      //Added by AN on 12/15/04 to correct for easting and northing
      // code below (within for loop) uses the ratio of the mirror
	// easting and northing to the surface easting and northing
	// to determine the change in the horizontal for the bottom.
	// The data.east and data.north values are replaced with the
	// bottom easting and northing.

      for (i=1;i<=numberof(data);i++) { 
        idx = where(irg_a(i).irange != 0);
	if (!is_array(idx)) continue;
        nsdepth = -1*data(i).depth/(CNSH2O2X*100); // actual depth in ns
        dratio = float(irg_a(i).irange(idx)+nsdepth(idx)+irg_a(i).fs_rtn_centroid(idx))/float(irg_a(i).irange(idx)+irg_a(i).fs_rtn_centroid(idx));
        ndiff = data(i).mnorth-data(i).north;
        ediff = data(i).meast-data(i).east;
        bnorth = (data(i).mnorth(idx)-dratio*ndiff(idx));
        beast = (data(i).meast(idx)-dratio*ediff(idx));
	idxx = where((data(i).north(idx) != 0) &
		     (data(i).east(idx) != 0) );
	if (!is_array(idx(idxx))) continue;
        data(i).north(idx(idxx)) = int(bnorth(idxx));
        data(i).east(idx(idxx)) = int(beast(idxx));
      }

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

func make_bathy(latutm=, q=, ext_bad_att=, ext_bad_depth=, avg_surf=) {
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

/*
   if (!(type)) {
    write, "BATH_CTL structure not initialized.  Running define_bath_ctl... \n";
     type=define_bath_ctl(junk);
     write, "\n";
   }
   write, "BATH_CTL initialized to : \r";
*/

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


  /* initialize counter variables */
  tot_count = 0;
  ba_count = 0;
  bd_count = 0;
  fcount = 0;

  if (is_array(rn_arr)) {
   no_t = numberof(rn_arr(1,));

  open_seg_process_status_bar;

    for (i=1;i<=no_t;i++) {
      if ((rn_arr(1,i) != 0)) {
       fcount ++;
       write, format="Processing segment %d of %d for bathymetry\n", i, no_t;
       d = run_bath(start=rn_arr(1,i), stop=rn_arr(2,i));
       if ( d == 0 ) return 0;
       write, "Processing for first_surface...";
       rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=1); 
       a=[];
       write, "Using make_fs_bath for submerged topography...";
       depth = make_fs_bath(d,rrr, avg_surf=avg_surf) ;
       //limits,square=1; limits


       //make depth correction using compute_depth
       write, "Correcting water depths for Snells law...";
       cdepth_ptr = compute_depth(data_ptr=&depth); 
       depth = *cdepth_ptr(1);
       grow, depth_all, depth;
       tot_count += numberof(depth.elevation);
      }
    }

    if (_ytk) tkcmd, "destroy .seg";

    /* if ext_bad_att is set, find all points having elevation = ht 
        of airplane 
    */
/*
    if (ext_bad_att && is_array(depth_all)) {
        write, "Extracting and writing false first points";
        // compare depth.elevation within 20m  of depth.melevation 
	elv_thresh = (depth_all.melevation-2000);
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

	// compute array for bad attitude (ba_depth) to write to a file 
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
*/

      /* if ext_bad_depth is set, find all points having depth 
         and bath = 0  
      */
/*
      if (ext_bad_depth && is_array(depth_all)) {
        write, "Extracting false depths ";
        // compare depth.depth with 0 
        bd_indx = where(depth_all.depth == 0);
	bd_count += numberof(ba_indx);
	bd_depth = depth_all;
	deast = depth_all.east;
	deast(bd_indx) = 0;
	dnorth = depth_all.north;
	dnorth(bd_indx) = 0;
	//depth_all.east = deast;
	//depth_all.north = dnorth;

	// compute array for bad depth (bd_depth) to write to a file 
	bd_indx_r = where(bd_depth.depth != 0);
	if (is_array(bd_indx_r)) {
	  bdeast = bd_depth.east;
	  bdeast(bd_indx_r) = 0;
	  bdnorth = bd_depth.north;
	  bdnorth(bd_indx_r) = 0;
	  bd_depth.east = bdeast;
	  bd_depth.north = bdnorth;
  	}

      } 
*/


    write, "\nStatistics: \r";
    write, format="Total number of records processed = %d\n",tot_count;
/*
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
      if (tot_count != ba_count) {
        pbd = float(bd_count)*100.0/(tot_count-ba_count);
      } else {
	pbd = 100.0;
      }
      write, format = "%5.2f%% of total records with good "+
                      "first returns had false depth! \n",pbd; 
    } else 
	write, "No bathy records found"
*/
    no_append = 0;
    rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);	

    tkcmd, swrite(format="send_rnarr_to_l1pro %d %d %d\n", rn_arr(1,), rn_arr(2,), rn_arr_idx(1:-1))
    return depth_all;

   } else write, "No Data in selected flightline. Good Bye!";

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

func plot_bathy(depth_all, fs=, ba=, de=, fint=, lint=, win=, cmin=, cmax=, msize=, marker=, skip=) {
  /* DOCUMENT plot_bathy(depth_all, fs=, ba=, de=, int=, win=)
     This function plots bathy data in window, "win" depending on which variable is set.
     If fs = 1, first surface returns are plotted referenced to NAD83.
     If ba = 1, subaqueous topography is plotted referenced to NAD83.
     If de = 1, water depth in meters is plotted.
     If int = 1, intensity values are plotted.

  */
  if (!(skip)) skip = 1
  if (is_void(win)) win = 5;
  //window, win;fma;
  if (fs) {
     indx = where(depth_all.north != 0);
     plcm, depth_all.elevation(indx)(1:0:skip)/100., depth_all.north(indx)(1:0:skip)/100., depth_all.east(indx)(1:0:skip)/100., cmin=cmin, cmax=cmax, msize = msize, marker = marker;
  } else if (ba) {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, (depth_all.elevation(indx)(1:0:skip) + depth_all.depth(indx)(1:0:skip))/100., depth_all.north(indx)(1:0:skip)/100., depth_all.east(indx)(1:0:skip)/100., cmin = cmin, cmax = cmax, msize = msize, marker=marker;
  } else if (fint) {
    indx = where(depth_all.north != 0);
    plcm, depth_all.first_peak((indx)(1:0:skip)), depth_all.north((indx)(1:0:skip))/100., depth_all.east((indx)(1:0:skip))/100., cmin = cmin, cmax = cmax, msize = msize, marker=marker;
  } else if (lint) {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, depth_all.bottom_peak((indx)(1:0:skip)), depth_all.north((indx)(1:0:skip))/100., depth_all.east((indx)(1:0:skip))/100., cmin = cmin, cmax = cmax, msize = msize, marker=marker;
  } else {
    indx = where((depth_all.north != 0) & (depth_all.depth !=0));
    plcm, depth_all.depth((indx)(1:0:skip))/100., depth_all.north((indx)(1:0:skip))/100., depth_all.east((indx)(1:0:skip))/100., cmin = cmin, cmax = cmax, msize = msize, marker=marker;
  }
//////////////   colorbar, cmin, cmax, drag=1;
}


func hist_depth( depth_all, win=, dtyp=, dofma=, binsize= ) {
/* DOCUMENT hist_depth(depth_all)

   Return the histogram of the good depths.  The input depth_all 
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs: 
	depth_all   An array of "GEOALL" structures.  
	dytp = display type (water surface or bathymetry)
	dofma= set to 0 if you do not want to clear the screen. Defaults to 1
	binsize= size of the histogram bin in cm. Default=100cm.

 amar nayegandhi 10/6/2002.  similar to hist_fs by W. Wright

See also: GEOALL
*/


  if ( is_void(win) ) 
	win = 7;

  if (is_void(dofma)) dofma=1;

  if (is_void(binsize)) binsize=100;

// build an edit array indicating where values are between -60 meters
// and 3000 meters.  Thats enough to encompass any EAARL data than
// can ever be taken.
  gidx = (depth_all.elevation > -6000) | (depth_all.elevation <300000);  

// Now kick out values which are within 1-meter of the mirror and depth = 0. Some
// functions will set the elevation to the mirror value if they cant
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
  h = histogram( (depthy / int(binsize)) + 1 );
  hind = where(h == 0);
  if (is_array(hind)) 
    h(hind) = 1;
  e = span( minn, maxx, numberof(h) ) + 1 ; 
  w = current_window();
  window,win; fma; plg,h,e;
  pltitle(swrite( format="Depth Histogram %s", data_path));
  xytitles,"Depth Elevation (meters)", "Number of measurements"
  window_select, w;
  return [e,h];
}

func clean_bathy(depth_all, rcf_width=) {
  /* DOCUMENT clean_bathy(depth_all, rcf_width=)
      This function cleans the bathy data.
      Optionally set rcf_width to the elevation width (in meters) to use the RCF filter on the entire data set.For e.g., if you know your data set can have a maximum extent of -1m to -25m, then set rcf_width to 25.  This will remove the outliers from the data set.
    amar nayegandhi 03/07/03
  */
  if (numberof(depth_all) != numberof(depth_all.north)) {
      write, "converting GEOALL to GEO...";
      depth_all = geoall_to_geo(depth_all);
  }
  write, "cleaning geo data...";
  idx = where(depth_all.north != 0);
  if (is_array(idx)) 
    depth_all = depth_all(idx);
  idx = where(depth_all.depth != 0)
  if (is_array(idx)) 
    depth_all = depth_all(idx);
    // commented out section below because it would not work for high elevations.
   /* 
    idx = where(depth_all.elevation < (0.75*depth_all.melevation));
    if (is_array(idx))
    depth_all = depth_all(idx);
  */
  if (is_array(rcf_width)) {
    write, "using rcf to clean data..."
    //run rcf on the entire data set
    ptr = rcf((depth_all.elevation+depth_all.depth), rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
        depth_all = depth_all(*ptr(1));
    } else {
        depth_all = 0
    }
  }
  write, "cleaning completed.";
  return depth_all
}

func geoall_to_geo(data) {
   /* DOCUMENT geoall_to_geo(data)
      this function converts the data array from the GEO_ALL structure (in raster format) to the GEO structure in point format.
      amar nayegandhi
     03/07/03
   */
   
 if (numberof(data) != numberof(data.north)) {
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
	        data_new.soe = data.soe(indx);
  } else data_new = data;

  return data_new
}

  

