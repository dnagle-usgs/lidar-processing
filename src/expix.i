// vim: set ts=2 sts=2 sw=2 ai sr et:

func expix_pointcloud(vname, radius=, win=, mode=) {
/* DOCUMENT expix_pointcloud, "<vname>", radius=, win=, mode=
*/
  if(!is_string(vname)) error, "must provide vname as string";
  if(!symbol_exists(vname)) error, "variable "+vname+" does not exist";

  default, radius, 10.;
  default, win, 5;
  default, mode, "fs";

  local x, y;
  data = symbol_def(vname);
  if(is_void(data)) error, "variable "+vname+" contains no data";
  data2xyz, data, x, y, mode=mode;
  
  continue_interactive = 1;
  while(continue_interactive) {

    write, format="\nWindow %d: Left-click to examine a point. Anything else aborts.\n", win;

    window, win;
    spot = mouse(1, 1, "");

    if(mouse_click_is("left", spot)) {
      distance = index = point = [];
      bbox = spot([1,1,2,2]) + radius * [-1,1,-1,1];
      w = data_box(x, y, bbox);

      if(numberof(w)) {
        d = sqrt((x(w)-spot(1))^2 + (y(w)-spot(2))^2);
        if(d(min) <= radius) {
          distance = d(min);
          index = w(d(mnx));
          point = data(index);
          xp = x(index);
          yp = y(index);
        }
      }

      write, format="\n-----\n\n%s", "";
      if(is_void(point)) {
        write, format="Location clicked: %9.2f %10.2f\n", spot(1), spot(2);
        write, format="No point found within search radius (%.2fm).\n", radius;
      } else {
        expix_highlight, yp, xp;
        expix_show, save(vname, mode, spot, distance, index, point, xp, yp);
      }
    } else {
      continue_interactive = 0;
    }
  }
}

func expix_highlight(y, x) {
/* DOCUMENT expix_highligh_point, y, x;
  Plots an X at the specified location in the current window. Used to highlight
  the selected point.
*/
  plmk, y, x, msize=0.004, color="red",
    marker=[[0,1,0,1,0,-1,0,-1,0],[0,1,0,-1,0,-1,0,1,0]];
}

func expix_show(nearest) {
/* DOCUMENT expix_show, nearest;
  Shows output (on console and/or plots) for the selected point. This is
  somewhat generically written so that it can be used for other interactive
  frameworks (such as groundtruth analysis examination or transect analysis
  examination).

  NEAREST should be an oxy group object containing:
    spot - mouse() result where clicked
    mode - data mode ("fs", "be", "ba")
    vname - name of data variable used for look up
    index - index into data array of selected point
    point - point result, which is equivalent to symbol_def(vname)(index)
    distance - distance from point to click
    xp - x coordinate of point found
    yp - y coordinate of point found

  This invokes a hook: "expix_show". See source for details.
*/
  spot = nearest.spot;
  point = nearest.point;

  write, format="Location clicked: %.2f %.2f\n", spot(1), spot(2);
  write, format="   Nearest point: %.2f %.2f (%.2fm away)\n",
    nearest.xp, nearest.yp, nearest.distance;
  write, format="    first return: %.2f\n", point.elevation/100.;
  if(has_member(point, "lelv")) {
    write, format="     last return: %.2f\n", point.lelv/100.;
    write, format="    first - last: %.2f\n", (point.elevation-point.lelv)/100.;
  } else if(has_member(point, "depth")) {
    write, format="   bottom return: %.2f\n", (point.elevation+point.depth)/100.;
    write, format="  first - bottom: %.2f\n", -1 * point.depth/100.;
  }
  write, format="%s", "\n";
  write, format="Timestamp: %s\n", soe2iso8601(point.soe);
  write, format="soe= %.4f ; sod= %.4f\n", point.soe, soe2sod(point.soe);
  write, format="Corresponds to %s(%d)\n", vname, nearest.index;

  // Leaving units in cm because units don't matter, as long as they are
  // consistent.
  // calculate distance along surface plane from mirror point
  dist = sqrt(double(point.east-point.meast)^2 +
    double(point.north-point.mnorth)^2);
  // calculate elevation difference
  ht = abs(point.melevation - point.elevation);
  if(ht == 0) {
    write, format="%s\n", "Cannot calculate angle of incidence (0 height)";
  } else {
    // calculate angle of incidence
    aoi = atan(dist, ht) * RAD2DEG;
    write, format="Angle of incidence= %.4f degrees\n", aoi;
  }

  hook_invoke, "expix_show", save(nearest);
}
