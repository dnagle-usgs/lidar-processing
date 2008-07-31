/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

require, "ll2utm.i";
require, "mathop.i";
require, "yeti.i";

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
*/
/*
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
   ll = utm2ll(north, east, src_zone);
   u = fll2utm(ll(*,2), ll(*,1), force_zone=dest_zone);
   if(am_subroutine()) {
      north = u(1,);
      east = u(2,);
   }
   return u;
}
