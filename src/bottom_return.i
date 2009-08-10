require, "l1pro.i";

struct BOTRET {
   long  rn;	//raster-pulse number
   short idx;	//bottom index from ex_bath
   short sidx;	//starting index of bottom return
   short range;	//range of bottom return
   float ac;	//area under the bottom return
   float cent;	//centroid of bottom return
   float centidx;	//index of centroid
   float peak;	//peak power in the bottom return
   short peakidx;	//peak power indx in the bottom return
   double soe;	//seconds of the epoch
}
   
func bot_ret_stats(rn, i, graph=, win=) {
  /*DOCUMENT get_bottom_return(rn,i,graph=,win=)
    amar nayegandhi 10/28/03
     This function uses ex_bath to get the bottom return information and returns an array of type BOTRET
   */

 extern bath_ctl, db, nostats;
 bret = BOTRET();
 rv = ex_bath(rn, i, graph=graph, win=win);
 bret.rn = rv.rastpix;
 bret.idx = rv.idx;
  
 if (is_void(nostats)) nostats = 0;
 if (bret.idx != 0) {
  // now find all returns within the waveform above the threshold
  ridx = where(db > 2);
  //check to see if there is more than 1 peak
  if (numberof(ridx) <= 1) {
     nostats++;
     //write, "No bottom stats found";
     return bret;
  }
  mpp = where(ridx(dif) > 1);
  if (is_array(mpp)) {
    mpidx = grow(1,where(ridx(dif) > 1), numberof(ridx));
    //find the peak that was chosen as the bottom
    xidx = where((ridx-rv.idx)==0);
    if (is_array(xidx)) {
     lidx = where(xidx(1) < mpidx);
    } else {
     //write, "no bottom urn found.";
     nostats++;
     return bret;
    }
    bret.sidx = ridx((mpidx(lidx(1)-1)+1));    
    end_idx = ridx((mpidx(lidx(1))));
  } else {
    bret.sidx = ridx(1);
    end_idx = ridx(0);
  }
  bret.range = end_idx - bret.sidx + 1;
  bret.ac = sum(db(bret.sidx:end_idx));
  bret.peak = db(bret.sidx:end_idx)(max);
  bret.peakidx = bret.sidx + db(bret.sidx:end_idx)(mxx);
  bret.centidx = bret.sidx +  float(  (db(bret.sidx:end_idx) * indgen(bret.range)) (sum) ) / bret.ac;
  bret.cent = float(  (db(bret.sidx:end_idx) * indgen(bret.range)) (sum) ) / (indgen(bret.range+1)(sum));
 } else {
  write, "No bottom return found."
 }

return bret
}
   

func make_ebs_from_edf(dirname, fname=, data=, write_ebs=, errorfile=) {
 /*DOCUMENT make_ebs_from_edf()
   amar nayegandhi 10/30/03
  */

extern edb, soe_day_start, data_path, nostats;

 if (is_void(write_ebs)) write_ebs = 1;
 if (is_void(fname)) {
      s = array(string, 10000);
      ss = ["*.edf"];
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

  
 for (df=1;df<=numberof(fn_all);df++) {
  write, format="*****BEGINNING File %d of %d*****\n",df,numberof(fn_all);
  sp_fn = split_path(fn_all(df),0);
  dirname = sp_fn(1);
  fname_arr = sp_fn(2);
  osp_fn = split_path(sp_fn(2), 0, ext=1);
  ofname = osp_fn(1)+".ebs";
  errfname = osp_fn(1)+".errors";
  // read the edf file
  data_ptr = read_yfile(dirname, fname_arr=fname_arr);
  data = *data_ptr(1);
  
  // make ebs array same size as data
  ebsarr = array(BOTRET,numberof(data));

  //split the data set by day
  data = data(sort(data.soe));
  idx = where(data.soe(dif) > 43200); // assume maximum of a 12 hour flight
  if (is_array(idx)) idx = grow(1,idx+1,numberof(data));
  
  //consider special case for 8-03-02
  idx03 = where(data.soe > 1028332800 & data.soe < 1028394000);
  if (is_array(idx03))  {
    //see if it is already an index value
    isidx = where(idx == idx03(1));
    if (!is_array(idx)) idx = grow(idx, idx03(1));
  }
  idx03 = where(data.soe > 1028394000 & data.soe < 1028419200);
  if (is_array(idx03))  {
    //see if it is already an index value
    isidx = where(idx == idx03(1));
    if (!is_array(idx)) idx = grow(idx, idx03(1));
  }
  idx = idx(sort(idx));
     
  ecount = 0;
  nostats = 0;

  ef = open(dirname+errfname, "w");
  for (i=1;i<=numberof(idx)-1;i++){
  //i = 7;
    daydata = data(idx(i):idx(i+1)-1); 
    st = soe2time(daydata.soe(1));
    st(3:6) = 0;
    soe_ds = time2soe(st);
    if (soe_ds == 1028332800) { // special case for 8-03-02 where there were am and pm flights
        idx03 = where(daydata.soe < 1028394000); //soe in between flights
	if (is_array(idx03)) {
            daydata = daydata(idx03);
	    load_this_edb, soe_ds;
 	    
        }
        idx03 = where(daydata.soe > 1028394000);
	if (is_array(idx03)) {
	    daydata = daydata(idx03);
	    load_this_edb, 1028394000;
	}
    } else {
	load_this_edb, soe_ds;
    }
    write, ef, format="\n****SOE day start = %d; Year = %d, Day = %d *****\n",soe_ds, st(1),st(2);

    for (j=1;j<=numberof(daydata);j++) {
	ecount++;
	rn = daydata(j).rn & 0xffffff;
	p = daydata(j).rn / 0xffffff;
        bret = bot_ret_stats(rn,p);
	if (bret.range == 0) {
    	  write, ef, format="No stats found. idx = %d, rn = %d, pulse = %d\n",bret.idx,rn,p;
        }
        bret.soe = daydata(j).soe;
	ebsarr(ecount) = bret;
        if (j%1000 == 0) write, format="%d of %d bathy stats completed for this day\r", j,numberof(daydata);
    }
    write, format="\n *** Now writing ebs data to file %s\n",ofname;
  }
  write_ebs_file, ebsarr, opath=dirname, ofname=ofname;
  close, ef;
 }
  return ebsarr
        
}


func load_this_edb(soe_ds) {
  /*
    amar nayegandhi 10/30/03.
  */

  extern edb, soe_day_start, data_path;
  
  dates_jul01 = ["7-10-01", "7-12-01", "7-13-01", "7-14-01"];
  dates_sep01 = ["9-4-01", "9-5-01", "9-6-01", "9-7-01"];
  dates_aug02 = ["8-02-02", "8-03-02-am", "8-03-02-pm", "8-04-02", "8-05-02", "8-06-02", "8-08-02", "8-09-02"];

  soe_ds_jul01 = [994723200, 994896000, 994982400, 995068800];
  soe_ds_sep01 = [999561600, 999648000, 999734400, 999820800];
  soe_ds_aug02 = [1028246400, 1028332800, 1028394000, 1028419200, 1028505600, 1028592000, 1028764800, 1028851200];

  path_jul01 = "/data/1/Fl_Keys_July_01/";
  path_sep01 = "/data/1/Fl_Keys_Sept_01/";
  path_aug02 = "/data/0/KEYS_AUG02/";
  if (soe_ds >= 1028246400) {
      idx = where(soe_ds == soe_ds_aug02);
      data_path = path_aug02+dates_aug02(idx)+"/";
      fn = data_path+"eaarl/"+dates_aug02(idx)+".idx";
  }
  if (soe_ds >= 999561600 && soe_ds < 1028246400) {
     idx = where(soe_ds == soe_ds_sep01);
     data_path=path_sep01+dates_sep01(idx)+"/";
     fn = data_path+"eaarl/"+dates_sep01(idx)+".idx";
  }
  if (soe_ds < 999561600) {
     idx = where(soe_ds == soe_ds_jul01);
     data_path=path_jul01+dates_jul01(idx)+"/";
     fn = data_path+"eaarl/"+dates_jul01(idx)+".idx";
  }
   
  data_path = data_path(1);
  write, format="Loading file %s\n",fn;
  load_edb, fn=fn(1);
     
  return
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
