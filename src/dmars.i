
/*

  $Id$

  Original: W. Wright

  Read a raw dmars dataset produced by dmarsd.c

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

   Loads a DMARS IEX generic IMU format file.  The data file is generate
by the dmars2iex.c program.  To load the raw DMARS data file (as generated
by the dmarsd.c data capture program) use the load_raw_dmars function.

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

func iex2tans( junk ) {
/* DOCUMENT iex2tans

  Convert an iex_nav variable to a tans variable.  This procedure:
 1) Creates a tans structure.  If it exists, it overwrites it.
 2) Fills it with iex_data
 3) Adjusts the iex_time from gps to utc
*/
 extern tans, iex_nav;
 tans = array( IEX_ATTITUDE, dimsof(iex_nav)(2));
 tans.somd   = iex_nav.somd;
 tans.roll   = iex_nav.roll;
 tans.pitch  = iex_nav.pitch;
 tans.heading= iex_nav.heading;
 tans.somd  %= 86400;
 tans.somd  -= 13.0;
}

func iex_ascii2pbd( fn ) {
/* DOCUMENT load_iex,fn

  fn is the filename containing 7 column ascii records generated by the
 iex program.  This function reads the ascii records, and saves them as
 an array of IEX_ATTITUDE structures in a pbd file.

 The IMU data undergoes the following processing:

 dmarsd -> *.bin -> 
                  dmars2iex.c -> *.imu -> 
                                      Iex -> *.ascii -> 
                                                      iex_ascii2pbd -> *.pbd

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
 iex_head=rdline(f, 16);
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






