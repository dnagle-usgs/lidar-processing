/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

func rezone_data_utm(&idata, src_zone, dest_zone) {
/* DOCUMENT rezone_data_utm(data, src_zone, dest_zone)
   rezone_data_utm, data, src_zone, dest_zone

   Converts an array of data from one UTM zone (src_zone) to another UTM zone
   (dest_zone). Currently will detect and convert the following struct members:
   - "long east;" and "long north;"
   - "long least;" and "long lnorth;"
   - "long meast;" and "long mnorth;"

   If used as a function, it will return a modified array of data with
   coordinates rezoned. However, the original data array will be left
   untouched.

   If used as a subroutine, the original array will be updated with the new
   rezoned coordinates.

   Original David Nagle 2008-07-17
*/
   if(is_void(idata)) return;
   data = idata;
   __rezone_data_utm, data, src_zone, dest_zone,
      "  long east;", "  long north;", 0.01;
   __rezone_data_utm, data, src_zone, dest_zone,
      "  long least;", "  long lnorth;", 0.01;
   __rezone_data_utm, data, src_zone, dest_zone,
      "  long meast;", "  long mnorth;", 0.01;
   if(am_subroutine())
      idata = data;
   return data;
}

func __rezone_data_utm(&data, src_zone, dest_zone, east, north, factor) {
/* DOCUMENT __rezone_data_utm, &data, src_zone, dest_zone, east, north, factor
   Utility function for rezone_data_utm to avoid code repetition.
   data - array of data to be modified in place
   src_zone - zone to convert from
   dest_zone - zone to convert to
   east - string; the struct member that has eastings
   north - string; the struct member that has northings
   factor - the eastings/northings should be multiplied by this to get meters

   If east/north do not exist in data, then this is a no-op.

   Original David Nagle 2008-07-17
*/
   fields = print(structof(data))(2:-1);
   if(numberof(where(fields==east)) && numberof(where(fields==north))) {
      fields = [east, north];
      fields = regsub("^ +", fields);
      fields = regsub(";$", fields);
      fields = strsplit(fields, " ")(,2);
      east = fields(1);
      north = fields(2);
      u = rezone_utm(get_member(data, north) * factor, get_member(data, east) * factor, src_zone, dest_zone);
      get_member(data, north) = u(1,) / factor;
      get_member(data, east) = u(2,) / factor;
   }
}

func rezone_utm(&north, &east, src_zone, dest_zone) {
/* DOCUMENT rezone_utm(north, east, src_zone, dest_zone)
   rezone_utm, north, east, src_zone, dest_zone

   Rezones the data represented by north, east, and src_zone to be in the zone
   dest_zone.

   If used as a function, it will return an array u where:
      u(1,) is Northing
      u(2,) is Easting
      u(3,) is Zone
   The original data arrays will be left untouched.

   If used as a subroutine, it will modify north and east in place.

   Original David Nagle 2008-07-17
*/
   ll = utm2ll(north, east, src_zone);
   u = fll2utm(ll(*,2), ll(*,1), force_zone=dest_zone);
   if(am_subroutine()) {
      north = u(1,);
      east = u(2,);
   }
   return u;
}
