// vim: set ts=2 sts=2 sw=2 ai sr et:

extern _transect_history;
/* DOCUMENT _transect_history
  Maintains a history of transect lines generated by calls to transect. These
  can be recalled using the recall= option on transect.

  To view a list of all transects in the history, use transect_history:
    > transect_history

  To plot a line from the history, use transect_plot_line:
    > transect_plot_line, recall=0, win=5
*/

func data_transect(data, line, width=, mode=) {
/* DOCUMENT data_transect(data, line, width=, mode=)
  Returns the points from DATA that fall along the transect LINE.

  Parameters:
    data: An array of ALPS data.
    line: An array [x0,y0,x1,y1] specifying the start and end points of the
      transect line.
  Options:
    width= The width of the transect line.
      width=1.0     Line is 1m wide; gets points within 50cm of line (default)
    mode= Data mode to use.
*/
  default, width, 1.0;
  ply = line_to_poly(line(1), line(2), line(3), line(4), width=width);
  return data_in_poly(data, ply, mode=mode);
}

func transect_history(void) {
/* DOCUMENT transect_history
  Shows a list of all transects currently defined in the transect history.
*/
  extern _transect_history;
  if(is_void(_transect_history)) {
    write, "No transect history";
    return;
  }
  write, format="%s\n", "First recall= will never change for a given line.";
  write, format="%s\n", "Second recall= changes as new transects are added to the history.";
  count = dimsof(_transect_history)(3);
  for(idx1 = 1; idx1 <= count; idx1++) {
    idx2 = idx1 - count;
    line = transect_recall(idx1);
    dist = long(sqrt(line([1,3])(dif)^2 + line([2,4])(dif)^2)(1)+.5);
    line = long(line+.5);
    write, format="recall=%-2d  recall=%-3d  (%6d,%7d) to (%6d,%7d)  length %dm\n",
      idx1, idx2, line(1), line(2), line(3), line(4), dist;
  }
}

func transect_recall(idx) {
/* DOCUMENT transect_recall(idx)
  Retrieve a line from the transect history. IDX should be an integer. It may
  be positive or negative. If negative, then it's an index into the history
  where 0 is most recent and -1 is second most recent. If positive, then it's
  into into the history where 1 is most recent and 2 is second most recent.
    idx=1 or idx=0 will return the most recently created transect
    idx=2 or idx=-1 will return the second most recent transect
    idx=3 or idx=-2 will return the third most recent transect
    etc.
  If the given IDX does not exist in the history, then EXIT will be called to
  abort out of all current functions.
*/
  extern _transect_history;
  if(is_void(_transect_history)) {
    write, "No lines in _transect_history";
    exit;
  }
  count = dimsof(_transect_history)(3);
  if(idx < 0)
    idx += count;
  if(idx > count) {
    write, "Requested line exceeds history in _transect_history";
    exit;
  }
  return _transect_history(,idx);
}

func transect_plot_line(line, win=, recall=) {
/* DOCUMENT transect_plot_line, line, win=, recall=
  Plots a transect line. The line will be red. The start point will be given a
  blue dot and the end point will be given a red dot.
*/
  extern _transect_history;
  wbkp = current_window();
  if(!is_void(win)) window, win;
  if(!is_void(recall)) line = transect_recall(recall);
  plg, line([2,4]), line([1,3]), width=2., color="red";
  plmk, line(2), line(1), marker=4, msize=.2, color="blue";
  plmk, line(4), line(3), marker=4, msize=.2, color="red";
  window_select, wbkp;
}

func transect_plot_points(line, data, how=, win=, xfma=, msize=, marker=,
connect=, scolor=) {
/* DOCUMENT transect_plot_points, line, data, how=, win=, xfma=, msize=,
   marker=, connect=

  Plots the points from DATA as they appear along the transect LINE. Points
  will be broken up into segments (based on HOW).

  Parameters:
    line: A 4-element array [x0,y0,x1,y1]
    data: The points along LINE (as determined by transect)

  Options:
    how= A string or array of strings containing any of "flight", "line",
      "channel", or "digitizer". This specifies how DATA will be broken up into
      segments. Each segment gets its own color.
        how="line"                Break data into flight lines (default)
        how="channel"             Break data up by channel
        how=["line","channel"]    Break data up by lines and by channels
    win= Window to plot in.
    xfma= Set to 1 to issue an fma prior to plotting.
    msize= Size to use for plotted points.
    marker= Marker to use for plotted points.
    connect= Set to connect=1 to draw a polyline in addition to the points.
    scolor= Sets the starting color. The colors used are black, red, blue,
      green, magenta, yellow, and cyan (in that order). If you set the starting
      color to blue, then blue will be the first color used, followed by green,
      magenta, etc. If there are more than 7 colors, then colors will be reused
      in a cyclic manner.
        scolor="black"            Start with black (default)
*/
  // Break the data up into segments
  segs = split_data(data, how);

  colors = ["black", "red", "blue", "green", "magenta", "yellow", "cyan"];
  ncolors = numberof(colors);

  // If scolor is specified, then shift the color array so that the specified
  // color is first.
  if(!is_void(scolor)) {
    w = where(colors == scolor);
    if(!numberof(w))
      error, "Invalid scolor="+pr1(scolor);
    colors = colors(long(roll(indgen(ncolors), 1-w(1))));
  }

  wbkp = current_window();
  if(!is_void(win)) window, win;
  if(xfma) fma;

  local x, y, z, rx, ry, rn;
  for(i = 1; i <= segs(*); i++) {
    color = colors(i % ncolors);
    seg = segs(noop(i));
    data2xyz, seg, x, y, z, mode=mode;
    project_points_to_line, line, x, y, rx, ry;

    if(numberof(how))
      write, format="%7s", color;

    if(anyof(how == "channel")) {
      write, format=" chn%d", seg.channel(1);
    }

    if(anyof(how == "digitizer")) {
      parse_rn, seg.rn(1), rn;
      write, format=" d%d", 2-(rn % 2);
    }

    if(anyof(how == "line") || anyof(how == "flight")) {
      write, format=" %s", soe2iso8601(seg.soe(min));
      write, format=" %8.2f", soe2sod(seg.soe(min));
      write, format=" (%.2fs)", seg.soe(max)-seg.soe(min);

      // If tans data is available, grab the heading
      if(!is_void(tans)) {
        tansdif = abs(tans.somd - soe2sod(seg.soe(min)));
        w = tansdif(mnx);
        if(tansdif(w) < 0.01) {
          write, format=" %5.1f", tans(w).heading;
        }
      }
    }

    if(numberof(how))
      write, format="%s", "\n";

    if(connect) {
      // Not all segmenting methods will put the points in a line graph
      // friendly order. Ordering by rx makes sure the line graph looks nice.
      srt = sort(rx);
      rx = rx(srt);
      z = z(srt);
      plg, z, rx, color=color;
    }
    plmk, z, rx, color=color, msize=msize, width=10, marker=marker;
  }

  window_select, wbkp;
}

func transect(data, line=, recall=, segment=, iwin=, owin=, width=, connect=,
xfma=, mode=, msize=, marker=, scolor=, plot=, showline=, showpts=) {
/* DOCUMENT transect(data, line=, recall=, segment=, iwin=, owin=, width=,
   connect=, xfma=, mode=, msize=, marker=, scolor=, plot=, showline=, showpts=)

  Performs a transect operation against some data and plots the result.

  The transect line is acquired in one of three ways:
    1. If line= is specified, that line is used.
    2. If recall= is specified, then a line from the history is used.
    3. Otherwise, the user is prompted to drag out a line.

  Parameter:
    data: An array of data to transect.

  Options:
    line= Optional. If provided, must be an array [x0,y0,x1,y1] specifying the
      transect line.
    recall= Optional. If provided, must be an integer representing which line
      from the transect history to use.
    segment= Specifies how to segment the points. If omitted, no segmenting
      will happen and plot will be in one color.
        segment="line"                Segment by line
        segment=["line", "channel"]   Segment by line and channel
    iwin= "Input" window, where the point cloud to transect is plotted. This
      window is used when prompting the user to draw a transect. It is also
      used to plot the transect line (if showline=1 or =2) and to highligh the
      selected points (if showpts=1).
        iwin=5      Window 5, default
    owin= "Output" window, where the transect points are plotted (if plot=1).
        owin=2      Window 2, default
    width= Width of the transect line. This is the total width, with the
      transect line running down the middle. (So points are used if they are
      within width/2 of the transect line.)
        width=3.0   3 meter width (1.5m on either side), default
    connect= By default, transect points are plotted as a scatterplot. This
      option adds a polyline graph to connect the points.
        connect=0   Don't plot lines, default
        connect=1   Plot polylines
    xfma= Specifies whether to issue an fma prior to plotting transect points.
        xfma=0      No fma, default
        xfma=1      Issue fma
    mode= Data mode to use for points.
        mode="fs    Default
    msize= Size to use for plotted points.
        msize=0.1   Default
    marker= Marker to use for plotted points.
        marker=1    Default
    scolor= Sets the starting color. The colors used are black, red, blue,
      green, magenta, yellow, and cyan (in that order). If you set the starting
      color to blue, then blue will be the first color used, followed by green,
      magenta, etc. If there are more than 7 colors, then colors will be reused
      in a cyclic manner.
        scolor="black"            Start with black (default)
    plot= Specifies whether or not to plot the transect points.
        plot=0      Don't plot
        plot=1      Plot, default
    showline= Specifies whether to show the transect line.
        showline=0  Never show transect line
        showline=1  Show transect line if just acquired, default
        showline=2  Always show line, even if from line= or recall=
    showpts= Specifies whether to plot markers over the points used for the
      transect in the original data window.
        showpts=0   Don't show, default
        showpts=1   Show
*/
  default, iwin, 5;
  default, owin, 2;
  default, width, 3.0;
  default, connect, 0;
  default, xfma, 0;
  default, mode, "fs";
  default, msize, 0.1;
  default, marker, 1;
  default, plot, 1;
  default, showline, 1;
  default, showpts, 0;

  wbkp = current_window();

  if(is_void(data)) {
    write, "No data provided";
    return;
  }

  if(is_void(line) && is_void(recall)) {
    window, iwin;
    write, format="Drag to draw transect line in window %d\n", iwin;
    line = mouse(1, 2, "")(1:4);
    grow, _transect_history, [line];
    write, format="Added line to history as recall=%d\n",
      dimsof(_transect_history)(3);
    window_select, wbkp;

    if(showline)
      transect_plot_line, line, win=iwin;
  } else {
    if(is_void(line) && !is_void(recall))
      line = transect_recall(recall);
    if(is_void(line))
      error, "No transect line selected";
    if(showline > 1)
      transect_plot_line, line, win=iwin;
  }

  data = data_transect(data, line, width=width, mode=mode);
  if(is_void(data)) {
    write, "no data along transect";
    return;
  }

  if(plot)
    transect_plot_points, line, data, how=segment, win=owin, xfma=xfma,
      msize=msize, marker=marker, scolor=scolor, connect=connect;

  // plot the actual points selected onto the input window
  if(showpts) {
    local x, y;
    data2xyz, data, x, y, mode=mode;
    window, iwin;
    plmk, y, x, msize=msize, marker=marker, color="black";
    window_select, wbkp;
  }

  return data;
}

func transect_pixelwf_interactive(vname, line, recall=, win=, mode=) {
/* DOCUMENT transect_pixelwf_interactive, vname, line, win=
  Enters an interactive query mode similar to pixelwf_interactive, except that
  it queries a transect plot. VNAME should be the name of the variable
  containing the points plotted, LINE should be the transect they're plotted
  with respect to, and WIN should be the window they're plotted in. RECALL can
  be used to recall an existing line from the transect history.
*/
  extern pixelwfvars;
  if(is_void(pixelwfvars)) {
    write, "EAARL plugin has not been loaded, aborting.";
    return;
  }

  if(is_void(win)) win = window();
  data = var_expr_get(vname);

  if(is_void(line) && !is_void(recall))
    line = transect_recall(recall);

  // Pull out data coordinates
  local x, y, z, rx, ry;
  data2xyz, data, x, y, z, mode=mode;
  project_points_to_line, line, x, y, rx, ry;

  // The window we're clicking in has RX along its X axis and Z along its Y
  // axis.

  wbkp = current_window();

  continue_interactive = 1;
  while(continue_interactive) {
   write, format="\nWindow %d: Left-click to examine a point. Anything else aborts.\n", win;

    window, win;
    spot = mouse(1, 1, "");

    if(mouse_click_is("left", spot)) {
      write, format="\n-----\n\n%s", "";
      nearest = transect_pixelwf_find_point(spot, data, rx, z);
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

func transect_pixelwf_find_point(spot, data, x, y) {
/* DOCUMENT transect_pixelwf_find_point(spot, data, x, y)
  Utility function for transect_pixelwf_interactive. Given SPOT (a mouse click
  result), DATA (a point cloud), and X,Y (the coordiantes in the plot that
  correspond to the points in DATA), this returns a various info about the
  closest point to SPOT.
*/
  extern pixelwfvars;
  if(is_void(pixelwfvars)) {
    write, "EAARL plugin has not been loaded, aborting.";
    return;
  }

  vars = pixelwfvars.selection;
  radius = vars.radius;

  bbox = spot([1,1,2,2]) + radius * [-1,1,-1,1];
  w = data_box(x, y, bbox);

  distance = index = point = [];
  if(numberof(w)) {
    d = sqrt((x(w)-spot(1))^2 + (y(w)-spot(2))^2);
    if(d(min) <= radius) {
      distance = d(min);
      index = w(d(mnx));
      point = data(index);
      nx = x(d(mnx));
      ny = y(d(mnx));
    }
  }

  return save(point, index, distance, spot, x=nx, y=ny);
}
