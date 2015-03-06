hook_add, "plugins_load", "hook_plugins_load_eaarlb";

func hook_plugins_load_eaarlb(env) {
  if(env.name != "eaarlb") return env;

  // set up eaarlb hooks

  return env;
}
