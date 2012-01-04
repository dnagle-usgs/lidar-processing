/******************************************************************************\
* This file was created in the attic on 2010-03-16. It contains functions that *
* were made obsolete by the functions provided by edf.i. These functions, and  *
* the files they came from, are:                                               *
*     batch_edf2pbd        from batch_typ_convert.i                            *
*     batch_pbd2edf        from batch_typ_convert.i                            *
*     yfile_to_pbd         from read_yfile.i                                   *
*     pbd_to_yfile         from read_yfile.i                                   *
*     read_yfile           from read_yfile.i                                   *
*     edfrstat             from read_yfile.i                                   *
*     data_struc           from read_yfile.i                                   *
*     read_pointer_yfile   from read_yfile.i                                   *
*     plot_yfile_data      from spatial_clean.i                                *
*     write_ebs_file       from bottom_return.i                                *
*     read_ebs             from bottom_return.i                                *
*     write_geobath        from geo_bath.i                                     *
*     write_geodepth       from geo_bath.i                                     *
*     write_geoall         from geo_bath.i                                     *
*     write_bathy          from geo_bath.i                                     *
*     write_vegall         from veg.i                                          *
*     write_veg            from veg.i                                          *
*     write_multipeak_veg  from veg.i                                          *
*     write_topo           from surface_topo.i                                 *
*     write_atm            from atm.i                                          *
* Peruse edf.i for details on the new functions that replace the above.        *
\******************************************************************************/

func batch_edf2pbd(dirname, typ=, fname=) {
/* DOCUMENT edf2pbd(dirname, typ=, fname=)
 Created by Lance Mosher, June 12, 2003
 This function recursively converts *.edf files to *.pbd files. The *.pbd variable name (vname)
is set to <type>_<date>_<index>. 
<type> comes from user input 'typ='. Set typ=0 for first surface
					 typ=1 for bathymetry
					 typ=2 for bare earth topography
NOTE: If you have used batchmaker and/or pilotbatch's tag="v" for veg (bare earth) or
tag="b" for bathymetry, the program will extract the typ from this tag regardless of user input
<date> is extracted from the file name. Vname will not be set correctly if your files were not
processed using batch_process and mdate="date". 
<index> is the place in line the converted file had. To ensure a unique vname, process all data
from the same date at the same time.
*/
    require, "read_yfile.i"
    require, "dir.i"
    if (is_void(fname)) {
       s = array(string, 100000);
       ss = ["*.bin", "*.edf"];
       scmd = swrite(format = "find %s -name '%s'",dirname, ss); 
       fp = 1; lp = 0;
       for (i=1; i<=numberof(scmd); i++) {
         f=popen(scmd(i), 0); 
         n = read(f,format="%s", s ); 
         close, f;
         lp = lp + n;
         if (n) fn_all = s(fp:lp);
         fp = fp + n;
       } 
    } else {
	fn_all = array(string, 1);
        fn_all = dirname+fname;
    }
    nfiles = numberof(fn_all);
    write, format="Total number of files to Convert to PBD = %d\n",nfiles;

    for (i=1;i<=(nfiles+10);i++) {
	write, format="Converting file %d of %d\n", i, nfiles;
	ofr = split_path(fn_all(i),0);
	ofr_new = split_path(ofr(0),0,ext=1);
	t = *pointer(ofr_new(1));
        nn = where(t == '_');
        date = string(&t(nn(-1)+1:(nn(0)-1)));
	if (typ == 0) type = "fst_";
	if (typ == 1) type = "bat_";
	if (typ == 2) type = "bet_";
	tag = string(&t(nn(0)+1));
	if (tag == "v") type = "bet_";
	if (tag == "b") type = "bat_";
	if (!type) {
	  	write, "Your files are not tagged! You will need to provide a typ\n";
		return
	}
	vname = type+date+"_"+swrite(format="%d",i);
	if (i == 21) amar();
        yfile_to_pbd, fn_all(i), vname;
	}
return
}


func batch_pbd2edf(dirname, rcfmode=, onlymf=,n88=, w84=,searchstr=, update=) {
/* DOCUMENT batch_pbd2edf(dirname, rcfmode=, n88=, w84=)
        Created by Lance Mosher, June 12, 2003
        This function converts *.pbd files to *.edf files in batch mode.
        rcfmode=1: rcf'd files
        rcfmode=2: ircf'd files
	searchstr="<string>" :  Use this instead of rcfmode, onlymf, n88, w84
		Can take wildcard characters.
	update = set to 1 to skip files that have already been converted. 
		useful when starting from where you left off.
*/
    require, "read_yfile.i"
    require, "dir.i"
    if (is_void(update)) update = 0;
       s = array(string, 100000);
       ss = ["*.pbd"];
       if (is_array(searchstr)) {
           ss = [searchstr];
           scmd = swrite(format = "find %s -name '*%s*'",dirname,ss);
       } else {
          if (rcfmode == 1) ss = ["*_rcf*.pbd"];
          if (rcfmode == 2) ss = ["*_ircf*.pbd"];
          if ((rcfmode == 2) && (onlymf)) ss = ["*_ircf_mf*.pbd"];
          if (n88) {
             n88s = "n88";
          } else n88s = "";
          if (w84) {
             w84s = "w84";
          } else w84s = "";
          if ((n88) && (w84)) {
	     w84s="";
	     n88s="";
          }
          scmd = swrite(format = "find %s -name '*%s*%s*%s'",dirname, n88s, w84s, ss);
       }
       fp = 1; lp = 0;
       for (i=1; i<=numberof(scmd); i++) {
         f=popen(scmd(i), 0);
         n = read(f,format="%s", s );
         close, f;
         lp = lp + n;
         if (n) fn_all = s(fp:lp);
         fp = fp + n;
       }
    nfiles = numberof(fn_all);
    write, format="Total number of files to Convert to EDF = %d\n",nfiles;

    for (i=1;i<=nfiles;i++) {
	if (update) {
  	   // check if file exists
	   newfile = split_path(fn_all(i),0,ext=1)(1)+".edf";
	   nfiledir = split_path(newfile,0);
           scmd = swrite(format = "find %s -name '%s'",nfiledir(1), nfiledir(2));
           nf = 0;
           sss = array(string, 1);
           f = popen(scmd(1),0);
           nf = read(f, format="%s",sss);
           close, f;
           if (nf) {
              write, format="File %s already exists...\n",newfile;
              continue;
           }
        }

        write, format="Converting file %d of %d\n", i, nfiles;
        pbd_to_yfile, fn_all(i);
    }
return
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

func plot_yfile_data(data_ptr_arr, cmin =, cmax=, size=, win= ) {
 /* DOCUMENT plot_yfile_data(data_ptr_arr)
    This function plots the xyz data in a window.  The data_ptr_arr is the array returned from the function read_yfile.  This array is an array of pointers which dereferences to the actual data read from .bin files and stored in structure DEPTH.
 */
 
 if ( is_void(win) )
   win = 5; 
 window, win; fma;
 if (is_void( cmin ))  cmin = -15;
 if (is_void( cmax )) cmax = 0;
 if (is_void( size )) size = 1.4;

 no_ptrs = numberof(data_ptr_arr);

 for (i=1;i<=no_ptrs;i++) {
   data = *data_ptr_arr(i);
   plcm, data.depth/100, data.north/100, data.east/100, msize=size, cmin=cmin, cmax=cmax;
   }
   colorbar(cmin,cmax);


}

func write_ebs_file(ebsarr, opath=, ofname=, type=, append=) {
     
/* DOCUMENT write_ebs_file(ebsarr, opath=, ofname=, type=, append=) 

 This function writes a binary file containing data for bottom return statistics.
 It writes an array of structure BOTRET to a binary file.  
 Input parameter ebsarr is an array of structure BOTRET.
 

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   ebsarr	Array of structure BOTRET as returned by function 
                make_ebs_from_edf

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file.

   append=	Set this keyword to append to existing file.


   See also: make_ebs_from_edf, bot_ret_stats

*/

fn = opath+ofname;
num_rec=0;

if (is_void(append)) {
  /* open file to read/write if append keyword not 
    set(it will overwrite any previous file with same name) */
  f = open(fn, "w+b");
} else {
  /*open file to append to existing file.  Header information 
  will not be written.*/
  f = open(fn, "r+b");
}
i86_primitives, f;

if (is_void(append)) {
  /* write header information only if append keyword not set */
  if (is_void(type)) 
        type = 1001;
  nwpr = long(10);

  rec = array(long, 4);
  /* the first word in the file will decide the endian system. */
  rec(1) = 0x0000ffff;
  /* the second word defines the type of output file */
  rec(2) = type;
  /* the third word defines the number of words in each record */
  rec(3) = nwpr;
  /* the fourth word will eventually contain the total number of records.  
     We don't know the value just now, so will wait till the end. */
  rec(4) = 0;

  _write, f, 0, rec;

  byt_pos = 16; /* 4bytes , 4words */
} else {
  byt_pos = sizeof(f);
}


/* now look through the vegall array of structures and write 
 out only valid points 
*/
len = numberof(ebsarr);
num_rec = numberof(ebsarr);

 for (i=1;i<=len;i++) {
   _write, f, byt_pos, ebsarr.rn(i);
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, ebsarr.idx(i);
   byt_pos = byt_pos + 2;
   _write, f, byt_pos, ebsarr.sidx(i);
   byt_pos = byt_pos + 2;
   _write, f, byt_pos, ebsarr.range(i);
   byt_pos = byt_pos + 2;
   _write, f, byt_pos, ebsarr.ac(i);
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, ebsarr.cent(i);
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, ebsarr.centidx(i);
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, ebsarr.peak(i);
   byt_pos = byt_pos + 4;
   _write, f, byt_pos, ebsarr.peakidx(i);
   byt_pos = byt_pos + 2;
   _write, f, byt_pos, ebsarr.soe(i);
   byt_pos = byt_pos + 8;
   if ((i%1000)==0) write, format="Writing to ebs file: %d of %d\r", i, len;
 }

/* now we can write the number of records in the 3rd element 
  of the header array 
*/
if (is_void(append)) {
  _write, f, 12, num_rec;
  write, format="Number of records written = %d \n", num_rec
} else {
  num_rec_old = 0L
  _read, f, 12, num_rec_old;
  num_rec = num_rec + num_rec_old;
  write, format="Number of old records = %d \n",num_rec_old;
  write, format="Number of new records = %d \n",(num_rec-num_rec_old);
  write, format="Total number of records written = %d \n",num_rec;
  _write, f, 12, num_rec;
}

close, f;
}

func read_ebs(path, fname_arr=, initialdir=, searchstring=) {
/* DOCUMENT read_ebs(fname_arr=, initialdir=, searchstring=) 
This function reads an EAARL yorick-written binary file for bottom return statistics.
   amar nayegandhi 11/03/2003.
   Input parameters:
   path 	- Path name where the file(s) are located. Don't forget the '/' at the end of the path name.
   fname_arr	- An array of file names to be read.  This may be just 1 file name.
   initialdir   - Initial data path name to search for file.
   searchstring - search string when fname_arr= is not defined.
   Output:
   This function returns an array of pointers.  Each pointer can be dereferenced like this:
   > data_ptr = read_yfile("~/input_files/")
   > data1 = *data_ptr(1)
   > data2 = *data_ptr(2)
   */

extern fn_arr, type;

if (is_void(path)) {
   if (is_void(initialdir)) initialdir = "~/";
   ifn  = get_openfn( initialdir=initialdir, filetype="*.ebs", title="Open EBS Data File" );
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
     ss = ["*.ebs"];
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

func write_geodepth (geodepth, opath=, ofname=, type=) {
/* DOCUMENT write_geodepth (geodepth, opath=, ofname=, type=)

This function writes a binary file containing georeferenced depth data.
input parameter geodepth is an array of structure GEODEPTH, defined 
by the make_fs_bath function.

Inputs:
 geodepth	Geodepth array.
    opath=	Output data path
   ofname=	Output file name
     type=	Output data type.

Amar Nayegandhi 02/15/02.


*/
fn = opath+ofname;

/* 
   open file to read/write (it will overwrite any previous 
   file with same name) 
*/

f = open(fn, "w+b");
i86_primitives, f;

nwpr = long(4);

if (is_void(type)) type = 1;

rec = array(long, 4);

/* The first word in the file will decide the endian system. */
rec(1) = 0x0000ffff;

/* The second word defines the type of output file */
rec(2) = type;

/* The third word defines the number of words in each record */
rec(3) = nwpr;

/* The fourth word will eventually contain the total number 
   of records.  We don't know the value just now, so will wait 
   till the end. 
*/
rec(4) = 0;

_write, f, 0, rec;

byt_pos = 16; /* 4bytes , 4words */
num_rec = 0;


/* Now look through the geodepth array of structures and write 
   out only valid points 
*/
len = numberof(geodepth);

for (i=1;i<=len;i++) {
  indx = where(geodepth(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geodepth(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geodepth(i).depth(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}

func write_geobath (geobath, opath=, ofname=, type=) {
/* DOCUMENT write_geobath (geobath, opath=, ofname=, type=)

This function writes a binary file containing georeferenced 
bathymetric data.  Input parameter geodepth is an array of 
structure GEOBATH, defined by the make_fs_bath function.

Amar Nayegandhi 02/15/02.

*/


fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");
i86_primitives, f;

if (is_void(type)) type = 3;
nwpr = long(6);

rec = array(long, 4);
/* the first word in the file will decide the endian system. */
rec(1) = 0x0000ffff;
/* the second word defines the type of output file */
rec(2) = type;
/* the third word defines the number of words in each record */
rec(3) = nwpr;
/* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
rec(4) = 0;

_write, f, 0, rec;

byt_pos = 16; /* 4bytes , 4words */
num_rec = 0;


/* now look through the geobath array of structures and write out only valid points */
len = numberof(geobath);

for (i=1;i<=len;i++) {
  indx = where(geobath(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geobath(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).east(indx(j));
     byt_pos = byt_pos + 4;
     bath_arr = long((geobath(i).sr2(indx(j)))*CNSH2O2X *10);
     _write, f, byt_pos, bath_arr;
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geobath(i).depth(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geobath(i).bottom_peak(indx(j));
     byt_pos = byt_pos + 2;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}

func write_geoall (geoall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_geoall (geoall, opath=, ofname=, type=, append=) 

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure GEOALL to a binary file.  
 Input parameter geoall is an array of structure GEOALL, defined by the 
 make_fs_bath function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   geoall	Array of structure geoall as returned by function 
                make_fs_bath;

    opath= 	Directory in which output file is to be written

   ofname=	Output file name

     type=	Type of output file, currently only type = 4 is supported.

   append=	Set this keyword to append to existing file.


   See also: make_fs_bath, make_bathy

*/

fn = opath+ofname;
num_rec=0;

if (is_void(append)) {
  /* open file to read/write if append keyword not set(it will overwrite any previous file with same name) */
  f = open(fn, "w+b");
} else {
  /*open file to append to existing file.  Header information will not be written.*/
  f = open(fn, "r+b");
}
i86_primitives, f;

if (is_void(append)) {
  /* write header information only if append keyword not set */
  if (is_void(type)) {
    if (geoall.soe(1) == 0) {
      type = 4;
      nwpr = long(11);
    } else {
      type = 102;
      nwpr = long(12);
    }
  } else {
      nwpr = long(12);
  }

  rec = array(long, 4);
  /* the first word in the file will decide the endian system. */
  rec(1) = 0x0000ffff;
  /* the second word defines the type of output file */
  rec(2) = type;
  /* the third word defines the number of words in each record */
  rec(3) = nwpr;
  /* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
  rec(4) = 0;

  _write, f, 0, rec;

  byt_pos = 16; /* 4bytes , 4words */
} else {
  byt_pos = sizeof(f);
}
num_rec = 0;


/* now look through the geoall array of structures and write 
 out only valid points 
*/
len = numberof(geoall);

for (i=1;i<=len;i++) {
  indx = where(geoall(i).north != 0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     _write, f, byt_pos, geoall(i).rn(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).sr2(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geoall(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).mnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).meast(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).melevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, geoall(i).bottom_peak(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geoall(i).first_peak(indx(j));
     byt_pos = byt_pos + 2;
     _write, f, byt_pos, geoall(i).depth(indx(j));
     byt_pos = byt_pos + 2;
     if (type == 102) {
       _write, f, byt_pos, geoall(i).soe(indx(j));
       byt_pos = byt_pos + 8;
     }
     if ((i%1000)==0) write, format="%d of %d\r", i, len;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element 
  of the header array 
*/
if (is_void(append)) {
  _write, f, 12, num_rec;
  write, format="Number of records written = %d \n", num_rec
} else {
  num_rec_old = 0L
  _read, f, 12, num_rec_old;
  num_rec = num_rec + num_rec_old;
  write, format="Number of old records = %d \n",num_rec_old;
  write, format="Number of new records = %d \n",(num_rec-num_rec_old);
  write, format="Total number of records written = %d \n",num_rec;
  _write, f, 12, num_rec;
}

close, f;
}

func write_bathy(opath, ofname, depth_all, ba_depth=, bd_depth=) {
  /* DOCUMENT write_bathy(opath, ofname, depth_all, ba_depth=, bd_depth=)
    This function writes bathy data to a file.
    amar nayegandhi 09/17/02.
  */
  if (is_array(ba_depth)) {
	ba_ofname_arr = strtok(ofname, ".");
	ba_ofname = ba_ofname_arr(1)+"_bad_fr."+ba_ofname_arr(2);
	write, format="Writing array ba_depth to file: %s\n", ba_ofname;
        write_geoall, ba_depth, opath=opath, ofname=ba_ofname;
  }

  if (is_array(bd_depth)) {
	bd_ofname_arr = strtok(ofname, ".");
	bd_ofname = bd_ofname_arr(1)+"_bad_depth."+bd_ofname_arr(2);
	write, "now writing array bad_depth  to a file \r";
        write_geoall, bd_depth, opath=opath, ofname=bd_ofname;
  }


  write_geoall, depth_all, opath=opath, ofname=ofname;

}

func write_vegall (vegall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_vegall (vegall, opath=, ofname=, type=, append=)

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure VEGALL to a binary file.
 Input parameter vegall is an array of structure VEGALL, defined by the
 make_fs_veg function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   vegall   Array of structure VEGALL as returned by function
                make_fs_veg;

    opath=  Directory in which output file is to be written

   ofname=  Output file name

     type=  Type of output file.

   append=  Set this keyword to append to existing file.


   See also: make_fs_veg, make_veg

*/
   fn = opath+ofname;
   num_rec=0;

   if (is_void(append)) {
      /* open file to read/write if append keyword not
         set(it will overwrite any previous file with same name) */
      f = open(fn, "w+b");
   } else {
      /*open file to append to existing file.  Header information
        will not be written.*/
      f = open(fn, "r+b");
   }
   i86_primitives, f;

   if (is_void(append)) {
      /* write header information only if append keyword not set */
      if (is_void(type)) {
         if (vegall.soe(1) == 0) {
            type = 8;
            nwpr = long(13);
         } else {
            type = 103;
            nwpr = long(14);
         }
      } else {
         nwpr = long(14);
      }

      rec = array(long, 4);
      /* the first word in the file will decide the endian system. */
      rec(1) = 0x0000ffff;
      /* the second word defines the type of output file */
      rec(2) = type;
      /* the third word defines the number of words in each record */
      rec(3) = nwpr;
      /* the fourth word will eventually contain the total number of records.
         We don't know the value just now, so will wait till the end. */
      rec(4) = 0;

      _write, f, 0, rec;

      byt_pos = 16; /* 4bytes , 4words */
   } else {
      byt_pos = sizeof(f);
   }
   num_rec = 0;

   vegall = test_and_clean(unref(vegall));

   /* now look through the vegall array of structures and write
      out only valid points
    */
   len = numberof(vegall);

   for (i=1;i<=len;i++) {
      indx = where(vegall(i).north != 0);
      num_valid = numberof(indx);
      for (j=1;j<=num_valid;j++) {
         _write, f, byt_pos, vegall(i).rn(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).north(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).east(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).elevation(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).mnorth(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).meast(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).melevation(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).lnorth(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).least(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).lelv(indx(j));
         byt_pos = byt_pos + 4;
         _write, f, byt_pos, vegall(i).fint(indx(j));
         byt_pos = byt_pos + 2;
         _write, f, byt_pos, vegall(i).lint(indx(j));
         byt_pos = byt_pos + 2;
         _write, f, byt_pos, vegall(i).nx(indx(j));
         byt_pos = byt_pos + 1;
         if (type == 103) {
            _write, f, byt_pos, vegall(i).soe(indx(j));
            byt_pos = byt_pos + 8;
         }
         if ((i%1000)==0) write, format="%d of %d\r", i, len;
      }
      num_rec = num_rec + num_valid;
   }

   /* now we can write the number of records in the 3rd element
      of the header array
   */
   if (is_void(append)) {
      _write, f, 12, num_rec;
      write, format="Number of records written = %d \n", num_rec;
   } else {
      num_rec_old = 0L
         _read, f, 12, num_rec_old;
      num_rec = num_rec + num_rec_old;
      write, format="Number of old records = %d \n",num_rec_old;
      write, format="Number of new records = %d \n",(num_rec-num_rec_old);
      write, format="Total number of records written = %d \n",num_rec;
      _write, f, 12, num_rec;
   }

   close, f;
}

func write_veg(opath, ofname, veg_all, ba_veg=, bd_veg=) {
/* DOCUMENT write_veg(opath, ofname, veg_all, ba_veg=, bd_veg=)
   This function writes bathy data to a file.
   amar nayegandhi 10/17/02.
*/
   if (is_array(ba_veg)) {
      ba_ofname_arr = strtok(ofname, ".");
      ba_ofname = ba_ofname_arr(1)+"_bad_fr."+ba_ofname_arr(2);
      write, format="Writing array ba_veg to file: %s\n", ba_ofname;
      write_geoall, ba_veg, opath=opath, ofname=ba_ofname;
   }
   if (is_array(bd_veg)) {
      bd_ofname_arr = strtok(ofname, ".");
      bd_ofname = bd_ofname_arr(1)+"_bad_veg."+bd_ofname_arr(2);
      write, "now writing array bad_veg  to a file \r";
      write_geoall, bd_veg, opath=opath, ofname=bd_ofname;
   }
   write_vegall, veg_all, opath=opath, ofname=ofname;
}

func write_multipeak_veg (vegall, opath=, ofname=, type=, append=) {
/* DOCUMENT write_vegall (vegall, opath=, ofname=, type=, append=)

 This function writes a binary file containing georeferenced EAARL data.
 It writes an array of structure CVEG_ALL to a binary file.
 Input parameter vegall is an array of structure CVEG_ALL, defined by the
 make_fs_veg function.

 Amar Nayegandhi 05/07/02.

   The input parameters are:

   vegall   Array of structure CVEG_ALL as returned by function
                make_veg with multipeaks keyword set;

    opath=  Directory in which output file is to be written

   ofname=  Output file name

     type=  Type of output file, currently type = 7 is supported
                for multipeaks veg data.

   append=  Set this keyword to append to existing file.


   See also: make_veg, make_fs_veg_all, run_veg_all, ex_veg_all

*/

   fn = opath+ofname;
   num_rec=0;

   if (is_void(append)) {
      /* open file to read/write if append keyword not set(it will overwrite any previous file with same name) */
      f = open(fn, "w+b");
   } else {
      /*open file to append to existing file.  Header information will not be written.*/
      f = open(fn, "r+b");
   }
   i86_primitives, f;

   if (is_void(append)) {
      /* write header information only if append keyword not set */
      if (is_void(type)) {
         if (vegall.soe(1) == 0) {
            type = 7;
            nwpr = long(9);
         } else {
            type = 104;
            nwpr = long(10);
         }
      } else {
         nwpr = 10;
      }

      rec = array(long, 4);
      /* the first word in the file will decide the endian system. */
      rec(1) = 0x0000ffff;
      /* the second word defines the type of output file */
      rec(2) = type;
      /* the third word defines the number of words in each record */
      rec(3) = nwpr;
      /* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
      rec(4) = 0;

      _write, f, 0, rec;

      byt_pos = 16; /* 4bytes , 4words */
   } else {
      byt_pos = sizeof(f);
   }
   num_rec = 0;


   /* now look through the vegall array of structures and write
      out only valid points
    */

   /* call function clean_cveg_all to remove erroneous data. */
   write, "Cleaning data ... ";
   vegall = clean_cveg_all(vegall);
   write, "Writing data to file... ";
   len = numberof(vegall);

   for (i=1;i<=len;i++) {
      _write, f, byt_pos, vegall(i).rn;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).north;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).east;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).elevation;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).mnorth;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).meast;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).melevation;
      byt_pos = byt_pos + 4;
      _write, f, byt_pos, vegall(i).intensity;
      byt_pos = byt_pos + 2;
      _write, f, byt_pos, vegall(i).nx;
      byt_pos = byt_pos + 1;
      if (type == 104) {
         _write, f, byt_pos, vegall(i).soe;
         byt_pos = byt_pos + 8;
      }
      if ((i%1000)==0) write, format="%d of %d\r", i, len;

      num_rec++;
   }

   /* now we can write the number of records in the 3rd element
      of the header array
    */
   if (is_void(append)) {
      _write, f, 12, num_rec;
      write, format="Number of records written = %d \n", num_rec
   } else {
      num_rec_old = 0L
         _read, f, 12, num_rec_old;
      num_rec = num_rec + num_rec_old;
      write, format="Number of old records = %d \n",num_rec_old;
      write, format="Number of new records = %d \n",(num_rec-num_rec_old);
      write, format="Total number of records written = %d \n",num_rec;
      _write, f, 12, num_rec;
   }

   close, f;
}

func write_topo(opath, ofname, fs_all, type=) {

//this function writes a binary file containing georeferenced topo data.
// amar nayegandhi 03/29/02.
fn = opath+ofname;

/* open file to read/write (it will overwrite any previous file with same name) */
f = open(fn, "w+b");
i86_primitives, f;

nwpr = long(9);

if (is_void(type)) {
   if (fs_all.soe(1) == 0) {
      type = 3;
      nwpr = long(8);
   } else {
      type = 101;
   }
}

rec = array(long, 4);
/* the first word in the file will define the endian system. */
rec(1) = 0x0000ffff;
/* the second word defines the type of output file */
rec(2) = type;
/* the third word defines the number of words in each record */
rec(3) = nwpr;
/* the fourth word will eventually contain the total number of records.  We don't know the value just now, so will wait till the end. */
rec(4) = 0;

a = structof(fs_all);
_write, f, 0, rec;

write, format="Writing first surface data of type %d\n",type

byt_pos = 16; /* 4bytes , 4words  for header position*/
num_rec = 0;


/* now look through the geodepth array of structures and write out only valid points */
len = numberof(fs_all);

for (i=1;i<len;i++) {
  indx = where(fs_all(i).north !=  0);   
  num_valid = numberof(indx);
  for (j=1;j<=num_valid;j++) {
     //if (a == R) {
     _write, f, byt_pos, fs_all(i).rn(indx(j));
     //} else {
     //_write, f, byt_pos, fs_all(i).rn(indx(j));
     //}
     
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).mnorth(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).meast(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).melevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).north(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).east(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).elevation(indx(j));
     byt_pos = byt_pos + 4;
     _write, f, byt_pos, fs_all(i).intensity(indx(j));
     byt_pos = byt_pos + 2;
     if (type = 101) {
       _write, f, byt_pos, fs_all(i).soe(indx(j));
       byt_pos = byt_pos + 8;
     }
     if ((i%1000)==0) write, format="%d of %d\r", i, len;
  }
  num_rec = num_rec + num_valid;
}

/* now we can write the number of records in the 3rd element of the header array */
_write, f, 12, num_rec;

close, f;
}

func write_atm(opath, ofname, atm_all, type=) {
// David Nagle 2008-08-28
   fs_all = array(FS, numberof(atm_all));
   fs_all.north = atm_all.north;
   fs_all.east = atm_all.east;
   fs_all.elevation = atm_all.elevation;
   fs_all.intensity = atm_all.fint;
   fs_all.soe = atm_all.soe;
   write_topo, opath, ofname, fs_all;
}
