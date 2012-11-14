// vim: set ts=2 sts=2 sw=2 ai sr et:

func split_data(data, how, varname=, timediff=, daythresh=, pulsecount=) {
  segs = save();
  save, segs, string(0), data;

  for(i = 1; i <= numberof(how); i++) {
    if(how(i) == "flight")
      segs = subsplit_by_flight(segs, timediff=timediff, daythresh=daythresh,
        pulsecount=pulsecount);
    else if(how(i) == "line")
      segs = subsplit_by_line(segs, timediff=timediff);
    else if(how(i) == "channel")
      segs = subsplit_by_channel(segs);
    else if(how(i) == "digitizer")
      segs = subsplit_by_digitizer(segs);
    else
      error, "unknown split method: "+how(i);
  }
  if(!is_string(varname)) {
    result = segs;
  } else {
    result = save();
    for(i = 1; i <= segs(*); i++) {
      save, result, segs(*,i)+"_"+varname, segs(noop(i));
    }
  }
  return result;
}

func split_sequence_by_gaps(seq, gap=) {
/* DOCUMENT ptr = split_sequence_by_gaps(seq, gap=)
  Splits a sequence of values into segments, breaking wherever the gap is
  greater than then given gap. (If not provided, gap is twice the RMS of the
  gaps found in the data between consecutive points.)

  Return result is an array of pointers. Each pointer points to an index list
  for a segment.

  The given sequence seq should be monotonically increasing.
*/
  if(numberof(seq) == 1)
    return [&[1]];

  if(is_void(gap))
    gap = seq(dif)(rms)*2;

  // Find indexes where the time exceeds the threshold
  time_idx = where(seq(dif) > gap);
  if(numberof(time_idx)) {
    num_lines = numberof(time_idx) + 1;
    segs_idx = grow(1, time_idx+1, numberof(seq)+1);
  } else {
    num_lines = 1;
    segs_idx = [1, numberof(seq)+1];
  }

  // Create array of pointers to each subsequence
  ptr = array(pointer, num_lines);
  for (i = 1; i <= num_lines; i++) {
    ptr(i) = &indgen(segs_idx(i):segs_idx(i+1)-1);
  }
  return ptr;
}

func split_by_flight(data, timediff=, daythresh=, pulsecount=) {
  default, daythresh, 20;
  default, pulsecount, 119;
  local rn, pulse;

  lines = split_by_line(data, timediff=timediff);

  // bbar: The average y-intercept in linear fit for
  //    raster = intercept + slope * time
  // This thus gives an approximate time for when the rasters for this flight
  // started.
  bbar = array(double, numberof(lines));
  for(i = 1; i <= numberof(lines); i++) {
    data = *lines(i);
    data = data(sort(data.soe));
    parse_rn, data.rn, rn, pulse;
    // rnu: Combines raster and pulse into a unified form that better
    // reflects position in sequence. A pulse is effectively converted into a
    // fractional raster number.
    rnu = rn + (pulse-1.)/pulsecount;
    rn = pulse = [];

    model = regress(unref(data).soe, [1, rnu]);
    bbar(i) = model(1);
  }

  // Downgrade resolution of bbar from fractional seconds to integer minutes
  bbar = long(bbar/60);

  // Sort the bbars (and keep the lines sorted with them)
  idx = sort(bbar);
  bbar = bbar(idx);
  lines = lines(idx);

  // Merge lines that have similar bbars, they are from the same flight.
  merged = array(pointer, numberof(lines));
  merged(1) = &(*lines(1));
  j = 1;
  for(i = 2; i <= numberof(bbar); i++) {
    if(abs(bbar(i) - bbar(i-1)) < daythresh) {
      merged(j) = &grow(*merged(j), *lines(i));
    } else {
      j++;
      merged(j) = &(*lines(i));
    }
  }
  return merged(:j);
}

func split_by_line(data, timediff=) {
  default, timediff, 60;
  data = sortdata(test_and_clean(data), method="soe");
  ptr = split_sequence_by_gaps(data.soe, gap=timediff);
  for(i = 1; i <= numberof(ptr); i++)
    ptr(i) = &data(*ptr(i));
  return ptr;
}

func split_by_channel(data) {
  data = test_and_clean(data);
  if(has_member(data, "channel")) {
    chans = set_remove_duplicates(data.channel);
    num = numberof(chans);
    ptr = array(pointer, num);
    for(i = 1; i <= num; i++) {
      w = where(data.channel == chans(i));
      ptr(i) = &data(w);
    }
    return ptr;
  } else {
    return [&data];
  }
}

func split_by_digitizer(data) {
  data = test_and_clean(data);
  dig = data.rn % 2;
  ptr = [];
  if(anyof(dig))
    grow, ptr, &data(where(dig));
  if(nallof(dig))
    grow, ptr, &data(where(!dig));
  return ptr;
}

func subsplit_fmt(prefix, num, varname) {
  fmt = swrite(format="%s%%0%dd", prefix, int_digits(num));
  if(strlen(varname))
    fmt = varname + "_" + fmt;
  return fmt;
}

func subsplit_by_flight(segs, timediff=, daythresh=, pulsecount=) {
  result = save();
  for(i = 1; i <= segs(*); i++) {
    ptr = split_by_flight(segs(noop(i)), timediff=timediff,
      daythresh=daythresh, pulsecount=pulsecount);
    num = numberof(ptr);
    fmt = subsplit_fmt("flt", num, segs(*,i));
    for(j = 1; j <= num; j++)
      save, result, swrite(format=fmt, j), *ptr(j);
  }
  return result;
}

func subsplit_by_line(segs, timediff=) {
  result = save();
  for(i = 1; i <= segs(*); i++) {
    ptr = split_by_line(segs(noop(i)), timediff=timediff);
    num = numberof(ptr);
    fmt = subsplit_fmt("line", num, segs(*,i));
    for(j = 1; j <= num; j++)
      save, result, swrite(format=fmt, j), *ptr(j);
  }
  return result;
}

func subsplit_by_channel(segs) {
  result = save();
  for(i = 1; i <= segs(*); i++) {
    ptr = split_by_channel(segs(noop(i)));
    num = numberof(ptr);
    fmt = subsplit_fmt("chan", num, segs(*,i));
    for(j = 1; j <= num; j++) {
      data = *ptr(j);
      chan = has_member(*ptr(j), "channel") ? (*ptr(j)).channel(1) : 0;
      save, result, swrite(format=fmt, chan), *ptr(j);
    }
  }
  return result;
}

func subsplit_by_digitizer(segs) {
  result = save();
  for(i = 1; i <= segs(*); i++) {
    ptr = split_by_digitizer(segs(noop(i)));
    num = numberof(ptr);
    fmt = subsplit_fmt("d", num, segs(*,i));
    for(j = 1; j <= num; j++)
      save, result, swrite(format=fmt, j), *ptr(j);
  }
  return result;
}

func rcf_by_fltline(data, mode=, rcfmode=, buf=, w=, n=, timediff=) {
/* DOCUMENT rcf_by_fltline(data, mode=, rcfmode=, buf=, w=, n=, timediff=)
  Applies an RCF filter to eaarl data on a flightline by flightline basis.
  Each flightline is filtered in isolation and the results are merged
  together.

  The mode=, rcfmode=, buf=, w=, and n= options are as documented in
  rcf_filter_eaarl.

  The timediff= option is as documented in split_by_fltline.
*/
  ptrs = split_by_line(unref(data), timediff=timediff);
  for(i = 1; i <= numberof(ptrs); i++)
    ptrs(i) = &rcf_filter_eaarl(*ptrs(i), buf=buf, w=w, n=n, mode=mode,
      rcfmode=rcfmode);
  return merge_pointers(ptrs);
}

func tk_sdw_launch_split(varname, how) {
  segs = split_data(symbol_def(varname), how, varname=varname);
  restore, segs;
  vars = strjoin(segs(*,), " ");
  how = strjoin(how, ", ");
  title = "Segments for "+varname+" by "+how;
  tkcmd, swrite(format="launch_segmenteddatawindow {%s} -title {%s}",
    vars, title);
}

func tk_sdw_send_times(obj, idx, data) {
  mintime = soe2iso8601(data.soe(min));
  maxtime = soe2iso8601(data.soe(max));

  cmd = swrite(format="%s set_time %d {%s} {%s}",
    obj, idx, mintime, maxtime);

  tkcmd, cmd;
}

func tk_swd_define_region_possible(obj) {
  if(is_void(edb) || is_void(pnav)) {
    tkcmd, swrite(format="%s define_region_not_possible", obj);
  } else {
    tkcmd, swrite(format="%s define_region_is_possible", obj);
  }
}

func tk_sdw_define_region_variables(obj, ..) {
  extern _tk_swd_region, pnav, edb, q;
  _tk_swd_region = [];

  avail_min = edb.seconds(min);
  // Add one to max because edb seconds are truncated to integers
  avail_max = edb.seconds(max) + 1;

  multi_flag = 0;

  while(more_args()) {
    data = next_arg();
    ptr = split_by_fltline(data);
    if(numberof(ptr) > 1) {
      multi_flag = 1;
    }
    for(i = 1; i <= numberof(ptr); i++) {
      segment = *ptr(i);
      smin = segment.soe(min);
      smax = segment.soe(max);

      if(smin < avail_min || smax > avail_max) {
        tkcmd, swrite(format="%s define_region_mismatch", obj);
        _tk_swd_region = [];
        return;
      }

      smin = soe2sod(smin);
      smax = soe2sod(smax);
      while(smin < pnav.sod(min)) smin += 86400;
      while(smax < pnav.sod(min)) smax += 86400;

      idx = where(smin <= pnav.sod & pnav.sod <= smax);
      if(numberof(idx)) {
        grow, _tk_swd_region, idx;
      }
    }
  }
  _tk_swd_region = set_remove_duplicates(_tk_swd_region);
  if(multi_flag) {
    tkcmd, swrite(format="%s define_region_multilines", obj);
  } else {
    q = _tk_swd_region;
    tkcmd, swrite(format="%s define_region_successful", obj);
  }
}

func plot_statistically(y, x, title=, xtitle=, ytitle=, nofma=, win=) {
  default, nofma, 0;
  default, win, max([current_window(), 0]);

  w = current_window();
  window, win;

  if(!nofma) {
    fma;
    limits;
  }

  count = numberof(y);
  default, x, indgen(count);
  qs = quartiles(y);
  plg, array(qs(2), count), x, color="blue", width=1;
  plg, array(qs(1), count), x, color="blue", width=1, type="dash";
  plg, array(qs(3), count), x, color="blue", width=1, type="dash";
  ymin = y(min);
  ymax = y(max);
  yavg = y(avg);
  yrms = y(rms);
  plg, array(ymin, count), x, color="blue", width=1;
  plg, array(ymax, count), x, color="blue", width=1;
  plg, array(yavg, count), x, color="red", width=1, width=4;
  plg, array(yavg-yrms, count), x, color="red", width=1, type="dashdot";
  if(yavg-2*yrms > ymin)
    plg, array(yavg-2*yrms, count), x, color="red", width=1, type="dashdotdot";
  if(yavg-3*yrms > ymin)
    plg, array(yavg-3*yrms, count), x, color="red", width=1, type="dot";
  plg, array(yavg+yrms, count), x, color="red", width=1, type="dashdot";
  if(yavg+2*yrms < ymax)
    plg, array(yavg+2*yrms, count), x, color="red", width=1, type="dashdotdot";
  if(yavg+3*yrms < ymax)
    plg, array(yavg+3*yrms, count), x, color="red", width=1, type="dot";
  plg, y, x, color="black", marks=0, width=1;

  if(title)
    pltitle, title;
  if(xtitle)
    xytitles, xtitle;
  if(ytitle)
    xytitles, , ytitle;

  vport = viewport();
  if(vport(1) < 0.1) {
    vx = vport(1) - 0.07;
    vy = vport(3) - 0.07;
  } else {
    vx = vport(1) - 0.07;
    vy = vport(3) - 0.08;
  }
  plt, "red: mean, deviations\nblue: median, quartiles", vx, vy, justify="LA";

  window_select, w;
}

func tk_dsw_plot_stats(var, data, type, win) {
  title = var + " " + type;
  title = regsub("_", title, "!_", all=1);
  x = y = [];
  if(type == "elevation") {
    y = data.elevation/100.;
    x = data.soe;
    ytitle = "Elevation (meters)";
  } else if(type == "bathy") {
    if(structeq(structof(data), GEO)) {
      y = (data.elevation + data.depth)/100.;
      x = data.soe;
    } else if(structeq(structof(data), VEG__)) {
      y = data.lelv/100.;
      x = data.soe;
    }
    ytitle = "Elevation (meters)";
  } else if(type == "roll") {
    working_tans = tk_dsw_get_data(data, "ins", "tans", "somd");
    y = working_tans.roll;
    x = working_tans.somd;
    ytitle = "Roll (degrees)";
  } else if(type == "pitch") {
    working_tans = tk_dsw_get_data(data, "ins", "tans", "somd");
    y = working_tans.pitch;
    x = working_tans.somd;
    ytitle = "Pitch (degrees)";
  } else if(type == "pdop") {
    working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
    y = working_pnav.pdop;
    x = working_pnav.sod;
    ytitle = "Pitch (degrees)";
  } else if(type == "alt") {
    working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
    y = working_pnav.alt;
    x = working_pnav.sod;
    ytitle = "Altitude (meters)";
  } else if(type == "sv") {
    working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
    y = working_pnav.sv;
    x = working_pnav.sod;
    ytitle = "Number of Satellites";
  } else if(type == "xrms") {
    working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
    y = working_pnav.xrms;
    x = working_pnav.sod;
    ytitle = "GPS RMS";
  } else if(type == "velocity") {
    working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
    y = sqrt(working_pnav.veast^2 + working_pnav.vnorth^2 + working_pnav.vup^2);
    x = working_pnav.sod;
    ytitle = "Velocity (m/s)";
  }
  plot_statistically, y, x, title=title, win=win, ytitle=ytitle;
}


func gather_data_stats(data, &working_tans, &working_pnav) {
  stats = h_new();

  // First, pull stats out of the data itself:

  // elevation
  stat_temp = h_new();
  qs = quartiles(data.elevation);
  h_set, stat_temp, "q1", qs(1)/100.;
  h_set, stat_temp, "med", qs(2)/100.;
  h_set, stat_temp, "q3", qs(3)/100.;
  h_set, stat_temp, "min", data.elevation(min)/100.;
  h_set, stat_temp, "max", data.elevation(max)/100.;
  h_set, stat_temp, "avg", data.elevation(avg)/100.;
  h_set, stat_temp, "rms", data.elevation(rms)/100.;
  h_set, stats, "elevation", stat_temp;

  if(structeq(structof(data), GEO)) {
    temp_data = data.elevation + data.depth;
    stat_temp = h_new();
    qs = quartiles(temp_data);
    h_set, stat_temp, "q1", qs(1)/100.;
    h_set, stat_temp, "med", qs(2)/100.;
    h_set, stat_temp, "q3", qs(3)/100.;
    h_set, stat_temp, "min", temp_data(min)/100.;
    h_set, stat_temp, "max", temp_data(max)/100.;
    h_set, stat_temp, "avg", temp_data(avg)/100.;
    h_set, stat_temp, "rms", temp_data(rms)/100.;
    h_set, stats, "bathy", stat_temp;
  }

  if(structeq(structof(data), VEG__)) {
    stat_temp = h_new();
    qs = quartiles(data.lelv);
    h_set, stat_temp, "q1", qs(1)/100.;
    h_set, stat_temp, "med", qs(2)/100.;
    h_set, stat_temp, "q3", qs(3)/100.;
    h_set, stat_temp, "min", data.lelv(min)/100.;
    h_set, stat_temp, "max", data.lelv(max)/100.;
    h_set, stat_temp, "avg", data.lelv(avg)/100.;
    h_set, stat_temp, "rms", data.lelv(rms)/100.;
    h_set, stats, "bathy", stat_temp;
  }

  // Now attempt to extract from tans
  working_tans = tk_dsw_get_data(data, "ins", "tans", "somd");
  if(numberof(working_tans)) {
    // roll
    stat_temp = h_new();
    qs = quartiles(working_tans.roll);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_tans.roll(min);
    h_set, stat_temp, "max", working_tans.roll(max);
    h_set, stat_temp, "avg", working_tans.roll(avg);
    h_set, stat_temp, "rms", working_tans.roll(rms);
    h_set, stats, "roll", stat_temp;

    // pitch
    stat_temp = h_new();
    qs = quartiles(working_tans.pitch);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_tans.pitch(min);
    h_set, stat_temp, "max", working_tans.pitch(max);
    h_set, stat_temp, "avg", working_tans.pitch(avg);
    h_set, stat_temp, "rms", working_tans.pitch(rms);
    h_set, stats, "pitch", stat_temp;

    // heading
    angrng = angular_range(working_tans.heading);
    if(angrng(3) < 90) {
      stat_temp = h_new();
      h_set, stat_temp, "min", angrng(1);
      h_set, stat_temp, "max", angrng(2);
      amin = angrng(1);
      htemp = working_tans.heading;
      htemp *= pi / 180.;
      htemp = atan(sin(htemp),cos(htemp));
      htemp *= 180. / pi;
      htemp -= amin;
      qs = quartiles(htemp) + amin;
      h_set, stat_temp, "q1", qs(1);
      h_set, stat_temp, "med", qs(2);
      h_set, stat_temp, "q3", qs(3);
      h_set, stat_temp, "avg", amin + htemp(avg);
      h_set, stat_temp, "rms", htemp(rms);
      amin = htemp = [];
      h_set, stats, "heading", stat_temp;
    }
  }

  // Now attempt to extract from pnav
  working_pnav = tk_dsw_get_data(data, "pnav", "pnav", "sod");
  if(numberof(working_pnav)) {
    // pdop
    stat_temp = h_new();
    qs = quartiles(working_pnav.pdop);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_pnav.pdop(min);
    h_set, stat_temp, "max", working_pnav.pdop(max);
    h_set, stat_temp, "avg", working_pnav.pdop(avg);
    h_set, stat_temp, "rms", working_pnav.pdop(rms);
    h_set, stats, "pdop", stat_temp;

    // alt
    stat_temp = h_new();
    qs = quartiles(working_pnav.alt);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_pnav.alt(min);
    h_set, stat_temp, "max", working_pnav.alt(max);
    h_set, stat_temp, "avg", working_pnav.alt(avg);
    h_set, stat_temp, "rms", working_pnav.alt(rms);
    h_set, stats, "alt", stat_temp;

    // sv (number of satellites)
    stat_temp = h_new();
    qs = quartiles(working_pnav.sv);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_pnav.sv(min);
    h_set, stat_temp, "max", working_pnav.sv(max);
    h_set, stat_temp, "avg", working_pnav.sv(avg);
    h_set, stat_temp, "rms", working_pnav.sv(rms);
    h_set, stats, "sv", stat_temp;

    // xrms
    stat_temp = h_new();
    qs = quartiles(working_pnav.xrms);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", working_pnav.xrms(min);
    h_set, stat_temp, "max", working_pnav.xrms(max);
    h_set, stat_temp, "avg", working_pnav.xrms(avg);
    h_set, stat_temp, "rms", working_pnav.xrms(rms);
    h_set, stats, "xrms", stat_temp;

    // velocity
    stat_temp = h_new();
    v = sqrt(working_pnav.veast^2 + working_pnav.vnorth^2 + working_pnav.vup^2);
    qs = quartiles(v);
    h_set, stat_temp, "q1", qs(1);
    h_set, stat_temp, "med", qs(2);
    h_set, stat_temp, "q3", qs(3);
    h_set, stat_temp, "min", v(min);
    h_set, stat_temp, "max", v(max);
    h_set, stat_temp, "avg", v(avg);
    h_set, stat_temp, "rms", v(rms);
    h_set, stats, "velocity", stat_temp;
    v = [];
  }

  return stats;
}

func tk_dsw_launch_split_stats(varname, how) {
  segs = split_data(symbol_def(varname), how, varname=varname);
  for(i = 1; i <= segs(*); i++)
    save, segs, noop(i), gather_data_stats(segs(noop(i)));
  json = json_encode(segs);
  tkcmd, swrite(format="launch_datastats_stats {%s}", json);
}

func tk_dsw_launch_stats(vars) {
  vars = strsplit(vars, " ");
  stats = save();
  for(i = 1; i <= numberof(vars); i++) {
    data = symbol_def(vars(i));
    save, stats, vars(i), gather_data_stats(data);
  }
  json = json_encode(stats);
  tkcmd, swrite(format="launch_datastats_stats {%s}", json);
}

func tk_dsw_get_data(data, type, var, sod_field) {
// Extract either tans or pnav data for a set of mission days for a given data
// tk_dsw_get_data(data, "ins", "tans");
// tk_dsw_get_data(data, "pnav", "pnav");
  extern tans, pnav;

  segment_ptrs = split_by_line(unref(data));

  loaded = mission.data.loaded;

  // heading gets handled specially
  working = [];
  working_soe = [];
  days = mission(get,);
  for(i = 1; i <= numberof(segment_ptrs); i++) {
    temp = *segment_ptrs(i);
    mission, load_soe_rn, temp.soe(1), temp.rn(1);
    if(!numberof(symbol_def(var)))
      continue;
    ex_data = symbol_def(var);
    vsod = get_member(ex_data, sod_field);

    dmin = temp.soe(min) - soe_day_start;
    dmax = temp.soe(max) - soe_day_start;

    if(dmax < 0)
      continue;

    vmin = binary_search(vsod, dmin);
    if(vsod(vmin) < dmin)
      vmin++;

    vmax = binary_search(vsod, dmax);
    if(vsod(vmax) > dmax)
      vmax--;

    if(vmin <= vmax) {
      grow, working, ex_data(vmin:vmax);
      grow, working_soe, vsod(vmin:vmax) + soe_day_start;
    }
  }
  mission, load, loaded;

  if(numberof(working)) {
    idx = set_remove_duplicates(int((working_soe-working_soe(min))*200), idx=1);
    working = working(idx);
  }
  return working;
}
