// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"
#include <math.h>

void interp_angles(double *x, double *y, long xyn, double *xp, double *yp,
long *xb, long xpypn)
{
  long i, b0, b1, last_b0;
  double ratio, cos0, cos1, cosp, sin0, sin1, sinp;

  for(i = 0; i < xpypn; i++) {
    b1 = xb[i] - 1;
    b0 = b1 - 1;
    last_b0 = -1;

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

      // We only need to use trigonometry if the difference between the two
      // angles is greater than pi. We use a constant slightly smaller than pi,
      // which means we rarely use trig when we don't need to (but it's good
      // enough, no need to over-optimize).
      //
      // Notably, the difference between the two angles will be greater than pi
      // when they are near to but on opposite sides of the "rollover" point:
      // just above zero and just below 2pi.
      if(fabs(y[b0] - y[b1]) > 3.14159) {

        // Simple caching. In practice, we're very likely to encounter series
        // of angles to interpolate within the same pair of adjacent angles. An
        // extra comparison + assignment is cheap, whereas repeated sets of 4
        // trigonometric operations are expensive.
        if(b0 != last_b0) {
          cos0 = cos(y[b0]);
          cos1 = cos(y[b1]);
          sin0 = sin(y[b0]);
          sin1 = sin(y[b1]);
          last_b0 = b0;
        }

        cosp = cos0 + ratio * (cos1 - cos0);
        sinp = sin0 + ratio * (sin1 - sin0);

        yp[i] = atan2(sinp, cosp);
      } else {
        yp[i] = y[b0] + ratio * (y[b1] - y[b0]);
      }
    }
  }
}
