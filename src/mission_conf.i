// vim: set tabstop=4 softtabstop=4 shiftwidth=4 autoindent shiftround expandtab:
require, "eaarl.i";
require, "json.i";
write, "$Id$";

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
        "relative paths", ["data_path", "edb file", "pnav file", "dmars file",
            "ops_conf file", "cir dir", "rgb dir", "rgb file"]
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
    extern __mission_conf;
    default, compact, 0;
    data = h_new("days", __mission_conf);
    if(!compact) {
        soe_now = [];
        timestamp, soe_now;
        h_set, data, "save environment", h_new(
            "path", mission_path(),
            "user", get_user(),
            "host", get_host(),
            "platform", "Yorick",
            "timestamp", soe2iso8601(soe_now)
        )
    }
    return yorick2json(data, compact=compact);
}

func mission_json_import(json, sync=) {
/* DOCUMENT mission_json_import, json, sync=
    Loads the mission configuration defined in the given json string.
*/
    extern __mission_conf, __mission_settings;
    default, sync, 1;
    data = json2yorick(json);
    if(h_has(data, "days")) {
        __mission_conf = data("days");
    } else {
        __mission_conf = data;
    }

    if(__mission_settings("ytk") && sync)
        mission_send;
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
    logger, "info", "Mission configuration saved to: " + filename;
}

func mission_load(filename) {
/* DOCUMENT mission_load, filename
    Loads a mission configuration from the given filename, which must be in
    JSON format.
*/
    extern __mission_conf;
    logger, "info", "Loading mission configuration: " + filename;
    f = open(filename, "r");
    json = rdfile(f)(sum);
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

func missiondata_cache(action) {
/* DOCUMENT missiondata_cache, action
    Does something cache related, depending on the action specified.

        clear   - Clears the cache
        enable  - Enables the use of the cache
        disable - Disabled the use of the cache (but does not clear it)
        preload - Preloads the cache with each mission day's data
*/
    extern __mission_conf, __mission_day, __mission_cache, __mission_settings;
    if(action == "clear") {
        __mission_cache = h_new();
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
    }
}

func missiondata_wrap(type) {
/* DOCUMENT missiondata_wrap(type)
    Wraps currently loaded data in Yorick extern variables into a Yeti hash,
    suitable for restoring later with missiondata_unwrap.

    The type should be one of:
        all - includes all of the others
        edb
        pnav
        dmars
        ops_conf
*/
    if(is_void(type)) {
        error, "No type was provided.";
    } else if(type == "all") {
        return h_new(
            "__type", "all",
            "edb", missiondata_wrap("edb"),
            "pnav", missiondata_wrap("pnav"),
            "dmars", missiondata_wrap("dmars"),
            "ops_conf", missiondata_wrap("ops_conf")
        );
    } else if(type == "edb") {
        extern edb, edb_filename, edb_files, _ecfidx, total_edb_records,
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
        return h_new(
            "__type", "pnav",
            "pnav", pnav,
            "gga", gga,
            "pnav_filename", pnav_filename
        );
    } else if(type == "dmars") {
        extern iex_nav, iex_head, iex_nav1hz, tans;
        // ops_conf ?
        return h_new(
            "__type", "dmars",
            "iex_nav", iex_nav,
            "iex_head", iex_head,
            "iex_nav1hz", iex_nav1hz,
            "tans", tans
        );
    } else if(type == "ops_conf") {
        extern ops_conf;
        return h_new(
            "__type", "ops_conf",
            "ops_conf", ops_conf
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
        missiondata_unwrap, data.edb;
        missiondata_unwrap, data.pnav;
        missiondata_unwrap, data.dmars;
        missiondata_unwrap, data.ops_conf;
    } else if(type == "edb") {
        extern edb, edb_filename, edb_files, _ecfidx, total_edb_records,
            soe_day_start, eaarl_time_offset, data_path;
        // _edb_fd -- file handle??? also, _ecfidx
        // gps_time_correction -- shouldn't change
        edb = data.edb;
        edb_filename = data.edb_filename;
        edb_files = data.edb_files;
        total_edb_records = data.total_edb_records;
        soe_day_start = data.soe_day_start;
        eaarl_time_offset = data.eaarl_time_offset;
        data_path = data.data_path;
        _ecfidx = 0; //?
    } else if(type == "pnav") {
        extern pnav, gga, pnav_filename;
        pnav = data.pnav;
        gga = data.gga;
        pnav_filename = data.pnav_filename;
    } else if(type == "dmars") {
        extern iex_nav, iex_head, iex_nav1hz, tans;
        // ops_conf ?
        iex_nav = data.iex_nav;
        iex_head = data.iex_head;
        iex_nav1hz = data.iex_nav1hz;
        tans = data.tans;
    } else if(type == "ops_conf") {
        extern ops_conf;
        ops_conf = data.ops_conf;
    } else {
        error, swrite(format="Unknown type provided: %s", type);
    }
}

func missiondata_load(type, day=) {
/* DOCUMENT missiondata_load, type, day=
    Loads mission data for the current day, or for day= if specified.

    The type should be one of:
        all - will load all defined data
        edb
        pnav
        dmars
        ops_conf
*/
    extern __mission_conf, __mission_day, __mission_cache, __mission_settings;
    default, day, __mission_day;

    if(!day)
        error, "Please provide day= or set __mission_day.";

    if(type == "all") {
        if(mission_has("edb file", day=day))
            missiondata_load, "edb", day=day;
        if(mission_has("pnav file", day=day))
            missiondata_load, "pnav", day=day;
        if(mission_has("dmars file", day=day))
            missiondata_load, "dmars", day=day;
        if(mission_has("ops_conf file", day=day))
            missiondata_load, "ops_conf", day=day;
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
        } else {
            if(mission_has("edb file", day=day)) {
                extern data_path;
                if(mission_has("data_path", day=day))
                    data_path = mission_get("data_path", day=day);
                load_edb, fn=mission_get("edb file", day=day);
                if(cache_enabled) {
                    h_set, cache, "edb", missiondata_wrap("edb");
                }
            } else {
                error, "Could not load edb data: no edb file defined";
            }
        }
    } else if(type == "pnav") {
        if(cache_enabled && h_has(cache, "pnav")) {
            missiondata_unwrap, cache("pnav");
        } else {
            if(mission_has("pnav file", day=day)) {
                extern pnav;
                pnav = rbpnav(fn=mission_get("pnav file", day=day), verbose=0);
                if(cache_enabled) {
                    h_set, cache, "pnav", missiondata_wrap("pnav");
                }
            } else {
                error, "Could not load pnav data: no pnav file defined";
            }
        }
    } else if(type == "dmars") {
        if(cache_enabled && h_has(cache, "dmars")) {
            missiondata_unwrap, cache("dmars");
        } else {
            if(mission_has("dmars file", day=day)) {
                load_iexpbd, mission_get("dmars file", day=day), verbose=0;
                if(cache_enabled) {
                    h_set, cache, "dmars", missiondata_wrap("dmars");
                }
            } else {
                error, "Could not load dmars data: no dmars file defined";
            }
        }
    } else if(type == "ops_conf") {
        if(cache_enabled && h_has(cache, "ops_conf")) {
            missiondata_unwrap, cache("ops_conf");
        } else {
            if(mission_has("ops_conf file", day=day)) {
                extern ops_conf;
                include, mission_get("ops_conf file", day=day);
                if(cache_enabled) {
                    h_set, cache, "ops_conf", missiondata_wrap("ops_conf");
                }
            } else {
                error, "Could not load ops_conf: no ops_conf file defined";
            }
        }
    } else {
        error, swrite(format="Unknown type provided: %s", type);
    }
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
    pnav file, dmars file, ops_conf.i file, and edb file.

    If strict is 1 (which it is by default), then a mission day will not be
    initialized unless an edf file is present. If strict is 0, then that
    restriction is lifted.
*/
// Original David Nagle 2009-02-04
    extern __mission_conf, __mission_day;
    default, path, mission_path();
    default, strict, 1;

    logid = logger_id();
    logger, "debug", logid + swrite(
        format=" Entering mission_initialize_from_path(\"%s\", strict=%d)",
        path, strict);

    mission_clear;
    mission_path, path;

    dirs = lsdirs(path);
    days = get_date(dirs);
    w = where(days);
    if(!numberof(w))
        return;
    dirs = dirs(w);
    days = days(w);
    logger, "debug", logid + swrite(format=" Found %d potential days",
        numberof(days));
    for(i = 1; i <= numberof(days); i++) {
        logger, "debug", logid + swrite(format=" %d: day=%s dir=%s",
            i, days(i), dirs(i));
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

        dmars_file = autoselect_iexpbd(dir);
        if(dmars_file)
            mission_set, "dmars file", dmars_file;

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

    logger, "debug", logid + " Leaving mission_initialize_from_path";
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
    else
        return string(0);
}

func autoselect_rgb_dir(dir) {
/* DOCUMENT rgb_dir = autoselect_rgb_dir(dir)
    This function attempts to determine the EAARL rgb directory to load for a
    dataset. The dir parameter should be the path to the mission day directory.

    If a subdirectory "cam1" exists, it will be returned. Otherwise, string(0)
    is returned.
*/
// Original David B. Nagle 2009-05-12
    rgb_dir = file_join(dir, "cam1");
    if(file_isdir(rgb_dir))
        return rgb_dir;
    else
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
