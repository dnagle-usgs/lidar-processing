// vim: set ts=2 sts=2 sw=2 ai sr et:

/*
  Structure of a TLD file

  RASTER
  ----------------------------------
  Pos Len Type
  1   18  RASTER_HEADER
  19  ?   PULSE[?] where ? is number of pulses specified

  RASTER_HEADER
  ----------------------------------
  Pos Len Type    Description
  1   3   ui24    Raster length in bytes
  4   1   ui8     Raster type ID (always 5)
  5   4   ui32    Seconds since 1970
  9   4   ui32    Fractional seconds 1.6us lsb
  13  4   ui32    Raster number
  17  2   ui16    Bitfield:
                  15 bits: number of pulses in this raster (& 0x7fff)
                  1 bit: digitizer (>>15 &0x1)

  PULSE
  ----------------------------------
  1   15  PULSE_HEADER
  16  ?   TX_WF - Transmit
  ?   ?   RX_WF - Channel 1
  ?   ?   RX_WF - Channel 2
  ?   ?   RX_WF - Channel 3

  PULSE_HEADER
  ----------------------------------
  Pos Len Type    Description
  1   3   ui24    Offset time lbs=200e-9
  4   1   ui8     Number of waveforms in this sample
  5   1   ui8     Transmit bias
  6   4   ui8[4]  Return biases
  10  2   i16     Scan angle counts
  12  2   ui16    Bitfield:
                  14 bits: integer range (& 16383)
                  1 bit: flag (& 16384)
                  1 bit: flag (& 32768)
  14  2   ui16    Data length

  TX_WF
  ----------------------------------
  1   1   ui8     Length of waveform
  2   ?   ui8[?]  Array of char data with length given

  RX_WF
  ----------------------------------
  1   2   ui16    Length of waveform
  3   ?   ui8[?]  Array of char data with length given
*/

func eaarla_decode_header(raw, offset) {
/* DOCUMENT eaarla_decode_header(raw, offset)
  Given the raw data for a raster, this will decode and return its header
  information as an oxy group object with these fields:

    raster_length = array(long)
    raster_type = array(char)
    seconds = array(long)
    fseconds = array(long)
    raster_number = array(long)
    number_of_pulses = array(long)
    digitizer = array(long)
    pulse_offsets = array(long,119)

  The dimension of pulse_offsets will match number_of_pulses and is usually
  119. OFFSET should be the offset into the RAW data where the raster starts;
  it defaults to 1, which is appropriate when passed individual raster
  segments.
*/
  extern eaarl_time_offset, tca;
  local rasternbr, type, len;
  default, offset, 1;
  start = offset;

  result = save();
  save, result, raster_length=i24(raw, offset);
  save, result, raster_type=raw(offset+3);

  if(result.raster_type != 5)
    return result;

  if(result.raster_length >= 8)
    save, result, seconds=i32(raw, offset+4);
  if(result.raster_length >= 12)
    save, result, fseconds=i32(raw, offset+8);
  if(result.raster_length >= 16)
    save, result, raster_number=i32(raw, offset+12);

  if(result.raster_length >= 18) {
    save, result, number_of_pulses=i16(raw, offset+16) & 0x7fff,
        digitizer=(i16(raw,offset+16) >> 15) & 0x1;

    offset += 18;
    pulse_offsets = array(-1, result.number_of_pulses);
    for(i = 1; i <= result.number_of_pulses; i++) {
      if(offset + 15 > start + result.raster_length - 1)
        break;
      pulse_offsets(i) = offset;
      offset += 15 + i16(raw, offset + 13);
    }
    save, result, pulse_offsets;
  }

  return result;
}

func eaarla_header_valid(header) {
/* DOCUMENT eaarla_header_valid(header)
  Returns 1 if the given header is valid, 0 if not. HEADER must be the result
  of eaarla_decode_header.
*/
  if(header.raster_length < 20)
    return 0;
  if(header.raster_type != 5)
    return 0;
  if(header.seconds < 0)
    return 0;
  if(header.fseconds < 0)
    return 0;
  if(header.raster_number < 0)
    return 0;
  if(header.number_of_pulses > 120)
    return 0;
  if(header.number_of_pulses < 0)
    return 0;
  return 1;
}

func eaarla_decode_pulse(raw, pulse, offset, header=, wfs=) {
/* DOCUMENT eaarla_decode_pulse(raw, pulse, offset, header=)
  Given the raw data for a raster, this will decode and return the pulse
  information for the specified pulse number.

  Parameters:
    raw: An array of char data from a TLD file (as returned by get_erast).
    pulse: Pulse number to retrieve, usually in the range 1-119.
    offset: Offset into RAW where raster starts. Defaults to 1, which is
      appropriate when passed individual raster data chunks.
  Options:
    header= The result of eaarla_decode_header. If not supplied, it was be
      determined from RAW. Providing the header is more efficient if you
      already have it or will be retrieving multiple pulses from one raster.
    wfs= By default the waveforms aren't included. Set to wfs=1 to include
      them.

  The decoded information will be returned as an oxy group object with these
  fields:

    offset_time = array(long)
    number_of_waveforms = array(char)
    transmit_bias = array(char)
    return_bias = array(char,4)
    shaft_angle = array(short)
    integer_range = array(short)
    raw_irange = array(short)
    flag_irange_bit14 = array(char)
    flag_irange_bit15 = array(char)
    data_length = array(short)
    transmit_length = array(char)
    transmit_offset = array(long,x)
    channel1_length = array(short)
    channel1_offset = array(long,x)
    channel2_length = array(short)
    channel2_offset = array(long,x)
    channel3_length = array(short)
    channel3_offset = array(long,x)
    channel4_length = array(short)
    channel4_offset = array(long,x)

  And if wfs=1:

    transmit_wf = array(char,x)
    channel1_wf = array(char,x)
    channel2_wf = array(char,x)
    channel3_wf = array(char,x)
    channel4_wf = array(char,x)

  The various *_wf fields will be vectors of varying lengths (as defined by
  the corresponding *_length fields).
*/
  default, offset, 1;
  if(is_void(header)) header = eaarla_decode_header(raw, offset);
  result = save();
  if(!eaarla_header_valid(header))
    return result;

  offset = header.pulse_offsets(pulse);
  save, result, offset_time=i24(raw, offset);
  save, result, number_of_waveforms=raw(offset+3);
  if(result.number_of_waveforms != 4)
    write, format="WARNING: number_of_waveforms = %d\n",
      result.number_of_waveforms;
  save, result, transmit_bias=raw(offset+4);
  save, result, return_bias=raw(offset+5:offset+8);
  save, result, shaft_angle=i16(raw, offset+9);
  tmp = i16(raw, offset+11);
  save, result, integer_range=(tmp & 16383);
  save, result, raw_irange=tmp;
  save, result, flag_irange_bit14=char((tmp & 16384) != 0);
  save, result, flag_irange_bit15=char((tmp & 32768) != 0);
  tmp = [];
  save, result, data_length=i16(raw, offset+13);

  offset += 15;
  save, result, transmit_offset=offset+1;
  save, result, transmit_length=raw(offset);
  if(result.transmit_length <= 0)
    return result;
  if(wfs) {
    save, result, transmit_wf=raw(offset+1:offset+result.transmit_length);

    // See mission_constants for explanation of this code
    if(has_member(ops_conf, "tx_clean") && ops_conf.tx_clean) {
      tx = result.transmit_wf;
      if(numberof(tx) >= ops_conf.tx_clean) {
        tx(ops_conf.tx_clean:) = tx(1);
      }
      save, result, transmit_wf=tx;
    }
  }

  offset += 1 + result.transmit_length;
  save, result, channel1_offset=offset+2;
  save, result, channel1_length=i16(raw, offset);
  if(result.channel1_length <= 0)
    return result;
  if(wfs)
    save, result, channel1_wf=raw(offset+2:offset+1+result.channel1_length);

  offset += 2 + result.channel1_length;
  save, result, channel2_offset=offset+2;
  save, result, channel2_length=i16(raw, offset);
  if(result.channel2_length <= 0)
    return result;
  if(wfs)
    save, result, channel2_wf=raw(offset+2:offset+1+result.channel2_length);

  offset += 2 + result.channel2_length;
  save, result, channel3_offset=offset+2;
  save, result, channel3_length=i16(raw, offset);
  if(result.channel3_length <= 0)
    return result;
  if(wfs)
    save, result, channel3_wf=raw(offset+2:offset+1+result.channel3_length);

  offset += 2 + result.channel3_length;
  if(offset >= numberof(raw))
    return result;
  save, result, channel4_offset=offset+2;
  save, result, channel4_length=i16(raw, offset);
  if(result.channel4_length <= 0 || offset+1+result.channel4_length > numberof(raw))
    return result;
  if(wfs)
    save, result, channel4_wf=raw(offset+2:offset+1+result.channel4_length);

  return result;
}

func eaarla_decode_rasters(raw, wfs=) {
/* DOCUMENT data = eaarla_decode_rasters(raw)
  RAW may be an array of char for a single raster, or it may be an array of
  pointers to such data. The raster data will be decoded and returned as an
  oxy group object with the following fields:

    valid = array(char,COUNT)
    raster_length = array(long,COUNT)
    raster_type = array(short,COUNT)
    seconds = array(long,COUNT)
    fseconds = array(long,COUNT)
    raster_number = array(long,COUNT)
    number_of_pulses = array(short,COUNT)
    digitizer = array(short,COUNT)
    offset_time = array(long,COUNT,NUM_PULSES)
    number_of_waveforms = array(char,COUNT,NUM_PULSES)
    shaft_angle = array(short,COUNT,NUM_PULSES)
    integer_range = array(short,COUNT,NUM_PULSES)
    raw_irange = array(short,COUNT,NUM_PULSES)
    flag_irange_bit14 = array(short,COUNT,NUM_PULSES)
    flag_irange_bit15 = array(short,COUNT,NUM_PULSES)
    data_length = array(short,COUNT,NUM_PULSES)
    transmit_bias = array(char,COUNT,NUM_PULSES)
    transmit_offset = array(long,COUNT,NUM_PULSES)
    transmit_length = array(char,COUNT,NUM_PULSES)
    channel1_bias = array(char,COUNT,NUM_PULSES)
    channel1_offset = array(long,COUNT,NUM_PULSES)
    channel1_length = array(short,COUNT,NUM_PULSES)
    channel2_bias = array(char,COUNT,NUM_PULSES)
    channel2_offset = array(long,COUNT,NUM_PULSES)
    channel2_length = array(short,COUNT,NUM_PULSES)
    channel3_bias = array(char,COUNT,NUM_PULSES)
    channel3_offset = array(long,COUNT,NUM_PULSES)
    channel3_length = array(short,COUNT,NUM_PULSES)
    channel4_bias = array(char,COUNT,NUM_PULSES)
    channel4_offset = array(long,COUNT,NUM_PULSES)
    channel4_length = array(short,COUNT,NUM_PULSES)

  Where COUNT is the number of rasters provided and NUM_PULSES is the maximum
  number of pulses found for any given raster.

  If wfs=1, then the additional fields are also included:

    transmit_wf = array(pointer,COUNT,NUM_PULSES)
    channel1_wf = array(pointer,COUNT,NUM_PULSES)
    channel2_wf = array(pointer,COUNT,NUM_PULSES)
    channel3_wf = array(pointer,COUNT,NUM_PULSES)
    channel4_wf = array(pointer,COUNT,NUM_PULSES)
*/
  default, wfs, 0;

  count = 0;
  offset = 1;
  nraw = numberof(raw);
  while(offset < nraw) {
    count++;
    offset += u_cast(i24(raw, offset), long);
  }

  // header fields
  valid = array(char, count);
  raster_length = seconds = fseconds = raster_number = array(long, count);
  raster_type = number_of_pulses = digitizer = array(short, count);

  // pulse fields -- never more than 120 pulses
  offset_time = array(long, count, 120);
  number_of_waveforms = transmit_bias = flag_irange_bit14 = flag_irange_bit15 =
      transmit_length = channel1_bias = channel2_bias = channel3_bias =
      channel4_bias = array(char, count, 120);
  shaft_angle = integer_range = raw_irange = data_length = channel1_length =
      channel2_length = channel3_length = channel4_length =
      array(short, count, 120);
  transmit_offset = channel1_offset = channel2_offset = channel3_offset =
      channel4_offset = array(long, count, 120);
  if(wfs) {
    transmit_wf = channel1_wf = channel2_wf = channel3_wf = channel4_wf =
        array(pointer, count, 120);
  }

  offset = 1;
  i = 0;
  while(offset < nraw) {
    i++;
    header = eaarla_decode_header(raw, offset);
    valid(i) = eaarla_header_valid(header);
    raster_length(i) = header.raster_length;
    if(!valid(i)) {
      offset += raster_length(i);
      continue;
    }
    raster_type(i) = header.raster_type;
    seconds(i) = header.seconds;
    fseconds(i) = header.fseconds;
    raster_number(i) = header.raster_number;
    number_of_pulses(i) = header.number_of_pulses;
    digitizer(i) = header.digitizer;

    for(j = 1; j <= number_of_pulses(i); j++) {
      pulse = eaarla_decode_pulse(raw, j, offset, header=header, wfs=wfs);
      offset_time(i,j) = pulse.offset_time;
      number_of_waveforms(i,j) = pulse.number_of_waveforms;
      transmit_bias(i,j) = pulse.transmit_bias;
      channel1_bias(i,j) = pulse.return_bias(1);
      channel2_bias(i,j) = pulse.return_bias(2);
      channel3_bias(i,j) = pulse.return_bias(3);
      channel4_bias(i,j) = pulse.return_bias(4);
      shaft_angle(i,j) = pulse.shaft_angle;
      integer_range(i,j) = pulse.integer_range;
      raw_irange(i,j) = pulse.raw_irange;
      flag_irange_bit14(i,j) = pulse.flag_irange_bit14;
      flag_irange_bit15(i,j) = pulse.flag_irange_bit15;
      data_length(i,j) = pulse.data_length;
      transmit_length(i,j) = pulse.transmit_length;
      transmit_offset(i,j) = pulse.transmit_offset;
      if(wfs)
        transmit_wf(i,j) = &pulse.transmit_wf;
      channel1_length(i,j) = pulse.channel1_length;
      channel1_offset(i,j) = pulse.channel1_offset;
      if(wfs)
        channel1_wf(i,j) = &pulse.channel1_wf;
      channel2_length(i,j) = pulse.channel2_length;
      channel2_offset(i,j) = pulse.channel2_offset;
      if(wfs)
        channel2_wf(i,j) = &pulse.channel2_wf;
      channel3_length(i,j) = pulse.channel3_length;
      channel3_offset(i,j) = pulse.channel3_offset;
      if(wfs)
        channel3_wf(i,j) = &pulse.channel3_wf;
      channel4_length(i,j) = pulse.channel4_length;
      channel4_offset(i,j) = pulse.channel4_offset;
      if(wfs)
        channel4_wf(i,j) = &pulse.channel4_wf;
    }
    offset += raster_length(i);
  }

  max_pulse = number_of_pulses(max);
  if(max_pulse > 0 && max_pulse < 120) {
    offset_time = offset_time(..,:max_pulse);
    number_of_waveforms = number_of_waveforms(..,:max_pulse);
    transmit_bias = transmit_bias(..,:max_pulse);
    channel1_bias = channel1_bias(..,:max_pulse);
    channel2_bias = channel2_bias(..,:max_pulse);
    channel3_bias = channel3_bias(..,:max_pulse);
    channel4_bias = channel4_bias(..,:max_pulse);
    shaft_angle = shaft_angle(..,:max_pulse);
    integer_range = integer_range(..,:max_pulse);
    raw_irange = raw_irange(..,:max_pulse);
    flag_irange_bit14 = flag_irange_bit14(..,:max_pulse);
    flag_irange_bit15 = flag_irange_bit15(..,:max_pulse);
    data_length = data_length(..,:max_pulse);
    transmit_length = transmit_length(..,:max_pulse);
    transmit_offset = transmit_offset(..,:max_pulse);
    channel1_length = channel1_length(..,:max_pulse);
    channel1_offset = channel1_offset(..,:max_pulse);
    channel2_length = channel2_length(..,:max_pulse);
    channel2_offset = channel2_offset(..,:max_pulse);
    channel3_length = channel3_length(..,:max_pulse);
    channel3_offset = channel3_offset(..,:max_pulse);
    channel4_length = channel4_length(..,:max_pulse);
    channel4_offset = channel4_offset(..,:max_pulse);

    if(wfs) {
      transmit_wf = transmit_wf(..,:max_pulse);
      channel1_wf = channel1_wf(..,:max_pulse);
      channel2_wf = channel2_wf(..,:max_pulse);
      channel3_wf = channel3_wf(..,:max_pulse);
      channel4_wf = channel4_wf(..,:max_pulse);
    }
  }

  result = save(valid, raster_length, raster_type, seconds, fseconds,
    raster_number, number_of_pulses, digitizer);

  if(max_pulse) {
    save, result, offset_time, number_of_waveforms, shaft_angle, integer_range,
      raw_irange, flag_irange_bit14, flag_irange_bit15, data_length,
      transmit_bias, transmit_length, transmit_offset, channel1_bias,
      channel1_length, channel1_offset, channel2_bias, channel2_length,
      channel2_offset, channel3_bias, channel3_length, channel3_offset,
      channel4_bias, channel4_length, channel4_offset;
    if(wfs) {
      save, result, transmit_wf, channel1_wf, channel2_wf, channel3_wf,
        channel4_wf;
    }
  }

  return result;
}

func eaarla_fsecs2rn(seconds, fseconds, fast=) {
/* DOCUMENT rn = eaarla_fsecs2rn(seconds, fseconds, fast=)
  Given a pair of values SECONDS and FSECONDS, this will return the
  corresponding RN.

  This requires that the mission configuration manager have the mission
  configuration for the relevant dataset loaded. Otherwise, -1 will be
  returned.

  Values will be looked up against the EDB extern first. Then, the RN
  determined from that will be verified and refined by looking at the raw
  data. (If a time correction was applied to the EDB data, then the
  seconds/fseconds data in EDB may not match the raw data.) The raw data
  lookup can be suppressed using fast=1.

  If no match is found, -1 is returned.

  This can accept scalar or array input. SECONDS and FSECONDS must have
  identical dimensions.
*/
  extern edb;
  default, fast, 0;

  if(!is_scalar(seconds)) {
    result = array(long, dimsof(seconds));
    for(i = 1; i <= numberof(seconds); i++) {
      result(i) = eaarla_fsecs2rn(seconds(i), fseconds(i));
    }
    return result;
  }

  mission, load_soe, seconds + fseconds * 1.6e-6;
  if(is_void(edb))
    return -1;
  w = where(edb.seconds == seconds & edb.fseconds == fseconds);
  if(numberof(w) == 1) {
    rn = w(1);
    if(fast)
      return rn;
  } else if(numberof(w) > 1) {
    if(fast)
      return -1;
    rn = w(abs(edb.fseconds(w) - fseconds)(mnx));
  } else {
    if(fast)
      return -1;
    rn = abs(edb.seconds - seconds)(mnx);
  }

  count = numberof(edb);
  rast = eaarla_decode_header(get_erast(rn=rn));
  while(rn < count && rast.seconds < seconds) {
    rn++;
    rast = eaarla_decode_header(get_erast(rn=rn));
  }
  while(rn > 1 && rast.seconds > seconds) {
    rn--;
    rast = eaarla_decode_header(get_erast(rn=rn));
  }
  while(rn < count && rast.seconds == seconds && rast.fseconds < fseconds) {
    rn++;
    rast = eaarla_decode_header(get_erast(rn=rn));
  }
  while(rn > 1 && rast.seconds == seconds && rast.fseconds > fseconds) {
    rn--;
    rast = eaarla_decode_header(get_erast(rn=rn));
  }

  if(rast.seconds == seconds && rast.fseconds == fseconds)
    return rn;
  return -1;
}
