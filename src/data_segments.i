// vim: set ts=2 sts=2 sw=2 ai sr et:

func split_data(data, how, varname=, timediff=, daythresh=, pulsecount=) {
/* DOCUMENT segs = split_data(data, how, varname=, timediff=, daythresh=,
   pulsecount=)

  Splits DATA into segments using the methods specified by HOW. Return result
  is an oxy group object.

  Parameters:
    data: An array of ALPS data (in an ALPS structure).
    how: A string or array of strings containing one or more of "flight",
      "line", "channel", "digitizer", and "ptime". This specifies what to use
      as a basis for splitting up the data.
  Options:
    varname= The name of the variable. This will be incorporated into the oxy
      group object's key names.
    timediff= Passed through to subsplit_by_flight and subsplit_by_line.
    daythresh= Passed through to subsplit_by_flight.
    pulsecount= Passed through to subsplit_by_flight.

  The output oxy group object will use key names that reflect the splitting.
  For example, if you use a how of "line" and there are 3 separate flight
  lines, then you will get keys of "line1", "line2", and "line3". If you
  specified vname="fs_all", then you would get keys of "line1_fs_all",
  "line2_fs_all", "line3_fs_all".

  Each value in the oxy group object will be an array of ALPS data, which is a
  portion of the original DATA. Each source point will go into exactly one
  segment array. The data is not guaranteed to be sorted in any partcular order
  and may not match the ordering of the source data.
*/
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
    else if(how(i) == "ptime")
      segs = subsplit_by_ptime(segs);
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

func split_sequence_by_gaps(seq, gap=, bounds=) {
/* DOCUMENT ptr = split_sequence_by_gaps(seq, gap=, bounds=)
  Splits a sequence of values into segments, breaking wherever the gap is
  greater than then given gap. (If not provided, gap is twice the RMS of the
  gaps found in the data between consecutive points.)

  Return result is an array of pointers. Each pointer points to an index list
  for a segment.

  If bounds=1, then an array of start,stop indices is returned instead.

  The given sequence seq should be monotonically increasing.
*/
  if(numberof(seq) == 1)
    return [&[1]];

  if(is_void(gap))
    gap = seq(dif)(rms)*2;

  // Find indexes where the time exceeds the threshold
  time_idx = where(seq(dif) > gap);

  if(bounds) {
    if(numberof(time_idx))
      return transpose([grow(1, time_idx+1), grow(time_idx, numberof(seq))]);
    else
      return [[1, numberof(seq)]];
  }

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

func split_by_flight(data, timediff=, daythresh=, pulsecount=, spr=) {
/* DOCUMENT split_by_flight(data, timediff=, daythresh=, pulsecount=, spr=)
  Attempts to split a data variable up into chunks based on which flight the
  points are from.

  Determining a point's flight is non-trivial as we do not store any values in
  the structs that specifically map a point to its source flight. We also
  cannot just split them up by date because sometimes multiple flights occur in
  one day and sometimes a flight crosses through midnight.

  This function exploits the linear relationship between time and raster number
  in order to group rasters together. Rasters are collected at a steady rate,
  which means that there exists an equation TIME = START_TIME + RATE * RASTER
  that fairly accurately relates the two variables.

  The data is first split by line. Each line is analyzed to derive its linear
  equation for start_time and rate. If there are lines that cannot be properly
  analyzed (for example, due to too few points), then another pass is made to
  see if any of the derived linear equations also works for them. Then the
  per-line segments are merged together based on similarity of their start_time
  values.

  Options:
    timediff= This is passed to split_by_line to handle the initial line
      splitting.
    daythresh= Specifies a threshold to use when comparing the start_time
      values of two segments. If their start_time values are within DAYTHRESH
      minutes of one another, they are merged. In order to account for the
      possibility of the laser turning on and off, this should be at least a
      few minutes.
        daythresh=20    Default, 20 minutes
    pulsecount= The number of pulses in a raster. Since a raster actually
      covers a time period rather than a single point of time, the pulsecount
      is used to estimate the time of the center of each raster.
    spr= Seconds per pulse. This is used to derive an initial estimate of the
      linear equation, which improves the results of the lmfit algorithm.
        spr= 0.05       Default, 0.05 which corresponds to 20 Hz, which is the
          scan rate of EAARL-A and EAARL-B.
*/
  default, daythresh, 20;
  default, pulsecount, 119;
  default, spr, 0.05;
  local rn, pulse;

  // Convert daythresh from minutes to seconds
  daythresh *= 60;

  lines = split_by_ptime(data);

  // Solve linear equations -----------------------------------------------
  // Derive the parameters for the linear equation:
  //    soe = start_time + rate * raster
  start_time = array(double, numberof(lines));
  rate = array(double, numberof(lines));
  for(i = 1; i <= numberof(lines); i++) {
    data = *lines(i);
    // data must be sorted by soe for interpolation
    data = data(sort(data.soe));
    parse_rn, data.rn, rn, pulse;

    // Convert pulse into a fractional value such that the central pulse is at
    // 0.5 and such that all other pulses are spaced between 0 and 1 (but
    // strictly 0 < val < 1). These will be combined with the raster number to
    // give a floating point value that we can interpolate against; avoiding 0
    // and 1 allows us to distinguish between rasters (so that pulses first and
    // last don't get merged).

    // Instead of mapping 1..pulsecount to 0..1, map 0..pulsecount+1 to 0..1
    // which ensures that 1 and pulsecount are not at 0 and 1
    pf = double(pulse)/(pulsecount+1);

    // In order to properly interpolate for the middle, we only want to use
    // rasters where there's points both below and above the middle. (In other
    // words, we want to avoid interpolating using adjacent rasters.)

    w = where(pf <= .5);
    rnlo = rn(w);
    w = where(pf >= .5);
    rnhi = rn(w);
    rnlist = set_intersection(rnlo, rnhi);
    w = rnlo = rnhi = [];

    // lmfit doesn't like it when there are 2 or fewer data points to work
    // with; leave the values at 0 and attempt to deal with further below
    if(numberof(rnlist) < 3) continue;

    // Interpolate soe to center of each raster
    rnsoe = interp(data.soe, rn + pf, rnlist + 0.5);

    // Make an initial estimate for the model using spr
    model = [data.soe(1) - data.raster(1) * spr, spr];

    // Solve linear equation
    lmfit, poly1, rnlist, model, rnsoe, tol=0.001;
    start_time(i) = model(1);
    rate(i) = model(2);
  }

  // Check unsolvable segments --------------------------------------------
  // If there were any segments where we couldn't derive an equation, then go
  // through and see if any of the equations we did derive properly predict
  // them.
  if(nallof(start_time) && anyof(start_time)) {
    need = where(!start_time);
    ncount = numberof(need);

    valid = where(start_time);
    vcount = numberof(valid);

    for(i = 1; i <= ncount; i++) {
      n = need(i);
      data = *lines(n);

      // Note non-standard stop condition: it aborts if a start_time is
      // populated
      for(j = 1; j <= vcount && !start_time(n); j++) {
        v = valid(j);

        // Predicted soe values
        sp = start_time(v) + rate(v) * data.raster;
        // Upper and lower bounds for letting it pass daythresh
        slo = sp - daythresh;
        shi = sp + daythresh;

        // Only allow it to pass if it successfully predicts all points
        if(allof(slo <= data.soe & data.soe <= shi)) {
          start_time(n) = start_time(v);
          rate(n) = rate(v);
        }
      }
    }
  }

  // Sort the start_times (and keep the lines sorted with them) so that each
  // can be easily compared to its nearest neighbor.
  idx = sort(start_time);
  start_time = start_time(idx);
  rate = rate(idx);
  lines = lines(idx);

  // Group lines together based on similar start_times; they are in the same flight
  group = array(1, numberof(lines));
  j = 1;
  for(i = 2; i <= numberof(start_time); i++) {
    if(start_time(i) && abs(start_time(i) - start_time(i-1)) > daythresh) j++;
    group(i) = j;
  }

  // Merge and return grouped lines
  merged = array(pointer, j);
  for(i = 1; i <= j; i++) {
    merged(i) = &merge_pointers(lines(where(group == i)));
  }
  return merged;
}

func split_by_line(data, timediff=) {
  default, timediff, 60;
  data = sortdata(data, method="soe");
  ptr = split_sequence_by_gaps(data.soe, gap=timediff);
  for(i = 1; i <= numberof(ptr); i++)
    ptr(i) = &data(*ptr(i));
  return ptr;
}

func split_by_channel(data) {
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
  dig = data.rn % 2;
  ptr = [];
  if(anyof(dig))
    grow, ptr, &data(where(dig));
  if(nallof(dig))
    grow, ptr, &data(where(!dig));
  return ptr;
}

func split_by_ptime(data) {
  if(!has_member(data, "ptime"))
    return [&data];

  tmp = set_remove_duplicates(data.ptime);
  ptimes = [];

  // Organize so that sorted batch ptimes are first, followed by sorted
  // interactive ptimes, followed by unknown
  w = where(tmp > 0);
  if(numberof(w))
    grow, ptimes, tmp(w)(sort(tmp(w)));
  w = where(tmp < 0);
  if(numberof(w))
    grow, ptimes, tmp(w)(sort(abs(tmp(w))));
  if(anyof(tmp == 0)) grow, ptimes, 0;

  num = numberof(ptimes);
  ptr = array(pointer, num);
  for(i = 1; i <= num; i++) {
    w = where(data.ptime == ptimes(i));
    ptr(i) = &data(w);
  }
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
      chan = has_member(data, "channel") ? data.channel(1) : 0;
      save, result, swrite(format=fmt, chan), data;
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

func subsplit_by_ptime(segs) {
  result = save();
  for(i = 1; i <= segs(*); i++) {
    ptr = split_by_ptime(segs(noop(i)));
    num = numberof(ptr);

    pre = "";
    if(strlen(segs(*,i)))
      pre = segs(*,i) + "_";

    for(j = 1; j <= num; j++) {
      data = *ptr(j);
      ptime = has_member(data, "ptime") ? data.ptime(1) : 0;
      if(ptime > 0) {
        save, result, pre+swrite(format="pb%d", ptime), data;
      } else if(ptime < 0) {
        save, result, pre+swrite(format="pi%d", abs(ptime)), data;
      } else {
        save, result, pre+"punknown", data;
      }
    }
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

  The timediff= option is as documented in split_by_line.
*/
  ptrs = split_by_line(data, timediff=timediff);
  data = [];
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
  tkcmd, swrite(format="::l1pro::segments::main::launch_segs {%s} -title {%s}",
    vars, title);
}

func tk_sdw_send_times(cmd, idx, data) {
  mintime = soe2iso8601(data.soe(min));
  maxtime = soe2iso8601(data.soe(max));

  cmd = swrite(format="%s %d {%s} {%s}",
    cmd, idx, mintime, maxtime);

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
    ptr = split_by_line(data);
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
    q = gga_find_times(_tk_swd_region);
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

  segment_ptrs = split_by_line(data);
  data = [];

  loaded = mission.data.loaded;

  // heading gets handled specially
  working = [];
  working_soe = [];
  days = mission(get,);
  for(i = 1; i <= numberof(segment_ptrs); i++) {
    temp = *segment_ptrs(i);
    mission, load_soe_rn, temp.soe(1), temp.raster(1);
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
    working = working(unique(long((working_soe-working_soe(min))*200)));
  }
  return working;
}
