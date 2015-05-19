// This adds a new processing mode: b_stats
//
// This processing mode is a wrapper around the bathy processing algorithm
// (mode b) that adds four additional fields to the output: skew, auc, stdev,
// and peak. It also returns data in a dynamic DYN_PC_DUAL structure instead of
// GEO.
//
// This code is considered temporary and experimental. The output it generates
// may not work in some areas of ALPS.

if(is_void(eaarl_processing_modes)) eaarl_processing_modes = save();
save, eaarl_processing_modes,
  b_stats=save(process="process_b_stats", cast="processed_obj2dyn_dual");

hook_add, "jobs_env_wrap", "hook_jobs_b_stats";

func hook_jobs_b_stats(thisfile, env) {
  includes = env.env.includes;
  grow, includes, thisfile;
  save, env.env, includes;
  return env;
}
hook_jobs_b_stats = closure(hook_jobs_b_stats, current_include());

func process_b_stats(start, stop, ext_bad_att=, channel=, opts=) {
  pulses = process_ba(start, stop, ext_bad_att=ext_bad_att, channel=channel,
    opts=opts);

  if(!is_obj(pulses) || !numberof(pulses.fx)) return [];

  npulses = numberof(pulses.fx);
  skew = auc = stdev = peak = array(double, npulses);
  for(i = 1; i <= npulses; i++) {
    if(!pulses.lchannel(i)) continue;
    if(pulses.lrx(i) <= 0) continue;
    if(!pulses.rx(pulses.lchannel(i),i)) continue;

    wf = *pulses.rx(pulses.lchannel(i),i);
    if(!numberof(wf)) continue;

    wf = float(~wf);
    bias = wf(1:min(15,numberof(wf)))(min);
    wf -= bias;
    wf = max(0, wf);

    // Constrain the waveform to just the area around the detected bottom.
    // Target range is +/- 30% of distance between surface and bottom, but
    // limit distance to the range [1,12].
    buf = max(1, min(12, 0.3 * (pulses.lrx(i) - pulses.frx(i))));
    r0 = max(1, long(pulses.lrx(i) - buf + .5));
    r1 = min(numberof(wf), long(pulses.lrx(i) + buf + .5));
    wf = wf(r0:r1);

    skew(i) = wf_skew(wf);
    auc(i) = wf_auc(wf);
    stdev(i) = wf_stdev(wf);
    peak(i) = wf(max);
  }

  save, pulses, skew, auc, stdev, peak;
  return pulses;
}
