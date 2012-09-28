// vim: set ts=2 sts=2 sw=2 ai sr et:

/*******************************************************************************

  Programmer notes
  ----------------

  Many of the commands available through mission are extendible to add new
  subcommands. This explains how to add a new subcommand, using "mission,
  flights, ..." as an example.

  All subcommand functions should be given a name that matches the patterns of
  the command's other subcommands. This is gernerally mission_<CMD>_<SUBCMD>.
  Each command has a specified number of parameters that it expects its
  subcommands to accept, regardless of how many they actually use. If a
  subcommand needs fewer parameters than what it is expected to accept, it must
  still accept the extras but it may quietly ignore them.

  Each command is implemented as a closure. The closure contains a data element
  that is an oxy object associating subcommand names to functions. The first
  argument to each subcommand will be given mission.data, for convenience sake.

  Here is a basic framework for adding a new subcommand "auto" to "mission,
  flights".

    scratch = save(scratch, mission_flights_auto);
    func mission_flights_auto(data, path, nil) {
      // initialize configuration here
    }
    save, mission.flights.data, auto=mission_flights_auto;
    restore, scratch;

  Note that the subcommand should also have documentation provided for it!

*******************************************************************************/

local mission;
/* DOCUMENT mission
  Store and manages the mission configuration. This is an oxy object and thus
  contains both data and functions. It is expected that end-users will not need
  to interact with this object directly, as they will be using the Mission
  Configuration GUI.

  Some of the functionality of this object is defined in core ALPS. However, it
  also expects plugins to extend its functionality to become actually useful.

  For brevity, the documentation for mission is broken out into sections.

  Topics:
    mission_data - Details on the data stored in mission.data
*/

scratch = save(scratch, tmp, mission_plugins, mission_cache, mission_flights,
  mission_details, mission_get, mission_has, mission_json, mission_save,
  mission_read, mission_tksync);
tmp = save(data, plugins, cache, flights, details, get, has, json, save, read,
  tksync);

local mission_data;
/* DOCUMENT mission.data
  Stores the data used by the mission object. This is an oxy group object that
  contains the following:

    mission.data.plugins - Array of strings specifying which plugins are
      required.
      
    mission.data.path - Scalar string specifying the path to the mission
      dataset. This is the master path; all other paths are relative to it.

    mission.data.cache_mode - Scalar string specifying how the cache should be
      used. This can be one of three values:
        "disabled" - no caching will be done
        "onload" - data will be cached at load
        "onchange" - data will be cached whenever a new flight is loaded
      The "disabled" setting means data will be loaded from file each time a
      flight is loaded, which can be time intensive. The "onload" setting will
      cache the data the first time is loaded; future loads for that flight
      will retrieve that data from the cache. However, any changes you make
      (such as to ops_conf) will be lost when changing flights. The "onchange"
      setting allows you to preserve such changes: when a different flight is
      loaded, the current's flight data is cached as it currently is for future
      retrieval. Note that changing this setting does NOT change what's
      currently stored in the cache. It may be advisable to use 'mission,
      cache, "clear"' and/or 'mission, cache, "preload"' after changing this
      setting.

    The above three settings can be queried as they are shown. They can also be
    modified directly:
    
      mission, data, plugins=["eaarlb"]
      mission, data, path="/data/0/EAARL/raw/Example"
      mission, data, cache_mode="onload"

    mission.data.loaded - Scalar string specifying which flight is loaded. This
      will be void if no flights are loaded. This should not be externally
      modified.

    mission.data.conf - Oxy object containing the mission configuration. This
      will contain oxy objects with key names that are the flight names; each
      oxy object contains details for that flight as key-value pairs. Any
      key-value pairs can be defined. It is up to plugins to implement
      functionality that will apply to specific key-value pairs. Other
      key-value pairs are quietly ignored. This should not be externally
      modified, as there are subcommands to mission that allow you to do so.
      Direct modification may result in unexpected side effects.

    mission.data.cache - Oxy object containing the cached data. The structure
      of this object will mirror that of mission.data.conf; however, the
      key-value pairs will have values that are cached data (in oxy groups)
      instead of strings.
*/
data = save(
  plugins=[],
  path=[],
  loaded=[],
  cache_mode="onload",  // disabled | onload | onchange
  conf=save(),
  cache=save()
);

/*******************************************************************************
  mission, plugins, <cmd>

  Subcommands should have a call signature thus:
    mission_plugins_<SUBCMD>(data)
*/

func mission_plugins(cmds, cmd) {
/* DOCUMENT mission, plugins, cmd
  Implements subcommands for working with plugins. Documentation for
  subcommands can be found at "help, mission_plugins_SUBCMD" where SUBCMD is
  the subcommand name.

  By default, only one subcommand is defined:

    mission, plugins, "load"
      Loads the plugins currently defined in mission.data.plugins.

  This function is a closure. To see if additional subcommands are implemented,
  you can query its data member. By default, this would look like so:
    > missions.plugins.data(*,)
    ["load"]

  SEE ALSO: missions_plugins_load
*/
  if(cmds(*,cmd)) {
    cmds, noop(cmd), use(data);
    mission, tksync;
  } else {
    error, "invalid subcommand: "+pr1(cmd);
  }
}

scratch = save(scratch, cmds, mission_plugins_load);
cmds = save(load);

func mission_plugins_load(data) {
/* DOCUMENT missions, plugins, "load"
  Loads the plugins currently defined in mission.data.plugins.
*/
  plugins_load, data.plugins;
}
load = mission_plugins_load;

plugins = closure(mission_plugins, restore(cmds));
restore, scratch;

/*******************************************************************************
  mission, cache, <cmd>

  Subcommands should have a call signature thus:
    mission_cache_<SUBCMD>(data)
*/

func mission_cache(cmds, cmd) {
/* DOCUMENT mission, cache, cmd
  Implements subcommands for working with the cache. Documentation for
  subcommands can be found at "help, mission_cache_SUBCMD" where SUBCMD is
  the subcommand name.

  By default, these subcommands are defined:

  TODO

  This function is a closure. To see if additional subcommands are implemented,
  you can query its data member. By default, this would look like so:
    > missions.cache.data(*,)
    ["load"]

  SEE ALSO: 
*/
  if(cmds(*,cmd)) {
    cmds, noop(cmd), use(data);
  } else {
    error, "invalid subcommand: "+pr1(cmd);
  }
}

scratch = save(scratch, cmds, mission_cache_clear);
cmds = save(clear, preload);

func mission_cache_clear(data) {
/* DOCUMENT mission, cache, "clear"
  Clears all data currently stored in the cache.
*/
  data, cache=save();
}
clear = mission_cache_clear;

func mission_cache_preload(data) {
/* DOCUMENT mission, cache, "preload"
  If caching is enabled, this will iterate through the defined flights and load
  each one, which triggers caching. If a flight was loaded prior to calling
  this, the same flight will be set as loaded at the end. Otherwise, this has
  the side effect of loading the first flight.

  If caching is disabled, this is largely a no-op. However, for consistancy, if
  no flight is currently loaded, the first flight will be loaded.
*/
  loaded = data.loaded;

  // If cache is disabled, don't preload. But do load the first flight if
  // needed.
  if(data.cache_mode == "disabled") {
    if(is_void(loaded) && data.conf(*))
      mission, load, data.conf(*,1);
    return;
  }

  flights = mission(get,);
  count = numberof(flights);
  // Iterate backwards so that the first flight remains loaded when done (which
  // is arguable more intuitive/convenient than leaving the last one loaded)
  for(i = numberof(flights); i > 0; i--)
    mission, load, flights(i);
  if(!is_void(loaded))
    mission, load, loaded;
}
preload = mission_cache_preload;

cache = closure(mission_cache, restore(cmds));
restore, scratch;

/*******************************************************************************
  mission, flights, <cmd>

  Subcommands should have a call signature thus:
    mission_flights_<SUBCMD>(data, p1, p2)

  Plugins are encouraged to add a subcommand "auto" that will auto-initialize
  all flights given a directory name:
    mission_flights_auto(data, path, nil)
*/

func mission_flights(cmds, cmd, p1, p2) {
/* DOCUMENT mission, flights, cmd, p1, p2
  Implements subcommands for modifying the configuration for flights.
  Documentation for subcommands can be found at "help, mission_flights_SUBCMD"
  where SUBCMD is the subcommand name.

  By default, these subcommands are defined:

    mission, flights, "add", "<name>"
      Adds a flight with the given name.
    mission, flights, "remove", "<name>"
      Remvoes the flight with the given name.
    mission, flights, "rename", "<oldname>", "<newname>"
      Renames the specified flight.
    mission, flights, "swap", <idx1>, <idx2>
      Swaps two flights (given by indices) in the ordering.
    mission, flights, "raise", "<name>"
      Raises the specified flight in the ordering.
    mission, flights, "lower", "<name>"
      Lowers the specified flight in the ordering.
    mission, flights, "clear"
      Removes all flights.

  This function is a closure. To see if additional subcommands are implemented,
  you can query its data member. By default, this would look like so:
    > missions.flights.data(*,)
    ["add","remove","rename","swap","raise","lower","clear"]

  SEE ALSO: mission_flights_add, mission_flights_remove,
    mission_flights_rename, mission_flights_swap, mission_flights_raise,
    mission_flights_lower, mission_flights_clear
*/
  if(cmds(*,cmd)) {
    cmds, noop(cmd), use(data), p1, p2;
    mission, tksync;
  } else {
    error, "invalid subcommand: "+pr1(cmd);
  }
}

scratch = save(scratch, cmds, mission_flights_add, mission_flights_remove,
  mission_flights_rename, mission_flights_swap, mission_flights_raise,
  mission_flights_lower, mission_flights_clear);
cmds = save(add, remove, rename, swap, raise, lower, clear);

func mission_flights_add(data, name, nil) {
/* DOCUMENT mission, flights, "add", "<name>"
  Adds a new flight with the given NAME. NAME must not be an empty string. It
  must also not match a flight that already exists.
*/
  if(!is_string(name) || !strlen(name))
    error, "invalid name: "+pr1(name);
  if(data.conf(*,name))
    error, "an entry already exists for "+pr1(name);
  save, data.conf, noop(name), save();
}
add = mission_flights_add;

func mission_flights_remove(data, name, nil) {
/* DOCUMENT mission, flights, "remove", "<name>"
  Removes an existing flight as specified by its NAME. NAME must be a string
  and should match an existing flight. If NAME does not match an existing
  flight, this is a no-op.
*/
  if(!is_string(name) || !strlen(name))
    error, "invalid name: "+pr1(name);
  // Delete cached data as well as conf data
  data, cache=obj_delete(data.cache, noop(name));
  data, conf=obj_delete(data.conf, noop(name));
}
remove = mission_flights_remove;

func mission_flights_rename(data, oldname, newname) {
/* DOCUMENT mission, flights, "rename", <oldname>, "<newname>"
  Renames an existing flight from OLDNAME to NEWNAME. Both names must be
  non-empty strings. OLDNAME must match an existing flight, while NEWNAME must
  not match an existing flight. (However, if OLDNAME==NEWNAME, this is a
  no-op.)
*/
  if(!is_string(oldname) || !strlen(oldname))
    error, "invalid name: "+pr1(oldname);
  if(!is_string(newname) || !strlen(newname))
    error, "invalid name: "+pr1(newname);
  if(!data.conf(*,oldname))
    error, "unknown name: "+pr1(oldname);
  if(oldname == newname)
    return;
  if(data.conf(*,newname))
    error, "an entry already exists for "+pr1(newname);
  // Create new entries for cache and conf at the new name
  if(data.cache(*,oldname))
    save, data.cache, noop(newname), data.cache(noop(oldname));
  save, data.conf, noop(newname), data.conf(noop(oldname));
  // Swap the positions of the old and new names in conf
  mission, flights, "swap", data.conf(*,oldname), data.conf(*);
  // Remove entries under old name
  data, cache=obj_delete(data.cache, noop(oldname));
  data, conf=obj_delete(data.conf, noop(oldname));
}
rename = mission_flights_rename;

func mission_flights_swap(data, idx1, idx2) {
/* DOCUMENT mission, flights, "swap", <idx1>, <idx2>
  Swaps the two flights as given by numeric index. This simply reorders the
  sequence of the flights. Each index must be an integer between 1 and the
  number of flights.
*/
  if(!is_integer(idx1) || idx1 < 1 || idx1 > data.conf(*))
    error, "invalid idx1: "+pr1(idx1);
  if(!is_integer(idx2) || idx2 < 1 || idx2 > data.conf(*))
    error, "invalid idx2: "+pr1(idx2);
  // No need to swap if they are the same
  if(idx1 == idx2)
    return;
  w = indgen(data.conf(*));
  w([idx1,idx2]) = [idx2,idx1];
  data, conf=data.conf(noop(w));
}
swap = mission_flights_swap;

func mission_flights_raise(data, name, nil) {
/* DOCUMENT mission, flights, "raise", "<name>"
  Raise flight NAME up by one position. NAME must be a non-empty string
  matching an existing flight. If the flight is already first in the list, this
  is a no-op.
*/
  if(!is_string(name) || !strlen(name))
    error, "invalid name: "+pr1(name);
  idx = data.conf(*,name);
  if(idx == 1) return;
  mission, flights, "swap", idx, idx-1;
}
raise = mission_flights_raise;

func mission_flights_lower(data, name, nil) {
/* DOCUMENT mission, flights, "raise", "<name>"
  Lower flight NAME down by one position. NAME must be a non-empty string
  matching an existing flight. If the flight is already last in the list, this
  is a no-op.
*/
  if(!is_string(name) || !strlen(name))
    error, "invalid name: "+pr1(name);
  idx = data.conf(*,name);
  if(idx == data.conf(*)) return;
  mission, flights, "swap", idx, idx+1;
}
lower = mission_flights_lower;

func mission_flights_clear(data, nil1, nil2) {
/* DOCUMENT mission, flights, "clear"
  Removes all flights (which means it clears the entire mission configuration).
*/
  data, conf=save(), cache=save();
}
clear = mission_flights_clear;

flights = closure(mission_flights, restore(cmds));
restore, scratch;

/*******************************************************************************
  mission, details, <cmd>

  Subcommands should have a call signature thus:
    mission_details_<SUBCMD>(data, flight, p1, p2)

  Plugins are encouraged to add a subcommand "auto" that will auto-initialize
  the flight given a directory name:
    mission_details_auto(data, flight, path, nil)
*/

func mission_details(cmds, cmd, flight, p1, p2) {
/* DOCUMENT mission, details, cmd, flight, p1, p2
  Implements subcommands for modifying the configuration details for a given
  fight.  Documentation for subcommands can be found at "help,
  mission_details_SUBCMD" where SUBCMD is the subcommand name.

  By default, these subcommands are defined:

    mission, details, "set", "<flight>", "<key>", "<val>"
      Add or update a key-value pair.
    mission, details, "rename", "<flight>", "<oldkey>", "<newkey>"
      Renames a key.
    mission, details, "remove", "<flight>", "<key>"
      Removes a key-value pair.
    mission, details, "swap", "<flight>", <idx1>, <idx2>
      Swaps the positiosn of two key-value pairs.
    mission, details, "raise", "<flight>", "<key>"
      Raises a key-value pair in the sequence.
    mission, details, "lower", "<flight>", "<key>"
      Lowers a key-value pair in the sequence.
    mission, details, "clear", "<flight>"
      Clears all key-value pairs for a given flight.

  This function is a closure. To see if additional subcommands are implemented,
  you can query its data member. By default, this would look like so:
    > missions.flights.data(*,)
    ["set","rename","remove","swap","raise","lower","clear"]

  SEE ALSO: mission_details_set, mission_details_rename,
    mission_details_remove, mission_details_swap, mission_details_raise,
    mission_details_lower, mission_details_clear
*/
  if(cmds(*,cmd)) {
    cmds, noop(cmd), use(data), flight, p1, p2;
    mission, tksync;
  } else {
    error, "invalid subcommand: "+pr1(cmd);
  }
}

scratch = save(scratch, mission_details_set, mission_details_rename,
  mission_details_remove, mission_details_swap, mission_details_raise,
  mission_details_lower, mission_details_clear);
cmds = save(set, rename, remove, swap, raise, lower, clear);

func mission_details_set(data, flight, key, val) {
/* DOCUMENT mission, details, "set", "<flight>", "<key>", "<val>"
  Sets the given KEY-VAL association for the specified FLIGHT. FLIGHT must be a
  non-empty string that matches an existing flight. KEY must also both be
  non-emptry string and VAL must be a string (but can be empty). If KEY already
  exists, its associated value will be updated; if it does not exist, it will
  be added to the details for the given flight.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  if(!is_string(key) || !strlen(key))
    error, "invalid key: "+pr1(key);
  if(!is_string(val))
    error, "invalid val: "+pr1(val);

  // If the key already exists and has the same value, this is a no-op
  fconf = data.conf(noop(flight));
  if(fconf(*,key) && fconf(noop(key)) == val)
    return;

  // Remove the cached data for this key, if necessary
  if(data.cache(*,flight)) {
    fcache = data.cache(noop(flight));
    save, data.cache, noop(flight), obj_delete(fcache, noop(key));
  }

  save, data.conf(noop(flight)), noop(key), val;
}
set = mission_details_set;

func mission_details_rename(data, flight, oldkey, newkey) {
/* DOCUMENT mission, details, "rename", "<flight>", "<oldkey>", "<newkey>"
  Renames the given OLDKEY to NEWKEY for the specified FLIGHT. FLIGHT, OLDKEY,
  and NEWKEY must all be non-empty strings. FLIGHT must match an existing
  flight and OLDKEY must match an existing key for that flight. If OLDKEY and
  NEWKEY are the same, this is a no-op. NEWKEY may not match any other existing
  key for that flight.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  if(!is_string(oldkey) || !strlen(oldkey))
    error, "invalid oldkey: "+pr1(oldkey);
  if(!is_string(newkey) || !strlen(newkey))
    error, "invalid newkey: "+pr1(newkey);

  fconf = data.conf(noop(flight));
  // Check that oldkey exists
  if(!fconf(*,oldkey))
    error, "invalid oldkey: "+pr1(oldkey);
  // No-op if keys match
  if(oldkey == newkey)
    return;
  // Error if newkey otherwise exists
  if(fconf(*,newkey))
    error, "newkey conflicts with existing key: "+pr1(newkey);

  // Remove the cached data for this key, if necessary. (Do -not- rename it,
  // since it's possible that it may get loaded differently under the new key
  // name.)
  if(data.cache(*,flight)) {
    fcache = data.cache(noop(flight));
    save, data.cache, noop(flight), obj_delete(fcache, noop(oldkey));
  }

  // Create new entry, swap position with old entry, then remove old
  // (fconf is redefined repeatedly in case the reference in data.conf changes)
  save, data.conf(noop(flight)), noop(newkey), fconf(noop(oldkey));
  fconf = data.conf(noop(flight));
  mission, details, "swap", flight, fconf(*,oldkey), fconf(*);
  fconf = data.conf(noop(flight));
  save, data.conf, noop(flight), obj_delete(fconf, noop(oldkey));
}
rename = mission_details_rename;

func mission_details_remove(data, flight, key, nil) {
/* DOCUMENT mission, details, "remove", "<flight>", "<key>"
  Removes the given KEY from the specified FLIGHT. FLIGHT and KEY must be
  non-empty strings. FLIGHT must match an existing flight. If KEY does not
  exist, this is a no-op.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  if(!is_string(key) || !strlen(key))
    error, "invalid key: "+pr1(key);

  // Remove the cached data for this key
  if(data.cache(*,flight)) {
    fcache = data.cache(noop(flight));
    save, data.cache, noop(flight), obj_delete(fcache, noop(key));
  }

  // Remove conf entry
  fconf = data.conf(noop(flight));
  save, data.conf, noop(flight), obj_delete(fconf, noop(key));
}
remove = mission_details_remove;

func mission_details_swap(data, flight, idx1, idx2) {
/* DOCUMENT mission, details, "swap", "<flight>", <idx1>, <idx2>
  Swaps the two key-value pairs for a given FLIGHT as given by numeric indices.
  This simply reorders the sequence of the key-value pairs. Each index must be
  an integer between 1 and the number of key-value pairs for the specified
  flight.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  fconf = data.conf(noop(flight));
  if(!is_integer(idx1) || idx1 < 1 || idx1 > fconf(*))
    error, "invalid idx1: "+pr1(idx1);
  if(!is_integer(idx2) || idx2 < 1 || idx2 > fconf(*))
    error, "invalid idx2: "+pr1(idx2);
  // No need to swap if they are the same
  if(idx1 == idx2)
    return;
  w = indgen(fconf(*));
  w([idx1,idx2]) = [idx2,idx1];
  save, data.conf, noop(flight), fconf(noop(w));
}
swap = mission_details_swap;

func mission_details_raise(data, flight, key, nil) {
/* DOCUMENT mission, details, "raise", "<flight>", "<name>"
  Raises the key-value pair identified by NAME for FLIGHT up one position in
  sequence. FLIGHT and KEY must both be non-empty strings and must match
  existing entries. If the key-value pair specified is already first, this is a
  no-op.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  fconf = data.conf(noop(flight));
  if(!is_string(key) || !strlen(key) || !fconf(*,key))
    error, "invalid key: "+pr1(key);
  idx = fconf(*,key);
  if(idx == 1) return;
  mission, details, "swap", flight, idx, idx-1;
}
raise = mission_details_raise;

func mission_details_lower(data, flight, key, nil) {
/* DOCUMENT mission, details, "lower", "<flight>", "<name>"
  Lowers the key-value pair identified by NAME for FLIGHT down one position in
  sequence. FLIGHT and KEY must both be non-empty strings and must match
  existing entries. If the key-value pair specified is already last, this is a
  no-op.
*/
  if(!is_string(flight) || !strlen(flight) || !data.conf(*,flight))
    error, "invalid flight: "+pr1(flight);
  fconf = data.conf(noop(flight));
  if(!is_string(key) || !strlen(key) || !fconf(*,key))
    error, "invalid key: "+pr1(key);
  idx = fconf(*,key);
  if(idx == fconf(*)) return;
  mission, details, "swap", flight, idx, idx+1;
}
lower = mission_details_lower;

func mission_details_clear(data, flight, nil1, nil2) {
/* DOCUMENT mission, details, "clear", "<flight>"
  Removes all key-value pairs for the given FLIGHT, which must be a non-empty
  string that already exists in the configuration.
*/
  if(!is_string(name) || !strlen(name) || !data.conf(*,name))
    error, "invalid name: "+pr1(name);
  save, data.conf, noop(name), save();
  // Delete associated cache
  data, cache=obj_delete(data.cache, noop(oldname));
}
clear = mission_details_clear;

details = closure(mission_details, restore(cmds));
restore, scratch;

/*******************************************************************************
  mission(get,)
  mission(get, "<flight>")
  mission(get, "<flight>", "<key>")

  This command does not have subcommands.
*/

func mission_get(flight, key) {
/* DOCUMENT flights = mission(get, )
  -or- keys = mission(get, "<flight>")
  -or- value = mission(get, "<flight>", "<key>")

  Retrieves information from the configuration. As shown above, this can be
  called in three ways.

  flights = mission(get,)
    Returns an array containing the names of the flights defined.

  keys = mission(get, "<flight>")
    Returns an array of key values for the specified flight, which must exist.
    If the flight doesn't exist, an error will occur.

  value = mission(get, "<flight>", "<key>")
    Returns the value associated with the given key for the specified flight.
    The flight and key must both exist, otherwise an error will occur.
*/
  if(is_void(flight))
    return use(data, conf, *, );
  if(!is_string(flight) || !strlen(flight) || !use(data, conf, *,flight))
    error, "invalid flight: "+pr1(flight);
  if(is_void(key))
    return use(data, conf, noop(flight), *, );
  fconf = use(data, conf, noop(flight));
  if(!is_string(key) || !strlen(key) || !fconf(*,key))
    error, "invalid key: "+pr1(key);
  return fconf(noop(key));
}
get = mission_get;

/*******************************************************************************
  mission(has, "<flight>")
  mission(has, "<flight>", "<key>")

  This command does not have subcommands.
*/

func mission_has(flight, key) {
/* DOCUMENT exists = mission(has, "<flight>")
  -or- exists = mission(has, "<flight>", "<key>")

  Checks to see if the specified flight or flight+key exist in the
  configuration. As shown above, this can be called in two ways.

  exists = mission(has, "<flight>")
    Returns 1 if the given FLIGHT exists in the configuration, or 0 if it does
    not.

  exists = mission(has, "<flight>", "<key>")
    Returns 1 if the given FLIGHT exists and if it has the specified KEY;
    otherwise returns 0.
*/
  if(!use(data, conf, *, flight))
    return 0;
  if(!is_void(key) && !use(data, conf, noop(flight), *, key))
    return 0;
  return 1;

  // Check to see if flight specified is valid and exists
  if(!is_string(flight) || !strlen(flight))
    error, "invalid flight: "+pr1(flight);
  if(!data.conf(*,flight))
    return 0;

  // If no key is specified, return 1 -- flight existed
  if(is_void(key))
    return 1;

  // Check to see if key specified is valid and exists
  fconf = use(data, conf, noop(flight));
  if(!is_string(key) || !strlen(key))
    error, "invalid key: "+pr1(key);
  return fconf(*,key) > 0;
}
has = mission_has;

/*******************************************************************************
  mission, load, "<flight>"

  TODO
*/

// mission, load, <flight>
// func mission_load(flight) {}

/*******************************************************************************
  mission, json, "<jsondata>"
  mission(json, compact=)

  TODO
*/

func mission_json(cmds, json, compact=) {
/* DOCUMENT mission, json, "<jsondata>"
  -or- jsondata = mission(json, compact=)
  
  If called as a subroutine, this imports a mission configuration from the
  given JSON data.

  If called as a function, this returns the current mission configuration in
  JSON format. If compact=1 is specified, the output will be more compact; this
  is primarily intended for internal use for synchronizing to Tcl.

  This command is primarily for internal use.
*/
  if(!am_subroutine())
    return cmds.export(compact);
  cmds, import, json;
  mission, tksync;
}

scratch = save(scratch, mission_json_export, mission_json_import);
cmds = save(export, import);

func mission_json_export(compact) {
/* DOCUMENT mission_json_export(compact)
  This is used internally by calls to 'mission(json, compact=)'. It exports the
  mission configuration to JSON format.
*/
  output = save(
    mcversion=2,
    flights=use(data, conf),
    plugins=use(data, plugins)
  );
  if(!compact) {
    save, output, "save environment", save(
      "path", use(data, path),
      "user", get_user(),
      "host", get_host(),
      "timestamp", soe2iso86501(getsoe()),
      "repository", _hgid
    );
  }
  return json_encode(output, indent=(compact ? [] : 2));
}
export = mission_json_export;

func mission_json_import(versions, json) {
/* DOCUMENT mission_json_import(json)
  This is used internally by calls to 'mission, json, "<jsondata>"'. It imports
  a mission configuration from JSON data.
*/
  mission, cache, "clear";
  data = json_decode(json, objects="");

  // Prior to 2012-09-27, there was no mcversion field; this is treated as
  // version 1.
  if(!data(*,"mcversion")) {
    save, data, mcversion=1;
  }
  if(is_string(data.mcversion))
    save, data, mcversion=atoi(data.mcversion);

  // Upgrade the data by passing it through each conversion function, if
  // necessary.
  for(i = data.mcversion; i <= versions(*); i++) {
    data = versions(noop(i), data);
  }

  maxversion = versions(*) + 1;
  if(data.mcversion > maxversion) {
    write, format=" WARNING: mission configuration format is version %d!\n",
      data.mcversion;
    write, format=" This version of ALPS can only handle up to version %d.\n",
      maxversion;
    write, "Attempting to use anyway, but errors may ensue...";
  }

  mission, data, conf=data.flights, plugins=data.plugins, loaded=[];
}

scratch = save(scratch, versions);
versions = save(mission_json_version1);

/*
  The format used for mission configuration files has changed over time. To
  accommodate these changes, a series of conversion functions are implemented
  to change from one version to the next. These are then stored into an object
  in version order, and that object is then bundled into the closure for the
  import command.
*/

func mission_json_version1(data) {
  // Technically speaking, there was no "version 1". Instead, this version
  // encompasses all the versions that happened before an actual version number
  // was attached to the format.

  // Convert format 2009-02-03 to format 2009-06-06
  // Change: original format stored all information at the top level; new
  // format stores that information in sub-key "days". The original format can
  // thus be detected by the absence of the "days" key.
  // Update 2012-09-27: original format must now be detected by the absence of
  // both "days" and "flights".
  if(noneof(data(*,["days","flights"]))) {
    data = save(days=data);
  }

  // Convert format 2009-06-06 to format 2010-01-28
  // Change: previous format stored INS filename as "dmars file", new format
  // stores as "ins file".
  if(data(*,"days")) {
    for(i = 1; i <= data.days(*); i++) {
      if(data.days(noop(i),*,"dmars file")) {
        save, data.days(noop(i)), "ins file", data.days(noop(i), "dmars file");
        save, data.days, noop(i), obj_delete(data.days(noop(i)), "dmars file");
      }
    }
  }

  // Convert format 2010-01-28 to format 2012-09-13
  // Change: previous format did not store plugin information, must detect by
  // date.
  if(!data(*,"plugins")) {
    date = [];
    // Scan through flights to detect the date
    for(i = 1; i <= data.days(*); i++) {
      day = data.days(noop(i));
      if(day(*,"date")) {
        date = day.date;
        break;
      }
    }
    if(date < "2012-01-01") {
      save, data, plugins=["eaarla"];
    } else {
      save, data, plugins=["eaarlb"];
    }
  }

  // Convert format 2010-01-28 to format 2012-09-27
  // Change: previous format stored flight information in "days" key, new
  // format stores in "flights" key to better reflect that a flight isn't
  // equivalent to a day. (NOTE: If both "days" and "flights" are present,
  // flights gets clobbered by days. However, this should never happen.)
  if(data(*,"days")) {
    save, data, flights=data.days;
    data = obj_delete(data, "days");
  }

  // Assume that we've properly upgraded to mcversion 2 now.
  save, data, mcversion=2;

  return data;
}

import = closure(mission_json_import, restore(versions));
restore, scratch;

json = closure(mission_json, restore(cmds));
restore, scratch;

/*******************************************************************************
  mission, save, "<filename>"
*/

func mission_save(fn) {
  f = open(fn, "w");
  write, f, format="%s\n", mission(json,);
  close, f;
}
save = mission_save;

/*******************************************************************************
  mission, read, "<filename>"
*/

func mission_read(fn) {
  mission, data, path=file_dirname(fn);
  f = open(fn, "r");
  mission, json, rdfile(f);
  close, f;
}
read = mission_read;

/*******************************************************************************
  mission, tksync
*/

func mission_tksync {}
tksync = mission_tksync;

mission = restore(tmp);
restore, scratch;
