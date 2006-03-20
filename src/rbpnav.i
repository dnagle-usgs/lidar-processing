/*
  rbpnav.i

  $Id$ 

History:
    9/20/02  -ww Fixed problem where data_path was being overwritten
             when the pnav file was not located in "gps".
    1/21/02  Added automatic correction for gps time.
   11/17/01  Added raeggnav function to read precision gps
             data files generated by John Sonntag and Chreston.
   11/13/01  Modified to check/correct midnight rollover. -WW
  
  This program reads a binary file of precision GPS data generated by
  the pnav2ybin.c program.  The input data file begines with a single
  32 bit integer which contains the number of pnav sample points following
  it in the file.  The points which follow are binary values in the 
  following structure: 

 struct PNAV {
   short sv;
   short flag;
   float sod;
   float pdop;
   float alt;
   float xrms;
   float veast;
   float vnorth;
   float vup; 
   double lat;
   double lon;
};


*/

 struct PNAV {
   short sv;
   short flag;
   float sod;
   float pdop;
   //float hdop;		// egg data only
   float alt;
   float xrms;
   float veast;
   float vnorth;
   float vup; 
   double lat;
   double lon;
};


struct EGGNAV {
 short yr;
 short day;
 float sod;
 double lat;
 double lon;
 float alt;
 float pdop;
 float hdop;
}



require, "sel_file.i"
require, "ytime.i"
write,"$Id$"

plmk_default,msize=.1
pldefault,marks=0


if ( is_void( gps_time_correction ) )
  gps_time_correction = -13.0




func raeggnav (junk) {  
/* DOCUMENT raeggnav 
   Read ASCII EGG precision navigation file.  This reads nav trajectories
  produced by John Sonntag or Chreston Martin.

 The data are returned as an array of structures of the form:

struct EGGNAV {
 short yr;
 short day;
 float sod;
 double lat;
 double lon;
 float alt;
 float pdop;
 float hdop;
}


*/

   
 if ( is_void(data_path) ) {
 write,"Enter path:"
   data_path = rdline(prompt="Enter data path:");
 }

 path = data_path +"/gps/"
 ifn = sel_file(ss="*.egg", path=path)(1);

 n = int(0)
 idf = open( ifn);

// an array big enough to hold 24 hours at 10hz (76mb)
// ncol = 11;
 ncol = 14;
 tmp = array( double, ncol, 864000);
 write,"Reading........."
 s = rdline(idf);
 n = read(idf,format="%f", tmp) / ncol;
 egg = array( EGGNAV, n);
 egg.yr  = tmp(1,:n)
 egg.day = tmp(2,:n)
 egg.sod = tmp(3,:n)
 egg.lat = tmp(4,:n)
 egg.lon = tmp(5,:n) - 360.0;
 egg.alt = tmp(6,:n)
 egg.pdop = tmp(7,:n)
 egg.hdop = tmp(8,:n)
write,format="\n\n    File:%s\n", ifn
write,format="Contains:%d points\n", dimsof(egg)(2);
write,format="%s", 
              "               Min          Max\n"
write, format="  SOD:%14.3f %14.3f %6.2f hrs\n", egg.sod(min), egg.sod(max), 
	(egg.sod(max) -egg.sod(min))/ 3600.0
write, format=" Pdop:%14.3f %14.3f\n", egg.pdop(min), egg.pdop(max)
write, format="  Lat:%14.3f %14.3f\n", egg.lat(min), egg.lat(max)
write, format="  Lon:%14.3f %14.3f\n", egg.lon(min), egg.lon(max)
write, format="  Alt:%14.3f %14.3f\n", egg.alt(min), egg.alt(max)

 close,idf
 return egg;
}

func precision_warning {
      tkcmd, "tk_messageBox -icon warning -message { \
      The pnav file you have selected does not appear\
 to be a precision trajectory.\
  It should not be used in the \
 production of final data products\
 or to assess accuracy of the system. i\
      }"
}


func rbpnav (junk, fn=) {
/* DOCUMENT rbpnav()

   This function read a "C" precision data file generated by
   B.J.'s Ashtech program(s).  The data are usually not produced
   with precision trajectories.  The file must already be in
   ybin format produced by the pnav2ybin.c program.


*/
// extern pn;
extern pnav_filename;		// so we can show which trajectory was used
extern data_path, gps_time_correction
extern gga;
 if ( !is_void( fn ) ) {
    ifn = fn;
    pnav_filename = ifn;
    ff = split_path( ifn, -1 );
    path = ff(1);
    if ( !strmatch(pnav_filename,"-p-") ) {
      precision_warning;
    }
 } else {
 if ( is_void(data_path)  || data_path == "") {
 write,"Enter path:"
   data_path = rdline(prompt="Enter data path:");
   path = data_path;
 }

 if ( _ytk ) {
    // path = data_path + "/gps/"
    path = data_path + "/trajectories/"
    // path = data_path;
    tkcmd, "path_exists "+path
    // ifn  = get_openfn( initialdir=data_path, filetype="*pnav.ybin" );
    ifn  = get_openfn( initialdir=path, filetype="*pnav.ybin" );
    if (strmatch(ifn, "ybin") == 0) {
          exit, "NO FILE CHOSEN, PLEASE TRY AGAIN\r";
    }
    pnav_filename = ifn;
    ff = split_path( ifn, -1 );
    path = ff(1);
    //data_path = path;
    if ( !strmatch(pnav_filename,"-p-") ) {
      precision_warning;
    }
 } else {
  write,format="data_path=%s\n",path
 ifn = sel_file(ss="*.ybin", path=path)(1);
 }
}

n = int(0)
idf = open( ifn, "rb");

 add_member, idf, "PNAV", 0,  "sv",    short
 add_member, idf, "PNAV",-1,  "flag",  short
 add_member, idf, "PNAV",-1,  "sod",   float
 add_member, idf, "PNAV",-1,  "pdop",  float
 add_member, idf, "PNAV",-1,  "alt",   float
 add_member, idf, "PNAV",-1,  "xrms",   float
 add_member, idf, "PNAV",-1,  "veast", float
 add_member, idf, "PNAV",-1,  "vnorth",float
 add_member, idf, "PNAV",-1,  "vup",   float
 add_member, idf, "PNAV",-1,  "lat",   double
 add_member, idf, "PNAV",-1,  "lon",   double
 install_struct, idf, "PNAV"

// get the integer number of records
_read, idf,  0, n

///  pnav = array( double, 12, n);
pn   = array( PNAV, n);
_read(idf, 4, pn );


// check for time roll-over, and correct it
  q = where( pn.sod(dif) < 0 );
  if ( numberof(q) ) {
    rng = q(1)+1:dimsof(pn.sod)(2);
    pn.sod(rng) += 86400;
  }

  pn.sod += gps_time_correction;
  

gps_time_correction = float(gps_time_correction)
write,format="Applied GPS time correction of %f\n", gps_time_correction
write,format="%s", 
              "               Min          Max\n"
write, format="  SOW:%14.3f %14.3f %6.2f hrs\n", pn.sod(min), pn.sod(max), 
	(pn.sod(max) -pn.sod(min))/ 3600.0
write, format=" Pdop:%14.3f %14.3f\n", pn.pdop(min), pn.pdop(max)
write, format="  Lat:%14.3f %14.3f\n", pn.lat(min), pn.lat(max)
write, format="  Lon:%14.3f %14.3f\n", pn.lon(min), pn.lon(max)
write, format="  Alt:%14.3f %14.3f\n", pn.alt(min), pn.alt(max)
write, format="  Rms:%14.3f %14.3f\n", pn.xrms(min), pn.xrms(max)
  if ( is_void( gga ) ) {
    gga = pn;
    write,"**Note: Created gga from pnav"
  }

 return pn;
}



