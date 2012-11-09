// vim: set ts=2 sts=2 sw=2 ai sr et:

local coordinate_system;
/* DOCUMENT coordinate_system

  Coordinate systems are defined using a space-separated list of parameter
  settings, in a style similar to that used in PROJ.4. An example of a
  coordinate system string:
    +proj=utm +ellps=WGS84 +datum=WGS84 +zone=17

  Follows are the parameters available and their permissible values:

    +proj= Specifies the projection. Required. Valid values:
        +proj=longlat
        +proj=utm
    +ellps= Specifies the ellipsoid. Required. Valid values:
        +ellps=WGS84
        +ellps=GRS80
    +datum= Specifies the horizontal datum. Required. Valid values:
        +datum=WGS84
        +datum=NAD83
    +vert= Specifies the vertical datum. If not applicable, omit. Valid
      values:
        +vert=NAVD88
    +geoid= Specifies the geoid. Required when vert=NAVD88. If not
      applicable, omit. Examples:
        +geoid=96
        +geoid=03
        +geoid=09
    +zone= Specifies the UTM zone. If not applicable, omit. While the other
      values are all strings, this must be an integer. Examples:
        +zone=8
        +zone=17

  Follows are more examples.

    WGS-84 using geographic coordinates:
      +proj=longlat +ellps=WGS84 +datum=WGS84

    WGS-84 using UTM zone 18:
      +proj=utm +ellps=WGS84 +datum=WGS84 +zone=18

    NAD-83 using UTM zone 15:
      +proj=utm +ellps=GRS80 +datum=NAD83 +zone=15

    NAVD-88 using UTM zone 17, geoid 2009:
      +proj=utm +ellps=GRS80 +datum=NAD83 +zone=17 +vert=NAVD88 +geoid=09

  When passing such a string in Yorick, surround it by a single pair of
  quotes, as such:

    mycs = "+proj=longlat +ellps=WGS84 +datum=WGS84";

  SEE ALSO: cs_parse cs_wgs84 cs_nad83 cs_navd88 cs2cs
*/

func cs_parse(cs, output=) {
/* DOCUMENT cs_parse(cs, output=)
  Given a coordinate system string, this will return a parsed hash with the
  parameter values defined therein. Given a hash with coordinate system
  parameters, this will return the corresponding coordinate system string.

  Parameter:
    cs: Must be a coordinate system definition, either as a string or a hash.

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

func cs_compromise(csA, csB) {
/* DOCUMENT csC = cs_compromise(csA, csB)
  Works out a compromise coordinate system between two given coordinate
  systems. If csA and csB are the same, then csA is returned. Otherwise, a
  coordinate system is determined that attempts to minimize the amount of
  change necessary for each of the given coordinate systems to convert to the
  compromise.

  Specifically:
    * Fields that are present and identical in each are kept
    * If both are not UTM with the same zone, then proj=longlat
    * If both do not have the same datum/ellps, then datum=NAD83 ellps=GRS80
    * If both do not use the same NAVD88 geoid, then no vertical datum is
      used at all

  Returns a coordinate system string.
*/
  csA = cs_parse(csA, output="hash");
  csB = cs_parse(csB, output="hash");

  if(cs_parse(csA) == cs_parse(csB))
    return cs_parse(csA);

  // Start by copying everything they have in common
  csC = h_new();
  keys = h_keys(csA);
  nkeys = numberof(keys);
  for(i = 1; i <= nkeys; i++)
    if(h_has(csB, keys(i)) && csA(keys(i)) == csB(keys(i)))
      h_set, csC, keys(i), csA(keys(i));

  // All transformations go through longlat, so it's a safe bet to change to.
  // Besides, if they couldn't agree on a zone, we can't know what zone would
  // work well.
  if(!h_has(csC, "proj") || !h_has(csC, "zone"))
    h_set, csC, proj="longlat";

  // Horizontal is either WGS84 or NAD83. If they don't agree, then opt for
  // NAD83, since it's in the middle of the progression WGS84 <-> NAD83 <->
  // NAVD88.
  if(!h_has(csC, "datum"))
    h_set, csC, datum="NAD83";
  if(!h_has(csC, "ellps"))
    h_set, csC, "ellps", (csC.datum == "NAD83" ? "GRS80" : "WGS84");

  // If they are using different NAVD88 geoids, then just revert to NAD83.
  if(h_has(csC, "vert") && !h_has(csC, "geoid"))
    h_pop, csC, "vert";

  return cs_parse(csC);
}

func cs_wgs84(nil, zone=) {
/* DOCUMENT cs = cs_wgs84(zone=)
  Returns a coordinate system string that specifies WGS-84. If zone is
  provided, the coordinate system will be UTM using that zone. If zone is
  omitted (or specified as zero), then the coordinate system will be
  geographic.

  Examples:
    Coordinate system for WGS-84, geographic:
      cs = cs_wgs84()
    Coordinate system for WGS-84, UTM zone 18:
      cs = cs_wgs84(zone=18)

  SEE ALSO: coordinate_system cs_parse cs_nad83 cs_navd88 cs2cs
*/
  default, zone, 0;
  cs = h_new(ellps="WGS84", datum="WGS84");
  if(zone)
    h_set, cs, proj="utm", zone=zone;
  else
    h_set, cs, proj="longlat";
  return cs_parse(cs);
}

func cs_nad83(nil, zone=) {
/* DOCUMENT cs = cs_nad83(zone=)
  Returns a coordinate system string that specifies NAD-83. If zone is
  provided, the coordinate system will be UTM using that zone. If zone is
  omitted (or specified as zero), then the coordinate system will be
  geographic.

  Examples:
    Coordinate system for NAD-83, geographic:
      cs = cs_nad83()
    Coordinate system for NAD-83, UTM zone 18:
      cs = cs_nad83(zone=18)

  SEE ALSO: coordinate_system cs_parse cs_wgs84 cs_navd88 cs2cs
*/
  default, zone, 0;
  cs = h_new(ellps="GRS80", datum="NAD83");
  if(zone)
    h_set, cs, proj="utm", zone=zone;
  else
    h_set, cs, proj="longlat";
  return cs_parse(cs);
}

func cs_navd88(nil, zone=, geoid=) {
/* DOCUMENT cs = cs_navd88(zone=, geoid=)
  Returns a coordinate system string that specifies NAD-83 for the horizontal
  datum and NAVD-88 for the vertical datum. If zone is provided, the
  coordinate system will be UTM using that zone. If zone is omitted (or
  specified as zero), then the coordinate system will be geographic. If geoid=
  is not specified, it will default to "09".

  Examples:
    Coordinate system for NAVD-88, geoid 03, geographic:
      cs = cs_navd88(geoid="03")
    Coordinate system for NAVD-88, geoid 09, UTM zone 18:
      cs = cs_navd88(zone=18, geoid="09")

  SEE ALSO: coordinate_system cs_parse cs_wgs84 cs_nad83 cs2cs
*/
  default, zone, 0;
  default, geoid, "09";
  cs = h_new(ellps="GRS80", datum="NAD83", vert="NAVD88", geoid=geoid);
  if(zone)
    h_set, cs, proj="utm", zone=zone;
  else
    h_set, cs, proj="longlat";
  return cs_parse(cs);
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

  SEE ALSO: coordinate_system cs_parse cs_wgs84 cs_nad83 cs_navd88
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
  src = cs_parse(src, output="hash");
  dst = cs_parse(dst, output="hash");

  // Check for short-circuit: src == dst
  if(
    src.datum == dst.datum && src.vert == dst.vert &&
    src.geoid == dst.geoid && src.proj == dst.proj &&
    (src.proj == "latlong" || src.zone == dst.zone)
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

local current_cs;
/* DOCUMENT current_cs
  This is a global variable that defines your current coordinate system. At
  start-up, this will be WGS-84 with lat/long.
*/
if(is_void(current_cs)) current_cs = cs_wgs84();
