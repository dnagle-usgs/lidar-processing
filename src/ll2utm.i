/*

  $Id$

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

write, "$Id$"

//Lat = [37.0, 38, 39]
//Long = [-74.0, -75.0, -72.0]

deg2rad = pi / 180.0;
rad2deg = 180.0 / pi;
FOURTHPI = pi / 4.0;

func fll2utm( lat, lon ) {
/* DOCUMENT  u=fll2utm(lat, lon)
  
   Convert latitude and longitude pairs to utm and return 
   a 3xn  array of values where:

   u(1,)   is Northing
   u(2,)   is Easting
   u(3,)   is Zone

   See also:  ll2utm.
*/


  n=ll2utm(lat, lon);
  u = array( double, 3, n);
  u(1, ) = UTMNorthing;
  u(2, ) = UTMEasting;
  u(3, ) = ZoneNumber;
  return u;
}

func ll2utm( lat, lon, retarr= ) {
/* DOCUMENT  ll2utm(lat, lon)

   Convert lat/lon pairs to UTM.  Returns values in
   the global arrays UTMNorth, UTMEasting, and UTMZone;

   See also: fll2utm.
*/
extern UTMEasting, UTMNorthing, ZoneNumber;
//       earth      
//       radius     ecc
wgs84 = [6378137, 0.00669438];
wgs72 = [6378135, 0.006694318];
eccSquared    = double(wgs84(2));
Earth_radius  = double(wgs84(1));
k0         = double(0.9996);
eccPrimeSquared = double(eccSquared)/(1-eccSquared);


//Make sure the longitude is between -180.00 .. 179.9
lonTemp = (lon+180)-int((lon+180)/360)*360-180;
ZoneNumber = int((lonTemp + 180)/6) + 1;

latRad = double(lat*deg2rad);
lonRad = double(lonTemp*deg2rad);

lonOrigin = (ZoneNumber - 1)*6 - 180 + 3;  //+3 puts origin in middle of zone
lonOriginRad = lonOrigin * deg2rad;

N = Earth_radius/sqrt(1-eccSquared*sin(latRad)*sin(latRad));
T = tan(latRad)*tan(latRad);
C = eccPrimeSquared*cos(latRad)*cos(latRad);
A = cos(latRad)*(lonRad-lonOriginRad);

M = Earth_radius*((1- eccSquared/4 - \
	3*eccSquared*eccSquared/64 - \
	5*eccSquared*eccSquared*eccSquared/256)*latRad - \
	(3*eccSquared/8 + 3*eccSquared*eccSquared/32 + \
	45*eccSquared*eccSquared*eccSquared/1024)*sin(2*latRad) + \
	(15*eccSquared*eccSquared/256 + \
	45*eccSquared*eccSquared*eccSquared/1024)*sin(4*latRad) - \
	(35*eccSquared*eccSquared*eccSquared/3072)*sin(6*latRad));
        
UTMEasting = (double)(k0*N*(A+(1-T+C)*A*A*A/6 + \
	(5-18*T+T*T+72*C-58*eccPrimeSquared)*A*A*A*A*A/120) + 500000.0);

UTMNorthing = (double)(k0*(M+N*tan(latRad)*(A*A/2+(5-T+9*C+4*C*C)*A*A*A*A/24 + \
	(61-58*T+T*T+600*C-330*eccPrimeSquared)*A*A*A*A*A*A/720)));

    if (!retarr) {
	return numberof(lat);
    } else {
	return [UTMEasting, UTMNorthing];
    }	
}



func utm2ll( UTMNorthing, UTMEasting, UTMZone) {
/* DOCUMENT  utm2ll( UTMNorthing, UTMEasting, UTMZone)

   Convert UTM coords. to  lat/lon.  Returned values are
   in Lat and Long;
*/

extern Lat, Long;
//       earth
//       radius     ecc
wgs84 = [6378137, 0.00669438];
wgs72 = [6378135, 0.006694318];
eccSquared    = double(wgs84(2));
Earth_radius  = double(wgs84(1));
k0         = double(0.9996);
e1 = double(1-sqrt(1-eccSquared))/(1+sqrt(1-eccSquared))
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

        Lat = Lat * rad2deg;

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
  return u
}

func ddm2deg(coord) {
/* DOCUMENT dms2deg(coord)
	
   Converts coordinates in degree-deciminute format to degrees.

   The following parameter is required:

      coord: A scalar or array of coordinate values to be converted.
         The format should be DDDMMMM.MM where DDD is the value for
         degrees and MMMM.MM is the value for deciminutes. Deciminutes
         must have a width of four (zero-padding if necessary). (The
         number of places after the decimal may vary.)

   Function returns:

      A scalar or array of the converted degree values.
*/
	d = int(coord / 10000.0);
	coord -= d * 10000;
	m = coord / 100.0 / 60.0;
	deg = d + m;
	return deg;
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
*/
	d = int(coord / 10000.0);
	coord -= d * 10000;
	m = int(coord / 100.0);
	s = coord - (m * 100);
	deg = d + m / 60.0 + s / 3600.0;
	return deg;
}
