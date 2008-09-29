/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$"

require, "zone.i";

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

deg2rad = pi / 180.0;
rad2deg = 180.0 / pi;
FOURTHPI = pi / 4.0;

func ll2utm( lat, lon, force_zone= ) {
/* DOCUMENT  ll2utm(lat, lon, force_zone=)
  
   Convert lat/lon pairs to UTM.  Returns values in
   the global arrays UTMNorthing, UTMEasting, and UTMZone;

   If retarr=1, then [UTMNorthing, UTMEasting] are returned.
   Otherwise, numberof(UTMEasting) is returned.

   If a zone is provided by the option force_zone= or by the extern fixedzone,
   the coordinates will be forced to that zone. If both are set, then
   force_zone takes precedence.

   See also:  fll2utm.
*/
   extern UTMEasting, UTMNorthing, ZoneNumber;
   u = fll2utm(lat, lon, force_zone=force_zone);
   UTMNorthing = u(1, );
   UTMEasting  = u(2, );
   ZoneNumber  = u(3, );

   if (!retarr) {
      return numberof(u(1, ));
   } else {
      return [u(2, ), u(1, )];
   }  
}

func fll2utm(lat, lon, force_zone=) {
/* DOCUMENT  u=fll2utm(lat, lon, force_zone=)

   Convert latitude and longitude pairs to utm and return 
   a 3xn  array of values where:

   u(1,)   is Northing
   u(2,)   is Easting
   u(3,)   is Zone

   If a zone is provided by the option force_zone= or by the extern fixedzone,
   the coordinates will be forced to that zone. If both are set, then
   force_zone takes precedence.

   See also: ll2utm.
*/
   extern fixedzone, curzone;
   //       earth      
   //       radius     ecc
   wgs84 = [6378137, 0.00669438];
   wgs72 = [6378135, 0.006694318];
   eccSquared        = double(wgs84(2));
   Earth_radius      = double(wgs84(1));
   k0                = double(0.9996);
   eccPrimeSquared   = eccSquared/(1-eccSquared);

   u = array(double, 3, numberof(lat));

   //Make sure the longitude is between -180.00 .. 179.9
   // Original:
   //lonTemp = (lon+180)-int((lon+180)/360)*360-180;
   // Simplified (more efficient):
   lonTemp = -int((lon+180.0)/360)*360 + lon;
   // Original:
   //ZoneNumber = int((lonTemp + 180)/6) + 1;
   // Simplified (more efficient):
   if (!is_void(force_zone)) {
      u(3, *) = force_zone;
   } else if (is_array(fixedzone)) {
      u(3, *) = fixedzone; // set to fixedzone when set.. this is useful when data crosses utm zones.
      curzone=fixedzone;
   } else {
      u(3, ) = int(lonTemp/6 + 31)
   }

   latRad = double(lat*deg2rad);
   lonRad = double(lonTemp*deg2rad);
   lat = lon = lonTemp = []; // free memory

   // Original:
   //lonOrigin = (ZoneNumber - 1) *6 - 180 + 3;  //+3 puts origin in middle of zone
   //lonOriginRad = lonOrigin * deg2rad;
   // Simplified (more efficient):
   lonOriginRad = (6 * u(3,) - 183) * deg2rad;

   N = Earth_radius/sqrt(1-eccSquared*sin(latRad)*sin(latRad));
   T = tan(latRad)*tan(latRad);
   C = eccPrimeSquared*cos(latRad)*cos(latRad);
   A = cos(latRad)*(lonRad-lonOriginRad);
   lonRad = []; // free memory

   M = (
      (1 - eccSquared/4     -  3*eccSquared^2/64  -  5*eccSquared^3/256 ) * latRad        -
      (3 * eccSquared/8     +  3*eccSquared^2/32  + 45*eccSquared^3/1024) * sin(2*latRad) +
      (15* eccSquared^2/256 + 45*eccSquared^3/1024                      ) * sin(4*latRad) -
      (35* eccSquared^3/3072                                            ) * sin(6*latRad)
   ) * Earth_radius;

   // Original:
   //UTMEasting = (double)(k0*N*(A+(1-T+C)*A*A*A/6 + \
   //   (5-18*T+T*T+72*C-58*eccPrimeSquared)*A*A*A*A*A/120) + 500000.0);
   // Optimized:
   u(2, ) =
      ((5-18*T+T*T+72*C-58*eccPrimeSquared)*A^5/120+A+(1-T+C)*A^3/6)*k0*N+500000.0;

   // Original:
   //UTMNorthing = (double)(k0*(M+N*tan(latRad)*(A*A/2+(5-T+9*C+4*C*C)*A*A*A*A/24 + \
   //   (61-58*T+T*T+600*C-330*eccPrimeSquared)*A*A*A*A*A*A/720)));
   // Optimized:
   u(1, ) =
      (((-(58+T)*T+600*C-330*eccPrimeSquared+61)*A^6/720+(5-T+9*C+4*C*C)*A^4/24+A*A/2)*N*tan(latRad)+M)*k0;

   return u;
}

func utm2ll( UTMNorthing, UTMEasting, UTMZone) {
/* DOCUMENT  utm2ll( UTMNorthing, UTMEasting, UTMZone)

   Convert UTM coords. to  lat/lon.  Returned values are
   in Lat and Long;

   NOTE: Returns [long, lat], NOT [lat, long]
*/

   extern Lat, Long;
   //       earth
   //       radius     ecc
   wgs84 = [6378137, 0.00669438];
   wgs72 = [6378135, 0.006694318];
   eccSquared    = double(wgs84(2));
   Earth_radius  = double(wgs84(1));
   k0            = double(0.9996);
   e1 = double(1-sqrt(1-eccSquared))/(1+sqrt(1-eccSquared));
   NorthernHemisphere = 1;
   x = UTMEasting - 500000.0;
   y = UTMNorthing;
   M = y / k0;
   LongOrigin = (UTMZone - 1)*6 - 180 + 3;
   eccPrimeSquared = double(eccSquared)/(1-eccSquared);
   mu = M/(Earth_radius*(1-eccSquared/4-3*eccSquared*eccSquared/64- \
      5*eccSquared*eccSquared*eccSquared/256));

   phi1Rad = mu    + (3*e1/2-27*e1*e1*e1/32)*sin(2*mu) \
      + (21*e1*e1/16-55*e1*e1*e1*e1/32)*sin(4*mu) \
      +(151*e1*e1*e1/96)*sin(6*mu);

   phi1 = phi1Rad*rad2deg;

   N1 = Earth_radius/sqrt(1-eccSquared*sin(phi1Rad)*sin(phi1Rad));
   T1 = tan(phi1Rad)*tan(phi1Rad);
   C1 = eccPrimeSquared*cos(phi1Rad)*cos(phi1Rad);
   R1 = Earth_radius*(1-eccSquared)/(1-eccSquared* \
      sin(phi1Rad)*sin(phi1Rad))^ 1.5;
   D = x/(N1*k0);

   Lat = phi1Rad - \
      (N1*tan(phi1Rad)/R1)*(D*D/2- \
      (5+3*T1+10*C1-4*C1*C1-9*eccPrimeSquared)*D*D*D*D/24 + \
      (61+90*T1+298*C1+45*T1*T1-252*eccPrimeSquared- \
      3*C1*C1)*D*D*D*D*D*D/720);

   Lat *= rad2deg;

   Long = (D-(1+2*T1+C1)*D*D*D/6+(5-2*C1+28*T1- \
            3*C1*C1+8*eccPrimeSquared+24*T1*T1) \
         *D*D*D*D*D/120)/cos(phi1Rad);

   Long = LongOrigin + Long * rad2deg;
   return [Long, Lat]
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
   dms = sign(coord) * (d * 10000 + m * 100 + s);
   if(arr)
      return sign(coord) * [d, m, s];
   else
      return dms;
}
