/*
   $Id$
*/

require, "string.i"
require, "dir.i"
require, "sel_file.i"
require, "ytime.i"
require, "rlw.i"
require, "ytk.i"

 struct EAARL_INDEX {
   int seconds;
   int fseconds;
   int offset;
   int raster_length;
   short file_number;
   char  pixels;
   char  digitizer;
} ;

struct EDB_FILE {
  string name;
  char status;
};


struct RAST {
  int soe;                      // seconds of the epoch
  int rasternbr;                // raster number
  int digitizer;                // digitizer
  int npixels;                  // number of pixels actually in this raster
  int irange(120);              // integer range values
  int sa(120);                  // shaft angles
  double offset_time(120);      // fractional offset seconds
  int rxbias(120,4);            // receive waveform bias values
  pointer tx(120);              // transmit waveforms
  pointer rx(120,4);            // return waveforms
};



t0 = t1 = array(double,3)
_ecfidx = 0;

local edb_access
/* DOCUMENT edb_access.i

   Vars/Data Structures:
       EDB
       RAST
       EDB_FILE
       EDB_INDEX

   Functions/subroutines:
       load_edb, fn=
       get_erast( rn=, sod=, hms= )
       decode_raster(r)

*/

total_edb_records = 0;

if ( is_void( data_path) ) {
  data_path = "";
}


func get_total_edb_records(junk ) {
 extern total_edb_records,data_path
  if ( _ytk) {
	tkcmd,swrite(format="set total_edb_records %d\n", total_edb_records );
	tkcmd,swrite(format="set data_path  \"%s\" \n", data_path );
  }
  return total_edb_records;
}

func load_edb (  fn=, update= ) {
/* DOCUMENT load_edb, fn=

  This function reads the index file produced by the
  efdb program.  The data is a type of cross-reference
  to an entire EAARL data set. This permits easy access
  to the data without regard to what file the data are
  located in.
  
  Two variables are created by this load_edb: edb and
  edb_file.  edb is an array of structures of type
  EDB, and edb_file is an array of structures containing
  the cross-referenced file names and the file status.  
  To see whats in the edb structure, type EDB.  This will 
  list the definition.  To see some actual edb data, type 
  edb(N) where N is the record number.
  
*/
 extern edb_filename, edb;
 extern edb_files, _ecfidx, _edb_fd;
 extern total_edb_records;
 extern data_path;
 extern soe_day_start;
 extern eaarl_time_offset;
 extern tans, pnav;
 _ecfidx = 0;

///// if ( is_void( data_path ) ) 

if (is_void(fn)) {
if ( _ytk ) {
    if (!fn) fn  = get_openfn( initialdir="/data/0/", filetype="*.idx" ); 
    if (strmatch(fn, "idx") == 0) {
       exit, "NO FILE CHOSEN, USING PREVIOUSLY DEFINED .idx FILE IF PRESENT";
    } 
    ff = split_path( fn, -1 );
    data_path = ff(1);
} else {
     data_path = get_dir(initialdir="/data/0/" );
 if ( !is_void( data_path) )
     tldpath = data_path + "/eaarl/";
 if ( is_void( fn ) ) {
     fn  = get_openfn( initialdir=tldpath, filetype="*.idx" );
 }
}
}

 filemode = "rb";
  if ( !is_void( update )  )
     if ( update == 1 ) 
	filemode = "r+b";

  _edb_fd = idf = open(fn, filemode );
  edb_filename = fn;			// 

// get the first three 32 bit integers from the file. They describe
// things in the file as follows:
// n(1) is the offset to the actual file names
// n(2) is the number of raster index records
// n(3) is the number of filenames indexed by this database
  n = array(int, 3);


 add_member, idf, "EDB", 0,  "seconds", int
 add_member, idf, "EDB", -1, "fseconds", int
 add_member, idf, "EDB", -1, "offset", int
 add_member, idf, "EDB", -1, "raster_length", int
 add_member, idf, "EDB", -1, "file_number", short
 add_member, idf, "EDB", -1, "pixels", char
 add_member, idf, "EDB", -1, "digitizer", char
 install_struct, idf, "EDB"

  _read(idf,0, n);
  write,format="\n%s contains %d records from %d files\n", fn, n(1), n(3)

  edb_files = array( EDB_FILE, n(3) );
  len = short(0);
  os = n(1);
  for (i=1; i<= n(3); i++ ) {
    _read,idf, os, len;		// get the string length
    os += 2;
    s = array( char, len);
    _read,idf, os, s;
//    edb_files(i).name = data_path + string( &s );		// convert char array to string
    edb_files(i).name = string( &s );		// convert char array to string
    os += len
  }

  edb = array( EDB, n(2) ); 
  _read(idf, 12, edb);



/*
   eaarl_time_offset is computed below.  It needs to be added to any soe values 
 read from the waveform database.  It is computed below by subtracting the time 
 found in the first raster from the time in the first record of  edb.  This works
 because after we determine the time offset, we correct the edb and write out
 a new version of the idx file.  This makes the idx file differ from times in 
 the waveform data base by eaarl_time_offset seconds.  If you read in an idx
 file which hasn't been time corrected, the eaarl_time_offset will become 0
 because there will be no difference in the time values in edb and the waveform
 database.

 The eaarl_time_offset can be safely used from decode_raster to correct time
 valuse as the rasters are read in.
 */
 eaarl_time_offset = 0;	// need this first, cuz get_erast uses it.
 eaarl_time_offset = edb(1).seconds - decode_raster( get_erast(rn=1) ).soe;



// locate the first time value that appears to be set to the gps
  q = where( edb.seconds > time2soe( [2000,0,0,0,0,0] )) ;

// If valid soe time then do this.
 if ( numberof(q) > 0 ) {
  write,"*****  TIME contains date information ********"
//////  edb.seconds += eaarl_time_offset ;	// adjust time to gps
   data_begins = q(1);
   data_ends   = q(0);
   year = soe2time( edb(data_begins).seconds ) (1);
   day  = soe2time( edb(data_begins).seconds ) (2);
   soe_start = 0;
   soe_stop  = 0;
   soe_start = edb(data_begins).seconds;
   soe_stop  = edb(data_ends).seconds;
// change the time record to seconds of the day
//   edb.seconds -= time2soe( [ year, day, 0, 0,0,0 ] );
   soe_day_start = time2soe( [ year, day, 0, 0,0,0 ] ); 
   mission_duration = ( edb.seconds(q(0)) - edb.seconds(q(1)))/ 3600.0 ;
 } else {
   soe_day_start = 0;
   data_begins = 1;
   data_ends   = 0;
   soe_start = edb(data_begins).seconds;
   soe_stop  = edb(data_ends).seconds;
   year = 0;
   day  = 0;
   mission_duration = (edb.seconds(0) - edb.seconds(1)) / 3600.0 ;
 }


// convert to time/date
  soe2time( soe_start );
  soe2time( soe_stop );

  write,format="  Database contains: %6.3f GB across %d files.\n", 
         float(edb.raster_length)(sum)*1.0e-9, n(3)
  write,format="          Year, day: %d, %d\n", year, day
  write,format="   SOE at day start: %d\n", soe_day_start
  write,format="       First record: %d (first valid time)\n", data_begins
  write,format="        Last record: %d\n", data_ends
  write,format="       Data_path is: %s\n", data_path
  write,format="   Mission duration: %f hours\n", mission_duration
  write,format="\nYou now have edb and edb_files\n\
    variables.  Type info,EDB to see the structure of edb.%s\n\
  Try: rn = 1000;   rp = get_erast(rn = rn ); fma; drast(rp); rn +=1\n\
   to see a raster\n","\n"
  if ( !is_void(update) ) 
    write,"******NOTE: The file(s) are open for updating\n"


  total_edb_records = numberof(edb);
/* if we're using ytk, then set a var over in tcl to indicate the total
 number of records and the data path. */
 if ( _ytk ) {
	get_total_edb_records;
    tkcmd,swrite(format="set edb(gb) %6.3f\n", 
          float(edb.raster_length)(sum)*1.0e-9);
    tkcmd,swrite(format="set edb(number_of_files) %d", n(3) );
    tkcmd,swrite(format="set edb(year) %d", year);
    tkcmd,swrite(format="set edb(day)  %d",  day);
    tkcmd,swrite(format="set edb(data_begins)  %d",  data_begins);
    tkcmd,swrite(format="set edb(data_ends)    %d",  data_ends);
    tkcmd,swrite(format="set edb(mission_duration)  %f",  mission_duration);
    tkcmd,swrite(format="set edb(soe)  %d",  soe_day_start);
    tkcmd,swrite(format="set edb(eaarl_time_offset)  %d",  eaarl_time_offset);
    tkcmd,swrite(format="set edb(path)  %s",  data_path);
    tkcmd,swrite(format="set edb(idx_file)  %s",  fn);
    tkcmd,swrite(format="set edb(nbr_rasters)  %d",  numberof(edb) );
 }
 /* adding time correct array (tca) function */
 time_correct, data_path;
 write,"load_edb_completed\r";
 pnav = [];
 tans = [];
}


func edb_update ( time_correction ) {
/* DOCUMENT edb_update
   
  Writes the memory version of edb back into the file.  Used to correct time
  of day problems.


*/
 extern _edb_fd
 extern edb
  if ( (!is_void( _edb_fd ))  && (!is_void(edb))  ) {
     edb.seconds += time_correction;
     _write(_edb_fd, 12, edb);
     write,"edb updated"
  }
}



func get_erast( rn=, sod=, hms=, timeonly= ) {
/* DOCUMENT get_erast( rn=, sod=, hms= ) 
   
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
 extern data_path, edb, edb_files, _eidf, _ecfidx;
 extern soe_day_start;


 if ( is_void( rn ) ) {
   if ( !is_void( sod ) ) {
       rn = where( edb.seconds == sod );
 rn
   } else if ( !is_void( hms ) ) {
     sod = hms2sod( hms );
     rn = where( edb.seconds == sod );
 rn 
   }
   // just use the first record with this value
   if ( numberof(rn) > 1 ) 
	rn = rn(1); 
 }

 fidx = edb(rn).file_number;

// If the currently open file is the same as the same as the
// one the requested raster is in, then we use it else we
// change to the new file.
 if ( _ecfidx != fidx ) {
   _ecfidx = fidx;
   i = strchr( edb_files( fidx ).name, '/', last=1);   // strip out filename only
   fn = strpart( edb_files( fidx ).name, i+1:0 );

   if ( is_void(timeonly) ) 
        omode = "rb";
   else 
        omode = "r+b";

   _eidf = open( data_path+"/eaarl/"+fn, omode );    
 }

// _eidf now should point to our file
 
 if ( is_void( timeonly ) ) { 
   rast = array( char, edb(rn).raster_length);
   _read,_eidf, edb(rn).offset, rast
 } else {
   rast = array( char, 16 );
   _read,_eidf, edb(rn).offset, rast
 }
 return rast
}


func decode_raster( r ) {
/* DOCUMENT decode_raster(r)
   Inputs: 	r      ; r is an edb raster data variable
   Returns:     
     decode_raster returns a RAST array of data.  

Type RAST to see whats in the RAST structure.

Usage: 
  r = get_erast(rn = rn );	// get a raster from the database
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
 extern t0,t1
 extern eaarl_time_offset, tca; 
  timer,t0
  return_raster = array(RAST,1);
  irange = array(int, 120);
  sa     = array(int, 120);
  offset_time = array(int, 120);
  len = i24(r, 1);      		// raster length
  type= r(4);           		// raster type id (should be 5 )
  if ( len < 20  )			// return empty raster.  System must have 
	return return_raster;		// failed.

  seconds = i32(r, 5);  		// raster seconds of the day
  seconds += eaarl_time_offset;		// correct for time set errors.
  

  fseconds = i32(r, 9); 		// raster fractional seconds 1.6us lsb
  rasternbr = i32(r, 13); 		// raster number
  npixels   = i16(r, 17)&0x7fff;        // number of pixels
  digitizer = (i16(r,17)>>15)&0x1;      // digitizer                          
  a = 19;        			// byte starting point for waveform data
  if (rasternbr < 0) return return_raster;
  if (fseconds < 0) return return_raster;
  if (npixels < 0) return return_raster;
  if (seconds(1) < 0) return return_raster;
  if ((!is_void(tca)) && (numberof(tca) > rasternbr) ) { 
     seconds = seconds+tca(rasternbr);
  }
//write, format= "rasternbr = %d, seconds = %d\n", rasternbr, seconds;
 for (i=1; i<=npixels-1; i++ ) {	// loop thru entire set of pixels
   offset_time(i) = i32(r, a);   a+= 4;	// fractional time of day since gps 1hz
       txb = r(a);      a++;		// transmit bias value
       rxb = r(a:a+3);  a+=4;		// waveform bias array
       sa(i)  = i16(r, a); a+=2;	// shaft angle values
    irange(i) = i16(r, a); a+=2;	// integer NS range value
      plen = i16(r, a); a+=2;
        wa = a;                 	// starting waveform index (wa)
         a = a + plen;			// use plen to skip to next pulse
    txlen = r(wa); wa++;		// transmit len is 8 bits max
    txwf = r(wa:wa+txlen-1);		// get the transmit waveform
    wa += txlen;			// update waveform addres to first rx waveform
    rxlen = i16(r,wa); wa += 2;		// get the 1st waveform and update wa to next
    if ( rxlen <= 0 ) { 
       write, format="*** edb_access.i:decode_raster(%d). Channel 1  Bad rxlen value (%d) i=%d\n", 
              rxlen, wa, i ;
       break;		
    }
    rx = array(char, rxlen, 4);	// get all four return waveform bias values
    rx(,1) = r(wa: wa + rxlen-1 );	// get first waveform
    wa += rxlen;			// update wa pointer to next
    rxlen = i16(r,wa); wa += 2;
    if (rxlen <=0) {
       write, format="*** edb_access.i:decode_raster(%d)  Channel 2. Bad rxlen value (%d) i=%d\n", 
              rxlen, wa, i ;
       break;
    }
    rx(,2) = r(wa: wa + rxlen-1 );
    wa += rxlen;
    rxlen = i16(r,wa); wa += 2;
    if (rxlen <=0) {
       write, format="*** edb_access.i:decode_raster(%d)  Channel 3. Bad rxlen value (%d) i=%d\n", 
              rxlen, wa, i ;
       break;
    }
    rx(,3) = r(wa: wa + rxlen-1 );
   return_raster.tx(i) = &txwf;
   return_raster.rx(i,1) = &rx(,1);
   return_raster.rx(i,2) = &rx(,2);
   return_raster.rx(i,3) = &rx(,3);
   return_raster.rx(i,4) = &rx(,4);
   return_raster.rxbias(i,) = rxb;
/*****
    write,format="\n%d %d %d %d %d %d",
        i, offset_time, sa(i), irange(i), txlen , rxlen		 */
}                                                   
 return_raster.offset_time  = ((offset_time & 0x00ffffff) 
                              + fseconds) * 1.6e-6 + seconds;
 return_raster.irange    = irange;
 return_raster.sa        = sa;
 return_raster.digitizer = digitizer;
 return_raster.soe       = seconds;
 return_raster.rasternbr = rasternbr;
 return_raster.npixels   = npixels;
 timer,t1
 return return_raster;
}



pldefault,marks=0
write,"$Id$"

