// vim: set ts=2 sts=2 sw=2 ai sr et:

func gt_extract_comparisons(model, truth, modelmode=, truthmode=, radius=) {
/* DOCUMENT gt_extract_comparisons(model, truth, modelmode=, truthmode=,
  radius=)

  Returns a group object with the comparison results for the given MODEL
  against the given TRUTH.

  The parameters, MODEL and TRUTH, must be values suitable for passing to
  data2xyz. This means they can be arrays of type VEG__, FS, etc. They can
  also be 3xn or nx3 arrays of doubles.

  Options MODELMODE= and TRUTHMODE= specify how to interpret MODEL and TRUTH,
  respectively. Defaults are:
    modelmode="fs"
    truthmode="fs"
  However, any of the normal values may be passed ("be", "ba", etc.).

  RADIUS= is the search radius to use about each truth point, in meters. It
  defaults to 1 meter.

  Return result is a group object with these members:
    model - The elevation value from MODEL.
    t_best - The elevation value from TRUTH that is closest in value to
      MODEL's elevation value, among those points within the RADIUS.
    t_nearest - The elevation value from TRUTH that is spatially closest to
      MODEL's x,y location.
    t_average - The average elevation value for the TRUTH points within
      RADIUS of MODEL.
    t_median - The median elevation value for the TRUTH points within RADIUS
      of MODEL.
    data - The points from MODEL that correspond to "model". This is only
      included if MODEL is a struct instance (VEG__, FS, GEO, etc.).
*/
  extern curzone;
  local mx, my, mz, tx, ty, tz;
  default, radius, 1.;
  radius = double(radius);

  // Use curzone if it's defined, otherwise arbitrarily make it 15. The zone
  // really doesn't matter since all we're using it for is to dummy out tile
  // names as part of partitioning.
  zone = curzone ? curzone : 15;

  data2xyz, model, mx, my, mz, mode=modelmode;
  data2xyz, truth, tx, ty, tz, mode=truthmode;

  data = [];
  if(typeof(model) == "struct_instance")
    data = model;

  // Eliminate model points outside of bbox+radius from truth points. Easy to
  // do, and results in huge savings if the model points cover a much larger
  // region than the truth points.
  w = data_box(mx, my, [tx(min),tx(max),ty(min),ty(max)] + radius*[-1,1,-1,1]);
  if(!numberof(w))
    error, "Points do not overlap";
  mx = mx(w);
  my = my(w);
  mz = mz(w);
  if(!is_void(data))
    data = data(w);

  // We seek four results:
  //    best: The truth elevation closest to model
  //    nearest: The truth elevation for the point spatially closest to model
  //    average: Average of truth elevations in radius about model
  //    median: Median of truth elevations in radius about model
  t_best = t_nearest = t_average = t_median = array(double, dimsof(mx));

  // Some or all of the model points may not have a truth point within radius;
  // such points must be discarded. "keep" tracks which points have yielded
  // results.
  keep = array(char(0), dimsof(mx));

  // In order to speed up the comparisons, the x and y coordinates are binned
  // into a grid so that only relevant sub-sections of the data need to be
  // examined. This avoids needing to query the entire point cloud each time.

  mxgrid = long(mx/radius);
  mygrid = long(my/radius);

  txgrid = long(tx/radius);
  tygrid = long(ty/radius);

  mxgrid_uniq = set_remove_duplicates(mxgrid);
  mxgrid_count = numberof(mxgrid_uniq);

  t0 = array(double, 3);
  timer, t0;
  p_count = numberof(mx);
  p_finished = 0;
  status, start, count=p_count, msg="Comparison analysis, done CURRENT of COUNT model points";
  for(mxgi = 1; mxgi <= mxgrid_count; mxgi++) {
    status, progress, p_finished, p_count;

    mxgw = where(mxgrid == mxgrid_uniq(mxgi));
    if(is_void(mxgw)) continue;

    txgw = where(abs(txgrid - mxgrid_uniq(mxgi)) <= 1);
    if(is_void(txgw)) {
      p_finished += numberof(mxgw);
      continue;
    }

    mygrid_uniq = set_remove_duplicates(mygrid(mxgw));
    mygrid_count = numberof(mygrid_uniq);

    for(mygi = 1; mygi <= mygrid_count; mygi++) {
      status, progress, p_finished, p_count;

      mygw = where(mygrid(mxgw) == mygrid_uniq(mygi));
      if(is_void(mygw)) continue;
      mw = mxgw(mygw);

      tygw = where(abs(tygrid(txgw) - mygrid_uniq(mygi)) <= 1);
      if(is_void(tygw)) {
        p_finished += numberof(mygw);
        continue;
      }
      tw = txgw(tygw);

      X = tx(tw);
      Y = ty(tw);
      Z = tz(tw);
      count = numberof(mw);
      for(i = 1; i <= count; i++) {
        j = mw(i);
        idx = find_points_in_radius(mx(j), my(j), X, Y, radius=radius);
        if(!numberof(idx))
          continue;

        XP = X(idx);
        YP = Y(idx);
        ZP = Z(idx);

        keep(j) = 1;

        dist = abs(ZP - mz(j));
        t_best(j) = ZP(dist(mnx));

        dist = ((mx(j) - XP)^2 + (my(j) - YP)^2) ^ .5;
        t_nearest(j) = ZP(dist(mnx));

        t_average(j) = ZP(avg);
        t_median(j) = median(ZP);
      }

      p_finished += numberof(mygw);
    }
  }
  status, finished;
  timer_finished, t0;

  if(noneof(keep))
    return [];
  mx = my = tx = ty = tz = [];

  w = where(keep);
  model = mz(w);
  if(!is_void(data))
    data = data(w);
  t_best = t_best(w);
  t_nearest = t_nearest(w);
  t_average = t_average(w);
  t_median = t_median(w);

  result = save(model, t_best, t_nearest, t_average, t_median);
  if(!is_void(data))
    save, result, data;
  return result;
}

func gt_metrics(z1, z2, metrics) {
/* DOCUMENT gt_metrics(z1, z2, metrics)
  Returns an array of strings that are the metric values as requested by the
  given array METRICS. Z1 and Z2 must each be one-dimensional arrays of
  numbers. METRICS must be an array of strings.

  Valid metrics:
    "# points" - Number of points
    "COV" - Covariance of z1 and z2
    "MinE" - Minimum z2-z1
    "Q1E" - First quartile of z2-z1
    "Q3E" - Third quartile of z2-z1
    "MaxE" - Maximum z2-z1
    "Median E" - Median of z2-z1
    "ME" - Average of z2-z1
    "MAE" - Average of abs(z2-z1)
    "Midhinge E" - Midhinge of z2-z1
    "Trimean E" - Trimean of z2-z1
    "IQME" - Interquartile mean of z2-z1
    "Pearson's R" - Perason's correlation coefficient for z1 and z2
    "Spearman's rho" - Spearman's correlation coefficient for z1 and z2
    "95% CI E" - 95% confidence interval for z2-z1
    "E skewness" - Skewness of z2-z1
    "E kurtosis" - Kurtosis of z2-z1
    "Rsq" - R squared of z2 versus z1
    "E StdDev" - Standard deviation of z2-z2
    "RMSE" - Root-mean-squared of z2-z1
    "NRMSE" - Normalized root-mean-squared of z2-z1 (as percentage)
    "SEM" - Standard error of the mean of z2-z1
    "STME" - Stadardized mean error between z2 and z1

  For information about the statistics, SEE ALSO:
    covariance quartiles median midhinge trimean interquartile_mean
    pearson_correlation spearman_correlation confidence_interval_95 skewness
    kurtosis root_mean_square normalized_rmse standardized_mean_error
    standard_error_of_mean sample_sd variance
*/
  count = numberof(metrics);
  result = array(string, count);
  zdif = z2 - z1;
  for(i = 1; i <= count; i++) {
    if(metrics(i) == "# points")
      result(i) = swrite(format="%d", numberof(z1));
    else if(metrics(i) == "COV")
      result(i) = swrite(format="%.3f", covariance(z1,z2));
    else if (metrics(i) == "MinE")
      result(i) = swrite(format="%.3f", zdif(min));
    else if (metrics(i) == "MaxE")
      result(i) = swrite(format="%.3f", zdif(max));
    else if(metrics(i) == "Q1E")
      result(i) = swrite(format="%.3f", quartiles(zdif)(1));
    else if(metrics(i) == "Q3E")
      result(i) = swrite(format="%.3f", quartiles(zdif)(3));
    else if(metrics(i) == "Median E")
      result(i) = swrite(format="%.3f", median(zdif));
    else if(metrics(i) == "ME")
      result(i) = swrite(format="%.3f", zdif(avg));
    else if(metrics(i) == "Midhinge E")
      result(i) = swrite(format="%.3f", midhinge(zdif));
    else if(metrics(i) == "Trimean E")
      result(i) = swrite(format="%.3f", trimean(zdif));
    else if(metrics(i) == "IQME")
      result(i) = swrite(format="%.3f", interquartile_mean(zdif));
    else if(metrics(i) == "Pearson's R")
      result(i) = swrite(format="%.3f", pearson_correlation(z1,z2));
    else if(metrics(i) == "Spearman's rho")
      result(i) = swrite(format="%.3f", spearman_correlation(z1,z2));
    else if(metrics(i) == "95% CI E") {
      ci = confidence_interval_95(zdif);
      result(i) = swrite(format="%.3f to %.3f", ci(1), ci(2));
    } else if(metrics(i) == "E skewness")
      result(i) = swrite(format="%.3f", skewness(zdif));
    else if(metrics(i) == "E kurtosis")
      result(i) = swrite(format="%.3f", kurtosis(zdif));
    else if(metrics(i) == "Rsq")
      result(i) = swrite(format="%.3f", r_squared(z2, z1));
    else if(metrics(i) == "RMSE")
      result(i) = swrite(format="%.3f", root_mean_square(zdif));
    else if(metrics(i) == "NRMSE")
      result(i) = swrite(format="%.1f%%", normalized_rmse(z2, z1) * 100);
    else if(metrics(i) == "SEM")
      result(i) = swrite(format="%.3f\n", standard_error_of_mean(zdif));
    else if(metrics(i) == "STME")
      result(i) = swrite(format="%.3f\n", standardized_mean_error(z2, z1));
    else if(metrics(i) == "E StdDev")
      result(i) = swrite(format="%.3f", zdif(rms));
    else if (metrics(i) == "MAE")
      result(i) = swrite(format="%.3f", abs(zdif)(avg));
    else
      error, "Unknown metric: " + metrics(i);
  }
  return result;
}

func gt_scatterplot(z1, z2, win=, dofma=, title=, xtitle=, ytitle=,
scatterplot=, equality=, mean_error=, ci95=, linear_lsf=, quadratic_lsf=,
metrics=) {
/* DOCUMENT gt_scatterplot, z1, z2, win=, dofma=, title=, xtitle=, ytitle=,
  scatterplot=, equality=, mean_error=, ci95=, linear_lsf=, quadratic_lsf=,
  metrics=

  Plots a scatterplot of Z1 versus Z2, along with additional plots and
  metrics.

  Parameters:
    z1: A one-dimensional array of values. These are typically ground truth
      values and will be associated with the X axis.
    z2: A one-dimensional array of values. These are typically model/lidar
      data values and will be associated with the Y axis.

  General options:
    win= The window to plot in. Default is the current window.
    dofma= Specifies whether to clear before plotting. Valid settings:
        dofma=0     Do not clear
        dofma=1     Clear (default)
    title= Specifies a title for the plot. Examples:
        title="Fire Island Analysis"
        title=""    (default; this results in no title)
    xtitle= Specifies a title for the X axis. Examples:
        xtitle="Ground Truth Data (m)"   (default)
    ytitle= Specifies a title for the Y axis. Examples:
        ytitle="Lidar Data (m)"    (default)
    metrics= Specifies which metrics to plot. This should be an array of
      strings. Each string must be a valid metric for gt_metrics. Examples:
        metrics=["# points", "ME"]    (default)

  Plot options:
  These options each take a string as a value. The string should be formatted
  as detailed in parse_plopts.
    scatterplot= Scatter plot of z2 vs z1
        scatterplot="square black 0.2"   (default)
    equality= Equality line: x = y
        equality="dash black 1.0"
    mean_error= Mean error line
        mean_error="hide"
    ci95= 95% confidence interval lines about the mean error
        ci95="hide"
    linear_lsf= Linear least-squares-fit line
        linear_lsf="solid black 1.0"
    quadratic_lsf= Quadratic least-squares-fit line
        quadratic_lsf="hide"
*/
  local type, color, size;

  default, win, current_window();
  default, dofma, 1;
  default, title, string(0);
  default, xtitle, "Ground Truth Data (m)";
  default, ytitle, "Lidar Data (m)";
  default, scatterplot, "square black 0.2";
  default, equality, "dash black 1.0";
  default, mean_error, "hide";
  default, ci95, "hide";
  default, linear_lsf, "solid black 1.0";
  default, quadratic_lsf, "hide";
  default, metrics, ["# points", "RMSE", "ME", "Rsq"];

  if(win < 0)
    win = 0;

  // z1 = truth; z2 = lidar
  zdif = z2 - z1;

  xbounds = [z1(min), z1(max)];
  ybounds = [z2(min), z2(max)];

  window, win;
  if(dofma) fma;

  parse_plopts, scatterplot, type, color, size;
  if(type != "hide")
    plmk, z2, z1, width=10, marker=type, color=color, msize=size;

  parse_plopts, equality, type, color, size;
  if(type != "hide")
    plg, xbounds, xbounds, type=type, color=color, width=size;

  parse_plopts, mean_error, type, color, size;
  if(type != "hide") {
    ME = zdif(avg);
    plg, xbounds + ME, xbounds, type=type, color=color, width=size;
  }

  parse_plopts, ci95, type, color, size;
  if(type != "hide") {
    CI = confidence_interval_95(zdif);
    plg, xbounds + CI(1), xbounds, type=type, color=color, width=size;
    plg, xbounds + CI(2), xbounds, type=type, color=color, width=size;
  }

  parse_plopts, linear_lsf, type, color, size;
  if(type != "hide") {
    c = poly1_fit(z2, z1, 1);
    plg, poly1(xbounds, c), xbounds, type=type, color=color, width=size;
  }

  parse_plopts, quadratic_lsf, type, color, size;
  if(type != "hide") {
    c = poly1_fit(z2, z1, 2);
    x = span(xbounds(1), xbounds(2), 100);
    plg, poly1(x, c), x, type=type, color=color, width=size;
  }

  if(!is_scalar(metrics)) {
    values = gt_metrics(z1, z2, metrics);
    display = strjoin(metrics + ": " + values, "\n");
    vp = viewport();
    plt, display, vp(1) + .01, vp(4) - .01, justify="LT", height=12;
  }

  if(strlen(title))
    pltitle, title;
  if(strlen(xtitle) || strlen(ytitle))
    xytitles, xtitle, ytitle;
  limits, square=1;
  limits;
}

func gt_report(comparisons, which, metrics=, title=, outfile=) {
/* DOCUMENT gt_report, comparisons, which, metrics=, title=, outfile=
  Prints out statisticts for the given comparisons.

  Parameters:
    comparisons: The output of gt_extract_comparisons.
    which: An array of strings that specify which comparisons to use. For
      example: ["best", "nearest", "average"]

  Options:
    metrics= An array of metrics to report on. This array should be suitable
      for gt_metrics. Example:
        metrics=["# points", "RMSE", "ME", "Rsq"]    (default)
    title= If provided, this will be printed as a title at the top of the
      report.
    outfile= If provided, then the output will go to this file instead of
      being printed on the screen.
*/
  default, metrics, ["# points", "RMSE", "ME", "Rsq"];
  fmt = swrite(format="%%%ds", strlen(metrics)(max));
  output = swrite(format=fmt, grow("", metrics));
  for(i = 1; i <= numberof(which); i++) {
    col = gt_metrics(comparisons.model, comparisons("t_"+which(i)), metrics);
    col = grow(which(i), col);
    fmt = swrite(format="  %%%ds", strlen(col)(max));
    output += swrite(format=fmt, col);
  }

  if(!is_void(title) && strlen(title)) {
    indent = (strlen(output)(max) - strlen(title))/2;
    if(indent > 0)
      title = array(" ", indent)(sum) + title;
    output = grow(title, output);
  }

  if(outfile) {
    f = open(outfile, "w");
    write, f, format="%s\n", output;
    close, f;
  } else {
    write, format="%s\n", output;
  }
}

func gt_extract_selpoly(which) {
/* DOCUMENT gt_extract_selpoly, which
  Glue for Groundtruth Analysis tool's Extract pane. Prompts user to draw a
  polygon in the current window. The coordinates are sent to the tool to be
  used for the data specified by WHICH.
*/
  win = window();
  write, format="Draw a polygon in window %d to select the region.", win;
  ply = getPoly();
  gt_extract_send, ply, "Polygon", which;
}

func gt_extract_selbbox(which) {
/* DOCUMENT gt_extract_selbbox, which
  Glue for Groundtruth Analysis tool's Extract pane. Prompts user to draw a
  box in the current window. The coordinates are sent to the tool to be used
  for the data specified by WHICH.
*/
  win = window();
  msg = swrite(format="Draw a box in window %d to select the region.", win);
  rgn = mouse(1, 1, msg);
  ply = transpose([rgn([1,3,3,1,1]), rgn([2,2,4,4,2])]);
  gt_extract_send, ply, "Rubberband box", which;
}

func gt_extract_seltran(which, width) {
/* DOCUMENT gt_extract_seltran, which
  Glue for Groundtruth Analysis tool's Extract pane. Prompts user to draw a
  transect line in the current window. The line is buffered into a polygon
  with the specified WIDTH. The coordinates are sent to the tool to be used
  for the data specified by WHICH.
*/
  win = window();
  msg = swrite(format="Drag a transect line in window %d to select the region.", win);
  line = mouse(1, 2, msg);
  ply = line_to_poly(line(1), line(2), line(3), line(4), width=width);
  gt_extract_send, ply, "Transect", which;
}

func gt_extract_sellims(which) {
/* DOCUMENT gt_extract_sellims, which
  Glue for Groundtruth Analysis tool's Extract pane. Retrieves current
  window's limits as a polygon. The coordinates are sent to the tool to be
  used for the data specified by WHICH.
*/
  win = window();
  lims = limits();
  ply = lims([[1,3],[1,4],[2,4],[2,3],[1,3]]);
  gt_extract_send, ply, swrite(format="Window %d limits", win), which;
}

func gt_extract_send(ply, kind, which) {
/* DOCUMENT gt_extract_send, ply, kind, which
  Utility function for other glue functions for Groundtruth Analysis tool's
  Extract pane. Sends a polygon PLY of type KIND to the tool to be used for
  data WHICH.
*/
  area = poly_area(ply);
  if(area < 1e6)
    area = swrite(format="%.0f square meters", area);
  else
    area = swrite(format="%.3f square kilometers", area/1.e6);
  fmt = "set ::l1pro::groundtruth::extract::v::%s_region_desc {%s with area %s}";
  tkcmd, swrite(format=fmt, which, kind, area);

  ply = swrite(format="%.3f", ply);
  ply = "[" + ply(1,) + "," + ply(2,) + "]";
  ply(:-1) += ","
  ply = "[" + ply(sum) + "]";
  fmt = "set ::l1pro::groundtruth::extract::v::%s_region_data {%s}";
  tkcmd, swrite(format=fmt, which, ply);
}

func gt_vars_selpoly(data, which, win) {
/* DOCUMENT gt_vars_selpoly(data, which, win)
  Glue for Groundtruth Analysis tool's Variables pane. Prompts user to draw a
  polygon in the Scatterplot window. Points in that region are then extracted
  and returned. DATA is comparisons variable, WHICH is truth data to use, WIN
  is window the plot exists in.
*/
  wbkp = current_window();
  window, win;
  write, format="Draw a polygon in window %d to select the region.", win;
  ply = getPoly();
  window_select, wbkp;
  return gt_vars_subsample(data, which, ply);
}

func gt_vars_selbbox(data, which, win) {
/* DOCUMENT gt_vars_selbbox(data, which, win)
  Glue for Groundtruth Analysis tool's Variables pane. Prompts user to draw a
  box in the Scatterplot window. Points in that region are then extracted and
  returned. DATA is comparisons variable, WHICH is truth data to use, WIN is
  window the plot exists in.
*/
  wbkp = current_window();
  window, win;
  msg = swrite(format="Draw a box in window %d to select the region.", win);
  rgn = mouse(1, 1, msg);
  ply = transpose([rgn([1,3,3,1,1]), rgn([2,2,4,4,2])]);
  return gt_vars_subsample(data, which, ply);
}

func gt_vars_subsample(data, which, ply) {
/* DOCUMENT gt_vars_subsample(data, which, ply)
  Utility function for other glue functions for Groundtruth Analysis tool's
  Variables pane. Extracts from DATA using comparison type WHICH (such as
  "t_best"), the points within polygon PLY.
*/
  w = testPoly(ply, data(noop(which)), data(model));
  if(numberof(w))
    return obj_index(data, w);
  else
    return [];
}

func gt_vars_bound(data, which, win, bound) {
/* DOCUMENT gt_vars_bound(data, which, bound)
  Glue for Groundtruth Analysis tool's Variables pane. User is prompted to
  click according to BOUND. Extracts data from histogram of DATA using truth
  data WHICH that falls between user-clicked bounds.
*/
  local lbound, ubound;
  wbkp = current_window();
  window, win;
  if(bound == "minmax") {
    write, format="Select two bounding points in window %d\n", win;
    lbound = mouse()(1);
    ubound = mouse()(1);
    if(ubound < lbound)
      swap, lbound, ubound;
  } else if(bound == "min") {
    write, format="Select minimum bounding point in window %d\n", win;
    lbound = mouse()(1);
  } else if(bound == "max") {
    write, format="Select maximum bounding point in window %d\n", win;
    ubound = mouse()(1);
  }
  w = filter_bounded_elv(data(model) - data(noop(which)), lbound=lbound,
    ubound=ubound, idx=1);
  if(numberof(w))
    return obj_index(data, w);
  else
    return [];
}

func gt_pixelwf_interactive(vname, which, win) {
  extern pixelwfvars;
  data = var_expr_get(vname);

  wbkp = current_window();

  continue_interactive = 1;
  while(continue_interactive) {
    write, format="\nWindow %d: Left-click to examine a point. Anything else aborts.\n", win;

    window, win;
    spot = mouse(1, 1, "");

    if(mouse_click_is("left", spot)) {
      write, format="\n-----\n\n%s", "";
      nearest = gt_pixelwf_find_point(spot, data, which);
      if(is_void(nearest.point)) {
        write, format="Location clicked: %9.2f %10.2f\n", spot(1), spot(2);
        write, format="No point found within search radius (%.2fm).\n",
          pixelwfvars.selection.radius;
      } else {
        pixelwf_set_point, nearest.point;
        plmk, nearest.y, nearest.x, msize=0.004, color="red",
          marker=[[0,1,0,1,0,-1,0,-1,0],[0,1,0,-1,0,-1,0,1,0]];
        tkcmd, "::misc::idle {ybkg pixelwf_plot}";
        pixelwf_selected_info, nearest, vname=vname;
      }
    } else {
      continue_interactive = 0;
    }
  }

  window_select, wbkp;
}

func gt_pixelwf_find_point(spot, data, which) {
  extern pixelwfvars;
  vars = pixelwfvars.selection;
  radius = vars.radius;

  bbox = spot([1,1,2,2]) + radius * [-1,1,-1,1];
  w = data_box(data(noop(which)), data.model, bbox);

  dist = index = nearest = [];
  if(numberof(w)) {
    x = data(noop(which))(w);
    y = data.model(w);
    d = sqrt((x-spot(1))^2 + (y-spot(2))^2);
    if(d(min) <= radius) {
      dist = d(min);
      index = w(d(mnx));
      nearest = data.data(index);
      nx = x(d(mnx));
      ny = y(d(mnx));
    }
  }

  return h_new(point=nearest, index=index, distance=dist, spot=spot, x=nx, y=ny);
}
