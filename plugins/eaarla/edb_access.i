// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "general.i";

default, total_edb_records, 0;
default, data_path, "";

local EAARL_INDEX;
/* DOCUMENT
  Structure for indexing into TLD files to retrieve waveforms.

  struct EAARL_INDEX {
    int seconds;         seconds of the epoch
    int fseconds;        fractional seconds (1e-6)
    int offset;          offset in file to raster data
    int raster_length;   length of raster
    short file_number;   file raster is in (index into array of filenames)
    char pixels;         pixel count for this raster
    char digitizer;      digitizer used
  };

  SEE ALSO: edb_open load_edb
*/
struct EAARL_INDEX {
  int seconds;
  int fseconds;
  int offset;
  int raster_length;
  short file_number;
  char pixels;
  char digitizer;
};

local RAST;
/* DOCUMENT
  Structure for raw waveform raster data.

  struct RAST {
    int soe;                   seconds of the epoch
    int rasternbr;             raster number
    int digitizer;             digitizer
    int npixels;               number of pixels actually in this raster
    int irange(120);           integer range values
    int sa(120);               shaft angles
    double offset_time(120);   fractional offset seconds
    int rxbias(120,4);         receive waveform bias values
    pointer tx(120);           transmit waveforms
    pointer rx(120,4);         return waveforms
  };

  SEE ALSO: decode_raster
*/
struct RAST {
  int soe, rasternbr, digitizer, npixels;
  int irange(120), sa(120);
  double offset_time(120);
  int rxbias(120,4);
  pointer tx(120), rx(120,4);
};

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

  edb_fn1 = file_join(file_dirname(edb_filename), file_tail(edb_files(1)));
  if(!is_void(override_offset)) {
    eaarl_time_offset = override_offset;
  } else if(file_exists(edb_fn1)) {
    eaarl_time_offset = edb(1).seconds - decode_raster(rn=1).soe;
  } else {
    write, "WARNING: Unable to determine eaarl_time_offset, using 0"
    if(file_exists(edb_fn1+".bz2"))
      write, "         EAARL TLD files appear to be compressed, please decompress";
    else
      write, "         EAARL TLD files appear to be missing";
    eaarl_time_offset = 0.;
  }

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

func time_correct(path) {
  extern tca, edb;
  fname = path+"tca.pbd";
  if (catch(0x02)) {
    return;
  }
  f = openb(fname);
  restore, f, tca;
  edb.seconds = edb.seconds + tca;
  close, f;
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
    f.records = edb;
    close, f;
    write, "edb updated";
  }
}

func get_soe_rasts(start, stop) {
/* DOCUMENT get_soe_rasts(start, stop)
  Given a START time and STOP time in seconds of the epoch, this will return
  the raw rasters for that range of times. START and STOP may optionally be
  arrays (which must match each other in dimensions). The return result will be
  a 1-dimensional array of pointers to raw char data.

  This function requires that a mission configuration is loaded. Each
  START/STOP range must fall within a single mission day; however, multiple
  START/STOP ranges may fall within multiple mission days.
*/
  start = long(floor(start));
  stop = long(ceil(stop));
  count = numberof(start);
  result = array(pointer, count);
  for(i = 1; i <= count; i++) {
    mission, load_soe, start(i);
    b1 = digitize(start(i)-1, edb.seconds);
    b0 = digitize(stop(i), edb.seconds) - 1;
    result(i) = &get_erast(rn=indgen(b1:b0));
  }
  return merge_pointers(result);
}

func get_erast(rn=, soe=, sod=, hms=, timeonly=) {
/* DOCUMENT get_erast(rn=, soe=, sod=, hms=, timeonly=)

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
    if(is_void(soe) && !is_void(sod))
      soe = sod + soe_day_start;
    if(!is_void(soe)) {
      rn = where(set_contains(soe, edb.seconds));
      scalar = is_scalar(soe);
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

func decode_raster(raw, rn=) {
/* DOCUMENT rast = decode_raster(raw, rn=)
  Decodes raw raster data (in a char array) into the RAST structure.

  Parameter:
    raw: An array of char as extracted from a TLD file by get_erast.

  Option:
    rn= A raster number to look up via get_erast; used only if raw is not
      supplied.

  Returns:
    array(RAST,1) with the decoded raster data.

  Usage:
    Retrieve raster data for a raster number:
      rn = 1000
      raw = get_erast(rn=rn);
      rast = decode_raster(raw);

    Extract waveform for channel 1 from pixel 60 and assign to wf:
      wf = *rast.rx(60,1)

    Extract, convert to integer, flip, and remove bias from pixel 60,
    channel 1:
      wf = *rast.rx(60,1)
      wf = int((~wf+1)-(~wf(1)+1))
*/
  extern eaarl_time_offset, tca;
  local rasternbr, type, len;

  if(is_void(raw) && !is_void(rn)) {
    if(numberof(rn) == 1) {
      raw = get_erast(rn=rn);
    } else {
      result = array(RAST, numberof(rn));
      for(i = 1; i <= numberof(rn); i++) {
        result(i) = decode_raster(rn=rn(i));
      }
      return result;
    }
  }

  result = array(RAST,1);
  header = eaarl_decode_header(raw);
  if(header.raster_type != 5) {
    write, format="Raster %d has invalid type (%d) Len:%d\n",
      header.raster_number, header.raster_type, header.raster_length;
    return result;
  }
  if(!eaarl_header_valid(header))
    return result;

  seconds = header.seconds + eaarl_time_offset;
  if(!is_void(tca) && numberof(tca) >= header.raster_number)
    seconds += tca(header.raster_number);

  result.digitizer = header.digitizer;
  result.soe = seconds;
  result.rasternbr = header.raster_number;
  result.npixels = header.number_of_pulses;

  for(i = 1; i <= header.number_of_pulses; i++) {
    pulse = eaarl_decode_pulse(raw, i, header=header, wfs=1);
    result.irange(i) = pulse.raw_irange;
    result.sa(i) = pulse.shaft_angle;
    result.offset_time(i) = (pulse.offset_time + header.fseconds) \
      * 1.6e-6 + seconds;
    result.rxbias(i,) = pulse.return_bias;
    result.tx(i) = &pulse.transmit_wf;
    result.rx(i,1) = &pulse.channel1_wf;
    result.rx(i,2) = &pulse.channel2_wf;
    result.rx(i,3) = &pulse.channel3_wf;
    result.rx(i,4) = &pulse.channel4_wf;
  }

  return result;
}

func mission_edb_summary {
/* DOCUMENT mission_edb_summary
  Wrapper around edb_summary that calls it with the list of edb files defined
  in the current mission configuration.
*/
  flights = mission(get,);
  edbfns = [];
  for(i = 1; i <= numberof(flights); i++) {
    if(mission(has, flights(i), "edb file"))
      grow, edbfns, mission(get, flights(i), "edb file");
  }
  edb_summary, edbfns;
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
    path = find(path, searchstr=searchstr);
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
