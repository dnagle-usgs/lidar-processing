// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";
/*
   For processing bathymetry data using the topographic georectification.
*/

func make_fs_bath(d, rrr, avg_surf=, sample_interval=) {
/* DOCUMENT make_fs_bath (d, rrr, avg_surf=, sample_interval=)

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

  local raster, pulse;
  parse_rn, rrr.rn, raster, pulse;

  surface_window = 100;
  altitude_thresh = 5000;
  pulse_window = 25;

  for (i=1; i<=len; i=i+1) {
    offset(*) = 0.;
    // code added by AN (12/03/04) to make all surface returns across a raster
    // to be the average of the fresnel reflections.  the surface return is
    // determined from the reflections that have the first channel saturated
    // and come from close to the center of the swath.
    if(avg_surf) {
      iidx = where((rrr(i).intensity > 220) & (abs(60 - pulse(,i)) < pulse_window));
      if(!is_array(iidx)) {
        write,format= "No water surface Fresnel reflection in raster rn = %d\n", raster(1,i);
      } else {
        elvs = median(rrr(i).elevation(iidx));
        elvsidx = where(abs(rrr(i).elevation(iidx)-elvs) <= surface_window);
        elvs = avg(rrr(i).elevation(iidx(elvsidx)));
        old_elvs = rrr(i).elevation;
        indx = where(rrr(i).melevation - rrr(i).elevation > altitude_thresh);
        if (is_array(indx)) rrr(i).elevation(indx) = int(elvs);
        // now rrr.fs_rtn_centroid will change depending on where in time the
        // surface occurs for each laser pulse with respect to where its
        // current surface elevation is. this change is defined by the array
        // offset
        offset = ((old_elvs - elvs)/(CNSH2O2X*sample_interval*100.));
      }
    }
    indx = where((d(,i).idx > 0) & (abs(offset) < 100));
    if (is_array(indx)) {
      fs_rtn_cent = rrr(i).fs_rtn_centroid(indx)+offset(indx);
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

func compute_depth(data, sample_interval=) {
/* DOCUMENT compute_depth(data, sample_interval=)
  This function computes the depth in water using the mirror position and the
  angle of refraction in water. The input parameters defined are as follows:

  data= Data array of structure GEOALL.

  This function returns the data array with computed depth.

  SEE ALSO: make_fs_bath, make_bathy
*/
  // Force copy so that original isn't modified in place.
  data = noop(data);

  dist = data.sr2/10. * NS2MAIR * sample_interval;

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
  defined in that region.

    latutm= Passed to gga_win_sel, if q is void.
    q= Indices into extern pnav where data should be processed.
    avg_surf= Set to 1 if the surface returns should be averaged to the first
      surface returns at the center of the swath.

  Returns an array depth_all of GEOALL.

  Please ensure that the tans and pnav data have been loaded before executing
  make_bathy. See rbpnav() and rbtans() for details. The structure BATH_CTL
  must be initialized as well. See define_bath_ctl().

  SEE ALSO: first_surface, run_bath, make_fs_bath, rbpnav, rbtans,
    define_bath_ctl
*/
  extern tans, pnav;
  depth_all = [];
  sample_interval = 1.0;

  if(is_void(tans))
    error, "TANS/INS data not loaded";
  if(is_void(pnav))
    error, "PNAV data not loaded";

  if (!is_array(q)) {
    // select a region using function gga_win_sel in rbgga.i
    q = gga_win_sel(latutm=latutm, llarr=llarr);
  }

  // find start and stop raster numbers for all flightlines
  status, start, msg="Scanning flightlines for rasters...";
  raster_ranges = sel_region(q);

  if(is_void(raster_ranges)) {
    write, "No Data in selected flightline. Good Bye!";
    return [];
  }
  raster_starts = raster_ranges(1,);
  raster_stops = raster_ranges(2,);
  raster_ranges = [];

  count = numberof(raster_starts);

  for(i = 1; i <= count; i++) {
    if((raster_starts(i) != 0)) {
      msg_prefix = swrite(format="Line %d/%d; ", i, count);
      msg = msg_prefix + "Step 1/3: Processing bathymetry...";
      write, format="Processing segment %d of %d for bathymetry\n", i, count;
      status, start, msg=msg;
      depth = run_bath(start=raster_starts(i), stop=raster_stops(i), msg=msg);
      if(depth == 0) return 0;

      msg = msg_prefix + "Step 2/3: Processing surface...";
      write, "Processing for first_surface...";
      status, start, msg=msg;
      surface = first_surface(start=raster_starts(i), stop=raster_stops(i),
        usecentroid=1, msg=msg);

      msg = msg_prefix + "Step 3/3: Merging and correcting depths...";
      status, start, msg=msg;
      write, "Using make_fs_bath for submerged topography...";
      depth = make_fs_bath(depth, surface, avg_surf=avg_surf,
        sample_interval=sample_interval);

      // make depth correction using compute_depth
      write, "Correcting water depths for Snells law...";
      grow, depth_all, compute_depth(depth, sample_interval=sample_interval);
    }
  }
  status, finished;

  write, "\nStatistics:";
  write, format="Total number of records processed = %d\n",
      numberof(depth_all.elevation);

  return depth_all;
}
