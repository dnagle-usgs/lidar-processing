// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "dir.i";
require, "json.i";
require, "yeti.i";

local alpsrc;
/* DOCUMENT alpsrc
   Contains global ALPS configuration settings. These settings are initialized
   by alpsrc_load (which is automatically run when alpsrc.i is loaded).

   Settings handled by alpsrc, and their defaults:

      geoid_data_root = ../
         Defines the directory in which GEOID files can be found for
         conversions between NAD83 and NAVD88. It should contain
         subdirectories such as GEOID03.

      maps_dir = ../maps
         Defines the directory in which map files can be found. File reefs.i
         will use this to find fla-reefs.dat, and plot.ytk will use it as a
         default directory for the maps.

      l1pro_startup = 0
         Defines whether to display the l1pro GUI at startup. 0 is "no", 1 is
         "yes". This takes effect when eaarl.ytk is sourced.

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
   __alpsrc_load_and_merge, alpsrc, ".alpsrc";
}

func __alpsrc_load_and_merge(&hash, fn) {
   if(file_exists(fn)) {
      hash = h_merge(hash, json2yorick(rdfile(open(fn, "r"))));
   }
}

func __alpsrc_set_defaults(&hash) {
/* DOCUMENT __alpsrc_set_defaults, hash;
   Sets the initial defaults for __alpsrc_defaults.
*/
   default, hash, h_new();
   h_set, hash, batcher_dir=file_join(get_cwd(), "..", "batcher");
   h_set, hash, l1pro_startup=1;
   // Newer installations keep data files in a share directory
   // If the src directory is .../eaarl/lidar-processing/src
   // Then the share directory is .../eaarl/share
   sharedir = file_join(get_cwd(), "..", "..", "share");
   if(file_isdir(sharedir)) {
      h_set, hash, geoid_data_root=file_join(sharedir, "NAVD88");
      h_set, hash, maps_dir=file_join(sharedir, "maps");
   // Old installations keep everything under lidar-processing
   } else {
      h_set, hash, geoid_data_root=file_join(get_cwd(), "..");
      h_set, hash, maps_dir=file_join(get_cwd(), "..", "maps");
   }
}

__alpsrc_set_defaults, __alpsrc_defaults;
alpsrc_load;
