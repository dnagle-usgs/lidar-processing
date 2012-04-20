// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
/*
   For processing bathymetry data using the topographic georectification.
*/

func make_fs_bath(d, rrr, avg_surf=) {
/* DOCUMENT make_fs_bath (d, rrr, avg_surf=)

  This function makes a depth or bathymetric image using the georectification
  of the first surface return. The parameters are as follows:

    d: Array of structure BATHPIX containing depth information. This is the
      return value of function run_bath.

    rrr: Array of structure R containing first surface information. This the is
      the return value of function first_surface.

    avg_surf= Set to 1 if the surface returns should be averaged to the first
      surface returns at the center of the swath.

   The return value depth is an array of structure GEOALL.

   SEE ALSO: first_surface, run_bath
*/
  // d is the depth array from bathy.i
  // rrr is the topo array from surface_topo.i
  default, avg_surf, 0;

  if(dimsof(d)(3) < numberof(rrr))
    rrr = rrr(:dimsof(d)(3));
  if(numberof(rrr) < dimsof(d)(3))
    d = d(,:numberof(rrr));

  len = numberof(rrr);
  geodepth = array(GEOALL, len);

  offset = array(double, 120);

  for (i=1; i<=len; i=i+1) {
    // code added by AN (12/03/04) to make all surface returns across a raster
    // to be the average of the fresnel reflections.  the surface return is
    // determined from the reflections that have the first channel saturated
    // and come from close to the center of the swath.
    if (avg_surf) {
      iidx = where((rrr(i).intensity > 220) & ((rrr(i).rn>>24) > 35) & ((rrr(i).rn>>24) < 85));
      if (is_array(iidx)) {
        elvs = median(rrr(i).elevation(iidx));
        elvsidx = where(abs(rrr(i).elevation(iidx)-elvs) <= 100) ;
        elvs = avg(rrr(i).elevation(iidx(elvsidx)));
        old_elvs = rrr(i).elevation;
        indx = where(rrr(i).elevation < (rrr(i).melevation - 5000));
        if (is_array(indx)) rrr(i).elevation(indx) = int(elvs);
        // now rrr.fs_rtn_centroid will change depending on where in time the
        // surface occurs for each laser pulse with respect to where its
        // current surface elevation is. this change is defined by the array
        // offset
        offset = ((old_elvs - elvs)/(CNSH2O2X*100.));
      } else {
        write,format= "No water surface Fresnel reflection in raster rn = %d\n",(rrr(i).rn(1) & 0xffffff);
        offset(*) = 0;
      }
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
      geodepth(i).depth(indx) = int((-d(,i).idx(indx) + fs_rtn_cent ) * CNSH2O2X *100.-0.5);
      geodepth(i).sr2(indx) =int((d(,i).idx(indx) - fs_rtn_cent)*10);
    }
  }

  geodepth.rn = rrr.rn;
  geodepth.north = rrr.north;
  geodepth.east = rrr.east;
  geodepth.elevation = rrr.elevation;
  geodepth.mnorth = rrr.mnorth;
  geodepth.meast = rrr.meast;
  geodepth.melevation = rrr.melevation;
  geodepth.soe = rrr.soe;
  geodepth.bottom_peak = d.bottom_peak;
  geodepth.first_peak = d.first_peak;

  return geodepth;
}

func compute_depth(data) {
/* DOCUMENT compute_depth(data)
  This function computes the depth in water using the mirror position and the
  angle of refraction in water. The input parameters defined are as follows:

  data= Data array of structure GEOALL.

  This function returns the data array with computed depth.

  SEE ALSO: make_fs_bath, make_bathy
*/
  // Force copy so that original isn't modified in place.
  data = noop(data);

  dist = data.sr2/10. * NS2MAIR;

  ref = [data.meast/100., data.mnorth/100., data.melevation/100.];
  fs = [data.east/100., data.north/100., data.elevation/100.];

  dims = dimsof(ref);
  ref = reform(ref, [2, numberof(ref)/3, 3]);
  fs = reform(fs, [2, numberof(fs)/3, 3]);
  dist = dist(*);

  be = ba = array(double, dimsof(fs));

  valid = fs(..,3) <= ref(..,3);
  if(anyof(valid)) {
    w = where(valid);
    be(w,) = point_project(ref(w,), fs(w,), dist(w), tp=1);
    ba(w,) = snell_be_to_bathy(fs(w,), be(w,));
  }
  if(nallof(valid)) {
    w = where(!valid);
    be(w,) = point_project(ref(w,), fs(w,), -dist(w), tp=1);
    ba(w,) = snell_be_to_bathy(fs(w,), be(w,));
  }

  fs = reform(fs, dims);
  ba = reform(ba, dims);

  data.east = ba(..,1)*100;
  data.north = ba(..,2)*100;
  data.depth = (ba(..,3) - fs(..,3))*100;
  return data;
}

func make_bathy(latutm=, q=, avg_surf=) {
/* DOCUMENT make_bathy(latutm=, q=, avg_surf=)
  This function allows a user to define a region on the gga plot of flightlines
  (usually window 6) to write out a 'level 1' file and plot a depth image
  defined in that region. The input parameters are:

  opath: ouput path where the output file must be written
  ofname:  output file name

  Returns:
  This function returns the array depth_arr.

  Please ensure that the tans and pnav data have been loaded before executing
  make_bathy.  See rbpnav() and rbtans() for details.  The structure BATH_CTL
  must be initialized as well. See define_bath_ctl()

  SEE ALSO: first_surface, run_bath, make_fs_bath
*/
  extern tans, pnav, rn_arr;
  depth_all = [];

  if(is_void(tans))
    error, "TANS/INS data not loaded";
  if(is_void(pnav))
    error, "PNAV data not loaded";

  if (!is_array(q)) {
    // select a region using function gga_win_sel in rbgga.i
    q = gga_win_sel(2, latutm=latutm, llarr=llarr);
  }

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q);

  if(is_void(rn_arr)) {
    write, "No Data in selected flightline. Good Bye!";
    return [];
  }

  no_t = numberof(rn_arr(1,));

  open_seg_process_status_bar;

  for (i=1;i<=no_t;i++) {
    if ((rn_arr(1,i) != 0)) {
      write, format="Processing segment %d of %d for bathymetry\n", i, no_t;
      d = run_bath(start=rn_arr(1,i), stop=rn_arr(2,i));
      if ( d == 0 ) return 0;
      write, "Processing for first_surface...";
      rrr = first_surface(start=rn_arr(1,i), stop=rn_arr(2,i), usecentroid=1);
      a=[];
      write, "Using make_fs_bath for submerged topography...";
      depth = make_fs_bath(d,rrr, avg_surf=avg_surf);

      // make depth correction using compute_depth
      write, "Correcting water depths for Snells law...";
      grow, depth_all, compute_depth(depth);
    }
  }

  if (_ytk) tkcmd, "destroy .seg";

  write, "\nStatistics:";
  write, format="Total number of records processed = %d\n",
      numberof(depth_all.elevation);

  return depth_all;
}
