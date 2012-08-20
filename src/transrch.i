// vim: set ts=2 sts=2 sw=2 ai sr et:

/**********************************************************************

  transrch.i
  Original R. Mitchell 2008-11-20

  Contains:
    transrch

*********************************************************************/

require, "eaarl.i";

func transrch( fs, m, llst, _rx=, _el=, spot=, iwin=, disp_type= ) {
/* DOCUMENT  transrch(fs, m)
Searches for the point in the transect plot window iwin (default 3) nearest to where
the user clicks.

The selected point is highlighted red in the transect window and as a
blue circle on the topo (5) window.

Windows showing the raster and pixel waveform are displayed.

Text is displayed in the console window showing details on the point selected.

Input:
  fs          : Variable to process, must be of type FS.
           use   fs=test_and_clean(fs_all) to create
  m           : is the result from a call to mtransect()
  llst        : internal variable created from mtransect()

To use, first generate a transect with these steps:

cln_fs = test_and_clean(fs)
m = mtransect(cln_fs, show=1);

transrch, cln_fs, fs, llst

*/

//            1      2       3        4          5         6       7
  clr = ["black", "red", "blue", "green", "magenta", "yellow", "cyan" ];

  wbkp = current_window();

  extern mindata;
  extern _last_transrch;
  if ( ! is_void( _rx ) ) rx = _rx;
  if ( ! is_void( _el ) ) elevation = _el;
  if ( is_void( _last_transrch ) ) _last_transrch = [0.0, 0.0, 0.0, 0.0];
  if ( is_void(iwin)) iwin = 3;

  window,iwin;  // xyzzy - this assumes the default iwin for transect;
  // m is the result from mtransect();
  xx = rx(llst)     / 100.;     // llst is an extern from transect()
  yy = elevation(m) / 100.;
  if ( is_void(spot) ) spot = mouse();
  write, format="mouse :       : %f %f\n", spot(1), spot(2);

  if ( 1 ) {          // the yorick way - rwm
    ll = limits();

    dx = spot(1)-xx;
    dx = dx / (ll(2) - ll(1));   // need to normalize the x and y values
    dx = dx^2;
    dy = spot(2)-yy;
    dy = dy / (ll(4) - ll(3));   // need to normalize the x and y values
    dy = dy^2;
    dd = dx+dy;
    dd = sqrt(dd);
    minindx = dd(mnx);

  } else {         // copied from raspulsrch(), useful for debugging.
    qy = where( yy     > spot(2) -   2.5 & yy     < spot(2) +   2.5);
    qx = where( xx(qy) > spot(1) - 500.0 & xx(qy) < spot(1) + 500.0);

    indx = qy(qx);    // Does this really differ from qx?
    write, format="searching %d points\n", numberof(indx);


    if ( is_array(indx) ) {

      mindist = 999999;
      for ( i=1; i<numberof(indx); ++i) {
        dist = sqrt( ( (spot(1) - xx(indx(i)))^2)
                + ((spot(2) - yy(indx(i)))^2));
x = [xx(i), xx(i)];
y = [yy(i), yy(i)];
plg, y, x, width=8.0, color="green";
        if ( dist < mindist ) {
          mindist = dist;
          minindx = indx(i);
x = [xx(minindx), xx(minindx)];
y = [yy(minindx), yy(minindx)];
plg, y, x, width=9.0, color="blue";
        }
      }
    }
  } // end of the non-yorick way

  // Now we have the x/y values of the nearest transect point.
  // From here we need to find the original data value
  write, format="Result: %6d: %f %f\n", minindx, xx(minindx), yy(minindx);
  x = [xx(minindx), xx(minindx)];
  y = [yy(minindx), yy(minindx)];
  // plg, y, x, width=10.0, color="red";    // highlight selected point in iwin


  // We want to determine which segment a point is from so that we can
  // redraw it in that color.

  // Made segs extern in transect.i
  // 2008-11-25: wonder why i did that.  must be computed here so we can
  // have multiple transects - rwm
  segs = where(abs(fs.soe(m)(dif)) > 5.0 );
  for (i=1, col=0; i<=numberof(segs); ++i) {     // there must be a better way.
    if (segs(i) < minindx )
     col = i;
  }
  col += 2;   // just is.
  col = col%7;
  write, format="color=%s\n", clr(col);
  plg, y, x, width=10.0, color=clr(col);    // highlight selected point in iwin

  mindata = fs(m(minindx));
  pixelwf_set_point, mindata;
  rasterno = mindata.rn&0xFFFFFF;
  pulseno  = mindata.rn/0xFFFFFF
  hms= sod2hms(soe2sod(mindata.soe));
  write, format="Indx  : %6d HMS: %02d%02d%02d  Raster/Pulse: %d/%d FS UTM: %7.1f, %7.1f\n",
    minindx,
    hms(1), hms(2),hms(3),
    rasterno, pulseno,
    mindata.north/100.0,
    mindata.east /100.0;
  show_track, mindata, utm=1, skip=0, color=clr(col), win=5, msize=.5;
  // show_fstrack,fs(m(minindx)), utm=1, skip=0, color="blue", win=5, msize=.5;
  window, 1, wait=1; fma;
  rr = decode_raster(rn=rasterno);
  write, format="soe: %d  rn: %d  dgtz: %d  np: %d\n",
  rr.soe, rr.rasternbr, rr.digitizer, rr.npixels;

  // Now lets display the waveform
  show_wf, rasterno, pulseno, win=0, cb=7;
  limits;

  mindata_dump_info, edb, mindata, minindx, last=_last_transrch,
    ref=_transrch_reference

  _last_transrch = get_east_north_elv(mindata,disp_type=disp_type);

  window_select, wbkp;
}

func mtransrch( fs, m, llst, _rx=, _el=, spot=, iwin=, disp_type=,ptype=, fset= ) {
/* DOCUMENT  mtransrch( fs, m, llst )
  Call transrch repeatedly until the user clicks the right mouse button.
  Should work similar to Pixel Waveform

To use, first generate a transect with these steps:

cln_fs = test_and_clean(fs_all)
m = mtransect(cln_fs, show=1);

mtransrch, cln_fs, fs, llst

*/

  wbkp = current_window();

  extern _last_transrch;
  extern _transrch_reference;

  if ( is_void(_last_transrch ) ) _last_transrch = [0.0, 0.0, 0.0, 0.0];
  if ( is_void(_last_soe) )        _last_soe = 0;
  if (is_void(iwin))                          iwin = 3;
  if (is_void(disp_type))                disp_type = 0; //default fs topo
  if (is_void(ptype))                        ptype = 0; //default fs topo
  if (is_void(msize))                        msize = 1.0
  if (is_void(fset))                          fset = 0
  if (typeof(data)=="pointer")          data = *data(1);
  if (is_void(buf))                              buf = 1000; // 10 meters

  left_mouse =  1;
  center_mouse =  2;
   right_mouse =  3;
   shift_mouse = 12;

  ctl_left_mouse = 41;

  // the data must be clean coming in, otherwise the
  // index do not match the data.
  fs = test_and_clean(fs);

  rtn_data = [];
  nsaved   = 0;

  do {
    write, format="Window: %d. Left: examine point, Center: set reference, Right: quit\n", iwin
    window, iwin;

    spot = mouse(1,1, "");
    mouse_button = spot(10) + 10 * spot(11);
    if ( mouse_button == right_mouse ) break;

    if ( mouse_button == ctl_left_mouse ) {
      grow, finaldata, mindata;
      write, format="\007Point appended to finaldata.  Total saved = %d\n",
       ++nsaved;
    }

    transrch, fs, m, llst, _rx=_rx, _el=_el, spot=spot, iwin=iwin;

    if ( mouse_button == center_mouse || mouse_button == shift_mouse ) {
      _transrch_reference = get_east_north_elv(mindata, disp_type=disp_type);
    }


    mdata = get_east_north_elv(mindata, disp_type = disp_type);

    if ( is_void( _transrch_reference ) ) {
      write, "No Reference Point Set";
    } else {
      if (disp_type == 0) {
        write, format="   Ref. Dist: %8.2fm  Elev diff: %7.2fm\n",
        sqrt(double(mdata(1,) - _transrch_reference(1))^2 +
            double(mdata(2,)  - _transrch_reference(2))^2)/100.0,
        (mdata(3,)/100.0  - _transrch_reference(3)/100);
      }
      if ((disp_type == 1) (disp_type == 2)) {
        write, format="   Ref. Dist: %8.2fm  Last Elev diff: %7.2fm\n",
        sqrt(double(mdata(1,) - _transrch_reference(1))^2 +
            double(mdata(2,)  - _transrch_reference(2))^2)/100.0,
        (mdata(4,)/100.0  - _transrch_reference(4)/100);
      }
    }

  } while ( mouse_button != right_mouse );

  window_select, wbkp;
}



func get_east_north_elv(mindata, disp_type=) {
 /* DOCUMENT get_east_north_elv(mindata, disp_type=)
   This function returns array containing the easting and northing values based on the type of data being used, i.e.
   for disp_type =
   0: first surface - it returns (east, north, elevation, 0)
   1: last surface - it returns (least, lnorth, elevation, lelv);
   2: bathymetry - it returns (east, north, elevation, elv+depth);

    INPUT:
    mindata - eaarl n-data array (1 element)
    disp_type - type of data to be displayed.
    OUTPUT:
    (4,n) array consisting of east, north, elevation, lelv/depth values based on the display type.
*/


  if (is_void(disp_type)) disp_type = 0; // defaults to first return
  mindata = test_and_clean(mindata);
  n = numberof(mindata);
  mdata = array(double, 4,n);
  if ((disp_type == 0) || (disp_type == 2)) {
    mdata(1,n) = mindata.north;
    mdata(2,n) = mindata.east;
  }
    mdata(3,n) = mindata.elevation;
  if (disp_type == 2) {
    mdata(4,n) = mindata.elevation+mindata.depth;
  }
  if ((disp_type == 1)) {
    mdata(1,n) = mindata.lnorth;
    mdata(2,n) = mindata.least;
    mdata(4,n) = mindata.lelv;
  }

  return mdata
}

func mindata_dump_info(edb, mindata, minindx, last=, ref=) {
/* DOCUMENT mindata_dump_info, edb, mindata, minindx, last=, ref=

  NEEDS DOCUMENTATION
*/
  if(is_void(ref)) last = [0.0, 0.0, 0.0, 0.0];
  if(!is_array(edb)) {
    write, "edb is not set, try again";
    return;
  }

  rasterno  = mindata.rn&0xffffff;
  pulseno   = mindata.rn>>24;
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
    aoi = acos((mindata.melevation - mindata.elevation) / hy) * RAD2DEG;
  else
    aoi = -9999.999;
  write, format="Scanner Elev: %8.2fm   Aoi:%6.3f Slant rng:%6.3f\n",
    mindata.melevation/100.0, aoi, hy/100.0;

  write, format="First Surface elev: %8.2fm Delta: %7.2fm\n",
    mindata.elevation/100.0, mindata.elevation/100.0 - last(3)/100.0;

  if(structeq(structof(mindata(1)), FS)) {
    fs_chn_used = eaarl_intensity_channel(mindata.intensity);

    write, format="First Surface channel / intensity: %d / %3d\n",
      fs_chn_used, mindata.intensity;
  }

  if(structeq(structof(mindata(1)), VEG__)) {
    fs_chn_used = eaarl_intensity_channel(mindata.fint);
    be_chn_used = eaarl_intensity_channel(mindata.lint);

    write, format="Last return elev: %8.2fm Delta: %7.2fm\n",
      mindata.lelv/100., mindata.lelv/100.-last(4)/100.
    write, format="First/Last return elv DIFF: %8.2fm\n",
      (mindata.elevation-mindata.lelv)/100.;
    write, format="First Surface channel-intensity: %d-%3d\n",
      fs_chn_used, mindata.fint;
    write, format="Last Surface channel-intensity: %d-%3d\n",
      be_chn_used, mindata.lint;
  }

  if(structeq(structof(mindata(1)), GEO)) {
    fs_chn_used = eaarl_intensity_channel(mindata.first_peak);
    be_chn_used = eaarl_intensity_channel(mindata.bottom_peak);

    write, format="Bottom elev: %8.2fm Delta: %7.2fm\n",
      (mindata.elevation+mindata.depth)/100.,
      (mindata.elevation+mindata.depth)/100.-last(4)/100.;
    write, format="First/Bottom return elv DIFF: %8.2fm", mindata.depth/100.;
    write, format="Surface channel-intensity: %d-%3d\n", fs_chn_used,
      mindata.first_peak;
    write, format="Bottom channel / intensity: %d-%3d\n", be_chn_used,
      mindata.bottom_peak;
  }

  write, "=============================================================\n";
}

