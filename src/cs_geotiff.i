// vim: set ts=2 sts=2 sw=2 ai sr et:

func cs_encode_geotiff(cs) {
/* DOCUMENT cs_geotiff(cs)
  Given a coordinate system, this will return the GeoTIFF encoding for that
  coordinate system as an oxy group object of tag-value pairs. (Use
  geotiff_tags_encode to convert into numeric form suitable for plugging into
  a raw file.)
*/
  cs = cs_parse(cs, output="hash");
  result = save();

  if(cs.proj == "longlat") {
    save, result, "GTModelTypeGeoKey", "ModelTypeGeographic";

    if(cs.datum == "NAD83") {
      save, result, "GeographicTypeGeoKey", "GCS_NAD83";
    } else if(cs.datum == "WGS84") {
      save, result, "GeographicTypeGeoKey", "GCS_WGS_84";
    } else {
      error, "unknown datum=";
    }

  } else if(cs.proj == "utm") {
    save, result, "GTModelTypeGeoKey", "ModelTypeProjected";

    if(cs.datum == "NAD83") {
      save, result, "ProjectedCSTypeGeoKey",
        swrite(format="PCS_NAD83_UTM_zone_%dN", cs.zone);
    } else if(cs.datum == "WGS84") {
      save, result, "ProjectedCSTypeGeoKey",
        swrite(format="PCS_WGS84_UTM_zone_%dN", cs.zone);
    } else {
      error, "unknown datum=";
    }

    save, result, "ProjLinearUnitsGeoKey", "Linear_Meter";

  } else {
    error, "unknown proj=";
  }

  if(h_has(cs, "vert")) {
    if(cs.vert == "NAVD88") {
      save, result, "VerticalCSTypeGeoKey",
        "VertCS_North_American_Vertical_Datum_1988";
    } else {
      error, "unknown vert=";
    }
  } else if(cs.ellps == "GRS80") {
    save, result, "VerticalCSTypeGeoKey", "VertCS_GRS_1980_ellipsoid";
  } else if(cs.ellps == "WGS84") {
    save, result, "VerticalCSTypeGeoKey", "VertCS_WGS_84_ellipsoid";
  } else {
    error, "unknown ellps=";
  }

  save, result, "VerticalUnitsGeoKey", "Linear_Meter";

  return result;
}

func cs_decode_geotiff(gtif, geoid=) {
/* DOCUMENT cs_decode_geotiff(gtif, geoid=)
  Decodes a set of GeoTIFF key-value tags and returns a coordinate system
  string. This only works with a selected range of possible coordinate
  systems.

  The geoid for NAVD88 is not encoded by the GeoTIFF specification. It is
  assumed to be geoid 09 by default, but you can use geoid= to specify another
  geoid, ie. geoid="03".

  If a coordinate system cannot be determined or if an error is encountered,
  [] is returned.
*/
  default, geoid, "09";
  cs = h_new();

  if(gtif.GTModelTypeGeoKey == "ModelTypeGeographic") {
    h_set, cs, proj="longlat";

    if(gtif.GeographicTypeGeoKey == "GCS_NAD83") {
      h_set, cs, datum="NAD83", ellps="GRS80";
    } else if(gtif.GeographicTypeGeoKey == "GCS_WGS_84") {
      h_set, cs, datum="WGS84", ellps="WGS84";
    } else {
      return [];
    }
  } else if(gtif.GTModelTypeGeoKey == "ModelTypeProjected") {
    h_set, cs, proj="utm";

    projcs = gtif.ProjectedCSTypeGeoKey;
    if(is_void(projcs))
      return [];

    zone = 0;
    if(regmatch("PCS_NAD83_UTM_zone_([0-9]+)N", projcs, , zone)) {
      h_set, cs, datum="NAD83", ellps="GRS80", zone=atoi(zone);
    } else if(regmatch("PCS_WGS84_UTM_zone_([0-9]+)N", projcs, , zone)) {
      h_set, cs, datum="WGS84", ellps="WGS84", zone=atoi(zone);
    } else {
      return [];
    }

    if(!is_void(gtif.ProjLinearUnitsGeoKey)) {
      if(gtif.ProjLinearUnitsGeoKey != "Linear_Meter")
        return [];
    }
  } else {
    return [];
  }

  if(gtif.VerticalCSTypeGeoKey == "VertCS_North_American_Vertical_Datum_1988") {
    h_set, cs, ellps="GRS80", vert="NAVD88", geoid=geoid;
  } else if(gtif.VerticalCSTypeGeoKey == "VertCS_GRS_1980_ellipsoid") {
    h_set, cs, ellps="GRS80";
  } else if(gtif.VerticalCSTypeGeoKey == "VertCS_WGS_84_ellipsoid") {
    h_set, cs, ellps="WGS84";
  } else if(!is_void(gtif.VerticalCSTypeGeoKey)) {
    return [];
  }

  if(!is_void(gtif.VerticalUnitsGeoKey)) {
    if(gtif.VerticalUnitsGeoKey != "Linear_Meter")
      return [];
  }

  return cs_parse(cs, output="string");
}
