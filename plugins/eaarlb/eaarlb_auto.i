hook_add, "plugins_load", "hook_plugins_load_eaarlb";
hook_add, "plugins_load_post", "hook_plugins_load_post_eaarlb";

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

  set_depth_scale, units="meters", offset=-9;

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

func hook_eaarlb_eaarl_ba_rx_wf(env) {
  eaarl_ba_bback, env.wf, env.result;
  return env;
}

func hook_eaarlb_mission_flights_auto_keys(env) {
  keys = env.keys;
  grow, keys, [
    "rgb dir",
    "nir dir"
  ];
  save, env, keys;
  return env;
}

func hook_eaarlb_mission_details_autolist(env) {
  key = env.key;
  path = env.path;
  if(key == "rgb dir")
    env, result=autoselect_rgb_dir(path, options=1);
  else if(key == "nir dir")
    env, result=autoselect_nir_dir(path, options=1);
  return env;
}

func hook_eaarlb_mission_flights_validate_fields(env) {
  save, env.fields,
    "rgb dir", save(
      "help", "The rgb directory contains RGB imagery acquired during the flight. This is usually a subdirectory in the flight directory named \"rgb\". This is optional and does not affect lidar processing.",
      required=0
    ),
    "nir dir", save(
      "help", "The nir directory contains NIR imagery acquired during the flight. This is usually a subdirectory in the flight directory named \"nir\". This is optional and does not affect lidar processing.",
      required=0
    );

  return env;
}
