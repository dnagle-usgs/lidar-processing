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
