hook_add, "plugins_load", "hook_plugins_load_eaarla";

func hook_plugins_load_eaarla(env) {
  if(env.name != "eaarla") return env;

  // set up eaarla hooks

  return env;
}
