// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"
#include <math.h>

#ifndef DEG2RAD
#define DEG2RAD 0.017453292519943295
#endif
#ifndef RAD2DEG
#define RAD2DEG 57.295779513082
#endif

void ll2utm(
  double *lat, double *lon,
  double *north, double *east, short *zone,
  long count,
  double a, double e2)
{
  // This code is structured to mirror the code in the Yorick function, so that
  // the two can be kept in sync in case of code changes / bug fixes.

  long i;
  double cmeridian;
  double N, T, C, A, M;

  // Scale factor along central meridian
  double k0 = 0.9996;

  // eccentricity prime squared
  double ep2 = e2/(1-e2);

  // higher powers of eccentricity squared
  double e4 = e2*e2;
  double e6 = e4*e2;

  // constants used in M equation further below
  double M0 = 1 - e2/4 - 3*e4/64 - 5*e6/256;
  double M2 = 3*e2/8 + 3*e4/32 + 45*e6/1024;
  double M4 = 15*e4/256 + 45*e6/1024;
  double M6 = 35*e6/3072;

  for(i = 0; i < count; i++) {
    // Make sure the longitude is between -180. and 179.99999
    lon[i] -= floor(.5+lon[i]/360.)*360.;

    // Calculate zone if needed
    if(!zone[i])
      zone[i] = floor(lon[i]/6. + 31);

    // Convert to radians
    lon[i] *= DEG2RAD;
    lat[i] *= DEG2RAD;

    // Central meridian
    cmeridian = (zone[i] * 6 - 183) * DEG2RAD;

    // PP1395 eq 4-20 p25, p61
    // N is radius of curvature of the ellipsoid in a plane perpendicular to the
    // meridian and also perpendiuclar to a plane tangent to the surface
    N = a/sqrt(1 - e2 * pow(sin(lat[i]), 2));

    // PP1395 eq 8-13 p61
    T = pow(tan(lat[i]), 2);

    // PP1395 eq 8-14 p61
    C = ep2 * pow(cos(lat[i]), 2);

    // PP1395 eq 8-15 p61
    A = cos(lat[i]) * (lon[i] - cmeridian);

    // PP1395 eq 3-21 p17, p61
    // M is the true distance along the central meridian from the equator to
    // this latitude
    M = (
      M0 * lat[i] - M2 * sin(2*lat[i]) +
      M4 * sin(4*lat[i]) - M6 * sin(6*lat[i])
    ) * a;

    // PP1395 eq 8-9 p61
    east[i] = (
      (5-18*T+T*T+72*C-58*ep2) * pow(A,5)/120 + A + (1-T+C) * pow(A,3)/6
    ) * k0 * N + 500000.;

    // PP1395 eq 8-10 p61
    north[i] = (
      ( (-(58+T)*T + 600*C - 330*ep2 + 61
        ) * pow(A,6) / 720 + (5-T+9*C+4*C*C) * pow(A,4)/24 + A*A/2
      ) * N * tan(lat[i]) + M
    ) * k0;
  }
}

void utm2ll(
  double *north, double *east, short *zone,
  double *lon, double *lat,
  long count,
  double a, double e2)
{
  long i;
  double x, y, M, N1, T1, C1, R1, D, lon0, lat1, mu;

  // Scale factor along central meridian
  double k0 = 0.9996;

  // PP1395 eq 8-12 p61, p64
  // eccentricity prime squared
  double ep2 = e2/(1-e2);

  // PP1395 eq 3-24 ??, p63
  double e1 = (1-sqrt(1-e2))/(1+sqrt(1-e2));

  for(i = 0; i < count; i++) {
    x = east[i] - 500000.;
    y = north[i];

    // PP1395 eq 8-20 p63
    // M = M0 + y/k0
    // Apparently M0 is 0 here...
    M = y / k0;

    lon0 = DEG2RAD * ((zone[i] - 1)*6 - 180 + 3);

    // PP1395 eq 7-10 p??, p63
    mu = M/(a*(1-e2/4-3*e2*e2/64 - 5*e2*e2*e2/256));

    // PP1395 eq 3-26 p??, p63
    // "footprint latitude" or latitude at central meridian which has same y
    // coordinate as that of the point (lat,lon).
    lat1 = mu + (3*e1/2-27*e1*e1*e1/32)*sin(2*mu) +
      (21*e1*e1/16-55*e1*e1*e1*e1/32)*sin(4*mu) +
      (151*e1*e1*e1/96)*sin(6*mu);

    // PP1395 eq 8-23 p64
    N1 = a/sqrt(1-e2*pow(sin(lat1), 2));
    // PP1395 eq 8-22 p64
    T1 = pow(tan(lat1), 2);
    // PP1395 eq 8-21 p64
    C1 = ep2*pow(cos(lat1), 2);
    // PP1395 eq 8-24 p64
    R1 = a*(1-e2)/pow(1-e2*pow(sin(lat1), 2), 1.5);
    // PP1395 eq 8-25 p64
    D = x/(N1*k0);

    // PP1395 eq 8-17 p63
    lat[i] = lat1 -
      (N1*tan(lat1)/R1)*(D*D/2-
      (5+3*T1+10*C1-4*C1*C1-9*ep2)*D*D*D*D/24 +
      (61+90*T1+298*C1+45*T1*T1-252*ep2-
      3*C1*C1)*D*D*D*D*D*D/720);

    // PP1395 eq 8-18 p63
    lon[i] = lon0 + (D-(1+2*T1+C1)*D*D*D/6+(5-2*C1+28*T1-
      3*C1*C1+8*ep2+24*T1*T1)
      *D*D*D*D*D/120)/cos(lat1);

    lat[i] *= RAD2DEG;
    lon[i] *= RAD2DEG;
  }
}
