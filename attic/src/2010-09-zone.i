// vim: set ts=3 sts=3 sw=3 ai sr et:
/******************************************************************************\
* This file was created in the attic on 2010-09-14. These functions were moved *
* here from zone.i because they are unused and obsolete in favor of other      *
* functionality.                                                               *
*     zoneload_dt_pbd                                                          *
*     zoneload_qq_pbd                                                          *
*     load_rezone_pbd                                                          *
*     zoneload_dt_dir                                                          *
*     zoneload_qq_dir                                                          *
*     __load_rezone_dir                                                        *
* All of these functions are replaced in favor of dirload.i's functionality.   *
\******************************************************************************/

require, "eaarl.i";

func zoneload_dt_pbd(file, zone, skip=) {
/* DOCUMENT zoneload_dt_pbd(file, zone, skip=)
   Will load the given data tile pbd file, coercing its data into the given
   zone. If skip is provided, the data will be subsampled accordingly.

   Original David Nagle 2008-07-31
*/
   dtzone = [];
   dt2utm, file_tail(file), , , dtzone;
   return load_rezone_pbd(file, dtzone, zone, skip=skip);
}

func zoneload_qq_pbd(file, zone, skip=) {
/* DOCUMENT zoneload_qq_pbd(file, zone, skip=)
   Will load the given quarter quad pbd file, coercing its data into the given
   zone. If skip is provided, the data will be subsampled accordingly.

   Original David Nagle 2008-07-31
*/
   qqzone = qq2uz(file_tail(file));
   return load_rezone_pbd(file, qqzone, zone, skip=skip);
}

func load_rezone_pbd(file, src_zone, dest_zone, skip=) {
/* DOCUMENT load_rezone_pbd(file, src_zone, dest_zone, skip=)
   Will load the given pbd file, coercing its data from src_zone to dest_zone
   (which is a no-op if they are the same). If skip is provided, the data will
   be subsampled accordingly.

   Original David Nagle 2008-07-31
*/
   default, skip, 1;
   data = pbd_load(file);
   if(numberof(data))
      data = unref(data)(::skip);
   if(src_zone != dest_zone)
      rezone_data_utm, data, src_zone, dest_zone;
   return data;
}

func zoneload_dt_dir(dir, zone, skip=, glob=, unique=) {
/* DOCUMENT zoneload_dt_dir(dir, zone, skip=, glob=, unique=)
   Will load and merge all data tile pbds that match the given glob (or "*.pbd"
   if none is given), subsampling by skip (if specified). All data will be
   coerced to the given zone.

   Original David Nagle 2008-07-31
*/
   return __load_rezone_dir(dir, zone, zoneload_dt_pbd, skip=skip, glob=glob, unique=unique);
}

func zoneload_qq_dir(dir, zone, skip=, glob=, unique=) {
/* DOCUMENT zoneload_qq_dir(dir, zone, skip=, glob=, unique=)
   Will load and merge all quarter quad pbds that match the given glob (or
   "*.pbd" if none is given), subsampling by skip (if specified). All data will
   be coerced to the given zone.

   Original David Nagle 2008-07-31
*/
   return __load_rezone_dir(dir, zone, zoneload_qq_pbd, skip=skip, glob=glob, unique=unique);
}

func __load_rezone_dir(dir, zone, fnc, skip=, glob=, unique=) {
/* DOCUMENT __load_rezone_dir(dir, zone, fnc, skip=, glob=, unique=
   Private function for zoneload_dt_dir and zoneload_qq_dir.
   dir: dir to load
   zone: zone to coerce to
   fnc: function used to load a file
   skip: skip factor
   glob: glob to find by
   unique: makes unique via soe field

   Original David Nagle 2008-07-31
*/
   default, glob, "*.pbd";
   default, unique, 1;
   files = find(dir, glob=glob);
   data = [];
   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files);
      grow, data, fnc(files(i), zone, skip=skip);
   }
   if(unique) {
      idx = set_remove_duplicates(data.soe, idx=1);
      data = data(idx);
   }
   return data;
}
