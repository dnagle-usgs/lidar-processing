// vim: set ts=2 sts=2 sw=2 ai sr et:

local plugins;
/* DOCUMENT plugins
  Documentation for the ALPS plugin system.

  Plugins are optional components that can be plugged into an ALPS session.
  These optional components introduce additional functionality, such as
  specialized processing routines for specific data sources.

  Plugins must be kept in an plugins subdirectory. Each plugin has its own
  subdirectory in the plugins subdirectory. The plugin's subdirectory is given
  the name of the plugin (and thus in turn specifies the plugin's name) and
  must be an alphanumeric string beginning with an alphabetic character (that
  is, it must match [A-Za-z][A-Za-z0-9]*).
  
  Each plugin directory must contain a JSON file named "manifest.json" that
  provides details on the plugin. Here is an example of JSON content showing
  all the permissible fields:

    {
      "description": "Short plugin description",
      "yorick": {
        "auto": "auto.i",
        "load": "load.i"
      },
      "tcl": {
        "auto": "auto.tcl",
        "load": "load.tcl"
      },
      "requires": [
        "requiredplugin1", "requiredplugin2"
      ],
      "conflicts": [
        "conflictingplugin1", "conflictingplugin2"
      ]
    }

  The "description" field is mandatory and should be a short, few word
  description of the plugin. For example, "EAARL-B processing".

  The "yorick" entry should be a sub-object with keys "auto" and/or "load".
  These should each be file names relative to the plugin directory. By
  convention, "auto.i" and "load.i" are used. The "yorick" entry is optional,
  as are its sub-entries. If present, yorick.auto defines a file that should be
  loaded automatically at ALPS start-up and yorick.load defines a file that
  should be loaded if the plugin is to be loaded. Note that code in yorick.auto
  must be very careful not to do anything that might conflict with other
  plugins.

  The "tcl" entry is much like the "yorick" entry. By convention, the names
  "auto.tcl" and "load.tcl" are used for its files, and they serve the same
  purpose as for Yorick. These are all optional as well.

  The "requires" entry is a list of other plugins that are required by this
  plugin. This field is optional. If either of yorick.load or tcl.load are
  defined, then the required plugins will be loaded prior to loading this
  plugin. However, no check is made for requirements when loading yorick.auto
  or tcl.auto if they are present. (Note: circular requirements are not allowed
  and will result in an infinite loop if present.)

  The "conflicts" entry is a list of other plugins that conflict with this
  plugin. This field is optional. If any of the listed plugins have been
  loaded, then this plugin will not be able to be loaded (unless ALPS is
  restarted). Conflicts are always interpreted as mutually exclusive; that is,
  only one in a pair needs to note the conflict for it to apply to both.

  The auto entries (yorick.auto and tcl.auto) are not intended to provide
  functionality. Rather, their primary intent is to provide hooks for loading
  the plugin. For example, tcl.auto might add menu entries.

  The load entries (yorick.load and tcl.load) should load all of the
  functionality. (Note that tcl.load might also add menu entries.)

  If Yorick code is present, it should reside in the base plugin directory. If
  Tcl code is present, most of it should be organized into package files
  located under a tcl subdirectory.

  SEE ALSO: plugins_list, plugins_loaded, plugins_load, plugins_autoload
*/

local __plugins__;
/* DOCUMENT __plugins__
  Variable used internally by plugin functions for maintaining state and such.
  This variable should not be used or modified outside of plugins.i.
  SEE ALSO: plugins, plugins_list, plugins_loaded, plugins_load,
    plugins_autoload
*/
if(is_void(__plugins__))
  __plugins__ = save(loaded=[], conflicts=[], auto=0);

func plugins_list(void, verbose=) {
/* DOCUMENT plugins_list, verbose=
  -or- names = plugins_list()

  If called as a subroutine, will display a list of the plugins available. If
  verbose=1, details for each plugin will be displayed as well.

  If called as a function, an array of the plugin names will be returned.

  SEE ALSO: plugins, plugins_loaded, plugins_load, plugins_autoload
*/
  extern src_path;
  default, verbose, 0;
  manifests = find(file_join(src_path, "../plugins"), searchstr="manifest.json");
  names = file_tail(file_dirname(manifests));
  if(!am_subroutine())
    return names;
  count = numberof(manifests);
  for(i = 1; i <= count; i++) {
    manifest = manifests(i);
    name = names(i);
    data = json_decode(rdfile(manifest));
    write, format=" - %s", name;
    if(is_string(data.description))
      write, format=": %s", data.description;
    if(anyof(__plugins__.loaded == name))
      write, format="%s", " (loaded)";
    write, format="%s", "\n";
    if(verbose) {
      if(is_hash(data.yorick)) {
        if(is_string(data.yorick.auto))
          write, format="     Yorick auto: %s\n", data.yorick.auto;
        if(is_string(data.yorick.load))
          write, format="     Yorick load: %s\n", data.yorick.load;
      }
      if(is_hash(data.tcl)) {
        if(is_string(data.tcl.auto))
          write, format="     Tcl auto: %s\n", data.tcl.auto;
        if(is_string(data.tcl.load))
          write, format="     Tcl load: %s\n", data.tcl.load;
      }
      if(numberof(data.requires))
        write, format="     Requires: %s\n", strjoin(data.requires, ", ");
      if(numberof(data.conflicts))
        write, format="     Conflicts: %s\n", strjoin(data.conflicts, ", ");
    }
  }
}

func plugins_loaded(void) {
/* DOCUMENT plugins_loaded()
  Returns a list of the currently loaded plugins.

  SEE ALSO: plugins, plugins_list, plugins_load, plugins_autoload
*/
  return __plugins__.loaded;
}

func plugins_load(name, force=) {
/* DOCUMENT plugins_load, name, force=
  Loads the specified plugin, given by NAME. The plugin's name is the directory
  it is contained in. An array of plugin names may also be provided to load
  multiple plugins at once.

  If the specific plugin requires any additional plugins, they will also be
  loaded.

  If the plugin (or any of its requirements) are not found, an error will be
  generated.

  If the plugin conflicts with a plugin that's already loaded, an error will be
  raised.

  If the plugin has already been loaded, this is a no-op.

  If force=1, then conflicts are disregarded with a warning message and the
  plugin will be loaded anyway. It will also be re-loaded if it was already
  loaded. Use of force=1 is highly discouraged.

  SEE ALSO: plugins, plugins_list, plugins_loaded, plugins_autoload
*/
  if(numberof(name) > 1) {
    for(i = 1; i <= numberof(name); i++)
      plugins_load, name(i), force=force;
    return;
  }
  name = name(1);
  if(!force && anyof(__plugins__.loaded == name))
    return;
  manifest = find(file_join(src_path, "../plugins", name),
    searchstr="manifest.json");
  if(numberof(manifest) != 1)
    error, "unable to locate manifest for"+pr1(name);
  manifest = manifest(1);
  data = json_decode(rdfile(manifest));
  conflicts = (
    anyof(__plugins__.conflicts == name) ||
    numberof(set_intersection(__plugins__.loaded, data.conflicts))
  );
  if(conflicts) {
    if(force)
      write, "WARNING: loading plugin despite conflicts";
    else
      error, "cannot load plugin due to conflicts";
  }
  save, __plugins__,
    conflicts=grow(__plugins__.conflicts, data.conflicts);
  for(i = 1; i <= numberof(data.requires); i++) {
    plugins_load, data.requires(i);
  }
  base = file_dirname(manifest);
  if(data.yorick && data.yorick.load)
    include, file_join(base, data.yorick.load), 1;
  if(_ytk && data.tcl && data.tcl.load)
    tkcmd, swrite(format="source {%s}", file_join(base, data.tcl.load)), async=0;
  save, __plugins__,
    loaded=grow(__plugins__.loaded, name);
  if(_ytk)
    tkcmd, swrite(format="lappend ::plugins::loaded {%s}", name), async=0;
}

func plugins_autoload(void) {
/* DOCUMENT plugins_autoload
  Loads any autoload directives in the detected plugins' manifests.

  SEE ALSO: plugins, plugins_list, plugins_loaded, plugins_load
*/
  if(__plugins__.auto) {
    if(logger(warn))
      logger, warn, "plugins_autoload: autoloads were already processed";
    return;
  }
  manifests = find(file_join(src_path, "../plugins"), searchstr="manifest.json");
  for(i = 1; i <= numberof(manifests); i++) {
    data = json_decode(rdfile(manifests(i)));
    base = file_dirname(manifests(i));
    if(data.yorick && data.yorick.auto)
      include, file_join(base, data.yorick.auto), 1;
    if(_ytk && data.tcl && data.tcl.auto)
      tkcmd, swrite(format="source {%s}", file_join(base, data.tcl.auto)), async=0;
  }
  save, __plugins__, auto=1;
}

if(_ytk)
  tkcmd, "package require plugins";
