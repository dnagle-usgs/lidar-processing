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

   Converted to Yorick by C. W. Wright wright@osb-wff.nasa.gov
   6/21/1999

*/

write, "ll2utm as of 11/18/2001"

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

func ll2utm( lat, lon ) {
/* DOCUMENT  ll2utm(lat, lon)

   Convert lat/lon pairs to UTM.  Returns values in
   UTMNorth, UTMEasting, and UTMZone;

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

return numberof(lat);
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
}


