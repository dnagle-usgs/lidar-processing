/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */

/**********************************************************************

  $Id$
  Original: Amar Nayegandhi 12/26/08
  Contains:

*********************************************************************/

func split_by_fltline(data) {
/* DOCUMENT split_by_fltline(data)
   This function splits the data by flightline.
   orig: amar nayegandhi 12/26/08.
   INPUT:
      data = input data array of type (R,FS,GEO,VEG__, ATM, etc.)
   OUTPUT:
      fptr = array of pointers pointing to the flight segments
      for e.g. - f1 = *fptr(1) is the first flight line segment
                 f2 = *fptr(2) is the 2nd flight line segment
                 fn = *fptr(n) is the nth flight line segment.
*/
   // convert data to point format (if in raster format) and clean
   data = test_and_clean(data);
   // sort data by time
   data = data(sort(data.soe));
   n_data = numberof(data);
   tidx = where(data.soe(dif) > 180); // assume flightlines are split by at least 180 seconds (3 mins)
   if(numberof(tidx)) {
      n_lines = numberof(tidx) + 1; // total number of flightline segments in data
      segs_idx = grow(1,tidx+1,1); // create segment list array.
   } else {
      n_lines = 1;
      segs_idx = [1, 1];
   }
   write, format="Total flightline segments = %3d\n",n_lines;
   fptr = array(pointer, n_lines);
   for (i=1;i<=n_lines;i++) {
     fltseg = data(segs_idx(i):segs_idx(i+1)-1);
     fptr(i) = &fltseg;
   }
   return fptr;
}

func find_numberof_segments(data) {
/* DOCUMENT find_numberof_segments(data)
   This function outputs the number of segments in data
   orig: amar nayegandhi 12/26/08.
   INPUT:
      data = input data array of type (R,FS,GEO,VEG__, ATM, etc.)
   OUTPUT:
      n_lines = number of flightline segments
*/
   
    // convert data to point format (if in raster format) and clean
    data = test_and_clean(data);
    // sort data by time
    data = data(sort(data.soe));
    n_data = numberof(data);
    tidx = where(data.soe(dif) > 180); // assume flightlines are split by at least 180 seconds (3 mins)
    n_lines = numberof(tidx) + 1; // total number of flightline segments in data

    return n_lines;
}

func merge_fltline_segments(fptr, indx=) {
/* DOCUMENT merge_fltline_segments(fptr, indx=)
   This function merges the flightline segments.
   orig: amar nayegandhi 12/26/08.
   INPUT:
      fptr = pointer array returned by the split_by_fltline function
      indx = array of fltline segments to be merged, e.g. [1,2,5] will merge the 1st, 2nd and 5th fltline segment in fptr.
   OUTPUT:
      merged_segs = merged array
*/

   if (is_void(indx)) indx = [1];
   merged_segs = [];
   n_indx = numberof(indx);
   if (is_pointer(fptr)) {
      for (i=1;i<=n_indx;i++) {
         varname = *fptr(indx(i));
         merged_segs = grow(merged_segs, varname);
      }
   }

   return merged_segs;
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
