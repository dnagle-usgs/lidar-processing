/*
   $Id$
   */
   write, "$Id$"

struct GEO {
     long rn;
     long north;
     long east;
     short sr2;
     long elevation;
     long mnorth;
     long meast;
     long melevation;
     short bottom_peak;
     short first_peak;
     long bath;
     short depth;
     double soe;
     }

struct FS {
     long rn;
     long mnorth;
     long meast;
     long melevation;
     long north;
     long east;
     long elevation;
     short intensity;
     double soe;
     }

struct VEG {
     long rn;
     long north;
     long east;
     long elevation;
     long mnorth;
     long meast;
     long melevation;
     short felv;
     short fint;
     short lelv;
     short lint;
     char nx;
     double soe;
     }

struct VEG_ {
     long rn;
     long north;
     long east;
     long elevation;
     long mnorth;
     long meast;
     long melevation;
     long felv;
     short fint;
     long lelv;
     short lint;
     char nx;
     double soe;
     }

struct VEG__ {
     long rn;
     long north;
     long east;
     long elevation;
     long mnorth;
     long meast;
     long melevation;
     long lnorth;
     long least;
     long lelv;
     short fint;
     short lint;
     char nx;
     double soe;
     }

func read_yfile (path, fname_arr=, initialdir=, searchstring=) {

/* DOCUMENT read_yfile(path, fname_arr=) 
This function reads an EAARL yorick-written binary file.
   amar nayegandhi 04/15/2002.
   Input parameters:
   path 	- Path name where the file(s) are located. Don't forget the '/' at the end of the path name.
   fname_arr	- An array of file names to be read.  This may be just 1 file name.
   initialdir   - Initial data path name to search for file.
   searchstring - search string when fname_arr= is not defined.
   Output:
   This function returns a an array of pointers.  Each pointer can be dereferenced like this:
   > data_ptr = read_yfile("~/input_files/")
   > data1 = *data_ptr(1)
   > data2 = *data_ptr(2)
   modified 10/01/02.  amar nayegandhi.
      - to include struct FS for first surface topography
      - add more documentation to this function.
   modified 10/17/02.  amar nayegandhi.
      - to include struct VEG for vegetation
   modified 01/02/03 amar nayegandhin.
      - to include new format of veg algorithm with structure VEG_
   */

extern fn_arr, type;

if (is_void(path)) {
   if (is_void(initialdir)) initialdir = "~/";
   ifn  = get_openfn( initialdir=initialdir, filetype="*.bin *.edf", title="Open Data File" );
   if (ifn != "") {
     ff = split_path( ifn, 0 );
     path = ff(1);
     fname_arr = ff(2);
     tkcmd, swrite(format="set data_file_path \"%s\" \n",path);
   } else {
    write, "No File chosen.  Return to main."
    return
   }
}

if (is_void(fname_arr)) {
   s = array(string, 10000);
   if (searchstring) {
     ss = searchstring;
   } else {
     ss = ["*.bin", "*.edf"];
   }
   scmd = swrite(format = "find %s -name '%s'",path, ss); 
   fp = 1; lp = 0;
   for (i=1; i<=numberof(scmd); i++) {
     f=popen(scmd(i), 0); 
     n = read(f,format="%s", s ); 
     close, f;
     lp = lp + n;
     if (n) fn_arr = s(fp:lp);
     fp = fp + n;
   }
} else { 
  fn_arr = path+fname_arr; 
  n = numberof(fn_arr);
}

write, format="Number of files to read = %d \n", n
//write, format="Type = %d\n", type;

bytord = 0L;
type =0L;
nwpr = 0L;
recs = 0L;
byt_pos=0L;
data_ptr = array(pointer, n);

for (i=0;i<n;i++) {
  f=open(fn_arr(i), "r+b"); 
  _read, f, 0, bytord;
  if (bytord == 65535L) order = 1; else order = 0; 
  //read the output type of the file
  _read, f, 4, type;
  //read the number of words in each record
  _read, f, 8, nwpr;
  //read the total number of records
  _read, f, 12, recs;
  write, format="Reading file %s of type %d\n",fn_arr(i), type;
  write, format="%d records to be read\n",recs;

  byt_pos = 16;
       
  //fill the array of data structures using the value of type.
  data_ptr(i) = &(data_struc(type, nwpr, recs, byt_pos, f));
  close, f;


 }
 write, format="All %d files read. \n",n;

return data_ptr;
}

func edfrstat( i, nbr ) {
  write, format=" %6d of %6d\r", i, nbr
}

func data_struc (type, nwpr, recs, byt_pos, f) {
  /* DOCUMENT data_struc(type, nwpr, recs, byt_pos, f).
     This function is used by read_yfile to define the structure depending on the data type.
     */

  if ((type == 3) || (type == 101)) {
    rn = 0L;
    mnorth = 0L;
    meast = 0L;
    melevation = 0L;
    north = 0L;
    east = 0L;
    elevation = 0L;
    intensity = 0S;
    soe = 0.0;

    data = array(FS, recs); 
    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, intensity;
       data(i).intensity = intensity;
       byt_pos = byt_pos + 2;

      if (type == 101) {
       _read, f, byt_pos, soe;
       data(i).soe = soe;
       byt_pos = byt_pos + 8;
      }
    }
  }  

  if ((type == 4) || (type == 102)) {

    rn = 0L;
    north = 0L;
    east = 0L;
    sr2 = 0S;
    bath = 0L;
    elevation=0L;
    mnorth=0L;
    meast=0L;
    melevation=0L;
    depth = 0S;
    bottom_peak = 0S;
    first_peak = 0S;
    sa = 0S;
    soe = 0.0;

    data = array(GEO, recs); 

    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, sr2;
       data(i).sr2 = sr2;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, bottom_peak;
       data(i).bottom_peak = bottom_peak;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, first_peak;
       data(i).first_peak = first_peak;
       byt_pos = byt_pos + 2;
       
       _read, f, byt_pos, depth;
       data(i).depth = depth;
       byt_pos = byt_pos + 2;

      if (type == 102) {
       _read, f, byt_pos, soe;
       data(i).soe = soe;
       byt_pos = byt_pos + 8;
      }

    }
  }

  if (type == 5) {  //OLD VEG

    rn = 0L;
    north = 0L;
    east = 0L;
    elevation=0L;
    mnorth=0L;
    meast=0L;
    melevation=0L;
    felv = 0s;
    fint = 0s;
    lelv = 0s;
    lint = 0s;
    nx = ' ';
    soe = 0.0;


    data = array(VEG, recs); 

    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, felv;
       data(i).felv = felv;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, fint;
       data(i).fint = fint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, lelv;
       data(i).lelv = lelv;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, lint;
       data(i).lint = lint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, nx;
       data(i).nx = nx;
       byt_pos = byt_pos + 1;

    }
  }

  if (type == 6) { //OLD VEG_

    rn = 0L;
    north = 0L;
    east = 0L;
    elevation=0L;
    mnorth=0L;
    meast=0L;
    melevation=0L;
    felv = 0L;
    fint = 0s;
    lelv = 0L;
    lint = 0s;
    nx = ' ';
    soe = 0.0;


    data = array(VEG_, recs); 

    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, felv;
       data(i).felv = felv;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, fint;
       data(i).fint = fint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, lelv;
       data(i).lelv = lelv;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, lint;
       data(i).lint = lint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, nx;
       data(i).nx = nx;
       byt_pos = byt_pos + 1;

    }
  }
  if ((type == 7) || (type == 104)) { // CVEG_ALL

    rn = 0L;
    north = 0L;
    east = 0L;
    elevation=0L;
    mnorth=0L;
    meast=0L;
    melevation=0L;
    intensity = 0s;
    nx = ' ';
    soe = 0.0;


    data = array(CVEG_ALL, recs); 

    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, intensity;
       data(i).intensity = intensity;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, nx;
       data(i).nx = nx;
       byt_pos = byt_pos + 1;

      if (type == 104) {
       _read, f, byt_pos, soe;
       data(i).soe = soe;
       byt_pos = byt_pos + 8;
      }

    }
  }

  if ((type == 8) || (type == 103)) {
    //type = 8 introduced on 08/03/03 for processing "VEGETATION" to include both first and last return locations. Type of structure VEG__

    rn = 0L;
    north = 0L;
    east = 0L;
    elevation=0L;
    mnorth=0L;
    meast=0L;
    melevation=0L;
    lnorth = 0L;
    least = 0L;
    lelv = 0L;
    fint = 0s;
    lint = 0s;
    nx = ' ';
    soe = 0.0;


    data = array(VEG__, recs); 

    for (i=0;i<recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, north;
       data(i).north = north;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, east;
       data(i).east = east;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, elevation;
       data(i).elevation = elevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, mnorth;
       data(i).mnorth = mnorth;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, meast;
       data(i).meast = meast;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, melevation;
       data(i).melevation = melevation;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, lnorth;
       data(i).lnorth = lnorth;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, least;
       data(i).least = least;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, lelv;
       data(i).lelv = lelv;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, fint;
       data(i).fint = fint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, lint;
       data(i).lint = lint;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, nx;
       data(i).nx = nx;
       byt_pos = byt_pos + 1;

      if (type == 103) {
       _read, f, byt_pos, soe;
       data(i).soe = soe;
       byt_pos = byt_pos + 8;
      }
    }
  }
  if (type == 1001) {
    //type = 1001 introduced on 11/03/03 for processing eaarl bottom return stats using bottom_return.i
    rn = 0L;
    idx = 0s;
    sidx = 0s;
    range=0s;
    ac=0.0F;
    cent=0.0F;
    centidx=0.0F;
    peak= 0.0F;
    peakidx= 0s;
    soe = 0.0;


    data = array(BOTRET, recs); 

    for (i=1;i<=recs;i++) {

       if ( (i % 1000) == 0 ) edfrstat, i, recs;
       _read, f, byt_pos, rn;
       data(i).rn = rn;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, idx;
       data(i).idx = idx;
       byt_pos = byt_pos + 2;
       
       _read, f, byt_pos, sidx;
       data(i).sidx = sidx;
       byt_pos = byt_pos + 2;
       
       _read, f, byt_pos, range;
       data(i).range = range;
       byt_pos = byt_pos + 2;

       _read, f, byt_pos, ac;
       data(i).ac = ac;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, cent;
       data(i).cent = cent;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, centidx;
       data(i).centidx = centidx;
       byt_pos = byt_pos + 4;
       
       _read, f, byt_pos, peak;
       data(i).peak = peak;
       byt_pos = byt_pos + 4;

       _read, f, byt_pos, peakidx;
       data(i).peakidx = peakidx;
       byt_pos = byt_pos + 2;
       
       _read, f, byt_pos, soe;
       data(i).soe = soe;
       byt_pos = byt_pos + 8;
    }
  }
  return data;
}

func write_ascii_xyz(data_arr, opath, ofname, type=, ESRI=, header=, footer=, delimit=, intensity=, rn=, soe=, indx=, zclip=, latlon=, split=, zone=, pstruc=) {
/* DOCUMENT write_ascii_xyz, data_arr, opath, ofname, type=, ESRI=, header=,
   footer=, delimit=, intensity=, rn=, soe=, indx=, zclip=, latlon=, split=,
   zone=, pstruc=

   Creates an ascii file containing information from the data array.

   Required parameters and options:

      data_arr     : Data array. Can be first surface (fs_all), bathymetry
                     (depth_all), or vegetation (veg_all).

      opath        : Path for output file.

      ofname       : File name for output file.

      type=        : Type of data to be written out.
                        1 - first surface
                        2 - bathymetry
                        3 - vegetation (bare earth)
                        4 - depth
                        5 - (unknown?)
                        6 - multi-peak veg

   Options that affect output file content:

      ESRI=        : Forces ESRI compatibility.  Removes ()'s from header and
                     forces index number.

      header=      : Set to 1 to add a header line to each ascii file

      footer=      : Set to a "string" to put at the last line of the output
                     file

      delimit=     : Define the delimeter between fields in an output line,
                     such as " ", ",", or ";". Default is a single space.

      intensity=   : Set to 1 to include the laser backscatter intensity in the
                     output files.

      rn=          : Set to 1 to include the raster/pulse number in the output
                     files.

      soe=         : Set to 1 to include the unique timestamp in the output
                     files.

      indx=        : Set to 1 to include the index number for each record in
                     the output files.

      zclip=       : [minz,maxz] Min and max elevation values in cm to be used
                     as a 'clipper'. Values outside of this range will be
                     excluded.

      latlon=      : Set to 1 to convert utm values to latlon.

   Miscellaneous options:
      
      split=       : Set to the number of maximum lines to put in a file. If
                     specified, multiple files may be created. If set to 0,
                     then only one file will be created. (Default: split=0)

      zone=        : UTM zone number. Only required if latlon=1. Defaults to
                     extern curzone if not supplied.

      pstruc=      : Specifies a structure that suggests how the data should be
                     cleaned, if cleaning is necessary.
                        FS - convert FS_ALL to FS using clean_fs
                        GEO - convert GEOALL to GEO using clean_bathy
                        VEG__ - convert veg_all_ to veg using clean_veg

   amar nayegandhi 04/25/02
   modified 12/30/02 amar nayegandhi to :
   write out x,y,z (first surface elevation) data for type=1
   to split at 1 million points and write to another file
   modified 01/30/03 to optionally split at 1 million points
   modified 10/06/03 to add rn and soe and correct the output format for different delimiters.
   modified 10/09/03 to add latlon conversion capability

   Refactored and modified by David Nagle 2008-11-18
*/
   extern curzone;
   default, ESRI, 0;
   default, header, 0;
   default, indx, 0;
   default, delimit, " ";
   default, zclip, [-600., 30000.];
   default, latlon, 0;
   default, footer, [];

   default, mode, 1;

   if (ESRI) {
      header = 1;
      indx = 1;
   }

   default, zone, curzone;
   if (latlon && !zone) { 
      szone = "";
      zone = 0;
      f = read(prompt="Enter UTM Zone Number:", szone);
      sread, szone, zone;
      curzone = zone;
   }

   fn = opath+ofname;

   data_arr = test_and_clean(unref(data_arr));

   hline = [];
   if (header) {
      if (indx)
         grow, hline, (ESRI ? "id" : "Index");
      grow, hline, (ESRI
         ? ["utm_x", "utm_y", "z_meters"]
         : ["UTMX(m)", "UTMY(m)", "cZ(m)"]);
      if (intensity)
         grow, hline, (ESRI ? "intensity_counts" : "Intensity(counts)");
      if (rn)
         grow, hline, (ESRI ? "raster_pulse" : "Raster/Pulse");
      if (soe)
         grow, hline, (ESRI ? "soe" : "SOE");
      hline = strjoin(hline, delimit);
   }

   if (pstruc == CVEG_ALL) type = 6;

   if ( (type == 1) || (type == 6)) {
      z = data_arr.elevation/100.;
   } else if (type == 2) {
      z = (data_arr.elevation + data_arr.depth)/100.;
   } else if ((type == 3) || (type == 5)) {
      z = data_arr.lelv/100.;
   } else if (type == 4) {
      z = data_arr.depth/100.;
   }
   zvalid = where( (z > zclip(1)) & (z < zclip(2)) );
   if(numberof(zvalid)) {
      z = z(zvalid);
      data_arr = data_arr(zvalid);
      if (numberof(where(type == [1,2,4,5,6]))) {
         east = data_arr.east/100.;
         north = data_arr.north/100.;
         if ( type == 6 ) {
           nx = data_arr.nx; 
         }
      } else if (type == 3) {
         east = data_arr.least/100.;
         north = data_arr.lnorth/100.;
      }
      if (latlon) {
         ldat = utm2ll(north,east,zone);
         east = ldat(,1);
         north = ldat(,2);
         east = swrite(format="%3.7f", east);
         north = swrite(format="%3.7f", north);
      } else {
         east = swrite(format="%8.2f", east);
         north = swrite(format="%9.2f", north);
      }
      if (intensity) {
         data_intensity = [];
         if ( (type == 1) || (type == 6 ) ) {
            if (pstruc == FS) {
               data_intensity = data_arr.intensity;
            }
            if (pstruc == GEO) {
               data_intensity = data_arr.first_peak;
            }
            if (pstruc == VEG__) {
               data_intensity = data_arr.fint;
            }
         } else if ((type == 2) || (type == 4)) {
            if (pstruc == GEO) {
               data_intensity = data_arr.bottom_peak;
            }
         } else if ((type == 3) || (type == 5)) {
            if (pstruc == VEG__) {
               data_intensity = data_arr.lint;
            }
         }
         if(is_void(data_intensity))
            intensity = 0;
         else
            data_intensity = swrite(format="%d", data_intensity);
      }
      z = swrite(format="%4.2f", z);

      // indx is deferred to output section...
      curline = [east, north, z];
      if (intensity) grow, curline, data_intensity;
      if (rn) grow, curline, swrite(format="%d", data_arr.rn);
      if (soe) grow, curline, swrite(format="%12.3f", data_arr.soe);
      if ( type == 6 ) grow, curline, swrite(format="%d", nx);

      if(split) {
         fn_base = file_rootname(fn);
         fn_ext = file_extension(fn);
         fn_num = 0;
         for(i = 1; i <= numberof(data_arr); i += split) {
            fn_num++;
            cur_fn = swrite(format="%s_%d.%s", fn_base, fn_num, fn_ext);
            max_idx = min(i + split, numberof(data_arr));
            __write_ascii_xyz_helper, fn=cur_fn, lines=curline(i:max_idx),
               header=hline, footer=footer, indx=indx, delimit=delimit;
         }
      } else {
         data_arr = [];
         __write_ascii_xyz_helper, fn=fn, lines=unref(curline),
            header=hline, footer=footer, indx=indx, delimit=delimit;
      }
   }
}

func __write_ascii_xyz_helper(void, fn=, lines=, header=, footer=, indx=, delimit=) {
   f = open(fn, "w");
   if (header)
      write, f, format="%s\n", header;
   if (indx) {
      totw = swrite(format="%d", indgen(numberof(lines(,1))));
      lines = grow([totw], lines);
   }
   // Put delimiters in place and merge line elements into single strings
   lines(,:-1) += delimit;
   lines = unref(lines)(,sum);
   write, f, format="%s\n", lines;
   if (footer)
      write, f, format="%s\n", footer;
   close, f;
   write, format="Total records written to ascii file = %d\n", numberof(lines(,1));
}

func read_ascii_xyz(ipath=,ifname=, no_lines=, header=, columns=){
 /* this function reads in an xyz ascii file and returns a n-d array.
    amar nayegandhi 05/01/02
    modified 10/05/06 to make it faster and read more columns
   ** ALL COLUMNS MUST BE INTEGERS OR FLOATING POINT.. NO STRINGS ALLOWED**
	ipath = input path name
	ifname = input file name
	no_lines = number of lines in file
	header = set to 1 if header line is present
	columns = number of columns in file (only needed if > 3)
    */

    fn = ipath+ifname;
    if (is_void(columns)) columns = 3;
    if (is_void(no_lines)) {
	cmd = "cat "+ipath+ifname+" | wc -l"
	f = popen(cmd,0);
	no_lines = 0;
	read, f, no_lines;
	close,f;
   }
    
   f = open(fn, "r");
   if (header) {
	hd = rdline(f);
	no_lines--;
   }
   arr = array(double, columns, no_lines);
   
   read, f, arr;
 
   return arr;

}

func read_pointer_yfile(data_ptr, mode=) {
  // this function reads the data_ptr array from read_yfile.
  // select mode = 1 to merge all data files
  // amar nayegandhi 11/25/02.
  extern fs_all, depth_all, veg_all, cveg_all;
  data_out = [];

  if (!is_array(data_ptr)) return;
  if (mode == 1) {
    //merge all data files 
    for (i=1; i <= numberof(data_ptr); i++) {
       grow, data_out, (*data_ptr(i));
    }
  }
  a = structof(data_out);
  if (a == FS) {
    fs_all = data_out;
    if (_ytk) {
      tkcmd, "set pro_var fs_all";
      tkcmd, "processing_mode_by_index 0";
      tkcmd, "display_type_by_index 0";
      cmin = min(fs_all.elevation)/100.;
      cmax = max(fs_all.elevation)/100.;
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (a == GEO) {
    depth_all = data_out;
    if (_ytk) {
      tkcmd, "set pro_var depth_all";
      tkcmd, "processing_mode_by_index 1";
      tkcmd, "display_type_by_index 1";
      cmin = min(depth_all.depth+depth_all.elevation)/100.;
      cmax = max(depth_all.depth+depth_all.elevation)/100.;
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (a == VEG || a == VEG_ || a == VEG__) {
    veg_all = data_out;
    if (_ytk) {
      tkcmd, "set pro_var veg_all";
      tkcmd, "processing_mode_by_index 2";
      tkcmd, "display_type_by_index 3";
      cmin = min(veg_all.lelv)/100.;
      cmax = max(veg_all.lelv)/100.;
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (a == CVEG_ALL) {
    cveg_all = data_out;
    if (_ytk) {
      tkcmd, "set pro_var veg_all";
      tkcmd, "processing_mode_by_index 3";
      tkcmd, "display_type_by_index 0";
      cmin = min(cveg_all.elevation)/100.;
      cmax = max(cveg_all.elevation)/100.;
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }

}
    
    
func set_read_tk(junk) {
  /* DOCUMENT set_read_tk(vname)
    This function sets the variable name in the Process Eaarl Data gui
   amar nayegandhi 05/05/03
  */

   extern vname
   tkcmd, swrite(format="append_varlist %s",vname);
   tkcmd, "varlist_plot";
   tkcmd, swrite(format="set pro_var %s", vname);
   write, "Tk updated \r";

}

func set_read_yorick(vname) {
  /* DOCUMENT set_read_yorick(vname)
    This function sets the cmin and cmax values in the Process EAARL data GUI
    amar nayegandhi 05/06/03
  */

  ab = structof(vname);
  if (ab == FS || ab == R) {
    if (_ytk) {
      tkcmd, "processing_mode_by_index 0";
      tkcmd, "display_type_by_index 0";
      cminmax = stdev_min_max(vname.elevation)/100.;
      cmin = cminmax(1);
      cmax = cminmax(2);
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (ab == GEO || ab == GEOALL) {
    if (_ytk) {
      tkcmd, "processing_mode_by_index 1";
      tkcmd, "display_type_by_index 1";
      cminmax = stdev_min_max(vname.depth+vname.elevation)/100.;
      cmin = cminmax(1);
      cmax = cminmax(2);
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (ab == VEG || ab == VEG_ || ab == VEG__ || ab == VEGALL || ab == VEG_ALL || ab == VEG_ALL_) {
    if (_ytk) {
      tkcmd, "processing_mode_by_index 2";
      tkcmd, "display_type_by_index 3";
      cminmax = stdev_min_max(vname.lelv)/100.;
      cmin = cminmax(1);
      cmax = cminmax(2);
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  if (ab == CVEG_ALL) {
    if (_ytk) {
      tkcmd, "processing_mode_by_index 0";
      cminmax = stdev_min_max(vname.elevation)/100.;
      cmin = cminmax(1);
      cmax = cminmax(2);
      tkcmd, swrite(format="set plot_settings(cmin) %f", cmin);
      tkcmd, swrite(format="set plot_settings(cmax) %f", cmax);
    }
  }
  
  tkcmd, swrite("if {$cbv == 1} {set plot_settings(cmin) $cbvc(cmin)}");
  tkcmd, swrite("if {$cbv == 1} {set plot_settings(cmax) $cbvc(cmax)}");
  tkcmd, swrite("if {$cbv == 1} {set plot_settings(msize) $cbvc(msize)}");
  tkcmd, swrite("if {$cbv == 1} {set plot_settings(mtype) $cbvc(mtype)}");
  
}
  

func yfile_to_pbd (filename, vname) {
  /* DOCUMENT yfile_to_pbd(filename, vname)
     This function converts a yorick written (.edf or .bin) file to a pbd file.
     amar nayegandhi 05/27/03
     */
 
 filepath = split_path(filename, 0);
 path = filepath(1);
 file = filepath(2);

 data_ptr = read_yfile(path, fname_arr=file);
 data = *data_ptr(1);

 // now create the pbd file
 fnamepbd = (split_path(filename, 1, ext=1))(1)+".pbd";
 
 f = createb(fnamepbd);
 add_variable, f, -1, vname, structof(data), dimsof(data);
 get_member(f,vname) = data;
 save, f, vname;
 close, f;
 data = []
}

func pbd_to_yfile(filename) {
   /*DOCUMENT pbd_to_yfile(filename) 
     This function converts a pbd file to the .edf or .bin yfile
     */

     f = openb(filename);
     restore, f, vname;
     data = get_member(f, vname);
     close, f;
     a = data(1);
     b = structof(a);
     
     fnameedf = (split_path(filename, 1, ext=1))(1)+".edf";
     filepath = split_path(fnameedf,0);
     path = filepath(1);
     file = filepath(2);

     if (b == FS) 
        write_topo, path, file, data;
     if (b == GEO) 
        write_bathy, path, file, data;
     if (b == VEG__) 
        write_veg, path, file, data;
     if (b == CVEG_ALL) 
        write_multipeak_veg, data, opath=path, ofname=file;
     if (b == ATM2)
        write_atm, path, file, data;
}

   
func merge_data_pbds(filepath, write_to_file=, merged_filename=, nvname=, uniq=, skip=, searchstring=, fn_all=) {
 /*DOCUMENT merge_data_pbds(filename) 
   This function merges the EAARL processed pbd data files in the given filepath
   INPUT:
   filepath : the path where the pbd files are to be merged
   write_to_file : set to 1 if you want to write the merged pbd to file
   merged_filename : the merged filename where the merged pbd file will be written to.
   vname = the variable name for the merged data
   uniq = set to 1 if you want to delete the same records (keep only unique records).
   skip = set to subsample the data sets read in.
   amar nayegandhi 05/29/03
   */

 if (!skip) skip = 1;
 skip = int(skip);
 eaarl = [];
 // find all the pbd files in filepath

  if ( is_void(fn_all) ) {
    s = array(string, 10000);
    if (searchstring) ss = [searchstring];
    if (!searchstring) ss = ["*.pbd"];
    scmd = swrite(format="find %s -name '%s'", filepath, ss);
    fp = 1; lp = 0;
    for (i=1; i<=numberof(scmd); i++) {
        f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) fn_all = s(fp:lp);

/*
    // 2009-01-29: added to remove output file from the list to be merged
    // THIS CANNOT BE UNIVERSALLY APPLIED... an output file can contain "merged" in its filename and be a valid file to merge.
    mgd_idx = strmatch(fn_all,"merged",1);
    fn_all = fn_all(where(!mgd_idx));
    n = numberof(fn_all);
*/

        fp = fp + n;
    }
  }

  if(numberof(fn_all)) {
     eaarl_size = 0;
     eaarl_struct = [];
     for(i = 1; i <= numberof(fn_all); i++) {
        write, format="Getting size of file %d of %d\r", i, numberof(fn_all);
        f = openb(fn_all(i));
        if(get_member(f, f.vname) != 0) {
           // The next line deliberately uses integer math, which truncates
           eaarl_size += (numberof(get_member(f, f.vname))+skip-1)/skip;
           // The above should be faster than
           // numberof(get_member(f,f.vname)(::skip)) because it doesn't need
           // to actually load the data into memory
           if(is_void(eaarl_struct)) {
              // The "obvious" way to do this would be:
              //    eaarl_struct = structof(get_member(f, f.vname)(1))
              // However, that results in a structure definition that is tied
              // to the file, which is not usuable when we try to create an
              // array with it. Using the temporary variable avoids that issue.
              temp = get_member(f, f.vname)(1);
              eaarl_struct = structof(temp);
              temp = [];
           }
        }
        close, f;
     }
     write, format="\nAllocating data array of size %d...\n", eaarl_size;
     eaarl = array(eaarl_struct, eaarl_size);
     idx = 1;
     for(i = 1; i <= numberof(fn_all); i++) {
        write, format="Merging file %d of %d\r", i, numberof(fn_all);
        f = openb(fn_all(i));
        if(get_member(f, f.vname) != 0) {
           idx_upper = idx + (numberof(get_member(f, f.vname))+skip-1)/skip - 1;
           eaarl(idx:idx_upper) = get_member(f, f.vname)(::skip);
           idx = idx_upper + 1;
        }
        close, f;
     }
  }

 if (uniq) {
   write, "Finding unique elements in array..."
   // sort the elements by soe
   idx = sort(eaarl.soe);
   if (!is_array(idx)) {
     write, "No Records found.";
     return
   }
   eaarl = eaarl(idx);
   // now use the unique function with ret_sort=1
   idx = unique(eaarl.soe, ret_sort=1);
   if (!is_array(idx)) {
     write, "No Records found.";
     return
   }
   eaarl = eaarl(idx);
 }

 if (write_to_file) {
   // write merged data out to merged_filename
   if (!merged_filename) merged_filename = filepath+"data_merged.pbd";
   if (!nvname) {
     // create variable vname if required
     a = eaarl(1);
     b = structof(a);
     if (a == FS) nvname = "fst_merged";
     if (a == GEO) nvname = "bat_merged";
     if (a == VEG__) nvname = "bet_merged";
     if (a == CVEG_ALL) nvname = "mvt_merged";
   }
   vname=nvname
   f = createb(merged_filename);
   add_variable, f, -1, vname, structof(eaarl), dimsof(eaarl);
   get_member(f,vname) = eaarl;
   save, f, vname;
   close, f;
 }

 write, format="Merged %d files, skip = %d \n", numberof(fn_all), skip;


 return eaarl
}

func subsample_pbd_data (fname=, skip=,output_to_file=, ofname=) {
  /* DOCUMENT subsample_pbd_data(fname, skip=)
    This function subsamples the pbd file at the skip value.
  //amar nayegandhi 06/15/03
   INPUT:
     fname = filename to input.  If not defined, a pop-up window will be called to select the file.
     skip = the subsample (default = 10)
     output_to_file = set to 1 if you want the output to be written out to a file.
     ofname = the name of the output file name.  Valid only when output_to_file = 1.  If not defined, same as input file name with a "-skip-xx" added to it.
     OUTPUT:
       If called as a function, returned array is the subsampled data array.
  */
  
  extern initialdir;
  if (!skip) skip = 10;

  //read pbd file
  if (!fname) {
   if (is_void(initialdir)) initialdir = "/data/";
   fname  = get_openfn( initialdir=initialdir, filetype="*.pbd", title="Open PBD Data File" );
  }
  
  fif = openb(fname); 
  //restore, fif, vname, plyname, qname;
  restore, fif, vname;
  eaarl = get_member(fif, vname)(1:0:skip);
  //ply = get_member(fif, plyname);
  //q = get_member(fif, qname);
  close, fif;
  if (output_to_file == 1) {
    if (!ofname) {
      sp = split_path(fname, 0, ext=1)
      ofname = sp(1)+swrite(format="-skip%d",skip)+sp(2);
    }
    fof = createb(ofname);
    save, fof, vname;
    add_variable, fof, -1, vname, structof(eaarl), dimsof(eaarl);
    get_member(fof, vname) = eaarl;
    //add_variable, fof, -1, qname, structof(q), dimsof(q);
    //get_member(fof, qname) = q;
    //add_variable, fof, -1, plyname, structof(ply), dimsof(ply);
    //get_member(fof, plyname) = ply;
    close, fof;
  }
  return eaarl;
  
}
