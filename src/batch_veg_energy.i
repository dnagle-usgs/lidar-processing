
require, "veg_energy.i"

func batch_veg_lfpw(ipath, opath, fname=, searchstr=,binsize=, normalize=, mode=, pse=, plot=, bin=) {
  /* DOCUMENT batch_veg_lfpw(ipath, opath, binsize=, normalize=, mode=, pse=, plot=, bin=)
    This function makes large footprint waveforms in a batch mode. 
    See make_large_footprint_waveform in veg_energy.i
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
