hook_add, "plugins_load", "hook_plugins_load_eaarlb";
hook_add, "plugins_load_post", "hook_plugins_load_eaarlb_post";

// All EAARL plugin hook functions should have the naming convention
//    hook_eaarlX_<hook name>
// where X is the EAARL revision (A, B, etc.). This allows hook functions to be
// auto-detected. The sole exception to this is the plugin hooks, which are the
// ones driving the loading (we don't want it to recurse into itself).

func hook_plugins_load_eaarlb(env) {
  if(env.name != "eaarlb") return env;

  extern CHANNEL_COUNT;
  CHANNEL_COUNT = 4;

  // 16 is the magic constant for interpreted functions
  f = symbol_names(16);
  w = where(strpart(f, :12) == "hook_eaarlb_");
  hooks = f(w);

  for(i = 1; i <= numberof(hooks); i++)
    hook_add, strpart(hooks(i), 13:), hooks(i);

  return env;
}

func hook_plugins_load_post_eaarlb(env) {
  if(env.name != "eaarlb") return env;

  apply_depth_scale, units="meters", offset=-9;

  extern camera_specs, camera_mounting_bias;
  camera_specs = ge2040c_specs;
  camera_mounting_bias = ge2040c_n7793q_dummy;

  return env;
}

func hook_eaarlb_pcr_channel(env) {
  if(env.forcechannel == 4) save, env, forcechannel=2;
  return env;
}

func hook_eaarlb_chanconfobj_clear(env) {
  save, env, working=save(
    chn1=save(channels=1), 
    chn2=save(channels=2), 
    chn3=save(channels=3), 
    chn4=save(channels=4) 
  );
  return env;
}

func hook_eaarlb_vegconfobj_validate_defaults(env) {
  if(numberof(env.channels) == 1 && env.channels(1) == 3)
    save, env.defaults, max_samples=20;
  return env;
}

func hook_eaarlb_bathy_detect_surface(env) {
  if(env.forcechannel == 4) save, env, wantlen=17;
  return env;
}
