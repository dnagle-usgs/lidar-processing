/******************************************************************************\
* This file was created in the attic on 2010-01-29. It contains functions that *
* were made obsolete by function hist_data in eaarl_data.i. These functions,   *
* and the files they came from, are:                                           *
*     hist_fs     from surface_topo.i                                          *
*     hist_veg    from veg.i                                                   *
*     hist_depth  from geo_bath.i                                              *
* Each function has comments on how it differs from hist_data.                 *
\******************************************************************************/

/*
   Function 'hist_fs' was removed from surface_topo.i.

   Functionality differences between func hist_fs and func hist_data:

    * hist_fs does some secret filtering of the data:
         - Points with elevations below -60m are removed
         - Points with elevations above 3000m are removed
         - Points whose mirror elevation and first surface elevation are less
           than 1m apart are removed
      No filtering is done by hist_data. If you want it cleaned, pass it
      through test_and_clean.
*/
func hist_fs( fs_all, binsize=, win=, dofma=, color=, normalize=, lst=, width= ) {
/* DOCUMENT hist_fs(fs)

   Return the histogram of the good elevations in fs.  The input fs elevation
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs: 
	fs_all		An array of "R" structures.  
	binsize=	Binsize in centimeters from 1.0 to 200.0  
	win=		Defaults to 0.
	dofma=		Defaults to 1 (Yes), Set to zero if you don't want an fma.
	color=		Set graph color
	width=		Set line width
	normalize=	Defaults to 0 (not normalized),  Set to 1  to cause it to normalize
                        to one.  This is very useful in case you are plotting multiple 
                        histograms where you actually want to compare their peak value.
        lst=            An optional externally generated "where" filter list.
	

  Outputs:
	A histogram graphic in Window 0

  Returns:
	An 2xn array of x values and counts found at those values.

 Orginal: W. Wright 9/29/2002

See also: R
*/

  if ( is_void(fs_all) ) {
    "fs_all doesnt have any data in it."
    return;
  }

  if ( is_void(binsize))
	binsize = 10.0;

  if ( is_void(win) ) 
	win = 0;

  if ( is_void(dofma) ) 
	dofma = 1;

  if ( is_void(lst)) 
     lst = where(fs_all.elevation);

  elev = fs_all.elevation(lst);
// build an edit array indicating where values are between -60 meters
// and 3000 meters.  Thats enough to encompass any EAARL data than
// can ever be taken.
  gidx = (elev > -6000) | (elev <300000);  

// Now kick out values which are within 1-meter of the mirror. Some
// functions will set the elevation to the mirror value if they cant
// process it.
 if(!structeq(structof(fs_all), "ATM2")) { 
        melev = fs_all.melevation(lst);
        gidx &= (elev < (melev-1));
}


// Now generate a list of where the good values are.
  q = where( gidx )
  

// now find the minimum 
minn = elev(q)(min);
maxx = elev(q)(max);

 fsy = elev(q) - minn ;
// minn /= binsize;
// maxx /= binsize;

  minn /= 100.0
  maxx /= 100.0


// make a histogram of the data indexed by q.
  h = histogram( (fsy / int(binsize)) + 1 );
  zero_list = where( h == 0 ) 
  if ( numberof(h) < 2 ) {
    h = [1,h(1),1];   
  }
  if ( numberof(zero_list) )
  	h( zero_list ) = 1;
  e = span( minn, maxx, numberof(h) )  ; 
  w = current_window();
  window,win; 
  if ( dofma ) 
  	fma; 
  if ( normalize ) {
	h = float(h);
	h = h/(h(max));
   }
  plg,h,e, color=color, width=width;
  pltitle(swrite( format="Elevation Histogram %s", data_path));
  xytitles,"Elevation (meters)", "Number of measurements"
  //limits
  hst = [e,h];
  window, win;
  // The next line checks to see if the user has supplied any custom limits.
  // If so, we do not override them. If not, we display it nicely.
  if(long(limits()(5)) & 1)
     limits,"e","e",0,hst(max,2) * 1.5;
  window_select, w;
  return hst;
}

/*
   Function 'hist_veg' was removed from veg.i

   Functionality differences between func hist_veg and func hist_data:

    * hist_veg does some secret filtering of the data. The exact filtering
      depends on the options set.
         - Sometimes, the data gets passed through clean_cveg_all.
         - Sometimes, points with zero elevations are removed.
         - Sometimes, only points where nx==1 are kept.
         - Sometimes, points with elevations below -60m are removed.
         - Sometimes, points with elevations above 3000m are removed.
         - Sometimes, points whose mirror elevation and first surface elevation
           are less than 1m apart are removed
      No filtering is done by hist_data. If you want it cleaned, pass it
      through test_and_clean.
*/
func hist_veg( veg_all, binsize=, win=, dofma=, color=, normalize=, lst=, width=, multi=, type= ) {
/* DOCUMENT hist_veg(fs)

   Return the histogram of the good elevations in veg.  The input veg elevation
data are in cm, and the output is an array of the number of time a given
elevation was found. The elevations are binned to 1-meter.

  Inputs:
   veg_all     An array of "VEG_ALL_" or "CVEG_ALL" structures.
   binsize= Binsize in centimeters from 1.0 to 200.0
   win=     Defaults to 0.
   dofma=      Defaults to 1 (Yes), Set to zero if you don't want
                        an fma.
   color=      Set graph color
   width=      Set line width
   normalize=  Defaults to 0 (not normalized),  Set to 1  to cause
                        it to normalize to one.  This is very useful in case
                        you are plotting multiple histograms where you actually
                        want to compare their peak value.
        lst=            An optional externally generated "where" filter list.
        multi=    Set to 1 if using Multipeak vegetation algorithm
   type =      Set to 1 for First Return Topography only
                2 for Bare Earth Topography only (only when
                                 multi = 0)
                3 for considering all returns


  Outputs:
   A histogram graphic in Window 0

  Returns:
   An 2xn array of x values and counts found at those values.

 Orginal: Amar Nayegandhi 02/20/03.  Adapted from hist_fs by WW.

See also: VEG_ALL_, CVEG_ALL
*/
   if ( is_void(binsize))
      binsize = 100.0;

   if ( is_void(win) )
      win = 0;
   if (numberof(where(veg_all.north == 0)) > 0) {
      if (multi == 1)
         veg_all = clean_cveg_all(veg_all);
   }
   if (!type) type = 2;
   if (is_void(dofma)) dofma=1;

   if ( is_void(lst)) {
      if (type == 1) {
         if (multi == 0) {
            lst = where(veg_all.elevation);
         } else {
            lst = where(veg_all.nx == 1);
            if (is_array(lst)) {
               ilst = where(veg_all.elevation(lst));
               if (is_array(ilst))
                  lst = lst(ilst);
            }
         }
         elev = veg_all.elevation(lst);
      }
      if (type == 2) {
         lst = where(veg_all.lelv);
         elev = veg_all.lelv(lst);
      }
      if (type == 3) {
         if (multi == 0) {
            lst = where(veg_all.elevation);
            if (is_array(lst)) {
               ilst = where(veg_all.lelv(lst));
               if (is_array(ilst))
                  lst = lst(ilst);
            }
         } else lst = where(veg_all.elevation);
         elev = veg_all.elevation(lst);
      }
   } else {
      elev = veg_all.elevation(lst);
   }

   if (multi == 0) {
      // clean the array only if multi = 0.
      melev = veg_all.melevation(lst);
      // build an edit array indicating where values are between -60 meters
      // and 3000 meters.  Thats enough to encompass any EAARL data than
      // can ever be taken.
      gidx = (elev > -6000) | (elev <300000);

      // Now kick out values which are within 1-meter of the mirror. Some
      // functions will set the elevation to the mirror value if they cant
      // process it.
      gidx &= (elev < (melev-1));

      // Now generate a list of where the good values are.
      q = where( gidx );
      elev = elev(q);
   }

   // now find the minimum
   minn = elev(min);
   maxx = elev(max);

   fsy = elev - minn;

   minn /= 100.0;
   maxx /= 100.0;

   // make a histogram of the data indexed by q.
   h = histogram( (fsy / int(binsize)) + 1 );
   zero_list = where( h == 0 );
   if ( numberof(h) < 2 ) {
      h = [1,h(1),1];
   }
   if ( numberof(zero_list) )
      h( zero_list ) = 1;
   e = span( minn, maxx, numberof(h) );
   w = current_window();
   window,win;
   if ( dofma )
      fma;
   if ( normalize ) {
      h = float(h-1);
      if ((h(max)) > 0) {
         h = h/(h(max));
      } else {
         h = [0];
      }

      plg,h,e, color=color, width=width;
      plmk, h, e, marker=4, msize=0.4, width=10, color="red";
   } else {
      h = h-1;
      plg,h,e, color=color, width=width;
      plmk, h, e, marker=4, msize=0.4, width=10, color="red";
   }
   pltitle, swrite( format="Elevation Histogram %s", data_path);
   xytitles,"Elevation (meters)", "Number of measurements";
   //limits
   hst = [e,h];
   window, win;
   // The next line checks to see if the user has supplied any custom limits.
   // If so, we do not override them. If not, we display it nicely.
   if(long(limits()(5)) & 1)
      limits,"e","e",0,hst(max,2) * 1.5;
   window_select, w;
   return hst;
}

/*
   Function 'hist_depth' was removed from geo_bath.i

   Functionality differences between func hist_depth and func hist_data:

    * hist_depth does some secret filtering of the data:
         - Points with elevations below -60m are removed.
         - Points with elevations above 3000m are removed.
         - Points whose mirror elevation and first surface elevation are less
           than 1m apart are removed
         - Points where the depth is zero are removed.
      No filtering is done by hist_data. If you want it cleaned, pass it
      through test_and_clean.
*/
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


