// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_eaarl_decode_fast(fn, start, stop, rnstart=, raw=, wfs=) {
/* DOCUMENT result = eaarl_decode_fast(fn, start, stop)
  Decodes the data in the specified TLD file from offset START through offset
  STOP. START and STOP must each be scalar integers.

  This performs a faster decode than alternative functions because it pulls
  only the data typically needed during processing.

  Parameters:
    fn: Should be a full path to a TLD file.
    start: The byte addres (1-based) where the first raster to decode starts.
    stop: The byte address (1-based) where the last raster to decode ends. This
      may also be 0, which means to decode to the end of the file.

  Options:
    rnstart= Starting raster number. If provided, then the raster field will be
      added, treating the raster found at START as raster RNSTART and numbering
      the ones that follow sequentially. This is required when
      eaarl_time_offset is an array.
    raw= Specifies whether raw data is desired.
      raw=0   Default; soe will be updated using eaarl_time_offset
      raw=1   All data returned as it was in the file
    wfs= By default, waveforms are included. Use wfs=0 to disable, which will
      omit the rx and tx fields.

  Returns:
    An oxy group object containing the following array members:
      digitizer - int8_t
      dropout - int8_t
      pulse - int8_t
      irange - int16_t
      scan_angle - int16_t
      raster - int32_t (if rnstart!=0)
      soe - double
      tx - pointer (if wfs=1)
      rx - pointer x 4 (if wfs=1)
    All arrays have the same size and dimensions, except for RX which has an
    extra dimension of size 4.
*/
  extern eaarl_time_offset;
  default, wfs, 1;
  default, raw, 0;

  if(!rnstart && !is_scalar(eaarl_time_offset)) {
    error, "if eaarl_time_offset is array, must provide rnstart";
  }

  f = open(fn, "rb");
  add_variable, f, -1, "raw", char, sizeof(f);

  if(!stop) stop = sizeof(f);

  // scan to see how many rasters there are
  count = 0;
  offset = start;
  while(offset <= stop) {
    rlen = u_cast(fi24(f, offset), long);
    if(rlen >= 18 && f.raw(offset+3) == 5) {
      count += (fi16(f, offset+16) & 0x7fff);
    } else if(rlen <= 0) {
      break;
    }
    offset += rlen;
  }

  // Edge case: no rasters contain valid data
  if(!count) return [];

  digitizer = dropout = pulse = array(int8_t, count);
  irange = scan_angle = array(int16_t, count);
  soe = array(double, count);
  if(rnstart) {
    raster = array(int32_t, count);
  }
  if(wfs) {
    tx = array(pointer, count);
    rx = array(pointer, 4, count);
  }

  // pulse index into results
  pidx = 0;

  // rn, if we're using it (if rnstart=[], then it's not used)
  rn = rnstart;

  offset = start;
  while(offset <= stop) {
    rstart = offset;

    rlen = u_cast(fi24(f, offset), long);
    rstop = rstart + rlen - 1;
    if(rlen < 18 || f.raw(offset+3) != 5) {
      offset = rstop - 1;
      continue;
    }

    seconds = fi32(f, offset+4);
    fseconds = fi32(f, offset+8);

    tmp = fi16(f, offset+16);
    npulse = tmp & 0x7fff;
    dig = (tmp >> 15) & 0x1;

    offset += 18;
    for(i = 1; i <= npulse; i++) {
      if(offset + 15 > rstart + rlen - 1)
        break;
      pstart = offset;
      pstop = pstart + 15 + fi16(f, pstart + 13) - 1;
      pidx++;

      if(rn) raster(pidx) = rn;
      pulse(pidx) = i;
      digitizer(pidx) = dig;

      offset_time=fi24(f, offset);
      soe(pidx) = seconds + (fseconds + offset_time) * 1.6e-6 +
        (raw ? 0 : (
          (is_scalar(eaarl_time_offset) ? eaarl_time_offset : eaarl_time_offset(rn))
        ));

      scan_angle(pidx) = fi16(f, offset+9);

      tmp = fi16(f, offset+11);
      irange(pidx) = (tmp & 0x3fff);
      dropout(pidx) = ((tmp >> 14) & 0x3);
      tmp = [];

      if(!wfs) {
        offset = pstart + 15 + fi16(f, pstart + 13);
        continue;
      }

      // tx rx(4)
      offset += 15;

      transmit_length = f.raw(offset);
      if(transmit_length <= 0) continue;
      tx(pidx) = &f.raw(offset+1:offset+transmit_length);

      // See mission_constants for explanation of this code
      if(has_member(ops_conf, "tx_clean") && ops_conf.tx_clean) {
        tmptx = *tx(pidx);
        if(numberof(tmptx) >= ops_conf.tx_clean) {
          tmptx(ops_conf.tx_clean:) = tmptx(1);
        }
        tx(pidx) = &tmptx;
      }

      offset += 1 + transmit_length;

      for(j = 1; j <= 4; j++) {
        chan_len = fi16(f, offset);
        wfend = offset+1+chan_len;
        if(chan_len <= 0 || wfend > pstop || wfend > rstop) break;
        rx(j,pidx) = &f.raw(offset+2:wfend);
        offset += 2 + chan_len;
      }

      offset = pstop + 1;
    }

    if(rn) rn++;
    offset = rstop + 1;
  }

  close, f;

  result = save(digitizer, dropout, pulse, irange, scan_angle, soe);
  if(rnstart) save, result, raster;
  if(wfs) save, result, tx, rx;
  return result;
}

if(is_func(eaarl_decode_fast) != 2) eaarl_decode_fast = nocalps_eaarl_decode_fast;
