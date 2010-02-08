/******************************************************************************\
* This file was created in the attic on 2010-02-08. It contains functions that *
* were made obsolete by function test_and_clean in manual_filter.i, as well as *
* the old version of test_and_clean from prior to its rewrite. The functions   *
* removed, and the files they came from, are:                                  *
*     clean_fs       from surface_topo.i                                       *
*     clean_veg      from veg.i                                                *
*     clean_bathy    from geo_bath.i                                           *
* All three functions are replaced by the new test_and_clean. The only feature *
* lacking in the new test_and_clean that was present in these functions is the *
* rcf_width= option, which was not being used. If you want to rcf your data    *
* after cleaning it, there are functions in rcf.i that can help.               *
\******************************************************************************/

// manual_filter.i
func test_and_clean(data, verbose=) {
   if(is_void(data)) {
      tk_messageBox, "No data found in the variable you selected. Please select another one.", "ok", title="";
      return [];
   }

   /***************************************************************
     Added to convert from raster format to cleaned linear format.
    ***************************************************************/
   if(numberof(dimsof(data.north)) > 2) {
      a = structof(data(1));
      if (structeq(a, GEOALL))
         data = clean_bathy(unref(data), verbose=verbose);
      if (structeqany(a, VEG_ALL_, VEG_ALL))
         data = clean_veg(unref(data), verbose=verbose);
      if (structeqany(a, R, ATM2))
         data = clean_fs(unref(data), verbose=verbose);
   }

   return data;
}

// surface_topo.i
func clean_fs(fs_all, rcf_width=, verbose=) {
  /* DOCUMENT clean_fs(fs_all, rcf_width=)
   this function cleans the fs_all array
   amar nayegandhi 08/03/03
   Input: fs_all  : Initial data array of structure R or FS
          rcf_width  : The elevation width (m) to be used for the RCF filter.  If not set, rcf is not used.
   Output: Cleaned data array of type FS
  */
  default, verbose, 1;
                                                                                       if (numberof(fs_all) != numberof(fs_all.north)) {
      // convert R to FS
      if(verbose) write, "converting raster structure (R) to point structure (FS)";
      struct_cast, fs_all;
  }                                                                                  
  if(verbose) write, "cleaning data...";


  // remove pts that had north values assigned to 0                                    indx = where(fs_all.north != 0);
  if (is_array(indx)) {
     fs_all = unref(fs_all)(indx);
  } else {
     fs_all = [];                                                                         return fs_all;
  }


  // remove points that have been assigned mirror elevation values                     indx = where(fs_all.elevation != fs_all.melevation)
  if (is_array(indx)) {
    fs_all = unref(fs_all)(indx);
  } else {
    fs_all = [];                                                                         return fs_all;
  }

  if (is_array(rcf_width)) {
    if(verbose) write, "using rcf filter to clean fs data..."                            //run rcf on the entire data set
    ptr = rcf(fs_all.elevation, rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
        fs_all = unref(fs_all)(*ptr(1));
    } else {                                                                                 fs_all = [];
    }
  }


  return fs_all
}


// veg.i
func clean_veg(veg_all, rcf_width=, type=, verbose=) {
/* DOCUMENT clean_veg(veg_all, rcf_width=)
   this function cleans the veg_all array
   amar nayegandhi 12/20/02
   Input: veg_all    Initial data array of structure VEG__ or VEG_ALL_
          rcf_width  The elevation width (m) to be used for the RCF
                     filter.  If not set, rcf is not used.

     type=      3 = structure VEG__.
           5 = strucutre VEG_.

   Output: Cleaned data array of type VEG_ or VEG__
   modified AN 3/8/03 to add rcf_width= option and other changes
   modified AN 3/14/03 to make this function work for data of old type
*/
   default, verbose, 1;

   if (!type) type = 3;
   if (numberof(veg_all) != numberof(veg_all.north)) {
      if(verbose) write, "converting raster structure to point structure";
      struct_cast, veg_all;
   }

   if(verbose) write, "cleaning data...";

   // remove pts that have both bare earth and first return elevations assigned to melevation
   indx = where((veg_all.lelv != veg_all.melevation) | (veg_all.elevation != veg_all.melevation));
   if (is_array(indx)) {
      veg_all = veg_all(indx);
   } else {
      veg_all = [];
      return veg_all;
   }

   // remove pts that had north and lnorth values assigned to 0
   indx = where(veg_all.north != 0);
   if (is_array(indx)) {
      veg_all = veg_all(indx);
   } else {
      veg_all = [];
      return veg_all;
   }

   if (type == 3) {
      indx = where(veg_all.lnorth != 0);
      if (is_array(indx)) {
         veg_all = veg_all(indx);
      } else {
         veg_all = [];
         return veg_all;
      }
   }

   /*
   // remove points that have been assigned mirror elevation values
   indx = where((veg_all.melevation - veg_all.elevation) > 14000)
   if (is_array(indx)) {
      veg_all = veg_all(indx);
   } else {
      veg_all = [];
      return veg_all
   }
   */

   if (is_array(rcf_width)) {
      if(verbose) write, "using rcf filter to clean veg data..."
         //run rcf on the entire data set
         ptr = rcf(veg_all.elevation, rcf_width*100, mode=2);
      if (*ptr(2) > 3) {
         veg_all = veg_all(*ptr(1));
      } else {
         veg_all = [];
      }
   }

   if(verbose) write, "cleaning completed";
   return veg_all;
}

// geo_bath.i
func clean_bathy(depth_all, rcf_width=, verbose=) {
  /* DOCUMENT clean_bathy(depth_all, rcf_width=)
      This function cleans the bathy data.
      Optionally set rcf_width to the elevation width (in meters) to use the RCF filter on the entire data set.For e.g., if you know your data set can have a maximum extent of -1m to -25m, then set rcf_width to 25.  This will remove the outliers from the data set.
    amar nayegandhi 03/07/03
  */
  default, verbose, 1;
  if (numberof(depth_all) != numberof(depth_all.north)) {
      if(verbose) write, "converting GEOALL to GEO...";
      struct_cast, depth_all;
  }
  if(verbose) write, "cleaning geo data...";
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
    if(verbose) write, "using rcf to clean data..."
    //run rcf on the entire data set
    ptr = rcf((depth_all.elevation+depth_all.depth), rcf_width*100, mode=2);
    if (*ptr(2) > 3) {
        depth_all = depth_all(*ptr(1));
    } else {
        depth_all = 0
    }
  }
  if(verbose) write, "cleaning completed.";
  return depth_all
}
