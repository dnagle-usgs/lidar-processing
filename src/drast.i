// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func set_depth_scale(new_units) {
/* DOCUMENT set_depth_scale, new_units
  Updates externs _depth_display_units and _depth_scale per new_units.

  new_units should be one of: "meters", "ns", "feet".

  _depth_display_units will be set to new_units.
  _depth_scale will be set to a 250-value span based on the units.
*/
  extern _depth_display_units, _depth_scale;
  _depth_display_units = new_units;
  _depth_scale = apply_depth_scale(span(0, -249, 250));
}

func apply_depth_scale(scale) {
/* DOCUMENT new_scale = apply_depth_scale(scale)
  Applies the current depth scale to the given input scale. Input scale should
  be in nanoseconds. Used for waveform scales.
*/
  extern _depth_display_units;
  // If the units are "ns", no action is necessary and is thus omitted here
  if (_depth_display_units == "meters") {
    scale = (scale + 5) * CNSH2O2X;
  } else if (_depth_display_units == "feet") {
    scale = (scale + 5) * CNSH2O2XF;
  }
  return scale;
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

func ndrast(r, rn=, channel=, units=, win=, graph=, sfsync=, cmin=, cmax=,
autolims=, parent=) {
/* DOCUMENT drast(r, rn=, channel=, units=, win=, graph=, sfsync=, cmin=,
   cmax=, autolims=, parent=)
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

  Returns a pointer to a 250x120x5 array of all the decoded waveforms in this
  raster (channels 1 through 4 and the transmit as #5 [or 0]).

  Be sure to load a database file with load_edb first.

  The channel= option specifies which channel should be plotted (if graph=1)
  and defaults to channel=1. Use channel=0 for transmit.

  Options cmin= and cmax= will contrain the pulse values to the given ranges.
  The waveforms are first normalized to the range 0 to 255. This effect is only
  applied to plotting, not to the returned data.

  By default, the limits are automatically reset (autolims=1), including
  inverting the x-axis if necessary based on the digitizer. Use autolims=0 to
  prevent this behavior.

  By default, this will sync with SF. Set sfsync=0 to disable that behavior.
*/
  extern aa, last_somd, pkt_sf;
  default, graph, 1;
  default, sfsync, 1;

  if(is_void(r) && !is_void(rn))
    r = decode_raster(get_erast(rn=rn));

  aa = array(short(255), 250, 120, 5);

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
    for (j=1; j<=4; j++) {
      n = numberof(*r.rx(i,j));  // number of samples
      if (n) aa(1:n,i,j) = *r.rx(i,j);
    }
    n = numberof(*r.tx(i));
    if (n) aa(1:n,i,0) = *r.tx(i);
  }

  if(graph)
    ndrast_graph, r, aa, somd, channel=channel, units=units, win=win,
      cmin=cmin, cmax=cmax, autolims=autolims, parent=parent;

  return &aa;
}

func ndrast_graph(r, aa, somd, channel=, units=, win=, cmin=, cmax=, autolims=,
parent=) {
/* DOCUMENT ndrast_graph, r, aa, somd, channel=, units=, win=, cmin=, cmax=,
   autolims=, parent=
  Called by ndrast to handle its plotting.
*/
  extern rn, data_path;
  default, units, "ns";
  default, win, max(0, current_window());
  default, channel, 1;
  default, autolims, 1;

  settings = h_new(
    ns=h_new(scale=1, title="Nanoseconds"),
    meters=h_new(scale=CNSH2O2X, title="Water depth (meters)"),
    feet=h_new(scale=CNSH2O2XF, title="Water depth (feet)")
  );
  units = h_has(settings, units) ? units : "ns";

  win_bkp = current_window();

  window, win;
  // Need to save limits here since window_embed_tk will destroy them
  lims = limits();
  fma;
  if(!is_void(parent))
    window_embed_tk, win, parent, 1;

  rast = transpose(aa(,,channel));
  rast = short(~char(rast));

  default, cmin, rast(*)(min);
  rast = max(cmin, rast);
  default, cmax, rast(*)(max);
  rast = min(cmax, rast);

  pli, rast, 1, 4 * settings(units).scale, 121,
    -244 * settings(units).scale;

  xytitles, swrite(format="somd:%d hms:%s rn:%d chn:%d  Pixel #",
    somd, sod2hms(somd, str=1), rn, channel), settings(units).title;
  pltitle, regsub("_", data_path, "!_", all=1);

  if(autolims) {
    limits;
    lims = limits();
  }

  // Digitizer 0 sweeps left-to-right, digitizer 1 sweeps right-to-left. This
  // checks to make sure the x-axis is left-to-right or right-to-left.
  if(
    (r.digitizer(1) && lims(1) < lims(2)) ||
    (!r.digitizer(1) && lims(2) < lims(1))
  ) {
    // The x axis ranged from 1 to 121. Subtracting from 122 flips the axis and
    // makes sure we're still focused on the same region (ie. if we were
    // looking at the upper left, we'd still be looking at the upper left).
    // Previously we simply swapped, but that would result in flipping back and
    // forth on the focus area (ie. upper left and upper right).
    lims([1,2]) = 122 - lims(1:2);
  }
  limits, lims;

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

func drast_msel(rn, type=, rx=, tx=, bath=, cb=, bathchan=, winsel=, winrx=,
wintx=, winbath=) {
/* DOCUMENT drast_msel, rn, type=, rx=, tx=, cb=, bath=, bathchan=, winsel=,
   winrx=, wintx=, winbath=

  Enters an interactive mode that allows the user to query waveforms on an
  ndrast plot.

  Parameter:
    rn: The raster number plotted.
  Options:
    type= Type of plot being queried.
        type="rast"   ndrast plot (default)
        type="geo"    geo_rast plot
    rx= Whether or not to plot the return waveform.
        rx=1          plot return waveform (default)
        rx=0          don't plot return waveform
    tx= Whether or not to plot the transmit waveform.
        tx=1          plot return waveform
        tx=0          don't plot return waveform (default)
    bath= Whether or not to plot the bathy waveform.
        tx=1          plot return waveform
        tx=0          don't plot return waveform (default)
    cb= Channel bitmask, indicating which channels to plot (ignored if rx=0).
      Bit 1 is channel 1, bit 2 is channel 2, bit 3 is channel 3, and bit 4 is
      channel 4.
        cb=7          plot channels 1, 2, 3 (default)
        cb=15         plot channels 1, 2, 3, 4
    bathchan= Channel to use for bathy plot (ignored if bath=0).
        bathchan=0    automatically determine channel as for EAARL-A (default)
        bathchan=1    use channel 1
        bathchan=4    use channel 4
    winsel= Window to use for mouse selection (where ndrast is plotted).
        winsel=11     default
    winrx= Window to use for plotting return waveform(s).
        window=9      default
    wintx= Window to use for plotting transmit waveform.
        window=16     default
    winbath= Window to use for plotting bathy waveform.
        window=4      default

  Extern dependency:
    xm: Set by geo_rast and used to determine which pixel is clicked on.
*/
  default, type, "rast";
  default, cb, 7;
  default, rx, 1;
  default, tx, 0;
  default, bath, 0;
  default, winsel, 11;
  default, winrx, 9;
  default, wintx, 16;
  default, winbath, 4;

  extern xm;

  rast = ndrast(rn=rn, graph=0);

  write, format="Window: %d. Left-click to examine a waveform. Anything else aborts.\n", winsel;

  continue_interactive = 1;

  while(continue_interactive) {
    window, winsel;
    click = mouse(1, 1, "");

    if(mouse_click_is("left", click)) {
      if(type == "rast") {
        pulse = int(click(1));
      } else if(type == "geo") {
        pulse = (abs(click(1)-xm))(mnx);
      } else {
        error, "type="+type+" not implemented";
      }

      write, format=" - Pulse %d\n", pulse;
      if(rx)
        show_wf, *rast, pulse, win=winrx, cb=cb;
      if(bath)
        ex_bath, rn, pulse, graph=1, win=winbath, xfma=1, forcechannel=bathchan;
      if(tx)
        show_wf_transmit, rn, pulse, win=wintx;
    } else {
      continue_interactive = 0;
    }
  }

  write, format="%s\n", "Finished examining waveforms.";
}

func show_wf(r, pix, win=, nofma=, cb=, c1=, c2=, c3=, c4=, raster=, range_bias=) {
/* DOCUMENT show_wf, r, pix, win=, nofma=, cb=, c1=, c2=, c3=, c4=, raster=
  Display a set of waveforms for a given pulse.

  Parameters:
    r - An array of waveform data as returned by drast. Alternately, this may
      be a scalar raster number (which will then be used for raster=).
    pix - The pixel index into r to display.

  Options:
    win= If specified, this window will be used instead of the current window
      for the plot.
    nofma= Set to 1 to disable automatic fma.
    cb= Channel bitmask indicating which channels should be displayed. 1 is
      channel 1, 2 is channel 2, 4 is channel 3, 8 is channel 4. Defaults to 0
      (no channels). This is additive to c1=, c2=, c3=, and c4= below.
    c1= Set to 1 to display channel 1.
    c2= Set to 1 to display channel 2.
    c3= Set to 1 to display channel 3.
    c4= Set to 1 to display channel 4.
    raster= Raster where pulse is located. This is printed if present.
    range_bias= Set to 1 to adjust the y-axis (depth) to include the range
      biases defined for each channel in ops_conf.
*/
  extern _depth_scale, _depth_display_units, data_path, ops_conf;

  default, nofma, 0;
  default, cb, 0;
  default, c1, 0;
  default, c2, 0;
  default, c3, 0;
  default, c4, 0;
  default, range_bias, 0;

  if(is_scalar(r)) {
    raster = r;
    r = *ndrast(decode_raster(get_erast(rn=raster)), graph=0, sfsync=0);
  }

  if(cb & 1) c1 = 1;
  if(cb & 2) c2 = 1;
  if(cb & 4) c3 = 1;
  if(cb & 8) c4 = 1;

  if(!is_void(win)) {
    prev_win = current_window();
    window, win;
  }
  if(!nofma) fma;

  vp = viewport();
  tx = vp(1) + .01;
  ty = vp(3) + .01;
  tw = 0.02;

  multichannel = c1 + c2 + c3 + c4 > 1;
  if(multichannel)
    plt, "Channels:\n ", tx, ty, justify="LA", height=12, color="black";

  if(c1) {
    scale = span(0, -249, 250);
    if(range_bias && has_member(ops_conf, "chn1_range_bias"))
      scale -= ops_conf.chn1_range_bias;
    scale = apply_depth_scale(scale);
    plg, scale, r(,pix,1), marker=0, color="black";
    plmk, scale, r(,pix,1), msize=.2, marker=1, color="black";
    msg = multichannel ? "1" : "Channel 1";
    plt, msg, tx, ty, justify="LA", height=12, color="black";
    tx += tw;
  }
  if(c2) {
    scale = span(0, -249, 250);
    if(range_bias && has_member(ops_conf, "chn2_range_bias"))
      scale -= ops_conf.chn2_range_bias;
    scale = apply_depth_scale(scale);
    plg, scale, r(,pix,2), marker=0, color="red";
    plmk, scale, r(,pix,2), msize=.2, marker=1, color="red";
    msg = multichannel ? "2" : "Channel 2";
    plt, msg, tx, ty, justify="LA", height=12, color="red";
    tx += tw;
  }
  if(c3) {
    scale = span(0, -249, 250);
    if(range_bias && has_member(ops_conf, "chn3_range_bias"))
      scale -= ops_conf.chn3_range_bias;
    scale = apply_depth_scale(scale);
    plg, scale, r(,pix,3),  marker=0, color="blue";
    plmk, scale, r(,pix,3), msize=.2, marker=1, color="blue";
    msg = multichannel ? "3" : "Channel 3";
    plt, msg, tx, ty, justify="LA", height=12, color="blue";
    tx += tw;
  }
  if(c4) {
    scale = span(0, -249, 250);
    if(range_bias && has_member(ops_conf, "chn4_range_bias"))
      scale -= ops_conf.chn4_range_bias;
    scale = apply_depth_scale(scale);
    plg, scale, r(,pix,4),  marker=0, color="magenta";
    plmk, scale, r(,pix,4), msize=.2, marker=1, color="magenta";
    msg = multichannel ? "4" : "Channel 4";
    plt, msg, tx, ty, justify="LA", height=12, color="magenta";
    tx += tw;
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

func geo_rast(rn, channel=, fsmarks=, eoffset=, win=, verbose=, titles=, rcfw=,
style=, bg=) {
/* DOCUMENT geo_rast, rn, channel=, fsmarks=, eoffset=, win=, verbose=,
   titles=, rcfw=, style=, bg=

  Plot a geo-referenced false color waveform image.

  Parameters:
    rn - The raster number to display.
  Options:
    channel= The channel to use.
      channel=1   Default, channel 1.
    fsmarks= If fsmarks=1, will plot first surface range values over the
      waveform.
    eoffset= The mount to offset the vertical scale, in meters. Default is 0.
      - Updates externs fs and xm
    win= The window to plot in. Defaults to 2.
    verbose= Displays progress/info output if verbose=1; goes quiet if
      verbose=0. Default is 1.
    titles= By default, helpful titles are added to the plot. use titles=0 to
      prevent that.
    rcfw= When this option is specified, the RCF filter will be passed over
      the elevations to remove outliers. This option species the window to
      use for that filtering, in meters.
    style= Allows for specifying an alternate plotting style.
        style="pli"    Plot using the pli command (default)
        style="plcm"   Plot using the plcm command (former default)
    bg= The value to use for the background. Default is 9.
*/
  extern xm, fs;
  default, channel, 1;
  default, fsmarks, 0;
  default, eoffset, 0.;
  default, win, 2;
  default, verbose, 1;
  default, titles, 1;
  default, style, "pli";
  default, bg, 9;

  prev_win = current_window();
  window, win;
  fma;

  fs = first_surface(start=rn, stop=rn+1, verbose=verbose)(1);
  sp = fs.elevation/100.0;
  skip = array(short(0), numberof(sp));
  if(rcfw) {
    skip() = 1;
    rcfres = rcf(sp, rcfw, mode=2);
    skip(*rcfres(1)) = 0;
  }
  xm = (fs.east - fs.east(where(!skip))(avg))/100.0;
  xw = abs(xm(where(!skip))(dif))(min) * 0.475;

  rst = decode_raster(get_erast(rn=rn))(1);
  w = where(!rst.rx(,1));
  if(numberof(w))
    skip(w) = 1;

  C = .15;  // in air

  // prepare background
  w = where(!skip);
  xmax = max(abs([xm(w)(max)+xw,xm(w)(min)-xw])) * 1.1;
  xmin = -xmax;
  ymax = sp(w)(max)+eoffset + 10*C;
  ymin = sp(w)(min)+eoffset-255*C - 10*C;
  if(style == "pli") {
    ymax += 0.5 * C;
    ymin -= 0.5 * C;
  }
  // Coerce into square
  if(ymax - ymin > xmax - xmin) {
    xmax = 0.5 * (ymax-ymin);
    xmin = -xmax;
  } else {
    yavg = [ymin,ymax](avg);
    ymax = yavg + xmax;
    ymin = yavg + xmin;
  }
  bg = [[bg]];
  pli, bg, xmin, ymin, xmax, ymax, cmin=0, cmax=255;

  // plot pulses
  for(i = 1; i <= 120; i++) {
    if(skip(i))
      continue;
    wf = *rst.rx(i,channel);
    if(is_void(wf))
      continue;
    z = 254 - wf;
    n = numberof(z);

    if(style == "plcm") {
      x = array(xm(i), n);
      y = span(sp(i)+eoffset, sp(i)-(n-1)*C+eoffset, n);
      plcm, z, y, x, cmin=0, cmax=255, msize=2.0;
    } else {
      x0 = xm(i) - xw;
      x1 = xm(i) + xw;
      y0 = sp(i) + eoffset + 0.5 * C;
      y1 = sp(i) + eoffset - 0.5 * C - (n-1) * C;
      pli, z(-,), x0, y0, x1, y1, cmin=0, cmax=255;
    }
  }

  // fsmarks, if necessary
  if (fsmarks) {
    indx = where(fs(1).elevation <= 0.4*(fs(1).melevation));
    if(numberof(indx))
      plmk, sp(indx)+eoffset, xm(indx), marker=4, msize=.1, color="magenta";
  }

  if(titles) {
    xytitles, "Relative distance across raster (m)", "Height (m)";
    pltitle, swrite(format="Raster %d Channel %d", rn, channel);
  }
  window_select, prev_win;
}

func show_wf_transmit(rast, pix, win=, xfma=) {
/* DOCUMENT show_wf_transmit, rast, pix, win=, xfma=
  Displays a transmit waveform.

  Arguments:
    rast - May be either an integer specifying the raster, or a scalar
      instance of the RAST structure. Integer is prefered, as this enables
      display of raster number in the plot.
    pix - The pixel to plot. This is an index into RAST, in the range 1 to
      120.
  Options:
    win= The window to plot in. Default is the current window.
    xfma= By default, an fma is issued (xfma=1). Use xfma=0 to prevent that.
*/
  extern data_path;
  default, win, window();
  default, xfma, 1;

  raster = [];
  if(is_integer(rast)) {
    raster = rast;
    rast = decode_raster(get_erast(rn=raster));
  }

  tx = *rast.tx(pix);

  wbkp = current_window();
  window, win;

  if(xfma) fma;

  time = indgen(numberof(tx));
  plg, time, tx, marker=0, color="black";
  plmk, time, tx, msize=.2, marker=1, color="black";

  xtitle = swrite(format="Pix:%d   Digital Counts", pix);
  if(!is_void(raster)) xtitle = swrite(format="Raster:%d %s", raster, xtitle);
  ytitle = "Index";
  xytitles, xtitle, ytitle;
  pltitle, regsub("_", data_path, "!_", all=1);

  window_select, wbkp;
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

func drast_set_soe(soe) {
  extern edb;
  found = missiondata_soe_load(soe);
  if(found) {
    w = where(abs(edb.seconds - soe) <= 1);
    if(numberof(w)) {
      rnsoes = edb.seconds(w) + edb.fseconds(w)*1.6e-6;
      closest = abs(rnsoes - soe)(mnx);
      rn = w(closest);
      tksetval, "::l1pro::drast::v::rn", rn;
    }
  }
  return found;
}
