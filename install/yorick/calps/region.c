// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"

// For each point (x,y), determines whether it is in the box defined by xmin,
// xmax, ymin, ymax. Available in Yorick as _yin_box.
// Argument *in is modified.
void in_box(double *x, double *y, double xmin, double xmax, double ymin,
    double ymax, short *in, long count)
{
  long i;
  for(i = 0; i < count; i++) {
    if(x[i] < xmin)
      in[i] = 0;
    else if(x[i] > xmax)
      in[i] = 0;
    else if(y[i] < ymin)
      in[i] = 0;
    else if(y[i] > ymax)
      in[i] = 0;
    else
      in[i] = 1;
  }
}
