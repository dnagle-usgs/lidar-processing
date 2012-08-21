// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// Original David Nagle 2009-02-03

local mission_conf;
local mission_conf_i;
/* DOCUMENT mission_conf.i

  This file defines functionality for managing a mission configuration. A
  mission configuration defines the files used to load the data for each
  mission day in a mission.

  Most of the functions present in mission_conf.i for Yorick are also present
  in mission_conf.ytk for Tcl. The two sides attempt to stay in sync with
  each other. Thus, using a given function on one side is equivalent to using
  it on the other: both sides will receive the change.

  Functions for working with a mission configuration:

    ## Functions that alter the configuration
    mission_set, key, value, day=, sync=
    mission_clear, sync=
    mission_delete, key, day=, sync=
    mission_path, path, sync=

    ## Functions that retrieve existing information
    mission_get(key, day=)
    mission_has(key, day=)
    mission_keys(day=)
    mission_path()

  Functions for working with mission days:

    ## Functions that alter the configuration
    missionday_add, day, sync=
    missionday_delete, day, sync=
    missionday_set, hash, day=, sync=

    ## Functions that retrieve existing information
    missionday_current(day, sync=)
    missionday_exists(day=)
    missionday_get(day=)
    missionday_list()

  Functions for working with the environment and cache:

    missiondata_cache, action
    missiondata_wrap(type)
    missiondata_unwrap, data
    missiondata_load, type, day=
    missiondata_read(filename) -or- missiondata_read, filename
    missiondata_write, filename, input, overwrite=

  Functions for saving/loading/transmitting the configuration:

    mission_json_export(compact=)
    mission_json_import, json, sync=
    mission_save, filename
    mission_load, filename
    mission_send
    mission_receive

  Miscellaneous:

    mission_initialize_from_path, path, strict=
    autoselect_ops_conf(dir)
    autoselect_edb(dir)
*/

local __mission_conf;
/* DOCUMENT __mission_conf
  This global variable contains the data representing the current mission's
  configuration.

  The various mission_* functions in mission_conf.i interact and use
  __mission_conf behind the scenes. Users are recommended to use those
  functions instead of interacting with __mission_conf directly.
*/

local __mission_day;
/* DOCUMENT __mission_day
  This global variable is a scalar string that specifies which mission day is
  currently of interest.

  The various mission_* functions in mission_conf.i use this as the default
  for their day= parameters, where applicable.
*/

local __mission_path;
/* DOCUMENT __mission_path
  This global variable is a scalar string representing the mission's path.
  The paths in __mission_conf are all intended to be relative to this path.

  This is used internally by the mission_* functions and probably shouldn't
  be used directly.
*/

local __mission_cache;
/* DOCUMENT __mission_cache
  This global variable stores loaded data for the mission in order to reduce
  load times later.

  Users shouldn't need to access this directly. It is considered a private
  variable to the mission_conf.i functionality.
*/

local __mission_settings;
/* DOCUMENT __mission_settings
  This global variable stores some settings for mission_conf.i. Users
  shouldn't interact with it directly.
*/

if(is_void(__mission_conf))
  __mission_conf = h_new();

if(is_void(__mission_day))
  __mission_day = string(0);

if(is_void(__mission_path))
  __mission_path = string(0);

if(is_void(__mission_cache))
  __mission_cache = h_new();

if(is_void(__mission_settings))
  __mission_settings = h_new(
    "use cache", 1,
    "ytk", 0,
    "relative paths", ["data_path", "edb file", "pnav file", "ins file",
      "ops_conf file", "bath_ctl file", "cir dir", "rgb dir", "rgb file"]
  );

func mission_clear(void, sync=) {
/* DOCUMENT mission_clear(sync=)
  Clears all data for the mission configuration.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_settings, __mission_path;
  default, sync, 1;
  __mission_conf = h_new();
  if(__mission_settings("ytk") && sync)
    tkcmd, "mission_clear 0";
}

func mission_get(key, day=) {
/* DOCUMENT mission_get(key, day=)
  Retrieves the value corresponding key for the current mission day, or for
  the mission day specified by day= if present.
*/
  extern __mission_conf, __mission_day, __mission_settings, __mission_path;
  default, day, __mission_day;
  if(!h_has(__mission_conf, day))
    return [];
  obj = h_get(__mission_conf, day);
  if(!h_has(obj, key))
    return [];
  result = h_get(obj, key);
  if(set_contains(__mission_settings("relative paths"), key))
    result = file_join(__mission_path, result);
  return result;
}

func mission_set(key, value, day=, sync=) {
/* DOCUMENT mission_set, key, value, day=, sync=
  Sets the value for the given key to the value given for the current mission
  day, or for the mission day specified by day= if present.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_day, __mission_settings, __mission_path;
  default, day, __mission_day;
  default, sync, 1;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  if(__mission_settings("ytk") && sync)
    tkcmd, swrite(format="mission_set {%s} {%s} {%s} 0", key, value, day);

  if(set_contains(__mission_settings("relative paths"), key))
    value = file_relative(__mission_path, value);

  if(!h_has(__mission_conf, day))
    h_set, __mission_conf, day, h_new();
  obj = h_get(__mission_conf, day);
  h_set, obj, key, value;
}

func mission_set_bg(key, value, day) {
/* DOCUMENT mission_set_bg(key, value, day)
  Wrapper around mission_set suitable for use with Ytk ybkg.
*/
  mission_set, key, value, day=day, sync=0;
}

func mission_has(key, day=) {
/* DOCUMENT mission_has(key, day=)
  Returns boolean indicating whether the current mission day (or the mission
  day specified by day=, if present) has a value for the specified key.
*/
  extern __mission_conf, __mission_day;
  default, day, __mission_day;
  if(!h_has(__mission_conf, day))
    return 0;
  obj = h_get(__mission_conf, day);
  return h_has(obj, key);
}

func mission_keys(void, day=) {
/* DOCUMENT mission_keys(day=)
  Returns a list of the keys defined for the current mission day, or the
  mission day specified by day= if present.
*/
  extern __mission_conf, __mission_day;
  default, day, __mission_day;
  if(!h_has(__mission_conf, day))
    return [];
  return h_keys(h_get(__mission_conf, day));
}

func mission_delete(key, day=, sync=) {
/* DOCUMENT mission_delete, key, day=, sync=
  Deletes the value for the specified key for the current mission day, or the
  mission day specified by day= if present.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_day, __mission_settings;
  default, day, __mission_day;
  default, sync, 1;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  if(h_has(__mission_conf, day)) {
    obj = h_get(__mission_conf, day);
    h_pop, obj, key;
  }

  if(__mission_settings("ytk") && sync)
    tkcmd, swrite(format="mission_delete {%s} {%s} 0", key, day);
}

func missionday_current(day, sync=) {
/* DOCUMENT missionday_current, day, sync=
  missionday_current()

  Returns the current mission day. If a day is passed, the mission day
  will be updayd with that value.

  If the day is set, this will sync with Tcl unless sync=0 or
  __mission_settings("ytk") = 0.
*/
  extern __mission_day, __mission_settings;
  default, sync, 1;
  if(!is_void(day)) {
    __mission_day = day
    if(__mission_settings("ytk") && sync)
      tkcmd, swrite(format="missionday_current {%s} 0", day);
  }
  return __mission_day;
}

func missionday_list(void) {
/* DOCUMENT missionday_list()
  Returns an array of the mission days currently defined.
*/
  extern __mission_conf;
  days = h_keys(__mission_conf);
  if(numberof(days))
    days = days(sort(days));
  return days;
}

func missionday_add(day, sync=) {
/* DOCUMENT missionday_add(day, sync=)
  Creates an entry for the specified day. This isn't usually needed since
  days are automatically created when setting a key for them.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_settings;
  default, sync, 1;

  if(! h_has(__mission_conf, day))
    h_set, __mission_conf, day, h_new();

  if(__mission_settings("ytk") && sync)
    tkcmd, swrite(format="missionday_add {%} 0", day);
}

func missionday_delete(day, sync=) {
/* DOCUMENT missionday_delete, day, sync=
  Deletes the specified mission day.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_settings;
  default, sync, 1;
  h_pop, __mission_conf, day;

  if(__mission_settings("ytk") && sync)
    tkcmd, swrite(format="missionday_delete {%s} 0", day);
}

func missionday_delete_bg(day) {
/* DOCUMENT missionday_delete_bg(day)
  Wrapper around mission_delete suitable for use with Ytk ybkg.
*/
  missionday_delete, day, sync=0;
}

func missionday_exists(void, day=) {
/* DOCUMENT missionday_exists(day=)
  Returns 1 if the current mission day (or day=, if specified) exists.
  Otherwise, returns 0.
*/
  extern __mission_conf, __mission_day;
  default, day, __mission_day;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  return h_has(__mission_conf, day);
}

func missionday_set(hash, day=, sync=) {
/* DOCUMENT missionday_set, hash, day=, sync=
  Sets the data for the current mission day (or day=, if specified) to the
  data in the specified Yeti hash.

  This will sync with Tcl unless sync=0 or __mission_settings("ytk") = 0.
*/
  extern __mission_conf, __mission_day, __mission_settings;
  default, day, __mission_day;
  default, sync, 1;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  missionday_delete, day, sync=sync;
  keys = h_keys(hash);
  for(i = 1; i <= numberof(keys); i++) {
    mission_set, keys(i), hash(keys(i)), day=day, sync=sync;
  }
}

func missionday_get(void, day=) {
/* DOCUMENT missionday_get(day=)
  Returns the Yeti hash for the current day, or day= if specified.
*/
  extern __mission_conf, __mission_day;
  default, day, __mission_day;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  if(missionday_exists(day=day))
    return __mission_conf(day);
  else
    return [];
}

func mission_json_export(void, compact=) {
/* DOCUMENT mission_json_export(compact=)
  Returns a json string that represents the current mission configuration.

  If compact=1, a compact form will be generated.
*/
  extern __mission_conf, _hgid;
  default, compact, 0;
  data = h_new("days", __mission_conf);
  if(!compact) {
    soe_now = [];
    timestamp, soe_now;
    h_set, data, "save environment", h_new(
      "path", mission_path(),
      "user", get_user(),
      "host", get_host(),
      "timestamp", soe2iso8601(soe_now),
      "repository", _hgid
    )
  }
  return json_encode(data, indent=(compact ? [] : 2));
}

func mission_json_import(json, sync=) {
/* DOCUMENT mission_json_import, json, sync=
  Loads the mission configuration defined in the given json string.
*/
  extern __mission_conf, __mission_settings;
  default, sync, 1;
  data = json_decode(json);
  if(h_has(data, "days")) {
    __mission_conf = data("days");
  } else {
    __mission_conf = data;
  }

  keys = h_keys(__mission_conf);
  for(i = 1; i <= numberof(keys); i++) {
    mday = __mission_conf(keys(i));
    // On 2010-01-28, "dmars file" was renamed to "ins file". This provides
    // compatibility for previously saved configuration files.
    if(h_has(mday, "dmars file"))
      h_set, mday, "ins file", h_pop(mday, "dmars file");
  }

  if(__mission_settings("ytk") && sync)
    mission_send;
}

func mission_json_import_bg(json) {
/* DOCUMENT mission_json_import_bg(json)
  Wrapper around mission_json_import suitable for use with Ytk ybkg.
*/
  mission_json_import, json, sync=0;
}

func mission_save(filename) {
/* DOCUMENT mission_save, filename
  Writes the current mission configuration to the specified file, in JSON
  format.
*/
  extern __mission_conf;
  json = mission_json_export();
  f = open(filename, "w");
  write, f, format="%s\n", json;
  close, f;
}

func mission_load(filename) {
/* DOCUMENT mission_load, filename
  Loads a mission configuration from the given filename, which must be in
  JSON format.
*/
  extern __mission_conf;
  f = open(filename, "r");
  json = rdfile(f);
  close, f;
  mission_path, file_dirname(filename);
  mission_json_import, json;
}

func mission_send(void) {
/* DOCUMENT mission_send
  Sends the mission configuration as defined in Yorick to Tcl.
*/
  extern __mission_conf, __mission_day;
  json = mission_json_export(compact=1);
  tkcmd, swrite(format="mission_json_import {%s} 0", json);
  tkcmd, swrite(format="set __mission_day {%s}", __mission_day);
}

func mission_receive(void) {
/* DOCUMENT mission_receive
  Asks Tcl to update Yorick with the mission configuration as defined in Tcl.
*/
  tkcmd, "after idle [list after 0 mission_send]";
}

func missiondata_cache(action, day=) {
/* DOCUMENT missiondata_cache, action
  Does something cache related, depending on the action specified. Action
  must be a string.

    query   - Returns 1 if the cache is enabled, 0 if not
    clear   - Clears the cache
    enable  - Enables the use of the cache
    disable - Disabled the use of the cache (but does not clear it)
    preload - Preloads the cache with each mission day's data
    recache - Stores the current mission data to the cache for the current
        mission day. (Note: This does not write to file. It only
        updates the cache so that working state is not lost.)

  You can also pass the integers 1 or 0 to enable or disable the cache,
  respectively. (Useful if you need to temporarily disable the cache and then
  return it to its previous state.)

  Options:
    day= Only used for the "recache" option. If provided, this will update
        the cache for the given day instead of the current mission day.
        Not intended for general use.
*/
  extern __mission_conf, __mission_day, __mission_cache, __mission_settings;
  default, day, __mission_day;
  if(is_integer(action)) {
    h_set, __mission_settings, "use cache", (action ? 1 : 0);
  } else if(action == "clear") {
    __mission_cache = h_new();
  } else if(action == "query") {
    return __mission_settings("use cache");
  } else if(action == "enable") {
    h_set, __mission_settings, "use cache", 1;
  } else if(action == "disable") {
    h_set, __mission_settings, "use cache", 0;
  } else if(action == "preload") {
    days = missionday_list();
    missiondata_cache, "clear";
    missiondata_cache, "enable";
    environment_backup = missiondata_wrap("all");
    for(i = 1; i <= numberof(days); i++) {
      missiondata_load, "all", day=days(i);
    }
    missiondata_unwrap, environment_backup;
  } else if(action == "recache") {
    if(! __mission_settings("use cache")) {
      write, "Caching is not enabled. To enable caching, use:";
      write, "  missiondata_cache, \"enable\"";
      return;
    }
    if(!day) {
      write, "The recache command needs a mission day. Either provide day=";
      write, "or set __mission_day.";
    }
    if(!h_has(__mission_cache, day))
      h_set, __mission_cache, day, h_new();
    cache = __mission_cache(day);
    settings = ["ops_conf", "edb", "pnav", "ins", "bath_ctl"];
    for(i = 1; i <= numberof(settings); i++)
      h_set, cache, settings(i), missiondata_wrap(settings(i));
    write, "Current data (edb, pnav, ins, ops_conf, and bath_ctl) have been";
    write, "stored to the cache for "+day;
    write, "Important: changes have NOT been written to file. If you want to";
    write, "save changes, you must do that separately!";
  }
}

func missiondata_wrap(type) {
/* DOCUMENT missiondata_wrap(type)
  Wraps currently loaded data in Yorick extern variables into a Yeti hash,
  suitable for restoring later with missiondata_unwrap.

  The type should be one of:
    all - includes all of the others
    ops_conf
    edb
    pnav
    ins
    bath_ctl
*/
  if(is_void(type)) {
    error, "No type was provided.";
  } else if(type == "all") {
    return h_new(
      "__type", "all",
      "ops_conf", missiondata_wrap("ops_conf"),
      "edb", missiondata_wrap("edb"),
      "pnav", missiondata_wrap("pnav"),
      "ins", missiondata_wrap("ins"),
      "bath_ctl", missiondata_wrap("bath_ctl")
    );
  } else if(type == "edb") {
    extern edb, edb_filename, edb_files, total_edb_records,
      soe_day_start, eaarl_time_offset, data_path;
    return h_new(
      "__type", "edb",
      "edb", edb,
      "edb_filename", edb_filename,
      "edb_files", edb_files,
      "total_edb_records", total_edb_records,
      "soe_day_start", soe_day_start,
      "eaarl_time_offset", eaarl_time_offset,
      "data_path", data_path
    );
  } else if(type == "pnav") {
    extern pnav, gga, pnav_filename;
    if(is_void(pnav)) {
      return h_new(
        "__type", "pnav_gga",
        "gga", gga,
      );
    } else {
      return h_new(
        "__type", "pnav_pnav",
        "pnav", pnav,
        "pnav_filename", pnav_filename
      );
    }
  } else if(type == "ins") {
    extern iex_nav, iex_head, tans, ins_filename;
    if(is_void(iex_head)) {
      return h_new(
        "__type", "ins_tans",
        "tans", tans,
        "ins_filename", ins_filename
      );
    } else {
      return h_new(
        "__type", "ins_iex",
        "iex_nav", iex_nav,
        "iex_head", iex_head,
        "ins_filename", ins_filename
      );
    }
  } else if(type == "ops_conf") {
    extern ops_conf;
    return h_new(
      "__type", "ops_conf",
      "ops_conf", ops_conf,
      "ops_conf_filename", ops_conf_filename
    );
  } else if(type == "bath_ctl") {
    extern bath_ctl, bath_ctl_chn4;
    return h_new(
      "__type", "bath_ctl",
      "bath_ctl", bath_ctl,
      "bath_ctl_chn4", bath_ctl_chn4
    );
  } else {
    error, swrite(format="Unknown type provided: %s", type);
  }
}

func missiondata_unwrap(data) {
/* DOCUMENT missiondata_unwrap, data
  Updates Yorick extern variables by unwrapping data that was wrapped using
  missiondata_wrap.
*/
  if(h_has(data, "__type"))
    type = data.__type;
  else
    error, "Data does not define its type.";

  if(type == "all") {
    missiondata_unwrap, data.ops_conf;
    missiondata_unwrap, data.edb;
    missiondata_unwrap, data.pnav;
    missiondata_unwrap, data.ins;
    missiondata_unwrap, data.bath_ctl;
  } else if(type == "edb") {
    extern edb, edb_filename, edb_files, total_edb_records,
      soe_day_start, eaarl_time_offset, data_path;
    // _edb_fd -- file handle???
    // gps_time_correction -- shouldn't change
    edb = data.edb;
    edb_filename = data.edb_filename;
    edb_files = data.edb_files;
    total_edb_records = data.total_edb_records;
    soe_day_start = data.soe_day_start;
    eaarl_time_offset = data.eaarl_time_offset;
    data_path = data.data_path;
  } else if(type == "pnav_gga") {
    extern pnav, gga, pnav_filename;
    pnav = pnav_filename = [];
    gga = data.gga;
  } else if(type == "pnav_pnav") {
    extern pnav, gga, pnav_filename;
    pnav = gga = data.pnav;
    pnav_filename = data.pnav_filename;
  } else if(type == "ins_tans") {
    extern iex_nav, iex_head, tans, ins_filename;
    iex_nav = iex_head = [];
    tans = data.tans;
    ins_filename = data.ins_filename;
  } else if(type == "ins_iex") {
    extern iex_nav, iex_head, tans;
    iex_nav = data.iex_nav;
    iex_head = data.iex_head;
    ins_filename = data.ins_filename;
    iex2tans;
  } else if(type == "ops_conf") {
    extern ops_conf, ops_conf_filename;
    ops_conf = data.ops_conf;
    ops_conf_filename = data.ops_conf_filename;
  } else if(type == "bath_ctl") {
    extern bath_ctl, bath_ctl_chn4;
    bath_ctl = data.bath_ctl;
    bath_ctl_chn4 = data.bath_ctl_chn4;
  } else {
    error, swrite(format="Unknown type provided: %s", type);
  }
}

func missiondata_load(type, day=, noerror=) {
/* DOCUMENT missiondata_load, type, day=
  Loads mission data for the current day, or for day= if specified.

  The type should be one of:
    all - will load all defined data
    edb
    pnav
    ins
    ops_conf
    bath_ctl
*/
  extern __mission_conf, __mission_day, __mission_cache, __mission_settings;
  default, day, __mission_day;
  default, noerror, 0;

  if(!day)
    error, "Please provide day= or set __mission_day.";

  if(type == "all") {
    missiondata_load, "ops_conf", day=day, noerror=1;
    missiondata_load, "edb", day=day, noerror=1;
    missiondata_load, "pnav", day=day, noerror=1;
    missiondata_load, "ins", day=day, noerror=1;
    missiondata_load, "bath_ctl", day=day, noerror=1;
    return;
  }

  cache_enabled = __mission_settings("use cache");

  if(cache_enabled) {
    if(! h_has(__mission_cache, day)) {
      h_set, __mission_cache, day, h_new();
    }
    cache = __mission_cache(day);
  } else {
    cache = h_new();
  }

  if(is_void(type)) {
    error, "No type was provided.";
  } else if(type == "edb") {
    if(cache_enabled && h_has(cache, "edb")) {
      missiondata_unwrap, cache("edb");
    } else if(mission_has("edb file", day=day)) {
      extern data_path;
      if(mission_has("data_path", day=day))
        data_path = mission_get("data_path", day=day);
      load_edb, fn=mission_get("edb file", day=day), verbose=0;
      if(cache_enabled) {
        h_set, cache, "edb", missiondata_wrap("edb");
      }
    } else if(noerror) {
      extern edb, edb_filename, edb_files, total_edb_records,
        soe_day_start, eaarl_time_offset, data_path;
      edb = edb_filename = edb_files = total_edb_records =
        soe_day_start = eaarl_time_offset = data_path = [];
    } else {
      error, "Could not load edb data: no edb file defined";
    }
  } else if(type == "pnav") {
    extern pnav;
    if(cache_enabled && h_has(cache, "pnav")) {
      missiondata_unwrap, cache("pnav");
    } else if(mission_has("pnav file", day=day)) {
      extern pnav;
      pnav = rbpnav(fn=mission_get("pnav file", day=day), verbose=0);
      if(cache_enabled) {
        h_set, cache, "pnav", missiondata_wrap("pnav");
      }
    } else if(noerror) {
      extern pnav, gga, pnav_filename;
      pnav = gga = pnav_filename = [];
    } else {
      error, "Could not load pnav data: no pnav file defined";
    }
    if(mission_has("pnav file", day=day))
      tkcmd, swrite(format="set ::plot::g::pnav_file {%s}",
        mission_get("pnav file", day=day));
    if(!is_void(pnav))
      auto_curzone, pnav.lat, pnav.lon;
  } else if(type == "ins") {
    extern iex_nav, iex_head, tans, ins_filename;
    if(cache_enabled && h_has(cache, "ins")) {
      missiondata_unwrap, cache("ins");
    } else if(mission_has("ins file", day=day)) {
      ins_filename = mission_get("ins file", day=day);
      if(file_extension(ins_filename) == ".pbd") {
        load_iexpbd, ins_filename, verbose=0;
      } else {
        tans = iex_nav = rbtans(fn=ins_filename);
        iex_head = [];
      }
      if(cache_enabled) {
        h_set, cache, "ins", missiondata_wrap("ins");
      }
    } else if(noerror) {
      iex_nav = iex_head = tans = ins_filename = [];
    } else {
      error, "Could not load ins data: no ins file defined";
    }
    if(has_member(iex_nav, "lat") && has_member(iex_nav, "lon"))
      auto_curzone, iex_nav.lat, iex_nav.lon;
  } else if(type == "ops_conf") {
    if(cache_enabled && h_has(cache, "ops_conf")) {
      missiondata_unwrap, cache("ops_conf");
    } else if(mission_has("ops_conf file", day=day)) {
      extern ops_conf, ops_conf_filename;
      ops_conf_filename = mission_get("ops_conf file", day=day);
      ops_conf = load_ops_conf(ops_conf_filename);
      if(cache_enabled) {
        h_set, cache, "ops_conf", missiondata_wrap("ops_conf");
      }
    } else if(noerror) {
      extern ops_conf, ops_conf_filename;
      ops_conf = ops_conf_filename = [];
    } else {
      error, "Could not load ops_conf: no ops_conf file defined";
    }
  } else if(type == "bath_ctl") {
    if(cache_enabled && h_has(cache, "bath_ctl")) {
      missiondata_unwrap, cache("bath_ctl");
    } else if(mission_has("bath_ctl file", day=day)) {
      extern bath_ctl, bath_ctl_chn4;
      bath_ctl_load, mission_get("bath_ctl file", day=day);
      if(cache_enabled) {
        h_set, cache, "bath_ctl", missiondata_wrap("bath_ctl");
      }
    } else if(noerror) {
      extern bath_ctl, bath_ctl_chn4;
      bath_ctl = bath_ctl_chn4 = BATH_CTL();
    } else {
      error, "Could not load bath_ctl: no bath_ctl file defined";
    }
  } else {
    error, swrite(format="Unknown type provided: %s", type);
  }
}

func missiondata_soe_load(soe) {
/* DOCUMENT missiondata_soe_load, soe;
  If a mission day exists that contains this soe in its edb data, it will be
  loaded and 1 will be returned. Otherwise, 0 will be returned.
*/
// Original David Nagle 2009-08-07
  day = missiondata_soe_query(soe);
  if(day) {
    missionday_current, day;
    missiondata_load, "all";
    return 1;
  } else {
    return 0;
  }
}

func missiondata_soe_query(soe) {
/* DOCUMENT day = missiondata_soe_query(soe)
  If a mission day exists and contains this soe in its edb or pnav data, that
  day's name will be returned. Otherwise, returns [].
*/
// Original David Nagle 2009-08-07
  extern edb, pnav_filename, pnav;
  edb_backup = missiondata_wrap("edb");
  pnav_backup = missiondata_wrap("pnav");

  days = missionday_list();
  result = pnavresult = [];
  for(i = 1; i <= numberof(days); i++) {
    if(mission_has("edb file", day=days(i))) {
      missiondata_load, "edb", day=days(i);
      w = where(edb.seconds > time2soe([2000,0,0,0,0,0]));
      if(numberof(w)) {
        soe_min = edb(w).seconds(min);
        soe_max = edb(w).seconds(max);
        if(soe_min <= soe && soe <= soe_max) {
          result = days(i);
          break;
        }
      }
    }
    if(mission_has("pnav file", day=days(i))) {
      missiondata_load, "pnav", day=days(i);
      cur_date = mission_get("date", day=days(i));
      if(strlen(cur_date)) {
        soe_min = date2soe(cur_date, pnav.sod(min))(1);
        soe_max = date2soe(cur_date, pnav.sod(max))(1);
        if(soe_min <= soe && soe <= soe_max) {
          pnavresult = days(i);
        }
      }
    }
  }

  missiondata_unwrap, edb_backup;
  missiondata_unwrap, pnav_backup;
  return is_void(result) ? pnavresult : result;
}

func missiondata_read(filename) {
/* DOCUMENT missiondata_read, filename
  data = missiondata_read(filename)

  Reads a Yeti YHD file. If used as a subroutine, the data will be unwrapped
  (via missiondata_unwrap). If used as a function, the data will be returned
  instead (and will not be unwrapped).
*/
  if(!file_exists(filename)) {
    error, "File does not exist";
  } else if(!yhd_check(filename)) {
    error, "File is not a Yeti YHD file";
  } else {
    if(am_subroutine())
      missiondata_unwrap, yhd_restore(filename);
    else
      return yhd_restore(filename);
  }
}

func missiondata_write(filename, input, overwrite=) {
/* DOCUMENT missiondata_write, filename, type, overwrite=
  missiondata_write, filename, wrapped_data, overwrite=

  Writes out a Yeti YHD file containing wrapped data.

  If passed a type, it must be a string suitable for passing to
  missiondata_wrap.

  If passed wrapped_data, it must be a Yeti hash.

  By default, filename will be overwritten if it exists. Set overwrite=0 to
  prevent that (it will trigger a Yorick error though if the file exists).
*/
  default, overwrite, 1;
  if(typeof(input) == "string") {
    data = missiondata_wrap(input);
  } else if(typeof(input) == "hash_table") {
    data = input;
  } else {
    error, "Unknown input type";
  }
  yhd_save, filename, data, overwrite=overwite,
    comment="Restore using missiondata_read in mission_conf.i";
}

func mission_path(path, sync=) {
/* DOCUMENT mission_path, path, sync=
  mission_path()

  Returns the mission path. If a path is passed, the mission path will be
  updated with that value.

  If the path is set, this will sync with Tcl unless sync=0 or
  __mission_settings("ytk") = 0.
*/
  extern __mission_path, __mission_settings;
  default, sync, 1;
  if(!is_void(path)) {
    __mission_path = path;
    if(__mission_settings("ytk") && sync)
      tkcmd, swrite(format="mission_path {%s} 0", path);
  }
  return __mission_path;
}

func mission_initialize_from_path(path, strict=) {
/* DOCUMENT mission_initialize_from_path, path, strict=

  This will clear __mission_conf and attempt to initialize it automatically.
  For each mission day in the mission path (identified by those directories
  whose names contain a date string), it will attempt to locate and define a
  pnav file, ins file, ops_conf.i file, and edb file.

  If strict is 1 (which it is by default), then a mission day will not be
  initialized unless an edb file is present. If strict is 0, then that
  restriction is lifted.
*/
// Original David Nagle 2009-02-04
  extern __mission_conf, __mission_day;
  default, path, mission_path();
  default, strict, 1;

  mission_clear;
  mission_path, path;

  dirs = lsdirs(path);
  days = get_date(dirs);
  w = where(days);
  if(!numberof(w))
    return;
  dirs = dirs(w);
  days = days(w);
  for(i = 1; i <= numberof(days); i++) {
    missionday_current, dirs(i);
    dir = file_join(path, dirs(i));

    edb_file = autoselect_edb(dir);
    if(edb_file) {
      mission_set, "edb file", edb_file;
    } else if(strict) {
      continue;
    }
    mission_set, "data_path", dir;
    mission_set, "date", days(i);

    pnav_file = autoselect_pnav(dir);
    if(pnav_file)
      mission_set, "pnav file", pnav_file;

    ins_file = autoselect_iexpbd(dir);
    if(ins_file)
      mission_set, "ins file", ins_file;

    ops_conf_file = autoselect_ops_conf(dir);
    if(ops_conf_file)
      mission_set, "ops_conf file", ops_conf_file;

    cir_dir = autoselect_cir_dir(dir);
    if(cir_dir)
      mission_set, "cir dir", cir_dir;

    rgb_dir = autoselect_rgb_dir(dir);
    if(rgb_dir)
      mission_set, "rgb dir", rgb_dir;

    rgb_tar = autoselect_rgb_tar(dir);
    if(rgb_tar)
      mission_set, "rgb file", rgb_tar;
  }
}

func autoselect_ops_conf(dir) {
/* DOCUMENT ops_conf_file = autoselect_ops_conf(dir)

  This function attempts to determine the ops_conf.i file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function attempts to find an appropriate ops_conf.i file by following
  these steps:

    1. Is there a file named ops_conf.i in dir? If so, it is returned.
    2. Do any files in dir match ops_conf*.i? If so, those files are sorted
       by name and the last is returned.
    3. The same as 1, except looking in dir's parent directory.
    4. The same as 2, except looking in dir's parent directory.

  If no file can be found, then the nil string is returned (string(0)).
*/
// Original David Nagle 2009-02-04
  dir = file_join(dir);
  dirs = [dir, file_dirname(dir)];

  for(i = 1; i <= numberof(dirs); i++) {
    dir = dirs(i);

    if(file_isfile(file_join(dir, "ops_conf.i")))
      return file_join(dir, "ops_conf.i");

    files = lsfiles(dir, glob="ops_conf*.i");
    if(numberof(files)) {
      files = files(sort(files));
      return file_join(dir, files(0));
    }
  }

  return string(0);
}

func autoselect_edb(dir) {
/* DOCUMENT edb_file = autoselect_edb(dir)

  This function attempts to determine the EAARL edb file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  The function will return the first file (sorted) that matches
  dir/eaarl/*.idx. If no files match, string(0) is returned.
*/
// Original David Nagle 2009-02-04
  files = lsfiles(file_join(dir, "eaarl"), glob="*.idx");
  if(numberof(files))
    return file_join(dir, "eaarl", files(sort(files))(1));
  else
    return string(0);
}

func autoselect_cir_dir(dir) {
/* DOCUMENT cir_dir = autoselect_cir_dir(dir)
  This function attempts to determine the EAARL cir directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "cir" exists, it will be returned. Otherwise, string(0)
  is returned.
*/
// Original David B. Nagle 2009-05-12
  cir_dir = file_join(dir, "cir");
  if(file_isdir(cir_dir))
    return cir_dir;
  cir_dir = file_join(dir, "nir");
  if(file_isdir(cir_dir))
    return cir_dir;
  return string(0);
}

func autoselect_rgb_dir(dir) {
/* DOCUMENT rgb_dir = autoselect_rgb_dir(dir)
  This function attempts to determine the EAARL rgb directory to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  If a subdirectory "rgb" or "cam1" exists, it will be returned. Otherwise,
  string(0) is returned.
*/
// Original David B. Nagle 2009-05-12
  dirs = ["rgb", "cam1"];
  for(i = 1; i <= numberof(dirs); i++) {
    rgb_dir = file_join(dir, dirs(i));
    if(file_isdir(rgb_dir))
      return rgb_dir;
  }
  return string(0);
}

func autoselect_rgb_tar(dir) {
/* DOCUMENT rgb_tar = autoselect_rgb_tar(dir)
  This function attempts to determine the EAARL rgb tar file to load for a
  dataset. The dir parameter should be the path to the mission day directory.

  Three patterns are checked, in this order: *-cam1.tar, cam1-*.tar, and
  cam1.tar. The first pattern that matches any files will be used; if
  multiple files match that pattern, then the files are sorted and the first
  is returned. If no matches are found, string(0) is returned.
*/
// Original David B. Nagle 2009-05-12
  globs = ["*-cam1.tar", "cam1-*.tar", "cam1.tar"];
  for(i = 1; i <= numberof(globs); i++) {
    files = lsfiles(dir, glob=globs(i));
    if(numberof(files)) {
      files = files(sort(files));
      return file_join(dir, files(1));
    }
  }
  return string(0);
}

func auto_mission_conf(dir, strict=, load=, autoname=) {
/* DOCUMENT json_file = auto_mission_conf(dir, strict=, load=, autoname=)
  This automatically gets a mission configuration defined for the dataset
  living at the specified dir. It then returns the name of the JSON file
  that was automatically determined.

  If there is no JSON file in dir, then one will be created using
  mission_initialize_from_path. It will be saved using the value of
  autoname=, which is "auto_mission_conf.json" by default.

  If there is exactly one *.json file in the dir, then that file's name will
  be returned.

  If there are multiple *.json files in the dir, then the list of files is
  sorted and the first is returned.

  The JSON file will be just the filename, which will be relative to dir.

  By default, the JSON file found or created will also be loaded. If you'd
  rather it not be, use load=0 to keep any existing mission_conf in effect.

  If mission_initialize_from_path is used, the strict= option is passed
  through to it untouched. See that function for information on how it's
  used and what its default is.
*/
// Original David B. Nagle 2009-04-03
  default, load, 1;
  default, autoname, "auto_mission_conf.json";

  json_files = lsfiles(dir, glob="*.json");
  if(numberof(json_files)) {
    json_files = json_files(sort(json_files));
    json_file = json_files(1);
  } else {
    backup_path = mission_path();
    backup_conf = mission_json_export();

    mission_initialize_from_path, dir, strict=strict;
    json_file = autoname;
    mission_save, file_join(dir, json_file);

    mission_path, backup_path;
    mission_json_import, backup_conf;
  }

  if(load)
    mission_load, file_join(dir, json_file);

  return json_file;
}

func set_sf_bookmarks(controller) {
/* DOCUMENT set_sf_bookmarks, controller;
  Used internally by the mission_conf GUI when creating SF instances to set
  bookmarks for an entire mission.
*/
  days = missionday_list();
  env_backup = missiondata_wrap("edb");
  for(i = 1; i <= numberof(days); i++) {
    if(mission_has("edb file", day=days(i))) {
      missiondata_load, "edb", day=days(i);
      soe = long(edb.seconds(min));
      tkcmd, swrite(format="%s bookmark add %d {%s}",
        controller, soe, days(i) + " (edb start)");
      soe = long(edb.seconds(max));
      tkcmd, swrite(format="%s bookmark add %d {%s}",
        controller, soe, days(i) + " (edb end)");
    }
  }
  missiondata_unwrap, env_backup;
}

func set_sf_bookmark(controller, day) {
/* DOCUMENT set_sf_bookmark, controller, day;
  Used internally by the mission_conf GUI when creating SF instances to set
  bookmarks for a single mission day.
*/
  if(mission_has("edb file", day=day)) {
    env_backup = missiondata_wrap("edb");
    missiondata_load, "edb", day=day;
    soe = long(edb.seconds(min));
    tkcmd, swrite(format="%s bookmark add %d {%s}",
      controller, soe, day + " (edb start)");
    soe = long(edb.seconds(max));
    tkcmd, swrite(format="%s bookmark add %d {%s}",
      controller, soe, day + " (edb end)");
    missiondata_unwrap, env_backup;
  }
}

func mission_edb_summary(nil) {
/* DOCUMENT mission_edb_summary;
  Wrapper around edb_summary that calls it with the list of edb files defines
  in the current mission configuration.
*/
  days = missionday_list();
  days = days(sort(days));
  edblist = [];
  for(i = 1; i <= numberof(days); i++) {
    filename = mission_get("edb file", day=days(i));
    if(!is_void(filename))
      grow, edblist, filename;
  }
  edb_summary, edblist;
}
