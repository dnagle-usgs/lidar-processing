// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
write, "$Id$";

func raspulsearch(data, win=, buf=, cmin=, cmax=, msize=, disp_type=, ptype=,
fset=, lmark=, bconst=, xyz_data=, xyz_buf=, tx=) {
/* DOCUMENT mindata = raspulsearch(data, win=, buf=, cmin=, cmax=, msize=,
   disp_type=, ptype=, fset=, lmark=, bconst=, xyz_data=, xyz_buf=, tx=)

  This function allows the user to click on an EAARL point cloud data plot and
  does the following:

      1. Finds the processed xyz point nearest to the mouse click in the image
         plot.
      2. Displays the corresponding RGB image (if available), raster, and
         waveform.
      3. Displays detailed information about the selected laser pulse in the
         yorick terminal window.

   This function can be invoked from the 'Process EAARL Data' GUI by clicking
   the 'Pixel Waveform' Button.

   Inputs:
      data: Input data array (processed EAARL data).
      (mouse click): User must click on the input data window after calling the
         function.

   Options:
      win= Input data window number (where "data" is plotted). Default: 5.
      buf= Maximum radial distance in cm within which the nearest data point
         will be searched. If no xyz point is located within this distance from
         the mouse click, the function will halt. Default: 1000 (10m).
      cmin= Minimum elevation for defining range to plot the selected data
         point.
      cmax= Maximum elevation for defining range to plot the selected data
         point.
      msize= Marker size of the plotted data point. Default: 1.0.
      disp_type= Type of data to display. Valid values:
            0 = First Return Topography (default)
            1 = Submerged Topography
            2 = Water Depth
            3 = Bare Earth Topography
            4 = Surface Amplitude
            5 = Bottom Amplitude
            6 = Canopy Height
      ptype= Type of processed data array. Valid values:
            0 = First Return Topo
            1 = Submerged Topo
            2 = Topo Under Veg
            3 = Multi Peak Veg [Not implemented]
            4 = Direct Wave Spectra [Not implemented]
      fset= No longer used. (Has no effect.)
      lmark= UNKNOWN
      bconst= Specifies which waveform to show. Valid values:
            0 = Show bathy waveform without constants (default)
            1 = Show bathy waveform with constants
            2 = Show both bathy waveforms (with and without constants)
      xyz_data= 3-d (x,y,z) data array representing ground truth data. If this
         array is present, the function will search for the nearest xyz ground
         truth data point and print out the difference between the selected
         pixel and the ground truth point. Values should all be in meters.
      xyz_buf= The range in meters around the search point within which to
         search for a ground truth point. Default: 2.
      tx= Display 10 transmit waveform if non-zero, starting with the supplied
         value. Default: 0.

   Returns:
      Array mindata, which is an array of type 'ptype' that includes all the
      data points selected in this iteration.

   Original by: Amar Nayegandhi 06/11/02
*/
   extern pnav_filename, wfa, edb, _last_rastpulse, _last_soe, _rastpulse_reference;

   default, _last_rastpulse, [0.0, 0.0, 0.0, 0.0];
   default, _last_soe, 0;

   default, win, 5;
   default, buf, 1000;     // 10 meters
   default, cmin, [];
   default, cmax, [];
   default, msize, 1.0;
   // disp_type corresponds to return value of l1pro.ytk's display_type
   default, disp_type, 0;  // default fs topo
   // ptype corresponds to return value of l1pro.ytk's processing_mode
   default, ptype, 0;      // default fs topo
   default, fset, 0;
   default, lmark, [];
   default, bconst, 0;
   default, xyz_data, [];
   default, xyz_buf, 2;
   default, tx, 0;

   // Sanitize data
   if(typeof(data)=="pointer") data = *data(1);
   data = test_and_clean(data);

   window, win;

   /*
   Mouse commands:

   left            Examine a point
   middle          Set reference point
   right           Quit

   shift-left      Append point
   shift-middle
   shift-right

   control-left
   control-middle
   control-right
   */

   left_mouse  = 1;
   center_mouse = 2;
   right_mouse = 3;

   ctl_left_mouse = 41;

   rtn_data = [];
   nsaved = 0;
   do {
      write, format="Window: %d. Left: examine point, Center: Set Reference, Right: Quit\n", win;

      window, win;
      spot = mouse(1, 1, "");
      mouse_button = spot(10) + 10 * spot(11);

      if(mouse_button == right_mouse) break;

      if(mouse_button == ctl_left_mouse) {
         if(is_void(mindata)) {
            write, "\007You must first select a point before you can append it.";
            continue;
         }

         grow, finaldata, mindata;
         write, format="\007Point appended to finaldata. Total saved =%d\n", ++nsaved;
         if(is_array(edb)) {
            ex_bath, rasterno, pulseno, win=0, graph=1;
            window, 4;
            plcm, (mindata.elevation+mindata.depth)/100., mindata.north/100.,
               mindata.east/100., msize=msize, cmin=cmin, cmax=cmax, marker=4;
            window, win;
            plmk, mindata.north/100., mindata.east/100., msize=msize/3.0,
               color="red", marker=2, width=5;
         }

         continue;
      }

      write, "=============================================================";

      mindata = raspulsearch_findpoint(data, spot, buf);
      if(!is_void(mindata)) {
         rasterno = mindata.rn&0xffffff;
         pulseno = mindata.rn/0xffffff;

         if(_ytk) {
            if(strlen(data_path) > 0) {
               window, 1, wait=1;
               ytk_rast, rasterno(1);
               window, 0, wait=1;
               fma;
               redraw;
               tkcmd, swrite(format="set rn %d", rasterno(1));
            }
            if(is_void(cmin) || is_void(cmax) || lmark) {
               window, win;
               plmk, mindata.north/100., mindata.east/100., msize=0.4,
                  marker=lmark, color="red";
            } else {
               // Plot waveforms, if edb is present
               if(is_array(edb)) {
                  if((bconst == [0,2])(sum) && (disp_type == [0,1,2,3,4])(sum)) {
                     wf_win = bconst ? 7 : 0;
                     wf_win = (disp_type == [0,4])(sum) ? 0 : wf_win;
                     show_wf, *wfa, pulseno(1), win=wf_win, cb=7, raster=rasterno(1);
                  }
                  if(bconst) {
                     if((disp_type == [1,2])(sum))
                        ex_bath, rasterno, pulseno, win=0, graph=1;
                     if(disp_type == 3)
                        ex_veg, rasterno, pulseno, last=250, graph=1, win=0,
                           use_be_peak=1;
                  }
               }

               // Bathy gets different markers
               if((disp_type == [1,2])(sum)) {
                  msz = mindata.depth ? 2.0 : 1.0;
                  mkr = mindata.depth ? 4 : 6;
               } else {
                  msz = 1.5;
                  mkr = 4;
               }

               // Figure out what elevation/etc. value to use
               z = [];
               if(disp_type == 0) {
                  z = mindata.elevation/100.;
               } else if(disp_type == 1) {
                  z = (mindata.elevation+mindata.depth)/100.;
               } else if(disp_type == 2) {
                  z = mindata.depth/100.;
               } else if(disp_type == 3) {
                  z = mindata.lelv/100.;
               } else if(disp_type == 4) {
                  if(ptype == 0)
                     z = mindata.intensity/100.;
                  else if(ptype == 1)
                     z = mindata.first_peak;
                  else if(ptype == 2)
                     z = mindata.fint;
               } else if(disp_type == 5) {
                  if(ptype == 1)
                     z = mindata.bottom_peak;
                  else if(ptype == 2)
                     z = mindata.lint;
               } else if(disp_type == 6) {
                  z = (mindata.lelv-mindata.felv)/100.;
               }

               if(!is_void(z)) {
                  window, win;
                  plcm, z, mindata.north/100., mindata.east/100.,
                     msize=msize*msz, cmin=cmin, cmax=cmax, marker=mkr;
               }
            }
         }
      } else {
         print, "No points found.\n";
      }

      if(!is_void(mindata) && is_array(edb)) {
         rast = decode_raster(get_erast(rn=rasterno));
         geo_rast, rasterno;

         // XYZZY rwm 2008-11-10
         // plot tx waveform.
         if(tx > 0) {
            window, 3;
            fma;
            for(j = tx; j <= tx+10; j++) {
               plg, *rast.tx(j);
            }
            limits, 0, 16, 0, 255;
         }
         // end XYZZY
      }

      dump_info, edb, mindata, last=_last_rastpulse, ref=_rastpulse_reference;

      if(mouse_button == center_mouse) {
         _rastpulse_reference = array(double, 4);
         _rastpulse_reference(1) = mindata.north;
         _rastpulse_reference(2) = mindata.east;
         _rastpulse_reference(3) = mindata.elevation;
         if(structof(mindata(1)) == GEO)
            _rastpulse_reference(4) = (mindata.elevation+mindata.depth)/100.;
         if(structof(mindata(1)) == VEG__)
            _rastpulse_reference(4) = mindata.lelv/100.
      }

      if(is_void(_rastpulse_reference)) {
         write, " No reference point set";
      } else {
         write, format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n",
            sqrt(double(mindata.north - _rastpulse_reference(1))^2 +
            double(mindata.east  - _rastpulse_reference(2))^2)/100.0,
            (mindata.elevation/100.0 - _rastpulse_reference(3)/100.0);
      }

      write, "=============================================================";
      write, "\n";

      if(is_array(edb))
         _last_soe = edb(mindata.rn&0xffffff).seconds;
      _last_rastpulse(3) = mindata.elevation;
      _last_rastpulse(1) = mindata.north;
      _last_rastpulse(2) = mindata.east;

      if(structof(mindata(1)) == GEO)
         _last_rastpulse(4) = (mindata.elevation+mindata.depth);

      if(structof(mindata(1)) == VEG__)
         _last_rastpulse(4) = mindata.lelv;
      // Collect all the click-points and return them so the user
      // can do stats or whatever on them.
      grow, rtn_data, mindata;

      // if ground truth data are available...
      if(is_array(xyz_data))
         raspulsearch_groundtruth, mindata, xyz_data, xyz_buf;

   } while(mouse_button != right_mouse);

   q = *(rcf( rtn_data.elevation, 1000.0, mode=2)(1));
   write, "*************************************************************************************";
   write, format=" * Trajectory file: %-64s *\n", pnav_filename;
   write, format=" * %d points, avg elev: %6.3fm, %6.1fcm RMS, %6.1fcm Peak-to-peak                  *\n",
      numberof(rtn_data), rtn_data.elevation(q)(avg)/100.0,
      rtn_data.elevation(q)(rms), float(rtn_data.elevation(q)(ptp));
   write, "*************************************************************************************";

   return rtn_data;
}

func raspulsearch_findpoint(data, spot, buf) {
/* DOCUMENT raspulsearch_findpoint(data, spot, buf)
   Primarily intended to be called from raspulsearch.

   Arguments:
      data: An array of EAARL data with east and north fields.
      spot: The result of a mouse-click. spot(1) is x, spot(2) is y.
      buf: The distance from spot in which to search.
*/
   w = data_box(data.east, data.north, spot(1)*100-buf, spot(1)*100+buf,
      spot(2)*100-buf, spot(2)*100+buf);

   mindata = [];
   if(numberof(w)) {
      x1 = data(w).east/100.;
      y1 = data(w).north/100.;
      dist = sqrt((x1-spot(1))^2 + (y1-spot(2))^2);
      if(dist(min) <= buf)
         mindata = data(w)(dist(mnx));
   }

   return mindata;
}

func raspulsearch_groundtruth(mindata, xyz_data, xyz_buf) {
/* DOCUMENT raspulsearch_groundtruth, mindata, xyz_data, xyz_buf
   Primarily intended to be called from raspulsearch.

   Arguments:
      mindata: A single point of data with east, north, and elevation fields.
      xyz_data= 3-d (x,y,z) data array representing ground truth data. The
         function will search for the nearest xyz ground truth data point and
         print out the difference between the selected pixel and the ground
         truth point. Values should all be in meters.
      xyz_buf= The range in meters around the search point within which to
         search for a ground truth point.

   If any arguments are void, this is a no-op.
*/
   if(is_void(mindata) || is_void(xyz_data) || is_void(xyz_buf))
      return;

   n_xyz = numberof(xyz_data(1,));
   xyz_fs = array(FS, n_xyz);
   xyz_fs.east = long(xyz_data(1,)*100);
   xyz_fs.north = long(xyz_data(2,)*100);
   xyz_fs.elevation = long(xyz_data(3,)*100);

   point = [mindata.east, mindata.north, mindata.elevation]/100.;

   indx_xyz = sel_data_ptRadius(xyz_fs, point=point, radius=xyz_buf,
      msize=0.2, retindx=1, silent=1);
   // now find nearest point
   mindist = xyz_buf*sqrt(2);
   minxyz_fs = [];
   for(j = 1; j <= numberof(indx_xyz); j++) {
      x1 = (xyz_fs(indx_xyz(j)).east)/100.0;
      y1 = (xyz_fs(indx_xyz(j)).north)/100.0;
      dist = sqrt((point(1)-x1)^2 + (point(2)-y1)^2);
      if(dist <= mindist) {
         mindist = dist;
         minxyz_fs = xyz_fs(indx_xyz(j));
         minindx_xyz = indx_xyz(j);
      }
   }
   if(is_void(minxyz_fs)) {
      write, "No XYZ Ground Truth Data point found within search range";
   } else {
      xyz_diff = point(3) - minxyz_fs.elevation/100.;
      write, "Comparing with XYZ Ground Truth Data...";
      write, format="Nearest XYZ point to selected point is %3.2f m away\n", dist;
      write, format="Elevation difference between selected point and ground truth data point = %3.2f\n", xyz_diff;
   }
   write, "====================================================";
}

func intensity_channel(intensity) {
/* DOCUMENT channel = intensity_channel(intensity)
   Returns the channel associated with the given intensity.

      channel = 1  if  intensity < 255
      channel = 2  if  300 <= intensity < 600
      channel = 3  if  600 <= intensity < 900
      channel = 0  otherwise

   Works for both scalars and arrays.
*/
// Original David Nagle 2009-07-21
   result = array(0, dimsof(intensity));
   result += (intensity < 255);
   result += 2 * ((intensity >= 300) & (intensity < 600));
   result += 3 * ((intensity >= 600) & (intensity < 900));
   return result;
}

func dump_info(edb, mindata, minindx, last=, ref=) {
/* DOCUMENT dump_info, edb, mindata, minindx, last=, ref=

   NEEDS DOCUMENTATION
*/
   if(is_void(ref)) last = [0.0, 0.0, 0.0, 0.0];
   if(!is_array(edb)) {
      write, "edb is not set, try again";
      return;
   }

   rasterno  = mindata.rn&0xffffff;
   pulseno   = mindata.rn/0xffffff;
   _last_soe = edb(mindata.rn&0xffffff).seconds;

   somd = edb(mindata.rn&0xffffff).seconds % 86400;
   rast = decode_raster(get_erast(rn=rasterno));

   fsecs = rast.offset_time - edb(mindata.rn&0xffffff).seconds ;
   ztime = soe2time(somd);
   zdt   = soe2time(abs(edb(mindata.rn&0xffffff).seconds - _last_soe));

   if(is_array(tans) && is_array(pnav)) {
      pnav_idx = abs(pnav.sod - somd)(mnx);
      tans_idx = abs(tans.somd - somd)(mnx);
      knots = lldist(pnav(pnav_idx).lat, pnav(pnav_idx).lon,
         pnav(pnav_idx+1).lat, pnav(pnav_idx+1).lon) *
         3600.0/abs(pnav(pnav_idx+1).sod - pnav(pnav_idx).sod);
   }

   write, "\n=============================================================";
   write, format="                  Raster/Pulse: %d/%d UTM: %7.1f, %7.1f\n",
      mindata.rn&0xffffff, pulseno, mindata.north/100.0, mindata.east/100.0;

   if(is_array(edb)) {
      write, format="        Time: %7.4f (%02d:%02d:%02d) Delta:%d:%02d:%02d \n",
         double(somd)+fsecs(pulseno),
         ztime(4), ztime(5), ztime(6),
         zdt(4), zdt(5), zdt(6);
   }
   if(is_array(tans) && is_array(pnav)) {
      write, format="    GPS Pdop: %8.2f  Svs:%2d  Rms:%6.3f Flag:%d\n",
         pnav(pnav_idx).pdop, pnav(pnav_idx).sv, pnav(pnav_idx).xrms,
         pnav(pnav_idx).flag;
      write, format="     Heading:  %8.3f Pitch: %5.3f Roll: %5.3f %5.1fm/s %4.1fkts\n",
         tans(tans_idx).heading, tans(tans_idx).pitch, tans(tans_idx).roll,
         knots * 1852.0/3600.0, knots;
   }

   hy = sqrt(double(mindata.melevation - mindata.elevation)^2 +
      double(mindata.meast - mindata.east)^2 +
      double(mindata.mnorth - mindata.north)^2);

   if((mindata.melevation > mindata.elevation) && (mindata.elevation > -100000))
      aoi = acos((mindata.melevation - mindata.elevation) / hy) * rad2deg;
   else
      aoi = -9999.999;
   write, format="Scanner Elev: %8.2fm   Aoi:%6.3f Slant rng:%6.3f\n",
      mindata.melevation/100.0, aoi, hy/100.0;

   write, format="First Surface elev: %8.2fm Delta: %7.2fm\n",
      mindata.elevation/100.0, mindata.elevation/100.0 - last(3)/100.0;

   if(structof(mindata(1)) == FS) {
      fs_chn_used = intensity_channel(mindata.intensity);

      write, format="First Surface channel / intensity: %d / %3d\n",
         fs_chn_used, mindata.intensity;
   }

   if(structof(mindata(1)) == VEG__) {
      fs_chn_used = intensity_channel(mindata.fint);
      be_chn_used = intensity_channel(mindata.lint);

      write, format="Last return elev: %8.2fm Delta: %7.2fm\n",
         mindata.lelv/100., mindata.lelv/100.-last(4)/100.
      write, format="First/Last return elv DIFF: %8.2fm\n",
         (mindata.elevation-mindata.lelv)/100.;
      write, format="First Surface channel-intensity: %d-%3d\n",
         fs_chn_used, mindata.fint;
      write, format="Last Surface channel-intensity: %d-%3d\n",
         be_chn_used, mindata.lint;
   }

   if(structof(mindata(1)) == GEO) {
      fs_chn_used = intensity_channel(mindata.first_peak);
      be_chn_used = intensity_channel(mindata.bottom_peak);

      write, format="Bottom elev: %8.2fm Delta: %7.2fm\n",
         (mindata.elevation+mindata.depth)/100.,
         (mindata.elevation+mindata.depth)/100.-_last_rastpulse(4)/100.;
      write, format="First/Bottom return elv DIFF: %8.2fm", mindata.depth/100.;
      write, format="Surface channel-intensity: %d-%3d\n", fs_chn_used,
         mindata.first_peak;
      write, format="Bottom channel / intensity: %d-%3d\n", be_chn_used,
         mindata.bottom_peak;
   }

   write, "=============================================================\n";
}

func old_refjunk(void) {
/* DOCUMENT old_refjunk;
   (needs documentation)
*/
   extern mouse_button, center_mouse, mindata;
   if(mouse_button == center_mouse) {
      _rastpulse_reference = array(double, 4);
      _rastpulse_reference(1) = mindata.north;
      _rastpulse_reference(2) = mindata.east;
      _rastpulse_reference(3) = mindata.elevation;
      if(structof(mindata(1)) == GEO)
         _rastpulse_reference(4) = (mindata.elevation+mindata.depth)/100.;
      if(structof(mindata(1)) == VEG__)
         _rastpulse_reference(4) = mindata.lelv/100.;
   }

   if(is_void(_rastpulse_reference)) {
      write, " No reference point set";
   } else {
      write, format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n",
         sqrt(double(mindata.north - _rastpulse_reference(1))^2 +
               double(mindata.east - _rastpulse_reference(2))^2)/100.0,
         (mindata.elevation/100.0 - _rastpulse_reference(3)/100.0) ;
   }
}
