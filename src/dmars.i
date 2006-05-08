
extern dmars_i
/* DOCUMENT dmars_i

  $Id$

  Original: W. Wright

  The DMARS (Digital Miniature Attitude Reference System) is a set of 
three spinning mass "dynamically tuned" gyros and a set of three high 
accuracy precision accelerometers.  There is one gyro and one 
accelerometer for each axis, X Y and Z.  

The gyros put out rotation rates for each axis, not the actual attitude. 
In other words they put out how fast the pitch, roll, and yaw are changing.  
The accelerometers output the acceleration along each axis.  Measurements 
are taken and output every five miliseconds (0.005 seconds) which is 200 
Hertz.  Every sample is locked to GPS time of day by way of a 1-Hz 
electronic signal delivered from a precision GPS receiver to the DMARS IMU.  

Extreme care must be taken to insure the DMARS is properly synchronized 
with the GPS time and to minimize the number corrupt records. 

The EAARL DMARS datasystem consists of two single board Linux systems 
interfaced to the DMARS via a 115kbaud asynchronous 8 bit rs-232 serial 
connection. One datasystem captures DMARS data simultaneous with NTP 
(Network Time Protocol) data and records the result in a compressed file.  
The second system captures the same data stream using the builtin Linux 
command "cat."  The "cat" file has no time information at all and is 
intended as a backup in the even that the NTP based system fails for 
some reason. 

 POST PROCESSING
  
Normally, only the NTP DMARS files need to be processed.  The "cat" 
files only need to be processed if there were problems in the NTP system.  
Problems in the NTP system are indicated by time gaps larger then 20-30ms 
as indicated by reading the data file with rdmars.c as follows:
  

The normal NTP based IMU data undergoes the following processing:


 dmarsd -> *.bin -> 
                 rdmars.c
                 dmars2iex.c -> *.imu -> 
                                      Iex -> *INS.txt -> 
                                                      iex_ascii2pbd -> *.pbd

Dmarsd is run during the flight mission to capture the NTP based data 
(*.bin).  Postprocessing begins by running rdmars and simply viewing the 
output and visually scanning for time gaps greater than 20-30ms. Problematic 
data are typically indicated by gaps of several seconds.  If no larger gaps 
are seen, then the dmars2iex "C" program is run which generates a *.imu file.
If you detected gaps then see the section below "PROCESSING CAT FILES". The 
*.imu file mus then be transferred to the Windows based Grafnav Inertial 
Explorer (IEX) program where it will be combined with the GPS data to produce 
an ASCII INS.txt file.  The ASCII INS.txt file is transferred back into your 
linux system and converted to a Yorick *.pbd file using the ALPS Yorick 
function iex_ascii2pbd found in dmars.i.

  Read a dmars dataset produced by dmarsd.c


  PROCESSING CAT FILES

The critical piece of data you need to process "cat" data is the delta time
from the DMARS unit's "tspo" (Time Since Power On) value to the actual GPS
time of day when the data was captured.  The easiest way to get that 
information is to run the dmars2iex program on the DMARS file which contains 
the NTP time stamps.  The program will printout the time difference between 
the IMU and NTP.  Even though the NTP file will contain the problematic data 
gaps, it will also generate the correct time difference you will need to 
process the "cat" data. 
  
Below is an example of how to run dmars2iex to find the time difference.
 
3:15 <129>% dmars2iex junk.bin
$Id$
Pass 1...
------------------------------------------------------------------
    Header: $IMURAW             Version: 2.000     Byte Order: Intel
DeltaTheta: 0            Delta Velocity: 0          Data Rate: 200Hz
Gyro Scale: 2.746582e-03    Accel Scale: 5.981445e-04    Time: GPS
 Time Corr: 2                 Time Bias: 13.000    Total Recs: 4734112
 Start SOW: 58522.000          Stop SOW: 82192.000
  Duration: 23670.0/secs (6.575/hrs)
------------------------------------------------------------------
 
23671 Time recs, 4734112 DMARS recs
sizeof(hdr)=512
 sizeof(IEX_RECORD)=32, gscale=0.002747 ascale=0.000598
2004-02-13 Day:5  22:39:53
GPS Seconds of the week time offset: 490519 seconds

 The "GPS Seconds of the week time offset" of 490519 is the number
you will need to correctly process the DMARS "cat" file. An example 
run is shown below.  The input file is some-cat.bin and the output
is some-cat.imu.  The time offset is 490519.  The diagonostic 
printout shows the some limited information at records that have
checksum errors. The Recs column shows the record number where
the checksum error occured, the "Bad Recs" simply counts the number
of bad records, the "lgt" is the "last good time" record, and
the "ct" is the current time of the record.

dmarscat2iex -t 490519 -d some-cat.bin -o some-cat.imu
                 Recs  Bad Recs      lgt      ct
Bad Checksum:    13932        1   71.995   72.000
Bad Checksum:    25133        2  127.995  128.000
Bad Checksum:   123534        3  619.995  620.000
Bad Checksum:   232535        4 1164.995 1165.000
Bad Checksum:   253536        5 1269.995 1270.000
Bad Checksum:   253537        6 1269.995 505944.370
Bad Checksum:   271138        7 1357.995 1358.000
------------------------------------------------------------------
    Header: $IMURAW             Version: 2.000     Byte Order: Intel
DeltaTheta: 0            Delta Velocity: 0          Data Rate: 200Hz
Gyro Scale: 2.746582e-03    Accel Scale: 5.981445e-04    Time: GPS
 Time Corr: 2                 Time Bias: 13.000    Total Recs: 4736419
 Start SOW: 490521.345          Stop SOW: 514203.485
  Duration: 23682.1/secs (6.578/hrs)
------------------------------------------------------------------
 4730000 Records processed
4736419 Total records processed

Once the .imu file is generated, it can be sent processed by
the Windows IEX program which will produce a .INS file containing
pitch/roll/heading and other information.
 
  
*/ 


 G = 9.80665;
 gs = 90.0/double(2^15); 
 as = (19.6/double(2^15)); 


/*
   The sensor array is as follows:

    1     X gyro
    2     Y Gyro
    3     Z Gyro
    4     X Accel
    5     Y Accel
    6     Z Acces ( this one is very close to gravity)
*/ 



struct IEX {
  double sow;
  int  sensors(6);
};

 struct RAW_DMARS_IMU {
   int tspo;		// time since power on
   char status;		// status byte
   short sensor(6);	// IMU sensor data
 };


/*
   This data is in engineering units of degrees/second
   and "G".
*/
struct ENGR_DMARS {
  double soe;
  float sensor(6);
};


write,"$Id$"

// This is designed to be driven by ytk.
func load_iexpbd( fn ) {
  extern _ytk_pbd_f, iex_nav1hz, gps_time_offset,
        tans,
        iex_head,
        iex_nav, iex_nav1hz,
        ops_conf,
        ops_IMU2_default;
  _ytk_pbd_f = openb(fn)
  restore, _ytk_pbd_f;
  show, _ytk_pbd_f;
  iex2tans;
  ops_conf = ops_IMU2_default;
  gen_cir_nav( 0 );
  write, "Using default DMARS mounting bias and lever arms.(ops_IMU2_default)"
}


func gen_cir_nav( msoffset ) {
  extern iex_nav, iex_nav1hz;
  if ( is_void( iex_nav) ) return -8;
  iticks = int(msoffset/5.0);
  startIndex = where( (iex_nav(1:200).somd % 1) == 0.0 )(1);
  startIndex += iticks;
  tmp = iex_nav(startIndex:0:200);	
  tmp.somd = tmp.somd % 86400;
  utmx = fll2utm(tmp.lat, tmp.lon);
  iex_nav1hz = array(IEX_ATTITUDEUTM, dimsof(utmx)(3));
  iex_nav1hz.somd = tmp.somd + gps_time_correction;
  iex_nav1hz.lat = tmp.lat;
  iex_nav1hz.lon = tmp.lon;
  iex_nav1hz.alt = tmp.alt;
  iex_nav1hz.roll = tmp.roll;
  iex_nav1hz.pitch = tmp.pitch;
  iex_nav1hz.heading = tmp.heading;
  iex_nav1hz.northing = utmx(1,);
  iex_nav1hz.easting = utmx(2,);
  iex_nav1hz.zone = utmx(3,);
  write, format="%d %d %20.6f\n", startIndex, iticks, iex_nav(startIndex).somd
  return 1;
}


func load_raw_dmars(fn=) {
// extern engr_dmars;
 extern dmars_ntptime;
 extern stime;
 extern tdiff;
 bsz = 400000;		// nominal buffer size for reading

// Create a "buffer" array to load values to
 raw = array(RAW_DMARS_IMU,bsz);

// Create one for the dmars_ntptime values also.
 systime = array( int, 3, bsz );
 stime = []; 

 t = char();	// type is either 0x7d or 0x7e
 f = open(fn, "rb");
 p = 0;
 i = 1;		// index for dmars data
 j = 1; 	// index for system time
 total_dmars = 0;
 total_time  = 0;
 loop = 1;
 tspo = int();
 status = char();
 sensor = array(short,6);
 dmars = RAW_DMARS_IMU();
 la = array(int,2);

 if ( catch ( 0x02 ))  {
     grow, stime, systime(,1:j);
     grow, dmars, raw(1:i);
     loop = 0;
 }

 if ( loop ) {
   write,"\n"
   write," Hours        Time    raw_dmars"
   write,"Processed  Difference    Size"
 }
 while (loop) {
   if ( _read(f, p, t ) > 0 ) {
     p++;
     if ( t == 0x7d ) {   // system time
       n = _read( f, p, la ); 
       systime(1:2,j) = la;
       systime(3,j) = tspo;
       if ( total_time == 0 ) {
         start = systime(1,j);
       }
       p+= 8;
       j++;
       total_time++;
       if ( j > bsz ) {
         grow, stime, systime;
         j = 1;
       }

       if ( (systime(1,j-1) % 100) == 0 ) 
          write,format="   %4.3f      %6.6f   %4.3fmb\r", 
                 (systime(1,j-1)-start)/3600.0, 
                 systime(2,j-1)*1.0e-6,
                 (sizeof( dmars ) + sizeof(raw(1:i)))/1.0e6;

     } else if ( t == 0x7e ) { // dmars record
       total_dmars++;
       n = _read( f, p, tspo);    p += 4;
       n = _read( f, p, status);  p += 1; 
       n = _read( f, p, sensor);  p += 12; 
       p +=1;   // skip checksum
       raw.tspo(i) = tspo;
       raw.status(i) = status;
       raw(i).sensor = sensor;
       i++;
       if ( i > bsz ) {
          grow, dmars, raw;
          i = 1;
       }
     }
   } else  { 
     grow, stime, systime;
     grow, dmars, raw(1:i);
     loop = 0;
     write, format="\ndmars:%d Time:%d\n", total_dmars, total_time;
   }

 }
 write,"\n\n"
 write,format="\nTotal Recs; DMARS::%d SYSTIME:%d\n", total_dmars, total_time
 write,format="Computed GMT time diff is: %d secs\n", tdiff
 dmars_ntptime = stime(1,) + stime(2,)*1.0e-6;
 tdiff = stime(1,-1000) - stime(3,-1000)/200.0;
 tdiff = int(tdiff);
 return dmars;
}


func convert_raw_dmars_2_engr(dmars) {
//  extern engr_dmars;
  write,"Converting to engineering units..."
 engr_dmars = array(ENGR_DMARS, numberof( dmars )  );

// Convert the DMARS tspo (Time Since Power On) to GMT
// using a time defference determined from near the end of the 
// data set.  
 engr_dmars.soe = dmars.tspo/200.0 + tdiff;
 for (i=1, j=4; i<=3; i++,j++ ) {
   engr_dmars.sensor(i,) = dmars.sensor(i,) * gs;
   engr_dmars.sensor(j,) = dmars.sensor(j,) * as;
 }
 return engr_dmars;
}



func plot_z( junk ) {
r = 1:-1
window,0
fma
limits,,,-5,5
plg, dmars.sensor(6,1000:-1), 
     dmars.soe(1000:-1) 
plg, dmars_ntptime(r) - (stime(3,r)/200.0+tdiff), 
      dmars_ntptime(r), 
      color="red", 
      width=6.0
}


// fn = "/data/6/2003/asis/12-18-03/dmars/121803133617-dmars.bin";
//  dmars = convert_raw_dmars_2_engr(load_raw_dmars(fn=fn));


fn = "/data/6/2003/asis/12-18-03/dmars/121803133617-dmars.imu"

struct IEX_HEADER {
  char   szheader(8);
  char   bisintelormotorola(1);
  double dversionnumber;
  int    bdeltatheta;
  int    bdeltavelocity;
  double ddatarate;
  double dgyroscalefactor;
  double daccelscalefactor;
  int    iutcorgpstime;
  int    ircvtimeorcorrtime;
  double dtimetagbias;
  char   reserved(443);
  int    nrecs;
};

func load_iex( fn ) {
/* DOCUMENT load_iex, fn

   Loads a DMARS IEX generic IMU format file.  The data file is 
generate by the dmars2iex.c program.  To load the raw DMARS data 
file (as generated by the dmarsd.c data capture program) use the 
load_raw_dmars function.

 See also: load_raw_dmars, convert_raw_dmars_2_engr

*/
 extern iex_header;
 extern iex;
  iex_header = IEX_HEADER();
  nrecs = int();
  if ( catch(0x02) ) {
    write,format="Unable to open %s\n", fn
    return;
  }
  f = open(fn, "rb"); 
  
  data_align, f, 1
  struct_align, f, 1
  add_member, f, "IEX_HEADER",   0, "szheader",     char, 8
  add_member, f, "IEX_HEADER",   8, "bisintelormotorola",char
  add_member, f, "IEX_HEADER",   9, "dversionnumber", double, 1
  add_member, f, "IEX_HEADER",  17, "bdeltatheta", int, 1
  add_member, f, "IEX_HEADER",  21, "bdeltavelocity", int, 1
  add_member, f, "IEX_HEADER",  25, "ddataratehz", double, 1
  add_member, f, "IEX_HEADER",  33, "dgyroscalefactor", double, 1
  add_member, f, "IEX_HEADER",  41, "dacellscalefactor", double, 1
  add_member, f, "IEX_HEADER",  49, "iutcorgpstime", int, 1
  add_member, f, "IEX_HEADER",  53, "ircvtimeorcorrtime", int, 1
  add_member, f, "IEX_HEADER",  57, "dtimetagbias", double, 1
  add_member, f, "IEX_HEADER",  65, "reserved",     char, 443
  add_member, f, "IEX_HEADER", 508, "nrecs",     int, 1
  install_struct, f, "IEX_HEADER"
  _read, f, 0, iex_header;
  write,format="Loading %d records. This may take a few seconds....", 
  iex_header.nrecs


  add_member, f, "IEX",  0, "sow",     double
  add_member, f, "IEX", -1, "sensors", int, 6
  install_struct, f, "IEX"
  iex = array( IEX, iex_header.nrecs); 
  _read,f, 512, iex;
  write,"All done."


  bsow = iex.sow(1);
  esow = iex.sow(0);
  if ( iex_header.bisintelormotorola(1) ) 
     s = "Motorola";
  else 
     s = "Intel";
  write,
  "------------------------------------------------------------------"
  write, 
  format="    Header: %s             Version:%6.3f     Byte Order: %s\n", 
      string(&iex_header.szheader), 
      iex_header.dversionnumber,
      s
  write, 
  format="DeltaTheta:%2d            Delta Velocity:%2d          Data Rate: %3.0f \n", 
      iex_header.bdeltatheta,
      iex_header.bdeltavelocity,
      iex_header.ddatarate
  if ( iex_header.iutcorgpstime(1) ) 
     s = "GPS";
  else 
     s = "UTC";
  write, 
  format="Gyro Scale: %8.6e    Accel Scale: %8.6e    Time: %s\n", 
      iex_header.dgyroscalefactor,
      iex_header.daccelscalefactor,
      s
  write, 
  format=" Time Corr: %1d                 Time Bias: %4.3f     Total Recs: %7d\n", 
      iex_header.ircvtimeorcorrtime,
      iex_header.dtimetagbias,
      iex_header.nrecs
  write,
  format=" Start SOW: %9.3f         Stop SOW: %9.3f\n", bsow, esow
  write,
  format="  Duration: %6.1f/secs (%4.3f/hrs)\n", 
       esow-bsow, 
       (esow-bsow)/3600.0;
  write,
  "------------------------------------------------------------------"
  write,format="Variable \"iex\", %dmb, is ready\n", int(sizeof(iex)/1e6)
}

fn = "/data/6/2003/asis/12-18-03/dmars/121803133617-dmars-eaarliex-x146y51z48.ascii"


 struct IEX_ATTITUDE {
  double somd   
  double lat
  double lon
  float  alt
  float  roll
  float  pitch
  float  heading
};


 struct IEX_ATTITUDEUTM {
  double somd   
  double lat
  double lon
  double northing
  double easting
  double zone
  float  alt
  float  roll
  float  pitch
  float  heading
};

func iex2tans( junk ) {
/* DOCUMENT iex2tans

  Convert an iex_nav variable to a tans variable.  This procedure:
 1) Creates a tans structure.  If it exists, it overwrites it.
 2) Fills it with iex_data
 3) Adjusts the iex_time from gps to utc
*/
 extern tans, iex_nav, gps_time_correction;
 day_start = int(iex_nav.somd(1) / 86400) * 86400; 
 tans = array( IEX_ATTITUDE, dimsof(iex_nav)(2));
 tans.somd   = iex_nav.somd;
 tans.roll   = iex_nav.roll;
 tans.pitch  = iex_nav.pitch;
 tans.heading= iex_nav.heading;
 tans.somd  =  iex_nav.somd - day_start;
 tans.somd  += gps_time_correction;
}

if ( is_void( gps_time_correction) ) gps_time_correction = -13.0

func iex_ascii2pbd( fn ) {
/* DOCUMENT load_iex,fn

  fn is the filename containing 7 column ascii records generated by the
 iex program.  This function reads the ascii records, and saves them as
 an array of IEX_ATTITUDE structures in a pbd file.


 Original: W. Wright 12/27/2003

*/


 extern temp;
 extern iex_nav;
 BSZ = 100000;
 iex_nav = [];
 iex_temp = array(IEX_ATTITUDE, BSZ);
 temp = array(double, 7, BSZ);
 i = 0;
 ofn = strtok(fn, ".")(1) + ".pbd";
 f = open(fn);
 of = createb(ofn);
 iex_head=rdline(f, 24);
 write,iex_head
 write,"\n"
 while ( (n = read(f,format="%lf", temp )) == 7*BSZ ) {
   i++;
   write,format="  Processing %d\r", i
   iex_temp.somd    = temp(1,);
   iex_temp.lat     = temp(2,);
   iex_temp.lon     = temp(3,);
   iex_temp.alt     = temp(4,);
   iex_temp.roll    = temp(5,);
   iex_temp.pitch   = temp(6,);
   iex_temp.heading = temp(7,);
   grow,iex_nav, iex_temp;
 };
 iex_temp.somd    = temp(1,);
 iex_temp.lat     = temp(2,);
 iex_temp.lon     = temp(3,);
 iex_temp.alt     = temp(4,);
 iex_temp.roll    = temp(5,);
 iex_temp.pitch   = temp(6,);
 iex_temp.heading = temp(7,);
 grow, iex_nav, iex_temp(1:n/7);
 write,"\n"
 info, iex_nav
 save,of,iex_head,iex_nav
 write,format="Created: %s\n", ofn 
 close,of
}






