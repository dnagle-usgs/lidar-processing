// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
// original amar nayegandhi 07/15/03
// modified charlene sullivan 09/25/06
require, "l1pro.i";

func datum_convert_data(&data_in, zone=, src_datum=, src_geoid=, dst_datum=,
dst_geoid=, verbose=) {
/* DOCUMENT converted = datum_convert_data(data, zone=, src_datum=, src_geoid=,
      dst_datum=, dst_geoid=)
   datum_convert_data, data, zone=, src_datum=, src_geoid=, dst_datum=,
      dst_geoid=

   Converts data from one datum to another. The following transformations are
   possible:
         w84 -> n83
         w84 -> n88
         n83 -> n88
         n88_g03 -> n88_g09 (etc.)
         n88 -> n83
         n88 -> w84
         n83 -> w84

   Parameters:
      data: The data to convert, in an ALPS data structure (such as VEG__, GEO,
         etc.). If called as a function, the new data will be returned. If
         called as a subroutine, data is updated in place.

   Options:
      zone= The UTM zone of the data. If not provided, it defaults to curzone.
      src_datum= The datum that the original data is in. Possible values:
            src_datum="w84"   - data is in WGS-84 (default)
            src_datum="n83"   - data is in NAD-83
            src_datum="n88"   - data is in NAVD-88
      src_geoid= When using NAVD-88, there are several GEOIDs released that can
         be used. This specifies which one the original data is in. Possible
         values:
            src_geoid="96"    - for GEOID96
            src_geoid="99"    - for GEOID99
            src_geoid="03"    - for GEOID03 (default)
            src_geoid="09"    - for GEOID09
         If src_datum is not set to n88, then src_geoid has no effect.
      dst_datum= The datum that the converted data should be in. Possible
         values:
            dst_datum="w84"   - use WGS-84
            dst_datum="n83"   - use NAD-83
            dst_datum="n88"   - use NAVD-88 (default)
      dst_geoid= When using NAVD-88, this specifies which geoid to use for the
         converted data. Possible values:
            dst_geoid="96"    - for GEOID96
            dst_geoid="99"    - for GEOID99
            dst_geoid="03"    - for GEOID03
            dst_geoid="09"    - for GEOID09 (default)
         If dst_datum is not set to n88, then dst_geoid has no effect.

   The default for dst_geoid will change in the future when new GEOID models
   are released.

   The src_geoid= and dst_geoid= options may also have their value prefixed by
   a lowercase g (ie., src_geoid="g09").

   See also: datum_convert_utm, datum_convert_geo, datum_convert_pnav
*/
   default, verbose, 1;
   extern curzone;
   if(is_void(zone)) {
      if(curzone) {
         zone = curzone;
         write, format="Setting zone= to curzone: %d\n", curzone;
      } else {
         write, "Aborting. Please specify zone= or define extern curzone.";
         return;
      }
   }

   local data_out;
   if(am_subroutine()) {
      eq_nocopy, data_out, data_in;
   } else {
      data_out = data_in;
   }

   if (!structeq(structof(data_out), LFP_VEG)) {
      data_out(*) = test_and_clean(data_out);
   }

   defns = h_new(
      "First Return", h_new(e="east", n="north", z="elevation"),
      "Mirror", h_new(e="meast", n="mnorth", z="melevation"),
      "Last Return", h_new(e="least", n="lnorth", z="lelv")
   );
   order = ["Mirror", "First Return", "Last Return"];

   for(i = 1; i <= numberof(order); i++) {
      cur = defns(order(i));
      if(
         has_member(data_out, cur.e) && has_member(data_out, cur.n) &&
         has_member(data_out, cur.z)
      ) {
         if(verbose)
            write, format="Converting %s:\n  ", order(i);
         north = get_member(data_out, cur.n)/100.;
         east = get_member(data_out, cur.e)/100.;
         height = get_member(data_out, cur.z);

         if(is_pointer(height)) {
            for(j = 1; j <= numberof(height); j++) {
               cnorth = north(i);
               ceast = east(i);
               cheight = *height(i)/100.;
               w = where(cnorth == 0);
               datum_convert_utm, cnorth, ceast, cheight, zone=zone,
                  src_datum=src_datum, src_geoid=src_geoid, dst_datum=dst_datum,
                  dst_geoid=dst_geoid, verbose=verbose;
               if(numberof(w))
                  cnorth(w) = ceast(w) = cheight(w) = 0;
               write, format="%s", "\n";
               north(i) = cnorth;
               east(i) = ceast;
               height(i) = &(long(unref(cheight) * 100 + 0.5));
            }
         } else {
            height /= 100.;
            w = where(north == 0);
            datum_convert_utm, north, east, height, zone=zone,
               src_datum=src_datum, src_geoid=src_geoid, dst_datum=dst_datum,
               dst_geoid=dst_geoid, verbose=verbose;
            if(numberof(w))
               north(w) = east(w) = height(w) = 0;
            write, format="%s", "\n";
            height = long(unref(height) * 100 + 0.5);
         }

         get_member(data_out, cur.n) = long(unref(north) * 100 + 0.5);
         get_member(data_out, cur.e) = long(unref(east) * 100 + 0.5);
         get_member(data_out, cur.z) = height;
      }
   }

   return data_out;
}

func datum_convert_utm(&north, &east, &elevation, zone=, src_datum=,
src_geoid=, dst_datum=, dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_utm(north, east, elevation, zone=, src_datum=,
   src_geoid=, dst_datum=, dst_geoid=)

   Datum converts the northing, easting, and elevation values given. If called
   as a subroutine, they are updated in place; otherwise they are returned as
   [north, east, elevation].

   All options are the same as is documented in datum_convert_data.

   See also: datum_convert_data, datum_convert_geo
*/
   extern curzone;
   default, verbose, 2;
   if(is_void(zone)) {
      if(curzone) {
         zone = curzone;
         write, format="Setting zone= to curzone: %d\n", curzone;
      } else {
         write, "Aborting. Please specify zone= or define extern curzone.";
         return;
      }
   }

   local lon, lat;

   if(verbose > 1)
      write, "Converting data to lat/lon...";
   else if(verbose)
      write, format="%s", "utm -> lat/lon";
   utm2ll, north, east, zone, lon, lat;

   if(verbose == 1)
      write, format="%s", " | ";
   datum_convert_geo, lon, lat, elevation, src_datum=src_datum,
      src_geoid=src_geoid, dst_datum=dst_datum, dst_geoid=dst_geoid, verbose=verbose;
   if(verbose == 1)
      write, format="%s", " | ";

   if(verbose > 1)
      write, "Converting data to UTM...";
   else if(verbose)
      write, format="%s", "lat/lon -> utm";
   fll2utm, lat, lon, north, east, zone;

   if(!am_subroutine())
      return [north, east, elevation];
}

func datum_convert_geo(&lon, &lat, &height, src_datum=, src_geoid=, dst_datum=,
dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_geo(lon, lat, height, src_datum=, src_geoid=,
   dst_datum=, dst_geoid=)

   Datum converts the longitude, latitude, and height values given. If called
   as a subroutine, they are updated in place; otherwise they are returned as
   [lon, lat, height].

   All options are the same as is documented in datum_convert_data.

   See also: datum_convert_data, datum_convert_utm
*/
   default, src_datum, "w84";
   default, src_geoid, "03";
   default, dst_datum, "n88";
   default, dst_geoid, "09";
   default, verbose, 2;

   src_geoid = regsub("^g", src_geoid, "");
   dst_geoid = regsub("^g", dst_geoid, "");

   /* In all valid cases, we'll at some point be transitioning through n83.
               w84 -> n83
               w84 -> n83 -> n88
                      n83 -> n88
           n88_g03 -> n83 -> n88_g09
               n88 -> n83
               n88 -> n83 -> w84
                      n83 -> w84
   */

   if(src_datum == "w84") {
      if(verbose > 1)
         write, "Converting WGS84 to NAD83...";
      else if(verbose)
         write, format="%s", "wgs84 -> nad83";
      wgs842nad83, lon, lat, height;
   } else if(src_datum == "n88") {
      if(verbose > 1)
         write, format=" Converting NAVD88 (geoid %s) to NAD83...\n", src_geoid;
      else if(verbose)
         write, format="navd88 geoid %s -> nad83", src_geoid;
      navd882nad83, lon, lat, height, geoid=src_geoid, verbose=0;
   } else if(verbose == 1) {
      write, format="%s", "nad83";
   }

   if(dst_datum == "w84") {
      if(verbose > 1)
         write, "Converting NAD83 to WGS84...";
      else if(verbose)
         write, format="%s", " -> wgs84";
      nad832wgs84, lon, lat, height;
   } else if(dst_datum == "n88") {
      if(verbose > 1)
         write, format=" Converting NAD83 to NAVD88 (geoid %s)...\n", dst_geoid;
      else if(verbose)
         write, format=" -> navd88 geoid %s", dst_geoid;
      nad832navd88, lon, lat, height, geoid=dst_geoid, verbose=0;
   }
}

func datum_convert_pnav(pnav=, infile=, export=, outfile=, src_datum=, src_geoid=, dst_datum=, dst_geoid=, verbose=) {
/* DOCUMENT datum_convert_pnav(pnav=, infile=, export=, outfile=, src_datum=,
   src_geoid=, dst_datum=, dst_geoid=)

   Converts PNAV data from one datum to another.

   For the source data, one of the following two options must be specified:
      pnav= An array of pnav data.
      infile= A file with pnav data to load.

   Optionally, the convereted data can also be exported to file with these options:
      export= Set export=1 to save the data to file.
      outfile= The file to save the data to. If omitted, it will be based on
         infile (if it is defined).

   The rest of the options are as defined in datum_convert_data. The converted
   PNAV data is returned.

   See also: datum_convert_data datum_convert_geo
*/
   local pnav;
   default, verbose, 1;
   verbose *= 2;

   if(infile)
      pnav = load_pnav(fn=infile);

   if(is_void(pnav))
      error, "No pnav data chosen.";

   lon = pnav.lon;
   lat = pnav.lat;
   alt = pnav.alt;

   w = where(pnav.lon == 0 | pnav.lat == 0);

   datum_convert_geo, lon, lat, alt, src_datum=src_datum, src_geoid=src_geoid,
      dst_datum=dst_datum, dst_geoid=dst_geoid, verbose=verbose;

   pnav.lon = unref(lon);
   pnav.lat = unref(lat);
   pnav.alt = unref(alt);

   if(numberof(w)) {
      pnav.lon(w) = 0;
      pnav.lat(w) = 0;
      pnav.alt(w) = 0;
   }

   if(export) {
      if(is_void(outfile)) {
         if(is_void(infile)) {
            write, "Cannot export, no outfile= specified.";
         } else {
            outfile = file_rootname(infile) + "-nad83.pbd";
         }
      }
      if(!is_void(outfile))
         save, createb(outfile), pnav;
   }

   return pnav;
}
