// vim: set ts=2 sts=2 sw=2 ai sr et:

func rcf_triag_filter(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=, plottriag=, plottriagwin=, prefilter_min=, prefilter_max=, distthresh=, datawin=, wfs=, plottriagpal=) {
/* DOCUMENT rcf_triag_filter(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=)
 this function splits data sets into manageable portions and calls ircf_eaarl_pts that
uses the random consensus filter (rcf) and triangulation method to filter data.

 amar nayegandhi April 2004.

  INPUT:
  eaarl : data array to be filtered.
  buf = buffer size in CENTIMETERS within which the rcf block minimum filter will be implemented (default is 500cm).
  w   = block minimum elevation width (vertical extent) in CENTIMETERS of the filter (default is 20cm)
  no_rcf = minimum number of 'winners' required in each buffer (default is be).
  mode =
  mode = "fs" //for first surface
  mode = "ba" //for bathymetry
  mode = "be" // for bare earth vegetation
  (default mode = 3)
  fbuf = buffer size in METERS for the initial RCF to remove the "bad" outliers. Default = 100m
  fw = window size in METERS for the initial RCF to remove the "bad" outliers. Default = 25m
  tw = triangulation vertical range in centimeters Default = w
  interactive = set to 1 to allow interactive mode.  The user can delete triangulated facets
      with mouse clicks in the triangulated mesh.
  tai = number of 'triangulation' iterations to be performed. Default = 3;
  plottriag = set to 1 to plot resulting triangulations for each iteration (default = 0)
  plottriagwin = windown number where triangulations should be plotted (default = 0)
  plottriagpal = palette to use for the triangulation window
  distthresh = distance threshold that defines the max length of any side of a triangle
    (default: 100m) set to 0 if you don't want to use it.
  datawin = window number where unfiltered data is plotted (when interactive=1)
  OUTPUT:
   rcf'd data array of the same type as the 'eaarl' data array.

*/
// This function is kept primarily for backwards compatibility.
  default, mode, "be";
  default, distthresh, 200;
  default, datawin, 5;

  // if data array is in raster format (R, GEOALL, VEGALL), then covert to
  // non raster format (FS, GEO, VEG).
  test_and_clean, eaarl;

  //crop region to within user-specified elevation limits
  if(!is_void(prefilter_min) || !is_void(prefilter_max))
    eaarl = filter_bounded_elv(unref(eaarl), lbound=prefilter_min,
      ubound=prefilter_max, mode=mode);

  return ircf_eaarl_pts(eaarl, buf=buf, w=w, mode=mode,
    no_rcf=no_rcf, fbuf=fbuf, fw=fw, tw=tw, interactive=interactive,
    tai=tai, plottriag=plottriag, plottriagwin=plottriagwin,
    plottriagpal=plottriagpal);
}

func ircf_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=, plottriag=, plottriagwin=, plottriagpal=, autoreducetw=) {
/* DOCUMENT ircf_eaarl_pts(eaarl, buf=, w=, mode=, no_rcf=, fbuf=, fw=, tw=, interactive=, tai=)
 this function uses the random consensus filter (rcf) and triangulation method to filter data.

 amar nayegandhi Jan/Feb 2004.

  INPUT:
  eaarl : data array to be filtered.
  buf = buffer size in CENTIMETERS within which the rcf block minimum filter will be implemented (default is 500cm).
  w   = block minimum elevation width (vertical extent) in CENTIMETERS of the filter (default is 20cm)
  no_rcf = minimum number of 'winners' required in each buffer (default is 3).
  mode =
  mode = 1; //for first surface
  mode = 2; //for bathymetry
  mode = 3; // for bare earth vegetation
  (default mode = 3)
  fbuf = buffer size in METERS for the initial RCF to remove the "bad" outliers. Default = 100m
  fw = window size in METERS for the initial RCF to remove the "bad" outliers. Default = 25m
  tw = triangulation vertical range in centimeters Default = w
  interactive = set to 1 to allow interactive mode.  The user can deleted triangulated facets
      with mouse clicks in the triangulated mesh.
  tai = number of 'triangulation' iterations to be performed. Default = 3;
  plottriag = set to 1 to plot resulting triangulations for each iteration (default = 0)
  plottriagwin = windown number where triangulations should be plotted (default = 0)
  plottriagpal = palette to use for plottriagwin (default: no palette command issued)
  OUTPUT:
   rcf'd data array of the same type as the 'eaarl' data array.

*/
  default, mode, 3;
  default, fw, 25;     // 25m
  default, fbuf, 25;   // 25m
  default, buf, 500;   // 500cm
  default, w, 20;      // 20cm
  default, tw, w;
  default, no_rcf, 3;  // 3 points
  default, tai, 3;
  default, autoreducetw, 0;
  default, plottriagwin, 0;
  default, plottriagpal, "";

  wbkp = current_window();
  t0 = array(double, 3);
  timer, t0;

  // PRELIMINARIES....

  // if data array is in raster format (R, GEOALL, VEGALL), then covert to
  // non raster format (FS, GEO, VEG).
  test_and_clean, eaarl;

  write, format="RCF'ing data set with window size = %d, and elevation width = %d meters...\n", fbuf, fw;

  // Get rid of the really bad outliers
  eaarl = rcf_filter_eaarl(eaarl, buf=fbuf*100, w=fw*100, mode=mode);

  if(is_void(eaarl))
    return;

  // END OF PRELIMINARIES
  // The eaarl variable now holds our overall dataset; we want to run IRCF on
  // it. From this point on, we won't modify eaarl until the end. So... split
  // out its xyz coordinates for ease of access.
  data2xyz, eaarl, x, y, z, mode=mode;

  // mf is a boolean array for points that have been manually removed. Only
  // used in interactive mode.
  mf = array(short(0), numberof(eaarl));

  // maybe is a boolean array for points that haven't yet passed any tests
  maybe = array(short(1), numberof(eaarl));

  // -- our good data is where(!mf & !maybe)

  // Now figure out which points fail the normal RCF params and convert them
  // to maybes.
  w = rcf_filter_eaarl([x,y,z], buf=buf, w=w, n=no_rcf, idx=1);
  if(numberof(w)) {
    maybe(w) = 0;
  }

  done = 0; // set done to 0 to continue interactive mode

  // tai = number of triangulation iterations to perform
  for (ai = 1; ai <= tai; ai++) {
    write, format="Iteration number %d of %d...\n", ai, tai;

    if(autoreducetw) {
      if(ai > 1)
        tw = tw - tw*((ai-1)/(2.0*tai-2.5));
      write, format="Using tw of %f\n", tw;
    }

    // Want to test skipped points
    if(noneof(maybe)) {
      // No points left to consider!!
      continue;
    }

    // Triangulate good points
    good = where(!mf & !maybe);
    v = good(triangulate_data([x(good),y(good),0], maxside=distthresh, verbose=0));
    good = [];

    mfcount = numberof(where(mf));
    if(interactive)
      ircf_interactive_mode, x, y, z, maybe, mf, win=plottriagwin,
        pal=plottriagpal;

    if (plottriag)
      plot_triag_mesh, [x,y,z], v, win=plottriagwin, resetlimits=1, showcbar=1, dofma=1;

    if(mfcount != numberof(where(mf))) {
      // Exclude mf points from maybe
      maybe &= !mf;
      // Retriangulate
      good = where(!mf & !maybe);
      v = good(triangulate_data([x(good),y(good),0], maxside=distthresh, verbose=0));
      good = [];
    }

    if (plottriag)
      plot_triag_mesh, [x,y,z], v, win=plottriagwin, resetlimits=1, showcbar=1, dofma=1;

    // Check each maybe point to see if it fits the tin
    w = where(maybe);
    pz = triangle_interp(x, y, z, v, x(w), y(w));

    // Anything that's within tw is no longer a maybe... it's a good! So
    // update maybe to only point to things that are still out of bounds.
    maybe(w) = abs(pz - z(w)) > tw;

    write, format="%d points added this iteration.\n",
      numberof(w) - numberof(where(maybe));
  }

  timer_finished, t0, fmt="Total time taken to filter this section: ELAPSED\n";
  window_select, wbkp;

  return eaarl(where(!mf & !maybe));
}

func ircf_interactive_prompt(question) {
/* DOCUMENT used by ircf_interactive_mode */
  answer = "";
  valid = regsub("]([^][]*)\\[", regsub("][^]]*$",
      regsub("^[^[]*\\[", question, all=1), all=1), all=1);
  if(valid)
    valid = "[" + valid + "]";
  else
    valid = "*";
  do {
    read, prompt=question, answer;
    answer = strlower(strpart(strtrim(answer), 1:1));
  } while(!strglob(valid, answer));
  return answer;
}

func ircf_interactive_mode(x, y, z, maybe, &mf, win=, pal=, elvbuf=) {
/* DOCUMENT used by ircf_eaarl_pts */
  local v;

  // Local constant
  default, elvbuf, 2;
  default, win, window();
  default, pal, "";

  window, win;
  if(pal != "")
    palette, pal;

  answer = ircf_interactive_prompt("Interactive mode? [y]es or [n]o: ");
  if(answer == "n")
    return;

  // Force an initial ctrl-left click to initialize vertices and to plot the
  // triangulation.
  m = 41;

  show_prompt = 1;
  while (1) {
    // ctrl-left -- re-triangulate
    if(mouse_click_is("ctrl-left", m)) {
      good = where(!mf & !maybe);
      if(!numberof(good)) {
        error, "All points have been eliminated! Uh oh...";
      } else {
        v = good(triangulate_data([x(good),y(good),0], maxside=distthresh,
          verbose=0));
      }
      good = [];
      plot_triag_mesh, [x,y,z], v, showcbar=1, dofma=1;
    }

    // left click -- manually remove points
    if(mouse_click_is("left", m)) {
      tr = locate_triag_surface(x, y, z, v, m=m, plot=1, idx=1);
      if(is_void(tr))
        write, "No points selected...";
      else
        mf(tr) = 1;
    }

    // ctrl-right -- end
    if(mouse_click_is("ctrl-right", m))
      return;

    // center click -- pan/zoom mode
    if(mouse_click_is("center", m)) {
      answer = ircf_interactive_prompt(
        "Continue interactive mode? [y]es or [n]o: ");
      if(answer == "n")
        return;
      show_prompt = 1;
    }

    // right click -- select similar
    if(mouse_click_is("right", m)) {
      tr = locate_triag_surface(x, y, z, v, win=plottriagwin, m=m, plot=1);
      if(is_void(tr)) {
        write, "No points selected..."
      } else {
        maxpt = tr(3,max);

        good = where(!mf & !maybe);
        idx = good(filter_bounded_elv([x,y,z](good,), lbound=maxpt-elvbuf/2.,
          ubound=maxpt+elvbuf/2., idx=1));
        good = [];

        if(is_void(idx)) {
          write, "No points selected..."
        } else {
          plmk, y(idx), x(idx), marker=4, msize=0.2, color="blue";

          do {
            rmanswer = ircf_interactive_prompt(
              "Remove selected point? [y]es, [n]o, [s]pecify subregion: ");

            if(rmanswer == "s") {
              a = mouse(1,1, "Drag box to select region...");
              rxmn = a([1,3])(min);
              rxmx = a([1,3])(max);
              rymn = a([2,4])(min);
              rymx = a([2,4])(max);

              plmk, y(idx), x(idx), marker=4, msize=0.2, color="green";
              idx = idx(data_box(x(idx), y(idx), rxmn, rxmx, rymn, rymx));
              plmk, y(idx), x(idx), marker=4, msize=0.2, color="blue";
            }
          } while(rmanswer == "s");

          if (rmanswer == "y" && numberof(idx) >= 100) {
            rmanswer = ircf_interactive_prompt(swrite(format=
              "Too many points selected (%i)! Continue anyway? [y]es/[n]o: ",
              numberof(idx)));
          }
          if(rmanswer == "y") {
            write, format="Removed %d points.\n", numberof(idx);
            mf(idx) = 1;
          }
          show_prompt = 1;
        }
      }
    }

    if(show_prompt) {
      show_prompt = 0;
      write, "";
      write, format=" Mouse controls, using window %d:\n", win;
      write, "  left . . . . Remove triangle";
      write, "  middle . . . Enter pan/zoom mode";
      write, "  right. . . . Remove points of similar elevation";
      write, "  ctrl-left. . Retriangulate and replot";
      write, "  ctrl-right . End interactive mode";
    }
    window, win;
    m = mouse(1, 0, "");
  }
}
