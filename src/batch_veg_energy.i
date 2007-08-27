
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

func batch_veg_metrics(ipath, opath=, fname=,searchstr=, plotclasses=, thresh=, fill=, min_elv=, outwin=, onlyplot=, dofma=, use_be=, be_path=, be_ss=, cl_lfpw=, onlyupdate=) {
/* DOCUMENT batch_veg_metrics(ipath, opath, searchstr=, plot=, plotclasses=)
   amar nayegandhi 10/01/04
   ipath = input path
   opath = output path (optional). Defaults to ipath
   fname = name of output file if converting only 1 file (optional). 
   searchstr = search string for input files (defaults to "*energy_merged.pbd")
   plotclass = set to 1 to plot pre-defined vegetation classes from the derived metrics
   thresh= amplitude threshold to consider significan return
   fill = set to 1 to fill in gaps in the data.  This will use the average value of the 3x3 neighbor to defien the value of the output metric. Those that are set to -1000 will be ignored. Default fill = 1.
   min_elv = minimum elevation (in meters) to consider for bare earth

   outwin = output window to plot to. (Default = 3)
   onlyplot = only plot the results of the existing metrics. (Default: void)
   dofma = clear the window before each plot during the iterative run.

   use_be = use bare earth data (in *ircf or *mf files). (Default = void)
   be_path = path name to where bare earth files are located.  only useful if use_be=1
   be_ss = search string for bare earth files, defaults to : 
           be_ss = "*n88*_merged_*rcf*.pbd";
   cl_lfpw = set to 1 to reduce the noise in the large footprint waveform. (Default cl_lfpw=1)

   onlyupdate = only make metrics files for those tiles that don't have the output metric files.  Useful when the function is re-started midway through a batch run.
*/

   // start timer
   tb1=tb2=array(double, 3);
   timer, tb1;
   if (is_void(outwin)) outwin = 3;
   if (is_void(searchstr)) searchstr = "*energy_merged.pbd";
   if (is_void(cl_lfpw)) cl_lfpw = 1;

   if (plotclasses) {
       window, outwin; 
       if (dofma) fma;
   }

   if (onlyupdate) {
      // find all *_mets*.pbd files
      s = array(string,10000);
      old_fn = array(string,1000);
      ss = "*_mets.pbd"
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
	write, format="Processing %d of %d\n", i, nfiles;
        fn_split = split_path(fn_all(i), 1, ext=1);
        eaarl = [];
        vnametag = [];
        fnametag = "_mets";
        new_fn = fn_split(1)+fnametag+fn_split(2);
        if (onlyupdate) {
           if (is_array(where(old_fn == new_fn))) continue;
	}
        if (opath) {
           fn_split = split_path(fn_all(i), 0);
	   fn1 = fn_split(2);
  	   fn_split = split_path(fn1, 1, ext=1);
 	   new_fn = opath+fn_split(1)+fnametag+fn_split(2);
        }
	// look for bare earth files if use_be = 1
  	if (use_be) {
           be_file = [];
           if (is_void(be_path)) {
	      fn_split = split_path(fn_all(i),0);
              be_dir = fn_split(1);
           } else {
              be_dir = be_path;
           }
	   // find ircf and/or mf files
     	   s = array(string,10000);
           if (is_void(be_ss)) {
                be_ss = "*n88*_merged_*rcf*.pbd";
           }
           scmd = swrite(format = "find %s -name '%s'",be_dir, be_ss);
           fp = 1; lp = 0;
           f=popen(scmd, 0);
           n = read(f,format="%s", s );
           close, f;
           lp = lp + n;
           if (n) be_file = s(fp:lp);
           fp = fp + n;
           if (numberof(be_file) == 0) {
              print, "No Bare Earth file available for this tile.  No metrics created for this tile." 
              continue;
           }
           // remove any "fs" rcfd files.
           idx = where(!strmatch(be_file, "_fs"));
           be_file = be_file(idx);
	   if (numberof(be_file) > 1) {
              // search for be_file for the same data tile
              if (strmatch(fn_split(1), "t_e")) {
                 teast_north = "";
                 sread, strpart(fn_split(1),1:18), teast_north;
	         idx = where(strmatch(be_file, teast_north)); 
                 if (is_array(idx)) {
                   be_file = be_file(idx);
                 }
              }
	      if (numberof(be_file) > 1) {
                 // now search for mf files
	         idx = where(strmatch(be_file, "mf"));
                 if (is_array(idx)) {
		   be_file = be_file(idx(1));
	         } 
	      }
	   }
           if (numberof(be_file) > 1) {
              print, "There are more than one bare earth files for this tile.  Please check code.  Cannot continue."
              be_file;
              amar();
           }
           if (numberof(be_file) == 0) {
              print, "No Bare Earth file available for this tile.  No metrics created for this tile." 
              continue;
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
  	    img = make_begrid_from_bexyz(bexyz, binsize=binsize, lfpveg=outveg);
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
   write, format="Total time taken for batch process = %f minutes\n",time(3)/60.;
   return
}

func batch_merge_veg_energy(ipath, opath=, searchstr=) {
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
       fn_split1 = split_path(fn_split(2), 1, ext=1);
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

func write_pbd_to_gdf(ipath=, opath=, fname=, searchstr=, remove_buffer=) {
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
        remove_buffer = set to 1 to remove the buffer around each tile.  The resulting gdf tile will contain only the data within the 2k by 2k tile.  All excess data will be removed. Defaults to 1.
      OUTPUT:
	
        amar nayegandhi 03/30/05.
        modified amar nayegandhi 07/21/2007 to remove buffer data around each tile.
*/
 
   extern curzone
   if (is_void(remove_buffer)) remove_buffer = 1;
   // start timer
   tb1=tb2=array(double, 3);
   timer, tb1;
   if (is_void(searchstr)) searchstr = "*energy*mets*.pbd";

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

/*
        if (remove_buffer) {
           write, "Removing buffer data around tile..."
           // conform the tile to the 2k by 2k format.
           min_e = max_n = 0;
           sread, strpart(split_path(fn_all(i), 0)(2), 4:9), min_e;
           sread, strpart(split_path(fn_all(i), 0)(2), 12:18), max_n;
           max_e = min_e + 2000;
           min_n = max_n - 2000;
           num = int(2000/binsize)+1;
           mets_tile = array(double, dim3,num,num);
           mets_tile(*) = -1000;
           minx = int((min_e  - mets_pos(1,1)) / binsize);
           maxx = int(dmets(3) - (mets_pos(1,2)-max_e) / binsize);
           miny = int((min_n  - mets_pos(2,1)) / binsize);
           maxy = int (dmets(4) - (mets_pos(2,2)-max_n) / binsize);
           tminx = tminy = 1;
           tmaxx = tmaxy = num;
           if (minx < 0) {
                // the data in this tile does not start from the beginning
                tminx = int(-minx) + 1;
                minx = 1;
           }
           if (miny < 0) {
                // the data in this tile does not start from the beginning
                tminy = int(-miny) + 1;
                miny = 1;
           } 
          if ((maxx-minx) > num) {
                // the data in this tile does not extend all the way to the end of the tile
                tmaxx += int(maxx);
                maxx = 0;
          }
          if ((maxy-miny) > num) {
                // the data in this tile does not extend all the way to the end of the tile
                tmaxy += int(maxy);
                maxy = 0;
          }
          mets_tile(,tminx:tmaxx,tminy:tmaxy)  = mets(,minx:maxx,miny:maxy);
          mets = mets_tile;
          mets_pos = [[min_e, min_n],[max_e,max_n]];
        }
 */          
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
      
func batch_metrics_ascii_output(ipath, opath=, ofname=, energy_ss=, mets_ss=, remove_buffer =) {
/* DOCUMENT
   batch_metrics_ascii_output(ipath, opath=, ofname=, energy_ss=, mets_ss=, outveg=, mets=, remove_buffer =)
   amar nayegandhi 20070308
   modified amarn 20070726.
   this function writes out a comma delimited metrics file in the following format:
   X,Y,FR,BE,CRR,HOME,N ... where N is the number of individual laser pulses in each waveform
   INPUT:
   ipath:  input path to recursively search for input files.
   opath = location where all output files will be placed.  If not set, output files be placed in corresponding input fipath.
   ofname = output file name.  Used only when converting 1 input file.
   energy_ss = search string for finding the composite footprint files,  Default = "*energy_merged.pbd"
   mets_ss = search string for finding the metric files. Default = "*_mets.pbd"
   remove_buffer = set to 1 if you want data only within the 2k by 2k tile (removes all buffer data). Defaults to 1.

*/

if (is_void(energy_ss)) energy_ss = "*energy_merged.pbd"
if (is_void(mets_ss)) mets_ss = "*_mets.pbd"
if (is_void(remove_buffer)) remove_buffer=1;

  s = array(string,10000);
  if (mets_ss) ss = mets_ss;
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
  nfiles = numberof(fn_all);

  write, format="Total number of veg metric files to convert = %d\n",nfiles;

  for (i=1;i<=nfiles;i++) {
     write, format="Converting %d of %d\n", i, nfiles;
     fn_split = split_path(fn_all(i), 1, ext=1);

     new_fn = fn_split(1)+"_asc.txt";

     fn_split = split_path(fn_all(i),0);

     if (opath) {
        fn1 = fn_split(2);
        fn_split = split_path(fn1, 1, ext=1);
        new_fn = opath+fn_split(1)+"_asc.txt";
     }
     // find corresponding energy file
     s = array(string,10000);
     scmd = swrite(format = "find %s -name '%s'",fn_split(1), energy_ss);
     fp = 1; lp = 0;
     f=popen(scmd, 0);
     n = read(f,format="%s", s );
     close, f;
     lp = lp + n;
     if (n) energy_file = s(fp:lp);
     fp = fp + n;
     if (numberof(energy_file) > 1) {
        // search for energy_file for the same data tile
        if (strmatch(fn_split(1), "t_e")) {
           teast_north = "";
           sread, strpart(fn_split(1),1:18), teast_north;
           idx = where(strmatch(energy_file, teast_north));
           if (is_array(idx)) {
             energy_file = energy_file(idx);
           }
        }
        if (numberof(energy_file) > 1) {
           // now search for merged files
           idx = where(strmatch(energy_file, "merged"));
           if (is_array(idx)) {
             energy_file = energy_file(idx(1));
           }
        }
     }
     if (numberof(energy_file) > 1) {
        print, "There are more than one composite footprint energy files for this tile.  Please check code.  Cannot continue."
        energy_file;
        error1();
     }
     if (numberof(energy_file) == 0) {
         print, "No composite footprint energy file available for this tile.  No ascii metrics created for this tile."
              error1();
     }
     fn_split = split_path(fn_all(i),0);
     s_east = strpart(fn_split(2), 4:9);
     s_north = strpart(fn_split(2), 12:18);
     east = north = 0;
     sread, s_east, format="%d",east;
     sread, s_north, format="%d",north;
     // open energy file
     f = openb(energy_file(1));
     restore, f, outveg;
     close, f;
     binsize = (outveg.east(2)-outveg.east(1))/100.;

     // open metrics file
     f = openb(fn_all(i));
     restore, f, mets, mets_pos, binsize;
     close, f;
     nx = numberof(outveg(,1));
     ny = numberof(outveg(1,));
     nbins = long(2000/binsize + 1);
     if (remove_buffer) {
        // remove points outside of the actual tile area
        east = east*100;
        north = north*100;
        idx = where((outveg.east >= east) & (outveg.east <= east+200000));
        if (is_array(idx)) {
           iidx = where((outveg.north(idx) >= north-200000) & (outveg.north(idx) <= north));
           fidx = idx(iidx);
        }
        if (numberof(fidx) < (nbins^2)) {
          // make sure the tile is complete 2k by 2k grid format
          // make complete data tile array
          northm = north/100.;
          eastm = east/100.;
          tile_array_east = span(eastm, eastm+2000, 401)(,-:1:401);
          outveg_new = array(LFP_VEG, nbins, nbins);
          mets_new = array(double,5,nbins, nbins);
          outveg_new.east = 100*span(eastm, eastm+2000, nbins)(,-:1:nbins);
          for (j=1;j<=nbins;j++) {
            outveg_new(,j).north = (northm-2000 + (j-1)*binsize)*100;
          }
          for (j=1;j<=numberof(fidx);j++) {
             j_fidx = where((outveg_new.east == outveg(fidx(j)).east) & (outveg_new.north == outveg(fidx(j)).north));
             if (j%1000 == 0) write, format="%d of %d\r",j,numberof(fidx);
             if (numberof(j_fidx) > 0) {
                outveg_new(j_fidx) = outveg(fidx(j));
                mets_new(,j_fidx) = mets(,fidx(j));
             }
          }
          outveg = outveg_new;
          mets = mets_new;
          m_idx = where(mets(1,,) == 0);
          mets(,m_idx) = -1000;
          fidx = where(outveg.east > 0);
        }
     
     } else {
        fidx = where(outveg.east > 0);
     }
     f = open(new_fn,"w")
     write, f, "East(m), North(m), CH(m), BE(m), CRR, HOME(m), #Waveforms";
     //for (j=1;j<=numberof(fidx);j++) {
        write, f, format="%10.3f, %10.3f,%5.2f,%5.2f,%5.3f,%5.2f,%3d\n",outveg(fidx).east/100., outveg(fidx).north/100., mets(1,fidx), mets(2,fidx), mets(4,fidx), mets(5,fidx), outveg(fidx).npix;
      //  write, format="Writing %d of %d\r",i;
     //}

     close, f;
 }


 return
}
