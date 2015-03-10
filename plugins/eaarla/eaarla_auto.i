hook_add, "plugins_load", "hook_plugins_load_eaarla";

func hook_plugins_load_eaarla(env) {
  if(env.name != "eaarla") return env;

  extern CHANNEL_COUNT;
  CHANNEL_COUNT = 3;

  hook_add, "chanconfobj_clear", "hook_eaarla_chanconfobj_clear";

  return env;
}

func hook_eaarla_chanconfobj_clear(env) {
  save, env, working=save(
    channels123=save(channels=[1,2,3])
  );
  return env;
}
