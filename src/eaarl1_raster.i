// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func eaarl1_decode_header(raw) {
/* DOCUMENT eaarl1_decode_header(raw)
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
   119.
*/
   extern eaarl_time_offset, tca;
   local rasternbr, type, len;

   result = save();
   save, result, raster_length=i24(raw, 1);
   save, result, raster_type=raw(4);

   if(result.raster_type != 5)
      return result;

   if(result.raster_length >= 8)
      save, result, seconds=i32(raw, 5);
   if(result.raster_length >= 12)
      save, result, fseconds=i32(raw, 9);
   if(result.raster_length >= 16)
      save, result, raster_number=i32(raw, 13);

   if(result.raster_length >= 18) {
      save, result, number_of_pulses=i16(raw, 17) & 0x7fff,
            digitizer=(i16(raw,17) >> 15) & 0x1;

      offset = 19;
      pulse_offsets = array(-1, result.number_of_pulses);
      for(i = 1; i <= result.number_of_pulses; i++) {
         if(offset + 15 > result.raster_length)
            break;
         pulse_offsets(i) = offset;
         offset += 15 + i16(raw, offset + 13);
      }
      save, result, pulse_offsets;
   }

   return result;
}

func eaarl1_header_valid(header) {
/* DOCUMENT eaarl1_header_valid(header)
   Returns 1 if the given header is valid, 0 if not. HEADER must be the result
   of eaarl1_decode_header.
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

func eaarl1_decode_pulse(raw, pulse, header=) {
/* DOCUMENT eaarl1_decode_header(raw)
   Given the raw data for a raster, this will decode and return the pulse
   information for the specified pulse number.

   Parameters:
      raw: An array of char data from a TLD file (as returned by get_erast).
      pulse: Pulse number to retrieve, usually in the range 1-119.
   Options:
      header= The result of eaarl1_decode_header. If not supplied, it was be
         determined from RAW. Providing the header is more efficient if you
         already have it or will be retrieving multiple pulses from one raster.

   The decoded information will be returned as an oxy group object with these
   fields:

      offset_time = array(long)
      transmit_bias = array(char)
      return_bias = array(char,4)
      shaft_angle = array(short)
      integer_range = array(short)
      raw_irange = array(short)
      flag_irange_bit14 = array(char)
      flag_irange_bit15 = array(char)
      data_length = array(short)
      transmit_length = array(char)
      transmit_wf = array(char,x)
      channel1_length = array(short)
      channel1_wf = array(char,x)
      channel2_length = array(short)
      channel2_wf = array(char,x)
      channel3_length = array(short)
      channel3_wf = array(char,x)

   The various *_wf fields will be vectors of varying lengths (as defined by
   the corresponding *_length fields).
*/
   if(is_void(header)) header = decode_raster_header(raw);
   result = save();
   if(!eaarl1_header_valid(header))
      return result;

   offset = header.pulse_offsets(pulse);
   save, result, offset_time=i32(raw, offset);
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
   save, result, transmit_length=raw(offset);
   if(result.transmit_length <= 0)
      return result;
   save, result, transmit_wf=raw(offset+1:offset+result.transmit_length);

   offset += 1 + result.transmit_length;
   save, result, channel1_length=i16(raw, offset);
   if(result.channel1_length <= 0)
      return result;
   save, result, channel1_wf=raw(offset+2:offset+1+result.channel1_length);

   offset += 2 + result.channel1_length;
   save, result, channel2_length=i16(raw, offset);
   if(result.channel2_length <= 0)
      return result;
   save, result, channel2_wf=raw(offset+2:offset+1+result.channel2_length);

   offset += 2 + result.channel2_length;
   save, result, channel3_length=i16(raw, offset);
   if(result.channel3_length <= 0)
      return result;
   save, result, channel3_wf=raw(offset+2:offset+1+result.channel3_length);

   return result;
}

func eaarl1_decode_rasters(raw) {
/* DOCUMENT data = eaarl1_decode_rasters(raw)
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
      shaft_angle = array(short,COUNT,NUM_PULSES)
      integer_range = array(short,COUNT,NUM_PULSES)
      raw_irange = array(short,COUNT,NUM_PULSES)
      flag_irange_bit14 = array(short,COUNT,NUM_PULSES)
      flag_irange_bit15 = array(short,COUNT,NUM_PULSES)
      data_length = array(short,COUNT,NUM_PULSES)
      transmit_bias = array(char,COUNT,NUM_PULSES)
      transmit_length = array(char,COUNT,NUM_PULSES)
      transmit_wf = array(pointer,COUNT,NUM_PULSES)
      channel1_bias = array(char,COUNT,NUM_PULSES)
      channel1_length = array(short,COUNT,NUM_PULSES)
      channel1_wf = array(pointer,COUNT,NUM_PULSES)
      channel2_bias = array(char,COUNT,NUM_PULSES)
      channel2_length = array(short,COUNT,NUM_PULSES)
      channel2_wf = array(pointer,COUNT,NUM_PULSES)
      channel3_bias = array(char,COUNT,NUM_PULSES)
      channel3_length = array(short,COUNT,NUM_PULSES)
      channel3_wf = array(pointer,COUNT,NUM_PULSES)

   Where COUNT is the number of rasters provided and NUM_PULSES is the maximum
   number of pulses found for any given raster.
*/
   if(!is_pointer(raw))
      raw = &raw;
   raw = raw(*);

   count = numberof(raw);

   // header fields
   valid = array(char, count);
   raster_length = seconds = fseconds = raster_number = array(long, count);
   raster_type = number_of_pulses = digitizer = array(short, count);

   // pulse fields -- never more than 120 pulses
   offset_time = array(long, count, 120);
   transmit_bias = flag_irange_bit14 = flag_irange_bit15 = transmit_length =
         channel1_bias = channel2_bias = channel3_bias =
         array(char, count, 120);
   shaft_angle = integer_range = raw_irange = data_length = channel1_length =
         channel2_length = channel3_length = array(short, count, 120);
   transmit_wf = channel1_wf = channel2_wf = channel3_wf =
         array(pointer, count, 120);

   for(i = 1; i <= count; i++) {
      header = eaarl1_decode_header(*raw(i));
      valid(i) = eaarl1_header_valid(header);
      if(!valid(i))
         continue;
      raster_length(i) = header.raster_length;
      raster_type(i) = header.raster_type;
      seconds(i) = header.seconds;
      fseconds(i) = header.fseconds;
      raster_number(i) = header.raster_number;
      number_of_pulses(i) = header.number_of_pulses;
      digitizer(i) = header.digitizer;

      for(j = 1; j <= number_of_pulses(i); j++) {
         pulse = eaarl1_decode_pulse(*raw(i), j, header=header);
         offset_time(i,j) = pulse.offset_time;
         transmit_bias(i,j) = pulse.transmit_bias;
         channel1_bias(i,j) = pulse.return_bias(1);
         channel2_bias(i,j) = pulse.return_bias(2);
         channel3_bias(i,j) = pulse.return_bias(3);
         shaft_angle(i,j) = pulse.shaft_angle;
         integer_range(i,j) = pulse.integer_range;
         raw_irange(i,j) = pulse.raw_irange;
         flag_irange_bit14(i,j) = pulse.flag_irange_bit14;
         flag_irange_bit15(i,j) = pulse.flag_irange_bit15;
         data_length(i,j) = pulse.data_length;
         transmit_length(i,j) = pulse.transmit_length;
         transmit_wf(i,j) = &pulse.transmit_wf;
         channel1_length(i,j) = pulse.channel1_length;
         channel1_wf(i,j) = &pulse.channel1_wf;
         channel2_length(i,j) = pulse.channel2_length;
         channel2_wf(i,j) = &pulse.channel2_wf;
         channel3_length(i,j) = pulse.channel3_length;
         channel3_wf(i,j) = &pulse.channel3_wf;
      }
   }

   max_pulse = number_of_pulses(max);
   if(max_pulse > 0 && max_pulse < 120) {
      offset_time = offset_time(..,:max_pulse);
      transmit_bias = transmit_bias(..,:max_pulse);
      channel1_bias = channel1_bias(..,:max_pulse);
      channel2_bias = channel2_bias(..,:max_pulse);
      channel3_bias = channel3_bias(..,:max_pulse);
      shaft_angle = shaft_angle(..,:max_pulse);
      integer_range = integer_range(..,:max_pulse);
      raw_irange = raw_irange(..,:max_pulse);
      flag_irange_bit14 = flag_irange_bit14(..,:max_pulse);
      flag_irange_bit15 = flag_irange_bit15(..,:max_pulse);
      data_length = data_length(..,:max_pulse);
      transmit_length = transmit_length(..,:max_pulse);
      transmit_wf = transmit_wf(..,:max_pulse);
      channel1_length = channel1_length(..,:max_pulse);
      channel1_wf = channel1_wf(..,:max_pulse);
      channel2_length = channel2_length(..,:max_pulse);
      channel2_wf = channel2_wf(..,:max_pulse);
      channel3_length = channel3_length(..,:max_pulse);
      channel3_wf = channel3_wf(..,:max_pulse);
   }

   result = save(valid, raster_length, raster_type, seconds, fseconds,
      raster_number, number_of_pulses, digitizer);

   if(max_pulse) {
      save, result, offset_time, shaft_angle, integer_range, raw_irange,
         flag_irange_bit14, flag_irange_bit15, data_length, transmit_bias,
         transmit_length, transmit_wf, channel1_bias, channel1_length,
         channel1_wf, channel2_bias, channel2_length, channel2_wf,
         channel3_bias, channel3_length, channel3_wf;
   }

   return result;
}

func eaarl1_fsecs2rn(seconds, fseconds, fast=) {
/* DOCUMENT rn = eaarl1_fsecs2rn(seconds, fseconds, fast=)
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
         result(i) = eaarl1_fsecs2rn(seconds(i), fseconds(i));
      }
      return result;
   }

   missiondata_soe_load, seconds + fseconds * 1.6e-6;
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
   rast = eaarl1_decode_header(get_erast(rn=rn));
   while(rn < count && rast.seconds < seconds) {
      rn++;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rn > 1 && rast.seconds > seconds) {
      rn--;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rn < count && rast.seconds == seconds && rast.fseconds < fseconds) {
      rn++;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rn > 1 && rast.seconds == seconds && rast.fseconds > fseconds) {
      rn--;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }

   if(rast.seconds == seconds && rast.fseconds == fseconds)
      return rn;
   return -1;
}
