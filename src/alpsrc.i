// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "dir.i";
require, "json_decode.i";
require, "util_container.i";

local alpsrc;
/* DOCUMENT alpsrc
  Contains global ALPS configuration settings. These settings are initialized
  by alpsrc_load (which is automatically run when alpsrc.i is loaded).

  Settings handled by alpsrc, and their defaults:

    geoid_data_root = ../../share/NAVD88
      Defines the directory in which GEOID files can be found for
      conversions between NAD83 and NAVD88. It should contain
      subdirectories such as GEOID03.

    maps_dir = ../../share/maps
      Defines the directory in which map files can be found. File reefs.i
      will use this to find fla-reefs.dat, and the plotting tool will use it as
      a default directory for the maps.

    temp_dir = /tmp
      Directory to use for temporary files. Defaults to the system /tmp
      directory.

    batcher_dir = ../batcher
      Defines the directory where the batcher scripts can be found.

    memory_autorefresh = 5
      An interval in seconds that specifies how often the Memory Usage
      indicator should be refreshed. Set to 0 to disable. This is only
      applied at start-up.

    gdal_bin = ../../gdal/bin
      Defines the directory where the GDAL binaries may be found.

    cctools_bin = ../../cctools/bin
      Defines the directory where the cctools binaries may be found.

    makeflow_opts = [none]
      Options to pass to makeflow. Use 'makeflow -h' for list of options. This
      setting should only be used for advanced options. If you want to set -T,
      -N, or -j, use makeflow_type, makeflow_project, or cores_local instead.

    makeflow_enable = 1
      Use 1 to enable use of Makeflow. Use 0 to disable. As a special case, if
      makeflow_type = "local" and cores_local = 1, then makeflow is
      auto-disabled even if makeflow_enable = 1; to force enable, use
      makeflow_enable = 2.

    makeflow_type = local
      Specifies the batch system type to use for makeflow (makeflow's -T
      option).

    makeflow_project = alps
      Specifies the project name to use for makeflow (makeflow's -N option).

    log_dir = alps.log/
      Specifies the default directory where to write out ALPS logs. This can be
      a relative path, in which case it is relative to the temp_dir. It can
      also be an absolute path.

    log_level = debug
      Specifies the default level at which to log.

    log_keep = 30
      Specifies how many days to keep log files around for.

    cores_local = [auto detected]
      Specifies how many local cores may be used. By default, the number of
      cores will be detected from /proc/cpuinfo. Makeflow will only be used if
      cores_local > 1. The special value -1 means that the core count should be
      auto-detected. This value is passed to makeflow as a maximum number of
      local jobs to run at once (makeflow's -j option). It is also used in
      initializing some settings in ALPS.

    cores_remote = 0
      This setting specifies how many remote cores may be used. It is only used
      if makeflow_type != "local".

    mission_conf_dirs = initialdir
      Specifies a default list of directories to be searched for mission
      configuration files when using the Mission Conf Browser. Multiple paths
      can be provided by separating them with commas. Be sure to only list
      EAARL raw directories. If you include EAARL processed, scan times will be
      atrocious. If not specified, this is initialized to match Ytk's
      initialdir.

  SEE ALSO: alpsrc_load
*/

func alpsrc_load(void) {
/* DOCUMENT alpsrc_load;
  This command initializes the alpsrc global variable, which stores global
  ALPS configuration settings. It loads settings from each of the following:

    * Internally defined defaults
    * /etc/alpsrc
    * ~/.alpsrc
    * .alpsrc (in the current working directory)

  Values defined by each location override any defined previously.

  All rc files are formatted in JSON are specify a hash with keys that will
  become keys in alpsrc.

  SEE ALSO: alpsrc
*/
  extern alpsrc;
  alpsrc = save();
  __alpsrc_set_defaults, alpsrc;
  __alpsrc_load_and_merge, alpsrc, "/etc/alpsrc";
  __alpsrc_load_and_merge, alpsrc, get_home() + ".alpsrc";
  __alpsrc_load_and_merge, alpsrc, "./.alpsrc";
  __alpsrc_post, alpsrc;
}

func __alpsrc_load_and_merge(&obj, fn) {
  if(file_exists(fn)) {
    obj = obj_merge(obj, json_decode(rdfile(open(fn, "r")), objects=""));
  }
}

func __alpsrc_post(&obj) {
/* DOCUMENT __alpsrc_post, obj;
  Performs some post-load operations on the alpsrc settings.
*/
  if(obj.cores_local == -1) {
    save, obj, cores_local = atoi(popen_rdfile("grep ^processor /proc/cpuinfo | wc -l"))(1);
  }
}

func __alpsrc_set_defaults(&obj) {
/* DOCUMENT __alpsrc_set_defaults, obj;
  Provides sane defaults for alpsrc settings.
*/
  // IMPORTANT: When this changes, also change tcl/alpsrc-1.0.tm
  if(is_void(obj)) obj = save();
  save, obj, batcher_dir=file_join(get_cwd(), "..", "batcher");
  // If the src directory is .../eaarl/lidar-processing/src
  // Then the share directory is .../eaarl/share
  sharedir = file_join(get_cwd(), "..", "..", "share");
  save, obj, geoid_data_root=file_join(sharedir, "NAVD88");
  save, obj, maps_dir=file_join(sharedir, "maps");
  save, obj, gdal_bin=file_join(get_cwd(), "..", "..", "gdal", "bin");
  save, obj, cctools_bin=file_join(get_cwd(), "..", "..", "cctools", "bin");
  save, obj, temp_dir="/tmp";
  save, obj, makeflow_opts="";
  save, obj, makeflow_enable=1;
  save, obj, makeflow_type="local";
  save, obj, makeflow_project="alps";
  save, obj, memory_autorefresh=5;
  save, obj, log_dir="alps.log";
  save, obj, log_level="debug";
  save, obj, log_keep=30;
  save, obj, cores_local=-1;
  save, obj, cores_remote=0;
  save, obj, mission_conf_dirs=initialdir;
}

alpsrc_load;

if(_ytk)
  tkcmd, "package require alpsrc\n::alpsrc::link";

// Purge old log files if everything is in order to allow it.
if(is_obj(alpsrc) && is_numerical(alpsrc.log_keep) && is_func(logger_purge))
  logger_purge, alpsrc.log_keep;
if(is_obj(alpsrc) && is_string(alpsrc.log_level) && is_func(logger_level)) {
  logger_level, alpsrc.log_level;
  if(_ytk)
    tkcmd, "::logger::level {"+alpsrc.log_level+"}";
}
