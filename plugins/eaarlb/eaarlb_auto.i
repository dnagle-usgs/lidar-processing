hook_add, "plugins_load", "hook_plugins_load_eaarlb";

func hook_plugins_load_eaarlb(env) {
  if(env.name != "eaarlb") return env;

  extern CHANNEL_COUNT;
  CHANNEL_COUNT = 4;

  hook_add, "pcr_channel", "hook_eaarlb_pcr_channel";
  hook_add, "bathy_detect_surface", "hook_eaarlb_bathy_detect_surface";

  return env;
}

func hook_eaarlb_pcr_channel(env) {
  if(env.forcechannel == 4) save, env, forcechannel=2;
  return env;
}

func hook_eaarlb_bathy_detect_surface(env) {
  if(env.forcechannel == 4) save, env, wantlen=17;
  return env;
}
