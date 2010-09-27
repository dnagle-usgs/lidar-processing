// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_dt(text, dtlength=) {
/* DOCUMENT extract_dt(text, dtlength=)
   Attempts to extract a data tile name from each string in TEXT.

   Options:
      dtlength= Dictates whether to use the short or long form for data tile
         names. Valid values:
            dtlength="short"     Short form (default)
            dtlength="long"      Long form
*/
   local e, n, z;
   default, dtlength, "short";
   dt2utm_km, text, e, n, z;
   w = where(bool(e) & bool(n) & bool(z));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d" : "t_e%d000_n%d000_%d";
   if(numberof(w))
      result(w) = swrite(format=fmt, e(w), n(w), z(w));
   return result;
}

func extract_it(text, dtlength=) {
/* DOCUMENT extract_it(text, dtlength=)
   Attempts to extract an index tile name from each string in TEXT.

   Options:
      dtlength= Dictates whether to use the short or long form for index tile
         names. Valid values:
            dtlength="short"     Short form (default)
            dtlength="long"      Long form
*/
   result = extract_dt(text, dtlength=dtlength);
   w = where(result);
   if(numberof(w)) {
      if(dtlength == "long")
         result(w) = strpart(result(w), 3:);
      result(w) = "i_" + result(w);
   }
   return result;
}

func utm2dt(east, north, zone, dtlength=) {
/* DOCUMENT dt = utm2dt(east, north, zone, dtlength=)
   Returns the 2km data tile name for each east, north, and zone coordinate.
*/
   e = floor(east/2000.)*2;
   n = ceil(north/2000.)*2;
   return extract_dt(swrite(format="e%.0f_n%.0f_%d", e, n, long(zone)),
      dtlength=dtlength);
}

func utm2it(east, north, zone, dtlength=) {
/* DOCUMENT it = utm2it(east, north, zone, dtlength=)
   Returns the 10km data tile name for each east, north, and zone coordinate.
*/
   e = floor(east/10000.);
   n = ceil(north/10000.);
   return extract_it(swrite(format="e%.0f0_n%.0f0_%d", e, n, long(zone)),
      dtlength=dtlength);
}

func dt2utm_km(dtcodes, &east, &north, &zone) {
/* DOCUMENT dt2utm_km, dtcodes, &east, &north, &zone
   Parses the given data or index tile codes and sets the key easting,
   northing, and zone values. Values are in kilometers.
*/
   regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , east, , north, , zone;
   east = atoi(east);
   north = atoi(north);
   zone = atoi(zone);
}

func dt2uz(dtcodes) {
/* DOCUMENT dt2uz(dtcodes)
   Returns the UTM zone(s) for the given dtcode(s).
*/
// Original David Nagle 2009-07-06
   local zone;
   dt2utm_km, dtcodes, , , zone;
   return zone;
}

func dt2utm(dtcodes, &north, &east, &zone, bbox=, centroid=) {
/* DOCUMENT dt2utm(dtcodes, bbox=, centroid=)
   dt2utm, dtcodes, &north, &east, &zone

   Returns the northwest coordinates for the given dtcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   If centroid=1, then it returns the tile's central point.

   If called as a subroutine, it sets the northwest coordinates of the given
   output variables.
*/
//  Original David Nagle 2008-07-21
   local e, n, z;
   dt2utm_km, dtcodes, e, n, z;
   e *= 1000;
   n *= 1000;

   if(am_subroutine()) {
      north = n;
      east = e;
      zone = z;
      return;
   }

   if(is_void(z))
      return [];
   else if(bbox)
      return [n - 2000, e + 2000, n, e, z];
   else if(centroid)
      return [n - 1000, e + 1000, z];
   else
      return [n, e, z];
}

func it2utm(itcodes, bbox=, centroid=) {
/* DOCUMENT it2utm(itcodes, bbox=, centroid=)
   Returns the northwest coordinates for the given itcodes as an array of
   [north, west, zone].

   If bbox=1, then it instead returns the bounding boxes, as an array of
   [south, east, north, west, zone].

   If centroid=1, then it returns the tile's central point.
*/
//  Original David Nagle 2008-07-21
   u = dt2utm(itcodes);

   if(is_void(u))
      return [];
   else if(bbox)
      return [u(..,1) - 10000, u(..,2) + 10000, u(..,1), u(..,2), u(..,3)];
   else if(centroid)
      return [u(..,1) -  5000, u(..,2) +  5000, u(..,3)];
   else
      return u;
}
