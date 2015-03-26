// vim: set ts=2 sts=2 sw=2 ai sr et:

func handler_eaarl_mission_query_soe_rn(env) {
  flights = env.flights;
  rn = env.rn;

  flight = eaarl_mission_query_soe_rn(env.flights, env.soe, env.rn);
  if(is_string(flight)) env, match=flight;

  return env;
}

func eaarl_mission_query_soe_rn(flights, soe, rn) {
  count = numberof(flights);
  dist = array(10000., count);
  for(i = 1; i <= count; i++) {
    mission, load, flights(i);
    if(!is_void(edb) && rn <= numberof(edb))
      dist(i) = abs(soe - edb(rn).seconds - edb(rn).fseconds*1.6e-6);
  }
  if(dist(min) < 60) return flights(dist(mnx));
  return [];
}

func handler_eaarl_mission_query_soe(env) {
  match = eaarl_mission_query_soe(env.soe);
  if(numberof(match)) env, match=match;
  return env;
}

func eaarl_mission_query_soe(soe) {
/* DOCUMENT eaarl_mission_query_soe(env)

  This function determines the flight using time as follows:
    1. Attempts to uniquely determine using EDB
    2. Attempts to uniquely determine using GPS
    3. Attempts to uniquely determine using INS
    4. If multiple matches were found, returns an array of matches that all of
      them agreed on. (If no matches are found for a source, it is excluded.)
*/
  local edb_match, gps_match, ins_match;
  eaarl_mission_query_soe_scan, env.soe, edb_match, gps_match, ins_match;
  match = eaarl_mission_query_soe_winnow(edb_match, gps_match, ins_match);
  return match;
}

func eaarl_mission_query_soe_scan(soe, &edb_match, &gps_match, &ins_match) {
  loaded = mission.data.loaded;

  if(!mission.data(*,"soe_bounds"))
    mission, data, soe_bounds=save();

  // Scan through flights and collect information on which flights have matches
  // with the soe
  flights = mission(get,);
  count = numberof(flights);
  edb_match = gps_match = ins_match = [];
  for(i = 1; i <= count; i++) {
    if(!mission.data.soe_bounds(*,flights(i)))
      mission, load, flights(i);
    if(!mission.data.soe_bounds(*,flights(i)))
      continue;
    rng = mission.data.soe_bounds(flights(i));
    if(rng(*,"edb") && rng.edb(1) <= soe && soe <= rng.edb(2))
      grow, edb_match, flights(i);
    if(rng(*,"gps") && rng.gps(1) <= soe && soe <= rng.gps(2))
      grow, gps_match, flights(i);
    if(rng(*,"ins") && rng.ins(1) <= soe && soe <= rng.ins(2))
      grow, ins_match, flights(i);
  }

  mission, load, loaded;
}

func eaarl_mission_query_soe_winnow(edb_match, gps_match, ins_match) {
  // If exactly one edb match is found, use it.
  // If no edb match but exactly one gps, use it.
  // If no edb or gps but exactly one ins, use it.
  if(numberof(edb_match) == 1) {
    return edb_match(1);
  } else if(!numberof(edb_match)) {
    if(numberof(gps_match) == 1) {
      return gps_match(1);
    } else if(!numberof(gps_match) && numberof(ins_match) == 1) {
      return ins_match(1);
    }
  }

  // List of all flights that matched anything
  all_match = set_remove_duplicates(grow(edb_match, gps_match, ins_match));
  if(!numberof(all_match)) return [];

  // Winnow list down to just those that appeared on each list of results where
  // we actually had results.
  if(numberof(edb_match))
    all_match = set_intersection(all_match, edb_match);
  if(numberof(gps_match))
    all_match = set_intersection(all_match, gps_match);
  if(numberof(ins_match))
    all_match = set_intersection(all_match, ins_match);

  return all_match;
}

func handler_eaarl_mission_load_soe_rn(env) {
  eaarl_mission_load_soe_rn, env.soe, env.rn;
  return env;
}

func eaarl_mission_load_soe_rn(soe, rn) {
  // Check to see if the current flight contains this soe and rn; if so, do
  // nothing. Only checks EDB.
  if(mission.data.loaded != "" && !is_void(edb) && rn <= numberof(edb)) {
    dist = abs(soe - edb(rn).seconds - edb(rn).fseconds*1.6e-6);
    if(dist < 60) return;
  }

  flight = mission(query_soe_rn, soe, rn);
  // Avoid unload/reload if possible
  if(numberof(flight) == 1 && mission.data.loaded == flight(1))
    return;

  mission, unload;
  if(numberof(flight) == 0) {
    write, "WARNING: no flight found that matched the given soe+rn";
    return;
  }
  if(numberof(flight) > 1) {
    error, "found multiple matches which shouldn't happen";
  }
  mission, load, flight;
}

func handler_eaarl_mission_load_soe(env) {
  eaarl_mission_load_soe, env.soe;
  return env;
}

func eaarl_mission_load_soe(soe) {
  // Check to see if the current flight contains this soe using any of GPS,
  // INS, and EDB (if each is present). If so, use current flight. If multiple
  // flights contain this soe, best to keep the currently loaded rather than
  // changing; calling code should be using soe+rn to query in that case.
  if(mission.data.loaded != "") {
    if(!is_void(edb) && edb.seconds(1) <= soe & soe <= edb.seconds(0)+1)
        return;

    if(is_numerical(soe_day_start)) {
      sod = soe - soe_day_start;

      if(!is_void(pnav) && pnav.sod(1) <= sod && sod <= pnav.sod(0))
        return;

      if(!is_void(tans) && tans.somd(1) <= sod && sod <= tans.somd(0))
        return;
    }
  }

  flights = mission(query_soe, soe);
  // Avoid unload/reload if possible
  if(numberof(flights) == 1 && mission.data.loaded == flights(1))
    return;

  mission, unload;
  if(numberof(flights) == 0) {
    write, "WARNING: no flight found that matched the given soe";
    return;
  }
  if(numberof(flights) > 1) {
    write, "WARNING: multiple flights found that matched the given soe;";
    write, "         using first match, which may not be correct";
  }
  mission, load, flights(1);
}

func eaarl_mission_load_test_key(flight, key) {
/* DOCUMENT eaarl_mission_load_test_key(flight, key)
  Utility function for mission_eaarl_load.
  - Tests to see if the key exists. If not, warning issued.
  - Tests to see if defined file exists. If not:
    - Warning if mission.data.missing_file="warn"
    - Error otherwise
  - Returns 0 if any warning was issued.
  - Returns 1 if everything is okay.
*/
  if(mission(has, flight, key)) {
    fn = mission(get, flight, key);
    if(file_exists(fn)) {
      return 1;
    } else {
      msg = pr1(key)+" defined for "+pr1(flight)+" doesn't exist";
      if(mission.data.missing_file == "warn") {
        write, "WARNING: "+msg;
        return 0;
      } else {
        error, msg;
      }
    }
  } else {
    write, "WARNING: no "+pr1(key)+" defined for "+pr1(flight);
    return 0;
  }
}

func handler_eaarl_mission_load(env) {
  eaarl_mission_load, env.flight;
  return env;
}

func eaarl_mission_load(flight) {
  // Local alias for convenience
  test_key = eaarl_mission_load_test_key;

  // Start by clearing any currently loaded data. (This also triggers onchange
  // caching.)
  mission, unload;

  mission, data, loaded=flight;

  if(!strlen(flight))
    return;

  // What was restored from the cache?
  cached = "none";

  // Load from cache, if there is cached data present and caching is enabled.
  if(mission.data.cache_mode != "disabled" && mission.data.cache(*,flight)) {
    cached = mission(unwrap, mission.data.cache(noop(flight)));
  }

  // If we loaded everything from cache and we wanted to load everything from
  // cache, then nothing else needs to be done.
  if(cached == "everything" && mission.data.cache_what == "everything")
    return;

  // At this point:
  // If cached=="everything" && mission.data.cache_what=="settings" then:
  //    - all data items should be reloaded (don't want what was cached)
  //    - settings should not be reloaded
  // If cached=="settings" && mission.data.cache_what=="everything" then:
  //    - all data items need to be loaded (weren't cached)
  //    - settings do not need to be loaded (were cached)
  // If cached=="settings" && mission.data.cache_what="settings" then:
  //    - all data items need to be loaded
  //    - settings do not need to be loaded
  // if cached=="none" then:
  //    - all data items need to be loaded
  //    - all settings need to be loaded
  // Thus, all data items always need to be loaded at this point. The settings
  // items only need to be loaded if cached=="none".

  // soe_bounds information is used to speed up query_soe and query_soe_rn.
  // These shouldn't change much, so they are perma-cached regardless of cache
  // settings.
  if(!mission.data(*,"soe_bounds"))
    mission, data, soe_bounds=save();
  if(!mission.data.soe_bounds(*,flight))
    save, mission.data.soe_bounds, noop(flight), save();

  // Step through the data sources used in ALPS and load each one.

  extern data_path;
  if(mission(has, flight, "data_path dir"))
    data_path = mission(get, flight, "data_path dir");

  // If cached is not "none", then settings were restored from the cache
  // (cached == "everything" or cached == "settings").
  if(cached == "none") {
    // ops_conf -- needs to come first since some other sources depend on it
    extern ops_conf, ops_conf_filename;
    if(test_key(flight, "ops_conf file")) {
      ops_conf_filename = mission(get, flight, "ops_conf file");
      ops_conf = load_ops_conf(ops_conf_filename);
    } else {
      write, "         (using EAARL-B defaults)";
      ops_conf = obj_copy(ops_eaarlb);
    }

    if(test_key(flight, "bathconf file")) {
      bathconf, read, mission(get, flight, "bathconf file");
    } else {
      write, "         (using null defaults)";
      bathconf, clear;
    }

    if(test_key(flight, "vegconf file")) {
      vegconf, read, mission(get, flight, "vegconf file");
    } else {
      write, "         (using defaults)";
    }

    if(test_key(flight, "sbconf file")) {
      sbconf, read, mission(get, flight, "sbconf file");
    } else {
      write, "         (using defaults)";
    }

    if(test_key(flight, "mpconf file")) {
      mpconf, read, mission(get, flight, "mpconf file");
    } else {
      write, "         (using defaults)";
    }

    if(test_key(flight, "cfconf file")) {
      cfconf, read, mission(get, flight, "cfconf file");
    } else {
      write, "         (using defaults)";
    }
  }

  // edb -- defines a few variables (such as soe_day_start) that are needed by
  // things that follow
  extern edb;
  soes = [];
  if(test_key(flight, "edb file")) {
    load_edb, fn=mission(get, flight, "edb file"), verbose=0;
    idx = [1, numberof(edb)];
    save, mission.data.soe_bounds(noop(flight)), "edb",
      edb.seconds(idx) + edb.fseconds(idx)*1.6e-6;
  }

  extern pnav, gga, pnav_filename, curzone;
  if(test_key(flight, "pnav file")) {
    rbpnav, mission(get, flight, "pnav file"), verbose=0;
    if(!curzone && has_member(pnav, "lat") && has_member(pnav, "lon"))
      auto_curzone, pnav.lat, pnav.lon;
    if(has_member(pnav, "sod") && mission(has, flight, "date")) {
      idx = [1, numberof(pnav)];
      save, mission.data.soe_bounds(noop(flight)), "gps",
        date2soe(mission(get, flight, "date"), pnav.sod(idx));
    }
  }

  extern ins_filename, iex_nav, iex_head, tans;
  if(test_key(flight, "ins file")) {
    ins_filename = mission(get, flight, "ins file");
    if(file_extension(ins_filename) == ".pbd") {
      load_iexpbd, ins_filename, verbose=0;
    } else {
      tans = iex_nav = rbtans(fn=ins_filename);
      iex_head = [];
    }
    if(has_member(tans, "somd") && mission(has, flight, "date")) {
      idx = [1, numberof(tans)];
      save, mission.data.soe_bounds(noop(flight)), "ins",
        date2soe(mission(get, flight, "date"), tans.somd(idx));
    }
    if(!curzone && has_member(tans, "lat") && has_member(tans, "lon"))
      auto_curzone, tans.lat, tans.lon;
  }

  if(anyof(mission.data.cache_mode == ["onload","onchange"]))
    save, mission.data.cache, mission.data.loaded, mission(wrap,);
}

func handler_eaarl_mission_unload(env) {
  eaarl_mission_unload;
  return env;
}

func eaarl_mission_unload {
  if(mission.data.cache_mode == "onchange" && mission.data.loaded != "")
    save, mission.data.cache, mission.data.loaded, mission(wrap,);

  mission, data, loaded="";

  extern data_path;
  data_path = "";

  extern edb, edb_filename, edb_files, total_edb_records, soe_day_start,
    eaarl_time_offset;
  edb = edb_filename = edb_files = total_edb_records = soe_day_start =
    eaarl_time_offset = [];

  extern pnav, gga, pnav_filename;
  pnav = gga = [];
  pnav_filename = "";

  extern iex_nav, iex_head, tans, ins_filename;
  iex_nav = iex_head = tans = ins_filename = [];

  extern ops_conf, ops_conf_filename;
  ops_conf = ops_conf_filename = [];

  extern bathconf;
  bathconf, clear;

  extern vegconf;
  vegconf, clear;

  extern sbconf;
  sbconf, clear;

  extern mpconf;
  mpconf, clear;

  extern cfconf;
  cfconf, clear;
}

func handler_eaarl_mission_wrap(env) {
  wrapped = eaarl_mission_wrap(env.cache_what);
  save, env, wrapped=obj_merge(env.wrapped, wrapped);
  return env;
}

func eaarl_mission_wrap(cache_what) {
  default, cache_what, mission.data.cache_what;

  extern data_path;
  extern edb, edb_filename, edb_files, total_edb_records, soe_day_start,
    eaarl_time_offset;
  extern pnav, gga, pnav_filename;
  extern iex_nav, iex_head, tans, ins_filename;
  extern ops_conf, ops_conf_filename;
  extern bathconf;
  extern vegconf;
  extern sbconf;
  extern mpconf;
  extern cfconf;

  wrapped = save();

  save, wrapped,
    cache_what,
    ops_conf, ops_conf_filename,
    bathconf_data=bathconf.data,
    vegconf_data=vegconf.data,
    sbconf_data=sbconf.data,
    mpconf_data=mpconf.data;
    cfconf_data=cfconf.data;

  if(cache_what == "everything") {
    save, wrapped,
      data_path,
      edb, edb_filename, edb_files, total_edb_records, soe_day_start,
        eaarl_time_offset,
      pnav, gga, pnav_filename,
      iex_nav, iex_head, tans, ins_filename;
  }

  return wrapped;
}

func handler_eaarl_mission_unwrap(env) {
  eaarl_mission_unwrap, env.data;
  return env;
}

func eaarl_mission_unwrap(data) {
  extern data_path;
  extern edb, edb_filename, edb_files, total_edb_records, soe_day_start,
    eaarl_time_offset;
  extern pnav, gga, pnav_filename;
  extern iex_nav, iex_head, tans, ins_filename;
  extern ops_conf, ops_conf_filename;
  extern bathconf;
  extern vegconf;
  extern sbconf;
  extern mpconf;
  extern cfconf;

  cache_what = data.cache_what;
  bathconf_data = data.bathconf_data;
  vegconf_data = data.vegconf_data;
  mpconf_data = data.mpconf_data;
  cfconf_data = data.cfconf_data;

  idx = data(*,[
    "data_path",
    "edb", "edb_filename", "edb_files", "total_edb_records", "soe_day_start",
        "eaarl_time_offset",
    "pnav", "gga", "pnav_filename",
    "iex_nav", "iex_head", "tans", "ins_filename",
    "ops_conf", "ops_conf_filename"
  ]);
  restore, data(idx(where(idx)));

  if(is_void(bathconf_data))
    bathconf, clear;
  else
    bathconf, groups, bathconf_data, copy=0;

  if(is_void(vegconf_data))
    vegconf, clear;
  else
    vegconf, groups, vegconf_data, copy=0;

  if(is_void(sbconf_data))
    sbconf, clear;
  else
    sbconf, groups, sbconf_data, copy=0;

  if(is_void(mpconf_data))
    mpconf, clear;
  else
    mpconf, groups, mpconf_data, copy=0;

  if(is_void(cfconf_data))
    cfconf, clear;
  else
    cfconf, groups, cfconf_data, copy=0;
}

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
