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

func batch_las_split_by_class(dir, searchstr=, files=, outdir=, update=) {
/* DOCUMENT batch_las_split_by_class, dir, searchstr=, files=, outdir=, update=
   Batch splits a set of PBD files with LAS data (in LAS_ALPS format) into
   separate files based on their classifications.

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
*/
   local tstamp;
   default, searchstr, "*.pbd";
   if(is_void(files))
      files = find(dir, glob=searchstr);

   count = numberof(files);
   timer_init, tstamp;
   for(i = 1; i <= count; i++) {
      las_split_by_class, files(i), outdir=outdir, update=update;
      timer_tick, tstamp, i, count;
   }
}

func las_split_by_class(src, outdir=, update=) {
/* DOCUMENT las_split_by_class, src, outdir=, update=
   Splits a PBD LAS file (LAS_ALPS format) into separate files based on point
   classifications.

   Parameters:
      src: The file to split.

   Options:
      outdir= Specifies the output directory where the output files should go.
         Default is alongside the source file.
      update= When enabled, existing files are skipped.
            update=0          Process all files
            update=1          Skip existing output files
*/
   default, update, 0;

   class_names = swrite(format="reserved%2d", indgen(0:31));
   class_names(1) = "notclassified";
   class_names(2) = "unclassified";
   class_names(3) = "ground";
   class_names(4) = "low_vegetation"
   class_names(5) = "medium_vegetation"
   class_names(6) = "high_vegetation"
   class_names(7) = "building"
   class_names(8) = "low_point_noise"
   class_names(9) = "model_key_point"
   class_names(10) = "water"
   class_names(13) = "overlap_point";

   fnames = swrite(format="_class%02d_%s.pbd", indgen(0:31), class_names);
   vnames = swrite(format="_c%02d_%s", indgen(0:31), class_names);

   outroot = file_rootname(src);
   if(!is_void(outdir))
      outroot = file_join(outdir, file_tail(outroot));

   data = pbd_load(src, , vname);
   classes = set_remove_duplicates(data.class);
   count = numberof(classes);
   for(i = 1; i <= count; i++) {
      w = where(data.class == classes(i));
      fn = outroot + fnames(classes(i)+1);
      if(update && file_exists(fn))
         continue;
      vn = vname + vnames(classes(i)+1);
      pbd_save, fn, vn, data(w);
      w = [];
   }
}
