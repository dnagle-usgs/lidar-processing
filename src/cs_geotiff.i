// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

scratch = save(scratch, tmp, cs_en_gtif_enc_short, cs_en_gtif_enc_string,
   cs_en_gtif_enc_double);
tmp = save(enc_short, enc_string, enc_double);

func cs_en_gtif_enc_short(result, key, val) {
   extern GTIF;
   if(!GTIF.key(*,key))
      error, "unknown key: "+key;
   if(!GTIF.code(*,val))
      error, "unknown code: "+val;
   save, result,
      KeyId=grow(result.KeyId, GTIF.key(noop(key))),
      TIFFTagLocation=grow(result.TIFFTagLocation, 0s),
      Count=grow(result.Count, 1s),
      Value_Offset=grow(result.Value_Offset, short(GTIF.code(noop(val))));
}
enc_short = cs_en_gtif_enc_short;

func cs_en_gtif_enc_string(result, key, val) {
   if(!GTIF.key(*,key))
      error, "unknown key: "+key;
   if(is_string(val))
      val = strchar(val);
   save, result,
      KeyId=grow(result.KeyId, GTIF.key(noop(key))),
      TIFFTagLocation=grow(result.TIFFTagLocation, GTIF.tag.GeoAsciiParamsTag),
      Count=grow(result.Count, short(numberof(val))),
      Value_Offset=grow(result.Value_Offset,
         short(numberof(result.GeoAsciiParamsTag))),
      GeoAsciiParamsTag=grow(result.GeoAsciiParamsTag, val);
}
enc_string = cs_en_gtif_enc_string;

func cs_en_gtif_enc_double(result, key, val) {
   if(!GTIF.key(*,key))
      error, "unknown key: "+key;
   save, result,
      KeyId=grow(result.KeyId, GTIF.key(noop(key))),
      TIFFTagLocation=grow(result.TIFFTagLocation, GTIF.tag.GeoDoubleParamsTag),
      Count=grow(result.Count, short(numberof(val))),
      Value_Offset=grow(result.Value_Offset,
         short(numberof(result.GeoDoubleParamsTag))),
      GeoDoubleParamsTag=grow(result.GeoDoubleParamsTag, double(val));
}
enc_double = cs_en_gtif_enc_double;

func cs_encode_geotiff(util, cs) {
/* DOCUMENT cs_geotiff(cs)
   Given a coordinate system, this will return the GeoTIFF encoding for that
   coordinate system.

   The result is an oxy group with four or five members:
      KeyId
      TIFFTagLocation
      Count
      Value_Offset
      GeoAsciiParamsTag (optional)
      GeoDoubleParamsTag (optional)
*/
   cs = cs_parse(cs, output="hash");
   result = save();

   if(cs.proj == "longlat") {
      util, enc_short, result, "GTModelTypeGeoKey", "ModelTypeGeographic";

      if(cs.datum == "NAD83") {
         util, enc_short, result, "GeographicTypeGeoKey", "GCS_NAD83";
      } else if(cs.datum == "WGS84") {
         util, enc_short, result, "GeographicTypeGeoKey", "GCS_WGS_84";
      } else {
         error, "unknown datum=";
      }

   } else if(cs.proj == "utm") {
      util, enc_short, result, "GTModelTypeGeoKey", "ModelTypeProjected";

      if(cs.datum == "NAD83") {
         util, enc_short, result, "ProjectedCSTypeGeoKey",
            swrite(format="PCS_NAD83_UTM_zone_%dN", cs.zone);
      } else if(cs.datum == "WGS84") {
         util, enc_short, result, "ProjectedCSTypeGeoKey",
            swrite(format="PCS_WGS84_UTM_zone_%dN", cs.zone);
      } else {
         error, "unknown datum=";
      }

      util, enc_short, result, "ProjLinearUnitsGeoKey", "Linear_Meter";

   } else {
      error, "unknown proj=";
   }

   if(h_has(cs, "vert")) {
      if(cs.vert == "NAVD88") {
         util, enc_short, result, "VerticalCSTypeGeoKey",
            "VertCS_North_American_Vertical_Datum_1988";
      } else {
         error, "unknown vert=";
      }
   } else if(cs.ellps == "GRS80") {
      util, enc_short, result, "VerticalCSTypeGeoKey", "VertCS_GRS_1980_ellipsoid";
   } else if(cs.ellps == "WGS84") {
      util, enc_short, result, "VerticalCSTypeGeoKey", "VertCS_WGS_84_ellipsoid";
   } else {
      error, "unknown ellps=";
   }

   util, enc_short, result, "VerticalUnitsGeoKey", "Linear_Meter";

   return result;
}

cs_encode_geotiff = closure(cs_encode_geotiff, restore(tmp));
restore, scratch;
