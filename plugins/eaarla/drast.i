// vim: set ts=2 sts=2 sw=2 ai sr et:

func set_depth_scale(units=, offset=) {
/* DOCUMENT set_depth_scale, units=, offset=
  Updates apply_depth_scale to use new defaults for units= and offset=.

  units= should be one of: "meters", "ns", "feet"

  offset= should be a value in nanoseconds/samples indicating where in the
  waveform the water surface lies (so that it is marked as 0).

  The initial values are units="meters", offset=5.
*/
  extern apply_depth_scale;
  default, units, apply_depth_scale.data.units;
  default, offset, apply_depth_scale.data.offset;
  apply_depth_scale = closure(apply_depth_scale_f, save(units, offset));
}

func show_depth_scale(void) {
/* DOCUMENT show_depth_scale;
  Shows current values used for units and offset by apply_depth_scale.
*/
  write, format="apply_depth_scale values: units=\"%s\", offset=%g\n",
    apply_depth_scale.data.units, double(apply_depth_scale.data.offset);
}

func apply_depth_scale_f(data, scale, units=, autoshift=, offset=) {
/* DOCUMENT new_scale = apply_depth_scale(scale, units=, autoshift=, offset=)
  Applies the current depth scale to the given input scale. Input scale should
  be in nanoseconds. Output scale will be in nanoseconds, meters, or feet
  depending on units=. Used for waveform and raster scales.

  The default values for units= and offset= can be modified using
  set_depth_scale and can be viewed using show_depth_scale.

  You can alternately provide values for units= and offset= to override the
  defaults.

  units= should be one of: "meters", "ns", "feet"

  offset= should be a value in nanoseconds/samples indicating where in the
  waveform the water surface lies (so that it is marked as 0).

  autoshift= specifies whether the scale should be shifted using the offset. If
  units="ns", the scale is never shifted. If units="meters" or units="feet",
  the scale is shifted by default.
*/
  extern _depth_display_units;
  default, units, data.units;
  default, autoshift, 1;
  default, offset, data.offset;
  // If the units are "ns", no action is necessary and is thus omitted here
  if (units == "meters") {
    scale = (scale + (autoshift ? offset : 0)) * CNSH2O2X;
  } else if (units == "feet") {
    scale = (scale + (autoshift ? offset : 0)) * CNSH2O2XF;
  }
  return scale;
}
apply_depth_scale = closure(apply_depth_scale_f, save(units="meters", offset=5));

local wfa;  // decoded waveform array

func ytk_rast(rn) {
/* DOCUMENT ytk_rast, rn
  Wrapper used by YTK to display raster waveform data (via ndrast) for a given
  raster.
*/
  extern wfa, _depth_display_units, _ytk_rast;
  window, 1, wait=0;
  fma;
  wfa = ndrast(rn, units=_depth_display_units);
  if (is_void(_ytk_rast)) {
    limits;
    _ytk_rast = 1;
  }
}

func ndrast(rn, channel=, units=, win=, graph=, sfsync=, cmin=, cmax=, tx=,
autolims=, pulse=) {
/* DOCUMENT drast(rn, channel=, units=, win=, graph=, sfsync=, cmin=, cmax=,
   tx=, autolims=, pulse=)
  Displays raster waveform data for the given raster. Try this:

    > rn = 1000
    > w = ndrast(rn)

  rn should be a raster number. units= should be one of "ns", "meters", or
  "feet" and defaults to "ns". win= defaults to the current window. graph=
  defaults to 1; set graph=0 to disable plotting.

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

  Option pulse= is passed through to show_rast and is just for initializing the
  GUI.
*/
  extern aa, last_somd;
  default, graph, 1;
  default, sfsync, 1;

  r = decode_raster(get_erast(rn=rn));
  aa = array(short(255), 250, 120, 5);

  npix = r.npixels(1);
  somd = (r.soe - soe_day_start)(1);
  if (somd != last_somd && sfsync) {
    send_sod_to_sf, somd;
  }
  for (i=1; i<= npix; i++) {
    for (j=1; j<=4; j++) {
      n = numberof(*r.rx(i,j));  // number of samples
      if (n) aa(1:n,i,j) = *r.rx(i,j);
    }
    n = numberof(*r.tx(i));
    if (n) aa(1:n,i,0) = *r.tx(i);
  }

  if(graph)
    show_rast, rn, channel=channel, units=units, win=win, cmin=cmin, cmax=cmax,
      tx=tx, autolims=autolims, pulse=pulse;

  return &aa;
}

func show_rast(rn, channel=, units=, win=, cmin=, cmax=, geo=, rcfw=, eoffset=,
range_bias=, tx=, autolims=, showcbar=, sfsync=, pulse=, highlight=, bathy=,
bathyoffset=, bathyverbose=, bg=) {
/* DOCUMENT show_rast, rn, channel=, units=, win=, cmin=, cmax=, geo=, rcfw=,
   eoffset=, range_bias=, tx=, autolims=, showbar=, sfsync=, pulse=, bathy=,
   bathyoffset=, bathyverbose=, bg=

  Displays a raster's waveform data as an 2-dimensional image, where the x axis
  is the pulse number and the y axis is depth, time, or elevation (depending on
  units= and geo=). Intensity is represented by color.

  Parameter:
    rn: The raster number to display.
  Options:
    channel= Channel to display.
        channel=1         Default
        channel=0         Display the transmit raster
    units= Units to use for the y axis.
        units="meters"
        units="ns"        Default
        units="feet"
    win= Window to plot in.
        win=20            Default
    cmin= Constrain colobar to the given minimum value.
        cmin=0            Default
    cmax= Constrain colobar to the given maximum value.
        cmax=255          Default
    geo= Georeference for the y axis. If selected, units= is forced to
      "meters".
        geo=0             Default
    rcfw= RCF window to use to determine which waveforms to display. This is
      applies to the elevation of the first sample of the waveforms. This is
      only used when geo=1.
        rcfw=50.          50 meters, default
    eoffset= Elevation offset. This gets added to the y-axis values. This is
      only used when geo=1.
        eoffset=0         0 meteers, default
    range_bias= Set to 1 to adjust the y-axis (depth) to include the range
      biases defined for each channel in ops_conf.
    tx= Show the transmit raster above the return raster. Ignored if channel=0.
        tx=0              Default
    autolims= Automatically reset the limits.
        autolims=1        Default
    showcbar= Automatically plot the colorbar.
        showcbar=0        Default
    sfsync= Sync with SF.
        sfsync=0          Default
    highlight= Highlight the specified pulse(s) by putting a red triangle at
      the top of the raster.
        highlight=[]      Highlight nothing, default
        highlight=30      Highlight pulse 30
    pulse= Initialize the GUI with the specified pulse number.
        pulse=60          Default
    bathy= Enables bathy mode: bottom markers will be overlaid on the raster.
        bathy=0           Default (disabled)
    bathyoffset= Bathy offset. This gets added to the depth values. Value is in
      nanoseconds. Ignored if bathy=0.
        bathyoffset=0     Default
    bathyverbose= Enables a verbose bathy mode. Information about failed
      bottoms will be printed to the console. Ignored if bathy=0.
        bathyverbose=1    Default
    bg= Enables plotting of a solid background covering the extent of the main
      plot.
        bg=0              Default (no background)
*/
  extern data_path, soe_day_start;
  default, channel, 1;
  default, units, "ns";
  default, win, 20;
  default, geo, 0;
  default, rcfw, 50.;
  default, tx, 0;
  default, autolims, 1;
  default, showcbar, 0;
  default, sfsync, 0;
  default, pulse, 60;
  default, bathy, 0;
  default, bathyoffset, 0;
  default, bathyverbose, 1;
  default, bg, 0;

  // Ignore certain settings if channel=0 (=transmit)
  if(channel == 0) {
    tx = 0;
    bathy = 0;
    geo = 0;
    range_bias = 0;
  }

  bias = 0;
  if(range_bias && units != "ns") {
    key = swrite(format="chn%d_range_bias", channel);
    if(ops_conf(*,key))
      bias = ops_conf(noop(key));
  }

  local z;

  win_bkp = current_window();

  // Sanitize raster number
  if(!numberof(edb)) {
    rn = 0;
  } else {
    rn = max(1, min(numberof(edb), rn));
  }

  // Attach Tcl GUI
  cmd = swrite(format=
    "::eaarl::raster::config %d -raster %d -channel %d -units {%s}"
    +" -showcbar %d -bg %d",
    win, long(rn), long(channel), units, long(showcbar), long(bg));
  if(channel > 0)
    cmd += swrite(format=" -tx %d -bathy %d -geo %d -range_bias %d",
      long(tx), long(bathy), long(geo), long(range_bias));
  if(!is_void(cmin))
    cmd += swrite(format=" -cmin %g", double(cmin));
  if(!is_void(cmax))
    cmd += swrite(format=" -cmax %g", double(cmax));
  if(geo)
    cmd += swrite(format=" -rcfw %g -eoffset %g",
      double(rcfw), double(eoffset));
  tkcmd, cmd;

  default, cmin, 0;
  default, cmax, 255;

  window, win;
  // TODO: Is this necessary now?
  // Need to save limits here since window_embed_tk will destroy them
  lims = limits();
  fma;

  if(rn == 0) {
    port = viewport();
    plt, "No rasters available", port(1:2)(avg), port(3:4)(avg),
      tosys=0, justify="CC";
    window_select, win_bkp;
    return;
  }

  skip = array(0, 120);
  if(geo) {
    units = "meters";
    fs = first_surface(start=rn, stop=rn, verbose=0, usecentroid=1)(1);
    data2xyz, fs, , , z, mode="fs";
    if(rcfw) {
      skip(*) = 1;
      rcfres = rcf(z, rcfw, mode=2);
      skip(*rcfres(1)) = 0;
    }
    if(eoffset) z += eoffset;
  }

  top = -1e1000;

  rast = decode_raster(rn=rn);

  if(bg) {
    ymin = 1e1000;
    ymax = -1e1000;
    bgval = 255;
    for(pulse = 1; pulse <= 120; pulse++) {
      if(skip(pulse)) continue;
      wf = channel ? *rast.rx(pulse,channel) : *rast.tx(pulse);
      if(!numberof(wf)) continue;
      wf = short(~wf);
      bgval = min(bgval, wf(min));

      scale = [0, 1-numberof(wf)] - bias;
      scale = apply_depth_scale(scale, units=units, autoshift=!geo);
      if(geo) scale += z(pulse);

      ymin = min(ymin, scale(2));
      ymax = max(ymax, scale(1));
    }
    pli, [[bgval]], 1, ymin, 121, ymax, cmin=cmin, cmax=cmax;
  }

  for(pulse = 1; pulse <= 120; pulse++) {
    if(skip(pulse)) continue;
    wf = channel ? *rast.rx(pulse,channel) : *rast.tx(pulse);
    if(!numberof(wf)) continue;
    wf = short(~wf);
    wf = transpose([wf]);

    scale = [0, 1-numberof(wf)] - bias;
    scale = apply_depth_scale(scale, units=units, autoshift=!geo);
    if(geo) scale += z(pulse);

    pli, wf, pulse, scale(1), pulse+1, scale(2), cmin=cmin, cmax=cmax;
    top = max(top, scale(1));
  }

  if(numberof(highlight)) {
    scale = array(-bias, numberof(highlight));
    scale = apply_depth_scale(scale, units=units, autoshift=!geo);
    if(geo) scale += z(pulse);
    plmk, scale, highlight+.5, color="red", msize=.01, width=10,
      marker=[[0,-.5,.5],[-0.866,0,0]];
  }

  if(bathy) {
    bathy_bias = 0.;
    key = swrite(format="chn%d_range_bias", channel);
    if(ops_conf(*,key))
      bathy_bias = ops_conf(noop(key));
    bgood = bbad = 0;
    for(pulse = 1; pulse <= 120; pulse++) {
      if(skip(pulse)) continue;
      msg = [];
      depth = ba_analyze_pulse(rn, pulse, msg, channel=channel, plot=0);
      if(is_void(depth)) continue;
      if(!depth.candidate_lrx) continue;

      bottom = bathyoffset - bias - depth.candidate_lrx;
      bottom = apply_depth_scale(bottom, units=units, autoshift=!geo);
      if(geo) bottom += z(pulse);
      if(is_void(msg)) {
        bgood++;
        plmk, bottom, pulse+.5, color="green", marker=7, msize=0.25;
      } else {
        bbad++;
        plmk, bottom, pulse+.5, color="white", marker=6, msize=0.25;
      }
    }
    if(bathyverbose) {
      btotal = bgood + bbad;
      bsnr = (btotal > 0) ? 100*bgood/double(btotal) : 0.;
      write, format=" Bathy: %d total; %d accepted; %d rejected; SNR: %.1f%%\n",
        btotal, bgood, bbad, bsnr;
    }
  }

  if(tx) {
    hline = top + apply_depth_scale(2.5, units=units, autoshift=0);
    plhline, hline, 1, 121, type="dash";

    maxlen = 0;
    for(pulse = 1; pulse <= 120; pulse++) {
      if(skip(pulse)) continue;
      wf = *rast.tx(pulse);
      maxlen = max(maxlen, numberof(wf));
    }

    for(pulse = 1; pulse <= 120; pulse++) {
      if(skip(pulse)) continue;
      wf = *rast.tx(pulse);
      if(!numberof(wf)) continue;
      wf = short(~wf);
      wf = transpose([wf]);

      scale = [maxlen, 1] + 4;
      scale = top + apply_depth_scale(scale, units=units, autoshift=0);

      pli, wf, pulse, scale(1), pulse+1, scale(2), cmin=cmin, cmax=cmax;
    }
  }

  somd = (rast.soe - soe_day_start)(1);
  hms = sod2hms(somd, str=1);
  if(channel) {
    if(tx)
      xtitle = swrite(format="rn:%d tx+chn:%d  Pulse #", rn, channel);
    else
      xtitle = swrite(format="rn:%d chn:%d  Pulse #", rn, channel);
  } else {
    xtitle = swrite(format="rn:%d tx  Pulse #", rn);
  }
  xtitle = swrite(format="somd:%d hms:%s %s", somd, hms, xtitle);

  if(geo)
    ytitle = "Ellipsoid elevation (meters, WGS84)";
  else if(units=="ns")
    ytitle = "Nanoseconds";
  else
    ytitle = swrite(format="Water depth (%s)", units);

  xytitles, xtitle, ytitle;
  pltitle, regsub("_", data_path, "!_", all=1);

  if(showcbar) colorbar, cmin, cmax;

  if(autolims) {
    limits;
    lims = limits();
    // Strip off the flags that set the limits to their extreme values
    lims(5) = long(lims(5)) & ~15;
    // Make sure we cover 1 to 121
    lims(1:2) = [1,121];
  }

  // Digitizer 0 sweeps left-to-right, digitizer 1 sweeps right-to-left. This
  // checks to make sure the x-axis is left-to-right or right-to-left.
  if(
    (rast.digitizer(1) && lims(1) < lims(2)) ||
    (!rast.digitizer(1) && lims(2) < lims(1))
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

  if(sfsync || !am_subroutine())
    return ndrast(rn, channel=channel, graph=0, sfsync=sfsync);
}

func drast_msel(rn, type=, winsel=, single=, pulse=, optstr=) {
/* DOCUMENT drast_msel, rn, type=, winsel=, single=, pulse=, optstr=

  Enters an interactive mode that allows the user to query waveforms on an
  ndrast plot.

  Parameter:
    rn: The raster number plotted.
  Options:
    type= Type of plot being queried.
        type="rast"   show_rast or ndrast plot (default)
        type="geo"    geo_rast plot (old style)
    winsel= Window to use for mouse selection (where ndrast is plotted).
        winsel=11     default
    single= Enters single-click mode. After a single pulse is selected, it
      immediately exits interactive mode.
    pulse= Specifies a plot to pulse. The user will not be queried at all.
    optstr= An option string to be passed to ::eaarl::sync::sendyorick
      indicating which plots are wanted and which windows should be used.
        optstr="-rast 1 -rastwin 9"   default

  Extern dependency:
    xm: Set by geo_rast and used to determine which pixel is clicked on.
*/
  default, type, "rast";
  default, winsel, 11;
  default, single, 0;
  default, pulse, 0;

  default, optstr, "-rast 1 -rastwin 9";

  if(!is_string(optstr) ||  !strlen(optstr)) {
    write, " ABORTING: You must provide optstr= as a string";
    return;
  }

  // single = 0  -> multi mode
  // single = 1  -> single mode
  // single = -1 -> replot mode (internal state)

  extern xm;
  extern plotcmd, scratch;

  continue_interactive = 1;
  if(pulse) single = -1;

  if(!pulse)
    write, format="Window: %d. Left-click to examine a waveform. Anything else aborts.\n", winsel;

  while(continue_interactive) {
    if(single)
      continue_interactive = 0;

    if(!pulse) {
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
      } else {
        continue_interactive = 0;
      }
    }

    if(pulse) {
      write, format=" - Pulse %d\n", pulse;
      cmd = swrite(format="::eaarl::sync::sendyorick plotcmd"
        +" -raster %d -pulse %d %s", rn, pulse, optstr);
      scratch = save(scratch, plotcmd);
      plotcmd = [];
      tkcmd, cmd;
      while(is_void(plotcmd)) pause, 1;
      cmdf = include1(z_decompress(base64_decode(plotcmd)));
      restore, scratch;
      cmdf;

      pulse = 0;
    }
  }

  if(single >= 0)
    write, format="%s\n", "Finished examining waveforms.";
}

func show_wf(rn, pix, win=, nofma=, cb=, c1=, c2=, c3=, c4=, tx=, range_bias=,
amp_bias=, units=) {
/* DOCUMENT show_wf, rn, pix, win=, nofma=, cb=, c1=, c2=, c3=, c4=, tx=,
   range_bias=, amp_bias=
  Display a set of waveforms for a given pulse.

  Parameters:
    rn: Raster number.
    pix: Pulse number.

  Options:
    win= Window to use. Defaults to 21.
    nofma= Set to 1 to disable automatic fma.
    cb= Channel bitmask indicating which channels should be displayed. 1 is
      channel 1, 2 is channel 2, 4 is channel 3, 8 is channel 4. Defaults to 0
      (no channels). This is additive to c1=, c2=, c3=, and c4= below.
    c1= Set to 1 to display channel 1.
    c2= Set to 1 to display channel 2.
    c3= Set to 1 to display channel 3.
    c4= Set to 1 to display channel 4.
    tx= Set to 1 to display the transmit above the return waveforms.
    range_bias= Set to 1 to adjust the y-axis (depth) to include the range
      biases defined for each channel in ops_conf.
    amp_bias= Set to 1 to remove the amplitude bias. Also inverts waveform.
*/
  extern _depth_display_units, data_path, ops_conf;

  default, nofma, 0;
  default, cb, 0;
  default, c1, 0;
  default, c2, 0;
  default, c3, 0;
  default, c4, 0;
  default, range_bias, 0;
  default, amp_bias, 0;
  default, units, _depth_display_units;
  default, win, 21;
  default, tx, 0;

  rast = decode_raster(rn=rn);

  // Sync up cb and c1..c4
  if(cb & 1) c1 = 1;
  if(cb & 2) c2 = 1;
  if(cb & 4) c3 = 1;
  if(cb & 8) c4 = 1;
  cb |= (1 * (c1 != 0));
  cb |= (2 * (c2 != 0));
  cb |= (4 * (c3 != 0));
  cb |= (8 * (c4 != 0));

  prev_win = current_window();
  window, win;
  if(!nofma) fma;

  tkcmd, swrite(format=
      "::eaarl::rawwf::config %d -raster %d -pulse %d -chan1 %d -chan2 %d -chan3 %d -chan4 %d -amp_bias %d -range_bias %d -tx %d -units {%s}",
      win, rn, pix, c1, c2, c3, c4, amp_bias, range_bias, tx, units);

  justify = amp_bias ? "RA" : "LA";

  vp = viewport();
  if(amp_bias)
    pltx = vp(2) - .01;
  else
    pltx = vp(1) + .01;
  plty = vp(3) + .01;
  pltw = 0.02;

  multichannel = c1 + c2 + c3 + c4 > 1;
  if(multichannel)
    plt, "Channels:\n ", pltx, plty, justify=justify, height=12, color="black";

  scalemin = 0;

  colors = ["black", "red", "blue", "magenta"];
  chans = amp_bias ? indgen(4:1:-1) : indgen(1:4);
  for(i = 1; i <= 4; i++) {
    chan = chans(i);
    if(!(cb & (2^(chan-1)))) continue;
    wf = *rast.rx(pix,chan);
    if(amp_bias) {
      wf = long(~wf);
      wf -= wf(1);
    }
    scale = double(indgen(0:1-numberof(wf):-1));
    key = swrite(format="chn%d_range_bias", chan);
    if(range_bias && has_member(ops_conf, key))
      scale -= get_member(ops_conf, key);
    scalemin = max(scalemin, scale(1));
    scale = apply_depth_scale(scale, units=units);
    plg, scale, wf, marker=0, color=colors(chan);
    plmk, scale, wf, msize=.2, marker=1, color=colors(chan);
    msg = swrite(format=(multichannel?"%d":"Channel %d"), chan);
    plt, msg, pltx, plty, justify=justify, height=12, color=colors(chan);
    if(amp_bias)
      pltx -= pltw;
    else
      pltx += pltw;
  }

  if(tx) {
    wf = *rast.tx(pix);
    if(amp_bias) {
      wf = long(~wf);
      wf -= wf(1);
    }
    scale = double(indgen(numberof(wf):1:-1)) + 3 + long(ceil(scalemin));
    scale = apply_depth_scale(scale, units=units);
    plg, scale, wf, marker=0, color="cyan";
    plmk, scale, wf, msize=.2, marker=1, color="cyan";
    plt, "tx", pltx, plty, justify=justify, height=12, color="cyan";
  }

  xtitle = swrite(format="Raster:%d  Pls:%d   Digital Counts", rn, pix);
  ytitle = swrite(format="Water depth (%s)", units);
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

  xtitle = swrite(format="Pls:%d   Digital Counts", pix);
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
    win= The window to plot in. Default is 22.
    xfma= By default, an fma is issued (xfma=1). Use xfma=0 to prevent that.
*/
  extern data_path;
  default, win, 22;
  default, xfma, 1;

  raster = [];
  if(is_integer(rast)) {
    raster = rast;
    rast = decode_raster(get_erast(rn=raster));
  }

  tx = *rast.tx(pix);

  wbkp = current_window();
  window, win;

  cmd = swrite(format="::eaarl::transmit::config %d -pulse %d", win, pix);
  if(!is_void(raster)) {
    cmd += swrite(format=" -raster %d", raster);
  }
  tkcmd, cmd;

  if(xfma) fma;

  time = indgen(numberof(tx));
  plg, time, tx, marker=0, color="black";
  plmk, time, tx, msize=.2, marker=1, color="black";

  xtitle = swrite(format="Pls:%d   Digital Counts", pix);
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
  default, win, max(0, current_window());
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
  mission, load_soe, soe;
  if(!is_void(edb)) {
    w = where(abs(edb.seconds - soe) <= 1);
    if(numberof(w)) {
      rnsoes = edb.seconds(w) + edb.fseconds(w)*1.6e-6;
      closest = abs(rnsoes - soe)(mnx);
      rn = w(closest);
      tksetval, "::eaarl::drast::v::rn", rn;
    }
  }
  return found;
}
