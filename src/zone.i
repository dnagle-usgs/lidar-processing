/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";

__ZONE_STRUCTS = h_new(
/* DOCUMENT __ZONE_STRUCTS
   Yeti hash with info on the struct elements for northings/eastings.
   There are three keys into it: surface, bottom, mirror.
   Each hash member contains the following fields:
      match - A string that will appear in the struct definition if this is
         present.
      east - The name of the easting for this.
      north - The name of the northing for this.
      factor - What we multiple north/east by to get meters. Normally, 0.01.

   Original David Nagle 2008-07-31
*/
   "surface", h_new(
      match="  long east;",
      east="east",
      north="north",
      factor=0.01
   ),
   "bottom", h_new(
      match="  long least;",
      east="least",
      north="lnorth",
      factor=0.01
   ),
   "mirror", h_new(
      match="  long meast;",
      east="meast",
      north="mnorth",
      factor=0.01
   )
);

func rezone_data_utm(&idata, src_zone, dest_zone, keys=) {
/* DOCUMENT rezone_data_utm(data, src_zone, dest_zone)
   rezone_data_utm, data, src_zone, dest_zone

   Converts an array of data from one UTM zone (src_zone) to another UTM zone
   (dest_zone).

   If used as a function, it will return a modified array of data with
   coordinates rezoned. However, the original data array will be left
   untouched.

   If used as a subroutine, the original array will be updated with the new
   rezoned coordinates.

   If keys= is provided, then it will only change the struct elements dictated
   by the array of keys given. They must be keys into __ZONE_STRUCTS.

   Original David Nagle 2008-07-17
*/
   extern __ZONE_STRUCTS;
   default, keys, h_keys(__ZONE_STRUCTS);
   if(is_void(idata)||is_void(src_zone)||is_void(dest_zone)) return;
   data = idata;
   fields = print(structof(data))(2:-1);
   for(i = 1; i <= numberof(keys); i++) {
      key = __ZONE_STRUCTS(keys(i));
      if(numberof(where(fields==key.match))) {
         u = rezone_utm(get_member(data, key.north)*key.factor,
            get_member(data, key.east)*key.factor, src_zone, dest_zone);
         get_member(data, key.north) = u(1,) / key.factor;
         get_member(data, key.east)  = u(2,) / key.factor;
      }
   }
   if(am_subroutine())
      idata = data;
   return data;
}

func rezone_utm(&north, &east, src_zone, dest_zone) {
/* DOCUMENT rezone_utm(north, east, src_zone, dest_zone)
   rezone_utm, north, east, src_zone, dest_zone

   Rezones the data represented by north, east, and src_zone to be in the zone
   dest_zone.

   north and east must be arrays of equivalent dimensions.

   src_zone may be a scalar or an array of dimensions matching north.

   dest_zone may be a scalar or an array of dimensions matching north.

   If used as a function, it will return an array u where:
      u(1,) is Northing
      u(2,) is Easting
      u(3,) is Zone
   The original data arrays will be left untouched.

   If used as a subroutine, it will modify north and east in place.

   Original David Nagle 2008-07-17
*/
   u = transpose([north, east, src_zone]);
   if(numberof(src_zone) == 1 && numberof(dest_zone) == 1 && src_zone == dest_zone)
      return u;
   if(numberof(src_zone) == 1) src_zone = array(src_zone, dimsof(north));
   if(numberof(dest_zone) == 1) dest_zone = array(dest_zone, dimsof(north));
   w = where(src_zone != dest_zone);
   if(numberof(w)) {
      ll = utm2ll(north(w), east(w), src_zone(w));
      u(,w) = fll2utm(ll(*,2), ll(*,1), force_zone=dest_zone(w));
   }
   if(am_subroutine()) {
      north = u(1,);
      east = u(2,);
   }
   return u;
}

func batch_fix_dt_zones(dir, glob=, ignore_zeros=) {
/* DOCUMENT batch_fix_dt_zones, dir, glob=, ignore_zeroes=
   This will scan through all data tile pbds in a directory structure and
   ensure that the coordinates in each tile are properly zoned.

   If a data tile has a very low easting value in its name but contains some
   points with very high eastings, those points will be rezoned from the prior
   zone to the current zone.

   If a data tile has a very high easting value in its name but contains some
   points with very low eastings, those points will be rezoned from the next
   zone to the current zone.

   This operates on the data in-place. It will overwrite the pbd files with
   corrected versions of themselves. This should be safe, but if you're wary,
   make a backup first.

   This function is safe to run repeatedly. If there's nothing to fix, then
   nothing will be changed.

   The glob= option can be used to provide a search pattern; the default is
   "*.pbd".

   If ignore_zeroes= is set to 1, then any points with an easting of zero will
   be ignored.

   Original David Nagle 2008-07-31
*/
   extern __ZONE_STRUCTS;
   keys = h_keys(__ZONE_STRUCTS);
   default, glob, "*.pbd";
   default, ignore_zeroes, 0;

   files = find(dir, glob=glob);
   files = files(sort(file_tail(files)));
   for(i = 1; i <= numberof(files); i++) {
      basefile = file_tail(files(i));
      n = e = z = [];
      dt2utm, basefile, n, e, z;
      if(is_void(z)) {
         write, format="%s: Unable to parse UTM zone.\n", basefile;
         continue;
      }

      // I assume that any data tile between 300,000 and 700,000 is "good".
      // Those values may need to be modified when working with datasets
      // further north, as the UTM zone gets narrower towards the poles.
      if(e < 300000 || e > 700000) {
         write, format="%s: ", basefile;
         f = openb(files(i));
         vname = f.vname;
         data = get_member(f, vname);
         close, f;
         write, format="%d points\n", numberof(data);

         fields = print(structof(data))(2:-1);
         modified = 0;

         // Rather than having two blocks of code that differ only in the most
         // trivial of ways, I factored out the two differences here.
         if(e < 300000) {
            comparison = gt;
            badzone = z - 1;
         } else {
            comparison = lt;
            badzone = z + 1;
         }

         for(j = 1; j <= numberof(keys); j++) {
            key = __ZONE_STRUCTS(keys(j));
            if(numberof(where(fields==key.match))) {
               if(ignore_zeroes) {
                  filter = get_member(data, key.east) != 0;
               } else {
                  filter = array(1, numberof(data));
               }
               idx = where(filter & comparison(
                  get_member(data, key.east) * key.factor, 500000));
               if(numberof(idx)) {
                  modified = 1;
                  data(idx) = rezone_data_utm(data(idx), badzone, z,
                     keys=[keys(j)]);
                  write, format="  Found %d outliers for %s, zone %d -> %d\n",
                     numberof(idx), keys(j), badzone, z;
               }
            }
         }
         if(!modified) continue;
         
         write, format="  Saving corrected pbd.%s", "\n";

         f = createb(files(i));
         add_variable, f, -1, vname, structof(data), dimsof(data);
         get_member(f, vname) = data;
         save, f, vname;
         close, f;
      }
   }
}

func batch_fix_qq_zones(dir, glob=) {
/* DOCUMENT batch_fix_qq_zones, dir, glob=
   This will scan through all quarter quad pbds in a directory structure and
   ensure that the coordinates in each tile are properly zoned. The zone for
   each quarter quad is based on its centroid.

   If a quarter quad should have very low easting values but contains some
   points with very high eastings, those points will be rezoned from the prior
   zone to the current zone.

   If a quarter quad should have very high easting values but contains some
   points with very low eastings, those points will be rezoned from the next
   zone to the current zone.

   This operates on the data in-place. It will overwrite the pbd files with
   corrected versions of themselves. This should be safe, but if you're wary,
   make a backup first.

   This function is safe to run repeatedly. If there's nothing to fix, then
   nothing will be changed.

   The glob= option can be used to provide a search pattern; the default is
   "*.pbd".

   Original David Nagle 2008-07-31
*/
   extern __ZONE_STRUCTS;
   keys = h_keys(__ZONE_STRUCTS);
   default, glob, "*.pbd";

   files = find(dir, glob=glob);
   files = files(sort(file_tail(files)));
   for(i = 1; i <= numberof(files); i++) {
      basefile = file_tail(files(i));
      qq = extract_qq(basefile);
      if(!strlen(qq)) {
         write, format="%s: Unable to parse quarter quad.\n", basefile;
         continue;
      }
      centroid = qq2uz(qq, centroid=1);
      n = centroid(1);
      e = centroid(2);
      z = centroid(3);

      // I assume that any center easting between 300,000 and 700,000 is
      // "good".  Those values may need to be modified when working with
      // datasets further north, as the UTM zone gets narrower towards the
      // poles.
      if(e < 300000 || e > 700000) {
         write, format="%s: ", basefile;
         f = openb(files(i));
         vname = f.vname;
         data = get_member(f, vname);
         close, f;
         write, format="%d points\n", numberof(data);

         fields = print(structof(data))(2:-1);
         modified = 0;

         // Rather than having two blocks of code that differ only in the most
         // trivial of ways, I factored out the two differences here.
         if(e < 300000) {
            comparison = gt;
            badzone = z - 1;
         } else {
            comparison = lt;
            badzone = z + 1;
         }

         for(j = 1; j <= numberof(keys); j++) {
            key = __ZONE_STRUCTS(keys(j));
            if(numberof(where(fields==key.match))) {
               idx = where(comparison(
                  get_member(data, key.east) * key.factor, 500000));
               if(numberof(idx)) {
                  modified = 1;
                  data(idx) = rezone_data_utm(data(idx), badzone, z,
                     keys=[keys(j)]);
                  write, format="  Found %d outliers for %s, zone %d -> %d\n",
                     numberof(idx), keys(j), int(badzone), int(z);
               }
            }
         }
         if(!modified) continue;
         
         write, format="  Saving corrected pbd.%s", "\n";

         f = createb(files(i));
         add_variable, f, -1, vname, structof(data), dimsof(data);
         get_member(f, vname) = data;
         save, f, vname;
         close, f;
      }
   }
}

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
   f = openb(file);
   data = get_member(f, f.vname) (::skip);
   close, f;
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
