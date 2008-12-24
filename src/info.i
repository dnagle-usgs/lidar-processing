/*
   $Id$
*/

// this was scarfed from geo_bath.i: raspulsearch()
// if it works, it should replace the code there.
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
      be_chn_used, mindata.last_peak;
   }
   if (structof(mindata(1)) == VEG__) {
      write, format="Last return elev: %8.2fm Delta: %7.2fm\n",
         mindata.lelv/100.,
         mindata.lelv/100.-last(4)/100.
      write, format="First/Last return elv DIFF: %8.2fm\n",(mindata.elevation-mindata.lelv)/100.;
      write,format="First Surface channel-intensity: %d-%3d\n",
         fs_chn_used, mindata.fint;
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
