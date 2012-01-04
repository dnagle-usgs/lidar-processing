/******************************************************************************\
* This file was created in the attic on 2010-01-29. It contains functions that *
* were made obsolete by function display_data in eaarl_data.i. These           *
* functions, and the files they came from, are:                                *
*     display        from surface_topo.i                                       *
*     display_veg    from veg.i                                                *
*     plot_bathy     from geo_bath.i                                           *
* Each function has comments on how it differs from display_data.              *
\******************************************************************************/

/*
   Function 'display' was removed from file surface_topo.i.

   Functionality differences between func display and func display_data:

    * display has an i= and j= option that lets you select a start/stop point
      in your data to plot. You can accomplish the same thing with display_data
      by using those values to index into the data array when you pass it to
      display_data:
         display_data, rrr(i:j)

    * display did some filtering of the data. When edt=0, it would only plot
      data with non-zero northings. When edt=1, it would only plot data when
      the elevation and northing resulted in a true value when bitwise anded
      together (I suspect that's a but... it was probably intended to show any
      nonzero data). display_data does no filtering; filter your data before
      plotting.
*/
func display(rrr, i=,j=, mode=, cmin=, cmax=, size=, win=, dofma=, edt=, marker=, skip= ) {
/* DOCUMENT display(rrr, i=,j=, cmin=, cmax=, size=, win=, dofma=, edt=, marker= )

 
   Display EAARL laser samples.
   rrr		type "R" data array.
   i            Starting point.
   j            Stopping point.
   mode=	"elev"       elevation
                "intensity"  intensity
   cmin=        Deepest point in centimeters ( -3500 default )
   cmax=        Highest point in centimeters ( -1500 )
   size=        Screen size of each point. Fiddle with this
                to get the filling-in like you want.
   edt=		1 to plot only good data. Don't include this
                if you want un-edited data.
   marker=      Use a particular marker shape for each pixel.
   msize        Set the size for each pixel in ndc coords.

  The rrr northing and easting values are divided by 100 so the scales
 are in meters instead of centimeters.  The elevation remains in centimeters.
 
 
*/
 if ( is_void(mode) )
	mode = "elev";

 if ( is_void(win) )
	win = 5;

 if ( is_void(i) ) 
	i = 1;
 if ( is_void(j) ) 
	j = dimsof(rrr)(2);
 window,win 
 if ( !is_void( dofma ) )
	fma;
 if (is_void(skip)) skip = 1;


write,format="Please wait while drawing..........%s", "\r"
 if ( is_void( cmin )) cmin = -3500;
 if ( is_void( cmax )) cmax = -1500;
 if ( is_void( size )) size = 1.4;
 ii = i;
 /*
 if ( !is_void(edt) ) {
   ea = rrr.elevation;
   ea = ( (ea >= cmin) & ( ea <= cmax ) );
 } else {
   ea = rrr.elevation;
   ea = (ea != 0 );
 }
 */
for ( ; i<=j; i++ ) {
 if ( !is_void(edt) ) {
   //ea = rrr(i).elevation;
   //q = where((ea >= cmin) & (ea <= cmax) & (rrr(i).north != 0))
   q = where(rrr(i).north);
   //q = where( (ea(,i)) &  (rrr(i).north) );
 } else {
   q = where( (rrr(i).elevation) & (rrr(i).north) );
 }
  if ( numberof(q) >= 1) {
     if ( mode == "elev" ) { 
       plcm, [rrr(i).elevation(q)](1:0:skip), ([rrr(i).north(q)](1:0:skip))/100.0, ([rrr(i).east(q)](1:0:skip))/100.0,
       msize=size,cmin=cmin, cmax=cmax, marker=marker
     } else if ( mode == "intensity" ) {
       plcm, rrr(i).intensity(q), (rrr(i).north(q)(1:0:skip))/100.0, (rrr(i).east(q)(1:0:skip))/100.0,
       msize=size,cmin=cmin, cmax=cmax, marker=marker
     }
   }
  }
write,format="Draw complete. %d rasters drawn. %s", j-ii, "\n"
}

/*
   Function 'display_veg' was removed from file veg.i.

   Functionality differences between func display_veg and func display_data:

    * display_veg did some filtering of the data. It would only plot data with
      non-zero northings. display_data does no filtering; filter your data
      before plotting.
*/
func display_veg(veg_arr, felv=, lelv=, cht=, fint=, lint=, cmin=, cmax=, size=,
win=, dofma=, edt=, marker=, skip=, quiet=) {
/* DOCUMENT display_veg, veg_arr, felv=, lelv=, cht=, fint=, lint=, cmin=, cmax=,
 * size=, win=, dofma=, edt=, marker=, skip=, quiet=

   This function displays a veg plot using the veg array from function run_veg
   and the georeferencing from function first_surface.

   Parameter:
      veg_arr: An array of veg data.

   Exactly one of the following options must be provided to indicate what kind
   of data to plot. Set the desired option to =1 to enable. (Default is =0,
   disabled.)
      felv= first surface elevation (.elevation)
      lelv= bare earth elevation (.lelv)
      cht= canopy heights (.elevation - .lelv)
      fint= first surface intensity (.fint)
      lint= bare earth intensity (.lint)

   Options:
      cmin= Minimal color for colorbar (default: min of z value)
      cmax= Maximal color for colorbar (default: max of z value)
      size= The size to make the markers (default: size=1.4)
      win= The window to plot in (default: win=5)
      dofma= Set to 1 to issue an fma prior to plotting (default: dofma=0,
         disabled)
      marker= The marker to use when plotting (default: marker=4)
      skip= The default skip interval for thinning out plotted data. (default:
         skip=1, which means to plot every point)
      quiet= Set to 1 to silence output text (default: quiet=0, output enabled)

   The following option is available for backwards compatibility. However, it
   is completely ignored in the current version of this function.
      edt=
*/
   extern elv;
   default, win, 5;
   default, dofma, 0;
   default, quiet, 0;
   default, size, 1.4;
   default, marker, 4;
   default, skip, 1;

   // Coerce into boolean integer (1 or 0)
   felv = felv ? 1 : 0;
   lelv = lelv ? 1 : 0;
   cht = cht ? 1 : 0;
   fint = fint ? 1 : 0;
   lint = lint ? 1 : 0;

   if(felv + lelv + cht + fint + lint != 1) {
      error, "Must select exactly one of felv, lelv, cht, fint, or lint!";
   }

   window, win;
   if(dofma) fma;
   if(!quiet) write, "Please wait while drawing...\r";
   len = numberof(veg_arr);

   // Get "elevation"
   if (felv) {
      elv = veg_arr.elevation/100.;
   } else if (lelv) {
      elv = veg_arr.lelv/100.;
   } else if (cht) {
      elv = (veg_arr.elevation - veg_arr.lelv)/100.;
   } else if (fint) {
      elv = veg_arr.fint;
   } else if (lint) {
      elv = veg_arr.lint;
   }

   // Get north/east
   if (lelv || lint) {
      north = veg_arr.lnorth;
      east = veg_arr.least;
   } else {
      north = veg_arr.north;
      east = veg_arr.east;
   }
   veg_arr = [];

   if(is_void(cmin)) cmin = elv(min);
   if(is_void(cmax)) cmax = elv(max);

   q = where(north);
   if(numberof(q)) {
      q = q(::skip);
      plcm, elv(q), north(q)/100., east(q)/100.,
         msize=size, cmin=cmin, cmax=cmax, marker=marker;
   }

   if (!quiet)
      write, format="Draw complete. %d rasters drawn.\n", len;
}

/*
   Function 'plot_bathy' was removed from file geo_bath.i.

   Functionality differences between func plot_bathy and func display_data:

    * plot_bathy did some filtering of the data. In all modes, it would discard
      points with zero northings. Additionally, in all modes except fs and
      fint, it would discard points with zero depths. display_data does no
      filtering; filter your data before plotting.
*/
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



