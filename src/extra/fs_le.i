// This set of hacks is intended to support exploration of whether the leading
// edge tracker can usefully supplement the centroid algorithm for first
// returns.

// This uses two global constants, because it's a hack

// If the maximum intensity value of the first 12 samples is greater than this
// threshold, centroid is used. If it's less than or equal to this threshold,
// leading edge is used. If you want to always use centroid, set this to 0. If
// you always want to use leading edge, set this to 10000. (The max length of a
// waveform is 450 samples. If a waveform is saturated, then 20 * number of
// saturated pixels is added to intensity. Max intensity is normally 255. 255 +
// 450 * 20 = 9255. This makes 10000 a safe sentinel value.)
fs_le_thresh_cent = 15;

// For leading edge, the first derivative has to exceed this threshold to be
// detected as a leading edge. This should always be >= 1.
fs_le_thresh_deriv = 1;

hook_add, "jobs_env_wrap", "hook_jobs_fs_le";

func hook_jobs_fs_le(thisfile, env) {
  extern fs_le_thresh_cent, fs_le_thresh_deriv;
  includes = env.env.includes;
  grow, includes, thisfile;
  save, env.env, includes;
  save, env.env.vars, fs_le_thresh_cent, fs_le_thresh_deriv;
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
  nw = numberof(w);
  if(!nw) return;

  for(i = 1; i <= nw; i++) {
    j = w(i);

    // Retrieve wf, flip and remove bias
    rx = *pulses.rx(pulses.fchannel(j),j);
    wf = short(~rx);
    wf -= wf(1);

    // Truncate to 12
    np = min(numberof(wf),12);
    wf = wf(:np);

    // First derivative
    wfd1 = wf(dif);

    // Starts of leading edges where first derivative exceeds the threshold
    edges = where((wfd1 >= fs_le_thresh_deriv)(dif) == 1);

    if(!numberof(edges)) continue;

    // Pick first leading edge and find its peak
    start = edges(1)+1;
    stop = numberof(edges) > 1 ? edges(2) : np-1;
    wneg = where(wfd1(start:stop) < 0);
    if(numberof(wneg)) {
      frx(j) = edges(1) + wneg(1);
    }
  }

  save, pulses, frx;
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
      write, "fs processing currently IS using leading edge hacks";
    } else {
      write, "fs processing currently IS NOT using leading edge hacks";
    }
  } else {
    write, "Invalid parameter given. Can be invoked only in these ways:\n   eaarl_fs_le, \"enable\";\n   eaarl_fs_le, \"disable\";\n   eaarl_fs_le, \"status\";";
  }
}
