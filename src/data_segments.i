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

func plot_statistically(y, x, title=, xtitle=, ytitle=, nofma=, win=) {
   default, nofma, 0;
   default, win, max([current_window(), 0]);
   default, xtitle, "red: mean, deviations; blue: median and quartiles";

   w = current_window();
   window, win;

   if(! nofma)
      fma;

   count = numberof(y);
   default, x, indgen(count);
   qs = quartiles(y);
   plg, array(qs(2), count), x, color="blue", width=1;
   plg, array(qs(1), count), x, color="blue", width=1, type="dash";
   plg, array(qs(3), count), x, color="blue", width=1, type="dash";
   ymin = y(min);
   ymax = y(max);
   yavg = y(avg);
   yrms = y(rms);
   plg, array(ymin, count), x, color="blue", width=1;
   plg, array(ymax, count), x, color="blue", width=1;
   plg, array(yavg, count), x, color="red", width=1, width=4;
   plg, array(yavg-yrms, count), x, color="red", width=1, type="dashdot";
   if(yavg-2*yrms > ymin)
      plg, array(yavg-2*yrms, count), x, color="red", width=1, type="dashdotdot";
   if(yavg-3*yrms > ymin)
      plg, array(yavg-3*yrms, count), x, color="red", width=1, type="dot";
   plg, array(yavg+yrms, count), x, color="red", width=1, type="dashdot";
   if(yavg+2*yrms < ymax)
      plg, array(yavg+2*yrms, count), x, color="red", width=1, type="dashdotdot";
   if(yavg+3*yrms < ymax)
      plg, array(yavg+3*yrms, count), x, color="red", width=1, type="dot";
   plg, y, x, color="black", marks=0, width=1;

   if(title)
      pltitle, title;
   if(xtitle)
      xytitles, xtitle;
   if(ytitle)
      xytitles, , ytitle;

   window_select, w;
}

func tk_dsw_plot_stats(var, data, type, win) {
   title = var + " " + type;
   title = regsub("_", title, "!_", all=1);
   x = y = [];
   if(type == "elevation") {
      y = data.elevation;
      x = data.soe;
   } else if(type == "bathy") {
      if(structof(data) == GEO) {
         y = data.elevation + data.depth;
         x = data.soe;
      } else if(structof(data) == VEG__) {
         y = data.lelv;
         x = data.soe;
      }
   } else if(type == "roll") {
      working_tans = tk_dsw_get_data(data, "dmars", "tans", "somd");
      y = working_tans.roll;
      x = working_tans.somd;
   } else if(type == "pitch") {
      working_tans = tk_dsw_get_data(data, "dmars", "tans", "somd");
      y = working_tans.pitch;
      x = working_tans.somd;
   } else if(type == "pdop") {
      working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
      y = working_pnav.pdop;
      x = working_pnav.sod;
   } else if(type == "alt") {
      working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
      y = working_pnav.alt;
      x = working_pnav.sod;
   }
   plot_statistically, y, x, title=title, win=win;
}


func gather_data_stats(data, &working_tans, &working_pnav) {
   stats = h_new();

   // First, pull stats out of the data itself:

   // elevation
   stat_temp = h_new();
   qs = quartiles(data.elevation);
   h_set, stat_temp, "q1", qs(1)/100.;
   h_set, stat_temp, "med", qs(2)/100.;
   h_set, stat_temp, "q3", qs(3)/100.;
   h_set, stat_temp, "min", data.elevation(min)/100.;
   h_set, stat_temp, "max", data.elevation(max)/100.;
   h_set, stat_temp, "avg", data.elevation(avg)/100.;
   h_set, stat_temp, "rms", data.elevation(rms)/100.;
   h_set, stats, "elevation", stat_temp;

   if(structof(data) == GEO) {
      temp_data = data.elevation + data.depth;
      stat_temp = h_new();
      qs = quartiles(temp_data.elevation);
      h_set, stat_temp, "q1", qs(1)/100.;
      h_set, stat_temp, "med", qs(2)/100.;
      h_set, stat_temp, "q3", qs(3)/100.;
      h_set, stat_temp, "min", temp_data.elevation(min)/100.;
      h_set, stat_temp, "max", temp_data.elevation(max)/100.;
      h_set, stat_temp, "avg", temp_data.elevation(avg)/100.;
      h_set, stat_temp, "rms", temp_data.elevation(rms)/100.;
      h_set, stats, "bathy", stat_temp;
   }

   if(structof(data) == VEG__) {
      stat_temp = h_new();
      qs = quartiles(data.lelv);
      h_set, stat_temp, "q1", qs(1)/100.;
      h_set, stat_temp, "med", qs(2)/100.;
      h_set, stat_temp, "q3", qs(3)/100.;
      h_set, stat_temp, "min", data.lelv(min)/100.;
      h_set, stat_temp, "max", data.lelv(max)/100.;
      h_set, stat_temp, "avg", data.lelv(avg)/100.;
      h_set, stat_temp, "rms", data.lelv(rms)/100.;
      h_set, stats, "bathy", stat_temp;
   }

   // Now attempt to extract from tans
   working_tans = tk_dsw_get_data(data, "dmars", "tans", "somd");
   if(numberof(working_tans)) {
      // roll
      stat_temp = h_new();
      qs = quartiles(working_tans.roll);
      h_set, stat_temp, "q1", qs(1);
      h_set, stat_temp, "med", qs(2);
      h_set, stat_temp, "q3", qs(3);
      h_set, stat_temp, "min", working_tans.roll(min);
      h_set, stat_temp, "max", working_tans.roll(max);
      h_set, stat_temp, "avg", working_tans.roll(avg);
      h_set, stat_temp, "rms", working_tans.roll(rms);
      h_set, stats, "roll", stat_temp;

      // pitch
      stat_temp = h_new();
      qs = quartiles(working_tans.pitch);
      h_set, stat_temp, "q1", qs(1);
      h_set, stat_temp, "med", qs(2);
      h_set, stat_temp, "q3", qs(3);
      h_set, stat_temp, "min", working_tans.pitch(min);
      h_set, stat_temp, "max", working_tans.pitch(max);
      h_set, stat_temp, "avg", working_tans.pitch(avg);
      h_set, stat_temp, "rms", working_tans.pitch(rms);
      h_set, stats, "pitch", stat_temp;

      // heading
      angrng = angular_range(working_tans.heading);
      if(angrng(3) < 90) {
         stat_temp = h_new();
         h_set, stat_temp, "min", angrng(1);
         h_set, stat_temp, "max", angrng(2);
         amin = angrng(1);
         htemp = working_tans.heading;
         htemp *= pi / 180.;
         htemp = atan(sin(htemp),cos(htemp));
         htemp *= 180. / pi;
         htemp -= amin;
         qs = quartiles(htemp) + amin;
         h_set, stat_temp, "q1", qs(1);
         h_set, stat_temp, "med", qs(2);
         h_set, stat_temp, "q3", qs(3);
         h_set, stat_temp, "avg", amin + htemp(avg);
         h_set, stat_temp, "rms", htemp(rms);
         amin = htemp = [];
         h_set, stats, "heading", stat_temp;
      }
   }

   // Now attempt to extract from pnav
   working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
   if(numberof(working_pnav)) {
      // pdop
      stat_temp = h_new();
      qs = quartiles(working_pnav.pdop);
      h_set, stat_temp, "q1", qs(1);
      h_set, stat_temp, "med", qs(2);
      h_set, stat_temp, "q3", qs(3);
      h_set, stat_temp, "min", working_pnav.pdop(min);
      h_set, stat_temp, "max", working_pnav.pdop(max);
      h_set, stat_temp, "avg", working_pnav.pdop(avg);
      h_set, stat_temp, "rms", working_pnav.pdop(rms);
      h_set, stats, "pdop", stat_temp;

      // alt
      stat_temp = h_new();
      qs = quartiles(working_pnav.alt);
      h_set, stat_temp, "q1", qs(1);
      h_set, stat_temp, "med", qs(2);
      h_set, stat_temp, "q3", qs(3);
      h_set, stat_temp, "min", working_pnav.alt(min);
      h_set, stat_temp, "max", working_pnav.alt(max);
      h_set, stat_temp, "avg", working_pnav.alt(avg);
      h_set, stat_temp, "rms", working_pnav.alt(rms);
      h_set, stats, "alt", stat_temp;
   }

   return stats;
}

func tk_dsw_send_stats(obj, var, data) {
   stats = gather_data_stats(data);
   json = yorick2json(stats, compact=1);
   tkcmd, swrite(format="%s set_stats {%s} {%s}", obj, var, json);
}

func tk_dsw_get_data(data, type, var, sod_field) {
// Extract either tans or pnav data for a set of mission days for a given data
// tk_dsw_get_data(data, "dmars", "tans");
// tk_dsw_get_data(data, "pnav", "pnav");
   extern tans, pnav;

   // First, we need to figure out what date or dates are represented by the data
   segment_ptrs = split_by_fltline(data);
   dates = [];
   for(i = 1; i <= numberof(segment_ptrs); i++) {
      temp = *segment_ptrs(i);
      ymd = soe2ymd(temp.soe(min));
      grow, dates, swrite(format="%04d-%02d-%02d", ymd(1), ymd(2), ymd(3));
      ymd = soe2ymd(temp.soe(max));
      grow, dates, swrite(format="%04d-%02d-%02d", ymd(1), ymd(2), ymd(3));
   }
   dates = set_remove_duplicates(dates);

   // Now, we backup tans-related variables, then get stats for each mission day
   env_backup = missiondata_wrap(type);
   // heading gets handled specially
   working = [];
   for(i = 1; i <= numberof(dates); i++) {
      if(mission_has(type + " file", date=dates(i))) {
         missiondata_load, type, date=dates(i);
         if(! numberof(symbol_def(var)))
            continue;
         for(j = 1; j <= numberof(segment_ptrs); j++) {
            temp = *segment_ptrs(j);

            // Make sure we're only working with data that matches the current dmars
            ymd = soe2ymd(temp.soe(min));
            datemin = swrite(format="%04d-%02d-%02d", ymd(1), ymd(2), ymd(3));
            ymdmin = ymd;
            ymd = soe2ymd(temp.soe(max));
            datemax = swrite(format="%04d-%02d-%02d", ymd(1), ymd(2), ymd(3));
            ymdmax = ymd;

            if(datemin == dates(i) || datemax == dates(i)) {
               if(datemin == datemax) {
                  // temp is fine! do nothing
               } else {
                  // only part of temp is good
                  break_point = ymd2soe(ymdmax(1), ymdmax(2), ymdmax(3));
                  if(datemin == dates(i)) {
                     // early part is good
                     w = where(temp.soe < break_point);
                     temp = temp(w);
                  } else {
                     // later part is good
                     w = where(break_point <= temp.soe);
                     temp = temp(w);
                  }
               }
            } else {
               // completely wrong day
               temp = [];
            }

            if(!numberof(temp))
               continue;

            // At this points, temp's data should fall within dmars' range

            sodmin = soe2sod(temp.soe(min));
            sodmax = soe2sod(temp.soe(max));
            ex_data = symbol_def(var);
            w = where(
               (sodmin <= get_member(ex_data, sod_field)) &
               (get_member(ex_data, sod_field) <= sodmax)
            );
            if(!numberof(w))
               continue;

            ymd = soe2ymd(temp.soe(min));
            soe_base = ymd2soe(ymd(1), ymd(2), ymd(3));
            get_member(ex_data, sod_field) += soe_base;

            grow, working, ex_data(w);
         }
      }
   }
   missiondata_unwrap, env_backup;

   return working;
}
