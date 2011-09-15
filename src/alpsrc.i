// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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
         will use this to find fla-reefs.dat, and plot.ytk will use it as a
         default directory for the maps.

      batcher_dir = ../batcher
         Defines the directory where the batcher scripts can be found.

      memory_autorefresh = 5
         An interval in seconds that specifies how often the Memory Usage
         indicator should be refreshed. Set to 0 to disable. This is only
         applied at start-up.

      gdal_bin = ../../bin
         Defines the directory where the GDAL binaries may be found.

   See also: alpsrc_load
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

   See also: alpsrc
*/
   extern alpsrc;
   // load default
   alpsrc = h_clone(__alpsrc_defaults);
   __alpsrc_load_and_merge, alpsrc, "/etc/alpsrc";
   __alpsrc_load_and_merge, alpsrc, "~/.alpsrc";
   __alpsrc_load_and_merge, alpsrc, "./.alpsrc";
}

func __alpsrc_load_and_merge(&hash, fn) {
   if(file_exists(fn)) {
      hash = h_merge(hash, json_decode(rdfile(open(fn, "r"))));
   }
}

func __alpsrc_set_defaults(&hash) {
/* DOCUMENT __alpsrc_set_defaults, hash;
   Sets the initial defaults for __alpsrc_defaults.
*/
   default, hash, h_new();
   h_set, hash, batcher_dir=file_join(get_cwd(), "..", "batcher");
   // If the src directory is .../eaarl/lidar-processing/src
   // Then the share directory is .../eaarl/share
   sharedir = file_join(get_cwd(), "..", "..", "share");
   h_set, hash, geoid_data_root=file_join(sharedir, "NAVD88");
   h_set, hash, maps_dir=file_join(sharedir, "maps");
   h_set, hash, gdal_bin=file_join(get_cwd(), "..", "..", "bin");
   h_set, hash, memory_autorefresh=5;
}

__alpsrc_set_defaults, __alpsrc_defaults;
alpsrc_load;
