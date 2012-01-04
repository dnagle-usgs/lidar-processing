// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

/*
  Lat/Lon to UTM converter in Yorick
  Converted from C++ program found at:
    http://www.gpsy.com/gpsinfo/geotoutm/index.html
    C++ version written by: Chuck Gantz chuck.gantz@globalstar.com
    Source Defense Mapping Agency. 1987b. DMA Technical Report:
    Supplement to Department of Defense World Geodetic System
    1984 Technical Report. Part I and II. Washington, DC:
    Defense Mapping Agency.  Equations from USGS Bulletin 1532.

  Converted to Yorick by C. W. Wright wright@osb.wff.nasa.gov
  6/21/1999
*/

/*
  Citation for the math involved:
    Snyder, John P. (1987). Map Projections - A Working Manual. US Geological
    Survey Professional Paper 1395.
  PDF can be downloaded at:
    http://pubs.er.usgs.gov/usgspubs/pp/pp1395
  Page numbers noted below are all for the paper copy. To convert to PDF page
  numbers, add 9.
*/

func fll2utm {}
func ll2utm(lat, lon, &north, &east, &zone, force_zone=, ellipsoid=) {
/* DOCUMENT u = ll2utm(lat, lon, force_zone=, ellipsoid=)
  ll2utm, lat, lon, north, east, zone, force_zone=, ellipsoid=
  uxyz = ll2utm(llxyz, force_zone=, ellipsoid=)

  (This function can be called as either ll2utm or fll2utm; both are the same
  function.)

  Converts geographic coordinates (lat/lon) to UTM coordinates (north, east,
  zone).

  If called in the functional form with parameters lat and lon, the return
  result u is a 3xn array:
    u(1,) is Northing
    u(2,) is Easting
    u(3,) is Zone

  If called in the functional form with parameter llxyz, then llxyz must be a
  two-dimensional array of [lon,lat] or [lon,lat,elev] (or either transposed).
  The return result will be [east,north] or [east,north,elev]. If force_zone
  is not provided, then all coordinates will be converted to the zone that
  most of the data is in.

  If a zone is provided by the option force_zone= or by the extern fixedzone,
  the coordinates will be forced to that zone. If both are set, then
  force_zone takes precedence. (Note that fixedzone should only be used as a
  last resort!)

  The ellipsoid= option allows you to specify the ellipsoid to operate in.
  This defaults to ellipsoid="wgs84". See help, ELLIPSOID for other options.

  Historic note: The function ll2utm used to be separate from fll2utm. It
  would set the extern variables UTMNorthing, UTMEasting, and ZoneNumber. This
  usage was removed 2010-03-03 and both functions were made equivalent. If you
  need those externs set, then call the function in its subroutine form as
  such:
    ll2utm, lat, lon, UTMNorthing, UTMEasting, ZoneNumber

  SEE ALSO: utm2ll
*/
  // Support for 2-dimensional input
  if(!am_subroutine() && is_void(lon)) {
    z = [];
    if(dimsof(lat)(1) != 2)
      error, "Invalid call to ll2utm";
    if(anyof(dimsof(lat)(2:3) == 3)) {
      tmp = lat;
      splitary, unref(tmp), 3, lon, lat, z;
    } else if(anyof(dimsof(lat)(2:3) == 2)) {
      tmp = lat;
      splitary, unref(tmp), 2, lon, lat;
    } else {
      error, "Invalid call to ll2utm";
    }
    ll2utm, lat, lon, north, east, zone, force_zone=force_zone,
      ellipsoid=ellipsoid;
    if(is_void(force_zone) && allof(zone != zone(1))) {
      force_zone = histogram(zone)(mxx);
      ll2utm, lat, lon, north, east, zone, force_zone=force_zone,
        ellipsoid=ellipsoid;
    }
    return is_void(z) ? [east, north] : [east, north, z];
  }

  extern fixedzone, curzone;
  default, ellipsoid, "wgs84";

  // Retrieve ellipsoid-specific constants
  // a is semi-major axis
  a = ELLIPSOID(ellipsoid).a;
  // e2 is eccentricity squared
  e2 = ELLIPSOID(ellipsoid).e2;

  // Make sure we're working with copies so we don't change source data.
  lat = (lat);
  lon = (lon);

  // Make sure lat/lon are compatible
  dims = dimsof(lat, lon);
  if(is_void(dims))
    error, "lat and lon are not conformable";

  // Initialize output arrays
  north = east = array(double, dims);
  zone = array(short(0), dims);

  // Broadcast up front so that it only has to get done once
  if(numberof(lat) < numberof(zone))
    lat += zone;
  if(numberof(lon) < numberof(zone))
    lon += zone;

  // Fill in zone if appropriate
  if (!is_void(force_zone)) {
    zone += force_zone;
  } else if (!is_void(fixedzone)) {
    curzone = fixedzone;
    zone += fixedzone;
  }

  // *** Attempts to use CALPS ***
  if(is_func(_yll2utm)) {
    _yll2utm, lat, lon, north, east, zone, numberof(zone), a, e2;
    if(am_subroutine())
      return;
    else
      return transpose([north, east, zone]);
  }

  // The code that follows is structured to mirror the code in the C function
  // from CALPS, so that the two can be kept in sync in case of code changes /
  // bug fixes.

  // *** Calculate scalar values ***

  // Scale factor along central meridian
  k0 = 0.9996;

  // eccentricity prime squared
  ep2 = e2/(1-e2);

  // higher powers of eccentricity squared
  e4 = e2*e2;
  e6 = e4*e2;

  // constants used in M equation further below
  M0 = 1 - e2/4 - 3*e4/64 - 5*e6/256;
  M2 = 3*e2/8 + 3*e4/32 + 45*e6/1024;
  M4 = 15*e4/256 + 45*e6/1024;
  M6 = 35*e6/3072;

  // *** Now do vectorized operations ***

  // Make sure the longitude is between -180.00 .. 179.9
  lon -= floor(.5+lon/360.)*360.;

  // Calculate zone if needed
  if (is_void(force_zone) && is_void(fixedzone)) {
    zone() = short(lon/6. + 31);
  }

  // Convert to radians
  lat *= DEG2RAD;
  lon *= DEG2RAD;

  // Central meridian
  cmeridian = (zone * 6 - 183) * DEG2RAD;

  // PP1395 eq 4-20 p25, p61
  // N is radius of curvature of the ellipsoid in a plane perpendicular to the
  // meridian and also perpendiuclar to a plane tangent to the surface
  N = a/sqrt(1-e2*sin(lat)^2);

  // PP1395 eq 8-13 p61
  T = tan(lat)^2;

  // PP1395 eq 8-14 p61
  C = ep2*cos(lat)^2;

  // PP1395 eq 8-15 p61
  A = cos(lat)*(lon-cmeridian);

  lon = cmeridian = []; // free memory

  // PP1395 eq 3-21 p17, p61
  // M is the true distance along the central meridian from the equator to
  // this latitude
  //M = (
  //   (1 - e2/4   -  3*e4/64  -  5*e6/256 ) * lat        -
  //   (3 * e2/8   +  3*e4/32  + 45*e6/1024) * sin(2*lat) +
  //   (15* e4/256 + 45*e6/1024            ) * sin(4*lat) -
  //   (35* e6/3072                        ) * sin(6*lat)
  //) * a;
  // The constant factors are calculated once earlier above, yielding this:
  M = (
    M0 * lat - M2 * sin(2*lat) +
    M4 * sin(4*lat) - M6 * sin(6*lat)
  ) * a;

  // PP1395 eq 8-9 p61
  east() =
    ((5-18*T+T*T+72*C-58*ep2)*A^5/120+A+(1-T+C)*A^3/6)*k0*N+500000.0;

  // PP1395 eq 8-10 p61
  north() = (
    ( (-(58+T)*T + 600*C - 330*ep2 + 61
      ) * A^6 / 720 + (5-T+9*C+4*C*C) * A^4/24 + A*A/2
    ) * N * tan(lat) + M
  ) * k0;

  if(!am_subroutine())
    return transpose([north, east, zone]);
}
fll2utm = ll2utm;

func utm2ll(north, east, zone, &lon, &lat, ellipsoid=) {
/* DOCUMENT ll = utm2ll(north, east, zone, ellipsoid=)
  utm2ll, north, east, zone, lon, lat, ellipsoid=;

  Converts UTM coordinates (north, east, zone) to geographic coordinates
  (lat/lon).

  If called in the functional form, the return result ll is an nx2 array of
  [lon, lat].

  The ellipsoid= option allows you to specify the ellipsoid to operate in.
  This defaults to ellipsoid="wgs84". See help, ELLIPSOID for other options.

  SEE ALSO: ll2utm
*/
  default, ellipsoid, "wgs84";

  // *** Calculate scalar values ***

  // Retrieve ellipsoid-specific constants
  // a is semi-major axis
  a = ELLIPSOID(ellipsoid).a;
  // e2 is eccentricity squared
  e2 = ELLIPSOID(ellipsoid).e2;

  // *** Attempts to use CALPS ***
  if(is_func(_yutm2ll)) {
    // Preallocate results; broadcast input or explode.
    lat = lon = array(double(0), dimsof(north, east, zone));
    count = numberof(lat);
    if(numberof(north) < count)
      north += lat;
    if(numberof(east) < count)
      east += lat;
    if(numberof(zone) < count)
      zone += lat;
    _yutm2ll, north, east, short(zone), lon, lat, count, a, e2;
    if(am_subroutine())
      return;
    else
      return [lon, lat];
  }

  // The code that follows is structured to mirror the code in the C function
  // from CALPS, so that the two can be kept in sync in case of code changes /
  // bug fixes.

  // Scale factor along central meridian
  k0 = 0.9996;

  // PP1395 eq 8-12 p61, p64
  // eccentricity prime squared
  ep2 = e2/(1-e2);

  // PP1395 eq 3-24 ??, p63
  e1 = (1-sqrt(1-e2))/(1+sqrt(1-e2));

  // *** Now do vectorized operations ***

  x = east - 500000.0;
  y = north;

  // PP1395 eq 8-20 p63
  // M = M0 + y/k0
  // Apparently M0 is 0 here...
  M = y / k0;

  lon0 = DEG2RAD * ((zone - 1)*6 - 180 + 3);

  // PP1395 eq 7-10 p??, p63
  mu = M/(a*(1-e2/4-3*e2*e2/64 - 5*e2*e2*e2/256));

  // PP1395 eq 3-26 p??, p63
  // "footprint latitude" or latitude at central meridian which has same y
  // coordinate as that of the point (lat,lon).
  lat1 = mu + (3*e1/2-27*e1*e1*e1/32)*sin(2*mu) +
    (21*e1*e1/16-55*e1*e1*e1*e1/32)*sin(4*mu) +
    (151*e1*e1*e1/96)*sin(6*mu);

  // PP1395 eq 8-23 p64
  N1 = a/sqrt(1-e2*sin(lat1)^2);
  // PP1395 eq 8-22 p64
  T1 = tan(lat1)^2;
  // PP1395 eq 8-21 p64
  C1 = ep2*cos(lat1)^2;
  // PP1395 eq 8-24 p64
  R1 = a*(1-e2)/(1-e2*sin(lat1)^2)^1.5;
  // PP1395 eq 8-25 p64
  D = x/(N1*k0);

  // PP1395 eq 8-17 p63
  lat = lat1 -
    (N1*tan(lat1)/R1)*(D*D/2-
    (5+3*T1+10*C1-4*C1*C1-9*ep2)*D*D*D*D/24 +
    (61+90*T1+298*C1+45*T1*T1-252*ep2-
    3*C1*C1)*D*D*D*D*D*D/720);

  // PP1395 eq 8-18 p63
  lon = lon0 + (D-(1+2*T1+C1)*D*D*D/6+(5-2*C1+28*T1-
      3*C1*C1+8*ep2+24*T1*T1)
      *D*D*D*D*D/120)/cos(lat1);

  lat *= RAD2DEG;
  lon *= RAD2DEG;

  if(!am_subroutine())
    return [lon, lat];
}
