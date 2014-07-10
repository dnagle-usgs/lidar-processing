// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include "plugin.h"
#include "yapi.h"
#include "gist.h"

void Y_gist_gpbox(int nArgs)
{
  if(nArgs == 1)
  {
    GpBox viewport = yarg_true(0) ? gLandscape : gPortrait;

    long dims[Y_DIMSIZE];
    dims[0] = 1;
    dims[1] = 4;

    double *result = ypush_d(dims);
    result[0] = viewport.xmin;
    result[1] = viewport.xmax;
    result[2] = viewport.ymin;
    result[3] = viewport.ymax;

    return;
  }

  if(nArgs != 2) y_error("too many parameters in function call");

  double xmax = ygets_d(1);
  double ymax = ygets_d(0);

  // Make sure xmax < ymax so that the dimensions are for portrait mode
  if(xmax > ymax)
  {
    double tmp = xmax;
    xmax = ymax;
    ymax = tmp;
  }

  gPortrait.xmin = 0;
  gPortrait.xmax = xmax;
  gPortrait.ymin = 0;
  gPortrait.ymax = ymax;

  // Landscape matches portrait, but rotated
  gLandscape.xmin = 0;
  gLandscape.xmax = ymax;
  gLandscape.ymin = 0;
  gLandscape.ymax = xmax;


  ypush_nil();
}
