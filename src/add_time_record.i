write, "$Id$"

func add_time_record(data) {
/* DOCUMENT add_time_record(data)
  amar nayegandhi 04/03/03.
  Adds a timestamp (seconds of the epoch) from the edb to the
    processed data.
  Input:
    data:  A processed EAARL data array of type FS, GEO, VEG__ etc.
  Output:
    data:  The same data array with the timestamp (accurate to 1second)
           included for each record.
*/
   extern edb;
   indx = where(data.soe == 0);
   if (is_array(indx)) {
     //find the record numbers
     rn = data.rn(indx) & 0xffffff;
     //make sure the data are sorted by record numbers
     //sidx = sort(rn);
     //rn = rn(sidx);
     //mask = grow([1n], rn(1:-1) != rn(2:0));     
     //rn_edb = rn(where(mask));
     soe = edb(rn).seconds+(edb(rn).fseconds/1000000.);
     data.soe(indx) = soe;
   }
   return data;
}

func batch_add_time_record(dirname, date=, fname=, mode=) {
/* DOCUMENT batch_add_time_record(dirname, date=, fname=, mode=)
  Adds the timestamp to each record in a processed data file
  in a batch mode.  This timestamp (soe record) is *NOT*
  the most accurate as it searches only within the Eaarl
  database variable (edb) to find the seconds of the epoch
  for each raster.  The soe record will only be accurate to
  a second.  If the timing accuracy is required to be accurate
  to a microsecond, then please reprocess the data.

  This function should be applied to data of old formats if
  the timestamp needs to be added to each record.

  Input:
    Dirname: Directory name within which all *.bin and *.edf
             files will be modified to include the timestamp.

    date=  : A specific date to search for within the directory
             'dirname'.  For e.g. "091202".
             Note this date must be present in the filename.

    fname= : Filename that will be modified. if not defined,
             the function will modify all files in the directory.

    mode=  : Type of data to be modified.
             mode=1 for first surface topography
             mode=2 for bathymetry
             mode=3 for vegetation.

  Please note that the this function will overwrite the data
  file after adding the timestamp to each record.

    amar nayegandhi 04/03/03.
*/
     
    if (!mode) mode = 2; //default for bathymetry
    extern edb, type;
    if (is_void(fname)) {
       s = array(string, 10000);
       ss = [swrite(format="*%s*.bin",date), swrite(format="*%s*.edf",date)];
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
      fn_all = dirname+fname;
    }

    nfiles = numberof(fn_all);
    if ( _ytk && (int(nfiles) != 0) ) {
     tkcmd,"destroy .batch_add; toplevel .batch_add; set progress 0;"
     tkcmd,swrite(format="ProgressBar .batch_add.pb \
        -fg green \
        -troughcolor magenta \
        -relief raised \
        -maximum %d \
        -variable batch_add \
        -height 30 \
        -width 400", int(nfiles) );
     tkcmd,"pack .batch_add.pb; update;"
    }

    for (i=1;i<=nfiles;i++) {
        eaarl = [];
        fn_split = split_path(fn_all(i), 0);
        data_ptr = read_yfile(fn_split(1), fname_arr = fn_split(2));
	eaarl = *(data_ptr(1));
        eaarl = add_time_record(eaarl);
        
    	if (mode == 1) {
          write_topo, fn_split(1), fn_split(2), eaarl;
    	}
    	if (mode == 2) {
          write_geoall, eaarl, opath=fn_split(1), ofname=fn_split(2);
    	}
    	if (mode == 3) {
          write_vegall, eaarl, opath=fn_split(1), ofname=fn_split(2);
    	}	

    	if (_ytk)
          tkcmd, swrite(format="set batch_add %d", i)
    }

    if (_ytk) {
      tkcmd, "destroy .batch_add"
    }
}


   
