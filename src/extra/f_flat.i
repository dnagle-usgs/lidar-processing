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
  restore_if_exists, opts, start, stop, ext_bad_att, channel, opts;
  default, channel, 0;

  if(is_void(ops_conf))
    error, "ops_conf is not set";

  // Retrieve rasters
  if(is_integer(start)) {
    default, stop, start;
    pulses = decode_rasters(start, stop);
  } else if(is_obj(start)) {
    pulses = start;
  } else {
    error, "don't know how to handle input given for start";
  }

  // Throw away dropouts
  w = where(!pulses.dropout);
  if(!numberof(w)) return;
  if(numberof(w) < numberof(pulses.dropout))
    pulses = obj_index(pulses, w);

  // Adds ftx, frx, fintensity, fchannel, fbias
  eaarl_fs_ftx_frx, pulses, channel;

  // process_fs throws away bogus returns (frx=10000) at this point. They are
  // left in here so that they can be updated later with a synthetic surface.

  // Add fs_slant_range, fx, fy, fz, mx, my, mz
  eaarl_fs_vector, pulses;

  // Get rid of points with no slant range (that indicates no trajectory was
  // available)
  w = where(pulses.fs_slant_range);
  if(!numberof(w)) return;
  pulses = obj_index(pulses, w);

  // Now replace surfaces with synthetic ones...

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

    // Reduce wr to those points with valid frx...
    w = where(pulses.frx(wr) != 10000);
    if(!numberof(w)) continue;
    wr = wr(w);

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

    // Calculate how much the elevation changed
    dz = pulses.fz(wu) - fz;
    // Now use that to calculate the change in slant range
    dsr = pulses.fs_slant_range(wu) * dz / (pulses.mz(wu) - pulses.fz(wu));
    // Now convert that to ns and update frx
    pulses.frx(wu) = pulses.frx(wu) + dsr/NS2MAIR;
  }

  // Now call eaarl_fs_vector again to update values based on the new frx
  eaarl_fs_vector, pulses;

  // Get rid of points where mirror and surface are within ext_bad_att meters
  if(ext_bad_att) {
    w = where(pulses.mz - pulses.fz >= ext_bad_att);
    if(!numberof(w)) return;
    pulses = obj_index(pulses, w);
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
