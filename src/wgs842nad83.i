// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
/*
   Equations can be found at:
   http://www.linz.govt.nz/geodetic/conversion-coordinates/geodetic-datum-conversion/datum-transformation-equations/index.aspx
*/

func wgs842nad83(&lon, &lat, &height) {
/* DOUCMENT wgs842nad83, lon, lat, height
   Converts coordinates from WGS-84 to NAD-83. Conversion happens in place, or
   can be returned as [lon, lat, height].
*/
   local X, Y, Z;

   // Convert to cartesian coordinates
   geographic2cartesian, lon, lat, height, "wgs84", X, Y, Z;
   // Apply 7-param transform
   helmert_transformation, X, Y, Z, "wgs84 nad83";

   // Convert back to geographic coordinates
   if(am_subroutine()) {
      cartesian2geographic, X, Y, Z, "grs80", lon, lat, height;
   } else {
      return cartesian2geographic(X, Y, Z, "grs80");
   }
}

func nad832wgs84(&lon, &lat, &height) {
/* DOUCMENT nad832wgs84, lon, lat, height
   Converts coordinates from NAD-83 to WGS-84. Conversion happens in place, or
   can be returned as [lon, lat, height].
*/
   local X, Y, Z;

   // Convert to cartesian coordinates
   geographic2cartesian, lon, lat, height, "grs80", X, Y, Z;

   // Apply 7-param transform
   helmert_transformation, X, Y, Z, "nad83 wgs84";

   // Convert back to geographic coordinates
   if(am_subroutine()) {
      cartesian2geographic, X, Y, Z, "wgs84", lon, lat, height;
   } else {
      return cartesian2geographic(X, Y, Z, "wgs84");
   }
}

local __helmert;
/* DOCUMENT __helmert
   A yeti hash containing the parameter sets necessary for datum conversions.
   This is used by helmert_transformation. These are the 7 parameters for
   helmert:
      rx, ry, rz - rotation parameters in arcseconds
      tx, ty, tz - translation parameters in meters
      d - scale factor in ppm
*/
__helmert = h_new(
   "wgs84 nad83 wrong", h_new(
      rx = 0.0275, ry = 0.0101, rz = 0.0114,
      tx = 0.9738, ty = -1.9453, tz = -0.5486,
      d = 0.0
   ),
   "wgs84 nad83 right", h_new(
      rx = 0.0275, ry = 0.0101, rz = 0.0114,
      tx = -0.9738, ty = 1.9453, tz = 0.5486,
      d = 0.0
   )
);
// The inverse transformation is acheived by multiplying each element by -1.
k = h_keys(__helmert);
for(i = 1; i <= numberof(k); i++) {
   po = __helmert(k(i));
   pn = h_new(
      rx=po.rx*-1, ry=po.ry*-1, rz=po.rz*-1,
      tx=po.tx*-1, ty=po.ty*-1, tz=po.tz*-1,
      d=po.d*-1
   );
   po = []
   kn = strsplit(k(i), " ");
   kn([1,2]) = kn([2,1]);
   kn(:-1) += " ";
   h_set, __helmert, kn(sum), pn;
   kn = pn = [];
}
k = i = [];

func nad83_helmert_select(which) {
/* DOCUMENT nad83_helmert_select, "right"
   -or- nad83_helmert_select, "wrong"

   Specifies which set of Helmert transformation parameters should be used when
   converting between WGS-84 and NAD-83.

   Historically, ALPS data has used the parameters associated with "wrong". At
   present, "wrong" is the default.

   However, recent evidence suggests that the parameters for "right" are
   actually correct.

   The difference between right and wrong is simply a matter of flipped signs
   on three parameters.
*/
   if(is_void(which) || noneof(which == ["right", "wrong"]))
      error, "Must specify \"right\" or \"wrong\".";
   h_set, __helmert, "wgs84 nad83", __helmert("wgs84 nad83 " + which);
   h_set, __helmert, "nad83 wgs84", __helmert("nad83 wgs84 " + which);
}
nad83_helmert_select, "wrong";

func helmert_transformation(&X, &Y, &Z, transform) {
/* DOCUMENT helmert_transformation, X, Y, Z, transform
   Applies the 7-parameter Helmert transformation specified by transform to the
   given X, Y, and Z values, which are updated in place. Alternately, it will
   also return [X, Y, Z].
*/
   extern __helmert;
   p = __helmert(transform);
   if(!h_has(__helmert, transform))
      error, "Undefined transformation: " + transform;

   // Convert from arc-seconds to radians
   // arcsec2rad = pi / 180 / 60 / 60
   arcsec2rad = pi / 648000.;
   rx = p.rx * arcsec2rad;
   ry = p.ry * arcsec2rad;
   rz = p.rz * arcsec2rad;
   arcsec2rad = [];

   d = 1. + p.d/1000000.;

   // define rotation matrix
   rotmat = [
      [  d, -rz,  ry],
      [ rz,   d, -rx],
      [-ry,  rx,   d]
   ];

   XYZ = rotmat(+,) * [X(*),Y(*),Z(*)](,+);

   if(am_subroutine()) {
      X = XYZ(1,) + p.tx;
      Y = XYZ(2,) + p.ty;
      Z = unref(XYZ)(3,) + p.tz;
   } else {
      Xp = XYZ(1,) + p.tx;
      Yp = XYZ(2,) + p.ty;
      Zp = unref(XYZ)(3,) + p.tz;
      return [Xp, Yp, Zp];
   }
}

func geographic2cartesian(lon, lat, height, ellip, &X, &Y, &Z) {
/* DOCUMENT geographic2cartesian, lon, lat, height, ellip, X, Y, Z
   Given geographic coordinates in longitude, latitude, and height, this will
   convert them to X, Y, and Z cartesian coordinates using the parameters for
   the specified ellipsoid. The parameters X, Y, and Z are output parameters.
   Alternately, it will also return [X, Y, Z].
*/
   if(!h_has(ELLIPSOID, ellip))
      error, "Undefined ellipsoid: " + ellip;
   constants = ELLIPSOID(ellip);
   a = constants.a;
   e2 = constants.e2;
   constants = [];

   lon *= DEG2RAD;
   lat *= DEG2RAD;

   coslat = cos(lat);
   sinlat = sin(unref(lat));
   coslon = cos(lon);
   sinlon = sin(unref(lon));

   v = a / sqrt(1 - e2 * sinlat^2);
   v_height = v + height;

   X = v_height * coslat * unref(coslon);
   Y = unref(v_height) * unref(coslat) * unref(sinlon);
   Z = (unref(v) * (1 - e2) + unref(height)) * unref(sinlat);

   if(!am_subroutine())
      return [X, Y, Z];
}

func cartesian2geographic(X, Y, Z, ellip, &lon, &lat, &height) {
/* DOCUMENT cartesian2geographic, X, Y, Z, ellip, lon, lat, height
   Given cartesian coordinates as X, Y, and Z, this will convert them to
   geographic coordinates longitude, latitude, and height using the parameters
   for the specified ellipsoid. The parameters lon, lat, and height are output
   parameters. Alternately, it will also return [lon, lat, height].
*/
   if(!h_has(ELLIPSOID, ellip))
      error, "Undefined ellipsoid: " + ellip;
   constants = ELLIPSOID(ellip);
   a = constants.a;
   f = constants.f;
   e2 = constants.e2;
   constants = [];

   p2 = X*X + Y*Y;
   r = sqrt(p2 + Z*Z);
   p = sqrt(unref(p2));
   mu = atan(Z * ((1 - f) + e2 * a / r), p);

   lon = atan(unref(Y), unref(X));
   lat = atan(Z * (1 - f) + e2 * a * sin(mu)^3,
      (1 - f) * (p - e2 * a * cos(mu)^3));

   sinlat = sin(lat);
   height = p * cos(lat) + unref(Z) * sinlat - a * sqrt(1 - e2 * sinlat^2);

   lon *= RAD2DEG;
   lat *= RAD2DEG;

   if(!am_subroutine())
      return [lon, lat, height];
}
