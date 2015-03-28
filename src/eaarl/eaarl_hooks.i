// vim: set ts=2 sts=2 sw=2 ai sr et:

/* All general EAARL hooks should be defined in this file. The hook functions
 * should use the prefix "hook_eaarl_" to support auto-loading by plugins.
 */

func hook_eaarl_mission_flights_auto_critical(env) {
  edbs = mission(details, autolist, env.flight, "edb file", env.path);
  env, has_critical=(numberof(edbs) > 0);
  return env;
}

hook_eaarl_mission_flights_auto_keys_priority = -10;
func hook_eaarl_mission_flights_auto_keys(env) {
/* DOCUMENT eaarl_mission_flights_auto_keys(env)
  Hook function for "mission_flights_auto_keys" used by mission_flights_auto.
  SEE ALSO: mission_flights_auto
*/
  keys = env.keys;
  grow, keys, [
    "edb file",
    "pnav file",
    "ins file",
    "ops_conf file",
    "bathconf file",
    "vegconf file",
    "sbconf file",
    "mpconf file",
    "cfconf file"
  ];
  save, env, keys;
  return env;
}

hook_eaarl_mission_details_autolist_priority = -10;
func hook_eaarl_mission_details_autolist(env) {
/* DOCUMENT eaarl_mission_details_autolist(env)
  Hook function for mission_details_autolist.
  SEE ALSO: mission_details_autolist
*/
  key = env.key;
  path = env.path;
  if(key == "edb file")
    env, result=autoselect_edb(path, options=1);
  else if(key == "pnav file")
    env, result=autoselect_pnav(path, options=1);
  else if(key == "ins file")
    env, result=autoselect_iexpbd(path, options=1);
  else if(key == "ops_conf file")
    env, result=autoselect_ops_conf(path, options=1);
  else if(key == "bathconf file")
    env, result=autoselect_bathconf(path, options=1);
  else if(key == "vegconf file")
    env, result=autoselect_vegconf(path, options=1);
  else if(key == "sbconf file")
    env, result=autoselect_sbconf(path, options=1);
  else if(key == "mpconf file")
    env, result=autoselect_mpconf(path, options=1);
  else if(key == "cfconf file")
    env, result=autoselect_cfconf(path, options=1);
  return env;
}

hook_eaarl_mission_flights_validate_fields_priority = -10;
func hook_eaarl_mission_flights_validate_fields(env) {
  save, env.fields,
    "edb file", save(
      "help", "The edb file provides an index to the EAARL TLD data. It is usually found in an \"eaarl\" subdirectory and must be alongside the TLD files it indexes. The file usually ends in the extension .idx and can be generated using the command-line program mkeidx.",
      required=1
    ),
    "pnav file", save(
      "help", "The pnav file provides the GPS trajectory of the flight and is generally at a low sampling resolution such as 2 Hz. The pnav file has the extension .ybin and is generally in a trajectories subdirectory which is generated using the command-line program mktrajfiles. The input for mktrajfiles is a zip containing output from GrafNav.",
      required=1
    ),
    "ins file", save(
      "help", "The ins file provides the inertial trajectory of the flight and is generally at a higher sampling resolution such as 200 Hz. The ins file has the extension .pbd and is generally in a trajectories subdirectory which is generated using the command-line program mktrajfiles. The input for mktrajfiles is a zip containing output from GrafNav Inertial Explorer.",
      required=1
    ),
    "ops_conf file", save(
      "help", "The ops_conf file contains operational constants and biases between the individual instruments on the plane. These values are tuned in ALPS and then are written out from the EAARL Processing GUI. The ops_conf has the extension .i and usually has \"ops_conf\" in its name. It is found either in the flight directory (if it is specific to this flight) or in the mission directory (if it is shared across multiple flights).",
      required=1
    ),
    "bathconf file", save(
      "help", "The bathconf file contains parameters used to process for submerged topography. This file is only required if you will be processing for submerged topography. The bathconf file will usually have the extension .bathconf; however, it may instead end in -bctl.json or .bctl if using older configuration files. The file is found either in the flight directory (if it is specific to this flight) or in the mission directory (if it is shared across multiple flights).",
      required=0
    ),
    "vegconf file", save(
      "help", "The vegconf file contains parameters used to process for vegetation. This file is only required if you will be processing for vegetation and the defaults are not acceptable. The vegconf file will have the extension .vegconf. The file is found in the alps configuration subdirectory.",
      required=0
    ),
    "sbconf file", save(
      "help", "The sbconf file contains parameters used to process for shallow bathy. This file is only required if you will be processing for shallow bathy and the defaults are not acceptable. The sbconf file will have the extension .sbconf. The file is found in the alps configuration subdirectory.",
      required=0
    ),
    "mpconf file", save(
      "help", "The mpconf file contains parameters used to process for multi-peak. This file is only required if you will be processing multi-peak and the defaults are not acceptable. The mpconf file will have the extension .mpconf. The file is found in the alps configuration subdirectory.",
      required=0
    ),
    "cfconf file", save(
      "help", "The cfconf file contains parameters used to process for vegetation using curve fitting. This file is only required if you will be processing using curve fitting and the defaults are not acceptable. The cfconf file will have the extension .cfconf. The file is found in the alps configuration subdirectory.",
      required=0
    );

  return env;
}

func hook_eaarl_expix_show(env) {
  point = env.nearest.point;

  // In case we are querying non-EAARL data
  if(!has_member(point, "soe")) return env;
  if(!has_member(point, "raster")) return env;
  if(!has_member(point, "pulse")) return env;

  eaarl_expix_show, point;
  pixelwf_plot;

  return env;
}
