/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent expandtab: */
write, "$Id$";

func remove_bathy_from_veg(veg, bathy, buf=) {
/* DOCUMENT remove_bathy_from_veg(veg, bathy, buf=) 
   This function modifies a bare_earth data array of type VEG__ by removing all points that are within a bathymetry data array (of type GEO) and within a certain distance (default = 3 m) from each bathy location. 
   This function is very useful when merging a bare earth and bathymetry data set to create a seamless topo-bathy data product. 
   INPUT:
     veg: data array of type VEG__
     bathy: data array of type GEO
     buf = optional keyword to set the buffer around each bathy point. (default = 3m).
   OUTPUT:
     veg_new: data array of type VEG__ with points around bathy points removed.

     Original: amar nayegandhi September 2008.

   */

   // make sure bathy array has unique rn
   rnb_idx = sort(bathy.rn);
   bathy = bathy(rnb_idx);
   rnbu_idx = unique(bathy.rn, ret_sort=0);
   bathy = bathy(rnbu_idx);

   //sort veg array as well and ensure uniqueness
   rnv_idx = sort(veg.rn);
   veg = veg(rnv_idx);
   rnvu_idx = unique(veg.rn, ret_sort=0);
   veg = veg(rnvu_idx);


   num_rn_bathy = numberof(bathy.rn);
   num_rn_veg = numberof(veg.rn);
   idx_all = array(long,num_rn_veg);
   idx_all(*) = 1;
   if (is_void(buf)) buf = 3;
   for (i=1;i<=num_rn_bathy;i++) {
     if ( (i % 100) == 0 ) write, format="%d of %d complete\r", i, num_rn_bathy ;
      idx = where(veg.rn == bathy.rn(i));
      if (is_array(idx)) {
         idx_all(idx) = 0; 
         // find all points within buf meters from this point
         point = [veg.least(idx(1)),veg.lnorth(idx(1))]/100.
         temp_rgn = [point(1)-buf,point(1)+buf, point(2)-buf, point(2)+buf];
         box_idx = sel_data_rgn(veg, mode=4, rgn=temp_rgn, retindx=1, silent=1)
         //rad_idx = sel_data_ptRadius(veg_box_data, point=point, radius=buf, retindx=1, silent=1) 
         idx_all(box_idx) = 0;
      }
   }

   // now remove from veg array
   veg_new_idx = where(idx_all);
   veg_new = veg(veg_new_idx);
   
   // sort by northing
   nidx = sort(veg_new.lnorth);
   veg_new = veg_new(nidx);

   return veg_new;

}

