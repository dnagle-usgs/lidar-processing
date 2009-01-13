/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */

/**********************************************************************

  $Id$
  Original: Amar Nayegandhi 12/26/08
  Contains:

*********************************************************************/

func split_by_fltline(data, timediff=) {
/* DOCUMENT fptr = split_by_fltline(data, timediff=)
   This function splits the data by flightline.
   orig: amar nayegandhi 12/26/08.
   INPUT:
      data: input data array of type (R,FS,GEO,VEG__, ATM, etc.)
      timediff= minimum time difference between segments, in seconds; defaults
         to 180 seconds
   OUTPUT:
      fptr = array of pointers pointing to the flight segments
      for e.g. - f1 = *fptr(1) is the 1st flight line segment
                 f2 = *fptr(2) is the 2nd flight line segment
                 fn = *fptr(n) is the nth flight line segment
*/
   default, timediff, 180;

   // Convert data to point format (if in raster format) and clean
   data = test_and_clean(data);

   // Needs to be sorted in order for time diffing to work
   data = data(sort(data.soe));

   // Find indexes where the time exceeds the threshold
   time_idx = where(data.soe(dif) > timediff);
   if(numberof(time_idx)) {
      num_lines = numberof(time_idx) + 1;
      segs_idx = grow(1,time_idx+1,1);
   } else {
      num_lines = 1;
      segs_idx = [1, 1];
   }

   // Create array of pointers to each segment
   fptr = array(pointer, num_lines);
   for (i = 1; i<=num_lines; i++) {
     fltseg = data(segs_idx(i):segs_idx(i+1)-1);
     fptr(i) = &fltseg;
   }
   return fptr;
}

func create_fltline_seg_stats(fptr, indx=) {  
/* DOCUMENT create_fltline_seg_stats(fptr, indx=)   
   This function creates fligline segment statistics 
   Statistics include:
   **start and stop raster number for each segment
   **start and stop time in different formats (soe, sod, hms, etc.)
   ** first and last elevations, depths (if bathy).
   ** min, max, mean, median PDOP values for each fltline segment
   ** similar statistics for AGL, ATTITUDE (pitch, roll, heading)

   orig: amar nayegandhi 12/26/08.
   INPUT:
      fptr = pointer array returned by the split_by_fltline function
      indx = array of fltline segments to be merged, e.g. [1,2,5] will determine statistics for the 1st, 2nd and 5th fltline segment in fptr.
   OUTPUT:
     Does not output anything at this time.
*/
   
   extern pnav, tans;

   if (is_void(indx)) indx = [1];
   n_indx = numberof(indx);
   n_segs = numberof(fptr);

   for (i=1;i<=n_indx;i++) {
      seg_data = *fptr(indx(i));

      n_sd = numberof(seg_data);
      sd_type = structof(seg_data(1));

      //Raster numbers:
      sd_fromraster = min(seg_data.rn&0xffffff);
      sd_toraster = max(seg_data.rn&0xffffff);

      // TIME:
      sd_minsoe = min(seg_data.soe);
      sd_maxsoe = max(seg_data.soe);
      sd_mintime = soe2time(sd_minsoe);
      sd_maxtime = soe2time(sd_maxsoe);
      sd_minsod = soe2sod(sd_minsoe);
      sd_maxsod = soe2sod(sd_maxsoe);
      sd_minhms = sod2hms(sd_minsod, noary=1);
      sd_maxhms = sod2hms(sd_maxsod, noary=1);

      // Elevations:
      sd_minfselv = min(seg_data.elevation)/100.;
      sd_maxfselv = max(seg_data.elevation)/100.;

      if (sd_type == GEO) {
        sd_minbathy = min(seg_data.elevation+seg_data.depth)/100.;
        sd_maxbathy = max(seg_data.elevation+seg_data.depth)/100.;
      }

      if (sd_type == VEG__) {
        sd_minbathy = min(seg_data.lelv)/100.;
        sd_maxbathy = max(seg_data.lelv)/100.;
      }

      if (is_array(pnav)) {
         sd_pnav_idx = where((pnav.sod >= sd_minsod) & (pnav.sod <= sd_maxsod));
         sd_pnav = pnav(sd_pnav_idx);

         // PDOPS
         sd_minpdop = min(sd_pnav.pdop);
         sd_maxpdop = max(sd_pnav.pdop);
         sd_avgpdop = avg(sd_pnav.pdop);
         sd_medpdop = median(sd_pnav.pdop);

         // AGL
         sd_minalt = min(sd_pnav.alt);
         sd_maxalt = max(sd_pnav.alt);
         sd_avgalt = avg(sd_pnav.alt);
         sd_medalt = median(sd_pnav.alt);

      }
      if (is_array(tans)) {
         sd_tans_idx = where((tans.sod >= sd_minsod) & (tans.sod <= sd_maxsod));
         sd_tans = tans(sd_tans_idx);

         // ATTITUDE 
         sd_minroll = min(sd_tans.roll);
         sd_maxroll = max(sd_tans.roll);
         sd_avgroll = avg(sd_tans.roll);
         sd_medroll = median(sd_tans.roll);

         sd_minpitch = min(sd_tans.pitch);
         sd_maxpitch = max(sd_tans.pitch);
         sd_avgpitch = avg(sd_tans.pitch);
         sd_medpitch = median(sd_tans.pitch);

         sd_minheading = min(sd_tans.heading);
         sd_maxheading = max(sd_tans.heading);
         sd_avgheading = avg(sd_tans.heading);
         sd_medheading = median(sd_tans.heading);
      }
   }
}

func tk_sdw_send_times(obj, idx, data) {
   mintime = soe2iso8601(data.soe(min));
   maxtime = soe2iso8601(data.soe(max));
   
   cmd = swrite(format="%s set_time %d {%s} {%s}",
      obj, idx, mintime, maxtime);

   tkcmd, cmd;
}

func tk_swd_define_region_possible(obj) {
   if(is_void(edb) || is_void(pnav)) {
      tkcmd, swrite(format="%s define_region_not_possible", obj);
   } else {
      tkcmd, swrite(format="%s define_region_is_possible", obj);
   }
}

func tk_sdw_define_region_variables(obj, ..) {
   extern _tk_swd_region, pnav, edb, q;
   _tk_swd_region = [];

   avail_min = edb.seconds(min);
   avail_max = edb.seconds(max);

   multi_flag = 0;

   while(more_args()) {
      data = next_arg();
      ptr = split_by_fltline(data);
      if(numberof(ptr) > 1) {
         multi_flag = 1;
      }
      for(i = 1; i <= numberof(ptr); i++) {
         segment = *ptr(i);
         smin = segment.soe(min);
         smax = segment.soe(max);
         
         if(smin < avail_min || smax > avail_max) {
            tkcmd, swrite(format="%s define_region_mismatch", obj);
            _tk_swd_region = [];
            return;
         }

         smin = soe2sod(smin);
         smax = soe2sod(smax);
         while(smin < pnav.sod(min)) smin += 86400;
         while(smax < pnav.sod(min)) smax += 86400;

         idx = where(smin <= pnav.sod & pnav.sod <= smax);
         if(numberof(idx)) {
            grow, _tk_swd_region, idx;
         }
      }
   }
   _tk_swd_region = set_remove_duplicates(_tk_swd_region);
   if(multi_flag) {
      tkcmd, swrite(format="%s define_region_multilines", obj);
   } else {
      q = _tk_swd_region;
      tkcmd, swrite(format="%s define_region_successful", obj);
   }
}

