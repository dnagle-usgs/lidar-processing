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
	   newfile = split_path(fn_all,0,ext=1)(1)+".edf";
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
