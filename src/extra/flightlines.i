// vim: set ts=2 sts=2 sw=2 ai sr et:

func flightlines_detect_pnav(pn, tolerance=, minlen=, verbose=) {
/* DOCUMENT flightlines_detect_pnav(pnav, tolerance=, minlen=, verbose=)
  Wrapper around flightlines_detect that converts PNAV lat/lon to UTM
  coordinates.
*/
  local north, east;
  zone = best_zone(pn.lon, pn.lat);
  ll2utm, pn.lat, pn.lon, north, east, force_zone=zone;

  return flightlines_detect(east, north, tolerance=tolerance, minlen=minlen,
    verbose=verbose);
}

func flightlines_detect(x, y, tolerance=, minlen=, verbose=) {
/* DOCUMENT flightlines_detect(x, y, tolerance=, minlen=, verbose=)
  Returns indices that define the flightlines detected in the coordinates X,Y.
  These coordinate should be UTM coordinates in meters, all in the same zone.

  The algorithm has two steps:

  First, flightline segments are found using TOLERANCE and MINLEN as
  constraints. Flightlines are picked by repeatedly extracting the longest
  remaining sequence of x,y points with headings within the range defined by
  TOLERANCE and with a length of at least MINLEN. As each sequence is picked,
  its points are removed from consideration on further iterations of
  detection. Flightline segments are picked until there remain no more
  flightline segments within the given parameters.

  Second, the detected flightline segments are extended to include any regions
  not included in a detected flightline segment. Each segment that is between
  a pair of detected flightlines is split into two sub-segments with
  approximately equal angular range for the headings. Those two adjacent
  flightline segments are then extended to each include one of the
  sub-segments. As a special case, any leading or trailing segments are added
  in whole to the first or last flightline segment.

  Options:
    tolerance= The angular range permitted for the headings on a flightline
      segment, in degrees.
        tolerance=30.     30 degrees, default
    minlen= The minimum length for a flightline segment, in meters.
        minlen=2000.      2000m (2km), default
    verbose= Verbosity mode. At present, just displays time it took to
      compute flightlines.
        verbose=0         Silent, default
        verbose=1         Show run time

  Returns result 'flt' which is indices [start, stop], such that
    x(flt(1,1):flt(1,2)), y(flt(1,1):flt(1,2)) is the first flightline
    x(flt(2,1):flt(2,2)), y(flt(2,1):flt(2,2)) is the second flightline
    ...
    x(flt(0,1):flt(0,2)), y(flt(0,1):flt(0,2)) is the last flightline

  Note that these are always true:
    flt(:-1,2)+1 == flt(2:,1)
    flt(1,1) == 1
    flt(0,2) == numberof(x)
    flt(:-1,) < flt(2:,)
*/
  default, tolerance, 30.;
  default, minlen, 2000.;
  default, verbose, 0;

  t0 = array(double, 3);
  timer, t0;

  tolerance *= DEG2RAD;

  xdif = x(dif);
  ydif = y(dif);
  ang = atan(ydif, xdif);
  dist = sqrt(xdif^2 + ydif^2);
  xdif = ydif = [];

  // smooth out ang so that there's no 2pi shifts
  ang = continuous_angles(ang, rad=1);

  count = numberof(ang);
  lengths = lines = array(-1, count);

  // for each starting index, calculate the last index that maintains the
  // target threshold
  sequences = find_windowed_subsequences(ang, tolerance);
  for(i = 1; i <= count; i++)
    lengths(i) = dist(i:sequences(i))(sum);

  // pick the longest sequence. if it's >= minlen, consider it a flightline
  // and repeat.
  start = lengths(mxx);
  while(lengths(start) > minlen) {
    stop = sequences(start);
    lines(start) = stop;
    sequences(start:stop) = -1;
    w = where(sequences(:start) >= start);
    if(numberof(w)) {
      sequences(w) = start-1;
      for(i = 1; i <= numberof(w); i++) {
        lengths(w(i)) = dist(w(i):sequences(w(i)))(sum);
      }
    }
    lengths(start:stop) = -1;

    start = lengths(mxx);
  }

  // Retrieve bounds
  starts = where(lines > 0);
  stops = lines(starts);

  // Extend segments to include omitted regions
  starts(1) = 1;
  stops(0) = numberof(x);

  for(i = 1; i < numberof(stops); i++) {
    idx = range_bisection(ang(stops(i):starts(i+1)));
    stops(i) += idx - 2;
    starts(i+1) = stops(i) + 1;
  }

  if(verbose)
    timer_finished, t0, fmt=" Finished in SECONDS seconds\n";

  return [starts, stops];
}

func flightlines_pnav_indices_to_soe(flt, pn, soe_start) {
  extern pnav, soe_day_start;

  default, pn, pnav;
  default, soe_start, soe_day_start;

  soe = pn.sod + soe_start;

  fltsoe = soe(flt);

  result = array(double, dimsof(flt)(2)+1);

  result(1) = fltsoe(1,1) - 5.;
  result(0) = fltsoe(0,2) + 5.;

  for(i = 2; i < numberof(result); i++)
    result(i) = (fltsoe(i-1,1)+fltsoe(i,2))/2.;

  return result;
}

func flightlines_plot_pnav(pn, flt, colors=, win=, width=, xfma=) {
  local x, y;
  zone = best_zone(pn.lon, pn.lat);
  ll2utm, pn.lat, pn.lon, y, x, force_zone=zone;
  flightlines_plot, x, y, flt, colors=colors, win=win, width=width, xfma=xfma;
}

func flightlines_plot(x, y, flt, colors=, win=, width=, xfma=) {
  default, colors, ["black","red","blue","green","cyan","magenta","yellow"];
  default, win, window();
  default, width, 1;
  default, xfma, 0;

  wbkp = current_window();
  window, win;

  if(xfma) fma;

  start = flt(,1);
  stop = flt(,2);
  flt = [];

  for(i = 1; i <= numberof(start); i++) {
    ci = i % numberof(colors);
    plg, y(start(i):stop(i)), x(start(i):stop(i)), color=colors(ci),
      width=width, marks=0, legend=swrite(format="Flightline %d", i);
  }

  window_select, win;
}

func flightlines_merge(&flt, f1, f2) {
  start = flt(,1);
  stop = flt(,2);

  if(f2 < f1)
    swap, f1, f2;

  if(f2 - f1 != 1) {
    write, "invalid flightline numbers, merge aborted";
    return;
  }

  keep = array(1, numberof(start));
  keep(f1) = 0;
  stop = stop(where(keep));

  keep(*) = 1;
  keep(f2) = 0;
  start = start(where(keep));

  flt = [start,stop];
}

func flightlines_split_pnav(pn, &flt, fnum) {
  local x, y;
  zone = best_zone(pn.lon, pn.lat);
  ll2utm, pn.lat, pn.lon, y, x, force_zone=zone;
  flightlines_split, x, y, flt, fnum;
}

func flightlines_split(x, y, &flt, fnum) {
  click = mouse(1, 2,
    swrite(format="Click mouse where you would like to split segment %d", fnum));

  if(noneof(click)) {
    write, "Clicked on wrong window, aborting";
    return;
  }

  start = flt(,1);
  stop = flt(,2);

  x0 = click(1)
  y0 = click(2);
  x1 = click(3);
  y1 = click(4);

  rng = start(fnum):stop(fnum);

  dist0 = ppdist([x(rng),y(rng)], [x0,y0], tp=1);
  dist1 = ppdist([x(rng),y(rng)], [x1,y1], tp=1);
  dist = sqrt((dist0^2 + dist1^2)/2.);
  idx = dist(mnx);
  if(idx == start(fnum)) {
    // pass
  } else if(idx == stop(fnum)) {
    idx--;
  } else if(dist(idx-1) < dist(idx+1)) {
    idx--;
  }

  idx = idx - 1 + start(fnum);

  grow, stop, stop(fnum);
  stop(fnum) = idx;
  grow, start, idx+1;

  stop = stop(sort(stop));
  start = start(sort(start));

  flt = [start, stop];
}

func flightlines_showhide(data, win=) {
  local flt;

  default, win, window();
  wbkp = current_window();

  window, win;
  w = where(regmatch("Flightline ([0-9]+)", plq(), , flt));
  flt = flt(w);
  fltplq = save();
  for(i = 1; i <= numberof(flt); i++) {
    save, fltplq, flt(i), w(i);
    pledit, w(i), hide=1;
  }

  data = strsplit(data, " ");
  for(i = 1; i <= numberof(data); i += 2) {
    item = data(i);
    color = data(i+1);
    pledit, fltplq(noop(item)), hide=0, color=color;
  }

  window_select, wbkp;
}

func flightlines_play_pnav(pn, flt, colors=, win=, width=, xfma=) {
  local x, y;
  zone = best_zone(pn.lon, pn.lat);
  ll2utm, pn.lat, pn.lon, y, x, force_zone=zone;
  flightlines_play, x, y, flt, colors=colors, win=win, width=width, xfma=xfma;
}

func flightlines_play(x, y, flt, colors=, win=, width=, xfma=) {
  default, colors, ["black","red","blue","green","cyan","magenta","yellow"];
  default, win, window();

  wbkp = current_window();
  window, win;
  flightlines_plot, x, y, flt, colors=colors, width=width, xfma=xfma;

  count = dimsof(flt)(2);
  ploffset = numberof(plq()) - count;

  write, format="%d flightlines total (hit enter to start viewing individually)\n",
    count;
  pause, 10000;
  lims = limits();
  limits, lims(1), lims(2), lims(3), lims(4);

  for(i = 1; i <= count; i++) {
    write, format="%d of %d (hit enter for next)\n", i, count;
    flightlines_showhide, swrite(format="%d black", i);
    pause, 10000;
  }

  line_colors = array(string, count);
  for(i = 1; i <= numberof(colors) && i <= count; i++)
    line_colors(i::numberof(colors)) = colors(i);

  flightlines_showhide, swrite(format="%d %s ", indgen(count), line_colors)(sum);
}
