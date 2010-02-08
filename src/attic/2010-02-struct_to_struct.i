/******************************************************************************\
* This file was created in the attic on 2010-02-08. It contains functions that *
* were made obsolete by function struct_cast in eaarl_data.i. These functions, *
* and the files they came from, are:                                           *
*     r_to_fs              from surface_topo.i                                 *
*     veg_all__to_veg__    from veg.i                                          *
*     veg_all_to_veg_      from veg.i                                          *
*     geoall_to_geo        from geo_bath.i                                     *
* For all four functions, you can replace a call to that function with a call  *
* to struct_cast and it will perform the same conversion, automatically.       *
\******************************************************************************/

// surface_topo.i
func  r_to_fs(data) {
/*DOCUMENT r_to_fs(data)
    this function converts the data array from the raster structure R to the point structure FS for surface topography.
    amar nayegandhi
    03/08/03.
*/
 if (numberof(data) != numberof(data.north)) {
   data_new = array(FS, numberof(data)*120);
        indx = where(data.rn >= 0);
        data_new.rn = data.rn(indx);
        data_new.north = data.north(indx);
        data_new.east = data.east(indx);
        data_new.elevation = data.elevation(indx);
        data_new.mnorth = data.mnorth(indx);
        data_new.meast = data.meast(indx);
        data_new.melevation = data.melevation(indx);
        data_new.intensity = data.intensity(indx);
        data_new.soe = data.soe(indx);
  } else data_new = unref(data);
  return data_new;
}

// veg.i
func veg_all__to_veg__(data) {
/* DOCUMENT veg_all__to_veg__(data)
      This function converts the data array from the raster structure
      (VEG_ALL_) to the VEG__ structure in point format.
      amar nayegandhi
     03/08/03
*/
   if (numberof(data) != numberof(data.north)) {
      data_new = array(VEG__, numberof(data)*120);
      indx = where(data.rn >= 0);
      data_new.rn = data.rn(indx);
      data_new.north = data.north(indx);
      data_new.east = data.east(indx);
      data_new.elevation = data.elevation(indx);
      data_new.mnorth = data.mnorth(indx);
      data_new.meast = data.meast(indx);
      data_new.melevation = data.melevation(indx);
      data_new.lnorth = data.lnorth(indx);
      data_new.least = data.least(indx);
      data_new.lelv = data.lelv(indx);
      data_new.fint = data.fint(indx);
      data_new.lint = data.lint(indx);
      data_new.nx = data.nx(indx);
      data_new.soe = data.soe(indx);
   } else data_new = data;

   return data_new;
}

// veg.i
func veg_all_to_veg_(data) {
/* DOCUMENT veg_all_to_veg_(data)
      this function converts the data array from the raster structure (VEG_ALL)
      to the VEG_ structure in point format. Note this structure is of the OLD
      format.

      amar nayegandhi 03/14/03
*/
   if (numberof(data) != numberof(data.north)) {
      data_new = array(VEG_, numberof(data)*120);
      indx = where(data.rn >= 0);
      data_new.rn = data.rn(indx);
      data_new.north = data.north(indx);
      data_new.east = data.east(indx);
      data_new.elevation = data.elevation(indx);
      data_new.mnorth = data.mnorth(indx);
      data_new.meast = data.meast(indx);
      data_new.melevation = data.melevation(indx);
      data_new.felv = data.felv(indx);
      data_new.fint = data.fint(indx);
      data_new.lelv = data.lelv(indx);
      data_new.lint = data.lint(indx);
      data_new.nx = data.nx(indx);
      data_new.soe = data.soe(indx);
   } else data_new = data;

   return data_new;
}

// geo_bath.i
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
