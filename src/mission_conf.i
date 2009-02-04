// vim: set tabstop=4 softtabstop=4 shiftwidth=4 autoindent shiftround expandtab:
require, "eaarl.i";
require, "json.i";
write, "$Id$";

local mission_conf;
/* DOCUMENT mission_conf
    This global variable contains the data representing the current mission's
    configuration.

    The various mission_* functions in mission_conf.i interact and use
    mission_conf behind the scenes. Users are recommended to use those
    functions instead of interacting with mission_conf directly.
*/

local mission_date;
/* DOCUMENT mission_date
    This global variable is a scalar string representing the mission date
    that's currently of interest.

    The various mission_* functions in mission_conf.i use this as the default
    for their date= parameters, when applicable.
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

if(is_void(mission_conf))
    mission_conf = h_new();

if(is_void(mission_date))
    mission_date = "";

if(is_void(__mission_cache))
    __mission_cache = h_new();

if(is_void(__mission_settings))
    __mission_settings = h_new("use cache", 0);

func mission_get(key, date=) {
/* DOCUMENT mission_get(key, date=)
    Retrieves the value corresponding key for the current mission day, or for
    the mission day specified by date= if present.
*/
    extern mission_conf, mission_date;
    default, date, mission_date;
    if(!h_has(mission_conf, date))
        return [];
    obj = h_get(mission_conf, date);
    if(!h_has(obj, key))
        return [];
    return h_get(obj, key);
}

func mission_set(key, value, date=) {
/* DOCUMENT mission_set, key, value, date=
    Sets the value for the given key to the value given for the current mission
    day, or for the mission day specified by date= if present.
*/
    extern mission_conf, mission_date;
    default, date, mission_date;

    if(date == "")
        error, "Please provide date= or set mission_date.";

    if(!h_has(mission_conf, date))
        h_set, mission_conf, date, h_new();
    obj = h_get(mission_conf, date);
    h_set, obj, key, value;
}

func mission_has(key, date=) {
/* DOCUMENT mission_has(key, date=)
    Returns boolean indicating whether the current mission day (or the mission
    day specified by date=, if present) has a value for the specified key.
*/
    extern mission_conf, mission_date;
    default, date, mission_date;
    if(!h_has(mission_conf, date))
        return 0;
    obj = h_get(mission_conf, date);
    return h_has(obj, key);
}

func mission_keys(void, date=) {
/* DOCUMENT mission_keys(date=)
    Returns a list of the keys defined for the current mission day, or the
    mission day specified by date= if present.
*/
    extern mission_conf, mission_date;
    default, date, mission_date;
    if(!h_has(mission_conf, date))
        return [];
    return h_keys(h_get(mission_conf, date));
}

func mission_dates(void) {
/* DOCUMENT mission_dates()
    Returns an array of the mission dates currently defined.
*/
    extern mission_conf;
    dates = h_keys(mission_conf);
    return dates(sort(dates));
}

func mission_delete(key, date=) {
/* DOCUMENT mission_delete, key, date=
    Deletes the value for the specified key for the current mission day, or the
    mission day specified by date= if present.
*/
    extern mission_conf, mission_date;
    default, date, mission_date;

    if(date == "")
        error, "Please provide date= or set mission_date.";

    if(h_has(mission_conf, date)) {
        obj = h_get(mission_conf, date);
        h_pop, obj, key;
    }
}

func mission_delete_date(date) {
/* DOCUMENT mission_delete_date, date
    Deletes the specified mission day.
*/
    extern mission_conf;
    h_pop, mission_conf, date;
}

func mission_json_export(void) {
/* DOCUMENT mission_json_export()
    Returns a json string that represents the current mission configuration.
*/
    extern mission_conf;
    return yorick2json(mission_conf);
}

func mission_json_import(json) {
/* DOCUMENT mission_json_import, json
    Loads the mission configuration defined in the given json string.
*/
    extern mission_conf;
    mission_conf = json2yorick(json);
}

func mission_save(filename) {
/* DOCUMENT mission_save, filename
    Writes the current mission configuration to the specified file, in JSON
    format.
*/
    extern mission_conf;
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
    extern mission_conf;
    f = open(filename, "r");
    json = rdfile(f)(sum);
    close, f;
    mission_json_import, json;
}

func mission_send(void) {
/* DOCUMENT mission_send
    Sends the mission configuration as defined in Yorick to Tcl.
*/
    extern mission_conf, mission_date;
    json = mission_json_export();
    tkcmd, swrite(format="mission_json_import {%s}", json);
    tkcmd, swrite(format="set mission_date {%s}", mission_date);
}

func mission_receive(void) {
/* DOCUMENT mission_receive
    Asks Tcl to update Yorick with the mission configuration as defined in Tcl.
*/
    tkcmd, "after idle [list after 0 mission_send]";
}

func mission_initialize_from_path(mission_path) {
/* DOCUMENT mission_initialize_from_path, mission_path

    This will clear mission_conf and attempt to initialize it automatically.
    For each mission day in the mission path (identified by those directories
    whose names contain a date string), it will attempt to locate and define a
    pnav file, dmars file, ops_conf.i file, and edb file.
*/
// Original David Nagle 2009-02-04
    extern mission_conf, mission_date;
    mission_conf = h_new();
    dirs = lsdirs(mission_path);
    dates = get_date(dirs);
    w = where(dates);
    if(!numberof(w))
        return;
    dirs = dirs(w);
    dates = dates(w);
    for(i = 1; i <= numberof(dates); i++) {
        mission_date = dates(i);
        dir = file_join(mission_path, dirs(i));

        edb_file = autoselect_edb(dir);
        if(!edb_file)
            continue;
        mission_set, "edb file", edb_file;

        pnav_file = autoselect_pnav(dir);
        if(pnav_file)
            mission_set, "pnav file", pnav_file;

        dmars_file = autoselect_iexpbd(dir);
        if(dmars_file)
            mission_set, "dmars file", dmars_file;

        ops_conf_file = autoselect_ops_conf(dir);
        if(ops_conf_file)
            mission_set, "ops_conf file", ops_conf_file;
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
    dataset. The dir paremeter should be the path to the mission day directory.

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
