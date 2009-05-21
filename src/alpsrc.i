require, "dir.i";
require, "json.i";
require, "yeti.i";

write, "$Id$";

local alpsrc;
/* DOCUMENT alpsrc
   Contains global ALPS configuration settings. These settings are initialized
   by alpsrc_load (which is automatically run when alpsrc.i is loaded).

   Settings handled by alpsrc, and their defaults:

      geoid_data_root = ../
         Defines the directory in which GEOID files can be found for
         conversions between NAD83 and NAVD88. It should contain
         subdirectories such as GEOID03.

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
   alpsrc_apply;
}

func alpsrc_apply(void) {
/* DOCUMENT alpsrc_apply;
   Applies aplsrc settings. This primarily is used for cases where a setting in
   the Tcl side is being defined in the alpsrc file.
*/
   extern alpsrc;
   tkcmd, swrite(format="set ::_ytk_log_level {%s}", alpsrc.ytk_log_level);
   tkcmd, "ytk_logger_level_set";
}

func __alpsrc_load_and_merge(&hash, fn) {
   if(file_exists(fn)) {
      hash = h_merge(hash, json2yorick(rdfile(open(fn, "r"))));
   }
}

__alpsrc_defaults = h_new(
   "geoid_data_root", file_join(get_cwd(), ".."),
   "ytk_log_level", "info"
);

alpsrc_load;
