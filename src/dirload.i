// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
require, "eaarl.i";
/*
The functionality in this file is intended to supercede similar functions
elsewhere, including:
   read_yfile.i -- merge_data_pbds
   zone.i -- zoneload_dt_dir, zoneload_qq_dir, __load_rezone_dir
   data_rgn_selector.i -- sel_rgn_from_datatiles
*/

func dirload(dir, outfile=, outvname=, uniq=, skip=, searchstr=, files=,
filter=, verbose=) {
/* DOCUMENT data = dirload(dir, outfile=, outvname=, uniq=, skip=, searchstr=,
   files=, filter=, verbose=)

   Loads and merges the data found in the specified directory.

   Parameter:

      dir: The directory containing files to load.

   Options:

      outfile= If specified, the merged data will be written to this filename.
         By default, no file is created.

      outvname= If outfile= is specified, then this specifies the vname to use.
         Otherwise has no effect. The default vname varies based on the
         structure of the data:
            FS       ->  outvname="fst_merged"
            GEO      ->  outvname="bat_merged"
            VEG__    ->  outvname="bet_merged"
            CVEG_ALL ->  outvname="mvt_merged"
            (other)  ->  outvname="merged"

      uniq= Specifies whether the merged data should be restricted to unique
         points using the soe values. Possible settings:
            uniq=0   Use all data points, even duplicates (default)
            uniq=1   Restrict to unique points

      skip= Specifies the "skip factor". One out of this many points will be
         kept. This must be an integer greater than or equal to one. Examples:
            skip=1   Use all points (default)
            skip=2   Use half of the points (1 of every 2)
            skip=10  Use 10% of the points (1 of every 10)
            skip=25  Use 4% of the points (1 of every 25)
         The subsampling occurs on a file-by-file basis as they are loaded.

      searchstr= A search string to use for locating files to load and marge.
         Examples:
            searchstr="*.pbd"       All pbd files (default)
            searchstr="*fs*.pbd"    All first surface files
            searchstr="*.edf"       All edf files

      files= Specifies an array of file names to load and merge. If provided,
         then the dir parameter and the searchstr option are ignored.

      filter= Advanced option. Used for specifying a filter configuration. See
         source code for details.

      verbose= Specifies how chatty the function should be. Possible options:
            verbose=0   Complete silence, unless errors encountered
            verbose=1   Provide basic progress information (default)
*/
   // no defaults for: outfile, files; default for outvname established later
   default, uniq, 0;
   default, skip, 1;
   default, searchstr, "*.pbd";
   default, verbose, 1;
   default, filter, h_new();

   // Necessary to avoid clobbering external variables for some reason.
   local idx;

   // Generate list of input files
   if(is_void(files))
      files = find(dir, glob=searchstr);

   // filter file list ...
   __dirload_apply_filter, files, h_new(), filter, "files";

   if(is_void(files)) {
      if(verbose)
         write, "No files found.";
      return [];
   }

   // Determine data structure; user's responsibility to ensure all files have
   // the same one.
   eaarl_struct = [];
   for(i = 1; i <= numberof(files); i++) {
      ext = strlower(file_extension(files(i)));
      if(anyof(ext == [".bin", ".edf"]))
         temp = edf_import(files(i));
      else
         temp = pbd_load(files(i));
      if(!is_void(temp)) {
         eaarl_struct = structof(temp);
         break;
      }
   }
   temp = [];

   if(!is_struct(eaarl_struct)) {
      if(verbose)
         write, "Unable to determine struct for data. Aborting.";
      return [];
   }

   // data - the output data, as we build it up
   // start with an array of size 10MB
   sz = long(10485760 / sizeof(eaarl_struct)) + 1;
   data = array(eaarl_struct, sz);
   sz = [];
   // end - last valid index for the data
   end = 0;

   tstamp = err = [];
   timer_init, tstamp;
   if(verbose)
      write, format=" Loading data from %d files:\n", numberof(files);
   for(i = 1; i <= numberof(files); i++) {
      if(verbose)
         timer_tick, tstamp, i, numberof(files);

      ext = strlower(file_extension(files(i)));
      err = "";
      if(anyof(ext == [".bin", ".edf"]))
         temp = edf_import(files(i));
      else
         temp = pbd_load(files(i), err);

      if(is_void(temp)) {
         if(verbose)
            write, format=" !! %s: Skipping, %s\n", file_tail(files(i)), err;
         continue;
      }

      // filter data ...
      state = h_new(fn=files(i), cur=i, cnt=numberof(files));
      __dirload_apply_filter, temp, state, filter, "data";

      // The filter is allowed to eliminate all data for a file
      if(!numberof(temp))
         continue;

      // Skip gets applied on a file by file basis to keep the total memory
      // usage down
      if(numberof(temp) > 1)
         temp = unref(temp)(::skip);
      new_end = end + numberof(temp);

      // Make sure the data variable has enough space allocated
      array_allocate, data, new_end;

      data(end+1:new_end) = unref(temp);
      end = new_end;
   }

   if(end == 0) {
      if(verbose)
         write, "No data found in files.";
      return [];
   }

   data = unref(data)(:end);

   if(uniq) {
      if(verbose)
         write, "Removing duplicates...";
      idx = set_remove_duplicates(data.soe, idx=1);
      data = unref(data)(idx);
   }

   __dirload_apply_filter, data, h_new(), filter, "merged";

   if(!is_void(outfile))
      __dirload_write, outfile, outvname, &data;

   return data;
}

func dircopy(dir, outdir, searchstr=, files=, filter=, verbose=) {
/* DOCUMENT dircopy, dir, outdir, searchstr=, files=, filter=, verbose=
   Copies data from one directory to another, maintaining the directory and
   file structure.

   This function accepts the same kinds of filter= arguments as dirload.

   Parameters:
      dir: Source directory, to copy from.
      outdir: Destination directory, to copy to.

   Options:
      searchstr= A search string to use for locating files to copy. Examples:
            searchstr="*.pbd"       All pbd files (default)
            searchstr="*fs*.pbd"    All first surface files
      files= Specifies an array of file names to copy. If provided, then the
         dir parameter and the searchstr option are ignored.
      filter= Advanced option. Used for specifying a filter configuration. See
         source code for details.
      verbose= Specifies how chatty the function should be. Possible options:
            verbose=0   Complete silence, unless errors encountered
            verbose=1   Provide basic progress information (default)

   Note: Files are copied in append mode, to allow building up a copy over
   several passes. Duplicate points are eliminated.
*/
   // no defaults for: outfile, files; default for outvname established later
   default, searchstr, "*.pbd";
   default, verbose, 1;
   default, filter, h_new();

   // Generate list of input files
   if(is_void(files))
      files = find(dir, glob=searchstr);

   // filter file list ...
   __dirload_apply_filter, files, h_new(), filter, "files";

   if(is_void(files)) {
      if(verbose)
         write, "No files found.";
      return [];
   }

   local tstamp, data, vname;
   timer_init, tstamp;
   for(i = 1; i <= numberof(files); i++) {
      if(verbose)
         timer_tick, tstamp, i, numberof(files);

      data = pbd_load(files(i), , vname);

      if(!numberof(data))
         continue;

      // filter data ...
      state = h_new(fn=files(i), cur=i, cnt=numberof(files));
      __dirload_apply_filter, data, state, filter, "data";

      // The filter is allowed to eliminate all data for a file
      if(!numberof(data))
         continue;

      outfile = file_join(outdir, file_relative(dir, files(i)));
      mkdirp, file_dirname(outfile);
      pbd_append, outfile, vname, data, uniq=1;
   }
}

func dircopydiff(src, ref, dest, searchstr=, files=, verbose=) {
/* DOCUMENT dircopy, src, ref, dest, searchstr=, files=, verbose=
   Copies data from src that doesn't exist in ref to dest.

   This is intended to be used after a "dircopy". Suppose you're working with
   data that covers North Carolina and Virgina. You want to split it into
   sections for each state. First, you might decide to use dircopy to copy over
   the data for North Carolina with a command similar to this:

   dircopy, "/data/EAARL/processed/ExampleMission/Index_Tiles",
      "/data/EAARL/processed/ExampleMission/NC/Index_Tiles",
      searchstr="*.pbd", filter=dlfilter_poly(.....);

   Then you would use dircopydiff to get everything that /wasn't/ copied to
   NC/Index_Tiles so that you can work with that data without overlaps.

   dircopydiff, "/data/EAARL/processed/ExampleMission/Index_Tiles",
      "/data/EAARL/processed/ExampleMission/NC/Index_Tiles",
      "/data/EAARL/processed/ExampleMission/VA/Index_Tiles",
      searchstr="*.pbd"

   In some cases, you might need to use a more complicated series of commands
   involving temporary directories. For example, if your data covered SC, NC,
   and VA, you might need to do:
      dircopy to extract NC from Index_Tiles
      dircopydiff to extract Not_NC from Index_Tiles using NC
      dircopy to extract SC from Not_NC
      dircopydiff to extract VA from Not_NC using SC
      delete Not_NC

   Parameters:
      src: The directory that you want to copy from.
      ref: The directory to compare to. Anything that isn't in this directory
         will get copied.
      dest: The directory to copy to.

   Options:
      searchstr= A search string to use for locating files to copy. Examples:
            searchstr="*.pbd"       All pbd files (default)
            searchstr="*fs*.pbd"    All first surface files
      files= Specifies an array of file names to copy. If provided, then the
         dir parameter and the searchstr option are ignored.
      verbose= Specifies how chatty the function should be. Possible options:
            verbose=0   Complete silence, unless errors encountered
            verbose=1   Provide basic progress information (default)

   Note: Files are copied in append mode, to allow building up over several
   passes. Duplicate points are eliminated.
*/
// Original David Nagle 2010-04-28
   default, searchstr, "*.pbd";
   default, verbose, 1;

   // Generate list of input files
   if(is_void(files))
      files = find(src, glob=searchstr);

   if(is_void(files)) {
      if(verbose)
         write, "No files found.";
      return [];
   }

   local tstamp, data, vname;
   timer_init, tstamp;
   for(i = 1; i <= numberof(files); i++) {
      if(verbose)
         timer_tick, tstamp, i, numberof(files);

      data = pbd_load(files(i), , vname);

      if(!numberof(data))
         continue;

      reffile = file_join(ref, file_relative(src, files(i)));
      if(file_exists(reffile)) {
         refdata = pbd_load(reffile);
         if(numberof(refdata))
            data = extract_unique_data(data, refdata);
         refdata = [];
      }

      if(!numberof(data))
         continue;

      outfile = file_join(dest, file_relative(src, files(i)));
      mkdirp, file_dirname(outfile);
      pbd_append, outfile, vname, data, uniq=1;
   }
}

/*** PRIVATE FUNCTIONS FOR dirload ***/
func __dirload_apply_filter(&input, state, filters, name) {
   if(h_has(filters, name)) {
      filter = filters(name);
      while(!is_void(filter) && !is_void(input)) {
         void = filter.function(input, filter, state);
         filter = h_has(filter, "next") ? filter.next : [];
      }
   }
}

func __dirload_write(outfile, outvname, ptr) {
/* DOCUMENT __dirload_write, outfile, outvname, ptr;
   Used internally by dirload. Writes the merged data to a pbd file.
*/
   if(is_void(outvname)) {
      if(structeq(eaarl_struct, FS)) outvname = "fst_merged";
      else if(structeq(eaarl_struct, GEO)) outvname = "bat_merged";
      else if(structeq(eaarl_struct, VEG__)) outvname = "bet_merged";
      else if(structeq(eaarl_struct, CVEG_ALL)) outvname = "mvt_merged";
      else outvname = "merged";
   }

   pbd_save, outfile, outvname, *ptr;
}

/* FILTERS */

func dlfilter_merge_filters(filter, prev=, next=) {
/* DOCUMENT filter = dlfilter_merge_filters(filter, prev=, next=)
   Merges filters intended for dirload.

   Parameters:
      filter: Should be a filter suitable for dirload.

   Options:
      prev= If provided, should be a filter suitable for dirload. This will be
         merged with the filter parameter such that everything in prev will
         occur first.
      next= If provided, should be a filter suitable for dirload. This will be
         merged with the filter parameter such that everything in next will
         occur last.

   Returns:
      The merged filter.
*/
   if(!is_void(prev))
      filter = __dlfilter_merge_filters(prev, next=filter);
   if(!is_void(next)) {
      keys = h_keys(next);
      for(i = 1; i <= numberof(keys); i++) {
         if(h_has(filter, keys(i))) {
            temp = filter(keys(i));
            while(h_has(temp, "next")) {
               temp = temp.next;
            }
            h_set, temp, next=next(keys(i));
         } else {
            h_set, filter, keys(i), next(keys(i));
         }
      }
   }
   return filter;
}

func __dlfilter_data_rezone(&data, filter, state) {
/* DOCUMENT __dlfilter_data_rezone, data, filter, state;
   Support function for dlfilter_rezone.
*/
   zone = tile2uz(file_tail(state.fn));
   if(zone == 0)
      data = [];
   else if(zone != filter.zone)
      rezone_data_utm, data, zone, filter.zone;
}

func dlfilter_rezone(zone, prev=, next=) {
/* DOCUMENT filter = dlfilter_rezone(zone, prev=, next=)
   Creates a filter for dirload that will rezone the data.
*/
   filter = h_new(
      data=h_new(function=__dlfilter_data_rezone, zone=zone)
   );
   return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func __dlfilter_files_poly(&files, filter, state) {
/* DOCUMENT __dlfilter_files_poly, files, filter, state;
   Support function for dlfilter_poly.
*/
   poly = filter.poly;
   fbbox = [poly(1,min), poly(1,max), poly(2,min), poly(2,max)];
   keep = array(short, numberof(files));
   for(i = 1; i <= numberof(files); i++) {
      dbbox = tile2bbox(file_tail(files(i)))([4,2,1,3]);
      keep(i) = dbbox(1) <= fbbox(2) && fbbox(1) <= dbbox(2) &&
         dbbox(3) <= fbbox(4) && fbbox(3) <= dbbox(4);
   }
   w = where(keep);
   if(numberof(w))
      files = files(w);
   else
      files = [];
}

func __dlfilter_data_poly(&data, filter, state) {
/* DOCUMENT __dlfilter_data_poly, data, filter, state;
   Support function for dlfilter_poly.
*/
   idx = testPoly(filter.poly, data.east/100., data.north/100.);
   if(numberof(idx))
      data = data(idx);
   else
      data = [];
}

func dlfilter_poly(poly, prev=, next=) {
/* DOCUMENT filter = dlfilter_poly(poly, prev=, next=)
   Creates a filter for dirload that will filter using the given polygon.
*/
   if(dimsof(poly)(2) != 2)
      poly = transpose(poly);
   filter = h_new(
      files=h_new(function=__dlfilter_files_poly, poly=poly),
      data=h_new(function=__dlfilter_data_poly, poly=poly)
   );
   return dlfilter_merge_filters(filter, prev=prev, next=next);
}

func dlfilter_bbox(bbox, prev=, next=) {
/* DOCUMENT filter = dlfilter_bbox(bbox, prev=, next=)
   Creates a filter for dirload that will filter using the given bounding box.
   bbox should be [x1, y1, x2, y2].
*/
   poly = [bbox([1,3,3,1,1]), bbox([2,2,4,4,2])];
   return dlfilter_poly(poly, prev=prev, next=next);
}

// *** ALPS INTEGRATION ***

func dirload_l1pro_selpoly {
/* DOCUMENT dirload_l1pro_selpoly;
   Intergration function for YTK. Used by l1pro::dirload.
*/
   win = window();
   write, format="Draw a polygon in window %d to select the region.", win;
   ply = getPoly();
   dirload_l1pro_send, ply, "Polygon";
}

func dirload_l1pro_selbbox {
/* DOCUMENT dirload_l1pro_selbbox;
   Intergration function for YTK. Used by l1pro::dirload.
*/
   win = window();
   msg = swrite(format="Draw a box in window %d to select the region.", win);
   rgn = mouse(1, 1, msg);
   ply = transpose([rgn([1,3,3,1,1]), rgn([2,2,4,4,2])]);
   dirload_l1pro_send, ply, "Rubberband box";
}

func dirload_l1pro_sellims {
   win = window();
   lims = limits();
   ply = lims([[1,3],[1,4],[2,4],[2,3],[1,3]]);
   dirload_l1pro_send, ply, swrite(format="Window %d limits", win);
}

func dirload_l1pro_send(ply, kind) {
/* DOCUMENT dirload_l1pro_send, ply, kind;
   Intergration function for YTK. Used for l1pro::dirload.
*/
   area = poly_area(ply);
   if(area < 1e6)
      area = swrite(format="%.0f square meters", area);
   else
      area = swrite(format="%.3f square kilometers", area/1e6);
   tkcmd, swrite(format="set ::l1pro::dirload::v::region_desc {%s with area %s}",
      kind, area);

   ply = swrite(format="%.3f", ply);
   ply = "[" + ply(1,) + "," + ply(2,) + "]";
   ply(:-1) += ","
   ply = "[" + ply(sum) + "]";
   tkcmd, swrite(format="set ::l1pro::dirload::v::region_data {%s}", ply);
}
