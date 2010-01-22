// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "general.i";
require, "eaarl.i";

local edb_access
/* DOCUMENT edb_access.i

   Vars/Data Structures:
       EDB
       RAST
       EDB_INDEX

   Functions/subroutines:
       load_edb, fn=
       get_erast( rn=, sod=, hms= )
       decode_raster(r)
*/

default, t0, array(double, 3);
default, t1, array(double, 3);
default, total_edb_records, 0;
default, data_path, "";
pldefault, marks=0;

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
      f.records         struct EDB of length f.record_count
      f.files           struct EDB_FILES of length f.file_count

   The EDB struct has the following fields:

      f.records.seconds          int
      f.records.fseconds         int
      f.records.offset           int
      f.records.raster_length    int
      f.records.file_number      short
      f.records.pixels           char
      f.records.digitizer        char

   The EDB_FILES struct has the following fields:

      f.files.length    short
      f.files.name      char of length 17

   The values for f.files.length will always be 17. To get a file name in
   string format, use strchar(f.files.name).
*/
   default, filemode, "rb";
   default, verbose, 1;
   f = open(fn, filemode);
   i86_primitives, f;

   add_member, f, "EDB", 0,  "seconds", int;
   add_member, f, "EDB", -1, "fseconds", int;
   add_member, f, "EDB", -1, "offset", int;
   add_member, f, "EDB", -1, "raster_length", int;
   add_member, f, "EDB", -1, "file_number", short;
   add_member, f, "EDB", -1, "pixels", char;
   add_member, f, "EDB", -1, "digitizer", char;
   install_struct, f, "EDB";


   add_variable, f, 0, "files_offset", int;
   add_variable, f, 4, "record_count", int;
   add_variable, f, 8, "file_count", int;
   add_variable, f, 12, "records", "EDB", f.record_count;

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

   This function reads the index file produced by the efdb program.  The data
   is a type of cross-reference to an entire EAARL data set. This permits easy
   access to the data without regard to what file the data are located in.

   Two variables are created by this load_edb: edb and edb_file.  edb is an
   array of structures of type EDB, and edb_file is an array of structures
   containing the cross-referenced file names and the file status.  To see
   whats in the edb structure, type EDB.  This will list the definition.  To
   see some actual edb data, type edb(N) where N is the record number.
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
   f = edb_open(fn, filemode=filemode);

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

   determine_gps_time_correction, edb_filename;
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

func get_erast(rn=, sod=, hms=, timeonly=) {
/* DOCUMENT get_erast( rn=, sod=, hms=, timeonly= )

   Returns the requested raster from the database.  The request can
specify the raster either by raster number, sod (seconds-of-day), or
hms ( hours-minutes-seconds). Hms values are integers such as
123456 which is 12 hours, 34 minutes, and 56 seconds.

   The returned data will be an array of characters which will vary in
length depending on the complexity of the laser waveforms therein.

If the timeonly variable is set to anything, get_erast will only
read and return the first 16 bytes of the raster.  This is used
to improve speed when updating the seconds field in the data.  Setting
timeonly will also cause get_erast to open the waveform files for
random access read/write so the time can be updated.  See time_fix.i
for more information on this.

See also:
   drast decode_raster
   ytime.i:  soe2sod sod2hms hms2sod

*/
   extern data_path, edb, edb_files, _eidf, soe_day_start;
   default, timeonly, 0;

   if(is_void(rn)) {
      if(is_void(sod) && !is_void(hms))
         sod = hms2sod(hms);
      if(!is_void(sod))
         rn = where(edb.seconds == sod);
      if(numberof(rn))
         rn = rn(1);
   }

   if(is_void(rn))
      error, "Unable to determine rn. Please specify rn=, sod=, or hms=.";

   fidx = edb(rn).file_number;

   // If the currently open file is the same as the same as the one the
   // requested raster is in, then we use it else we change to the new file.
   fn = file_tail(edb_files(fidx));
   if(is_void(_eidf) || fn != file_tail(filepath(_eidf))) {
      filemode = timeonly ? "r+b" : "rb";
      _eidf = open(file_join(data_path, "eaarl", fn), filemode);
   }

   // _eidf now should point to our file
   len = timeonly ? 16 : edb(rn).raster_length;
   rast = array(char, len);
   _read, _eidf, edb(rn).offset, rast;
   return rast;
}

func decode_raster(r) {
/* DOCUMENT decode_raster(r)
   Inputs:  r      ; r is an edb raster data variable
   Returns:
     decode_raster returns a RAST array of data.

Type RAST to see whats in the RAST structure.

Usage:
  r = get_erast(rn = rn ); // get a raster from the database
  rp = get_erast(rn = rn ); fma; drast(rp); rn +=1

Examples using the result data:
   Plot rx waveform 60 channel 1:  plg,(*p.rx(60)) (,1)
   Plot irange values:             plmk,p.irange(1:0)
   Plot sa values:                 plmk,p.sa(1:0)


 To extract waveform 1 from pixel 60 and assign to w:
   w = (*p.rx(60))(,1)

 To extract, convert to integer, and remove bias from pixel 60, ch 1 use:
   w = *p.rx(60,1)
   w = int((~w+1) - (~w(1)+1));

 History:
   2/7/02 ww Modified to check for short rasters and return an empty one if
          short one was found.  The problem occured reading 9-7-01 data.  It
      may have been caused by data system lockup.

*/
   extern eaarl_time_offset, tca;

   return_raster = array(RAST,1);
   irange = array(int, 120);
   sa = array(int, 120);
   offset_time = array(int, 120);

   len = i24(r, 1);           // raster length
   type= r(4);                // raster type id (should be 5 )
   if(type != 5) {
      write, format="Raster %d has invalid type (%d) Len:%d\n",
         rasternbr, type, len;
      return return_raster;
   }

   if(len < 20)               // return empty raster.
      return return_raster;   // failed.

   seconds = i32(r, 5);             // raster seconds of the day
   seconds += eaarl_time_offset;    // correct for time set errors.

   fseconds = i32(r, 9);            // raster fractional seconds 1.6us lsb
   rasternbr = i32(r, 13);          // raster number
   npixels = i16(r,17)&0x7fff;      // number of pixels
   digitizer = (i16(r,17)>>15)&0x1; // digitizer
   a = 19;                          // byte starting point for waveform data

   if(anyof([rasternbr, fseconds, npixels] < 0))
      return return_raster;
   if(npixels > 120)
      return return_raster;
   if(seconds(1) < 0)
      return return_raster;

   if((!is_void(tca)) && (numberof(tca) > rasternbr))
      seconds = seconds+tca(rasternbr);

   for(i = 1; i <= npixels - 1; i++) { // loop thru entire set of pixels
      offset_time(i) = i32(r, a);   a+=4; // fractional time of day since gps 1hz
      txb = r(a);                   a++;  // transmit bias value
      rxb = r(a:a+3);               a+=4; // waveform bias array
      sa(i) = i16(r, a);            a+=2; // shaft angle values
      irange(i) = i16(r, a);        a+=2; // integer NS range value
      plen = i16(r, a);             a+=2;
      wa = a;                             // starting waveform index (wa)
      a = a + plen;                       // use plen to skip to next pulse
      txlen = r(wa);                wa++; // transmit len is 8 bits max

      if(txlen <= 0) {
         write, format=" (txlen<=0) raster:%d edb_access.i:decode_raster(%d). Channel 1  Bad rxlen value (%d) i=%d\n", rasternbr, txlen, wa, i;
         break;
      }

      txwf = r(wa:wa+txlen-1);            // get the transmit waveform
      wa += txlen;                        // update wf address to first rx waveform
      rxlen = i16(r,wa);         wa+=2;   // get 1st waveform and update wa to next

      if(rxlen <= 0) {
         write, format=" (rxlen<-0)raster:%d edb_access.i:decode_raster(%d). Channel 1  Bad rxlen value (%d) i=%d\n", rasternbr, rxlen, wa, i;
         break;
      }

      rx = array(char, rxlen, 4);   // get all four return waveform bias values
      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,1))) break;
      rx(,1) = rxr;  // get first waveform
      wa += rxlen;         // update wa pointer to next
      rxlen = i16(r,wa); wa += 2;

      if(rxlen <= 0) {
         write, format=" raster:%d edb_access.i:decode_raster(%d). Channel 2  Bad rxlen value (%d) i=%d\n", rasternbr, rxlen, wa, i;
         break;
      }

      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,2))) break;
      rx(,2) = rxr;  // get first waveform
      wa += rxlen;
      rxlen = i16(r,wa); wa += 2;

      if(rxlen <= 0) {
         write, format=" raster:%d edb_access.i:decode_raster(%d). Channel 3  Bad rxlen value (%d) i=%d\n",
            rasternbr, rxlen, wa, i ;
         break;
      }

      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,3))) break;
      rx(,3) = rxr;  // get first waveform
      return_raster.tx(i) = &txwf;
      return_raster.rx(i,1) = &rx(,1);
      return_raster.rx(i,2) = &rx(,2);
      return_raster.rx(i,3) = &rx(,3);
      return_raster.rx(i,4) = &rx(,4);
      return_raster.rxbias(i,) = rxb;
      /*****
        write,format="\n%d %d %d %d %d %d",
        i, offset_time, sa(i), irange(i), txlen , rxlen      */
   }
   return_raster.offset_time  = ((offset_time & 0x00ffffff)
                                 + fseconds) * 1.6e-6 + seconds;
   return_raster.irange    = irange;
   return_raster.sa        = sa;
   return_raster.digitizer = digitizer;
   return_raster.soe       = seconds;
   return_raster.rasternbr = rasternbr;
   return_raster.npixels   = npixels;
   return return_raster;
}
