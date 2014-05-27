// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "dir.i";
require, "json_decode.i";
require, "util_container.i";
require, "yeti.i";

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

    log_dir = /tmp/alps.log/
      Specifies the default directory where to write out ALPS logs.

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
  // load default
  alpsrc = h_clone(__alpsrc_defaults);
  __alpsrc_load_and_merge, alpsrc, "/etc/alpsrc";
  __alpsrc_load_and_merge, alpsrc, "~/.alpsrc";
  __alpsrc_load_and_merge, alpsrc, "./.alpsrc";
  __alpsrc_post, alpsrc;
}

func __alpsrc_load_and_merge(&hash, fn) {
  if(file_exists(fn)) {
    hash = h_merge(hash, json_decode(rdfile(open(fn, "r"))));
  }
}

func __alpsrc_post(&hash) {
/* DOCUMENT __alpsrc_post, hash;
  Performs some post-load operations on the alpsrc settings.
*/
  if(hash.cores_local == -1) {
    h_set, hash, cores_local = atoi(popen_rdfile("grep ^processor /proc/cpuinfo | wc -l"))(1);
  }
}

func __alpsrc_set_defaults(&hash) {
/* DOCUMENT __alpsrc_set_defaults, hash;
  Sets the initial defaults for __alpsrc_defaults.
*/
  // IMPORTANT: When this changes, also change tcl/alpsrc-1.0.tm
  default, hash, h_new();
  h_set, hash, batcher_dir=file_join(get_cwd(), "..", "batcher");
  // If the src directory is .../eaarl/lidar-processing/src
  // Then the share directory is .../eaarl/share
  sharedir = file_join(get_cwd(), "..", "..", "share");
  h_set, hash, geoid_data_root=file_join(sharedir, "NAVD88");
  h_set, hash, maps_dir=file_join(sharedir, "maps");
  h_set, hash, gdal_bin=file_join(get_cwd(), "..", "..", "gdal", "bin");
  h_set, hash, cctools_bin=file_join(get_cwd(), "..", "..", "cctools", "bin");
  h_set, hash, makeflow_opts="";
  h_set, hash, makeflow_enable=1;
  h_set, hash, makeflow_type="local";
  h_set, hash, makeflow_project="alps";
  h_set, hash, memory_autorefresh=5;
  h_set, hash, log_dir="/tmp/alps.log/";
  h_set, hash, log_level="debug";
  h_set, hash, log_keep=30;
  h_set, hash, cores_local=-1;
  h_set, hash, cores_remote=0;
}

__alpsrc_set_defaults, __alpsrc_defaults;
alpsrc_load;

if(_ytk)
  tkcmd, "package require alpsrc\n::alpsrc::link";

// Purge old log files if everything is in order to allow it.
if(is_hash(alpsrc) && is_numerical(alpsrc.log_keep) && is_func(logger_purge))
  logger_purge, alpsrc.log_keep;
if(is_hash(alpsrc) && is_string(alpsrc.log_level) && is_func(logger_level)) {
  logger_level, alpsrc.log_level;
  if(_ytk)
    tkcmd, "::logger::level {"+alpsrc.log_level+"}";
}
