// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "l1pro.i";

func set_depth_scale(new_units) {
/* DOCUMENT set_depth_scale, new_units
   Updates externs _depth_display_units and _depth_scale per new_units.

   new_units should be one of: "meters", "ns", "feet".

   _depth_display_units will be set to new_units.
   _depth_scale will be set to a 250-value span based on the units.
*/
   extern _depth_display_units, _depth_scale;
   _depth_display_units = new_units;
   if (_depth_display_units == "meters") {
      _depth_scale = span(5*CNSH2O2X, -245 * CNSH2O2X, 250);
   } else if (_depth_display_units == "ns") {
      _depth_scale = span(0, -249, 250);
   } else if (_depth_display_units == "feet") {
      _depth_scale = span(5*CNSH2O2XF, -245 * CNSH2O2XF, 250);
   } else {
      _depth_scale = -1;
   }
}

local wfa;  // decoded waveform array

default, _depth_display_units, "meters";
set_depth_scale, _depth_display_units;

func ytk_rast(rn) {
/* DOCUMENT ytk_rast, rn
   Wrapper used by YTK to display raster waveform data (via ndrast) for a given
   raster.
*/
   extern wfa, _depth_display_units, _ytk_rast;
   r = get_erast(rn=rn);
   rr = decode_raster(r);
   window, 1, wait=0;
   fma;
   wfa = ndrast(rr, units=_depth_display_units);
   if (is_void(_ytk_rast)) {
      limits;
      _ytk_rast = 1;
   }
}

func ndrast(r, rn=, units=, win=, graph=, sfsync=) {
/* DOCUMENT drast(r, rn=, units=, win=, graph=, sfsync=)
   Displays raster waveform data for the given raster. Try this:

      > rn = 1000
      > r = get_erast(rn=rn)
      > rr = decode_raster(r)
      > fma
      > w = ndrast(rr)

   r should be a decoded raster. units= should be one of "ns", "meters", or
   "feet" and defaults to "ns". win= defaults to the current window. graph=
   defaults to 1; set graph=0 to disable plotting.

   Alternately, try this:

      > w = ndrast(rn=1000)

   rn should be a raster number.

   Returns a pointer to a 250x120x4 array of all the decoded waveforms in this
   raster.

   Be sure to load a database file with load_edb first.

   By default, this will sync with SF. Set sfsync=0 to disable that behavior.
*/
   extern aa, last_somd, pkt_sf;
   default, graph, 1;
   default, sfsync, 1;

   if(is_void(r) && !is_void(rn))
      r = decode_raster(get_erast(rn=rn));

   aa = array(short(255), 250, 120, 3);

   npix = r.npixels(1);
   somd = (r.soe - soe_day_start)(1);
   if (somd != last_somd && sfsync) {
      send_sod_to_sf, somd;
      if (!is_void(pkt_sf)) {
         idx = where((int)(pkt_sf.somd) == somd);
         if (is_array(idx)) {
            send_tans_to_sf, somd, tans(idx).pitch, tans(idx).roll, tans(idx).heading;
         }
      }
   }
   for (i=1; i< npix; i++) {
      for (j=1; j<=3; j++) {
         n = numberof(*r.rx(i,j));  // number of samples
         if (n) aa(1:n,i,j) = *r.rx(i,j);
      }
   }

   if(graph) ndrast_graph, r, aa, somd, units=units, win=win;

   return &aa;
}

func ndrast_graph(r, aa, somd, units=, win=) {
/* DOCUMENT ndrast_graph, r, aa, somd, units=, win=
   Called by ndrast to handle its plotting.
*/
   extern rn, data_path;
   default, units, "ns";
   default, win, max(0, current_window());

   settings = h_new(
      ns=h_new(scale=1, title="Nanoseconds"),
      meters=h_new(scale=CNSH2O2X, title="Water depth (meters)"),
      feet=h_new(scale=CNSH2O2XF, title="Water depth (feet)")
   );
   units = h_has(settings, units) ? units : "ns";

   win_bkp = current_window();
   window, win;

   pli, -transpose(aa(,,1)), 1, 4 * settings(units).scale, 121,
      -244 * settings(units).scale;
   xytitles, swrite(format="somd:%d hms:%s rn:%d   Pixel #",
      somd, sod2hms(somd, str=1), rn), settings(units).title;
   pltitle, regsub("_", data_path, "!_", all=1);

   limits;
   lmts = limits()(1:2);
   mx = (r.digitizer(1) ? lmts(min) : lmts(max));
   mn = (r.digitizer(1) ? lmts(max) : lmts(min));
   limits, mn, mx;

   window_select, win_bkp;
}

func drast(r, win=, graph=) {
/* DOCUMENT drast(r, win=)
   Displays raster waveform data for the given raster. Try this:

      > rn = 1000
      > r = get_erast(rn = rn)
      > fma
      > w = drast(r)
      > rn +=1

   Returns a pointer to a 250x120x4 array of all the decoded waveforms in this
   raster.

   win= defaults to 1. graph= defaults to 1.

   Be sure to load a database file with load_edb first.
*/
   extern x, txwf, aa, irange, sa, x0, x1;
   default, graph, 1;

   aa = array(short(255), 250, 120, 3);
   bb = array(255, 250, 120);
   irange = array(int, 120);
   sa = array(int, 120);
   len = i24(r, 1);     // raster length
   type = r(4);         // raster type id (should be 5 )
   seconds = i32(r, 5); // raster seconds of the day
   fseconds = i32(r, 9);   // raster fractional seconds
   rasternbr = i32(r, 13); // raster number
   npixels   = i16(r, 17) & 0x7fff;   // number of pixels
   digitizer = (i16(r,17)>>15) & 0x1; // digitizer

   // Display values
   len;
   type;
   seconds;
   fseconds;
   rasternbr;
   npixels;
   digitizer;

   a = 19; // starting point for waveforms

   // Display sod - 4 hours
   soe2time(seconds)(3) - (4 * 3600);
   for(i=1; i<=npixels-1; i++ ) {
      offset_time = i32(r, a);   a += 4;
      txb = r(a);                a++;
      rxb = r(a:a+3);            a += 4;
      sa(i) = i16(r, a);         a += 2;
      irange(i) = i16(r, a);     a += 2;
      plen = i16(r, a);          a += 2;
      wa = a;                    // waveform index

      txlen = r(wa);             wa++;
      txwf = r(wa:wa+txlen-1);   wa += txlen;
      rxlen = r(wa);             wa += 2;
      rx = array(char, 4, rxlen);

      rx(1,) = r(wa:wa+rxlen-1);  wa += rxlen+2;
      rx(2,) = r(wa:wa+rxlen-1);  wa += rxlen+2;
      rx(3,) = r(wa:wa+rxlen-1);

      aa(1:rxlen, i, 1) = rx(1,);
      aa(1:rxlen, i, 2) = rx(2,);
      aa(1:rxlen, i, 3) = rx(3,);
   }

   if(graph) drast_graph, aa, digitizer, win=win;

   return &aa;
}

func drast_graph(aa, digitizer, win=) {
/* DOCUMENT drast_graph, aa, digitizer, win=
   Called by drast to handle its plotting.
*/
   default, win, 1;
   win_bkp = current_window();

   window, win;
   fma;

   x0 = (digitizer ? 1 : 121);
   x1 = (digitizer ? 121 : 1);

   lmts = limits();
   limits, lmts(2), lmts(1);
   pli, -transpose(aa(,,1)), x0, 255, x1, 0;

   window_select, win_bkp;
}

func msel_wf(w, cb=, geo=, winsel=, winplot=, seltype=) {
/* DOCUMENT msel_wf, w, cb=, geo=
   Use the mouse to select a pixel to display a waveform for.

   w - Should be a pointer to an array of waveform data as returned by drast.

   cb= Channel bitmask indicating which channels should be displayed. 1 is
      channel 1, 2 is channel 2, 4 is channel 3. Defaults to 7 (all channels).
   geo= Specifies whether to plot a normal raster or a georeferenced raster.
      Defaults to 0. If 0, uses show_wf (normal). If 1, uses show_geo_wf
      (georeferenced).
*/
   extern rn, bath_ctl, xm;

   default, cb, 7;
   default, geo, 0;
   default, winplot, 0;

   win = 1;
   if(geo == 1) win = 2; //use georectified raster
   if(!is_void(winsel)) win = winsel;
   default, seltype, (winsel == 2 ? "geo" : "rast");
   window, win;

   prompt = swrite(format="Window: %d. Left click: Examine Waveform. Middle click: Exit",win);
   while(1) {
      b = mouse(1,0,prompt);
      prompt = "";
      if (b(1) == 0) {
         write, "Wrong Window... Try Again.";
         break;
      }
      if (seltype == "rast")
         idx = int(b(1));
      if (seltype == "geo")
         idx = (abs(b(1)-xm))(mnx);

      if(mouse_click_is("middle", b)) break;

      if (geo)
         show_geo_wf, *w, idx, win=winplot, cb=cb;
      else
         show_wf, *w, idx , win=winplot, cb=cb;
      if (is_array(bath_ctl)) {
         if (bath_ctl.laser != 0)
            ex_bath, rn, idx, graph=1, win=4, xfma=1;
      }
      window, win;
      write, format="Pulse %d\n", idx;
   }
   write, "msel_wf completed";
}


func show_wf(r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster=) {
/* DOCUMENT show_wf, r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster=
   Display a set of waveforms for a given pulse.

   Parameters:
      r - An array of waveform data as returned by drast.
      pix - The pixel index into r to display.

   Options:
      win= If specified, this window will be used instead of the current window
         for the plot.
      nofma= Set to 1 to disable automatic fma.
      cb= Channel bitmask indicating which channels should be displayed. 1 is
         channel 1, 2 is channel 2, 4 is channel 3. Defaults to 0 (no
         channels). This is additive to c1=, c2=, and c3= below.
      c1= Set to 1 to display channel 1.
      c2= Set to 1 to display channel 2.
      c3= Set to 1 to display channel 3.
      raster= Raster where pulse is located. This is printed if present.
*/
   extern _depth_scale, _depth_display_units, data_path;

   default, nofma, 0;
   default, cb, 0;
   default, c1, 0;
   default, c2, 0;
   default, c3, 0;

   if(cb & 1) c1 = 1;
   if(cb & 2) c2 = 1;
   if(cb & 4) c3 = 1;

   if(!is_void(win)) {
      prev_win = current_window();
      window, win;
   }
   if(!nofma) fma;

   if(c1) {
      plg, _depth_scale, r(,pix,1), marker=0, color="black";
      plmk, _depth_scale, r(,pix,1), msize=.2, marker=1, color="black";
   }
   if(c2) {
      plg, _depth_scale, r(,pix,2), marker=0, color="red";
      plmk, _depth_scale, r(,pix,2), msize=.2, marker=1, color="red";
   }
   if(c3) {
      plg, _depth_scale, r(,pix,3),  marker=0, color="blue";
      plmk, _depth_scale, r(,pix,3), msize=.2, marker=1, color="blue";
   }

   xtitle = swrite(format="Pix:%d   Digital Counts", pix);
   if(!is_void(raster)) xtitle = swrite(format="Raster:%d %s", raster, xtitle);
   ytitle = swrite(format="Water depth (%s)", _depth_display_units);
   xytitles, xtitle, ytitle;
   pltitle, regsub("_", data_path, "!_", all=1);

   if(!is_void(win)) window_select, prev_win;
}

func show_geo_wf(r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster=) {
/* DOCUMENT show_geo_wf, r, pix, win=, nofma=, cb=, c1=, c2=, c3=, raster=
   Display a set of georeferenced waveforms for a given pulse.

   Parameters:
      r - An array of waveform data as returned by drast.
      pix - The pixel index into r to display.

   Options:
      win= If specified, this window will be used instead of the current window
         for the plot.
      nofma= Set to 1 to disable automatic fma.
      cb= Channel bitmask indicating which channels should be displayed. 1 is
         channel 1, 2 is channel 2, 4 is channel 3. Defaults to 7 (all
         channels). This is additive to c1=, c2=, and c3= below.
      c1= Set to 1 to display channel 1.
      c2= Set to 1 to display channel 2.
      c3= Set to 1 to display channel 3.
      raster= Raster where pulse is located. This is printed if present.
*/
   extern data_path, fs, a;

   default, nofma, 0;
   default, cb, 0;
   default, c1, 0;
   default, c2, 0;
   default, c3, 0;

   if(cb & 1) c1 = 1;
   if(cb & 2) c2 = 1;
   if(cb & 4) c3 = 1;

   if(!is_void(win)) {
      prev_win = current_window();
      window, win;
   }
   if(!nofma) fma;

   elvdiff = fs(1).melevation(pix)-fs(1).elevation(pix);

   elv = fs(1).elevation(pix)/100.;
   elvspan = elv-span(-3,246,250)*0.11;

   if(c1) {
      plg,elvspan,255-r(,pix,1), width=2.8,marker=0, color="black";
      plmk,elvspan,255-r(,pix,1),msize=.15,width=10,marker=1,color="black"
   }
   if(c2) {
      plg,elvspan,255-r(,pix,2), width=2.7,marker=0, color="red";
      plmk,elvspan,255-r(,pix,2),msize=.1,width=10,marker=1,color="red"
   }
   if(c3) {
      plg,elvspan,255-r(,pix,3), marker=0,width=2.5, color="blue";
      plmk,elvspan,255-r(,pix,3),msize=.1,width=10,marker=1,color="blue"
   }

   xtitle = swrite(format="Pix:%d   Digital Counts", pix);
   if(!is_void(raster)) xtitle = swrite(format="Raster:%d %s", raster, xtitle);
   ytitle = "Elevation (m)";
   xytitles, xtitle, ytitle;
   pltitle, regsub("_", data_path, "!_", all=1);

   if(!is_void(win)) window_select, prev_win;
}

func rast_scanline(rn, win=, style=, color=) {
   default, style, "average";
   default, win, window();
   local fs, x, y;
   fs = first_surface(start=rn, stop=rn+1, verbose=0)(1);
   test_and_clean, fs;
   // Kick out points within 1m of the mirror
   fs = fs(where(fs.melevation - fs.elevation > 100));
   if(numberof(fs) < 2) {
      write, "All points invalid.";
      return;
   }
   data2xyz, fs, x, y;
   if(style == "straight") {
      n = numberof(x);
      x = x([1,n]);
      y = y([1,n]);
   } else if(style == "average") {
      xy = avgline(x, y);
      x = grow(x(1), xy(,1), x(0));
      y = grow(y(1), xy(,2), y(0));
   } else if(style == "smooth") {
      xy = smooth_line(x, y, upsample=5);
      x = xy(,1);
      y = xy(,2);
   } else {
      // style == "actual" -- or anything else -- gives actual unmodified line
   }

   wbkp = current_window();
   window, win;
   plg, y, x, marks=0, color=color;
   window_select, wbkp;
}

func geo_rast(rn, fsmarks=, eoffset=, win=, verbose=, titles=) {
/* DOCUMENT get_rast, rn, fsmarks=, eoffset=, win=, verbose=

   Plot a geo-referenced false color waveform image.

   Parameters:
      rn - The raster number to display.
   Options:
      fsmarks= If fsmarks=1, will plot first surface range values over the
         waveform.
      eoffset= The mount to offset the vertical scale, in meters. Default is 0.
      - Updates externs fs and xm
      win= The window to plot in. Defaults to 2.
      verbose= Displays progress/info output if verbose=1; goes quiet if
         verbose=0. Default is 1.
*/
   extern xm, fs;
   default, fsmarks, 0;
   default, eoffset, 0.;
   default, win, 2;
   default, verbose, 1;
   default, titles, 1;

   prev_win = current_window();
   window, win;
   // animate, 2;
   fma;

   fs = first_surface(start=rn, stop=rn+1, north=1, verbose=verbose)(1);
   sp = fs.elevation/100.0;
   xm = (fs.east - fs.meast(1))/100.0;

   // prepare background
   // assuming the range gate will not allow the width to exceed 50 m
   // we use w = 50 in the rcf function below.

   allz = ally = allx = [];
   rst = decode_raster(get_erast(rn=rn))(1);
   for (i = 1; i < 120; i++) {
      zz = array(245, 255);
      z = *rst.rx(i);
      n = numberof(z);
      if (n > 0) {
         zz(1:n) = z;
         C = .15;  // in air
         grow, allx, array(xm(i), 255);
         grow, ally, span(sp(i)+eoffset, sp(i)-255*C+eoffset, 255);
         grow, allz, 254-zz;
      }
   }
   bg = [[char(9)]];
   pli, bg, min(allx), min(ally), max(allx), max(ally);
   plcm, allz, ally, allx, cmin=0, cmax=255, msize=2.0;
   if (fsmarks) {
      indx = where(fs(1).elevation <= 0.4*(fs(1).melevation));
      if(numberof(indx))
         plmk, sp(indx)+eoffset, xm(indx), marker=4, msize=.1, color="magenta";
   }

   if(titles) {
      xytitles, "Relative distance across raster (m)", "Height (m)";
      pltitle, swrite(format="Raster %d", rn);
   }
   window_select, prev_win;
}

func transmit_char(rr, p=, win=, plot=, autofma=) {
/* DOCUMENT transmit_char(rr, p=, win=, plot=, autofma=)

   Determines the peak power and area under the curve for the transmit
   waveform. It also returns the time (in ns) the signal is at its peak (useful
   in determining if the signal is saturated).

   Arguments:
      rr - Scalar instance of RAST
      p - Index into rr.tx to evaluate

   Options:
      win= The window to plot in. Defaults to the current window, or 0 if no
         window is active.
      plot= By default, no plot is made (and win= and autofma= are ignored).
         Set plot=1 to plot the transmit waveform.
      autofma= Set to 1 to issue an automatic fma.

   Original Amar Nayegandhi 01/21/04
*/
   default, p, [];
   default, win, (current_window() >= 0 ? current_window() : 0);
   default, plot, 0;
   default, autofma, 0;

   mxtx = max(*rr.tx(p));
   tx = mxtx - *rr.tx(p);
   mxtx = max(tx);
   stx = sum(tx);

   mxidx = where(tx == mxtx);
   nmx = numberof(mxidx);

   if (plot) {
      prev_win = current_window();
      window, win;
      if (autofma) fma;
      plmk, tx, marker=1, msize=.3, color="black";
      plg, tx;
      window_select, prev_win;
   }

   return [stx, mxtx, nmx];
}

func sfsod_to_rn(sfsod) {
/* DOCUMENT sf_sod_to_rn(sfsod)
   This function finds the rn values for the correspoding sod from sf and
   returns the rn value to the drast GUI via ytk_rast.

   Original Amar Nayegandhi 04/06/04
*/
   extern edb, soe_day_start;
   rnarr = where((edb.seconds - soe_day_start) == sfsod);
   if (!is_array(rnarr)) {
      write, format="No rasters found for sod = %d from sf\n",sfsod;
      return;
   }
   tkcmd, swrite(format="set rn %d\n",rnarr(1));
   ytk_rast, rnarr(1);
}
