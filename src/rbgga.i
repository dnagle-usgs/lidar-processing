// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func pnav_sel_rgn(win=, color=, mode=, region=, _batch=) {
/* DOCUMENT pnav_sel_rgn(win=, color=, mode=, region=, _batch=)
  The user is prompted to draw out a box or polygon. The points of PNAV within
  that region are found and the corresponding indices are returned.

  Options:
    win= The window where GGA/PNAV is plotted. The user will be prompted to
      click in this window.
        win=6   Default
    color= After dragging out the box or drawing the polygon, the bounding box
      for that region will be drawn in this color.
        color="cyan"  Default
    mode= The selection mode to use.
        mode="box"    The user will be prompted to drag out a box (default)
        mode="pip"    The user will be prompted to draw a polygon
    region= If provided, then these coordinates are used instead of prompting
      the user to draw a box. This can accept two kinds of input:
        - If region is a 4-element vector, it will be interpreted as an array
          [min_x, max_x, min_y, max_y].
        - Otherwise, region must be a 2xN array of vertices for a polygon.
    _batch= If set to 1, no check will be made on the size of the selected
      region. Otherwise, too large a selection will result in an warning.

  Additionally, three externs are used:
    utm: If utm=1, then the input coordinates are considered to be in UTM and
      will be converted to lat/lon prior to use.
    curzone: If utm=1, then curzone must be set to the current zone.
    pnav: The array of PNAV data that the return result will be an index into.
*/
  extern utm, curzone, pnav;
  default, win, 6;
  default, color, "cyan";
  default, mode, "box";
  default, _batch, 0;

  if(is_void(region)) {
    if(mode == "pip") {
      ply = getPoly();
    } else {
      bounds = mouse_bounds();
      ply = bounds([[1,2],[1,4],[3,4],[3,2]]);
    }
  } else {
    if(dimsof(region)(1) == 1 && numberof(region) == 4) {
      ply = region([[1,3],[1,4],[2,4],[2,3]]);
    } else {
      ply = region;
    }
  }

  plg, [ply(2,min),ply(2,max)]([1,1,2,2,1]), [ply(1,min),ply(1,max)]([1,2,2,1,1]),
      color=color;

  if(utm) {
    ply = transpose(utm2ll(ply(2,), ply(1,), curzone));
  }

  q = testPoly(ply, pnav.lon, pnav.lat);
  if(is_void(q)) {
    write, "No GGA records found, aborting";
    return [];
  }

  write, format=" %d GGA records found\n", numberof(q);

  if(!_batch) {
    seconds = ((gga_find_times(q)(dif,sum)))(1);
    write, format=" %5.1f seconds of data selected\n", seconds;
    if(seconds > 500) {
      write, format="%s\n", strindent(strwrap(
        "Warning!!! The area you selected may be too large. For interactive "+
        "processing, 500 seconds or less of flight time is recommended. Try "+
        "selecting a smaller area before pressing the Process button."
        ), " *** ");
    }
  }

  return q;
}

func gga_win_sel(win=, latutm=, llarr=) {
/* DOCUMENT gga_win_sel(win=, latutm=, llarr=)
  The user is prompted to draw out a bounding box. The points of GGA within
  that polygon are found and the corresponding indices are returned.

  DEPRECATED 2012-05-07: Calls to this function should be replaced by
  equivalent calls to pnav_sel_rgn.
*/
  return pnav_sel_rgn(win=win, mode="box", color=color, region=llarr,
    _batch=_batch);
}

func mark_time_pos(sod, win=, msize=, marker=, color=) {
/* DOCUMENT mark_time_pos, sod, win=, msize=, marker=, color=
  Plots a mark for the PNAV location at the given timestamp SOD.

  Parameter:
    sod: The seconds-of-the-day value to plot.
  Options:
    win= Window to plot in, defaults to current.
    msize= Marker size to use, defaults to 0.6.
    marker= Marker to use, defaults to 5 (diamond), see plmk for others.
    color= Color to use, defaults to blue.
  Externs used:
    pnav= The array of navigation data used to look up the x,y location.
    utm= If utm=1, then the lat/lon coordinate from pnav is converted to UTM
      northing/easting.
    curzone= If set and if utm=1, then UTM conversion is forced to this zone.
*/
  extern pnav, utm, curzone;
  default, win, window();
  default, marker, 5;
  default, color, "blue";
  default, msize, 0.6;

  q = where(pnav.sod == sod);
  if(!numberof(q))
    error, "Time not found";
  x = pnav.lon(q(1));
  y = pnav.lat(q(1));
  if(utm)
    ll2utm, noop(y), noop(x), y, x, force_zone=curzone;

  wbkp = current_window();
  window, win;
  plmk, y, x, marker=marker, color=color, msize=msize;
  window_select, wbkp;
}

func gga_click_start_isod {
/* DOCUMENT gga_click_start_isod
  Prompt the user to click a point on the map and then prompt SF to display the
  corresponding picture.
*/
  extern utm, curzone;
  if(utm && !curzone) {
    write, "Abort: curzone is not defined, please set to current UTM zone number";
    return;
  }

  local lon, lat;
  click = mouse(1, 0, "Left-click to select point on flightline");
  if(utm) {
    utm2ll, click(4), click(3), curzone, lon, lat;
  } else {
    lon = click(3);
    lat = click(4);
  }

  near = data_box(gga.lon, gga.lat, lon-.1, lon+.1, lat-.1, lat+.1);
  if(!numberof(near)) {
    write, "Abort: no nearby points found";
    return;
  }

  distsq = (gga(near).lon-lon)^2 + (gga(near).lat-lat)^2;
  nearest = distsq(mnx);

  send_sod_to_sf, long(gga(nearest).sod);
}

func gga_find_times(q) {
/* DOCUMENT gga_find_times(q)
  Input Q should be an index list into gga/pnav for points of interest. The
  function will return the start and stop times for the continuous ranges of
  points found in the index list as a 2xN array of floats where result(1,) is
  the start time and result(2,) is the stop time of the ranges. The times will
  be in seconds-of-the-day format.

  SEE ALSO: gga_win_sel, rbgga, plmk, sod2hms
*/
  if(!numberof(q)) return;
  extern pnav;

  w = where(q(dif) > 2);
  start = grow([0], w) + 1;
  stop = grow(w, numberof(q));

  return pnav.sod(transpose(q([start,stop])));
}

func sel_region(q, max_rps=) {
/* DOCUMENT sel_region(q, max_rps=)
   This function extracts the raster numbers for a region selected. It returns
   a the array rn_arr containing start and stop raster numbers for each
   flightline.

   Options:
    max_rps= Maximum rasters per second. If a segment appears to have more
      rasters per second than this threshold, it will be rejected (with the
      assumption that the corresponding TANS data is corrupted).
        max_rps=40    Default
*/
  default, max_rps, 40;

  if(is_void(q)) {
    write, "No flightline selection provided, aborting!";
    return;
  }

  sods = gga_find_times(q);
  write, format=" Seconds of flightline data selected = %6.2f\n",
      (sods(dif,))(,sum);

  sod_start = sods(1,);
  sod_stop = sods(2,);

  // now loop through the times and find corresponding start and stop raster
  // numbers
  count = numberof(sods(1,));
  write, format=" Number of flightline segments selected = %d\n", count;

  tans_bounds = digitize(sods, tans.somd) - 1;
  tans_start = tans_bounds(1,);
  tans_stop = tans_bounds(2,);
  tans_bounds = [];

  // Detect gaps
  for(i = 1; i <= count; i++) {
    gaps = where(tans.somd(tans_start(i):tans_stop(i))(dif) > 0.5);
    if(numberof(gaps)) {
      // Change to index into tans.somd
      gaps = gaps + tans_start(i) - 1;

      write, format="Segment #%d has gaps in TANS data, splitting into %d segments\n", i, numberof(gaps)+1;
      sod_stop(i) = tans.somd(gaps(1));
      if(numberof(gaps) > 1) {
        grow, sod_start, tans.somd(gaps(:-1)+1);
        grow, sod_start, tans.somd(gaps(2:));
      }
      grow, sod_start, tans.somd(gaps(0)+1);
      grow, sod_stop, tans.somd(bounds(0));
    }
  }

  sod_start = sod_start(sort(sod_start));
  sod_stop = sod_stop(sort(sod_stop));

  count = numberof(sod_start);
  rn_arr = array(int, 2, count);
  for(i = 1; i <= count; i++) {
    rn_start = rn_stop = 0;
    rnsidx = where(edb.seconds >= ceil(sod_start(i)) + soe_day_start);
    if(numberof(rnsidx))
      rn_start = rnsidx(1);
    rnsidx = where(edb.seconds <= floor(sod_stop(i)) + soe_day_start);
    if(numberof(rnsidx) > 1)
      rn_stop = rnsidx(-1);
    if(!rn_start || !rn_stop || (rn_start > rn_stop)) {
      write, format="Corresponding rasters for segment %d not found,"+
        " omitting flightline.\n",i;
      rn_start = 0;
      rn_stop = 0;
    }
    // assume a maximum of 40 rasters per second
    if((rn_stop-rn_start) > (sod_stop(i)-sod_start(i))*max_rps) {
      write, format="Time error in determining number of rasters.  Eliminating flightline segment %d.\n", i;
      rn_start = 0;
      rn_stop = 0;
    }

    rn_arr(,i) = [rn_start, rn_stop];
  }
  write, format=" Number of rasters selected = %d\n", rn_arr(dif,sum);

  return rn_arr;
}

func show_track(fs, x=, y=, color=,  skip=, msize=, marker=, lines=, utm=, width=, win=) {
/* DOCUMENT show_track, fs, x=, y=, color=,  skip=, msize=, marker=, lines=, utm=, width=, win=
  fs can either be an FS or PNAV

  SEE ALSO: show_pnav_track
*/
  a = structof(fs);
  if(structeq(a, FS)) pn = fs2pnav(fs);
  if(structeq(a, PNAV)) pn = fs;

  show_pnav_track, pn, x=x, y=y, color=color,  skip=skip, msize=msize,
    marker=marker, lines=lines, utm=utm, width=width, win=win;
}

func show_pnav_track(pn, x=, y=, color=,  skip=, msize=, marker=, lines=, utm=, width=, win=)  {
/* DOCUMENT func show_pnav_track, pn, x=, y=, color=,  skip=, msize=, marker=, lines=, utm=, width=, win=
*/
  extern curzone;

  default, win, 6;
  default, width, 5.;
  default, msize, 0.1;
  default, marker, 1;
  default, skip, 50;
  default, color, "red";
  default, lines, 1;

  window, win;

  if(is_void(x)) {
    if(is_void(pn)) {
      write, "No pnav/gga data available... aborting.";
      return;
    }
    x = pn.lon;
    y = pn.lat;
  }

  if(utm == 1) {
    // convert latlon to utm
    u = fll2utm(y, x);
    // check to see if data crosses utm zones
    if(numberof(pn) > 1)
      zd = where(abs(u(3,)(dif)) > 0);
    if(is_array(zd)) {
      write, "Selected flightline crosses UTM Zones.";
      if(curzone) {
        write, format="Using currently selected zone number: %d\n",int(curzone);
      } else {
        curzone = 0;
        ans = read(prompt="Enter UTM Zone Number: ", curzone);
      }
      zidx = where(u(3,) == curzone);
      if(is_array(zidx)) {
        x = u(2,zidx);
        y = u(1,zidx);
      } else {
        x = y = [];
      }
    } else {
      x = u(2,);
      y = u(1,);
    }
  }
  // when will this ever be true?  code above sets skip to 50 if is_void - rwm
  if(skip == 0)
    skip = 1;

  if(lines) {
    if(is_array(x) && is_array(y))
      plg, y(1:0:skip), x(1:0:skip), color=color, marks=0, width=width;
  }
  if(marker) {
    if(is_array(x) && is_array(y))
      plmk, y(1:0:skip), x(1:0:skip), color=color, msize=msize, marker=marker,
          width=width;
  }
}

func plot_no_raster_fltlines(pnav, edb) {
/* Document no_raster_flightline (gga, edb)
    This function overplots the flight lines having no rasters with a different color.
*/
  // amar nayegandhi 08/05/02
  extern soe_day_start, utm;

  w = current_window();
  window, 6;

  sod_edb = edb.seconds - soe_day_start;

  // find where the diff in sod_edb is greater than 5 second
  sod_dif = abs(sod_edb(dif));
  indx = where((sod_dif > 5) & (sod_dif < 100000));
  if(is_array(indx)) {
    f_norast = sod_edb(indx);
    l_norast = sod_edb(indx+1);

    for(i = 1; i <= numberof(f_norast); i++) {
      if(l_norast(i) >= f_norast(i)) {
        indx1 = where((pnav.sod >= f_norast(i)) & (pnav.sod <= l_norast(i)));
        if(is_array(indx1))
          show_pnav_track, x=pnav.lon(indx1), y=pnav.lat(indx1), marker=4,
              skip=50, color="yellow", utm=utm;
      }
    }
  }
  // also plot over region before the system is initially started.
  indx1 = where(pnav.sod < sod_edb(1));
  if(is_array(indx1))
    show_pnav_track, x=pnav.lon(indx1), y=pnav.lat(indx1), marker=4,
        skip=50, color="yellow", utm=utm;

  // also plot over region before first good raster
  lindx = where(sod_edb < 0);
  if(is_array(lindx))
    indx1 = where(pnav.sod <= sod_edb(lindx(0)+2));
  if(is_array(indx1))
    show_pnav_track, x=pnav.lon(indx1), y=pnav.lat(indx1), marker=4,
        skip=50, color="yellow", utm=utm;

  window_select, w;
}

func plot_no_tans_fltlines (tans, pnav) {
/* Document no_raster_flightline (pnav, edb)
    This function overplots the flight lines having no rasters with a different color.
*/
  // amar nayegandhi 08/05/02
  extern soe_day_start, utm;

  w = current_window();
  window, 6;
  default, width, 5.;

  // find where the diff in tans is greater than 0.5 second
  tans_dif = tans.somd(dif);
  indx = where((tans_dif > 0.5));
  if(is_array(indx)) {
    f_notans = tans.somd(indx);
    l_notans = tans.somd(indx+1);
    write, format="number of locations with bad tans data = %d\n", numberof(f_notans);

    for(i = 1; i <= numberof(f_notans); i++) {
      indx1 = where(pnav.sod >= f_notans(i));
      if(is_array(indx1)) {
        q = where(pnav.sod(indx1) <= l_notans(i));
        if(is_array(q)) {
          indx1 = indx1(q);
          show_pnav_track, x=pnav.lon(indx1), y=pnav.lat(indx1), marker=5,
              color="magenta", skip=50, msize=0.2, utm=utm, width=width;
        }
      }
    }
  }
  // also plot over region before the tans system is initially started.
  indx1 = where(pnav.sod < tans.somd(1));
  show_pnav_track, x=pnav.lon(indx1), y=pnav.lat(indx1), marker=5,
      color="magenta", skip=1, msize=0.2, utm=utm, width=width;

  window_select, w;
}

func gga_limits(utm=) {
/* DOCUMENT gga_limits(utm=)
   This will set the limits of the current window to constrain it to the
   gga data. Resulting limits will be similar as those attained if you use
   "limits, square=1; limits" when there is only gga data plotted, but
   unlike those commands, this will give those results even if there are
   other data or images plotted to the window. It will even work if the
   gga data isn't plotted at all.
*/
  temp = viewport()(dif)(1:3:2);
  plot_aspect = temp(1)/temp(2);

  latmin = gga.lat(min);
  latmax = gga.lat(max);
  lonmin = gga.lon(min);
  lonmax = gga.lon(max);

  if(utm) {
    u = fll2utm(latmin, lonmin);
    x0 = u(2);
    y0 = u(1);
    u = fll2utm(latmax, lonmax);
    x1 = u(2);
    y1 = u(1);
  } else {
    x0 = lonmin;
    x1 = lonmax;
    y0 = latmin;
    y1 = latmax;
  }

  // Expand ranges by 2% to make sure things fit well on the plot
  xdif = (x1 - x0)/100;
  ydif = (y1 - y0)/100;
  x0 -= xdif;
  x1 += xdif;
  y0 -= ydif;
  y1 += ydif;

  data_aspect = (x1-x0)/(y1-y0);

  limits, square=1;
  if(data_aspect < plot_aspect) {
    // use vertical for limits
    x = [x0,x1](avg) - (y1-y0)*plot_aspect/2;
    limits, x, "e", y0, y1;
  } else {
    // use horizontal for limits
    y = [y0,y1](avg) - (x1-x0)/plot_aspect/2;
    limits, x0, x1, y, "e";
  }
}

func show_mission_pnav_tracks(void, color=, skip=, msize=, marker=, lines=,
utm=, width=, win=) {
/* DOCUMENT show_mission_pnav_tracks, color=, skip=, msize=, marker=, lines=,
   utm=, width=, win=

   Displays the pnav tracks for all mission days (as defined in the loaded
   mission configuration).

   See show_pnav_track for an explanation of options; most are passed as-is to
   it.

   One exception: if color is not specified, each day's trackline will get a
   different color.

   SEE ALSO: mission_conf
*/
// Original David B. Nagle 2009-03-12
  extern pnav;
  default, width, 1;
  default, msize, 0.1;
  default, marker, 0;
  env_bkp = missiondata_wrap("pnav");
  days = missionday_list();
  color_tracker = -4;
  for(i = 1; i <= numberof(days); i++) {
    if(mission_has("pnav file", day=days(i))) {
      color_tracker--;
      cur_color = is_void(color) ? color_tracker : color;
      missiondata_load, "pnav", day=days(i);
      show_pnav_track, pnav, color=cur_color, skip=skip, msize=msize,
        marker=marker, lines=lines, utm=utm, width=width, win=win;
    }
  }
  missiondata_unwrap, env_bkp;
}
