// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"
#include <math.h>

void interp_angles(double *x, double *y, long xyn, double *xp, double *yp,
long *xb, long xpypn)
{
  long i, b0, b1;
  double ratio, cos0, cos1, cosp, sin0, sin1, sinp;

  for(i = 0; i < xpypn; i++) {
    b1 = xb[i] - 1;
    b0 = b1 - 1;

    if(b0 < 0) {
      yp[i] = y[0];
    } else if(b1 >= xyn) {
      yp[i] = y[xyn-1];
    } else if(xp[i] == x[b0]) {
      yp[i] = y[b0];
    } else if(xp[i] == x[b1]) {
      yp[i] = y[b1];
    } else {
      ratio = (xp[i] - x[b0]) / (x[b1] - x[b0]);

      cos0 = cos(y[b0]);
      cos1 = cos(y[b1]);
      cosp = cos0 + ratio * (cos1 - cos0);

      sin0 = sin(y[b0]);
      sin1 = sin(y[b1]);
      sinp = sin0 + ratio * (sin1 - sin0);

      yp[i] = atan2(sinp, cosp);
    }
  }
}
