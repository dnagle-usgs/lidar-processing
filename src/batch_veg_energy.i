
require, "veg_energy.i"

func batch_veg_lfpw(ipath, opath, fname=, searchstr=, onlyupdate=,binsize=, normalize=, mode=, pse=, plot=, bin=) {
  /* DOCUMENT batch_veg_lfpw(ipath, opath, binsize=, normalize=, mode=, pse=, plot=, bin=)
    This function makes large footprint waveforms in a batch mode. 
    See make_large_footprint_waveform in veg_energy.i
    onlyupdate = set to 1 if you want to continue from where you left off (at the file level).
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

    if ( _ytk ) {
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
 	   new_fn = opath+fn_split(2);
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

        
}

func batch_veg_metrics(ipath, opath, fname=,searchstr=, plotclasses=, thresh=, min_elv=, outwin=, onlyplot=, dofma=) {
/* DOCUMENT batch_veg_metrics(ipath, opath, searchstr=, plot=, plotclasses=)
   amar nayegandhi 10/01/04
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
 	   new_fn = opath+fn_split(2);
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
        if (onlyplot) {
          f = openb(new_fn);
          restore, f, mets;
          close, f;
	} else {
	  mets = lfp_metrics(outveg, thresh=thresh, img=img, fill=fill, min_elv=min_elv);
          f = createb(new_fn);
          save, f, mets;
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
	   plot_veg_classes, mets, outveg, win=outwin, smooth=1;
        }
     }

   return
}
