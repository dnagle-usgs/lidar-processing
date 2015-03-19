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

func hook_eaarla_mission_flights_auto_keys(env) {
  keys = env.keys;
  grow, keys, [
    "rgb dir",
    "rgb file",
    "cir dir"
  ];
  save, env, keys;
  return env;
}

func hook_eaarla_mission_details_autolist(env) {
  key = env.key;
  path = env.path;
  if(key == "rgb dir")
    env, result=autoselect_rgb_dir(path, options=1);
  else if(key == "rgb file")
    env, result=autoselect_rgb_tar(path, options=1);
  else if(key == "cir dir")
    env, result=autoselect_cir_dir(path, options=1);
  return env;
}

func hook_eaarla_mission_flights_validate_fields(env) {
  save, env.fields,
    "rgb dir", save(
      "help", "The rgb directory contains RGB imagery acquired during the flight. This is usually a subdirectory in the flight directory named \"rgb\" or \"cam1\". This is optional and does not affect lidar processing.",
      required=0
    ),
    "rgb file", save(
      "help", "The rgb file is a tar file that contains RGB imagery acquired during the flight. It has the extension .tar and will usually have \"cam1\" in its filename.This is optional and does not affect lidar processing. This field is mutually exclusive with \"rgb dir\" and is generally found on older missions.",
      required=0
    ),
    "cir dir", save(
      "help", "The cir directory contains CIR imagery acquired during the flight. This is usually a subdirectory in the flight directory named \"cir\". This is optional and does not affect lidar processing.",
      required=0
    );

  return env;
}

func hook_eaarla_mission_flights_validate_post(env) {
  fields = env.fields;

  rgbd = fields("rgb dir");
  rgbf = fields("rgb file");
  if(rgbd(*,"val") && rgbf(*,"val")) {
    msg = "both \"rgb dir\" and \"rgb file\" are defined";
    if(rgbd.ok) {
      save, rgbd, ok=0, msg;
    } else {
      save, rgbd, msg=msg + ";" + rgbd.msg;
    }
    if(rgbf.ok) {
      save, rgbf, ok=0, msg;
    } else {
      save, rgbf, msg=msg + ";" + rgbf.msg;
    }
  }

  if(rgbd(*,"val") && rgbd.ok && !rgbf(*,"val")) {
    save, env, fields=obj_delete(fields, "rgb file");
  }

  return env;
}
