/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
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

   (This function can be called as either ll2utm or fll2utm; both are the same
   function.)

   Converts geographic coordinates (lat/lon) to UTM coordinates (north, east,
   zone).

   If called in the functional form, the return result u is a 3xn array:
      u(1,) is Northing
      u(2,) is Easting
      u(3,) is Zone

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

   See also: utm2ll
*/
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

   See also: ll2utm
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

func combine_zones(u) {
  //this function combines zones for plotting purposes.
  //amar nayegandhi 04/22/03
  //search for change in utm zones
   m = where(u(3,1:-1) != u(3,2:0));
   if (is_array(m)) {
      z = array(int,60);
      for (i=1;i<=numberof(m);i++) {
         //find the zones
         z(int(u(3,m(i))))++;
         z(int(u(3,m(i)+1)))++;
      } 
      lz = where(z);
      z1 = where(u(3,) == lz(1));
      z2 = where(u(3,) == lz(2));

      if (numberof(z1) > numberof(z2)) {
         u(2,z2) = 1000000-u(2,z2);
      } else {
         u(2,z1) = 1000000-u(2,z1);
      }

   }
   return u;
}

func dm2deg(coord) {
/* DOCUMENT dm2deg(coord)
   
   Converts coordinates in degree-minute format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMM.MM where DDD is the value for
         degrees and MM.MM is the value for minutes. Minutes must
         have a width of two (zero-padding if necessary). (The number
         of places after the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: deg2dm, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
   d = int(coord / 100.0);
   coord -= d * 100;
   m = coord / 60.0;
   deg = d + m;
   return d + m;
}

func deg2dm(coord) {
/* DOCUMENT deg2dm(coord)

   Converts coordinates in degrees to degree-minute format.

   Required parameter:

      coord: A scalar or array of coordinate values in degrees to
         be converted.

   Function returns:

      A scalar or array of converted degree-minute values.

   See also: dm2deg, ddm2deg, deg2ddm, dms2deg, deg2dms
*/
   d = floor(abs(coord));
   m = (abs(coord) - d) * 60;
   dm = sign(coord) * (d * 100 + m);
   return dm;
}

func ddm2deg(coord) {
/* DOCUMENT ddm2deg(coord)
   
   Converts coordinates in degree-deciminute format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMMMM.MM where DDD is the value for
         degrees and MMMM.MM is the value for deciminutes. Deciminutes
         must have a width of four (zero-padding if necessary). (The
         number of places after the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: dm2deg, deg2dm, deg2ddm, dms2deg, deg2dms
*/
   return dm2deg(coord / 100.0);
}

func deg2ddm(coord) {
/* DOCUMENT deg2ddm(coord)

   Converts coordinates in degrees to degree-deciminute format.

   Required parameter:

      coord: A scalar or array of coordinate values in degrees to
         be converted.

   Function returns:

      A scalar or array of converted degree-deciminute values.

   See also: dm2deg, deg2dm, ddm2deg, dms2deg, deg2dms
*/
   return deg2dm(coord) * 100;
}

func dms2deg(coord) {
/* DOCUMENT dms2deg(coord)
   
   Converts coordinates in degree-minute-second format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMMSS.SS where DDD is the value for
         degrees, MM is the value for minutes, and SS.SS is the value
         for seconds. Minutes and seconds must each have a width of
         two (zero-padding if necessary). (The number of places after
         the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.

   See also: dm2deg, deg2dm, deg2dms, ddm2deg, deg2ddm
*/
   d = int(coord / 10000.0);
   coord -= d * 10000;
   m = int(coord / 100.0);
   s = coord - (m * 100);
   deg = d + m / 60.0 + s / 3600.0;
   return deg;
}

func deg2dms(coord, arr=) {
/* DOCUMENT deg2dms(coord, arr=)

   Converts coordinates in degrees to degrees, minutes, and seconds.

   Required parameter:

      coord: A scalar or array of coordinates values in degrees to
         be converted.

   Options:

      arr= Set to any non-zero value to make this return an array
         of [d, m, s]. Otherwise, returns [ddmmss.ss].

   Function returns:

      Depending on arr=, either [d, m, s] or [ddmmss.ss].

   See also: dm2deg, deg2dm, dms2deg, ddm2deg, deg2ddm
*/
   d = floor(abs(coord));
   m = floor((abs(coord) - d) * 60);
   s = ((abs(coord) - d) * 60 - m) * 60;
   if(arr)
      return sign(coord) * [d, m, s];
   else
      return sign(coord) * (d * 10000 + m * 100 + s);
}

func deg2dms_string(coord) {
/* DOCUMENT deg2dms_string(coord)
   Given a coordinate (or array of coordinates) in decimal degrees, this
   returns a string (or array of strings) in degree-minute-seconds, formatted
   nicely.
*/
   dms = deg2dms(coord, arr=1);
   // ASCII: 176 = degree  39 = single-quote  34 = double-quote
   return swrite(format="%.0f%c %.0f%c %.2f%c", dms(..,1), 176, abs(dms(..,2)),
      39, abs(dms(..,3)), 34);
}
