// vim: set ts=2 sts=2 sw=2 ai sr et:

// This file expects that the main mission.i has already been loaded.

scratch = save(scratch, mission_query_soe_rn, mission_query_soe,
  mission_load_soe_rn, mission_load_soe, mission_load, mission_unload,
  mission_wrap, mission_unwrap, mission_auto, mission_flights_auto,
  mission_details_auto, mission_details_autolist);

func mission_query_soe_rn(soe, rn) {
/* DOCUMENT mission(query_soe_rn, <soe>, <rn>)
  Returns the flight name that contains the specified SOE
  (seconds-of-the-epoch) and RN (raster number).

  This attempts to uniquely identify the flight using mission(query_soe,<soe>).
  If the flight can be uniquely determined that way, then that flight is
  returned and no checks are made on the raster number.

  Sometimes, multiple flights might match an SOE value. This might happen if
  multiple planes are surveying concurrently. In this case, the raster number
  is used to attempt to pinpoint the flight. For each matching flight day, the
  SOE value of the given RN is checked and compared to the given SOE. If one or
  more match within 0.01 seconds, then the closest match is returned.

  If no match is found, [] is returned.

  Note that this may call on "mission, load" to cycle through flights.
  Depending on your cache mode, this may result in unwanted side effects.
*/
  flights = mission(query_soe, soe);
  if(numberof(flights) <= 1) return flights;

  count = numberof(flights);
  dist = array(10000., count);
  for(i = 1; i <= count; i++) {
    mission, load, flights(i);
    if(!is_void(edb) && rn <= numberof(edb))
      dist(i) = abs(soe - edb(rn).seconds - edb(rn).fseconds*1.6e-6);
  }
  if(dist(min) > 0.01) return [];
  return flights(dist(mnx));
}

func mission_query_soe(soe) {
/* DOCUMENT mission(query_soe, <soe>)
  Returns the flight name that contains the specified SOE
  (seconds-of-the-epoch).

  A flight can contain several different sources of time information: EAARL
  index file (EDB), gps trajectory, and ins trajectory. Also, some flights may
  overlap.

  This function determines the flight as follows:
    1. Attempts to uniquely determine using EDB
    2. Attempts to uniquely determine using GPS
    3. Attempts to uniquely determine using INS
    4. If multiple matches were found, returns an array of matches that all of
      them agreed on. (If no matches are found for a source, it is excluded.)

  This will return either a scalar or array result, containing the string names
  of the flights. If no match is found, it will return [].

  Note that this may call on "mission, load" to cycle through flights.
  Depending on your cache mode, this may result in unwanted side effects.
*/
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

func mission_load_soe_rn(soe, rn) {
/* DOCUMENT mission, load_soe_rn, <soe>, <rn>
  Loads the flight that contains the specified SOE (seconds-of-the-epoch) and
  RN (raster number).

  See "mission, help, query_soe_rn" for details on how the flight is determined
  from the SOE and RN.
*/
  flight = mission(query_soe_rn, soe, rn);
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

func mission_load_soe(soe) {
/* DOCUMENT mission, load_soe, <soe>
  Loads the flight that contains the specified SOE (seconds-of-the-epoch).

  See "mission, help, query_soe" for details on how the flight is determined
  from the SOE.
*/
  flights = mission(query_soe, soe);
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

func mission_load(flight) {
/* DOCUMENT mission, load, "<flight>"
  Loads the data for the specified flight. If the flight given is "", then all
  data will just be unloaded.
*/
  // Start by clearing any currently loaded data. (This also triggers onchange
  // caching.)
  mission, unload;

  mission, data, loaded=flight;

  if(!strlen(flight))
    return;

  // Load from cache, if there is cached data present and caching is enabled.
  if(mission.data.cache_mode != "disabled" && mission.data.cache(*,flight)) {
    mission, unwrap, mission.data.cache(noop(flight));
    return;
  }

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

  // ops_conf -- neds to come first since some other sources depend on it
  extern ops_conf, ops_conf_filename;
  if(mission(has, flight, "ops_conf file")) {
    ops_conf_filename = mission(get, flight, "ops_conf file");
    ops_conf = load_ops_conf(ops_conf_filename);
  } else {
    write, "WARNING: no ops_conf file defined for "+pr1(flight);
    write, "         (using EAARL-B defaults)";
    ops_conf = ops_eaarlb;
  }

  // edb -- defines a few variables (such as soe_day_start) that are needed by
  // things that follow
  extern edb;
  soes = [];
  if(mission(has, flight, "edb file")) {
    load_edb, fn=mission(get, flight, "edb file"), verbose=0;
    idx = [1, numberof(edb)];
    save, mission.data.soe_bounds(noop(flight)), "edb",
      edb.seconds(idx) + edb.fseconds(idx)*1.6e-6;
  } else {
    write, "WARNING: no edb file defined for "+pr1(flight);
  }

  extern pnav, curzone;
  if(mission(has, flight, "pnav file")) {
    pnav = rbpnav(fn=mission(get, flight, "pnav file"), verbose=0);
    if(!curzone && has_member(pnav, "lat") && has_member(pnav, "lon"))
      auto_curzone, pnav.lat, pnav.lon;
    if(has_member(pnav, "sod") && mission(has, flight, "date")) {
      idx = [1, numberof(pnav)];
      save, mission.data.soe_bounds(noop(flight)), "gps",
        date2soe(mission(get, flight, "date"), pnav.sod(idx));
    }
    save, mission.data.soe_bounds(noop(flight)), "edb",
      edb.seconds(idx) + edb.fseconds(idx)*1.6e-6;
  } else {
    write, "WARNING: no pnav file defined for "+pr1(flight);
  }

  extern ins_filename, tans;
  if(mission(has, flight, "ins file")) {
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
  } else {
    write, "WARNING: no ins file defined for "+pr1(flight);
  }

  if(mission(has, flight, "bath_ctl file")) {
    bath_ctl_load, mission(get, flight, "bath_ctl file");
  } else {
    write, "WARNING: no bath_ctl file defined for "+pr1(flight);
  }

  if(anyof(mission.data.cache_mode == ["onload","onchange"]))
    save, mission.data.cache, mission.data.loaded, mission(wrap,);
}

func mission_unload(void) {
/* DOCUMENT mission, unload
  Unloads all currently loaded data. *If cache_mode is "onchange", then the
  data is cached first.
*/
  if(mission.data.cache_mode == "onchange")
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

  extern bath_ctl, bath_ctl_chn4;
  bath_ctl = bath_ctl_chn4 = [];
}

func mission_wrap(void) {
/* DOCUMENT data = mission(wrap,)
  Saves all of the relevant variables to an oxy group object for the currently
  loaded dataset. The group object is then returned. The group object should be
  restored with "mission, unwrap, <data>" instead of "restore, <data>" as there
  may be additional routines to call after restoration.

  This is intended for internal use for caching.
*/
  extern data_path;
  extern edb, edb_filename, edb_files, total_edb_records, soe_day_start,
    eaarl_time_offset;
  extern pnav, gga, pnav_filename;
  extern iex_nav, iex_head, tans, ins_filename;
  extern ops_conf, ops_conf_filename;
  extern bath_ctl, bath_ctl_chn4;

  return save(
    data_path,
    edb, edb_filename, edb_files, total_edb_records, soe_day_start,
      eaarl_time_offset,
    pnav, gga, pnav_filename,
    iex_nav, iex_head, tans, ins_filename,
    ops_conf, ops_conf_filename,
    bath_ctl, bath_ctl_chn4
  );
}

func mission_unwrap(data) {
/* DOCUMENT mission, unwrap, <data>
  Restores data that was wrapped by mission(wrap,).

  This is intended for internal use for caching.
*/
  extern data_path;
  extern edb, edb_filename, edb_files, total_edb_records, soe_day_start,
    eaarl_time_offset;
  extern pnav, gga, pnav_filename;
  extern iex_nav, iex_head, tans, ins_filename;
  extern ops_conf, ops_conf_filename;
  extern bath_ctl, bath_ctl_chn4;

  restore, data;
  iex2tans;
}

func mission_auto(path, strict=) {
/* DOCUMENT mission, auto, "<path>", strict=
  Automatically initializes a mission based on the given path. The path should
  be the top-level directory of the mission and should contain subdirectories
  for each flight.

  This command will clobber any configuration that is already defined.

  The strict= option controls whether non-lidar flights are included. When
  strict=1, only flights that contain an "edb file" will be defined. When
  strict=0, flights will be created as long as at least one key can be detected
  for a subdirectory. This defaults to strict=1.
*/
  default, strict, 1;
  mission, flights, clear;
  mission, data, path=path;

  // Mission flight directories should always start with a date in their names.
  dirs = lsdirs(path);
  days = get_date(dirs);
  w = where(days);
  if(!numberof(w))
    return;
  dirs = dirs(w);

  // Ensure a stable ordering.
  dirs = dirs(sort(dirs));

  for(i = 1; i <= numberof(dirs); i++) {
    mission, flights, auto, dirs(i), file_join(path, dirs(i)), strict=strict;
    if(!strict && !mission.data.conf(noop(dirs(i)))(*))
      mission, flights, remove, dirs(i);
  }
}

save, mission, query_soe_rn=mission_query_soe_rn, query_soe=mission_query_soe,
  load_soe=mission_load_soe, load_soe_rn=mission_load_soe_rn,
  load=mission_load, unload=mission_unload, wrap=mission_wrap,
  unwrap=mission_unwrap, auto=mission_auto;

func mission_flights_auto(flight, path, strict=) {
/* DOCUMENT mission, flights, auto, "<flight>", "<path>", strict=
  Automatically initializes the specified flight based on the given path. The
  path should be the flight's directory.

  This command will clobber any configuration that is already defined.

  The strict= option controls whether flight without lidar data will be
  initialized. If strict=1, the flight will only be generated when lidar data
  is present. If strict=0, it will always be generated with as much info as
  possible. This defaults to strict=0.

  If strict=1 and no lidar data is found, the flight will be entirely removed
  from the configuration. If strict=0 and no data is found, the flight be
  remain but will have no details defined for it.
*/
  // Make sure the flight exists
  if(!mission(has, flight))
    mission, flights, add, flight;

  // Clear any details that are already present
  mission, details, clear, flight;

  // If strict=1, the flight should only be generated if there's lidar data,
  // which is detected by the presence of an EAARL index file.
  if(strict) {
    mission, details, auto, flight, "edb file", path, strict=1;
    if(!mission.data.conf(noop(flight), *, "edb file")) {
      mission, flights, remove, flight;
      return;
    }
    mission, details, clear, flight;
  }

  // Keys will be added in the order specified below
  keys = [
    "data_path dir",
    "date",
    "edb file",
    "pnav file",
    "ins file",
    "ops_conf file",
    "bath_ctl file",
    "rgb dir",
    "rgb file",
    "nir dir",
    "cir dir"
  ];

  // Auto-detect the value for each key, but only add it if there's actually
  // something detected.
  count = numberof(keys);
  for(i = 1; i <= count; i++)
    mission, details, auto, flight, keys(i), path, strict=1;
}

save, mission.flights, auto=mission_flights_auto;

func mission_details_auto(flight, key, path, strict=) {
/* DOCUMENT mission, details, auto, "<flight>", "<key>", "<path>", strict=
  Automatically initializes a specific key-value pair for a flight. The path
  given should be the path to the flight (NOT to any of the data-specific
  subdirectories in the flight).

  If the function is unable to determine an appropriate value for the key, then
  the result will depend on strict=. When strict=1, the key is deleted from the
  flight. When strict=0, the key is set to "". The default is strict=0.
*/
  val = mission(details, autolist, flight, key, path)(1);
  if(strlen(val)) {
    mission, details, set, flight, key, val;
  } else if(strict) {
    mission, details, remove, flight, key;
  } else {
    mission, details, set, flight, key, "";
  }
}

func mission_details_autolist(flight, key, path) {
/* DOCUMENT mission(details, autolist, "<flight>", "<key>", "<path>")
  Returns a list of candidates values autodetected for the give flight-key-path
  combination. Candidates are ordered from "best guess" to "worst guess". If no
  candidates are autodetected, then [string(0)] is returned.
*/
  if(key == "data_path dir")
    return [path];
  else if(key == "date")
    return [get_date(file_tail(path))];
  else if(key == "edb file")
    return autoselect_edb(path, options=1);
  else if(key == "pnav file")
    return autoselect_pnav(path, options=1);
  else if(key == "ins file")
    return autoselect_iexpbd(path, options=1);
  else if(key == "ops_conf file")
    return autoselect_ops_conf(path, options=1);
  else if(key == "bath_ctl file")
    return autoselect_bath_ctl(path, options=1);
  else if(key == "rgb dir")
    return autoselect_rgb_dir(path, options=1);
  else if(key == "rgb file")
    return autoselect_rgb_tar(path, options=1);
  else if(key == "nir dir")
    return autoselect_nir_dir(path, options=1);
  else if(key == "cir dir")
    return autoselect_cir_dir(path, options=1);
  else
    return [string(0)];
}

save, mission.details, auto=mission_details_auto,
  autolist=mission_details_autolist;

restore, scratch;
