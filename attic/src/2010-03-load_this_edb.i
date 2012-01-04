/******************************************************************************\
* These functions were moved to the attic on 2010-03-16. They were removed     *
* from bottom_return.i. Functions removed are:                                 *
*     load_this_edb                                                            *
*     make_ebs_from_edf                                                        *
* These functions are hard-coded to only work with the Florida Keys datasets   *
* from 2001 and 2002; further, they are also designed to work using EDF files  *
* which are no longer prevalent in ALPS.                                       *
\******************************************************************************/

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
