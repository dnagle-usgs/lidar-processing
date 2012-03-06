require, "eaarl.i";
/*
   Orginal by Amar Nayegandhi

   7/6/02 WW
	Minor changes and additions made to many DOCUMENTS, comments,
        and a couple of divide by zero error checks made.

  This program is used to process bathymetry data using the 
  topographic georectification.
*/


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


   The return value depth is an array of structure GEOALL.

   SEE ALSO: first_surface, run_bath
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
   iidx = where((rrr(i).intensity > 220) & ((rrr(i).rn>>24) > 35) & ((rrr(i).rn>>24) < 85));
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
    // 2009-03-16: rwm: changed:  = short() to: = int()
    geodepth(i).depth(indx) = int((-d(,i).idx(indx) + fs_rtn_cent ) * CNSH2O2X *100.-0.5);
    bath_arr(indx,i) = long(((-d(,i).idx(indx)+fs_rtn_cent ) * CNSH2O2X *100) + rrr(i).elevation(indx));
    // 2009-04-15: amar: change: short() to int()
    geodepth(i).sr2(indx) =int((d(,i).idx(indx) - fs_rtn_cent)*10); 
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

SEE ALSO: make_fs_bath, make_bathy

*/
   if(!is_void(ipath)) {
      files = [];
      if(is_void(data_ptr) && is_void(fname)) {
      /* extract all data with *.bin extension from directory*/
         files = find(ipath, glob=["*.bin", "*.edf"]);
      } else if(!is_void(fname)) {
      /* extract data from file(s) */
         files = file_join(ipath, fname);
      }
      if(!is_void(files)) {
         data_ptr = array(pointer, numberof(files));
         for(i = 1; i <= numberof(files); i++)
            data_ptr(i) = &edf_import(files(i));
      }
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
        // if only one file, then append
         edf_export, file_join(ipath, ofname), data, append=(i == 1);
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

      SEE ALSO: first_surface, run_bath, make_fs_bath 
*/
   
   extern edb, soe_day_start, bath_ctl, tans, pnav, type, utm, depth_all, rn_arr, rn_arr_idx, ba_depth, bd_depth;
   depth_all = [];
   
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

    write, "\nStatistics: \r";
    write, format="Total number of records processed = %d\n",tot_count;

    no_append = 0;
    rn_arr_idx = (rn_arr(dif,)(,cum)+1)(*);	
    return depth_all;

   } else write, "No Data in selected flightline. Good Bye!";

}
