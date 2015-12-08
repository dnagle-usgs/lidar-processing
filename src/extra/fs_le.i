// This set of hacks is intended to support exploration of whether a leading
// edge tracker can usefully supplement the centroid algorithm for first
// returns.

// This uses a bunch of global constants, because it's a hack...

// If the maximum intensity value of the first 12 samples is greater than this
// threshold, centroid is used. If it's less than or equal to this threshold,
// leading edge is used. If you want to always use centroid, set this to 0. If
// you always want to use leading edge, set this to 10000. (The max length of a
// waveform is 450 samples. If a waveform is saturated, then 20 * number of
// saturated pixels is added to intensity. Max intensity is normally 255. 255 +
// 450 * 20 = 9255. This makes 10000 a safe sentinel value.)
default, fs_le_thresh_cent, 15;

// For leading edge, the first derivative has to exceed this threshold to be
// detected as a leading edge. This should always be >= 1.
default, fs_le_thresh_deriv, 1;

// How many samples afer the leading edge should be summed? This should always
// be >= 1.
default, fs_le_samples_sum, 3;

// What threshold should be used for the intensity sum? The sample sum must
// exceed this value to be considered valid.
default, fs_le_intensity_sum_thresh, 8;

// Enable debugging output
default, fs_le_debug, 0;

hook_add, "jobs_env_wrap", "hook_jobs_fs_le";

func hook_jobs_fs_le(thisfile, env) {
  extern fs_le_thresh_cent, fs_le_thresh_deriv;
  includes = env.env.includes;
  grow, includes, thisfile;
  save, env.env, includes;
  save, env.env.vars, fs_le_thresh_cent, fs_le_thresh_deriv,
    fs_le_samples_sum, fs_le_intensity_sum_thresh;
  return env;
}
hook_jobs_fs_le = closure(hook_jobs_fs_le, current_include());

func hook_eaarl_fs_le(env) {
  // Hacky: make original fs_rx available for later use.
  save, env, fs_rx_orig=env.fs_rx;
  save, env, fs_rx=eaarl_fs_rx_channel_le;
  return env;
}

func eaarl_fs_rx_channel_le(pulses) {
  // Start by using the normal fs_rx
  fs_rx_orig, pulses;

  // Find pulses that need to be revised with leading edge
  frx = pulses.frx;
  fintensity = pulses(*,"fintensity") ? pulses.fintensity : pulses.fint;
  w = where(fintensity <= fs_le_thresh_cent & fintensity > 0);

  // Hack: Flip the intensity to negative to designated it as a centroid return
  fintensity = min(0, -fintensity);

  nw = numberof(w);
  if(fs_le_debug >= 2) {
    write, format="FS_LE: %d of %d points fail centroid\n",
      numberof(w), numberof(frx);
  }
  if(!nw) return;

  applied_fs_le = array(char(0), numberof(frx));
  for(i = 1; i <= nw; i++) {
    j = w(i);
    if(fs_le_debug >= 2) {
      write, format="FS_LE: raster %d pulse %d channel %d\n",
        pulses.raster(j), pulses.pulse(j), pulses.fchannel(j);
    }

    // Retrieve wf, flip and remove bias
    rx = *pulses.rx(pulses.fchannel(j),j);
    wf = short(~rx);
    wf -= wf(1);

    // First derivative
    wfd1 = wf(dif);

    // Truncate first deriviative to first 12 samples
    if(numberof(wfd1) > 11) wfd1 = wfd1(:11);

    // Starts of leading edges where first derivative exceeds the threshold
    exceeds = (wfd1 >= fs_le_thresh_deriv);
    edges = where(exceeds(dif) == 1);
    if(numberof(edges))
      edges++;
    else
      edges = [];
    if(exceeds(1)) edges = grow([1], edges);

    if(fs_le_debug >= 2)
      write, format="FS_LE:   found %d leading edges\n", numberof(edges);
    if(!numberof(edges)) continue;

    // Iterate over the leading edges and find the first that has a sufficient
    // level of energy following it
    for(k = 1; k <= numberof(edges); k++) {
      le = edges(k);
      start = le+1;
      stop = le+fs_le_samples_sum;
      if(stop > numberof(wf)) {
        if(fs_le_debug >= 2) {
          write, format="FS_LE:   edge %d at sample %d: aborting, wf too short\n",
            k, le;
        }
        break;
      }
      lesum = wf(start:stop)(sum);
      if(fs_le_debug >= 2) {
        write, format="FS_LE:   edge %d at sample %d; sum %d\n",
          k, le, lesum;
      }
      if(lesum > fs_le_intensity_sum_thresh) {
        applied_fs_le(j) = 1;
        frx(j) = le;
        fintensity(j) = lesum;
        if(fs_le_debug >= 2)
          write, format="FS_LE:     ^^ passed threshold, updated surface%s", "\n";
        break;
      }
    }
  }
  if(fs_le_debug) {
    write, format="FS_LE: Summary: Looked at %d points\n", numberof(frx);
    write, format="FS_LE: Summary:   %d failed cent thresh\n", nw;
    write, format="FS_LE: Summary:   %d updated using le\n",
      numberof(where(applied_fs_le));
  }

  save, pulses, frx, applied_fs_le;
  if(pulses(*,"fintensity")) {
    save, pulses, fintensity;
  } else {
    save, pulses, fint=fintensity;
  }
}

func eaarl_fs_le(action) {
/* DOCUMENT
  eaarl_fs_le, "enable";
  eaarl_fs_le, "disable";
  eaarl_fs_le, "status";

  Enables, disables, or gives the status of the leading edge hacks for fs
  processing.
*/
  if(action == "enable") {
    hook_add, "process_fs_funcs", "hook_eaarl_fs_le";
    write, "leading edge hacks ENABLED";
  } else if(action == "disable") {
    hook_remove, "process_fs_funcs", "hook_eaarl_fs_le";
    write, "leading edge hacks DISABLED";
  } else if(action == "status") {
    hooks = hook_query("process_fs_funcs");
    if(anyof(hooks == "hook_eaarl_fs_le")) {
      if(!am_subroutine()) return 1;
      write, "fs processing currently IS using leading edge hacks";
    } else {
      if(!am_subroutine()) return 0;
      write, "fs processing currently IS NOT using leading edge hacks";
    }
  } else {
    write, "Invalid parameter given. Can be invoked only in these ways:\n   eaarl_fs_le, \"enable\";\n   eaarl_fs_le, \"disable\";\n   eaarl_fs_le, \"status\";";
  }
}

func eaarl_fs_plot_le(raster, pulse, channel=, win=) {
/* DOCUMENT eaarl_fs_plot_le, raster, pulse, channel=, win=
  Plots the FS result both with and without the fs_le hacks. Without is in
  blue, with is in red. (If only red is visible, that means they agreed.)

  Wraps around eaarl_fs_plot; see that for parameter details.
*/
  enabled = eaarl_fs_le("status");

  eaarl_fs_le, "disable";
  eaarl_fs_plot, raster, pulse, channel=channel, win=win, xfma=1, color="blue";

  eaarl_fs_le, "enable";
  eaarl_fs_plot, raster, pulse, channel=channel, win=win, xfma=0, color="red";

  if(!enabled) eaarl_fs_le, "disable";
}
