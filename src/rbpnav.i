// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";
/*
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

plmk_default,msize=.1
pldefault,marks=0

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
 ifn = select_file(path, pattern="\\.egg$");

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

func precision_warning(verbose) {
   extern silence_precision_warning;
   default, verbose, 1;
   if(! silence_precision_warning && verbose && _ytk ) {
      tkcmd, "tk_messageBox -icon warning -message { \
         The pnav file you have selected does not appear to be a precision \
         trajectory.  It should not be used in the production of final data \
         products or to assess accuracy of the system. \
      }";
   }
}


/* Per Nagle's suggestion, changed rbpnav() to load_pnav(), but without
 * the setting of gga.  Create a new rbpnav() that calls this, but then
 * sets gga, thus keeping the old functionality of rbpnav(), but adding
 * the ability to load a pnav without messing with gga.  2008-11-05 rwm
 */
func load_pnav (junk, fn=, verbose=) {
/* DOCUMENT load_pnav(fn=)

   This function read a "C" precision data file generated by
   B.J.'s Ashtech program(s).  The data are usually not produced
   with precision trajectories.  The file must already be in
   ybin format produced by the pnav2ybin.c program.
*/
extern pnav_filename; // so we can show which trajectory was used
extern data_path, gps_time_correction;
extern edb, soe_day_start;
default, verbose, 1;
 if ( !is_void( fn ) ) {
    ifn = fn;
    pnav_filename = ifn;
    ff = split_path( ifn, -1 );
    path = ff(1);
    if ( !strmatch(pnav_filename,"-p-") ) {
      precision_warning, verbose;
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
      precision_warning, verbose;
    }
 } else {
  write,format="data_path=%s\n",path
 ifn = select_file(path, pattern="\\.ybin$");
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
_read, idf, 4, pn;


// check for time roll-over, and correct it
  q = where( pn.sod(dif) < 0 );
  if ( numberof(q) ) {
    rng = q(1)+1:dimsof(pn.sod)(2);
    pn.sod(rng) += 86400;
    // correct soe_day_start if the tlds dont start until after midnight. -rwm
    if(!is_void(edb) && !is_void(soe_day_start)) {
      if ( (edb.seconds(0) - soe_day_start(1)) < pn.sod(1) ) {
         soe_day_start -= 86400;
         write, format="Correcting soe_day_start to %d\n", soe_day_start;
      }
    }
  }

  if(is_void(gps_time_correction))
    determine_gps_time_correction, ifn;
  pn.sod += gps_time_correction;
  
if(verbose) {
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
}
   return pn;
}



func rbpnav (junk, fn=, verbose=) {
  extern gga;
  pn = load_pnav(junk, fn=fn, verbose=verbose);
// assign new pnav array to gga even if gga is already set.
 // if ( is_void( gga ) ) {
    gga = pn;
 //   write,"**Note: Created gga from pnav"
 // }

 return pn;
}

func load_pnav2FS(junk, ifn=) {
  extern gt_pnav;
  extern pnav_filename;

  gt_pnav = load_pnav(junk, fn=ifn);

  if ( is_void(ifn) ) {
    ifn = pnav_filename;
  }

  myfn = file_tail(ifn);     // get the actual filename

  yr = atoi(strpart(myfn, 1:4) );   // strip out the date
  mo = atoi(strpart(myfn, 6:7) );
  dy = atoi(strpart(myfn, 9:10));

  soe = ymd2soe(yr, mo, dy, gt_pnav.sod);
  // soe = gt_pnav.sod;
  fs = pnav2fs(gt_pnav, soe=soe);

  return fs;
}

func autoselect_pnav(dir) {
/* DOCUMENT pnav_file = autoselect_pnav(dir)

   This function attempts to determine an appropriate pnav file to load for a
   dataset.

   The dir parameter should be either the path to the mission day or the path
   to the mission day's trajectories subdirectory.

   The function will find all *-pnav.ybin files underneath the trajectories
   directory. If there are more than one, then it selects based on what kind of
   file it is with the following priorities (high to low): *-p-*, *-b-*, *-r-*,
   and *-u-*. If there are still multiple matches, then it prefers
   *-cmb-pnav.ybin if present. If there are still multiple matches, it sorts
   them then returns the last one -- in many cases, this will result in the
   most recently created file being chosen.

   If no matches are found, [] is returned.

   This function is not guaranteed to return the best or most appropriate pnav
   file. It is a convenience function that should only be used when you know
   it's safe to be used.
*/
// Original David Nagle 2009-01-21
   dir = file_join(dir);
   if(file_tail(dir) != "trajectories") {
      if(file_exists(file_join(dir, "trajectories"))) {
         dir = file_join(dir, "trajectories");
      }
   }
   candidates = find(dir, glob="*-pnav.ybin");
   if(!numberof(candidates)) return [];
   patterns = [
      "*-p-*-cmb-pnav.ybin",
      "*-p-*-pnav.ybin",
      "*-b-*-cmb-pnav.ybin",
      "*-b-*-pnav.ybin",
      "*-r-*-cmb-pnav.ybin",
      "*-r-*-pnav.ybin",
      "*-u-*-cmb-pnav.ybin",
      "*-u-*-pnav.ybin",
      "*-pnav.ybin"
   ];
   for(i = 1; i <= numberof(patterns); i++) {
      w = where(strglob(patterns(i), candidates));
      if(numberof(w)) {
         candidates = candidates(w);
         candidates = candidates(sort(candidates));
         return candidates(0);
      }
   }
   return [];
}

/*
  Convert a PNAV to FS.  Used when reading a ground truth
  gtpnav file and then displaying it with lidar data
  A check should probably be done to make sure curzone is set.
  The "Process EAARL Data" window must also be open or FS isn't
  available.
*/

func pnav2fs(pn, soe=) {
   extern curzone;
   local x, y;
   default, soe, pn.sod;
   ll2utm, pn.lat, pn.lon, y, x, force_zone=curzone;
   fs = array(FS, dimsof(pn));
   fs.east = x * 100;
   fs.north = y * 100;
   fs.elevation = pn.alt * 100;
   fs.soe = soe;
   return fs;
}

func fs2pnav(fs) {
   retarr = 1;

   N = numberof(fs);
   pn = array(PNAV, N);
   ll = utm2ll(fs.north/100., fs.east/100., curzone);
   if ( N > 1 ) {
      pn.lat = ll(,2);
      pn.lon = ll(,1);
   } else {
      pn.lat = ll(2,);
      pn.lon = ll(1,);
   }

   return(pn);
}
