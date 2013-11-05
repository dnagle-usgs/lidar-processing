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

// result must be pointer to array with size for 3 doubles
void cent(long *wf, long count, double *result)
{
  if(count < 2) {
    result[0] = result[1] = result[2] = 0;
    return;
  }

  #define centroid result[0]
  #define max_index result[1]
  #define max_intensity result[2]

  long i;
  max_index = 1;
  max_intensity = wf[0];
  for(i = 1; i < count; i++)
  {
    if(wf[i] > max_intensity)
    {
      max_index = i+1;
      max_intensity = wf[i];
    }
  }

  centroid = wf_centroid(wf, count);
  if(centroid > 10000) centroid = 10000;

  #undef centroid
  #undef max_index
  #undef max_intensity
}

long *retrieve_wf(int iarg, long *count)
{
  if(yarg_rank(iarg) != 1) y_error("waveform must be one dimensional");
  long *wf = NULL;

  if(yarg_typeid(iarg) == Y_CHAR)
  {
    long i = 0, dims[Y_DIMSIZE];
    unsigned char *tmp = ygeta_uc(iarg, count, dims);
    wf = ypush_l(dims);
    yarg_swap(0, iarg+1);
    yarg_drop(1);

    long bias = (long)(~tmp[0]);
    wf[0] = 0;
    for(i = 1; i < *count; i++)
    {
      wf[i] = (long)(~tmp[i]) - bias;
    }
  }
  else
  {
    wf = ygeta_l(iarg, count, NULL);
  }

  return wf;
}

#define CENT_KEYCT 1
void Y_cent(int nArgs)
{
  static char *knames[CENT_KEYCT+1] = {"lim", 0};
  static long kglobs[CENT_KEYCT+1];
  int kiargs[CENT_KEYCT];
  yarg_kw_init(knames, kglobs, kiargs);

  int iarg_wf = yarg_kw(nArgs-1, kglobs, kiargs);
  if(iarg_wf == -1 || yarg_kw(iarg_wf-1, kglobs, kiargs) != -1)
    y_error("must provide 1 argument");

  long dims[Y_DIMSIZE];
  dims[0] = 1;
  dims[1] = 3;

  if(yarg_nil(iarg_wf))
  {
    // Yorick initializes it to 0's
    ypush_d(dims);
    return;
  }

  long count = 0;
  long *wf = retrieve_wf(iarg_wf, &count);

  if(kiargs[0] == -1 || yarg_nil(kiargs[0]))
  {
    if(12 < count) count = 12;
  }
  else if(yarg_number(kiargs[0]) != 1 || yarg_rank(kiargs[0]) != 0)
  {
    y_error("lim= must be a scalar integer");
  }
  else
  {
    long lim = ygets_l(kiargs[0]);
    if(lim < count) count = lim;
  }

  double *result = ypush_d(dims);
  cent(wf, count, result);
}
