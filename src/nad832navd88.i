// vim: set ts=2 sts=2 sw=2 ai sr et:
/*
   amar nayegandhi, original nad832navd88.i
   charlene sullivan, modified form of nad832navd88.i for use of GEOID 96 model
   The following code has been adapted from the GEOID 99 model available at
   http://www.ngs.noaa.gov/GEOID/GEOID99/
   The original DISCLAIMER applies to this as well.
   David Nagle, updated to reflect more recent algorithms used by NGS in
   GEOID09 model.
*/

func geoid_load(fn) {
/* DOCUMENT g = geoid_load(fn)
  Loads the GEOID data from a file.

  This performs some minor adjustments to the different kinds of possibly
  source files that allow them all to be used the same way, as well as
  performing some minor corrections.

  Specifically:
    - The .geo format GEOID files are documented to have a loss of accuracy
      for the dla and dlo fields. The recommended accuracy adjustment is
      applied.
    - The ncols and nrows have slightly different meanings from format to
      format and may not match the actual dimensions of the data. They are
      replaced here with the actual dimensions of the data.
    - The .geo format GEOID files use negative longitudes for glomn, while
      all other formats use positive longitudes. This adds 360 to glomn in
      that case, to put them in the same range of values.
    - The .geo and .bin GEOID files have their data in a "data" variable.
      However, Yorick .pbd files store a variable name in "vname" that
      dictates what the name of the data variable is. In either case, the
      data is loaded into a "data" variable for uniform use.

  The return value is a Yeti hash with these fields:
    g.glamn - southernmost latitude in whole degrees
    g.glomn - westernmost longitude in whole degrees
    g.dla - distance interval in latitude in degrees
    g.dlo - distance interval in longitude in degrees
    g.nrows - number of rows (latitude)
    g.ncols - number of columns (longitude)
    g.itype - always equal to one (indicates that data are four-byte floats)
    g.data - array of elevation offsets
*/
// Original David Nagle 2009-12-10
  f = is_string(fn) ? geoid_open(fn) : fn;

  dls = [f.dla, f.dlo];
  if(typeof(f.dla) == "float")
    dls = (int(dls*3600.)+1)/3600.;

  data = has_member(f, "vname") ? get_member(f, f.vname) : f.data;

  ncols = nrows = [];
  assign, dimsof(data), , ncols, nrows;

  glomn = f.glomn < 0 ? 360 + f.glomn : f.glomn;

  return h_new(
    glamn=f.glamn,
    glomn=glomn,
    dla=dls(1),
    dlo=dls(2),
    nrows=nrows,
    ncols=ncols,
    itype=f.itype,
    data=data
  );
}

func geoid_open(fn) {
/* DOCUMENT f = geoid_open(fn)
  Opens a GEOID file for NAVD-88 conversions.  This is primarily for internal
  use; most users will want to use geoid_load instead.

  The GEOID file (specified by fn) may be any of the following formats.
    - Yorick pbd file (*.pbd) created with geoid_data_to_pbd
    - NGS binary file for GEOID96 (*.geo; little endian)
    - NGS binary file for other years (*.bin; little or big endian)

  The return value is a filehandle to the binary file. The following variables
  will be defined in all cases:
    f.glamn - southernmost latitude in whole degrees
    f.glomn - westernmost longitude in whole degrees
    f.dla - distance interval in latitude in degrees
    f.dlo - distance internval in longitude in degrees
    f.nrows - number of rows (latitude)
    f.ncols - number of columns (longitude)
    f.itype - always equal to one (indicates that data are four-byte floats)

  Additionally, the data array itself will be defined differently depending on
  which kind of file was opened.

  Yorick files will have two variables:
    f.vname - the name of the variable containing the data
    f."??" - the data itself, named as per f.vname

  NGS binary files will have one variable:
    f.data - the data

  For NGS binary files from GEOID96 (*.geo), the ncols value will be one value
  lower than it should be.
*/
// Original David Nagle 2009-12-10
  ext = strlower(file_extension(fn));

  if(ext == ".pbd")
    return openb(fn);

  if(ext == ".geo") {
    order = ["geo", "little", "big"];
  } else {
    order = ["little", "big", "geo"];
  }

  for(i = 1; i <= numberof(order); i++) {
    f = open(fn, "rb");
    if(order(i) == "big")
      sun_primitives, f;
    else
      i86_primitives, f;
    if(order(i) == "geo")
      __geoid_geo_addvars, f;
    else
      __geoid_bin_addvars, f;
    if(f.itype == 1)
      return f;
    else
      close, f;
  }
  error, "Unable to open geoid file: " + file_tail(fn);
}

func __geoid_geo_addvars(f) {
/* DOCUMENT __geoid_geo_addvars, f
  Adds the geoid variables to a filestream of a .geo file.

  I think this format is a FORTRAN-based format. The first 64 bytes are a
  character array that seems to always be the literal string:
    'GEOID EXTRACTED REGION                                  GEOGRD'
  Following that are the variable fields as defined below.

  The ncols and nrows variables are slightly misnamed in this case. They
  appear to actually be upper indexes for the two dimensional array, which
  apparently has a 0-origin. The array actually has dims [2, ncols+1,
  nrows+1]; however, the first row is ignored because it contains the header
  information. This is why the offset and dimensions are calculated as they
  are.
*/
// Original David Nagle 2009-12-10
  add_variable, f, 64, "ncols", int;
  add_variable, f, 68, "nrows", int;
  add_variable, f, 72, "itype", int;
  add_variable, f, 76, "glomn", float;
  add_variable, f, 80, "dlo", float;
  add_variable, f, 84, "glamn", float;
  add_variable, f, 88, "dla", float;
  offset = 4 * (f.ncols + 1);
  add_variable, f, offset, "data", float, [2, f.ncols + 1, f.nrows];
}

func __geoid_bin_addvars(f) {
/* DOCUMENT __geoid_bin_addvars, f
  Adds the geoid variables to a filestream of a .bin file.

  This format is well documented on the NGS website.
*/
  add_variable, f, -1, "glamn", double;
  add_variable, f, -1, "glomn", double;
  add_variable, f, -1, "dla", double;
  add_variable, f, -1, "dlo", double;
  add_variable, f, -1, "nrows", int;
  add_variable, f, -1, "ncols", int;
  add_variable, f, -1, "itype", int;
  add_variable, f, -1, "data", float, [2, f.ncols, f.nrows];
}

func geoid_data_to_pbd(gfname=, pbdfname=, initialdir=, geoid_version=) {
/* DOCUMENT geoid_data_to_pbd(gfname=, pbdfname=, initialdir=, geoid_version=)
  Attempts to convert GEOIDxx ascii data files to pbd. The ascii data files
  are available on the NGS website:
    ftp://ftp.ngs.noaa.gov/pub/pcsoft/geoid96
    http://www.ngs.noaa.gov/GEOID/GEOID99/dnldgeo99ot1.html
    http://www.ngs.noaa.gov/GEOID/GEOID03/download.html
  The data from the file will also be returned at the end.
*/
// original amar nayegandhi 07/10/03
// modified 01/12/06 -- amar nayegandhi to add GEOID03
// modified 09/25/06 -- charlene sullivan to add GEOID96
  default, initialdir, "/dload/geoid99_data/";
  if(is_void(gfname))
    gfname = get_openfn(initialdir=initialdir, filetype="*.asc",
      title="Open GEOIDxx Ascii Data File");

  // split path and file name
  gpath = fix_dir(file_dirname(gfname));
  gfile = file_tail(gfname);

  default, pbdfname, file_rootname(gfname) + ".pbd";

  // open geoid ascii data file to read
  write, "reading geoid ascii data";
  gf = open(gfname, "r");
  // read header data off the geoid data file
  glamn = glomn = dla = dlo = 0.0;
  nrows = ncols = itype =dla1 = dlo1 = 0;
  if (strmatch(geoid_version,"GEOID96",1)) {
     read, gf, ncols, nrows, itype, glomn, dlo, glamn, dla;
     // account for loss of precision in GEOID96 grid file headers
     dla1 = int(dla*3600.0) + 1;
     dlo1 = int(dlo*3600.0) + 1;
     dla = double(dla1)/3600.0;
     dlo = double(dlo1)/3600.0;
  } else {
     read, gf, glamn, glomn, dla, dlo;
     read, gf, nrows, ncols, itype;
  }
  data = array(double, ncols, nrows);
  read, gf, data;
  write, "writing geoid pbd data";
  pf = createb(pbdfname);
  vname = file_rootname(gfile);
  save, pf, glamn, glomn, dla, dlo, nrows, ncols, itype, vname;
  add_variable, pf, -1, vname, structof(data), dimsof(data);
  get_member(pf,vname) = data;
  close, pf;
  return data;
}

func navd88_geoids_available(void) {
/* DOCUMENT geoids = navd88_geoids_available()
  Returns a list of available geoids. This simply checks for directories that
  match GEOID* in the geoid_data_root. Returns them as an array of strings in
  an arbitrary order.

  For example:

    > navd88_geoids_available()
    ["06","99","03","09","96"]
*/
  dirs = lsdirs(alpsrc.geoid_data_root, glob="GEOID*");
  if(!is_void(dirs))
    return strpart(dirs, 6:);
  else
    return [];
}

func navd88_geoid_file_coverage(lon, lat, geoid, gdata_dir=) {
/* DOCUMENT files = navd88_geoid_file_coverage(lon, lat, geoid, gdata_dir=)
  Given arrays of lon and lat and a geoid, this will return a list of geoid
  files that cover each of the given points. The result will have the same
  dimensions as lon. If a file couldn't be found to cover a point, it will be
  set to string(0).
*/
  default, gdata_dir, file_join(alpsrc.geoid_data_root, "GEOID"+geoid);

  if(lon(1) < 0)
    lon = lon + 360.;

  // Get list of candidate GEOID files
  files = [];
  grow, files, find(gdata_dir, searchstr="*.pbd");
  grow, files, find(gdata_dir, searchstr="*.bin");
  grow, files, find(gdata_dir, searchstr="*.geo");

  if(!numberof(files)) {
    write, "No GEOID files found, aborting.";
    return [];
  }

  files = files(sort(file_tail(files)));

  // Get bounds for each file
  latmin = latmax = lonmin = lonmax = array(double, numberof(files));
  for(i = 1; i <= numberof(files); i++) {
    g = geoid_load(files(i));
    latmin(i) = g.glamn;
    lonmin(i) = g.glomn;
    latmax(i) = latmin(i) + g.dla * (g.nrows - 1);
    lonmax(i) = lonmin(i) + g.dlo * (g.ncols - 1);
    g = [];
  }

  // Calculate the file to use for each point
  which = array(string(0), dimsof(lon));

  for(i = 1; i <= numberof(files); i++) {
    need = where(!which);
    if(!numberof(need))
      break;
    idx = data_box(lon(need), lat(need), lonmin(i), lonmax(i),
      latmin(i), latmax(i));
    if(numberof(idx))
      which(need(idx)) = files(i);
  }

  return which;
}

func nad832navd88(lon, lat, &elv, gdata_dir=, geoid=, verbose=) {
/* DOCUMENT navd882nad83, lon, lat, &elv, gdata_dir=, geoid=
  Converts data from NAD83 to NAVD88. lon and lat should be in degrees. elv
  should be in meters and is updated in place. See nad832navd88offset for a
  description of the options.
*/
  if(is_pointer(elv)) {
    // If elv is a pointer then we need to loop. :(
    offset = nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
      verbose=verbose);
    for(i = 1; i <= numberof(elv); i++)
      *elv(i) -= offset(i);
  } else {
    elv() -= nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
      verbose=verbose);
  }
}

func navd882nad83(lon, lat, &elv, gdata_dir=, geoid=, verbose=) {
/* DOCUMENT navd882nad83, lon, lat, &elv, gdata_dir=, geoid=
  Converts data from NAVD88 to NAD83. lon and lat should be in degrees. elv
  should be in meters and is updated in place. See nad832navd88offset for a
  description of the options.
*/
  if(is_pointer(elv)) {
    // If elv is a pointer then we need to loop. :(
    offset = nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
      verbose=verbose);
    for(i = 1; i <= numberof(elv); i++)
      *elv(i) += offset(i);
  } else {
    elv += nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
      verbose=verbose);
  }
}

func nad832navd88offset(lon, lat, gdata_dir=, geoid=, verbose=, interpolator=) {
/*DOCUMENT offset = nad832navd88offset(lon, lat, gdata_dir=, geoid_version=,
  interpolator=)
  This function provides the offset between NAD83 and NAVD88 data at a given
  lat/lon location using the GEOIDxx model.

  Parameters:
    lon: An array of longitude values in degrees.
    lat: An array of latitude values in degrees.

  Options:
    gdata_dir= The location where the geoid data files reside. This defaults
      based on the geoid= and based on the geoid_data_root specified in
      .alpsrc.
    geoid= The geoid version to use. Possible values:
        geoid="96"     For GEOID96
        geoid="99"     For GEOID99
        geoid="03"     For GEOID03
        geoid="09"     For GEOID09 (default)
      If gdata_dir= is specified, then geoid= is ignored.
    interpolator= The interpolator function to use. Default is:
        interpolator=n88_interp2d
      See help on n88_interp2d for further details.

  Output:
    The returns an array of offset values between NAD83 and NAVD88 for each
    lon/lat coordinate specified. To convert from NAD83 to NAVD88, use
    elevation - offset. To convert from NAVD88 to NAD83, use elevation +
    offset.

  Note on paths:
    If gdata_dir is not used, then the data is assumed to be in a directory
    named based on the geoid; for example, geoid="09" would be in "GEOID09".
    That directory will be assumed to be located in alpsrc.geoid_data_root.

  Note on files:
    The function will use the first geoid data file it finds that will
    suffice for each point. *.pbd takes precedence over *.bin, which takes
    precedence over *.geo.
*/
// Amar Nayegandhi 07/10/03, original nad832navd88
// Charlene Sullivan 09/21/06, modified for use of GEOID96 model
// David Nagle 11/21/07, modified to provide offset to facilate 2-way
//    conversions
  extern alpsrc;
  default, geoid, "03";
  default, gdata_dir, file_join(alpsrc.geoid_data_root, "GEOID"+geoid);
  default, verbose, 1;
  default, interpolator, n88_interp2d;

  if(lon(1) < 0)
    lon = lon + 360.;

  which = navd88_geoid_file_coverage(lon, lat, geoid, gdata_dir=gdata_dir);
  // navd88_geoid_file_coverage spits out a warning, so we don't need to here.
  // Just abort.
  if(is_void(which)) return;

  // This will hold our return results
  offset = array(0., numberof(lon));

  // Do any lack? Warn!
  if(noneof(which)) {
    write, format="%s", "\n ** No data is in area covered by GEOID. No change made. **\n";
    return offset;
  } else if(nallof(which)) {
    write, format="\n ** %d points (of %d) in areas not covered by GEOID. Those points will remain unchanged. **\n", numberof(where(!which)), numberof(which);
  }

  // Get a list of which files are needed
  needed = set_remove_duplicates(which(where(which)));

  for(i = 1; i <= numberof(needed); i++) {
    if(verbose)
      write, format="grid file = %s\n", files(needed(i));

    w = where(which == needed(i));
    g = geoid_load(needed(i));

    // Figure out where we are in the lat/lon grid
    ix = 1 + (lon(w) - g.glomn) / g.dlo;
    iy = 1 + (lat(w) - g.glamn) / g.dla;

    offset(w) = interpolator(ix, iy, g.data);
  }
  return offset;
}

func n88_interp2d(x, y, f) {
/* DOCUMENT n88_interp2d(x, y, f)
  Performs 2-dimensional interpolation on f at point(s) x, y.

  If x and y are valid integer indices into f, then the following will hold
  true:
    f(x,y) = n88_interp2d(x,y,f)
  All other values will be interpolated.

  This function is effectively a placeholder for one of the other 2d interp
  functions. If C-ALPS is available, then calps_n88_interp_spline2d is used
  internally. Otherwise, n88_interp_qfit2d is used instead.

  This function is the default function used for GEOID offset calculation. If
  you would like to override the function used, you can redfine this function,
  for example:
    n88_interp2d = n88_interp_spline2d
  Or:
    n88_interp2d = calps_n88_interp_qfit2d

  The spline and qfit interpolation functions generally agree to within 1 cm.
  The Yorick implementation of spline is much, much slower than the Yorick
  implementation of qfit, which is why qfit is used by default when C-ALPS is
  not available. The C versions of both algorithms run sufficiently fast that
  there is no noticeable speed difference. The spline algorithm is equivalent
  to what NGS currently uses in their conversion program. The qfit algorithm
  matches a much older version of their software.
*/
  if(is_func(calps_n88_interp_spline2d))
    return calps_n88_interp_spline2d(x, y, f);
  else
    return n88_interp_qfit2d(x, y, f);
}
// Make a backup in case it's overwritten by the user.
__n88_interp2d = n88_interp2d;

func n88_splinefit(x, f, offset, size) {
/* DOCUMENT n88_splinefit(x, f, offset, size)
  Performs a spline fit using the number of points specified by size.
  Algorithm derived from NGS code associated with the GEOID 09 model.

  Parameters:
    x: The value to interpolate at.
    f: Known values.
    offset: Offset into f that x is referenced against.
    size: Number of points to use for spline.

  Normally, x will be between 1 and size. If it is outside of that range,
  extrapolation is used.

  The following pseudo-code identity holds true:
    for(i = 1; i <= size; i++)
      f(offset+i-1) == n88_splinefit(i, f, offset, size)

  Any other value for x is interpolated on the spline that passes through
  those points.
*/
  // Calculate spline moments
  q = r = array(0., size, dimsof(x));
  for(k = 2; k < size; k++) {
    kk = k + offset - 1;
    p = q(k-1,..)/2 + 2;
    q(k,..) = -0.5/p;
    r(k,..) = (3.*(f(kk+1) - 2.*f(kk) + f(kk-1)) - r(k-1,..)/2.)/p;
  }
  kk = [];
  for(k = size - 1; k > 1; k--)
    r(k,..) += q(k,..) * r(k+1,..);
  q = [];

  result = array(double, dimsof(x));

  elo = x <= 1;
  ehi = x >= size;
  spl = !(elo | ehi);

  if(anyof(elo)) {
    w = where(elo);
    o = offset(w);
    result(w) = f(o) + (x(w)-1) * (f(o+1) - f(o) - r(2,w)/6.);
    w = o = [];
  }
  elo = [];

  if(anyof(ehi)) {
    w = where(ehi);
    o = offset(w) + size - 1;
    result(w) = f(o) + (x(w)-size) * (f(o) - f(o-1) + r(size-1,w)/6.);
    w = o = [];
  }
  ehi = [];

  if(anyof(spl)) {
    // Spline interpolation. This code is sprawled out in order to reduce
    // memory impact and improve performance.
    w = where(spl);
    spl = [];
    jj = long(x(w));
    xx = x(w) - jj;
    x = [];
    ro = size*(w-1) + jj;
    rr0 = r(ro);
    rr1 = r(ro+1);
    r = [];
    ojj = offset(w) - 1 + jj;
    offset = jj = [];
    result(w) = (rr1-rr0)/6;
    result(w) *= xx;
    result(w) += rr0/2;
    result(w) *= xx;
    result(w) += f(ojj+1)
    result(w) -= f(ojj)
    result(w) -= rr0/3;
    result(w) -= rr1/6;
    result(w) *= xx;
    result(w) += f(ojj);
  }

  return result;
}

func n88_interp_spline2d(x, y, f) {
/* DOCUMENT n88_interp_spline2d(x, y, f)
  Performs a 2-dimensional spline fit interpolation against f at coordinates
  x, y.

  The following holds true provided that x and y are valid integer indices
  into f:
    f(x, y) == n88_interp_spline2d(x, y, f)

  All other values for x and y are interpolated using splines. For each
  coordinate pair, splines are calculated using the neighborhood centered
  around the coordinates. The largest possible neighborhood out of 6x6, 4x4,
  and 2x2 are used for each coordinate; if none are possible, then
  extrapolation is used with the nearest 2x2 neighborhood.
*/
  result = array(double, dimsof(x));
  need = array(char(1), dimsof(x));

  // Calculate distance from edges
  xmin = ymin = 1;
  xmax = dimsof(f)(2);
  ymax = dimsof(f)(3);
  dist = min(x - xmin, y - ymin, xmax - x, ymax - y);

  thresh = [1, 2, -1];
  size = [2, 4, 6];

  for(i = 1; i <= numberof(thresh); i++) {
    current = need;
    // If we don't need anything... continue.
    if(noneof(current))
      continue;
    // If we have a threshold, apply it.
    if(thresh(i) > 0) {
      w = where(current);
      current(w) &= dist(w) <= thresh(i);
    }
    // If nothing is left... continue.
    if(noneof(current))
      continue;

    w = where(current);

    // Based on size, calculate lower/upper modifiers
    lo = long(size(i)/2.)-1;
    hi = size(i) - 1;

    // Determine index to corner of matrix to use
    xi = max(min(long(x(w)-lo), xmax - hi), 1);
    yi = max(min(long(y(w)-lo), ymax - hi), 1);

    // Determine position within sub matrix
    xp = 1 + x(w) - xi;
    yp = 1 + y(w) - yi;

    // Convert corner location into offset
    offset = xi + (yi - 1) * xmax;

    // Interim results
    interim = array(double, size(i), dimsof(offset));
    for(j = 1; j <= size(i); j++) {
      interim(j,..) = n88_splinefit(xp, f, offset, size(i));
      if(j != size(i))
        offset += xmax;
    }

    // Offsets into interim results
    offset = indgen(1:numberof(interim):size(i));

    result(w) = n88_splinefit(yp, interim, offset, size(i))(*);
    interim = offset = [];
    need(w) = 0;
  }

  return result;
}

func n88_interp_qfit2d(x, y, f) {
/* DOCUMENT n88_interp_qfit2d(x, y, f)
  Performs a 2-dimensional parabola fit interpolation against f at coordinates
  x, y.

  The following holds true provided that x and y are valid integer indices
  into f:
    f(x, y) == n88_interp_qfit2d(x, y, f)

  All other values of x and y are interpolated using the parabolas that pass
  through the points in their 3x3 neighborhood.
*/
  xmax = dimsof(f)(2);
  ymax = dimsof(f)(3);

  // Determine index for corner of 3x3 matrix to use
  xi = max(min(long(x), xmax-2), 1);
  yi = max(min(long(y), ymax-2), 1);

  // Determine position within sub matrix
  xp = 1 + x - xi;
  yp = 1 + y - yi;

  // Convert corner location into offset
  offset = xi + (yi - 1) * xmax;

  // Interim results
  interim = array(double, 3, dimsof(x));
  interim(1,..) = n88_qfit(xp, f, offset);
  offset += xmax;
  interim(2,..) = n88_qfit(xp, f, offset);
  offset += xmax;
  interim(3,..) = n88_qfit(xp, f, offset);

  // Offsets into interium results
  offset = indgen(1:numberof(interim):3);
  return n88_qfit(yp, interim, offset);
}

func n88_qfit(x, f, offset) {
/* DOCUMENT n88_qfit(x, f, offset)
  Performs a parabola fit using three points. Algorithm derived from NGS code
  associated with the GEOID 99 model.

  Parameters:
    x: The value to interpolate at.
    f: Known values.
    offset: Offset into f that x is referenced against.

  Normally, x will be between 1 and 3.

  Some identities:
    n88_qfit(1, f, offset) == f(offset)
    n88_qfit(2, f, offset) == f(offset+1)
    n88_qfit(3, f, offset) == f(offset+2)
  Any other value for x is interpolated on the parabola that passes through
  those points.
*/
  x--;
  t1 = f(offset+1) - f(offset);
  x2 = 0.5 * x * (x-1);
  t2 = f(offset+2) - 2 * f(offset+1) + f(offset);
  return f(offset) + x * t1 + x2 * t2;
}

func import_geoid_grid(g, searchstr=) {
/* DOCUMENT grid = import_geoid_grid(geoid)
  -or-  grid = import_geoid_grid(filename)
  -or-  grid = import_geoid_grid(path, searchstr=)

  Imports one or more GEOIDs into a ZGRID structure.
*/
  default, searchstr, "*.bin";
  if(is_string(g)) {
    if(file_isfile(g)) {
      g = geoid_load(g);
    } else {
      files = find(g, searchstr=searchstr);
      grids = array(ZGRID, numberof(files));
      for(i = 1; i <= numberof(files); i++)
        grids(i) = import_geoid_grid(files(i));
      return grids;
    }
  }

  grid = ZGRID();
  grid.xmin = g.glomn - 360.;
  grid.ymin = g.glamn;
  grid.cell = g.dla;
  grid.nodata = -32767;
  grid.zgrid = &g.data;

  return grid;
}
