// vim: set ts=2 sts=2 sw=2 ai sr et:

/* All general EAARL handlers should be defined in this file. The handler
 * functions should use the prefix "handler_eaarl_" to support auto-loading by
 * plugins.
 */

func handler_eaarl_mission_query_soe_rn(env) {
  flights = env.flights;
  rn = env.rn;

  flight = eaarl_mission_query_soe_rn(env.flights, env.soe, env.rn);
  if(is_string(flight)) env, match=flight;

  return env;
}

func handler_eaarl_mission_query_soe(env) {
  match = eaarl_mission_query_soe(env.soe);
  if(numberof(match)) env, match=match;
  return env;
}

func handler_eaarl_mission_load_soe_rn(env) {
  eaarl_mission_load_soe_rn, env.soe, env.rn;
  return env;
}

func handler_eaarl_mission_load_soe(env) {
  eaarl_mission_load_soe, env.soe;
  return env;
}

func handler_eaarl_mission_load(env) {
  eaarl_mission_load, env.flight;
  return env;
}

func handler_eaarl_mission_unload(env) {
  eaarl_mission_unload;
  return env;
}

func handler_eaarl_mission_wrap(env) {
  wrapped = eaarl_mission_wrap(env.cache_what);
  save, env, wrapped=obj_merge(env.wrapped, wrapped);
  return env;
}

func handler_eaarl_mission_unwrap(env) {
  eaarl_mission_unwrap, env.data;
  return env;
}
