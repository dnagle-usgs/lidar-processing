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

      pstruc=      : Mostly obsolete. If pstruc=CVEG_ALL, then type is forced
                     to type=6. Otherwise, pstruc= is ignored.

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
   default, pstruc, VEG__;

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
            if(has_member(data_arr, "intensity"))
               data_intensity = data_arr.intensity;
            else if(has_member(data_arr, "first_peak"))
               data_intensity = data_arr.first_peak;
            else if (has_member(data_arr, "fint"))
               data_intensity = data_arr.fint;
         } else if ((type == 2) || (type == 4)) {
            if(has_member(data_arr, "bottom_peak"))
               data_intensity = data_arr.bottom_peak;
         } else if ((type == 3) || (type == 5)) {
            if(has_member(data_arr, "lint"))
               data_intensity = data_arr.lint;
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
            cur_fn = swrite(format="%s_%d%s", fn_base, fn_num, fn_ext);
            max_idx = min(i + split, numberof(data_arr)+1);
            __write_ascii_xyz_helper, fn=cur_fn, lines=curline(i:max_idx-1,),
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

local __ascii_xyz_settings;
__ascii_xyz_settings = h_new(
   "charts", h_new(
      columns=["lon", "lat", "zone", "east", "north", "elev", "z_ellip",
         "yyyymmdd", "hhmmss", "intensity"],
      delimit=",",
      header=1
   ),
   "charts ellipsoid", h_new(
      columns=["lon", "lat", "zone", "east", "north", "elev_datum", "elev",
         "yyyymmdd", "hhmmss", "intensity"],
      delimit=",",
      header=1
   )
);

func __read_ascii_xyz_hhmmss2soe(&data, field, val) {
   soe = get_member(data, field);
   hms = atod(regsub(":", val, "", all=1));
   soe += hms2sod(hms);
   get_member(data, field) = soe;
}

func __read_ascii_xyz_yyyymmdd2soe(&data, field, val) {
   sod = get_member(data, field);
   soe = array(double, numberof(sod));
   ymds = set_remove_duplicates(val);
   for(i = 1; i <= numberof(ymds); i++) {
      ymd = regsub("/", ymds(i), "", all=1);
      ymd = regsub("-", ymd, "", all=1);
      ymd = atoi(ymd);
      y = long(ymd/10000);
      m = long((ymd/100) % 100);
      d = ymd % 100;
      w = where(val == ymds(i));
      soe(w) = ymd2soe(y, m, d) + sod(w);
   }
   get_member(data, field) = soe;
}

func __read_ascii_xyz_m2cm(&data, field, val) {
   get_member(data, field) = val * 100;
}

func __read_ascii_xyz_store(&data, field, val) {
   get_member(data, field) = val;
}

func read_ascii_xyz(file, pstruc, delimit=, header=, ESRI=, intensity=, rn=,
soe=, indx=, columns=, mapping=, types=, preset=) {
/* DOCUMENT data = read_ascii_xyz(file, pstruc, header=, delimit=, ESRI=,
   intensity=, rn=, soe=, indx=, mapping=, columns=, types=, preset=)

   Reads an ASCII file and stores its data in the specified structure. This
   function is optimized to read files created with write_ascii_xyz but has
   also been designed with flexibility for other uses in mind.

   This fills in as many fields in the provided structure as it can, even if
   doing so isn't "correct", in order to improve compatibility throughout ALPS.
   For example, the mirror coordinates are filled in with the XYZ coordinates.

   Required parameters:

      file: The full path and file name of the ascii XYZ file to read.
      pstruc: The structure to convert the data to. This must be a "clean"
         structure such as VEG__ (anything that can come out of
         test_and_clean).  Raw structures (such as R) will not work. If pstruc
         is omitted, then the data will be returned as a 2-dimensional array of
         doubles.

   Options:

      preset= Select a set of custom settings tailored to a specific XYZ
         format. Using preset= will turn off auto-detect mode (described
         below). The list of presets is given further below.

      delimit= The delimiter used. Defaults to " ".

      Without any additional options, the function works in auto-detect mode.
      It will analyze the first few lines of the file in an attempt to
      determine what the columns are. This will usually work provided you
      created the file using write_ascii_xyz. So if you created the file with
      write_ascii_xyz, you can probably read it without any explicit options.

      On rare occasions, it may not read in properly even though it was written
      with write_ascii_xyz. If you know what options were used when the file was
      created and for some reason the file isn't parsing automatically, then you
      can specify those same options here.  These options will turn off
      auto-detect mode and correspond to options from write_ascii_xyz.

      ESRI=
      intensity=
      rn=
      soe=
      indx=

      The header= option from write_ascii_xyz is also used, but its meaning is
      altered some. It will also turn off auto-detect mode.

      header= This is extended to provide the number of header lines. If your
         file has 3 header lines, use header=3.

      The following options from write_ascii_xyz are NOT implemented, but
      affect output when used. Thus, if these options were used on
      write_ascii_xyz, you may not have success with read_ascii_xyz.

      footer: If your file has a footer, you'll have to manually remove it.
      latlon: Conversion from lat/lon to UTM is not implemented.
      split: This can handle a file that was split, but it won't auto join
         multiple copies.
      type: If you used type=2, then be aware that the elevation written to
         file was data.elevation + data.depth. There's no way to figure out
         what those two values were. The output will set data.elevation
         to this value and leave data.depth at 0.

      If you are using a custom ASCII format that doesn't have a preset, you
      will probably need the column= option.

      columns= Used to specify what each column is. This is an array of column
         names, for example:
            columns=["east", "north", "elevation"]
         These column names can be anything, but in order for them to actually
         accomplish anything they must be defined in the mapping. See further
         below for the default mappings.

      If none of the above works, then you can use the following advanced
      options to further override the function's behavior.

      mapping= Used to provide a custom mapping of ascii columns to structure
         fields. This overrides the built-in mapping.
      types= Used to override the type expected when reading in the file. This
         should almost never be used, as it's accounted for in mapping. (Note:
         This is NOT the same as the type= parameter in write_ascii_xyz.)

   Presets

      Presets are intended for common-use ascii data that has a reliable
      format. Follows is a list of the currently defined presets. Note that
      some of the column names used in these presets are not defined in the
      default mappings; this means that those columns will be ignored.

      preset="charts"
         This preset is intended for CHARTS data. It is equivalent to using
         these settings:
            columns=["lon", "lat", "zone", "east", "north", "elev", "z_ellip",
               "yyyymmdd", "hhmmss", "intensity"]
            delimit=","
            header=1
         Here is a sample of the first five lines of an example CHARTS file,
         showing the format of data this is intended to work with:

# LONGITUDE, LATITUDE, UTM ZONE, EASTING, NORTHING, ELEV, ELEV (ellipsoid),  YYYY/MM/DD,HH:MM:SS.SSSSSS INTENSITY
-75.501746746,35.347383504,18,454408.926,3911683.171,2.38,-36.40,2009/08/12,14:48:51.243122,50
-75.501760721,35.347384483,18,454407.657,3911683.286,2.08,-36.70,2009/08/12,14:48:51.243176,42
-75.501816206,35.347391056,18,454402.619,3911684.040,1.91,-36.87,2009/08/12,14:48:51.243374,46
-75.501829975,35.347392697,18,454401.369,3911684.229,1.85,-36.93,2009/08/12,14:48:51.243423,44

      preset="charts ellipsoid"
         This preset is almost identical to the "charts" preset. The only
         difference is that it uses the ellipsoid elevation instead of the
         non-ellipsoid elevation. It is equivalent to using these settings:
            columns=["lon", "lat", "zone", "east", "north", "elev_datum", "elev",
               "yyyymmdd", "hhmmss", "intensity"],
            delimit=",",
            header=1

   Columns

      This function has a wide range of built-in column mappings defined that
      should make it easy in most circumstances to specify how to read in an
      ASCII file's content. Follows is a listing of defined column names and
      what data structure fields they will map to. If a value is passed to
      columns= that is not in this list, then that column is simply ignored.

      Column            Maps to                       Notes
      ----------------  ----------------------------  -----------------------
      utm_x             .east .meast .least           Input should be meters
      UTMX(m)           .east .meast .least           Input should be meters
      east              .east .meast .least           Input should be meters
      feast             .east                         Input should be meters
      least             .least                        Input should be meters
      meast             .meast                        Input should be meters
      utm_y             .north .mnorth .lnorth        Input should be meters
      UTMY(m)           .north .mnorth .lnorth        Input should be meters
      north             .north .mnorth .lnorth        Input should be meters
      fnorth            .north                        Input should be meters
      lnorth            .lnorth                       Input should be meters
      mnorth            .mnorth                       Input should be meters
      z_meters          .elevation .lelv .melevation  Input should be meters
      cZ(m)             .elevation .lelv .melevation  Input should be meters
      elev              .elevation .lelv .melevation  Input should be meters
      elevation         .elevation .lelv .melevation  Input should be meters
      felevation        .elevation                    Input should be meters
      lelv              .lelv                         Input should be meters
      melevation        .melevation                   Input should be meters
      depth             .depth                        Input should be meters
      intensity_counts  .intensity .first_peak .fint
                        .bottom_peak .lint
      Intensity(counts) .intensity .first_peak .fint
                        .bottom_peak .lint
      intensity         .intensity .first_peak .fint
                        .bottom_peak .lint
      first_peak        .first_peak
      bottom_peak       .bottom_peak
      fint              .fint
      lint              .lint
      soe               .soe
      SOE               .soe
      hhmmss            .soe                          See note [1] below
      hh:mm:ss          .soe                          See note [1] below
      yyyymmdd          .soe                          See note [1] below
      yyyy-mm-dd        .soe                          See note [1] below
      yyyy/mm/dd        .soe                          See note [1] below
      raster_pulse      .rn
      Raster/Pulse      .rn
      rn                .rn

      [1] Columns for HMS-values and date-values are combined if both are
         present. If only one is present, then soe will receive just the
         seconds of the day or the timestmap of the day start. If your input
         data for some reason has the HMS in multiple columns or the date in
         multiple columns, only use one of each. Otherwise, the multiple values
         will get added together to give you a bogus time.

   Example of using columns=

      Consider a file with content like this:

         574210.74,7378000.00,134.38,4,1,931741523.046877
         574001.46,7377693.71,134.78,8,1,931742705.021433
         574000.39,7377698.72,134.85,7,1,931742705.057043
         574002.36,7377697.26,134.64,15,1,931742705.057073
         574004.28,7377695.83,134.80,11,1,931742705.057103
         574006.23,7377694.39,134.66,12,1,931742705.057133
         574009.55,7377694.07,136.12,7,1,931742705.076933
         574007.76,7377695.47,134.74,7,1,931742705.076963
         574005.82,7377696.93,134.58,11,1,931742705.076993
         574003.90,7377698.37,134.51,15,1,931742705.077023
         ...

      The fields here correspond to UTM x, y, and z, the intensity, the return
      number, and the time. With the exception of the return number, all other
      fields are something we're used to seeing in the output of write_ascii_xyz.
      However, they're not in the same order and there's an extra field in the
      middle.  In order to read the file in, we need to tell the function what
      each column contains. We can use the names that the columns would have if
      we wrote it out with write_ascii_xyz.

      If we wanted to read this into an FS structure, our function call would look
      like this:

      fs_all = read_ascii_xyz("example1.txt", FS, delimit=",",
         columns=["utm_x", "utm_y", "z_meters", "intensity_counts", "", "soe"])

      Note that we used an empty string to ignore the column with the return
      number, since the FS structure does not have a field for this.

   The advanced mapping= option
      
      The mapping= option is primarily a "just in case" option. It isn't
      expected to actually be used, since the default mapping is supposed to
      cover everything a user may need. However, just in case...
   
      The mapping= option accepts a Yeti hash. The keys to that hash should match
      the column names. The value of each entry is another hash with the following
      keys:

      type= This corresponds to the type= option of rdcols and tells rdcols how
         to interpret the text for that field.
         Valid values:
            type=0 -- guess
            type=1 -- string
            type=2 -- integer
            type=3 -- real
            type=4 -- integer or real

      dest= This is an array of strings. Each string is the name of a structure
         field where this column should get written to. (If the structure
         doesn't have a given field, then that field is ignored.)

      fnc= Specifies a function to use to store the data. This is optional; if
         not provided, it is stored as is. If your data needs custom treatment
         (for example, converting meters to centimeters), you'll need to
         provide a storage function. The function must accept three arguments:
         data, field, and val. The data argument must also be an output
         argument that modifies the data in-place. The field argument is the
         string name of the field to be stored to (so... get_member(data,
         field)). And the val argument is the array of data to be stored
         (subject to custom alteration). There are a few predefined functions
         for this:
            __read_ascii_xyz_hhmmss2soe __read_ascii_xyz_yyyymmdd2soe
            __read_ascii_xyz_m2cm __read_ascii_xyz_store
*/
// Original: David Nagle 2009-08-24
   if(!is_void(preset)) {
      if(h_has(__ascii_xyz_settings, preset)) {
         settings = __ascii_xyz_settings(preset);
         if(h_has(settings, "mapping") && is_void(mapping))
            mapping = settings.mapping;
         if(h_has(settings, "columns") && is_void(columns))
            columns = settings.columns;
         if(h_has(settings, "header") && is_void(header))
            header = settings.header;
         if(h_has(settings, "types") && is_void(types))
            types = settings.types;
         if(h_has(settings, "delimit") && is_void(delimit))
            delimit = settings.delimit;
      } else {
         error, "Unknown preset.";
      }
   }

   default, delimit, " ";
   if(typeof(pstruc) == "string") pstruc = symbol_def(pstruc);

   if(ESRI) {
      header = 1;
      indx = 1;
   }

   if(is_void(mapping)) {
      // If you want to pass the mapping= option, then you'll need to create a
      // Yeti hash that contains information similar to the following.
      mapping = h_new();
      // Field definitions
      // id/Index has no destination in the struct, so it's omitted
      h_set, mapping, "utm_x",
         h_new(type=3, dest=["east","meast","least"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "utm_y",
         h_new(type=3, dest=["north","mnorth","lnorth"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "z_meters",
         h_new(type=3, dest=["elevation","lelv","melevation"],
            fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "intensity_counts",
         h_new(type=2, dest=["intensity","first_peak","fint","bottom_peak","lint"]);
      h_set, mapping, "raster_pulse",
         h_new(type=2, dest=["rn"]);
      h_set, mapping, "soe",
         h_new(type=3, dest=["soe"]);
      h_set, mapping, "hhmmss",
         h_new(type=1, dest=["soe"], fnc=__read_ascii_xyz_hhmmss2soe);
      h_set, mapping, "yyyymmdd",
         h_new(type=1, dest=["soe"], fnc=__read_ascii_xyz_yyyymmdd2soe);
      h_set, mapping, "feast",
         h_new(type=3, dest=["east"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "fnorth",
         h_new(type=3, dest=["north"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "felevation",
         h_new(type=3, dest=["elevation"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "least",
         h_new(type=3, dest=["least"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "lnorth",
         h_new(type=3, dest=["lnorth"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "lelv",
         h_new(type=3, dest=["lelv"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "depth",
         h_new(type=3, dest=["depth"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "meast",
         h_new(type=3, dest=["meast"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "mnorth",
         h_new(type=3, dest=["mnorth"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "melevation",
         h_new(type=3, dest=["melevation"], fnc=__read_ascii_xyz_m2cm);
      h_set, mapping, "first_peak",
         h_new(type=2, dest=["first_peak"]);
      h_set, mapping, "bottom_peak",
         h_new(type=2, dest=["bottom_peak"]);
      h_set, mapping, "fint",
         h_new(type=2, dest=["fint"]);
      h_set, mapping, "lint",
         h_new(type=2, dest=["lint"]);
      // Equivalencies for ESRI
      h_set, mapping, "UTMX(m)", mapping("utm_x");
      h_set, mapping, "UTMY(m)", mapping("utm_y");
      h_set, mapping, "cZ(m)", mapping("z_meters");
      h_set, mapping, "Intensity(counts)", mapping("intensity_counts");
      h_set, mapping, "Raster/Pulse", mapping("raster_pulse");
      h_set, mapping, "SOE", mapping("soe");
      // Equivalencies for user-friendliness
      h_set, mapping, "intensity", mapping("intensity_counts");
      h_set, mapping, "rn", mapping("raster_pulse");
      h_set, mapping, "east", mapping("utm_x");
      h_set, mapping, "north", mapping("utm_y");
      h_set, mapping, "elev", mapping("z_meters");
      h_set, mapping, "elevation", mapping("z_meters");
      h_set, mapping, "hh:mm:ss", mapping("hhmmss");
      h_set, mapping, "yyyy-mm-dd", mapping("yyyymmdd");
      h_set, mapping, "yyyy/mm/dd", mapping("yyyymmdd");
   }

   // If none of these were specified, then we should try to auto-detect
   if(
      is_void(columns) && is_void(indx) && is_void(intensity) && is_void(rn) &&
      is_void(soe) && is_void(header) && is_void(ESRI)
   ) {
      f = open(file, "r");
      line = rdline(f, 1)(1);
      close, f;
      fields = strsplit(line, delimit);

      // Check for text field headers. The first field is always id or easting.
      if(anyof(fields(1) == ["id","Index","utm_x","UTMX(m)"])) {
         columns = fields;
         header = 1;
      } else {
         // If there's no headers, then attempt to guess
         cols = numberof(fields);
         columns = [];
         idx = 4;
         // First column is either id or easting. Easting has a decimal
         // point. Thus, lack of decimal means it's the id.
         if(idx <= cols && !strglob("*.*", fields(1))) {
            grow, columns, "id";
            idx++;
         }
         // We always have east, north, and elevation
         grow, columns, ["utm_x", "utm_y", "z_meters"];
         // The rn and soe are both going to always be more than 65k,
         // whereas intensity is always less than 65k.
         if(idx <= cols && atoi(fields(idx)) < 65536) {
            grow, columns, "intensity_counts";
            idx++;
         }
         // The rn is a long, the soe is a double. Thus, we can diffentiate
         // by checking for a decimal point.
         if(idx <= cols && !strglob("*.*", fields(idx))) {
            grow, columns, "raster_pulse";
            idx++;
         }
         if(idx <= cols && strglob("*.*", fields(idx))) {
            grow, columns, "soe";
            idx++;
         }
         idx--;
         // If the number of columns we thought we auto detected doesn't
         // match the number of columns present, then we can't trust our
         // auto detection.
         if(idx != cols) {
            columns = [];
         } else {
            header = 0;
         }
         cols = idx = [];
      }
   }
   // If we still don't know the columns, then attempt to re-construct based on
   // options passed.
   if(is_void(columns)) {
      // idx, intensity, rn, and soe are 0 by default in write_ascii_xyz
      columns = [];
      if(indx) grow, columns, "id";
      grow, columns, ["utm_x", "utm_y", "z_meters"];
      if(intensity) grow, columns, "intensity_counts";
      if(rn) grow, columns, "raster_pulse";
      if(soe) grow, columns, "soe";
   }

   if(is_void(types)) {
      types = array(0, numberof(columns));
      for(i = 1; i <= numberof(columns); i++) {
         if(h_has(mapping, columns(i)))
            types(i) = mapping(columns(i)).type;
      }
   }

   nskip = (header ? header : 0);
   cols = rdcols(file, numberof(columns), marker=delimit, type=types, nskip=nskip);

   if(is_void(pstruc)) {
      data = array(double, numberof(columns), numberof(*cols(1)));
      for(i = 1; i <= numberof(columns); i++) {
         data(i,) = (typeof(*cols(i)) == "string") ? atod(*cols(i)) : *cols(i);
      }
   } else {
      data = array(pstruc, numberof(*cols(1)));
      for(i = 1; i <= numberof(columns); i++) {
         if(h_has(mapping, columns(i))) {
            map = mapping(columns(i));
            factor = (h_has(map, "factor") ? h_get(map, "factor") : 1);
            fnc = (h_has(map, "fnc")) ? h_get(map, "fnc") : __read_ascii_xyz_store;
            for(j = 1; j <= numberof(map.dest); j++) {
               if(has_member(data, map.dest(j)))
                  fnc, data, map.dest(j), *cols(i);
            }
         }
      }
   }

   return data;
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
  if (structeq(a, FS)) {
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
  if (structeq(a, GEO)) {
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
  if (structeqany(a, VEG, VEG_, VEG__)) {
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
  if (structeq(a, CVEG_ALL)) {
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

func restore_alps_pbd(fn, vname=, skip=) {
/* DOCUMENT restore_alps_pbd, fn;
   restore_alps_pbd, fn, vname=, skip=;

   Restores data from the given file. Updates the l1pro GUI as well.
*/
   local err, fvname;
   default, skip, 1;
   data = pbd_load(fn, err, fvname);
   if(strlen(err)) {
      write, format="Unable to load file due to error: %s\n", err;
   } else {
      default, vname, fvname;
      if(skip > 1 && numberof(data))
         data = data(::skip);
      symbol_set, vname, data;
      tkcmd, swrite(format="append_varlist %s", vname);
      tkcmd, swrite(format="set pro_var %s", vname);
      set_read_yorick, data, vname=vname, fn=fn;
      write, format="Loaded variable %s\n", vname;
   }
}

func set_read_tk(junk) {
  /* DOCUMENT set_read_tk(vname)
    This function sets the variable name in the Process Eaarl Data gui
   amar nayegandhi 05/05/03
  */

   extern vname
   tkcmd, swrite(format="append_varlist %s",vname);
   tkcmd, "varplot::gui";
   tkcmd, swrite(format="set pro_var %s", vname);
   write, "Tk updated \r";

}

func set_read_yorick(data, vname=, fn=) {
/* DOCUMENT set_read_yorick(data, vname=, fn=)
   This function sets the cmin and cmax values in the Process EAARL data GUI
   amar nayegandhi 05/06/03
*/
   if(is_void(_ytk) || !_ytk)
      return;

   default, vname, string(0);
   default, fn, string(0);
   if(strlen(fn))
      fn = file_tail(fn);

   local cminmax, pmode, dmode;

   dstruc = structof(data);

   if(structeqany(dstruc, FS, R, CVEG_ALL)) {
      pmode = 0;
      dmode = 0;
      cminmax = stdev_min_max(data.elevation)/100.;
   } else if(structeqany(dstruc, GEO, GEOALL)) {
      pmode = 1;
      dmode = 1;
      cminmax = stdev_min_max(data.depth+data.elevation)/100.;
   } else if(structeqany(dstruc, VEG, VEG_, VEG__, VEGALL, VEG_ALL, VEG_ALL_)) {
      pmode = 2;
      if(anyof(regmatch("(^|_)fs(t_|_|\.|$)", [vname, fn]))) {
         dmode = 0;
         cminmax = stdev_min_max(data.elevation)/100.;
      } else {
         dmode = 3;
         cminmax = stdev_min_max(data.lelv)/100.;
      }
   }

   if(!is_void(pmode)) {
      tkcmd, swrite(format="processing_mode_by_index %d", pmode);
      tkcmd, swrite(format="display_type_by_index %d", dmode);
      tkcmd, swrite(format="set plot_settings(cmin) %.2f", cminmax(1));
      tkcmd, swrite(format="set plot_settings(cmax) %.2f", cminmax(2));
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

     if (structeq(b, FS))
        write_topo, path, file, data;
     if (structeq(b, GEO))
        write_bathy, path, file, data;
     if (structeq(b, VEG__))
        write_veg, path, file, data;
     if (structeq(b, CVEG_ALL))
        write_multipeak_veg, data, opath=path, ofname=file;
     if (structeq(b, ATM2))
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
     if (structeq(a, FS)) nvname = "fst_merged";
     if (structeq(a, GEO)) nvname = "bat_merged";
     if (structeq(a, VEG__)) nvname = "bet_merged";
     if (structeq(a, CVEG_ALL)) nvname = "mvt_merged";
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
