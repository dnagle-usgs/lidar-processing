// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <math.h>
#include "yapi.h"

// From centroid.c
void cent(long *wf, long count, double *result);

// Comments about "stack" are to track how many items we add to the stack.
// Yorick ensures there is room to add at least 8; if at any point we exceed 8,
// then we'd need to use a ypush_check call.

void Y_eaarl_fs_rx_cent_eaarlb(int nArgs)
{
  if(nArgs != 1) y_error("must provide exactly one argument, pulses");

  long tmp = 0;
  yo_ops_t *ops;
  void *obj = NULL;

  // Retrieve values needed from ops_conf
  double range_bias[3];
  {
    long idx = yfind_global("ops_conf", 0);
    if(idx == -1) y_error("ops_conf not defined");
    // stack + 1 = +1
    ypush_global(idx);
    obj = yo_get(0, &ops);
    if(!obj) y_error("ops_conf not defined properly");

    // stack + 1 = +2
    if(ops->get_q(obj, "chn1_range_bias", -1))
      y_error("ops_conf.chn1_range_bias not defined");
    range_bias[0] = ygets_d(0);

    // stack + 1 = +3
    if(ops->get_q(obj, "chn2_range_bias", -1))
      y_error("ops_conf.chn2_range_bias not defined");
    range_bias[1] = ygets_d(0);

    // stack + 1 = +4
    if(ops->get_q(obj, "chn3_range_bias", -1))
      y_error("ops_conf.chn3_range_bias not defined");
    range_bias[2] = ygets_d(0);

    // Channel 2 is used for channel 4, so we do not need chn4_range_bias.

    // stack - 4 = +0
    yarg_drop(4);
  }

  // Retrieve pulses
  obj = yo_get(0, &ops);
  if(!obj) y_error("pulses not defined properly");

  // Retrieve fields needed from pulses: channel, rx
  // stack + 1 = +1
  if(ops->get_q(obj, "channel", -1))
    y_error("pulses.channel not defined");
  long npulses;
  long *channel = ygeta_l(0, &npulses, NULL);
  // stack + 1 = +2
  if(ops->get_q(obj, "rx", -1))
    y_error("pulses.rx not defined");
  ypointer_t (*rx)[4] = (ypointer_t (*)[4])ygeta_p(0, &tmp, NULL);
  if(tmp != npulses * 4)
    y_error("pulses.rx and pulses.channel do not have same size");

  // Output fields
  long dims[Y_DIMSIZE];
  dims[0] = 1;
  dims[1] = npulses;
  // stack + 1 = +3
  float *frx = ypush_f(dims);
  ops->set_q(obj, "frx", -1, 0);
  // stack + 1 = +4
  float *fint = ypush_f(dims);
  ops->set_q(obj, "fint", -1, 0);
  // stack + 1 = +5
  double *fbias = ypush_d(dims);
  ops->set_q(obj, "fbias", -1, 0);
  // stack + 1 = +6
  long *fchannel = ypush_l(dims);
  ops->set_q(obj, "fchannel", -1, 0);

  long i, j, samples;
  for(i = 0; i < npulses; i++)
  {
    fchannel[i] = channel[i] == 4 ? 2 : channel[i];
    fbias[i] = range_bias[fchannel[i]-1];

    // Get rx waveform
    // stack + 1 = +7
    int typeid = ypush_ptr(rx[i][fchannel[i]-1], &samples);
    if(yarg_nil(0) || (typeid == Y_CHAR && samples < 2))
    {
      frx[i] = 10000.;
      // stack - 1 = +6
      yarg_drop(1);
      continue;
    }
    if(typeid != Y_CHAR)
      y_error("rx encountered that was not an array of char");
    if(samples > 12) samples = 12;
    dims[2] = samples;
    unsigned char *raw = ygeta_uc(0, NULL, dims);

    // Convert into clean wf for cent, get saturated count
    // stack + 1 = +8
    long *wf = ypush_l(dims);
    long bias = (long)(~raw[0]);
    long nsat = raw[0] <= 1;
    wf[0] = 0;
    for(j = 1; j < samples; j++)
    {
      wf[j] = (long)(~raw[j]) - bias;
      if(raw[j] <= 1) nsat++;
    }

    double rx_cent[3];
    cent(wf, samples, rx_cent);

    // stack - 2 = +6
    yarg_drop(2);

    frx[i] = rx_cent[0];
    fint[i] = rx_cent[2] + nsat * 20;
  }

  // Don't return anything
  // stack + 1 = +7
  ypush_nil();
}
