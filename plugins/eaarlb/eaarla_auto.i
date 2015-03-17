hook_add, "plugins_load", "hook_plugins_load_eaarla";
hook_add, "plugins_load_post", "hook_plugins_load_post_eaarla";

// All EAARL plugin hook functions should have the naming convention
//    hook_eaarlX_<hook name>
// where X is the EAARL revision (A, B, etc.). This allows hook functions to be
// auto-detected. The sole exception to this is the plugin hooks, which are the
// ones driving the loading (we don't want it to recurse into itself).

func hook_plugins_load_eaarla(env) {
  if(env.name != "eaarla") return env;

  extern CHANNEL_COUNT;
  CHANNEL_COUNT = 3;

  // 16 is the magic constant for interpreted functions
  f = symbol_names(16);
  w = where(strpart(f, :12) == "hook_eaarla_");
  hooks = f(w);

  for(i = 1; i <= numberof(hooks); i++)
    hook_add, strpart(hooks(i), 13:), hooks(i);

  return env;
}

func hook_plugins_load_post_eaarla(env) {
  if(env.name != "eaarla") return env;

  set_depth_scale, units="meters", offset=5;

  extern camera_specs, camera_mounting_bias;
  camera_specs = ms4000_specs;
  camera_mounting_bias = ms4000_cir_bias_n111x;

  return env;
}

func hook_eaarla_chanconfobj_clear(env) {
  save, env, working=save(
    channels123=save(channels=[1,2,3])
  );
  return env;
}
