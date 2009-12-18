// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
/*
    amar nayegandhi, original nad832navd88.i
    charlene sullivan, modified form of nad832navd88.i for use of GEOID 96 model
    The following code has been adapted from the GEOID 99 model available at
    http://www.ngs.noaa.gov/GEOID/GEOID99/
    The original DISCLAIMER applies to this as well.
*/

require, "eaarl.i";

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
      g.dlo - distance internval in longitude in degrees
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

func nad832navd88(lon, lat, &elv, gdata_dir=, geoid=, verbose=) {
/* DOCUMENT navd882nad83, lon, lat, &elv, gdata_dir=, geoid=
   Converts data from NAD83 to NAVD88. lon and lat should be in degrees. elv
   should be in meters and is updated in place. See nad832navd88offset for a
   description of the options.
*/
   if(!is_pointer(lon))
      lon = &lon;
   if(!is_pointer(lat))
      lat = &lat;

   if(is_pointer(elv)) {
      // If elv is a pointer then we need to loop. :(
      offset = nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
         verbose=verbose);
      for(i = 1; i <= numberof(elv); i++)
         *elv(i) -= offset(i);
   } else {
      elv -= nad832navd88offset(lon, lat, gdata_dir=gdata_dir, geoid=geoid,
         verbose=verbose);
   }
}

func navd882nad83(lon, lat, &elv, gdata_dir=, geoid=, verbose=) {
/* DOCUMENT navd882nad83, lon, lat, &elv, gdata_dir=, geoid=
   Converts data from NAVD88 to NAD83. lon and lat should be in degrees. elv
   should be in meters and is updated in place. See nad832navd88offset for a
   description of the options.
*/
   if(!is_pointer(lon))
      lon = &lon;
   if(!is_pointer(lat))
      lat = &lat;

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

func nad832navd88offset(lon, lat, gdata_dir=, geoid=, verbose=) {
/*DOCUMENT offset = nad832navd88offset(lon, lat, gdata_dir=, geoid_version=)
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

   Memory optimization:
      For most efficient use of memory, this function allows you to pass a
      pointer to your lon and lat arrays instead of the arrays themselves. The
      original data will not be changed.
*/
// Amar Nayegandhi 07/10/03, original nad832navd88
// Charlene Sullivan 09/21/06, modified for use of GEOID96 model
// David Nagle 11/21/07, modified to provide offset to facilate 2-way
//    conversions
   extern alpsrc;
   default, geoid, "03";
   default, gdata_dir, file_join(alpsrc.geoid_data_root, "GEOID"+geoid);
   default, verbose, 1;

   if(!is_pointer(lon))
      lon = &lon;
   if(!is_pointer(lat))
      lat = &lat;

   if((*lon)(1) < 0)
      lon = &(*lon + 360.);

   // Get list of candidate GEOID files
   files = [];
   grow, files, find(gdata_dir, glob="*.pbd");
   grow, files, find(gdata_dir, glob="*.bin");
   grow, files, find(gdata_dir, glob="*.geo");

   if(!numberof(files)) {
      write, "No GEOID files found, aborting.";
      return;
   }

   // Get bounds for each file
   latmin = latmax = lonmin = lonmax = array(double, numberof(files));
   for(i = 1; i <= numberof(files); i++) {
      g = geoid_load(files(i));
      latmin(i) = g.glamn;
      lonmin(i) = g.glomn;
      latmax(i) = latmin(i) + g.dlo * (g.ncols - 1);
      lonmax(i) = lonmin(i) + g.dla * (g.nrows - 1);
      g = [];
   }

   // Calculate the file to use for each point
   which = array(short(0), numberof(*lon));
   for(i = 1; i <= numberof(files); i++) {
      need = where(!which);
      if(!numberof(need))
         break;
      idx = data_box((*lon)(need), (*lat)(need), lonmin(i), lonmax(i),
         latmin(i), latmax(i));
      if(numberof(idx))
         which(need(idx)) = i;
   }

   // This will hold our return results
   offset = array(0., numberof(*lon));

   // Do any lack? Warn!
   if(!numberof(where(which))) {
      write, format="%s", "\n ** No data is in area covered by GEOID. No change made. **\n";
      return offset;
   } else if(numberof(where(!which))) {
      write, format="\n ** %d points (of %d) in areas not covered by GEOID. Those points will remain unchanged. **\n", numberof(where(!which)), numberof(which);
   }

   // Get a list of which files are needed
   needed = set_remove_duplicates(which(where(which)));

   for(i = 1; i <= numberof(needed); i++) {
      if(verbose)
         write, format="grid file = %s\n", files(needed(i));

      w = where(which == needed(i));
      g = geoid_load(files(needed(i)));

      // Find the row/col of the nearest point to the data_in lat/lon points
      irown = 1 + int(((*lat)(w) - g.glamn) / g.dla);
      icoln = 1 + int(((*lon)(w) - g.glomn) / g.dlo);

      // Are we on an edge? If so, then move to the center point
      cidx = where(irown <= 1);
      if(numberof(cidx))
         irown(cidx) = 2;
      cidx = where(icoln <= 1);
      if(numberof(cidx))
         icoln(cidx) = 2;
      cidx = where(irown >= g.nrows);
      if(numberof(cidx))
         irown(cidx) = g.nrows - 1;
      cidx = where(icoln >= g.ncols);
      if(numberof(cidx))
         icoln(cidx) = g.ncols - 1;

      // At this point, the irown/icoln values reflect the center node of the
      // 3x3 grid of points we will use for biquadratic interpolation.

      // Now extract that 3x3 grid:
      // f1 f2 f3
      // f4 f5 f6
      // f7 f8 f9

      xx = ((*lon)(w) - g.glomn - ((icoln-2)*g.dlo)) / g.dlo;

      index = g.ncols * (irown - 2) + icoln;
      f1 = g.data(index-1);
      f2 = g.data(index);
      f3 = g.data(index+1);
      fx1 = qfit(xx,unref(f1),unref(f2),unref(f3));

      index += g.ncols;
      f4 = g.data(index-1);
      f5 = g.data(index);
      f6 = g.data(index+1);
      fx2 = qfit(xx,unref(f4),unref(f5),unref(f6));

      index += g.ncols;
      f7 = g.data(index-1);
      f8 = g.data(index);
      f9 = g.data(unref(index)+1);
      fx3 = qfit(unref(xx),unref(f7),unref(f8),unref(f9));

      yy = ((*lat)(w) - g.glamn - ((irown-2)*g.dla)) / g.dla;

      close, f;

      offset(w) = qfit(unref(yy),unref(fx1),unref(fx2),unref(fx3));
   }
   return offset;
}

func qfit(x,f0,f1,f2) {
/* DOCUMENT qfit(x,f1,f2,f3)
   Parabola fit through 3 points (x=0,x=1,x=2) with values
      f0=f(0)  f1=f(1)  f2=f(2)
   and returning the value qfit = f(x) where 0<=x<=2.
   Adapted from GEOID99 model.
*/
// Original Amar Nayegandhi 07/14/03
// Rewrote by David Nagle 2009-02-26 to reduce memory impact
   t1 = f1 - f0;
   x2 = 0.5 * x * (x-1);
   t2 = unref(f2) - 2 * unref(f1) + f0;
   return unref(f0) + unref(x) * unref(t1) + unref(x2) * unref(t2);
}
