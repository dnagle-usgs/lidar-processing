// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <math.h>
#include "yapi.h"

// Calculate the centroid of the given waveform. Returns Inf if unable to
// calculate.
double wf_centroid(long *wf, long count)
{
  long power = 0, i = 0;
  double weighted = 0.;

  for(i = 0; i < count; i++)
  {
    power += wf[i];
    weighted += (wf[i] * (i + 1));
  }

  if(power)
  {
    return weighted / power;
  }

  return INFINITY;
}

// Returns values of wf interpolated at the given position.
// Position is a 1-based index into wf.
double interp_index(long *wf, long count, double position)
{
    if(position < 1)
    {
      return (double)wf[0];
    }
    else if(position >= count)
    {
      return (double)wf[count-1];
    }
    else
    {
      double ratio = position - (long)position;
      return
        wf[(long)position - 1] * (1 - ratio) +
        wf[(long)position] * ratio;
    }
}

#define WF_CENTROID_KEYCT 1
void Y_wf_centroid(int nArgs)
{
  static char *knames[WF_CENTROID_KEYCT+1] = {"lim", 0};
  static long kglobs[WF_CENTROID_KEYCT+1];

  long *wf = NULL;
  double position = INFINITY;
  long glob_pos = -1, glob_int = -1;
  long count = 0;

  int kiargs[WF_CENTROID_KEYCT];
  yarg_kw_init(knames, kglobs, kiargs);

  int iarg_wf = yarg_kw(nArgs-1, kglobs, kiargs);
  if(iarg_wf == -1) y_error("must provide at least 1 argument");

  int iarg_position = yarg_kw(iarg_wf-1, kglobs, kiargs);

  int iarg_intensity = -1;
  if(iarg_position != -1)
  {
    iarg_intensity = yarg_kw(iarg_position-1, kglobs, kiargs);
  }

  if(iarg_intensity != -1)
    if(yarg_kw(iarg_intensity-1, kglobs, kiargs) != -1)
      y_error("must provide no more than 3 arguments");

  if(iarg_position != -1) glob_pos = yget_ref(iarg_position);
  if(iarg_intensity != -1) glob_int = yget_ref(iarg_intensity);

  if(yarg_nil(iarg_wf))
  {
    ypush_double(INFINITY);
    if(glob_pos != -1)
    {
      yput_global(glob_pos, 0);
    }
    if(glob_int != -1)
    {
      yput_global(glob_int, 0);
    }
    return;
  }

  if(yarg_rank(iarg_wf) != 1 || yarg_number(iarg_wf) != 1)
    y_error("wf array must be one dimensional array of integers");

  wf = ygeta_l(iarg_wf, &count, NULL);

  if(kiargs[0] != -1 && !yarg_nil(kiargs[0]))
  {
    if(yarg_number(kiargs[0]) != 1 || yarg_rank(kiargs[0]) != 0)
      y_error("lim= must be a scalar integer");
    long lim = ygets_l(kiargs[0]);
    if(lim < count) count = lim;
  }

  position = wf_centroid(wf, count);

  if(glob_int != -1)
  {
    ypush_double(isfinite(position)
      ? interp_index(wf, count, position) : INFINITY);
    yput_global(glob_int, 0);
  }

  ypush_double(position);
  if(glob_pos != -1)
  {
    yput_global(glob_pos, 0);
  }
}
