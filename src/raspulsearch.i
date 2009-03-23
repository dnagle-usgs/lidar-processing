/*
   $Id$
*/


func raspulsearch(data,win=,buf=, cmin=, cmax=, msize=, disp_type=, ptype=, fset=, lmark=, bconst=, xyz_data=, tx=) {
/* DOCUMENT raspulsearch(data,win=,buf=, cmin=, cmax=, msize=, disp_type=, ptype=, fset=)

  This function allows the user to click on an EAARL point cloud data plot and does the following:
  (i) finds the processed xyz point nearest to the mouse click in the image plot
  (ii) displays the corresponding rgb image (if available), raster, and waveform
  (iii) displays detailed information about the selected laser pulse in the yorick terminal window  
 
This function can be invoked from the 'Process EAARL Data' GUI by clicking the 'Pixel Waveform' Button.

  Inputs:
	mouse click on window, win.
	data: input data array

  Options:
	win= input data window number 
	buf= max. radial distance within which the nearest data point will be searched. Defaults to 10m. If no xyz point is located within this distance from the mouse click, the function will halt.
	cmin= min. elevation for defining range to plot the selected data point.
	cmax= max. elevation for defining range to plot the selected data point.
	msize= marker size of the plotted data point. Default = 1.0
	disp_type= type of data to display. Defaults to first surface (fs)
	ptype= Type of processed data array.
		0 = fs topo (default)
		1 = bathymetry 
		2 = tpop under veg.
	fset=	DEFUNCT
		0
        bconst= set to 1 to show the bathy waveform with constants,
		set to 2 to show both waveforms (with and without constants).
        xyz_data = 3-d (x,y,z) data array representing ground truth data.  If this array is present, the function will search for the nearest xyz ground truth data point and print out the difference between the selected pixel and the ground truth point.  The search for the nearest ground truth point will be only within 5m of the selected point.

  tx= display 10 transmit waveform if non-zero, starting with the supplied value.

  Returns:
	Array mindata.  mindata is an array of type 'ptype' that includes all the data points selected in this iteration.

 Original by:
    Amar Nayegandhi 06/11/02
*/
 extern pnav_filename;
 extern wfa, edb
 extern _last_rastpulse
 extern _rastpulse_reference

 if ( is_void(_last_rastpulse ) ) _last_rastpulse = [0.0, 0.0, 0.0, 0.0];
 if ( is_void(_last_soe) )        _last_soe = 0;
 if (!(win))                            win = 5;
 if (!(disp_type))                disp_type = 0; //default fs topo
 if (!(ptype))                        ptype = 0; //default fs topo
 if (!(msize))                        msize = 1.0
 if (!(fset))                          fset = 0
 if (typeof(data)=="pointer")          data = *data(1);
 if (!buf)                              buf = 1000; // 10 meters  
 if (is_void(tx))                       tx = 0;

 window, win;

 data = test_and_clean(data);
 /*
 if (numberof(data) != numberof(data.north)) {
     if ((ptype == 1) && (fset == 0)) { //Convert GEOALL to GEO 
        data = geoall_to_geo(data);
     }
     if ((ptype == 0) && (fset==0)) { //convert R to FS 
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

	data = data_new
     }
     if ((ptype == 2) && (fset == 0)) {  //convert VEG_ALL_ to VEG__
         data = veg_all__to_veg__(data);
     }
 }
*/

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
  left_mouse  = 1
 center_mouse = 2
  right_mouse = 3

 ctl_left_mouse = 41;

 rtn_data = [];
 nsaved = 0;
 do {
 write,format="Window: %d. Left: examine point, Center: Set Reference, Right: Quit\n",win
 window,win; 
 spot = mouse(1,1,"");
 mouse_button = spot(10) + 10 * spot(11);
 if ( mouse_button == right_mouse ) break;

 if ( mouse_button == ctl_left_mouse ) { 
       grow, finaldata, mindata;
       write, format="\007Point appended to finaldata. Total saved =%d\n", ++nsaved;
       if (is_array(edb)) {
        ex_bath, rasterno, pulseno, win=0, graph=1;
        window, 4; plcm, (mindata.elevation+mindata.depth)/100., 
                             mindata.north/100., mindata.east/100., 
                             msize = msize, cmin= cmin, cmax = cmax, 
                             marker=4
        window,win;
	plmk, mindata.north/100., 
               mindata.east/100.,
               msize = msize/3.0, color="red", marker=2, width=5
       }
/*
       window, win; plcm, (mindata.elevation+mindata.depth)/100., 
                             mindata.north/100., mindata.east/100., 
                             msize = msize*3.5, cmin= cmin, cmax = cmax, 
                             marker=2
*/

       continue;
 }


// Breaking the following where into two sections generally increases
// the speed by 2x,  but it can be much faster depending on the geometry
// of the data and the selection box.
 q = where(((data.east >= spot(1)*100-buf)   & 
               (data.east <= spot(1)*100+buf)) )
 
 indx = where(((data.north(q) >= spot(2)*100-buf) & 
               (data.north(q) <= spot(2)*100+buf)));

 indx = q(indx);


write,"============================================================="
 if (is_array(indx)) {
    // print, data(indx);
    rn = data(indx(1)).rn;
    mindist = buf*sqrt(2);
    for (i = 1; i < numberof(indx); i++) {
      x1 = (data(indx(i)).east)/100.0;
      y1 = (data(indx(i)).north)/100.0;
      dist = sqrt((spot(1)-x1)^2 + (spot(2)-y1)^2);
      if (dist <= mindist) {
        mindist = dist;
	mindata = data(indx(i));
	minindx = indx(i);
      }
    }
    blockindx = minindx / 120;
    rasterno = mindata.rn&0xffffff;
    pulseno  = mindata.rn/0xffffff;

///////    write, format="Nearest point: %5.3fm\n", mindist;
///////    write, format="       Raster: %6d    Pulse: %d\n",rasterno, pulseno;
///////    write, format="Plot   raster: %6d waveform: %d\n",rasterno(1), pulseno(1);
    if (_ytk) {
      if (strlen(data_path) > 0) {
       window,1,wait=1;
       ytk_rast, rasterno(1);
       window, 0, wait=1; fma; redraw;
       tkcmd, swrite(format="set rn %d", rasterno(1))
      }
      if (is_void(cmin) || is_void(cmax) || lmark) {
        if (!lmark) marker = 1;
	if (lmark) marker = lmark;
        window, win; plmk, mindata.north/100., 
                           mindata.east/100., 
                           msize = 0.4, marker = lmark, color = "red";
      } else {
        if (disp_type == 0) {
	  if (is_array(edb)) show_wf, *wfa, pulseno(1), win=0, cb=7, raster=rasterno(1);
          window, win; plcm, mindata.elevation/100., 
                             mindata.north/100., 
                             mindata.east/100., 
                             msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, 
                             marker=4
	} else
        if ((disp_type == 1) || (disp_type == 2))  {
	if (is_array(edb)) {
        if (bconst) {
	  a = [];
          irg_a = irg(rasterno,rasterno,usecentroid=1);
          ex_bath, rasterno, pulseno, win=0, graph=1;
         } else {
          show_wf, *wfa, pulseno(1), win=0, cb=7, raster=rasterno(1);
         }
	 if (bconst == 2) {
          show_wf, *wfa, pulseno(1), win=7, cb=7, raster=rasterno(1);
	 }
        }
          
         if ( mindata.depth == 0 ) {
            msz = 1.0; mkr = 6;
         } else {
            msz = 2.0; mkr = 4; 
         }
         if ( disp_type == 1 ) 
             elev = (mindata.elevation+mindata.depth)/100.;
         else
             elev = mindata.depth/100.;

          window, win; plcm, elev, mindata.north/100., 
                             mindata.east/100., msize = msize*msz, 
                             cmin= cmin, cmax = cmax, marker = mkr
	} else if (disp_type == 3)  {
     	  if (is_array(edb)) {
	    a = [];
            irg_a = irg(rasterno,rasterno,usecentroid=1);
	    if (bconst) {
	      ex_veg, rasterno, pulseno,  last=250, graph=1, win=0, use_be_peak=1;
	    } else {
              show_wf, *wfa, pulseno(1), win=0, cb=7, raster=rasterno(1);
	    }
	    if (bconst == 2) {
              show_wf, *wfa, pulseno(1), win=7, cb=7, raster=rasterno(1);
	    }
	      
            if ( _errno < 0 ) continue;
	  }
	  z = mindata.lelv/100.;
          window, win; plcm, z, mindata.north/100., 
                             mindata.east/100., msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, marker = 4
	} else if (disp_type == 4)  {
	  a = [];
	  if (ptype == 0) 
	     z = mindata.intensity/100.;
	  if (ptype == 1) 
	     z = mindata.first_peak;
	  if (ptype == 2) 
	     z = mindata.fint;
          if (is_array(edb)) show_wf, *wfa, pulseno(1), win=0, cb=7, raster=rasterno(1);
          window, win; plcm, z, mindata.north/100., 
                             mindata.east/100., msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, marker = 4
       } else 
        if (disp_type == 5) {
	  a = [];
	  if (ptype == 1) 
	     z = mindata.bottom_peak;
	  if (pytpe = 2) 
	     z = mindata.lint
          window, win; plcm, z, mindata.north/100., 
                             mindata.east/100., msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, marker = 4
       } else 
        if (disp_type == 6) {
	  a = [];
	  z = (mindata.lelv-mindata.felv)/100.;
          window, win; plcm, z, mindata.north/100., 
                             mindata.east/100., msize = msize*1.5, 
                             cmin= cmin, cmax = cmax, marker = 4
       }
      //write, format="minindx = %d\n",minindx;
    } 
   }
 } else {
   print, "No points found.\n";
 }
 if (is_array(edb)) {
   somd = edb(mindata.rn&0xffffff ).seconds % 86400; 
   rast  = decode_raster(get_erast( rn=rasterno ));
   
// XYZZY rwm 2008-11-10
// plot tx waveform.
   if ( tx > 0 ) {
      window,2;
      fma;
      for (j = tx; j <= tx+10; j++) {
         plg,*rast.tx(j);
      }
      limits, 0, 16, 0, 255
   }
// end XYZZY

   fsecs = rast.offset_time - edb(mindata.rn&0xffffff ).seconds ;
   ztime = soe2time( somd );
   zdt   = soe2time( abs(edb( mindata.rn&0xffffff ).seconds - _last_soe) );
 }

if ( 1 ) {
   dump_info, edb, mindata, minindx, last=_last_rastpulse, ref=_rastpulse_reference;
} else {   //  STARTBLOCK
 if (is_array(tans) && is_array(pnav)) {
   pnav_idx = abs( pnav.sod - somd)(mnx);
   tans_idx = abs( tans.somd - somd)(mnx);
   knots = lldist( pnav(pnav_idx).lat,   pnav(pnav_idx).lon,
                 pnav(pnav_idx+1).lat, pnav(pnav_idx+1).lon) * 
                 3600.0/abs(pnav(pnav_idx+1).sod - pnav(pnav_idx).sod);
 }

// XYZZY - Start of text dump
 write,format="        Indx: %4d Raster/Pulse: %d/%d UTM: %7.1f, %7.1f\n", 
 	       blockindx,
               mindata.rn&0xffffff,
	       pulseno,
               mindata.north/100.0,
	       mindata.east/100.0

 if (is_array(edb)) {
/// breakpoint();
   write,format="        Time: %7.4f (%02d:%02d:%02d) Delta:%d:%02d:%02d \n", 
        double(somd)+fsecs(pulseno),
        ztime(4),ztime(5),ztime(6),
        zdt(4), zdt(5), zdt(6);
 }
 if (is_array(tans) && is_array(pnav)) {
   write,format="    GPS Pdop: %8.2f  Svs:%2d  Rms:%6.3f Flag:%d\n", 
	       pnav(pnav_idx).pdop, pnav(pnav_idx).sv, pnav(pnav_idx).xrms,
	       pnav(pnav_idx).flag
   write,format="     Heading:  %8.3f Pitch: %5.3f Roll: %5.3f %5.1fm/s %4.1fkts\n",
	       tans(tans_idx).heading,
	       tans(tans_idx).pitch,
	       tans(tans_idx).roll,
               knots * 1852.0/3600.0, 
               knots;
 }

 hy = sqrt( double(mindata.melevation - mindata.elevation)^2 +
 	    double(mindata.meast      - mindata.east)^2 +
	    double(mindata.mnorth     - mindata.north)^2 );
	  
 if ( (mindata.melevation > mindata.elevation) && ( mindata.elevation > -100000) )
 aoi = acos( (mindata.melevation - mindata.elevation) / hy ) * rad2deg;	
 else aoi = -9999.999;
 write,format="Scanner Elev: %8.2fm   Aoi:%6.3f Slant rng:%6.3f\n", 
 	mindata.melevation/100.0,
	aoi, hy/100.0;

 write,format="Surface elev: %8.2fm Delta: %7.2fm\n",
               mindata.elevation/100.0,
               mindata.elevation/100.0 - _last_rastpulse(3)/100.0
 if (structof(mindata(1)) == GEO) {
  write, format="Bottom elev: %8.2fm Delta: %7.2fm\n",
		(mindata.elevation+mindata.depth)/100.,
		(mindata.elevation+mindata.depth)/100.-_last_rastpulse(4)/100.
 }
 if (structof(mindata(1)) == VEG__) {
  write, format="Last return elev: %8.2fm Delta: %7.2fm\n",
		mindata.lelv/100.,
		mindata.lelv/100.-_last_rastpulse(4)/100.
 }

// XYZZY - end of text dump
}  // ENDBLOCK - if dump_info works, this block can be removed.

   if ( (mouse_button == center_mouse)  ) {
     _rastpulse_reference = array(double, 4);
     _rastpulse_reference(1) = mindata.north;
     _rastpulse_reference(2) = mindata.east;
     _rastpulse_reference(3) = mindata.elevation;
     if (structof(mindata(1)) == GEO) 
	_rastpulse_reference(4) = (mindata.elevation+mindata.depth)/100.
     if (structof(mindata(1)) == VEG__) 
	_rastpulse_reference(4) = mindata.lelv/100.
   }

 if ( is_void(_rastpulse_reference) ) {
   write, " No reference point set"
 } else {
   write,format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n", 
               sqrt(double(mindata.north - _rastpulse_reference(1))^2 +
                    double(mindata.east  - _rastpulse_reference(2))^2)/100.0,
               (mindata.elevation/100.0 - _rastpulse_reference(3)/100.0) ; 
 }
	

write,"============================================================="
 write,"\n"

  if (is_array(edb)) {
   _last_soe = edb( mindata.rn&0xffffff ).seconds;
  }
   _last_rastpulse(3) = mindata.elevation;
   _last_rastpulse(1) = mindata.north;
   _last_rastpulse(2) = mindata.east;

   if (structof(mindata(1)) == GEO) 
	_last_rastpulse(4) = (mindata.elevation+mindata.depth)

   if (structof(mindata(1)) == VEG__) 
	_last_rastpulse(4) = mindata.lelv
// Collect all the click-points and return them so the user
// can do stats or whatever on them.
   grow, rtn_data, mindata;

  // if ground truth data are available...
  if (is_array(xyz_data)) {
        if (is_void(xyz_buf)) xyz_buf = 2;
        n_xyz = numberof(xyz_data(1,));
        xyz_fs = array(FS,n_xyz);
        xyz_fs.east = long(xyz_data(1,)*100);
        xyz_fs.north = long(xyz_data(2,)*100);
        xyz_fs.elevation = long(xyz_data(3,)*100);

        point = [mindata.east,mindata.north,mindata.elevation]/100.;

        indx_xyz = sel_data_ptRadius(xyz_fs, point=point, radius=xyz_buf, msize=0.2, retindx=1, silent=1)
        // now find nearest point
        mindist = xyz_buf*sqrt(2);
        for (j = 1; j <= numberof(indx_xyz); j++) {
          x1 = (xyz_fs(indx_xyz(j)).east)/100.0;
          y1 = (xyz_fs(indx_xyz(j)).north)/100.0;
          dist = sqrt((point(1)-x1)^2 + (point(2)-y1)^2);
          if (dist <= mindist) {
            mindist = dist;
            minxyz_fs = xyz_fs(indx_xyz(j));
            minindx_xyz = indx_xyz(j);
          }
        }
        xyz_diff = point(3) - minxyz_fs.elevation/100.;
        write, "Comparing with XYZ Ground Truth Data..."
        write, format="Nearest XYZ point to selected point is %3.2f m away\n",dist;
        write, format="Elevation difference between selected point and ground truth data point = %3.2f\n",xyz_diff;
        write, "===================================================="

  }
        

} while ( mouse_button != right_mouse );


 q = *(rcf( rtn_data.elevation, 1000.0, mode=2)(1));
 write,"*************************************************************************************"
 write,format=" * Trajectory file: %-64s *\n", pnav_filename
 write,format=" * %d points, avg elev: %6.3fm, %6.1fcm RMS, %6.1fcm Peak-to-peak                  *\n", 
        numberof(rtn_data),
 	rtn_data.elevation(q)(avg)/100.0, 
 	rtn_data.elevation(q)(rms),
 	float(rtn_data.elevation(q)(ptp)); 
write,"*************************************************************************************"
  
 return rtn_data;
      
}

func dump_info(edb, mindata, minindx, last=, ref=) {

 if ( is_void(ref ) ) last = [0.0, 0.0, 0.0, 0.0];

   if ( !is_array(edb)) {
      write, format="edb is not set, try again\n";
   }

// mindata   = data(indx);
   blockindx = minindx / 120;
   rasterno  = mindata.rn&0xffffff;
   pulseno   = mindata.rn/0xffffff;
   _last_soe = edb( mindata.rn&0xffffff ).seconds;

   somd = edb(mindata.rn&0xffffff ).seconds % 86400;
   rast  = decode_raster(get_erast( rn=rasterno ));

   fsecs = rast.offset_time - edb(mindata.rn&0xffffff ).seconds ;
   ztime = soe2time( somd );
   zdt   = soe2time( abs(edb( mindata.rn&0xffffff ).seconds - _last_soe) );

   if (is_array(tans) && is_array(pnav)) {
      pnav_idx = abs( pnav.sod - somd)(mnx);
      tans_idx = abs( tans.somd - somd)(mnx);
      knots = lldist( pnav(pnav_idx).lat,   pnav(pnav_idx).lon,
                      pnav(pnav_idx+1).lat, pnav(pnav_idx+1).lon) *
                      3600.0/abs(pnav(pnav_idx+1).sod - pnav(pnav_idx).sod);
   }

   write,"\n=============================================================";
   write,format="        Indx: %4d Raster/Pulse: %d/%d UTM: %7.1f, %7.1f\n",
      blockindx,
      mindata.rn&0xffffff,
      pulseno,
      mindata.north/100.0,
      mindata.east/100.0;

   if (is_array(edb)) {
/// breakpoint();
      write,format="        Time: %7.4f (%02d:%02d:%02d) Delta:%d:%02d:%02d \n",
         double(somd)+fsecs(pulseno),
         ztime(4),ztime(5),ztime(6),
         zdt(4), zdt(5), zdt(6);
      }
   if (is_array(tans) && is_array(pnav)) {
      write,format="    GPS Pdop: %8.2f  Svs:%2d  Rms:%6.3f Flag:%d\n",
         pnav(pnav_idx).pdop, pnav(pnav_idx).sv, pnav(pnav_idx).xrms,
         pnav(pnav_idx).flag;
      write,format="     Heading:  %8.3f Pitch: %5.3f Roll: %5.3f %5.1fm/s %4.1fkts\n",
         tans(tans_idx).heading,
         tans(tans_idx).pitch,
         tans(tans_idx).roll,
         knots * 1852.0/3600.0,
         knots;
   }

   hy = sqrt( double(mindata.melevation - mindata.elevation)^2 +
   double(mindata.meast      - mindata.east)^2 +
   double(mindata.mnorth     - mindata.north)^2 );

   if ( (mindata.melevation > mindata.elevation) && ( mindata.elevation > -100000) )
      aoi = acos( (mindata.melevation - mindata.elevation) / hy ) * rad2deg;
   else aoi = -9999.999;
   write,format="Scanner Elev: %8.2fm   Aoi:%6.3f Slant rng:%6.3f\n",
      mindata.melevation/100.0,
      aoi, hy/100.0;

   // find out which channel was used to compute the range
   fs_chn_used = 0;
   be_chn_used = 0;

   if (structof(mindata(1)) == FS) {
     if (mindata.intensity < 255) fs_chn_used=1;
     if ((mindata.intensity >= 300) && (mindata.intensity < 600)) fs_chn_used=2;
     if ((mindata.intensity >= 600) && (mindata.intensity < 900)) fs_chn_used=3;
   }

   if (structof(mindata(1)) == VEG__) {
     if (mindata.fint < 255) fs_chn_used=1;
     if ((mindata.fint >= 300) && (mindata.fint < 600)) fs_chn_used=2;
     if ((mindata.fint >= 600) && (mindata.fint < 900)) fs_chn_used=3;
     if (mindata.lint < 255) be_chn_used=1;
     if ((mindata.lint >= 300) && (mindata.lint < 600)) be_chn_used=2;
     if ((mindata.lint >= 600) && (mindata.lint < 900)) be_chn_used=3;
   }

   if (structof(mindata(1)) == GEO) {
     if (mindata.first_peak < 255) fs_chn_used=1;
     if ((mindata.first_peak >= 300) && (mindata.first_peak < 600)) fs_chn_used=2;
     if ((mindata.first_peak >= 600) && (mindata.first_peak < 900)) fs_chn_used=3;
     if (mindata.bottom_peak < 255) be_chn_used=1;
     if ((mindata.bottom_peak >= 300) && (mindata.bottom_peak < 600)) be_chn_used=2;
     if ((mindata.bottom_peak >= 600) && (mindata.bottom_peak < 900)) be_chn_used=3;
   }

   write,format="First Surface elev: %8.2fm Delta: %7.2fm\n",
      mindata.elevation/100.0,
      mindata.elevation/100.0 - last(3)/100.0
   if (structof(mindata(1)) == FS) {
      write,format="First Surface channel / intensity: %d / %3d\n",
      fs_chn_used, mindata.intensity;
   }
   if (structof(mindata(1)) == GEO) {
      write, format="Bottom elev: %8.2fm Delta: %7.2fm\n",
         (mindata.elevation+mindata.depth)/100.,
         (mindata.elevation+mindata.depth)/100.-_last_rastpulse(4)/100.;
      write, format="First/Bottom return elv DIFF: %8.2fm",mindata.depth/100.;
      write,format="Surface channel-intensity: %d-%3d\n",
      fs_chn_used, mindata.first_peak;
      write,format="Bottom channel / intensity: %d-%3d\n",
      be_chn_used, mindata.bottom_peak;
   }
   if (structof(mindata(1)) == VEG__) {
      write, format="Last return elev: %8.2fm Delta: %7.2fm\n",
         mindata.lelv/100.,
         mindata.lelv/100.-last(4)/100.
      write, format="First/Last return elv DIFF: %8.2fm\n",(mindata.elevation-mindata.lelv)/100.;
      write,format="First Surface channel-intensity: %d-%3d\n",
         fs_chn_used, mindata.fint;
      if ( mindata == VEG )
         write,format="Last Surface channel-intensity: %d-%3d\n",
            be_chn_used, mindata.lint;
   }

   write,"=============================================================\n";
}

func old_refjunk( junk ) {
   if ( (mouse_button == center_mouse)  ) {
      _rastpulse_reference = array(double, 4);
      _rastpulse_reference(1) = mindata.north;
      _rastpulse_reference(2) = mindata.east;
      _rastpulse_reference(3) = mindata.elevation;
      if (structof(mindata(1)) == GEO)
         _rastpulse_reference(4) = (mindata.elevation+mindata.depth)/100.
      if (structof(mindata(1)) == VEG__)
         _rastpulse_reference(4) = mindata.lelv/100.
   }

   if ( is_void(_rastpulse_reference) ) {
      write, " No reference point set"
   } else {
      write,format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n",
      sqrt(double(mindata.north - _rastpulse_reference(1))^2 +
      double(mindata.east  - _rastpulse_reference(2))^2)/100.0,
         (mindata.elevation/100.0 - _rastpulse_reference(3)/100.0) ;
   }
}
