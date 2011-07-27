// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func cs_encode_geotiff(cs) {
/* DOCUMENT cs_geotiff(cs)
   Given a coordinate system, this will return the GeoTIFF encoding for that
   coordinate system.

   The result is an oxy group with four or five members:
      KeyId
      TIFFTagLocation
      Count
      Value_Offset
      GeoASCIIParamsTag (optional)
*/
   cs = cs_parse(cs, output="hash");

   KeyId = TIFFTagLocation = Count = Value_Offset = GeoASCIIParamsTag = [];

   // GTModelTypeGeoKey
   // Defines the general type of model coordinate system used.
   // Key ID = 1024
   // Values:
   //    1 = Projection coordinate system
   //    2 = Geographic lat/lon system
   //    3 = Geocentric (x,y,z) coordinate system
   // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.1.1
   grow, KeyId, 1024s;
   grow, TIFFTagLocation, 0s;
   grow, Count, 1s;
   w = where(cs.proj == ["utm", "longlat"]);
   if(!numberof(w))
      error, "unknown proj= Value_Offset";
   grow, Value_Offset, short(w(1));

   if(cs.proj == "longlat") {

      // GeographicTypeGeoKey
      // Specifies the geographic coordinate system.
      // Key ID = 2048
      // Values:
      //    WGS84: 4326
      //    NAD83: 4269 
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.2.1
      grow, KeyId, 2048s;
      grow, TIFFTagLocation, 0s;
      grow, Count, 1s;
      if(cs.datum == "NAD83") {
         grow, Value_Offset, 4269s;
      } else if(cs.datum == "WGS84") {
         grow, Value_Offset, 4326s;
      } else {
         error, "unknown datum=";
      }

   } else if(cs.proj == "utm") {

      // ProjectedCSTypeGeoKey
      // Specifies the projected coordinate system.
      // Key ID = 3072
      // Values:
      //    WGS84 / UTM northern hemisphere: 326zz
      //    WGS84 / UTM southern hemisphere: 627zz
      //    NAD83 / UTM: 269zz
      // (where zz is the UTM zone)
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.3.1
      grow, KeyId, 3072s;
      grow, TIFFTagLocation, 0s;
      grow, Count, 1s;
      if(cs.datum == "NAD83") {
         grow, Value_Offset, short(26900 + cs.zone);
      } else if(cs.datum == "WGS84") {
         grow, Value_Offset, short(32600 + cs.zone);
      } else {
         error, "unknown datum=";
      }

      // ProjLinearUnitsGeoKey
      // Defines linear units used by the projection.
      // Key ID = 3076
      // Values:
      //    9001 = meters
      // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.1.3
      grow, KeyId, 3076s;
      grow, TIFFTagLocation, 0s;
      grow, Count, 1s;
      grow, Value_Offset, 9001s;

   } else {
      error, "unknown proj=";
   }

   // VerticalCSTypeGeoKey
   // Specifies the vertical coordinate system.
   // Key ID = 4096
   // Values:
   //    5019 = GRS 1980 ellipsoid
   //    5030 = WGS 1984 ellipsoid
   //    5103 = NAVD 1988 datum
   // See http://www.remotesensing.org/geotiff/spec/geotiff6.html#6.3.4.1
   grow, KeyId, 4096s;
   grow, TIFFTagLocation, 0s;
   grow, Count, 1s;
   if(h_has(cs, "vert")) {
      if(cs.vert == "NAVD88") {
         grow, Value_Offset, 5103s;

         // VerticalCitationGeoKey
         // Specifies the vertical coordinate system with a text citation
         // Key ID = 4097
         // Value: ASCII
         if(h_has(cs, "geoid")) {
            temp = "North American Vertical Datum of 1988, Geoid "+cs.geoid;
            temp = strchar(temp);
            grow, KeyID, 4097s;
            grow, TIFFTagLocation, 34737s;
            grow, Count, short(numberof(temp));
            grow, Value_Offset, short(numberof(GeoASCIIParamsTag));
            grow, GeoASCIIParamsTag, temp;
         }
      } else {
         error, "unknown vert=";
      }
   } else if(cs.ellps == "GRS80") {
      grow, Value_Offset, 5019s;
   } else if(cs.ellps == "WGS84") {
      grow, Value_Offset, 5030s;
   } else {
      error, "unknown ellps=";
   }

   // VerticalUnitsGeoKey
   // Specifies the vertical units of measurement used.
   // Key ID = 4099
   // Values:
   //    (same as for ProjLinearUnitsGeoKey)
   grow, KeyId, 4099s;
   grow, TIFFTagLocation, 0s;
   grow, Count, 1s;
   grow, Value_Offset, 9001s;

   result = save(KeyId, TIFFTagLocation, Count, Value_Offset);
   if(!is_void(GeoASCIIParamsTag))
      save, result, GeoASCIIParamsTag;

   return result;
}
