// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_qq(text) {
/* DOCUMENT extract_qq(text)

   Extract the quarter quad string from a text string. The text string will
   probably be a filename or similar. The expected rules it will follow:

   - The QQ name may be optionally preceeded by other text, but must be
     separated by an underscore if so.
   - The QQ name may be optionally followed by other text, but must be
     separated by either an underscore or a period if so.
   - The QQ name must be exactly 8 characters in length, and must use lowercase
     alpha instead of uppercase alpha where relevant.

   This function will work on scalars or arrays. The returned result will be
   the quarter quad name(s). If there is no quarter quad to extract, it will
   be string(0).
*/
//  Original David Nagle 2008-07-17
   regmatch, "(^|_|qq)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   return qq;
}

func qq2uz(qq, centroid=) {
/* DOCUMENT qq2uz(qq, centroid=)

   Returns the UTM zone that the given quarter quad is expected to fall in.
   Since UTM zones are exactly six degrees longitude in width and have
   boundaries that coincide with full degrees of longitude, and since the
   quarter quad scheme is based on fractions of degrees longitude, any given
   quarter quad is guaranteed to fall in exactly one UTM zone.

   In practical terms, however, numbers sometimes do not computer properly.
   Occasionally a few points along the border will get placed wrong. Also,
   it is possible that the UTM coordinates may have been forcibly projected
   in an alternate UTM zone. So proceed with caution.

   If set to 1, the centroid= option will return the UTM coordinates of the
   center of the quarter quad rather than just the zone. This may be useful
   if trying to determine whether the expected zone corresponds to the data
   on hand.

   Original David Nagle 2008-07-15
*/
   default, centroid, 0;
   bbox = qq2ll(qq, bbox=1);
   invalid = where((bbox == 0)(..,sum) == 4);
   u = array(double, 3, dimsof(qq));
   u(*) = fll2utm( bbox(..,[1,3])(..,avg), bbox(..,[2,4])(..,avg) )(*);
   if(numberof(invalid))
      u(,invalid) = 0;
   if(centroid)
      return u;
   else
      return long(u(3,));
}

func qq2utm(qq, &north, &east, &zone, bbox=, centroid=) {
/* DOCUMENT qq2utm(qq, bbox=, centroid=)
   -or-  qq2utm, qq, north, east, zone

   Returns the northwest coordinates for the given qq as an array of [north,
   west, zone]. This is the coordinates for the northwest corner; however, it
   may not be the northmost or westmost point.

   If bbox=1, then it instead returns the bounding box as an array of [south,
   east, north, west, zone]. (Note that this does not exactly match the tile's
   boundary since bbox is in UTM but tile is in lat/long.)

   If centroid=1, then it returns the tile's central point.

   If called as subroutine, sets northwest coordinates in given output
   variables
*/
   local lats, lone, latn, lonw, e, n, z;
   splitary, qq2ll(qq, bbox=1), lats, lone, latn, lonw;

   // Calculate central point
   ll2utm, (lats+latn)/2., (lone+lonw)/2., n, e, z;

   if(!am_subroutine() && centroid)
      return [n, e, z];

   if(am_subroutine() || !bbox) {
      ll2utm, latn, lonw, n, e, force_zone=z;
      if(!am_subroutine())
         return [n, e, z];
      north = n;
      east = e;
      zone = z;
      return;
   }

   local xne, xse, xnw, xne, yne, yse, ynw, yne;
   ll2utm, latn, lone, yne, xne, force_zone=z;
   ll2utm, latn, lonw, ynw, xnw, force_zone=z;
   ll2utm, lats, lone, yse, xse, force_zone=z;
   ll2utm, lats, lonw, ysw, xsw, force_zone=z;

   return [min(yse, ysw), max(xne, xse), max(yne, ynw), min(xnw, xsw), z];
}

func qq2ll(qq, bbox=) {
/* DOCUMENT ll = qq2ll(qq, bbox=)

   Returns the latitude and longitude of the SE corner of the 24k Quarter-Quad
   represented by the give code (or array of codes).

   Return value is [lat, lon].

   If bbox=1, then return value is [south, east, north, west].

   See calc24qq for documentation on the 24k Quarter-Quad format.
*/
   default, bbox, 0;
   qq = extract_qq(qq);

   lat = array(double(0.), dimsof(qq));
   lon = array(double(0.), dimsof(qq));

   valid = where(qq);
   if(numberof(valid)) {
      qq = qq(valid);

      AA    = atoi(strpart(qq, 1:2));
      OOO   = atoi(strpart(qq, 3:5));
      a     =      strpart(qq, 6:6);
      o     = atoi(strpart(qq, 7:7));
      q     =      strpart(qq, 8:8);

      lat(valid) = AA;
      lon(valid) = OOO;

      // The following line converts a-h to 0-7
      a = int(atoc(strcase(0,a))) - int(atoc("a"));
      a *= 0.125;
      lat(valid) += a;

      o = o - 1;
      o = o * 0.125;
      lon(valid) += o;

      // The following line converts a-d to 1-4
      q = int(atoc(strcase(0,q))) - int(atoc("a")) + 1;
      qa = (q == 2 | q == 3);
      qo = (q >= 3);

      qa = qa * 0.0625;
      qo = qo * 0.0625;

      lat(valid) += qa;
      lon(valid) += qo;
   }

   if(bbox) {
      north = lat;
      west = lon;
      if(numberof(valid)) {
         north(valid) += 0.0625;
         west(valid) += 0.0625;
      }
      return [lat, -1 * lon, north, -1 * west];
   } else {
      return [lat, -1 * lon];
   }
}
