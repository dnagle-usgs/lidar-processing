
require, "veg_energy.i"

func batch_veg_lfpw(ipath, opath, fname=, searchstr=, onlyupdate=,binsize=, normalize=, mode=, pse=, plot=, bin=) {
  /* DOCUMENT batch_veg_lfpw(ipath, opath, binsize=, normalize=, mode=, pse=, plot=, bin=)
    This function makes large footprint waveforms in a batch mode. 
    See make_large_footprint_waveform in veg_energy.i
    onlyupdate = set to 1 if you want to continue from where you left off (at the file level).
    opath = do not set if you want to write the files out to the data tiles within the input directory. 
   amar nayegandhi 09/27/04
*/

   // start timer
   tb1=tb2=array(double, 3);
   timer, tb1;

   if (is_void(fname)) {
     s = array(string,10000);
     if (datum) {
      ss = ["*"+datum+"*.pbd"];
     } else {
      ss = ["*.pbd"];
     }
     if (searchstr) ss = searchstr;
     scmd = swrite(format = "find %s -name '%s'",ipath, ss);
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
        fn_all = ipath+fname;
    }
    nfiles = numberof(fn_all);
    write, format="Total number of veg energy files to process  = %d\n",nfiles;

    if ( _ytk && (int(nfiles) != 0) ) {
     tkcmd,"destroy .batch_energy; toplevel .batch_energy; set progress 0;"
     tkcmd,swrite(format="ProgressBar .batch_energy.pb \
        -fg black \
        -troughcolor red \
        -relief raised \
        -maximum %d \
        -variable batch_energy \
        -height 30 \
        -width 400", int(nfiles) );
     tkcmd,"pack .batch_energy.pb; update;"
    }

    if (onlyupdate) {
      // find all *_energy*.pbd files
      old_fn = array(string,1000);
      ss = "*_energy*.pbd"
      scmd = swrite(format = "find %s -name '%s'",ipath, ss);
      fp = 1; lp = 0;
      for (i=1; i<=numberof(scmd); i++) {
        f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) old_fn = s(fp:lp);
        fp = fp + n;
      }
    } 

    for (i=1;i<=nfiles;i++) {
        fn_split = split_path(fn_all(i), 1, ext=1);
        eaarl = [];
        vnametag = [];
        fnametag = "_energy";
        new_fn = fn_split(1)+fnametag+fn_split(2);
        if (opath) {
           fn_split = split_path(fn_all(i), 0);
	   fn1 = fn_split(2);
  	   fn_split = split_path(fn1, 1, ext=1);
 	   new_fn = opath+fn_split(1)+fnametag+fn_split(2);
        }
        if (onlyupdate) {
           if (is_array(where(old_fn == new_fn))) continue;
	}
	   
        f = openb(fn_all(i));
        restore, f, vname;
	eaarl = get_member(f,vname);
        close, f;

        display_veg, eaarl, felv=1, cmin=-2., cmax=15., win=5, dofma=1, skip=20;
        limits, square=1;
	limits;
        pause, 2000;
        ll = limits();
        limits, ll(1)-200, ll(2)+200, ll(3)-200, ll(4)+200;

        outveg = make_large_footprint_waveform(eaarl, binsize=binsize, normalize=normalize,mode=mode, pse=pse, plot=plot, bin=bin);

        if (_ytk) 
	  tkcmd, swrite(format="set batch_energy %d",i);

	f = createb(new_fn);
	save, f, outveg;
	close, f;
    }

   // stop timer
   timer, tb2;
   time = tb2-tb1;

   write, "BATCH PROCESS FOR LFPW COMPLETE!!"
   write, format="Total time taken for batch process = %f hours\n",time(3)/3600.;
 return
}

func batch_veg_metrics(ipath, opath, fname=,searchstr=, plotclasses=, thresh=, min_elv=, outwin=, onlyplot=, dofma=, use_be=, cl_lfpw=) {
/* DOCUMENT batch_veg_metrics(ipath, opath, searchstr=, plot=, plotclasses=)
   amar nayegandhi 10/01/04
   use_be = use bare earth data (in *ircf or *mf files).
   cl_lfpw = set to 1 to reduce the noise in the large footprint waveform.
*/

   // start timer
   tb1=tb2=array(double, 3);
   timer, tb1;
   if (is_void(outwin)) outwin = 3;
   if (is_void(searchstr)) searchstr = "*energy.pbd";

   if (plotclasses) {
       window, outwin; 
       if (dofma) fma;
   }

   if (is_void(fname)) {
     s = array(string,10000);
     if (searchstr) ss = searchstr;
     scmd = swrite(format = "find %s -name '%s'",ipath, ss);
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
        fn_all = ipath+fname;
    }
    idx = strmatch(fn_all, "mets");
    fn_all = fn_all(where(!idx));
    nfiles = numberof(fn_all);
    write, format="Total number of veg energy files to process  = %d\n",nfiles;

    for (i=1;i<=nfiles;i++) {
	write, format="Processing %d of %d\r", i, nfiles;
        fn_split = split_path(fn_all(i), 1, ext=1);
        eaarl = [];
        vnametag = [];
        fnametag = "_mets";
        new_fn = fn_split(1)+fnametag+fn_split(2);
        if (opath) {
           fn_split = split_path(fn_all(i), 0);
	   fn1 = fn_split(2);
  	   fn_split = split_path(fn1, 1, ext=1);
 	   new_fn = opath+fn_split(1)+fnametag+fn_split(2);
        }
	// look for bare earth files if use_be = 1
  	if (use_be) {
	   fn_split = split_path(fn_all(i),0);
	   // find ircf and/or mf files
     	   s = array(string,10000);
           ss = "*n88_*ircf*";
           scmd = swrite(format = "find %s -name '%s'",fn_split(1), ss);
           fp = 1; lp = 0;
           f=popen(scmd, 0);
           n = read(f,format="%s", s );
           close, f;
           lp = lp + n;
           if (n) be_file = s(fp:lp);
           fp = fp + n;
	   if (numberof(be_file) > 1) {
	      idx = where(strmatch(be_file, "mf"));
              if (is_array(idx)) {
		be_file = be_file(idx(1));
	      } else {
	        be_file = be_file(1);
	      }
	   }
        }
        fn_split = split_path(fn_all(i),0);
        s_east = strpart(fn_split(2), 4:9);
        s_north = strpart(fn_split(2), 12:18);
        east = north = 0;
        sread, s_east, format="%d",east;
        sread, s_north, format="%d",north;
        f = openb(fn_all(i));
        restore, f, outveg;
        close, f;
        binsize = (outveg.east(2)-outveg.east(1))/100.;
        if (onlyplot) {
          f = openb(new_fn);
          restore, f, mets;
          close, f;
	} else {
	  if (use_be) {
	    write, "Opening bare earth data file... ";
	    f = openb(be_file(1));
	    restore, f;
	    bexyz = get_member(f,vname);
	    close, f;
	    write, "Converting bare earth xyz into a grid...";
  	    img = make_begrid_from_bexyz(bexyz, binsize=binsize, intdist=5, lfpveg=outveg);
	  }
          if (cl_lfpw) {
	   write, "cleaning composite waveform data array..."
	   outveg = clean_lfpw(outveg, beimg=img, min_elv=min_elv, max_elv=max_elv)
	  }
	   write, "computing large-footprint metrics..."
	  mets = lfp_metrics(outveg, thresh=thresh, img=img, fill=fill, min_elv=min_elv);
	  write, "writing metrics file..."
 	  // write the mets array along with the positioning information and size of bin
	  mets_pos = [[outveg(1,1).east, outveg(1,1).north], [outveg(0,0).east, outveg(0,0).north]]/100;
          f = createb(new_fn);
          save, f, mets, mets_pos, binsize;
          close, f;
        }


        if (plotclasses) {

	   outveg = outveg(2:-1,2:-1);
	   mets = mets(,2:-1,2:-1);
	   dd = dimsof(outveg);

           x0 = outveg.east(1)/100.;
           y0 = outveg.north(1)/100.;
           bin = (outveg.east(2)-outveg.east(1))/100.;

	   x1 = (east-x0)/bin;
	   y1 = (north-2000-y0)/bin;

	   x2 = (east+2000-x0)/bin;
	   y2 = (north-y0)/bin;

           if (x1 > 0) {
		startx = int(x1);
	   } else {
		startx = 1;
	   }
	   if (x2 < dd(2)) {
		stopx = int(ceil(x2));
	   } else {
		stopx = dd(2);
	   }
           
           if (y1 > 0) {
		starty = int(y1);
	   } else {
		starty = 1;
	   }
	   if (y2 < dd(3)) {
		stopy = int(ceil(y2));
	   } else {
		stopy = dd(3);
	   }

	   outveg = outveg(startx:stopx,starty:stopy);
	   mets = mets(,startx:stopx,starty:stopy);
	   if (opath) {
		opath1 = opath;
	   } else {
		opath1 = ipath;
	   }
	   plot_veg_classes, mets, outveg, win=outwin, smooth=1, write_imagefile=1, opath=opath1;
        }
     }

   // stop timer
   timer, tb2;
   time = tb2-tb1;

   write, "BATCH PROCESS FOR METRICS COMPLETE!!"
   write, format="Total time taken for batch process = %f hours\n",time(3)/3600.;
   return
}

func batch_merge_veg_energy(ipath, searchstr=) {
  // this function merges the *energy.pbd files for data tiles in a batch mode
  // amar nayegandhi 10/07/04

  if (is_void(searchstr)) searchstr = "*energy.pbd";

 
  s = array(string,10000);
  if (searchstr) ss = searchstr;
  scmd = swrite(format = "find %s -name '%s'",ipath, ss);
  fp = 1; lp = 0;
  for (i=1; i<=numberof(scmd); i++) {
      f=popen(scmd(i), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_all = s(fp:lp);
      fp = fp + n;
  }

  fn_path = array(string, numberof(fn_all));
  fn_file = array(string, numberof(fn_all));
  for (i=1;i<=numberof(fn_all);i++) {
      path = split_path(fn_all(i), 0)
      fn_path(i) = path(1);
      fn_file(i) = path(2);
  }

  xx = unique(fn_path, ret_sort=1);
 
 // now find the files in each unique path 
  for (i=1;i<=numberof(xx);i++) {
    write, format="Merging File %d of %d\r",i,numberof(xx);
    s = array(string,10000);
    scmd = swrite(format = "find %s -name '%s'",fn_path(xx(i)), ss);
    fp = 1; lp = 0;
    fn_all = [];
    for (j=1; j<=numberof(scmd); j++) {
      f=popen(scmd(j), 0);
      n = read(f,format="%s", s );
      close, f;
      lp = lp + n;
      if (n) fn_all = s(fp:lp);
      fp = fp + n;
    }
    // we need to merge
    // open the first file
    f = openb(fn_all(1));
    restore, f;
    close, f;
    outveg1 = outveg;
    fcount = 1;
    fn_split = split_path(fn_all(1), 1, ext=1);
    fnametag = "_merged";
    new_fn = fn_split(1)+fnametag+fn_split(2);
    if (opath) {
       fn_split = split_path(fn_all(1), 0);
       fn_split1 = split_path(fn_split1(2), 1, ext=1);
       new_fn = opath+fn_split1(1)+fnametag+fn_split1(2);
    }
    while (fcount < numberof(fn_all)) {
        fcount++;
        f = openb(fn_all(fcount));
        restore, f;
        close, f;
        outveg2 = outveg;
        outveg1 = merge_veg_lfpw(outveg1, outveg2);
    }
    outveg = outveg1;
    // write outveg to new file with keyword merged in it.
    f = createb(new_fn);
    save, f, outveg;
    close, f;
    
       
  }

}

func write_pbd_to_gdf(ipath=, opath=, fname=, searchstr=) {
/* DOCUMENT write_pbd_to_gdf(ipath=, opath=, file=, searchstr=) 
    This function reads in a pbd file representing a "multi-dimensional" 
    grid and writes out a binary file known as "grid data format" (gdf).
    This gdf file is readable by IDL.
     INPUT:
	ipath= Input path where pbd files are stored
	opath = output path where gdf files will be written to.  Leave 
		blank if you want to write it to the same ipath directory.
	fname= file name if you want to convert only one file.
	searchstr = set to search for specific file(s) in ipath.
      OUTPUT:
	
        amar nayegandhi 03/30/05.
*/
 
   extern curzone
   // start timer
   tb1=tb2=array(double, 3);
   timer, tb1;
   if (is_void(searchstr)) searchstr = "*energy*mets.pbd";

   if (is_void(curzone)) {
     curzone = 0L;
     read, prompt="Enter UTM Zone Number: ",curzone;
   }
   if (is_void(fname)) {
     s = array(string,10000);
     if (searchstr) ss = searchstr;
     scmd = swrite(format = "find %s -name '%s'",ipath, ss);
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
        fn_all = ipath+fname;
    }
    nfiles = numberof(fn_all);
    write, format="Total number of veg metric files to convert to gdf  = %d\n",nfiles;

    for (i=1;i<=nfiles;i++) {
	write, format="Converting %d of %d\r", i, nfiles;
        f = openb(fn_all(i));
        restore, f;
	close, f;
	if (is_void(mets_pos)) {
	  write, "Need position information in metrics file to continue... No file written"
	  continue;
	} 
        dmets = dimsof(mets);
        dim3 = 0L;
        if (dmets(1) == 2) {
	  // only 2 dimensions in mets array..
	  dim3 = 0; // # of elements in 3rd dimension
        } else {
	  dim3 = dmets(2);
        }
        fn_split = split_path(fn_all(i), 1, ext=1);
	outf = fn_split(1)+".gdf";
        f = open(outf,"w+b");
	byt_pos=0;
	_write, f, byt_pos, mets_pos; // xy position information in input file
	byt_pos = 16;
	binsize = long(binsize);
	_write, f, byt_pos, binsize; // bin size
	byt_pos += 4;
	_write, f, byt_pos, curzone; // utm zone
	byt_pos += 4;
	_write, f, byt_pos, dim3; // number of elements in 3rd dimension
	byt_pos += 4;
        _write, f, byt_pos, mets; // metrics data array
	close, f;
	mets = binsize = mets_pos = [];
   }
        
   return
}
      
