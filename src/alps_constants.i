// vim: set ts=2 sts=2 sw=2 ai sr et:

local DEG2RAD, RAD2DEG;
/* DOCUMENT
  DEG2RAD -- constant for converting degrees to radians
  RAD2DEG -- constant for converting radians to degrees
*/
DEG2RAD = pi/180.;
RAD2DEG = 180./pi;

local MPS2KN, KN2MPS;
/* DOCUMENT
  MPS2KN -- constant for converting meters per second to knots
  KN2MPS -- constant for converting knots to meters per second
*/
MPS2KN = 1.943844;
KN2MPS = 0.514444;

local NMI2KM, NMI2MI, MI2KM, KM2NMI, MI2NMI, KM2MI;
/* DOCUMENT
  NMI2KM -- constant for converting nautical miles to kilometers
  NMI2MI -- constant for converting nautical miles to statue miles
  MI2KM -- constant for converting statute miles to kilometers
  KM2NMI -- constant for converting kilometers to nautical miles
  MI2NMI -- constant for converting statute miles to nautical miles
  KM2MI -- constant for converting kilometers to statute miles
*/
NMI2KM = 1.852;
KM2NMI = 1./NMI2KM;
MI2KM = 1.609344;
KM2MI = 1/MI2KM;
NMI2MI = NMI2KM * KM2MI;
MI2NMI = MI2KM * KM2NMI;

local CNS;
/* DOCUMENT CNS
  Speed of light in space, in meters per nanosecond.
*/
CNS      = 0.299792458;

local KAIR, KH2O;
/* DOCUMENT
  KAIR - Refractive index for air (oxygen, as a gas)
  KH2O - Refractive index for water (at approx. 20 degrees C)
*/
KAIR     = 1.000276;
KH2O     = 1.333;

local NS2MAIR, CNSH2O2X, CNSH2O2XF;
/* DOCUMENT
  NS2MAIR - two-way speed of light through air, in m/ns
  CNSH2O2X - two-way speed of light through water, in m/ns
  CNSH2O2XF - two-way speed of light through water, in ft/ns
*/
NS2MAIR = CNS/KAIR*0.5;
CNSH2O2X = CNS/KH2O*0.5;
CNSH2O2XF = CNSH2O2X*3.280839895;

local ELLIPSOID;
/* DOCUMENT ELLIPSOID
  A Yeti hash containing constants that define the ellipsoids implemented in
  ALPS. These are used for various operations involving lat/lon coordinates.

  The keys for ELLIPSOID are ellipsoid names. Currently defined:
    wgs84
    grs80
    wgs72

  Each key corresponds to a hash with constants for that ellipsoid. The
  constants paramaters are:
    a     semi-major axis
    b     semi-minor axis
    f     flattening factor
    e2    eccentricity squared

  For example, to access the semi-major axis for wgs84:
    result = ELLIPSOID("wgs84").a
*/
ELLIPSOID = h_new();
// Defined constants
h_set, ELLIPSOID, wgs84=h_new(a=6378137., b=6356752.3142);
h_set, ELLIPSOID, grs80=h_new(a=6378137., b=6356752.3141);
h_set, ELLIPSOID, wgs72=h_new(a=6378135., b=6356750.520);
// Derived constants
for(key = h_first(ELLIPSOID); key; key = h_next(ELLIPSOID, key)) {
  tmp = ELLIPSOID(key);
  h_set, tmp, f=(tmp.a-tmp.b)/tmp.a;
  h_set, tmp, e2=2*tmp.f - tmp.f*tmp.f;
}
tmp = [];
