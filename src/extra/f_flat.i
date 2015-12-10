// This adds a new processing mode: f_flat
//
// This code is considered temporary and experimental.

default, f_flat_debug, 0;
default, f_flat_cluster_size, 10;
default, f_flat_cluster_adjacent, 1;
default, f_flat_aoi_max, 8;
default, f_flat_samples_min, 10;
default, f_flat_use_median, 1;

if(is_void(eaarl_processing_modes)) eaarl_processing_modes = save();
save, eaarl_processing_modes,
  f_flat=save(process="process_f_flat", cast="fs_struct_from_obj"),
  f_flat_dyn=save(process="process_f_flat", cast="processed_obj2dyn_dual");

hook_add, "jobs_env_wrap", "hook_jobs_f_flat";

func hook_jobs_f_flat(thisfile, env) {
  includes = env.env.includes;
  grow, includes, thisfile;
  save, env.env, includes;
  save, env.env.vars, f_flat_cluster_size, f_flat_cluster_adjacent,
    f_flat_aoi_max, f_flat_samples_min, f_flat_use_median;
  return env;
}
hook_jobs_f_flat = closure(hook_jobs_f_flat, current_include());

func process_f_flat(start, stop, ext_bad_att=, channel=, opts=) {
  sample_interval = 1.0;

  pulses = process_fs(start, stop, ext_bad_att=ext_bad_att, channel=channel,
    opts=opts);

  if(!is_obj(pulses) || !numberof(pulses.fx)) return [];

  // Calculate angle of incidence
  aoi = angle_of_incidence(pulses.fx, pulses.fy, pulses.fz,
      pulses.mx, pulses.my, pulses.mz);

  // Create clusters based on raster
  cluster = long(pulses.raster / f_flat_cluster_size);

  cnums = set_remove_duplicates(cluster);
  ccount = numberof(cnums);

  for(i = 1; i <= ccount; i++) {
    cnum = cnums(i);

    // Indices to points we want to update
    wu = where(cluster == cnum);

    // Indices to reference points used to calculate the new surface elevation
    if(f_flat_cluster_adjacent) {
      wr = where(
          cnum-f_flat_cluster_adjacent <= cluster &
          cluster <= cnum+f_flat_cluster_adjacent
          );
    } else {
      wr = wu;
    }

    // Reduce wr to those points with aoi <= aoi_max
    w = where(aoi(wr) <= f_flat_aoi_max);
    // Make sure we have enough sample points
    if(numberof(w) < f_flat_samples_min) continue;
    wr = wr(w);

    // Calculate a new surface elevation
    if(f_flat_use_median)
      fz = median(pulses.fz(wr));
    else
      fz = pulses.fz(wr)(avg);

    // For each point, calculate a new value for frx, fx, fy, and fs_slant_range
    // z-distance between mirror and new surface, and ratio of new/old
    dz = pulses.mz(wu) - fz;
    ratio = dz / (pulses.mz(wu) - pulses.fz(wu));
    // Corresponding x- and y-distances
    dx = (pulses.mx(wu) - pulses.fx(wu)) * ratio;
    dy = (pulses.my(wu) - pulses.fy(wu)) * ratio;
    // Corresponding points
    fx = pulses.mx(wu) - dx;
    fy = pulses.my(wu) - dy;
    // Calculate new slant range
    fs_slant_range = (dx*dx + dy*dy + dz*dz)^0.5;
    // Change in slant range
    dslant = pulses.fs_slant_range(wu) - fs_slant_range;
    // Update frx
    frx = pulses.frx(wu) - (dslant/NS2MAIR/sample_interval);

    // Store changed values
    pulses.fx(wu) = fx;
    pulses.fy(wu) = fy;
    pulses.fz(wu) = fz;
    pulses.frx(wu) = frx;
    pulses.fs_slant_range(wu) = fs_slant_range;
  }

  return pulses;
}

func eaarl_f_flat(action) {
  if(action == "f_replace") {
    save, eaarl_processing_modes.f, process="process_f_flat";
    save, eaarl_processing_modes.f_dyn, process="process_f_flat";
  } else if(action == "f_original") {
    save, eaarl_processing_modes.f, process="process_fs";
    save, eaarl_processing_modes.f_dyn, process="process_fs";
  } else {
    error, "try f_replace or f_original";
  }
}
