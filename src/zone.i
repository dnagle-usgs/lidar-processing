// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(curzone))
  curzone = 0;

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
    if(anyof(fields==key.match)) {
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
  if(numberof(src_zone) == 1 && numberof(dest_zone) == 1 && src_zone(1) == dest_zone(1))
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

func batch_fix_zones(dir, searchstr=, ignore_zeros=) {
/* DOCUMENT batch_fix_zones, dir, searchstr=, ignore_zeroes=
  This will scan through all tiled pbds in a directory structure and ensure
  that the coordinates in each tile are properly zoned.

  If a tile has a very low easting value in its name but contains some points
  with very high eastings, those points will be rezoned from the prior zone to
  the current zone.

  If a tile has a very high easting value in its name but contains some points
  with very low eastings, those points will be rezoned from the next zone to
  the current zone.

  This operates on the data in place. It will overwrite the pbd files with
  corrected versions of themselves. This should be safe, but if you're wary,
  make a backup first.

  This function is safe to run repeatedly. If there's nothing to fix, then
  nothing will be changed.

  The searchstr= option can be used to provide a search pattern; the default is
  "*.pbd".

  If ignore_zeroes= is set to 1, then any points with an easting of zero will
  be ignored.
*/
// Original David Nagle 2008-07-31
  extern __ZONE_STRUCTS;
  keys = h_keys(__ZONE_STRUCTS);
  default, searchstr, "*.pbd";
  default, ignore_zeroes, 0;

  files = find(dir, searchstr=searchstr);
  files = files(sort(file_tail(files)));
  for(i = 1; i <= numberof(files); i++) {
    basefile = file_tail(files(i));
    n = e = z = [];
    assign, tile2centroid(basefile), n, e, z;
    if(is_void(z)) {
      write, format="%s: Unable to parse UTM zone.\n", basefile;
      continue;
    }

    // I assume that any data tile between 300,000 and 700,000 is "good".
    // Those values may need to be modified when working with datasets
    // further north, as the UTM zone gets narrower towards the poles.
    if(e < 300000 || e > 700000) {
      write, format="%s: ", basefile;
      vname = [];
      data = pbd_load(files(i), , vname);
      write, format="%d points\n", numberof(data);

      fields = print(structof(data))(2:-1);
      modified = 0;

      // Rather than having two blocks of code that differ only in the most
      // trivial of ways, I factored out the two differences here.
      if(e < 300000) {
        comparison = mathop.gt;
        badzone = z - 1;
      } else {
        comparison = mathop.lt;
        badzone = z + 1;
      }

      for(j = 1; j <= numberof(keys); j++) {
        key = __ZONE_STRUCTS(keys(j));
        if(anyof(fields==key.match)) {
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

func auto_curzone(lat, lon, verbose=) {
/* DOCUMENT auto_curzone, lat, lon;
  Attempts to automatically set curzone based on the given lat/lon
  coordinates.

  If only one zone is represented by the coordinates, then curzone will be set
  to it. Otherwise, the user will be informed that they have to manually set
  it.

  If fixedzone is set, this function does nothing.

  Set verbose=0 to silence output. With verbose=1, the user is informed of any
  action taken by auto_curzone.

  This will also update Tcl's curzone variable.
*/
  extern curzone, fixedzone;
  local zone;
  default, verbose, 1;

  if(!is_void(fixedzone))
    return;

  lamn = lat(min);
  lomn = lon(min);
  lamx = lat(max);
  lomx = lon(max);
  lon = lat = [];
  fll2utm, [lamn,lamx,lamn,lamx], [lomn,lomn,lomx,lomx], , , zone;

  zmin = long(zone(min));
  zmax = long(zone(max));
  zone = [];

  updated = 0;
  needset = 0;
  conflict = 0;
  if(!curzone) {
    if(zmin == zmax) {
      updated = 1;
      curzone = zmin;
    } else {
      // Notify user for decision
      needset = 1;
    }
  } else {
    if(zmin <= curzone && curzone <= zmax) {
      // no action needed
    } else if(zmin == zmax) {
      conflict = curzone;
      updated = 1;
      curzone = zmin;
    } else {
      // Notify user for decision
      conflict = curzone;
      needset = 1;
    }
  }

  // Update Tcl, if needed
  tksync, check;
  if(!verbose)
    return;

  if(updated) {
    if(conflict) {
      write, format="*** curzone has been changed from %d to %d\n",
        long(conflict), long(curzone);
    } else {
      write, format="curzone has been set to %d\n", long(curzone);
    }
  } else if(needset) {
    if(conflict) {
      write, format="*** curzone currently %d; should be between %d and %d\n",
        long(conflict), zmin, zmax;
    } else {
      write, format="*** curzone should be between %d and %d\n", zmin, zmax;
    }
    write, format="*** Please manually set curzone to the proper zone%s", "\n";
  }
}

func best_zone(lon, lat, method=) {
/* DOCUMENT zone = best_zone(lon, lat, method=)
  Determines the best zone for a set of lon,lat coordinates. "Best" means that
  the UTM zone will yield coordinates with minimal distortion, as measured
  from the zone's central meridian of 500,000m. There are three ways of
  determining this:

  method="rms" (default)
    Best is the zone with the lowest RMS: sqrt(((east-500000)^2)(avg))
  method="max"
    Best is the zone with the lowest max: abs(east-500000)(max)
  method="avg"
    Best is the zone with the lowest average: abs(east-500000)(avg)

  Of course, if the coordinates all lie within a single UTM zone, that zone
  will always be returned.
*/
  default, method, "rms";
  local north, east, zone;

  ll2utm, lat, lon, north, east, zone;

  if(allof(zone == zone(1)))
    return zone(1);

  zones = set_remove_duplicates(zone);
  zone = [];

  dist = array(double, numberof(zones));

  for(i = 1; i <= numberof(zones); i++) {
    ll2utm, lat, lon, north, east, force_zone=zones(i);
    east -= 500000;
    if(method == "rms")
      dist(i) = sqrt((east^2)(avg));
    else if(method == "max")
      dist(i) = abs(east)(max);
    else if(method == "avg")
      dist(i) == abs(east)(avg);
    else
      error, "unknown method=";
  }

  return zones(dist(mnx));
}
