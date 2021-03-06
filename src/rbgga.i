// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(utm)) utm = 1;

func pnav_sel_rgn(win=, color=, mode=, region=, verbose=, plot=, _batch=) {
/* DOCUMENT pnav_sel_rgn(win=, color=, mode=, region=, verbose=, plot=, _batch=)
  The user is prompted to draw out a box or polygon. The points of PNAV within
  that region are found and the time bounds for those segments are returned.

  Options:
    win= The window where GGA/PNAV is plotted. The user will be prompted to
      click in this window.
        win=4   Default
    color= After dragging out the box or drawing the polygon, the bounding box
      for that region will be drawn in this color.
        color="cyan"  Default
    mode= The selection mode to use.
        mode="box"    The user will be prompted to drag out a box (default)
        mode="pip"    The user will be prompted to draw a polygon
    region= If provided, this defines the processing region and the user will
      not be prompted. This can accept any kind of region accepted by
      region_to_shp; see region_to_shp for details.
    verbose= By default informational output is displayed to the console. Use
      verbose=0 to disable.
    plot= Specify whether to plot the region selected.
        plot=1    Plot the region selected, default
        plot=0    Do not plot
    _batch= If set to 1, no check will be made on the size of the selected
      region. Otherwise, too large a selection will result in an warning.

  Additionally, three externs are used:
    curzone: If the plot is in UTM or if a poly/shapefile with UTM coordinates
      is provided, then curzone must be set to the current zone.
    pnav: The array of PNAV data.
*/
  extern utm, curzone, pnav;
  default, win, 4;
  default, color, "cyan";
  default, mode, "box";
  default, verbose, 1;
  default, plot, 1;
  default, _batch, 0;

  wbkp = current_window();

  if(is_void(region)) {
    window, win;
    if(mode == "pip") {
      region = get_poly();
    } else {
      region = mouse_bounds(ply=1);
    }
    window_select, wbkp;
  }
  shp = region_to_shp(region);

  if(plot) {
    window, win;
    tmp = region_to_shp(shp, utm=utm, ll=!utm);
    plot_shape, tmp, color=color;
    tmp = [];
  }

  shp = region_to_shp(shp, ll=1);
  q = points_in_shp(shp, pnav.lon, pnav.lat);

  if(!numberof(q)) {
    if(verbose) write, "No GGA records found, aborting";
    window_select, wbkp;
    return [];
  }

  if(verbose) write, format=" %d GGA records found\n", numberof(q);

  if(!_batch) {
    seconds = ((gga_find_times(q)(dif,sum)))(1);
    if(verbose) write, format=" %5.1f seconds of data selected\n", seconds;
    if(seconds > 500) {
      if(verbose)
        write, format="%s\n", strindent(strwrap(
          "Warning!!! The area you selected may be too large. For "+
          "interactive processing, 500 seconds or less of flight time is "+
          "recommended. Try selecting a smaller area before pressing the "+
          "Process button."
          ), " *** ");
    }
  }

  window_select, wbkp;
  return gga_find_times(q);
}

func pnav_sel_tile(type, buffer=, win=, color=, verbose=, plot=, _batch=) {
/* DOCUMENT q = pnav_sel_tile(type, buffer=, win=, color=, verbose=, plot=,
   _batch=)

  The user is prompted to click on the map. The tile for that location is
  determined and the points of PNAV within that region are found and the time
  bounds for those segments are returned.

  This is a wrapper around pnav_sel_rgn. See pnav_sel_rgn for documentation on:
  win=, color=, verbose=, plot=, _batch=

  Parameter:
    type: Specifies the kind of tile to use.
        type="dt"   2km tile
        type="it"   10km tile
        type="qq"   Quarter-quad tile.

  Option:
    buffer= Buffer to apply around the tile, in meters. If omitted, no buffer
      is added.
*/
  default, type, "dt";
  default, buffer, 0;
  default, win, 4;
  default, verbose, 1;
  default, plot, 1;

  wbkp = current_window();
  window, win;
  m = mouse();
  window_select, wbkp;

  zone = [];
  if(curzone) zone = curzone;

  x = m(1);
  y = m(2);
  if(x < 360 && y < 360)
    utm2ll, y, x, y, x, zone, force_zone=zone;

  if(!zone) zone = 15;

  tile = utm2tile_names(x, y, zone, type)(1);
  if(verbose) write, format="Tile selected: %s\n", tile;

  region = tile2bbox(tile)([4,2,1,3]);
  if(buffer)
    region += [-buffer,buffer,-buffer,buffer];

  return pnav_sel_rgn(region=region, win=win, color=color, verbose=verbose,
    plot=plot, _batch=_batch);
}

func mark_time_pos(sod, win=, msize=, marker=, color=, label=) {
/* DOCUMENT mark_time_pos, sod, win=, msize=, marker=, color=
  Plots a mark for the PNAV location at the given timestamp SOD.

  Parameter:
    sod: The seconds-of-the-day value to plot.
  Options:
    win= Window to plot in, defaults to current.
    msize= Marker size to use, defaults to 0.6.
    marker= Marker to use, defaults to 5 (diamond), see plmk for others.
    color= Color to use, defaults to blue.
    label= Text string to plot next to the marker.
  Externs used:
    pnav= The array of navigation data used to look up the x,y location.
    utm= If utm=1, then the lat/lon coordinate from pnav is converted to UTM
      northing/easting.
    curzone= If set and if utm=1, then UTM conversion is forced to this zone.
*/
  extern pnav, utm, curzone;
  default, win, 4;
  default, marker, 5;
  default, color, "blue";
  default, msize, 0.6;

  q = abs(pnav.sod - sod)(mnx);
  if(pnav.sod(q) - sod > .5)
    error, "Time not found";
  q = q(1);
  x = pnav.lon(q);
  y = pnav.lat(q);
  if(utm)
    ll2utm, noop(y), noop(x), y, x, force_zone=curzone;

  wbkp = current_window();
  window, win;
  plmk, y, x, marker=marker, color=color, msize=msize;
  if ( label )
    plt, label, x, y, tosys=1, color=color;
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
  nearest = near(distsq(mnx));

  send_sod_to_sf, long(gga(nearest).sod);
}

func gga_find_times(q) {
/* DOCUMENT gga_find_times(q)
  Input Q should be an index list into gga/pnav for points of interest. The
  function will return the start and stop times for the continuous ranges of
  points found in the index list as a 2xN array of floats where result(1,) is
  the start time and result(2,) is the stop time of the ranges. The times will
  be in seconds-of-the-day format.

  SEE ALSO: rbgga, plmk, sod2hms
*/
  if(!numberof(q)) return;
  extern pnav;

  start = [1];
  stop = [numberof(q)];

  if(numberof(q) > 1) {
    w = where(q(dif) > 2);
    if(numberof(w)) {
      start = grow([0], w) + 1;
      stop = grow(w, numberof(q));
    }
  }

  return pnav.sod(transpose(q([start,stop])));
}

func tans_check_times(sods, verbose=) {
/* DOCUMENT sods = tans_check_times(sods, verbose=)
  Given a range of times found against pnav, re-work them to be a range of
  times found against tans.
*/
  default, verbose, 1;

  sod_start = sods(1,);
  w = where(sod_start <= tans.somd(0));
  if(!numberof(w)) return;
  sods = sods(,w);

  sod_start = sods(1,);
  sod_stop = sods(2,);

  keep = array(0, numberof(tans));
  idx = digitize(sods, tans.somd);
  idx_start = idx(1,);
  idx_stop = min(idx(2,)+1, numberof(tans));

  w = where(sod_stop > tans.somd(idx_stop));
  if(numberof(w)) idx_stop(w) = max(1, idx_stop(w)-1);

  count = numberof(sod_start);
  for(i = 1; i <= count; i++)
    keep(idx_start(i):idx_stop(i)) = 1;

  q = where(keep);
  if(!numberof(q)) return;

  start = [1];
  stop = [numberof(q)];
  if(numberof(q) > 1) {
    w = where(q(dif) > 2);
    if(numberof(w)) {
      start = grow([0], w) + 1;
      stop = grow(w, numberof(q));
    }
  }

  return tans.somd(transpose(q([start,stop])));
}

func edb_sods_to_rns(sods, max_rps=, verbose=) {
/* DOCUMENT edb_sods_to_rns(sods, max_rps=, verbose=)
  Given an array of seconds-of-the-day values, this will return the
  corresponding raster numbers.

  Options:
    max_rps= Maximum rasters per second. If a segment appears to have more
      rasters per second than this threshold, it will be rejected (with the
      assumption that the corresponding TANS data is corrupted).
        max_rps=40    Default
    verbose= By default, informational messages are displayed to the console.
      These can be mostly silenced with verbose=0.
*/
  extern soe_day_start, edb;
  default, max_rps, 40;
  default, verbose, 1;

  sod_start = sods(1,);
  sod_stop = sods(2,);

  count = numberof(sod_start);
  rn_arr = array(int, 2, count);
  for(i = 1; i <= count; i++) {
    rn_start = rn_stop = 0;
    rnsidx = where(edb.seconds >= floor(sod_start(i)) + soe_day_start);
    if(numberof(rnsidx))
      rn_start = rnsidx(1);
    rnsidx = where(edb.seconds <= ceil(sod_stop(i)) + soe_day_start);
    if(numberof(rnsidx) > 1)
      rn_stop = rnsidx(-1);
    if(!rn_start || !rn_stop || (rn_start > rn_stop)) {
      if(verbose)
        write, format="Corresponding rasters for segment %d not found,"+
          " omitting flightline.\n",i;
      rn_start = 0;
      rn_stop = 0;
    }
    // assume a maximum of 40 rasters per second
    if(
      sod_start(i) < sod_stop(i) &&
      (rn_stop-rn_start+1) > (ceil(sod_stop(i))-floor(sod_start(i)))*max_rps
    ) {
      if(verbose)
        write, format="Time error in determining number of rasters.  Eliminating flightline segment %d.\n", i;
      rn_start = 0;
      rn_stop = 0;
    }

    rn_arr(,i) = [rn_start, rn_stop];
  }
  w = where(rn_arr(1,));
  return numberof(w) ? rn_arr(,w) : [];
}

func pnav_rgn_to_idx(sods) {
/* DOCUMENT idx = pnav_rgn_to_idx(sods)
  Given an array of sod values, returns the indices into pnav that match them.

  (This converts the newer style "q" to the older style "q".)
*/
  extern pnav;
  if(is_void(sods)) return [];

  match = array(0, dimsof(pnav));
  count = dimsof(sods)(3);
  for(i = 1; i <= count; i++)
    match |= (pnav.sod >= sods(1,i) & pnav.sod <= sods(2,i));

  return where(match);
}

func sel_region(sods, max_rps=, verbose=) {
/* DOCUMENT sel_region(sods, max_rps=, verbose=)
  This function extracts the raster numbers for a region selected. It returns a
  the array rn_arr containing start and stop raster numbers for each
  flightline.

  Options:
    max_rps= Maximum rasters per second. If a segment appears to have more
      rasters per second than this threshold, it will be rejected (with the
      assumption that the corresponding TANS data is corrupted).
        max_rps=40    Default
    verbose= By default, informational messages are displayed to the console.
      These can be mostly silenced with verbose=0.
*/
  default, verbose, 1;
  if(is_void(sods)) {
    if(verbose) write, "No flightline selection provided, aborting!";
    return;
  }

  sods = tans_check_times(sods, verbose=verbose);

  rns = edb_sods_to_rns(sods, max_rps=max_rps, verbose=verbose);

  if(verbose) {
    if(numberof(rns))
      write, format=" Number of rasters selected = %d\n",
          rns(dif,sum)(1)+dimsof(rns)(3);
    else
      write, "No rasters selected";
  }

  return rns;
}

func sel_rgn_lines(q, lines=) {
/* DOCUMENT q = sel_rgn_lines(q, lines=)
  Selects a sub-selection of the current selection by only using the specified
  lines.

  SEE ALSO: print_sel_region plot_sel_region
*/
  if(is_void(lines)) return q;
  return q(,lines);
}

func print_sel_region(q) {
/* DOCUMENT print_sel_region, q
  Prints a summary of the flightlines in the given selection.

  SEE ALSO: sel_rgn_lines plot_sel_region
*/
  local x, y;
  if(is_void(q)) {
    write, "No region selected.";
    return;
  }
  if(!is_matrix(q)) error, "Invalid q";
  count = dimsof(q)(3);
  for(i = 1; i <= count; i++) {
    w = where(pnav.sod >= q(1,i) & pnav.sod <= q(2,i));
    ll2utm, pnav.lat([w(1), w(0)]), pnav.lon([w(1), w(0)]), y, x,
      force_zone=curzone;
    // Attempt to flip alternating flightlines so that the coordinates are
    // easier to compare in sequence.
    if(abs(x(dif))(1) > abs(y(dif))(1)) {
      if(x(1) > x(2)) {
        x = x([2,1]);
        y = y([2,1]);
      }
    } else {
      if(y(1) > y(2)) {
        x = x([2,1]);
        y = y([2,1]);
      }
    }
    write, format="%2d: %.0f - %.0f   %.0f %.0f - %.0f %.0f\n",
      i, pnav(w(1)).sod, pnav(w(0)).sod, x(1), y(1), x(2), y(2);
  }
}

func plot_sel_region(q, pn=, win=, lines=, color=, number=, numbercolor=) {
/* DOCUMENT plot_sel_region, q, pn=, win=, lines=, color=, number=,
   numbercolor=
  Plots the current processing selection.

  If lines= is provided, it's an array of index values that specify which
  flightlines to plot.

  SEE ALSO: print_sel_region plot_sel_region
*/
  extern pnav;
  default, pn, pnav;
  if(is_void(q)) {
    write, "No region selected.";
    return;
  }
  if(!is_matrix(q)) error, "Invalid q";
  default, lines, indgen(dimsof(q)(3));
  default, color, "red";
  label = [];
  default, number, 0;
  if(number) default, numbercolor, "black";
  count = numberof(lines);
  for(i = 1; i <= count; i++) {
    j = lines(i);
    w = where(pn.sod >= q(1,j) & pn.sod <= q(2,j));
    if(!numberof(w)) continue;
    if(number) label = swrite(format="%d", j);
    show_track, pn(w), width=5, color=color, skip=0, marker=0,
      msize=0.1, win=win, label=label, labelcolor=numbercolor;
  }
}

func gui_sel_region(q) {
  // Used by eaarl plugins
  if(is_void(q)) {
    write, "No region selected.";
    return;
  }
  if(!is_matrix(q)) error, "Invalid q";
  tkcmd, swrite(format="::eaarl::processing::edit_region_callback %d", dimsof(q)(3));
}

func show_track(_1, _2, color=, skip=, msize=, marker=, lines=, width=, win=, label=, labelcolor=, zone=, mode=) {
/* DOCUMENT show_track, pn, color=, skip=, msize=, marker=, lines=, width=, win=, label=, labelcolor=, zone=, mode=
*/
  local x, y, uzone;
  extern curzone, utm;
  default, win, 4;
  default, width, 5.;
  default, msize, 0.1;
  default, marker, 1;
  default, skip, 50;
  default, color, "red";
  default, lines, 1;

  if(!is_void(_2)) {
    x = _1;
    y = _2;
  } else if(has_member(_1, "lat")) {
    x = _1.lon;
    y = _1.lat;
  } else if(!is_void(_1)) {
    data2xyz, _1, x, y, mode=mode;
  } else {
    write, "No pnav/gga data available... aborting.";
    exit;
  }
  _1 = _2 = [];

  if(skip > 1) {
    x = x(1::skip);
    y = y(1::skip);
  }

  // Handle utm <=> geo if needed and possible

  if(utm && allof(x < 360) && allof(y < 360)) {
    if(curzone) default, zone, curzone;
    ll2utm, y, x, y, x, uzone, force_zone=zone;
    // Crosses UTM zones
    if(is_void(zone) && anyof(uzone != uzone(1))) {
      write, "crosses UTM zones, please define curzone or use zone=";
      exit;
    }
  }
  if(!utm && allof(x > 360) && allof(y > 360)) {
    default, zone, curzone;
    if(!zone) {
      write, "please define curzone or use zone=";
      exit;
    }
    utm2ll, y, x, zone, x, y;
  }

  wbkp = current_window();
  window, win;

  if(lines)
    plg, y, x, color=color, marks=0, width=width;
  if(marker)
    plmk, y, x, color=color, msize=msize, marker=marker, width=width;
  if(label)
    plt, label, x(1), y(1), tosys=1, color=labelcolor, justify="CH";

  window_select, wbkp;
}

func plot_no_raster_fltlines(pnav, edb) {
/* Document no_raster_flightline (gga, edb)
    This function overplots the flight lines having no rasters with a different color.
*/
  extern soe_day_start;

  w = current_window();
  window, 4;

  sod_edb = edb.seconds - soe_day_start;

  // find where the diff in sod_edb is greater than 5 second
  indx = [];
  if(numberof(sod_edb) > 1) {
    sod_dif = abs(sod_edb(dif));
    indx = where((sod_dif > 5) & (sod_dif < 100000));
    sod_dif = [];
  }
  if(is_array(indx)) {
    f_norast = sod_edb(indx);
    l_norast = sod_edb(indx+1);

    for(i = 1; i <= numberof(f_norast); i++) {
      if(l_norast(i) >= f_norast(i)) {
        indx1 = where((pnav.sod >= f_norast(i)) & (pnav.sod <= l_norast(i)));
        if(is_array(indx1))
          show_track, pnav(indx1), marker=4, skip=50, color="yellow";
      }
    }
  }
  // also plot over region before the system is initially started.
  indx1 = where(pnav.sod < sod_edb(1));
  if(is_array(indx1))
    show_track, pnav(indx1), marker=4, skip=50, color="yellow";

  // also plot over region before first good raster
  lindx = where(sod_edb < 0);
  if(is_array(lindx))
    indx1 = where(pnav.sod <= sod_edb(lindx(0)+2));
  if(is_array(indx1))
    show_track, pnav(indx1), marker=4, skip=50, color="yellow";

  window_select, w;
}

func plot_no_tans_fltlines (tans, pnav) {
/* Document no_raster_flightline (pnav, edb)
    This function overplots the flight lines having no rasters with a different color.
*/
  extern soe_day_start;

  w = current_window();
  window, 4;
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
          show_track, pnav(indx1), marker=5, color="magenta", skip=50,
            msize=0.2, width=width;
        }
      }
    }
  }
  // also plot over region before the tans system is initially started.
  indx1 = where(pnav.sod < tans.somd(1));
  show_track, pnav(indx1), marker=5,
      color="magenta", skip=1, msize=0.2, width=width;

  window_select, w;
}

func gga_limits(void) {
/* DOCUMENT gga_limits
   This will set the limits of the current window to constrain it to the
   gga data. Resulting limits will be similar as those attained if you use
   "limits, square=1; limits" when there is only gga data plotted, but
   unlike those commands, this will give those results even if there are
   other data or images plotted to the window. It will even work if the
   gga data isn't plotted at all.
*/
  extern utm;
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
width=, win=) {
/* DOCUMENT show_mission_pnav_tracks, color=, skip=, msize=, marker=, lines=,
   width=, win=

   Displays the pnav tracks for all mission days (as defined in the loaded
   mission configuration).

   See show_track for an explanation of options; most are passed as-is to
   it.

   One exception: if color is not specified, each day's trackline will get a
   different color.

   SEE ALSO: mission_conf
*/
  default, width, 1;
  default, msize, 0.1;
  default, marker, 0;
  days = mission(get,);
  color_tracker = -4;
  for(i = 1; i <= numberof(days); i++) {
    if(mission(has, days(i), "pnav file")) {
      gps = load_pnav(mission(get, days(i), "pnav file"));
      color_tracker--;
      cur_color = is_void(color) ? color_tracker : color;
      show_track, gps, color=cur_color, skip=skip, msize=msize,
        marker=marker, lines=lines, width=width, win=win;
    }
  }
}
