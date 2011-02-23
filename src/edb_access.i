// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "general.i";
require, "eaarl.i";

default, total_edb_records, 0;
default, data_path, "";

func get_total_edb_records {
/* DOCUMENT get_total_edb_records;
   YTK glue used by drast.ytk to get the records information.
*/
   extern total_edb_records, data_path;
   if(_ytk) {
      tksetval, "total_edb_records", total_edb_records;
      tksetval, "data_path", data_path;
   }
}

func edb_open(fn, filemode=, verbose=) {
/* DOCUMENT f = edb_open(fn, filemode=, verbose=);
   Opens a filehandle to an EDB file. Variables will be installed as follows:

      f.files_offset    int, scalar
      f.record_count    int, scalar
      f.file_count      int, scalar
      f.records         struct EAARL_INDEX of length f.record_count
      f.files           struct EDB_FILES of length f.file_count

   The EDB_FILES struct has the following fields:

      f.files.length    short
      f.files.name      char array usually of length 17

   The values for f.files.length should always be 17. To get a file name in
   string format, use strchar(f.files.name).

   SEE ALSO: EAARL_INDEX
*/
   default, filemode, "rb";
   default, verbose, 1;
   f = open(fn, filemode);
   i86_primitives, f;

   add_variable, f, 0, "files_offset", int;
   add_variable, f, 4, "record_count", int;
   add_variable, f, 8, "file_count", int;
   add_variable, f, 12, "records", EAARL_INDEX, f.record_count;

   offset = f.files_offset;
   lengths = array(short, f.file_count);
   len = 0s;
   for(i = 1; i <= f.file_count; i++) {
      _read, f, offset, len;
      lengths(i) = len;
      offset += len + 2;
   }

   datasize = f.file_count * 2 + lengths(sum);
   add_variable, f, f.files_offset, "filename_data", char, datasize;

   if(allof(lengths == lengths(1))) {
      // Filenames are almost always of the form:
      //    YYMMDD-HHMMSS.tld
      // Since the length of the filename is effectively constant, we can
      // install a struct into the file rather than reading them out manually.
      add_member, f, "EDB_FILES", 0, "length", short;
      add_member, f, "EDB_FILES", 2, "name", char, lengths(1);
      install_struct, f, "EDB_FILES";
      add_variable, f, f.files_offset, "files", "EDB_FILES", f.file_count;
      // To get the file names:
      //   strchar(f.files.name)
   }

   if(verbose)
      write, format="%s contains %d records from %d files.\n",
         file_tail(fn), f.record_count, f.file_count;

   return f;
}

func edb_get_filenames(f) {
/* DOCUMENT names = edb_get_filenames(f);
   Returns an array of the filenames defined by the stream f, which should be a
   filehandle as opened by edb_open.
*/
   if(has_member(f, "files")) {
      return strchar(f.files.name);
   } else {
      names = array(string, f.file_count);
      offset = 0;
      for(i = 1; i <= f.file_count; i++) {
         len = i16(f.filename_data, offset);
         offset += 2;
         temp = f.filename_data(offset:offset+len-1);
         offset += len;
         names(i) = strchar(temp);
      }
      return names;
   }
}

func load_edb(fn=, update=, verbose=, override_offset=) {
/* DOCUMENT load_edb, fn=, update, verbose=, override_offset=

   This function reads the index file produced by the efdb program. The data is
   a type of cross-reference to an entire EAARL data set. This permits easy
   access to the data without regard to what file the data are located in.

   Two variables are created by this load_edb: edb and edb_file. edb is an
   array of structures of type EAARL_INDEX, and edb_file is an array of
   structures containing the cross-referenced file names and the file status.
   To see some actual edb data, type edb(N) where N is the record number.

   SEE ALSO: edb_open EAARL_INDEX
*/
   extern edb_filename, edb, edb_files, _edb_fd, total_edb_records,
      data_path, soe_day_start, eaarl_time_offset, tans, pnav,
      gps_time_correction, initialdir;

   default, verbose, 1;
   default, update, 0;

   if(is_void(fn)) {
      fn = get_openfn(initialdir=initialdir, filetype="*.idx");
      data_path = file_dirname(file_dirname(fn));
   }

   filemode = update ? "r+b" : "rb";

   edb_filename = fn;
   //_edb_fd = idf = open(fn, filemode );
   f = edb_open(fn, filemode=filemode, verbose=verbose);

   edb_files = edb_get_filenames(f);

   // Parentheses ensure that we make a copy, rather than making a reference to
   // the file.
   edb = (f.records);

   /*
      eaarl_time_offset is computed below.  It needs to be added to any soe
      values read from the waveform database.  It is computed below by
      subtracting the time found in the first raster from the time in the first
      record of edb.  This works because after we determine the time offset,
      we correct the edb and write out a new version of the idx file.  This
      makes the idx file differ from times in the waveform data base by
      eaarl_time_offset seconds.  If you read in an idx file which hasn't been
      time corrected, the eaarl_time_offset will become 0 because there will be
      no difference in the time values in edb and the waveform database.

      The eaarl_time_offset can be safely used from decode_raster to correct
      time values as the rasters are read in.
   */

   // need this first, cuz get_erast uses it.
   eaarl_time_offset = 0;

   if(is_void(override_offset))
      eaarl_time_offset = edb(1).seconds - decode_raster(get_erast(rn=1)).soe;
   else
      eaarl_time_offset = override_offset;

   // Set these up with some suitable fall-back values
   data_begins = 1;
   soe_day_start = data_ends = year = day = 0;

   // locate the first time value that appears to be set to the gps
   q = where(edb.seconds > time2soe([2000,0,0,0,0,0])) ;

   // If valid soe time then try to improve values
   if(numberof(q)) {
      if(verbose)
         write, "*****  TIME contains date information ********";
      data_begins = q(1);
      data_ends = q(0);
      tmp = soe2time(edb(data_begins).seconds);
      year = tmp(1);
      day = unref(tmp)(2);
      soe_day_start = time2soe([year, day, 0, 0, 0, 0]);
   }

   soe_start = edb(data_begins).seconds;
   soe_stop = edb(data_ends).seconds;
   mission_duration = (edb.seconds(data_ends) - edb.seconds(data_begins)) / 3600.;

   edb_gb = swrite(format="%.3f", edb.raster_length(sum)/(2.^30));

   if(verbose) {
      soe2time(soe_start);
      soe2time(soe_stop);

      write, format="\
  Database contains: %s GB across %d files.\n\
          Year, day: %d, %d\n\
   SOE at day start: %d\n\
       First record: %d (first valid time)\n\
        Last record: %d\n\
       Data_path is: %s\n\
   Mission duration: %f hours\n\
\n\
You now have edb and edb_files variables.\n\
Type info, EDB to see the structure of edb.\n\
To see a raster, try:\n\
   rn = 1000;\n\
   fma; drast, get_erast(rn=rn++);\n",
         edb_gb, f.file_count, year, day, soe_day_start, data_begins,
         data_ends, data_path, mission_duration;
      if(update)
         write, "******NOTE: The file(s) are open for updating.";
   }

   determine_gps_time_correction, edb_filename, verbose=verbose;
   total_edb_records = numberof(edb);

   // if we're using ytk, then set a var over in tcl to indicate the total
   // number of records and the data path.
   if(_ytk) {
      get_total_edb_records;
      tksetval, "edb(gb)", edb_gb;
      tksetval, "edb(number_of_files)", numberof(edb_files);
      tksetval, "edb(year)", year;
      tksetval, "edb(day)", day;
      tksetval, "edb(data_begins)", data_begins;
      tksetval, "edb(data_ends)", data_ends;
      tksetval, "edb(mission_duration)", mission_duration;
      tksetval, "edb(soe)", soe_day_start;
      tksetval, "edb(eaarl_time_offset)", eaarl_time_offset;
      tksetval, "edb(path)", data_path;
      tksetval, "edb(idx_file)", fn;
      tksetval, "edb(nbr_rasters)", numberof(edb);
   }
   // adding time correct array (tca) function
   time_correct, data_path;
   if(verbose)
      write, "load_edb_completed";
}

func edb_update(time_correction) {
/* DOCUMENT edb_update, time_correction;
   Writes the memory version of edb back into the file.  Used to correct time
   of day problems.
*/
   extern edb_filename, edb;
   if(!is_void(edb_filename) && !is_void(edb)) {
      edb.seconds += time_correction;
      f = edb_open(edb_filename, filemode="r+b");
      f.edb = edb;
      close, f;
      write, "edb updated";
   }
}

func get_tld_rasts(fnum=, fname=) {
/* DOCUMENT rasts = get_tld_rasts(fnum=, fname=)
   Returns an array of pointers to all of the rasters in a given TLD file.

   One of these two options are required:
      fnum= The file number in edb_files
      fname= The file name in edb_files

   Result is a vector of pointers. Each pointer points to a vector of type
   char. The char vectors can be interpreted using decode_raster.
*/
   extern edb, edb_files, edb_filename;
   if(is_void(fnum) && !is_void(fname)) {
      w = where(strglob("*"+file_tail(fname), edb_files));
      if(numberof(w) == 1)
         fnum = w(1);
   }
   if(is_void(fnum) || fnum < 1 || fnum > numberof(edb_files))
      error, "Must provide valid fnum= or fname=";

   w = where(edb.file_number == fnum);
   fn = file_tail(edb_files(fnum));
   fullfn = file_join(file_dirname(edb_filename), fn);
   f = open(fullfn, "rb");
   add_variable, f, -1, "raw", char, sizeof(f);

   rasts = array(pointer, numberof(w));
   offsets = (edb(w).raster_length)(cum);

   for(i = 1; i <= numberof(rasts); i++)
      rasts(i) = &(f.raw(offsets(i)+1:offsets(i+1)));

   return rasts;
}

func get_erast(rn=, sod=, hms=, timeonly=) {
/* DOCUMENT get_erast(rn=, sod=, hms=, timeonly=)

   Returns the requested raster from the database. The request can specify the
   raster either by raster number, sod (seconds-of-day), or hms
   (hours-minutes-seconds). Hms values are integers such as 123456 which is 12
   hours, 34 minutes, and 56 seconds.

   If a scalar raster (or sod or hms) is provided, then the return data will be
   an array of characters which will vary in length depending on the complexity
   of the laser waveforms therein. If an array of rasters (or sods or hms) is
   provided, then the return data will be an array of pointers to arrays of
   character.

   If the timeonly variable is set to anything, get_erast will only read and
   return the first 16 bytes of the raster.  This is used to improve speed when
   updating the seconds field in the data.  Setting timeonly will also cause
   get_erast to open the waveform files for random access read/write so the
   time can be updated.  See time_fix.i for more information on this.

   SEE ALSO: drast decode_raster soe2sod sod2hms hms2sod
*/
   extern data_path, edb, edb_files, edb_filename, _eidf, soe_day_start;
   default, timeonly, 0;

   scalar = 0;
   if(is_void(rn)) {
      if(is_void(sod) && !is_void(hms))
         sod = hms2sod(hms);
      if(!is_void(sod)) {
         rn = set_intersection(edb.seconds, sod, idx=1);
         scalar = is_scalar(sod);
      }
   }

   if(is_void(rn))
      error, "Unable to determine rn. Please specify rn=, sod=, or hms=.";
   scalar = scalar | is_scalar(rn);

   if(!is_scalar(rn)) {
      result = array(pointer, dimsof(rn));
      for(i = 1; i <= numberof(rn); i++)
         result(i) = &get_erast(rn=rn(i));
      return result;
   }

   fidx = edb(rn).file_number;

   // If the currently open file is the same as the same as the one the
   // requested raster is in, then we use it else we change to the new file.
   fn = file_tail(edb_files(fidx));
   if(is_void(_eidf) || fn != file_tail(filepath(_eidf))) {
      filemode = timeonly ? "r+b" : "rb";
      fullfn = file_join(file_dirname(edb_filename), fn);
      _eidf = open(fullfn, filemode);
   }

   // _eidf now should point to our file
   len = timeonly ? 16 : edb(rn).raster_length;
   rast = array(char, len);
   _read, _eidf, edb(rn).offset, rast;
   return rast;
}

func decode_rasters(raw) {
/* DOCUMENT rasts = decode_rasters(raw)
   Given an array of pointers to raw raster data, this returns an array of RAST
   with the decoded rasters. This is effectively a wrapper around decode_raster
   for an array of pointers.
*/
   rasts = array(RAST, dimsof(raw));
   count = numberof(raw);
   for(i = 1; i <= count; i++)
      rasts(i) = (decode_raster(*raw(i)))(1);
   return rasts;
}

func eaarl1_decode_header(raw) {
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
   if(is_void(header)) header = decode_raster_header(raw);
   result = save();
   if(!eaarl1_header_valid(header))
      return result;

   offset = header.pulse_offsets(pulse);
   save, result, offset_time=i32(raw, offset);
   save, result, transmit_bias=raw(offset+4);
   save, result, return_bias=raw(offset+5:offset+8);
   save, result, shaft_angle=i16(raw, offset+9);
   save, result, integer_range=i16(raw, offset+11);
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
   transmit_bias = transmit_length = channel1_bias = channel2_bias =
         channel3_bias = array(char, count, 120);
   shaft_angle = integer_range = data_length = channel1_length =
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
      save, result, offset_time, shaft_angle, integer_range, data_length,
            transmit_bias, transmit_length, transmit_wf, channel1_bias,
            channel1_length, channel1_wf, channel2_bias, channel2_length,
            channel2_wf, channel3_bias, channel3_length, channel3_wf;
   }

   return result;
}

func decode_raster(raw) {
   extern eaarl_time_offset, tca;
   local rasternbr, type, len;

   result = array(RAST,1);
   header = eaarl1_decode_header(raw);
   if(header.raster_type != 5) {
      write, format="Raster %d has invalid type (%d) Len:%d\n",
         header.raster_number, header.raster_type, header.raster_length;
      return result;
   }
   if(!eaarl1_header_valid(header))
      return result;

   seconds = header.seconds + eaarl_time_offset;
   if(!is_void(tca) && numberof(tca) >= header.raster_number)
      seconds += tca(header.raster_number);

   result.digitizer = header.digitizer;
   result.soe = seconds;
   result.rasternbr = header.raster_number;
   result.npixels = header.number_of_pulses;

   for(i = 1; i <= header.number_of_pulses; i++) {
      pulse = eaarl1_decode_pulse(raw, i, header=header);
      result.irange(i) = pulse.integer_range;
      result.sa(i) = pulse.shaft_angle;
      result.offset_time(i) = ((pulse.offset_time & 0x00ffffff) +
         header.fseconds) * 1.6e-6 + seconds;
      result.rxbias(i,) = pulse.return_bias;
      result.tx(i) = &pulse.transmit_wf(:);
      result.rx(i,1) = &pulse.channel1_wf(:);
      result.rx(i,2) = &pulse.channel2_wf(:);
      result.rx(i,3) = &pulse.channel3_wf(:);
   }

   return result;
}

func edb_summary(path, searchstr=) {
/* DOCUMENT edb_summary, directory, searchstr=
   edb_summary, files

   Prints out a summary of information from the EDB files. The parameter can be
   a directory path, a file path, or an array of file paths. If the parameter
   is a directory path, then searchstr= specifies a pattern to search for and
   defaults to "*.idx".

   This only needs access to the *.idx files and can be run even if the TLD
   files are compressed or unavailable.
*/
   if(is_scalar(path) && file_isdir(path)) {
      default, searchstr, "*.idx";
      path = find(path, glob=searchstr);
   }

   records = seconds = pixels = tldcount = 0;

   write, "";
   for(i = 1; i <= numberof(path); i++) {
      f = edb_open(path(i), verbose=0);
      rec = f.record_count;
      sec = numberof(set_remove_duplicates(f.records.seconds));
      pix = f.records.pixels(sum);
      tld = f.file_count;

      records += rec;
      seconds += sec;
      pixels += pix;
      tldcount += tld;

      write, format="%s (%d files):\n", file_tail(path(i)), tld;
      write, format="   Period: %s - %s\n",
         soe2iso8601(f.records.seconds(1)), soe2iso8601(f.records.seconds(0));
      write, format="  Seconds: %d (%s)\n", sec, seconds2prettytime(sec);
      write, format="   Pixels: %-16d Rasters: %d\n", pix, rec;
      write, format="     Rate: %.3f KHz\n", double(pix)/sec/1000.;
      write, "";

      close, f;
   }

   if(numberof(path) > 1) {
      write, format="Overall (%d files):\n", tldcount;
      write, format="  Seconds: %d (%s)\n", seconds, seconds2prettytime(seconds);
      write, format="   Pixels: %-16d Rasters: %d\n", pixels, records;
      write, format="     Rate: %.3f KHz\n", double(pixels)/seconds/1000.;
      write, "";
   }
}

func eaarl1_fsecs2rn(seconds, fseconds, fast=) {
/* DOCUMENT rn = eaarl1_fsecs2rn(seconds, fseconds, fast=)
   Given a pair of values SECONDS and FSECONDS, this will return the
   corresponding RN.

   This requires that the mission configuration manager have the mission
   configuration for the relevant dataset loaded.

   Values will be looked up against the EDB extern first. Then, the RN
   determined from that will be verified and refined by looking at the raw
   data. (If a time correction was applied to the EDB data, then the
   seconds/fseconds data in EDB may not match the raw data.) The raw data
   lookup can be suppressed using fast=1.

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
   w = where(edb.seconds == seconds & edb.fseconds == fseconds);
   if(numberof(w) == 1) {
      rn = w(1);
      if(fast)
         return rn;
   } else {
      if(fast)
         return -1;
      rn = abs(edb.seconds - seconds)(mnx);
   }

   rast = eaarl1_decode_header(get_erast(rn=rn));
   while(rast.seconds < seconds) {
      rn++;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rast.seconds > seconds) {
      rn--;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rast.seconds == seconds && rast.fseconds < fseconds) {
      rn++;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }
   while(rast.seconds == seconds && rast.fseconds > fseconds) {
      rn--;
      rast = eaarl1_decode_header(get_erast(rn=rn));
   }

   if(rast.seconds == seconds && rast.fseconds == fseconds)
      return rn;
   return -1;
}
