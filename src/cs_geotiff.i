// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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
