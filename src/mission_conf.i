// vim: set tabstop=4 softtabstop=4 shiftwidth=4 autoindent shiftround expandtab:
require, "eaarl.i";
require, "json.i";
write, "$Id$";

if(is_void(mission_conf))
    mission_conf = h_new();

if(is_void(mission_date))
    mission_date = "";

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
