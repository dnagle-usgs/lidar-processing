// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <string.h>
#include "yapi.h"
#include "filebuffer.h"

#define i32(F, OFFSET) filebuffer_i32((F), (OFFSET))
#define i24(F, OFFSET) filebuffer_i24((F), (OFFSET))
#define i16(F, OFFSET) filebuffer_i16((F), (OFFSET))
#define i8(F, OFFSET) filebuffer_i8((F), (OFFSET))

#define EAARL_DECODE_FAST_KEYCT 3
void Y_eaarl_decode_fast(int nArgs)
{
  static char *knames[EAARL_DECODE_FAST_KEYCT+1] = {"rnstart", "raw", "wfs", 0};
  static long kglobs[EAARL_DECODE_FAST_KEYCT+1];

  char *fn = NULL;
  long start = 0, stop = 0, rnstart = 0, raw = 0, wfs = 0;

  long tx_clean = 0;
  double eaarl_time_offset = 0.;

  filebuffer_t *f = NULL;
  long count = 0, offset = 0, pidx = -1, rn = 0, rstart = 0, rstop = 0;
  unsigned long rlen = 0, wflen = 0, tmp = 0;
  long seconds = 0, fseconds = 0, npulse = 0, dig = 0;
  long i = 0, j = 0, k = 0;
  long pstart = 0, pstop = 0;
  long dims[Y_DIMSIZE];
  long *pulse_offsets = NULL;
  char *wf = NULL;

  char *digitizer = NULL, *dropout = NULL, *pulse = NULL;
  short *irange = NULL, *scan_angle = NULL;
  double *soe = NULL;
  int *raster = NULL;
  ypointer_t *tx = NULL;
  ypointer_t (*rx)[4] = NULL;

  yo_ops_t *ops;
  void *obj;

  // Retrieve the provided arguments and options
  {
    int kiargs[EAARL_DECODE_FAST_KEYCT];
    yarg_kw_init(knames, kglobs, kiargs);

    int iarg_fn = yarg_kw(nArgs-1, kglobs, kiargs);
    if(iarg_fn == -1) y_error("must provide 3 arguments");

    int iarg_start = yarg_kw(iarg_fn-1, kglobs, kiargs);
    if(iarg_start == -1) y_error("must provide 3 arguments");

    int iarg_stop = yarg_kw(iarg_start-1, kglobs, kiargs);
    if(iarg_stop == -1) y_error("must provide 3 arguments");

    if(yarg_kw(iarg_stop-1, kglobs, kiargs) != -1)
      y_error("must provide 3 arguments");

    if(!yarg_string(iarg_fn))
      y_error("first argument must be string");
    if(yarg_number(iarg_start) != 1 || yarg_rank(iarg_start) != 0)
      y_error("second argument must be scalar integer");
    if(yarg_number(iarg_stop) != 1 || yarg_rank(iarg_stop) != 0)
      y_error("third argument must be scalar integer");

    if(kiargs[0] != -1)
    {
      if(yarg_number(kiargs[0]) != 1 || yarg_rank(kiargs[0]) != 0)
        y_error("rnstart= must be scalar integer");
      rnstart = ygets_l(kiargs[0]);
    }

    if(kiargs[1] != -1) raw = yarg_true(kiargs[1]);
    if(kiargs[2] != -1) wfs = yarg_true(kiargs[2]);

    fn = ygets_q(iarg_fn);
    start = ygets_l(iarg_start);
    stop = ygets_l(iarg_stop);

    yarg_drop(nArgs);
  }

  ypush_check(3);

  // Retrieve extern values: ops_conf.tx_clean and eaarl_time_offset
  {
    long idx = yfind_global("ops_conf", 0);
    if(idx != -1)
    {
      ypush_global(idx);
      obj = yo_get(0, &ops);
      if(!obj)
        y_error("ops_conf not defined properly");
      if(!ops->get_q(obj, "tx_clean", -1))
      {
        tx_clean = ygets_l(0);
      }
      yarg_drop(2);
    }

    idx = yfind_global("eaarl_time_offset", 0);
    if(idx != -1)
    {
      ypush_global(idx);
      eaarl_time_offset = ygets_d(0);
      yarg_drop(1);
    }
  }

  f = filebuffer_open(fn);

  // stop=0 is special for indicating to use the rest of the file
  if(stop == 0)
  {
    stop = filebuffer_size(f) - 1;
  }

  // Scan to see how many pulses there are
  offset = start - 1;
  while(offset < stop)
  {
    rlen = (unsigned long) i24(f, offset);
    if(rlen >= 18 || i8(f, offset+3) == 5)
      count += (i16(f, offset+16) & 0x7fff);
    else if(!rlen)
      break;
    offset += rlen;
  }

  // Initialize output arrays and group

  obj = yo_new_group(&ops);

  dims[0] = 1;
  dims[1] = count;

  #define obj_create_and_add(VAR, FNC) \
    VAR = FNC(dims); ops->set_q(obj, #VAR, -1, 0); yarg_drop(1)

  obj_create_and_add(digitizer, ypush_c);
  obj_create_and_add(dropout, ypush_c);
  obj_create_and_add(pulse, ypush_c);
  obj_create_and_add(irange, ypush_s);
  obj_create_and_add(scan_angle, ypush_s);
  obj_create_and_add(soe, ypush_d);

  if(rnstart)
  {
    obj_create_and_add(raster, ypush_i);
  }

  if(wfs)
  {
    obj_create_and_add(tx, ypush_p);

    dims[0] = 2;
    dims[1] = 4;
    dims[2] = count;
    rx = (ypointer_t (*)[4])ypush_p(dims);
    ops->set_q(obj, "rx", -1, 0);
    yarg_drop(1);
  }

  #undef obj_create_and_add

  // Actually retrieve data now
  rn = rnstart;
  offset = start - 1;
  while(offset < stop)
  {
    rstart = offset;

    rlen = (unsigned long) i24(f, offset);
    if(rlen < 18 || i8(f, offset+3) != 5) continue;
    rstop = rstart + rlen - 1;

    seconds = i32(f, offset+4);
    fseconds = i32(f, offset+8);

    tmp = i16(f, offset+16);
    npulse = tmp & 0x7fff;
    dig = (tmp >> 15) & 0x1;

    offset += 18;
    for(i = 1; i <= npulse; i++)
    {
      if(offset + 15 > rstart + rlen - 1)
        break;
      pstart = offset;
      pidx++;

      if(rn) raster[pidx] = rn;
      pulse[pidx] = i;
      digitizer[pidx] = dig;

      soe[pidx] = seconds + (fseconds + i24(f, offset)) * 1.6e-6 +
          eaarl_time_offset;

      scan_angle[pidx] = i16(f, offset+9);

      tmp = i16(f, offset+11);
      irange[pidx] = (tmp & 0x3fff);
      dropout[pidx] = ((tmp >> 14) & 0x3);
      
      pstop = pstart + 15 + i16(f, offset+13) - 1;

      if(!wfs)
      {
        offset = pstop + 1;
        continue;
      }

      offset += 15;

      wflen = i8(f, offset);
      if(!wflen) continue;

      wf = filebuffer_read(f, offset+1, wflen);
      yget_use(0);
      tx[pidx] = wf;
      yarg_drop(1);

      if(tx_clean)
      {
        for(j = tx_clean-1; j < wflen; j++)
        {
          wf[j] = wf[0];
        }
      }

      offset += 1 + wflen;

      for(j = 0; j < 4; j++)
      {
        wflen = i16(f, offset);
        tmp = offset + 1 + wflen;
        if(!wflen || tmp > pstop || tmp > rstop) break;
        wf = filebuffer_read(f, offset+2, wflen);
        yget_use(0);
        rx[pidx][j] = wf;
        yarg_drop(1);
        offset += 2 + wflen;
      }

      offset = pstop + 1;
    }

    if(rn) rn++;
    offset = rstop + 1;
  }
}

#undef i32
#undef i24
#undef i16
#undef i8
