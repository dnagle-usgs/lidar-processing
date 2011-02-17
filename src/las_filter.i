// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func batch_las_extract_return(dir, searchstr=, files=, outdir=, update=,
which=) {
/* DOCUMENT batch_las_extract_return, dir, searchstr=, files=, outdir=,
   update=, which=

   Extracts points from LAS_ALPS data based on whether they are first or last
   returns.

   Parameters:
      dir: Directory to find files in.

   Options:
      searchstr= Specifies which files to use.
            searchstr="*.pbd" Use all pbd files (default)
      files= Specifies which files to work with. This causes dir and searchstr
         to get ignored. Should be an array of file names if provided.
      outdir= Specifies the output directory where the output files should go.
         Default is alongside the source files.
      update= When enabled, existing files are skipped.
            update=0          Process all files
            update=1          Skip existing output files
      which= Specify whether to return first return or last return points.
            which="last"      Return last returns (default)
            which="first"     Return first returns.
*/
   local tstamp;
   default, searchstr, "*.pbd";
   default, which, "last";
   if(is_void(files))
      files = find(dir, glob=searchstr);

   suffix = (which == "last") ? "_lr" : "_fr";

   outfiles = file_rootname(files) + suffix + ".pbd";
   if(!is_void(outdir))
      outfiles = file_join(outdir, file_tail(outfiles));

   if(update) {
      w = where(!file_exists(outfiles));
      if(!numberof(w))
         return;
      files = files(w);
      outfiles = outfiles(w);
   }

   count = numberof(files);
   timer_init, tstamp;
   for(i = 1; i <= count; i++) {
      data = pbd_load(files(i), , vname);
      data = las_extract_return(data, which=which);
      pbd_save, outfiles(i), vname + suffix, data;
      timer_tick, tstamp, i, count;
   }
}

func las_extract_return(data, which=) {
/* DOCUMENT las_extract_return(data, which=)
   Extracts points from LAS_ALPS data based on whether they are first or last
   returns.

   Options:
      which= Specify whether to return first return or last return points.
            which="last"   Return last returns (default)
            which="first"  Return first returns
*/
   default, which, "last";

   w = [];
   if(which == "last") {
      w = where(data.ret_num == data.num_ret);
   } else if(which == "first") {
      w = where(data.ret_num == 1);
   } else {
      error, "Unknown value for which, must be \"first\" or \"last\"";
   }
   if(numberof(w))
      return data(w);
   else
      return [];
}
