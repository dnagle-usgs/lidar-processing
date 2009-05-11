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

   rnb_idx = [];
   rnbu_idx = [];
   // make sure bathy array has unique rn
   rnb_idx = sort(bathy.rn);
   bathy1 = bathy(rnb_idx);
   rnbu_idx = unique(bathy1.rn, ret_sort=0);
   bathy1 = bathy1(rnbu_idx);
    
   rnv_idx = [];
   rnvu_idx = [];

   //sort veg array as well and ensure uniqueness
   rnv_idx = sort(veg.rn);
   veg1 = veg(rnv_idx);
   rnvu_idx = unique(veg1.rn, ret_sort=0);
   veg1 = veg1(rnvu_idx);


   num_rn_bathy = numberof(bathy1.rn);
   num_rn_veg = numberof(veg1.rn);
   idx_all = array(long,num_rn_veg);
   idx_all(*) = 1;
   if (is_void(buf)) buf = 3;
   for (i=1;i<=num_rn_bathy;i++) {
     idx = [];
     box_idx = [];
     if ( (i % 100) == 0 ) write, format="%d of %d complete\r", i, num_rn_bathy ;
     point = [bathy1.east(i),bathy1.north(i)]/100.
     temp_rgn = [point(1)-buf,point(1)+buf, point(2)-buf, point(2)+buf]*100.;
     box_idx = data_box(veg1.least, veg1.lnorth,  temp_rgn(1), temp_rgn(2), temp_rgn(3), temp_rgn(4));
     if (is_array(box_idx)) 
           idx_all(box_idx) = 0;
   }

   // now remove from veg array
   veg_new_idx = where(idx_all);
   veg_new = veg1(veg_new_idx);
   
   // sort by northing
   nidx = sort(veg_new.lnorth);
   veg_new = veg_new(nidx);

   return veg_new;

}

