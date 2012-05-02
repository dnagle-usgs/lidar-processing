// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func gga_pip_sel(show, win=, color=, msize=, skip=, latutm=, llarr=, pmulti=) {
/* DOCUMENT gga_pip_sel(show, win=, color=, msize=, skip=, latutm=, llarr=)
This function uses the 'points in polygon' technique to select a region in the gga window.
Also see: getPoly, plpoly, testPoly, gga_win_sel
*/
  extern ZoneNumber, utm, ply, q, curzone;
  if(!(pmulti)) q = [];
  default, win, 6;
  window, win;
  if(!is_array(llarr)) {
    if(utm && !curzone) {
      if(is_void(ZoneNumber)) {
        message = "Points in Polygon requires that you set curzone if utm=1. Aborting.";
        if(!is_void(_ytk))
          tk_messageBox, message, "ok";
        error, message;
      } else {
        curzone = ZoneNumber(1);
      }
    }
    ply = getPoly();
    box = boundBox(ply);
    if(utm) {
      ZN = curzone;
      box = transpose(utm2ll(box(2,), box(1,), ZN));
      ply = transpose(utm2ll(ply(2,), ply(1,), ZN));
      show = 0;
    }
    box_pts = ptsInBox(box, gga.lon, gga.lat);
    poly_pts = testPoly(ply, gga.lon(box_pts), gga.lat(box_pts));
    if(!(pmulti)) {
      q = box_pts(poly_pts);
    } else {
      v = box_pts(poly_pts);
      ino = dimsof(q);
      if((is_array(ino)) && (ino(1) > 1)) {
        w = q;
        q = array(long, ino(2)+1, max(ino(2),numberof(v)));
        q(1:numberof(w(,1)),1:dimsof(w)(0)) = w;
        q(0,1:dimsof(v)(0)) = v;
      } else {
        if(is_array(ino)) {
          q = array(long, 2, max(ino(2),numberof(v)));
          q(1,1:dimsof(w)(0)) = w;
          q(2,1:dimsof(v)(0)) = v;
        } else {
          q = v;
        }
      }
    }
  }
  write, format="%d GGA records found\n", numberof(q);
  if((show != 0) && (show != 2)) {
    default, msize, 0.1;
    default, color, "red";
    default, skip, 10;
    plmk, gga.lat(q(1:0:skip)), gga.lon(q(1:0:skip)), msize=msize, color=color;
  }
  test_selection_size, q;
  return q;
}

func mark_time_pos(win, sod, msize=, marker=, color=) {
/* DOCUMENT mark_time_pos, sod

   Mark a lat/lon position on window, win  based on the sod.  Used from
 sf_a.tcl via eaarl.ytk

*/
  extern utm, UTMNorthing, UTMEasting, ZoneNumber;
  default, marker, 5;
  default, color, "blue";
  default, msize, 0.6;
  current_win = current_window();
  q = where(gga.sod == sod);
  window, win;
  if(utm) {
    fll2utm, gga.lat(q), gga.lon(q), UTMNorthing, UTMEasting, ZoneNumber;
    plmk, UTMNorthing, UTMEasting, marker=marker, color=color, msize=msize;
  } else {
    plmk, gga.lat(q), gga.lon(q), marker=marker, color=color, msize=msize;
  }
  window_select, current_win;
}

func test_selection_size (q) {
  if(!is_array(q)) return;
  sel_secs = ((gga_find_times(q)(dif,sum)))(1);
  write, format="%5.1f seconds of data selected\n", sel_secs;
  if(sel_secs > 500) {
    msg = "** Warning!!!  The area you selected is probably too large."+
        "               We recommend keeping the selected area less then"+
        "               500 seconds of flight time."+
        "Try selecting a smaller area before pressing the Process Now button";
    if(_ytk ) {
      cmd = "tk_messageBox -icon warning -message {" + msg + "}\n";
      tkcmd, cmd;
    } else {
      write, format="\n%s\n", msg;
    }
  }
}

func gga_win_sel(show, win=, color=, msize=, skip= , latutm=, llarr=, _batch=) {
/* DOCUMENT gga_win_sel( show, color=, msize=, skip= )

  There's a bug in yorick 1.5 which causes all the graphics screens to get fouled up
if you set show=1 when using this function.  The screen will reverse fg/bg and not respond
properly to the zoom buttons.

*/
  extern ZoneNumber, utm, ply, curzone;
  default, win, window();
  window, win;
  local minlon, minlat, maxlon, maxlat;
  if(!is_array(llarr)) {
    mouse_bounds, minlon, minlat, maxlon, maxlat;
    [minlon, minlat, maxlon, maxlat];
  } else {
    assign, llarr, minlon, maxlon, minlat, maxlat;
  }
  if(latutm) {
    tkcmd, swrite(format="send_latlon_to_l1pro %7.3f %7.3f %7.3f %7.3f %d\n",
        minlon, maxlon, minlat, maxlat, utm);
  }

  if(show == 2) {
    // plot a window over selected region
    a_x = [minlon, maxlon, maxlon, minlon, minlon];
    a_y = [minlat, minlat, maxlat, maxlat, minlat];
  }

  if(utm == 1) {
    minll = utm2ll(minlat, minlon, curzone);
    maxll = utm2ll(maxlat, maxlon, curzone);
    minlat = minll(2);
    maxlat = maxll(2);
    minlon = minll(1);
    maxlon = maxll(1);
    write, format="minlat = %7.3f, minlon= %7.3f\n", minlat, minlon;
  }

  ply = [[minlat, minlon], [maxlat, maxlon]];
  q = data_box(gga.lon, gga.lat, minlon, maxlon, minlat, maxlat);
  if(is_array(q)) {
    plg, a_y, a_x, color="black";
  }
  write, format="%d GGA records found\n", numberof(q);
  if((show != 0) && (show != 2)) {
    default, msize, 0.1;
    default, color, "red";
    default, skip, 10;
    plmk, gga.lat(q(1:0:skip)), gga.lon(q(1:0:skip)), msize=msize, color=color;
  }

  if(!_batch) test_selection_size, q;
  return q;
}

func gga_point_sel(show, win=, color=, msize=, skip= , latutm=, llarr=, _batch=) {
/* DOCUMENT gga_point_sel( show, color=, msize=, skip= )

  There's a bug in yorick 1.5 which causes all the graphics screens to get fouled up
if you set show=1 when using this function.  The screen will reverse fg/bg and not respond
properly to the zoom buttons.

*/
  extern ZoneNumber, utm, ply, curzone;
  default, win, window();
  if(utm && !curzone) {
    write, "Zone Number not defined.  Please set variable curzone to UTM Zone Number.";
    return;
  }
  window, win;
  local minlon, minlat, maxlon, maxlat;
  if(!is_array(llarr)) {
    mouse_bounds, minlon, minlat, maxlon, maxlat,
        prompt="Hold the left mouse button down, select a point on the flightline map:";
    [minlon, minlat, maxlon, maxlat];
  } else {
    assign, llarr, minlon, maxlon, minlat, maxlat;
  }
  if(latutm) {
    tkcmd, swrite(format="send_latlon_to_l1pro %7.3f %7.3f %7.3f %7.3f %d\n",
        minlon, maxlon, minlat, maxlat, utm);
  }
  if(show == 2) {
    // plot a window over selected region
    a_x=[minlon, maxlon, maxlon, minlon, minlon];
    a_y=[minlat, minlat, maxlat, maxlat, minlat];
    plg, a_y, a_x, color=color;
  }
  if(utm == 1) {
    minll = utm2ll(minlat, minlon, curzone);
    maxll = utm2ll(maxlat, maxlon, curzone);
    minlat = minll(2);
    maxlat = maxll(2);
    minlon = minll(1);
    maxlon = maxll(1);
    write, format="minlat = %7.3f, minlon= %7.3f\n", minlat, minlon;
  }

  ply = [[minlat, minlon], [maxlat, maxlon]];
  q = data_box(gga.lon, gga.lat, minlon-.1, maxlon+.1, minlat-.1, maxlat+.1);
  write, format="%d GGA records found\n", numberof(q);
  // now find the closest gga record to the selected point
  if(numberof(q)) {
    ggaq = gga(q);
    dist = (ggaq.lon-minlon)^2 + (ggaq.lat-minlat)^2;
    didx = dist(mnx);
    q = q(didx);
    if((show != 0) && (show != 2)) {
      default, msize, 0.1;
      default, color, "red";
      default, skip, 10;
      plmk, gga.lat(q(1:0:skip)), gga.lon(q(1:0:skip)), msize=msize, color=color;
    }

    if(!_batch) test_selection_size, q;
  }
  return q;
}


func gga_click_start_isod(x) {
/* DOCUMENT gga_click_start_isod

   Select a region from the gga map. This procedure will then show the picture at the start
of the selected region.  You can then use the "Examine Rasters" button on sf to see the raster
and continue looking at data down the flight line.

*/
  q = gga_point_sel(0);
  if(numberof(q)) {
    st = gga(q).sod;
  } else {
    st = [];
  }
  if(numberof(st)) {
    st = int(st);
    send_sod_to_sf, st;   // command sf and drast there.
  }
  write, "region_selected";
  return st;
}

func gga_find_times(q, win=, plt=) {
/* DOCUMENT gga_find_times(q)

   This function finds the start and stop times from a list generated
   by the gga_win_sel() function. It returns an array of 2xN floats
   where  (1, ) is the starting sod of the segment and (2, ) is the
   ending sod.  Sos is Seconds-of-day.

  SEE ALSO: gga_win_sel, rbgga, plmk, sod2hms
*/

  // begin with "q" list of selected points
  // add a 0 element to the start and end so they will produce
  //   a dif.
  lq = grow([1], q);
  lq = grow(lq, [1]);

  // Now we take the first dif of the sods in the gga records and then get a
  // list of all the places where the dif is larger than one second.  This list
  // "endptlist" will be an index into the list "lq" where had a change larger
  // than one second.  Adding one to "endptlist" gets us the starting point of
  // the next segment.
  endptlist = where(abs((gga.sod(lq)(dif))) > 2);
  if(numberof(endptlist) == 0)
    return;
  startptlist = endptlist+1;

  // start of each line is at qq+1
  // end of each line is at qq
  startggasod = pnav.sod(lq(startptlist));
  stopggasod = pnav.sod(lq(endptlist));

  // The startggasod and stopggasod have bogus values at the beginning and end
  // so we want to fix that and also copy the proper start/stop times to a
  // 2-by-n array to be returned to the caller.
  ssa = array(float, 2, numberof(startggasod) - 1);
  ssa(1,) = startggasod(1:-1);
  ssa(2,) = stopggasod(2:0);

  // to see a plot of the selected times with green/red markers at the
  // beginning and end of each list, enab enable the following:
  default, plt, 0;
  if(plt == 1) {
    default, win, 6;
    window, win;
    fma;
    plmk, pnav.sod(q), q;   // plot the selected times
    plmk, startggasod(1:-1), lq(startptlist(1:-1)), color="green", msize=.3;
    plmk, stopggasod(2:0)-1, lq(startptlist(2:0)-1), color="red", msize=.3;
    limits;
  }
  return ssa;
}

func sel_region (q, all_tans=) {
/* DOCUMENT sel_region(q, all_tans=)
   This function extracts the raster numbers for a region selected.
   It returns a the array rn_arr containing start and stop raster numbers
   for each flightline.
   Set all_tans = 1 if the selected rasters should be processed without tans data.
   amar nayegandhi 9/18/02.
*/

  // find the start and stop times using gga_find_times in rbgga.i
  t = gga_find_times(q);

  if(is_void(t)) {
    write, "No flightline found in selected area. Please start again... \r";
    return;
  }

  write, "\n";
  write, format="Total seconds of flightline data selected = %6.2f\n",
      (t(dif,))(,sum);

  // now loop through the times and find corresponding start and stop raster
  // numbers
  no_t = numberof(t(1,));
  write, format="Number of flightlines selected = %d \n", no_t;
  t_new = [];
  if(!all_tans) {
    for(i = 1; i <= numberof(t(1,)); i++) {
      tyes = 1;
      write, format="Processing %d of %d\r", i, numberof(t(1,));
      tans_idx = where(tans.somd >= t(1,i));
      if(is_array(tans_idx)) {
        tans_q = where(tans.somd(tans_idx) <= t(2,i));
        if(numberof(tans_q) > 1) {
          tans_idx = tans_idx(tans_q);
          ftans = [];
          ftans = tans.somd(tans_idx);
          // now find the gaps in tans data for this flightline
          tg_idx = where(ftans(dif) > 0.5);
          if(is_array(tg_idx)) {
            // this means there are gaps in the tans data for that flightline.
            // break the flightline at these gaps
            write, format="Due to gaps in TANS data, flightline # %d is split into %d segments\n", i, numberof(tg_idx)+1;
            ntsomd = array(float, 2, numberof(tg_idx));
            ntsomd(1,) = ftans(tg_idx);
            ntsomd(2,) = ftans(tg_idx+1);
            grow, t_new, [[ftans(1), ntsomd(1,1)]]; // add first segment to t_new
            for(ti = 1; ti < numberof(tg_idx); ti++) {
              write, "enters for loop";
              grow, t_new, [[ntsomd(2,ti), ntsomd(1,ti+1)]];
            }
            grow, t_new, [[ntsomd(2,0), ftans(0)]]; //add last segment to t_new
          } else grow, t_new, [[ftans(1), ftans(0)]];
        }
      }
      if(!is_array(ftans)) {
        write, format="Corresponding TANS data for flightline %d not found."+
          "Omitting flightline ... \n",i;
      }
    } // end for loop for t
  }

  if(all_tans) t_new = t;

  if(!is_void(t_new)) {
    t_new;
    no_t = numberof(t_new(1,));
    tyes_arr = array(int, no_t);
    tyes_arr(1:0) = 1;
    rn_arr = array(int, 2, no_t);
    for(i = 1; i <= no_t; i++) {
      rnsidx = where(((edb.seconds - soe_day_start)) >= ceil(t_new(1,i)));
      if(is_array(rnsidx) && (numberof(rnsidx) > 1)) {
        idxrn = where(rnsidx(dif) == 1);
        rn_indx_start = rnsidx(idxrn(1));
      } else {
        rn_indx_start = [];
      }
      rnsidx = where(((edb.seconds - soe_day_start)) <= int(t_new(2,i)));
      if(is_array(rnsidx) && (numberof(rnsidx) > 1)) {
        idxrn = where(rnsidx(dif) == 1);
        rn_indx_stop = rnsidx(idxrn(0));
      } else {
        rn_indx_stop = [];
      }
      if((!is_array(rn_indx_start) || !is_array(rn_indx_stop)) || (rn_indx_start > rn_indx_stop)) {
        write, format="Corresponding Rasters for flightline %d not found."+
          "  Omitting flightline ... \n",i;
        rn_start = 0;
        rn_stop = 0;
        tyes_arr(i) = 0;
      } else {
        rn_start = rn_indx_start(1);
        rn_stop = rn_indx_stop(0);
      }
      if(rn_start > rn_stop) {
        write, format="Corresponding Rasters for flightline %d not found."+
          "  Omitting flightline ... \n",i;
        rn_start = 0;
        rn_stop = 0;
        tyes_arr(i) = 0;
      }
      // assume a maximum of 40 rasters per second
      if((rn_stop-rn_start) > (t_new(,i)(dif)(1)*40)) {
        write, format="Time error in determining number of rasters.  Eliminating flightline segment %d.\n", i;
        rn_start = 0;
        rn_stop = 0;
        tyes_arr(i) = 0;
      }

      rn_arr(,i) = [rn_start, rn_stop];
    }
    write, format="\nNumber of Rasters selected = %6d\n", (rn_arr(dif,)) (,sum);
  }

  if(!(is_array(rn_arr))) {
    rn_arr = [];
  }
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
