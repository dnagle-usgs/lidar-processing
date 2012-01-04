// vim: set ts=2 sts=2 sw=2 ai sr et:

func triangulate_data(data, mode=, verbose=, maxside=, maxarea=, minangle=) {
/* DOCUMENT v = triangulate_data(data, mode=, verbose=, maxside=, maxarea=,
  minangle=)

  Given data, this will create a triangulation for it.

  NOTE: This function requires C-ALPS.

  Parameter:
    data: An array of data that data2xyz can handle.
  General options:
    mode= The mode of the data for data2xyz.
    verbose= Passed to triangulate; see its documentation for details.
  Constraint options:
    maxside= Specifies the maximum size permissible for a side of a triangle.
      Triangles with a side larger are discarded. Zero and negative values
      explicitly disable this option. Length in meters.
    maxarea= Specifies the maximum size permissible for triangles; larger
      triangles are discarded. Zero and negative values explicitly disable
      this option. Area in square meters.
    minangle= Specifies the smallest permissible angle allowed for triangles;
      triangles with smaller angles are discarded. Zero and negative values
      explicitly disable this option. Angle in degrees.
*/
  local x, y, z;
  default, verbose, 1;

  data2xyz, data, x, y, z;
  uniq = uniq_data(data, mode=mode, idx=1, forcexy=1);

  v = uniq(triangulate(x(uniq), y(uniq), verbose=verbose));

  if(maxside && maxside > 0)
    v = filter_trimesh_maxside(data, v, maxside, mode=mode);
  if(maxarea && maxarea > 0)
    v = filter_trimesh_maxarea(data, v, maxarea, mode=mode);
  if(minangle && minangle > 0)
    v = filter_trimesh_minangle(data, v, minangle, mode=mode);

  return v;
}

func plot_triag_mesh(data, v, mode=, edges=, win=, cmin=, cmax=, dofma=, showcbar=, restore_win=, resetlimits=) {
/* DOCUMENT plot_triag_mesh, data, v, mode=, edges=, win=, cmin=, cmax=, dofma=,
  showcbar=, restore_win=

  Plots a triangular mesh.

  Parameters:
    data: An array of data that data2xyz can handle.
    v: An array of vertices for the triangles.
  Options:
    mode= The mode of the data for data2xyz.
    edges= Whether or not to plot the edges of the triangles.
        edges=0  Do not plot edges (default)
        edges=1  Plot the edges
    win= Window to plot in; defaults to current window
    cmin= Colorbar minimum value. Defaults to the minimum z value.
    cmax= Colorbar maximum value. Defaults to the maximum z value.
    dofma= Whether to clear the plot first.
        dofma=1  Clear before plotting (default)
        dofma=0  Do not clear
    showcbar= Whether to plot a colorbar as well.
        showcbar=0  Do not plot colorbar (default)
        showcbar=1  Plot colorbar
    restore_win= After this is done, which window should be the current
      window?
        restore_win=0  Leaves window() set to win= (default)
        restore_win=1  Restores window() to what it was prior to this

  SEE ALSO: triangulate
*/
// original amar nayegandhi 01/09/04
  default, win, window();
  default, edges, 0;
  default, dofma, 1;
  default, showcbar, 0;
  default, restorewin, 0;
  default, resetlimits, 0;

  local x, y, z, v1, v2, v3;
  // Extract xyz and vertice information into a usable format
  data2xyz, data, x, y, z, mode=mode;
  splitary, v, 3, v1, v2, v3;
  data = v = [];

  // Juggle the coordinates into a format the plfp likes
  xx = transpose(x([v1,v2,v3]))(*);
  yy = transpose(y([v1,v2,v3]))(*);

  zz = z([v1,v2,v3]);
  default, cmin, min(zz);
  default, cmax, max(zz);

  // For each triangle, we use the average of its vertex elevations
  zz = zz(,sum)/3.;

  n = array(short(3), numberof(zz));

  wbkp = current_window();
  window, win;
  if(dofma)
    fma;
  plfp, zz, yy, xx, n, edges=edges, cmin=cmin, cmax=cmax;
  if(showcbar)
    colorbar, cmin, cmax, units="m";
  if(resetlimits) {
    limits, square=1;
    limits;
  }
  if(restore_win)
    window_select, wbkp;
}

func locate_triag_surface(x, y, z, v, win=, m=, plot=, idx=) {
/* DOCUMENT locate_triag_surface(xyz, v, win=, m=, plot=, idx=)
  locate_triag_surface(x, y, z, v, win=, m=, plot=, idx=)
  Locates the triangle in the mesh that contains a given point.

  Parameters:
    xyz: A 3xN or Nx3 array of points.
    v: A 3xN or Nx3 array of indexes into xyz representing vertices of
      triangles.
  Options:
    win= The window to use, if needed. Defaults to current window.
    m= The [x,y] coordinate to locate. If not given, you will be prompted to
      click on the window to locate it.
    plot= Use plot=1 to draw the triangle that is found.
    idx= Return the indices into xyz for the triangle found.
*/
// original amar nayegandhi 01/09/04.
// revised David Nagle 2010-02-12
  local v1, v2, v3;
  if(is_void(z)) {
    splitary, y, 3, v1, v2, v3;
    splitary, (x), 3, x, y, z;
  } else {
    splitary, v, 3, v1, v2, v3;
    v = [];
  }

  default, plot, 0;

  if(is_void(m) || plot) {
    default, win, window();
    window, win;
  }
  if(is_void(m)) m = mouse();

  in = in_triangle(x(v1), y(v1), x(v2), y(v2), x(v3), y(v3), m(1), m(2));
  if(noneof(in))
    return [];

  w = where(in)(1);
  tv = [v1(w), v2(w), v3(w)];
  tx = x(tv);
  ty = y(tv);
  tz = z(tv);

  if(plot) {
    plmk, ty, tx, marker=5, msize=0.3, color="red";
    plg, ty([1,2,3,1]), tx([1,2,3,1]), color="red";
  }

  if(idx)
    return tv;
  else
    return transpose([tx,ty,tz]);
}

func filter_trimesh_maxarea(data, v, thresh, mode=) {
/* DOCUMENT v = filter_trimesh_maxarea(data, v, thresh, mode=)
  Given a triangulation for data, this eliminates triangles with an area over
  the given threshold. The threshold is in square meters.
*/
  local x, y, v1, v2, v3;
  data2xyz, data, x, y, mode=mode;
  splitary, v, 3, v1, v2, v3;
  data = v = [];

  areas = triangle_areas(x(v1), y(v1), x(v2), y(v2), x(v3), y(v3));
  w = where(areas <= thresh);

  if(!numberof(w))
    return [];

  return [v1(w), v2(w), v3(w)];
}

func filter_trimesh_maxside(data, v, thresh, mode=) {
/* DOCUMENT v = filter_trimesh_maxside(data, v, thresh, mode=)
  Given a triangulation for data, this eliminates triangles with a side whose
  length is over the given threshold. The threshold is in meters.
*/
  local x, y, v1, v2, v3;
  data2xyz, data, x, y, mode=mode;
  splitary, v, 3, v1, v2, v3;
  data = v = [];

  l12 = ppdist([x(v1),y(v1)], [x(v2),y(v2)], tp=1);
  l13 = ppdist([x(v1),y(v1)], [x(v3),y(v3)], tp=1);
  l23 = ppdist([x(v2),y(v2)], [x(v3),y(v3)], tp=1);
  w = where(l12 <= thresh & l13 <= thresh & l23 <= thresh);

  if(!numberof(w))
    return [];

  return [v1(w), v2(w), v3(w)];
}

func filter_trimesh_minangle(data, v, thresh, mode=) {
/* DOCUMENT v = filter_trimesh_minangle(data, v, thresh, mode=)
  Given a triangulation for data, this eliminates triangles with an angle
  whose size is under the given threshold. The threshold is in degrees.
*/
  local x, y, v1, v2, v3, a, b, c;
  data2xyz, data, x, y, mode=mode;
  splitary, v, 3, v1, v2, v3;
  data = v = [];

  a = ppdist([x(v1),y(v1)], [x(v2),y(v2)], tp=1);
  b = ppdist([x(v1),y(v1)], [x(v3),y(v3)], tp=1);
  c = ppdist([x(v2),y(v2)], [x(v3),y(v3)], tp=1);

  aa = a*a;
  bb = b*b;
  cc = c*c;

  // Calculate the angles
  A = acos((bb+cc-aa)/(2*b*c));
  B = acos((aa+cc-bb)/(2*a*c));
  C = acos((aa+bb-cc)/(2*a*b));

  thresh *= DEG2RAD;

  w = where(A >= thresh & B >= thresh & C >= thresh);

  if(!numberof(w))
    return [];

  return [v1(w), v2(w), v3(w)];
}
