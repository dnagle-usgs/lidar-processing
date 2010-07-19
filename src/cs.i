// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

local coordinate_system;
/* DOCUMENT coordinate_system
   Coordinate systems are defined using the following parameters. Where
   possible, these parameters are vaguely based on PROJ.4.

      proj= Specifies the projection. Required. Valid values:
            proj="longlat"
            proj="utm"
      ellps= Specifies the ellipsoid. Required. Valid values:
            ellps="WGS84"
            ellps="GRS80"
      datum= Specifies the horizontal datum. Required. Valid values:
            datum="WGS84"
            datum="NAD83"
      vert= Specifies the vertical datum. If not applicable, omit. Valid
         values:
            vert="NAVD88"
      geoid= Specifies the geoid. Required when vert="NAVD88". If not
         applicable, omit. Examples:
            geoid="96"
            geoid="03"
            geoid="09"
      zone= Specifies the UTM zone. If not applicable, omit. While the other
         values are all strings, this must be an integer. Examples:
            zone=8
            zone=17

   There are two ways of representing a coordinate system with these
   parameters: as a string or as a Yeti hash. The string form is typically used
   for most purposes; the Yeti hash form is mostly used within functions to
   make it easier to access the information.

   In the Yeti hash form, the parameter names above are all keys, as shown.

   In the string form, each parameter name is prefixed with a plus sign. The
   value is appended to it after an equal size. For example:
      +proj=utm +ellps=WGS84 +datum=WGS84 +zone=17
   This notation is similar to that used in PROJ.4.

   Follows are some examples. For each example, both the string and hash forms
   are illustrated.

      WGS-84 using geographic coordinates:
         "+proj=longlat +ellps=WGS84 +datum=WGS84"
         h_new(proj="longlat", ellps="WGS84", datum="WGS84")

      WGS-84 using UTM zone 18:
         "+proj=utm +ellps=WGS84 +datum=WGS84 +zone=18"
         h_new(proj="utm", ellps="WGS84", datum="WGS84", zone=18)

      NAD-83 using UTM zone 15:
         "+proj=utm +ellps=GRS80 +datum=NAD83 +zone=15"
         h_new(proj="utm", ellps="GRS80", datum="NAD83", zone=15)
      
      NAVD-88 using UTM zone 17, geoid 2009:
         "+proj=utm +ellps=GRS80 +datum=NAD83 +zone=17 +vert=NAVD88 +geoid=09"
         h_new(proj="utm", ellps="GRS80", datum="NAD83", zone=17,
            vert="NAVD88", geoid="09")

   SEE ALSO: cs_string cs_wgs84 cs_nad83 cs_navd88 cs2cs
*/

func cs_string(cs, output=) {
/* DOCUMENT cs_string(cs, output=)
   Converts a coordinate system definition between a string representation and
   a hash representation.

   Parameter:
      cs: Must be a coordinate system definition, either as a hash or a string.

   Option:
      output= Specifies what kind of output to return.
            output="string"      Always return string form
            output="hash"        Always return hash form
            output=[]            Convert to other form (default)

   SEE ALSO: coordinate_system cs_wgs84 cs_nad83 cs_navd88 cs2cs
*/
   if(output == "string" && is_string(cs))
      return cs;
   if(output == "hash" && is_hash(cs))
      return cs;

   if(is_string(cs)) {
      pairs = strsplit(cs, " ");
      result = h_new();
      for(i = 1; i <= numberof(pairs); i++) {
         if(regmatch("^\\+(.*)=(.*)$", pairs(i), , key, val)) {
            if(key == "zone")
               val = atoi(val);
            h_set, result, key, val;
         } else {
            error, "Unable to parse: " + pairs(i);
         }
      }
   } else {
      result = swrite(format="+proj=%s +ellps=%s +datum=%s",
         cs.proj, cs.ellps, cs.datum);
      if(h_has(cs, vert=))
         result += swrite(format=" +vert=%s +geoid=%s",
            cs.vert, cs.geoid);
      if(h_has(cs, zone=))
         result += swrite(format=" +zone=%d", cs.zone);
   }

   return result;
}

func cs_wgs84(nil, zone=) {
/* DOCUMENT cs = cs_wgs84(zone=)
   Returns a coordinate system hash that specifies WGS-84. If zone is provided,
   the coordinate system will be UTM using that zone. If zone is omitted (or
   specified as zero), then the coordinate system will be geographic.

   Examples:
      Coordinate system for WGS-84, geographic:
         cs = cs_wgs84()
      Coordinate system for WGS-84, UTM zone 18:
         cs = cs_wgs84(zone=18)

   SEE ALSO: coordinate_system cs_string cs_nad83 cs_navd88 cs2cs
*/
   default, zone, 0;
   cs = h_new(ellps="WGS84", datum="WGS84");
   if(zone)
      h_set, cs, proj="utm", zone=zone;
   else
      h_set, cs, proj="longlat";
   return cs_string(cs);
}

func cs_nad83(nil, zone=) {
/* DOCUMENT cs = cs_nad83(zone=)
   Returns a coordinate system hash that specifies NAD-83. If zone is provided,
   the coordinate system will be UTM using that zone. If zone is omitted (or
   specified as zero), then the coordinate system will be geographic.

   Examples:
      Coordinate system for NAD-83, geographic:
         cs = cs_nad83()
      Coordinate system for NAD-83, UTM zone 18:
         cs = cs_nad83(zone=18)

   SEE ALSO: coordinate_system cs_string cs_wgs84 cs_navd88 cs2cs
*/
   default, zone, 0;
   cs = h_new(ellps="GRS80", datum="NAD83");
   if(zone)
      h_set, cs, proj="utm", zone=zone;
   else
      h_set, cs, proj="longlat";
   return cs_string(cs);
}

func cs_navd88(nil, zone=, geoid=) {
/* DOCUMENT cs = cs_navd88(zone=, geoid=)
   Returns a coordinate system hash that specifies NAD-83 for the horizontal
   datum and NAVD-88 for the verticla datum. If zone is provided, the
   coordinate system will be UTM using that zone. If zone is omitted (or
   specified as zero), then the coordinate system will be geographic. If geoid=
   is not specified, it will default to "09".

   Examples:
      Coordinate system for NAVD-88, geoid 03, geographic:
         cs = cs_navd88(geoid="03")
      Coordinate system for NAVD-88, geoid 09, UTM zone 18:
         cs = cs_navd88(zone=18, geoid="09")

   SEE ALSO: coordinate_system cs_string cs_wgs84 cs_nad83 cs2cs
*/
   default, zone, 0;
   default, geoid, "09";
   cs = h_new(ellps="GRS80", datum="NAD83", vert="NAVD88", geoid=geoid);
   if(zone)
      h_set, cs, proj="utm", zone=zone;
   else
      h_set, cs, proj="longlat";
   return cs_string(cs);
}

func cs2cs(src, dst, &X, &Y, &Z) {
/* DOCUMENT cs2cs, src, dst, x, y, z
   -or-  cs2cs, src, dst, xyz
   -or-  xyz = cs2cs(src, dst, x, y, z)
   -or-  xyz = cs2cs(src, dst, xyz)

   Converts a set of X, Y, Z coordinates from one coordinate system to another.

   The coordinate systems (src and dst) must be hashes (pointer or Yeti) that
   represent a valid, known coordinate system. See coordinate_system for
   details on how to construct such hashes; or use cs_wgs84, cs_nad83, or
   cs_navd88 for shortcuts.

   The coordinates may be provide as three arrays or as a single array with a
   dimension of size 3. If passed in as a subroutine, they'll be modified in
   place. If used as a function, will return the result as [x,y,z] and will
   leave the input unchanged.

   SEE ALSO: coordinate_system cs_string cs_wgs84 cs_nad83 cs_navd88
*/
   local x, y, z, lat, lon, north, east;
   if(is_void(Y)) {
      splitary, X, 3, x, y, z;
   } else {
      x = X;
      y = Y;
      z = Z;
   }

   // Convert hash pointers to Yeti pointers for ease of use
   src = cs_string(src, output="hash");
   dst = cs_string(dst, output="hash");

   // Check for short-circuit: src == dst
   if(
      src.datum == dst.datum && src.vert == dst.vert &&
      src.geoid == dst.geoid && src.proj == dst.proj
   ) {
      if(am_subroutine())
         return;
      else
         return [x,y,z];
   }

   // Convert to geographic coordinates; all transformations require them
   if(src.proj == "utm") {
      utm2ll, y, x, src.zone, lon, lat, ellipsoid=strlower(src.ellps);
      x = lon;
      y = lat;
      lat = lon = [];
   }

   // When changing datums, all datum shifts pass through NAD83 for ALPS. Thus,
   // we want to convert to NAD83 (if needed), then convert away (if needed).
   if(
      src.datum != dst.datum || src.vert != dst.vert || src.geoid != dst.geoid
   ) {
      if(src.datum == "NAD83" && src.vert == "NAVD88")
         navd882nad83, x, y, z, geoid=src.geoid, verbose=0;
      if(src.datum == "WGS84")
         wgs842nad83, x, y, z;
      if(dst.datum == "WGS84")
         nad832wgs84, x, y, z;
      if(dst.datum == "NAD83" && dst.vert == "NAVD88")
         nad832navd88, x, y, z, geoid=dst.geoid, verbose=0;
   }

   // If necessary, convert to projected coordinates
   if(dst.proj == "utm") {
      ll2utm, y, x, north, east, force_zone=dst.zone,
         ellipsoid=strlower(dst.ellps);
      x = east;
      y = north;
      east = north = [];
   }

   if(am_subroutine()) {
      if(is_void(Y)) {
         X = [x,y,z];
      } else {
         eq_nocopy, X, x;
         eq_nocopy, Y, y;
         eq_nocopy, Z, z;
      }
   } else {
      return [x,y,z];
   }
}
