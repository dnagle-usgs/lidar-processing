/******************************************************************************\
* This file was created in the attic on 2010-01-29. It contains functions that *
* were made obsolete by function batch_tile in batch_process.i. These          *
* functions, both of which came from qq24k.i, are:                             *
*     batch_2k_to_qq                                                           *
*     batch_qq_to_2k                                                           *
* Function batch_tile does what these functions did in a more generalized way  *
* that lets you not have to worry so much about what the source format was,    *
* and lets you convert to a wider range of destination tiling schemes.         *
\******************************************************************************/

func batch_2k_to_qq(src_dir, dest_dir, mode, searchstr=, dir_struc=, prefix=,
suffix=, remove_buffers=, buffer=, uniq=) {
/* DOCUMENT batch_2k_to_qq, src_dir, dest_dir, mode, searchstr=, dir_struc=,
   prefix=, suffix=, move_buffers=, buffer=

   Crawls through a directory structure of 2km x 2km EAARL tiles to generate
   the corresponding quarter-quad tiles. Input and output are both pbd files.

   Parameters:
   
      src_dir: The source directory. This should be the root directory of the
         directory structure containing the EAARL 2kx2k tiles in pbd format
         that need to be converted into quarter quad tiles.

      dest_dir: The destination directory. The quarter quad pbd's will be
         written here.

      mode: The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface
         2 = bathy
         3 = bare earth

   Options:
      
      searchstr= The glob string to use. Narrows the criteria for inclusion in
         src_dir. Default is "*.pbd".

      dir_struc= If set to 1, the quarter quad data files will be organized
         into a directory structure in the output directory. Each tile will get
         a directory named after it. If not set (which is the default), all
         files will go into the output directory as is, without any
         subdirectory organization.

      prefix= A string to prefix at the beginning of each quarter quad file
         name. By default, there is no prefix (prefix=""). If using a prefix,
         it can optionally include a trailing "_" (if not present, it will be
         added).

      suffix= A string to suffix at the end of each quarter quad file name. By
         default, this is two letters based on the mode: 1="fs", 2="ba",
         3="be". This can optionally include a trailing ".pbd" (if not present,
         it will be added) and can optionally be preceded by a leading "_" (if
         not present, it will be added). To suppress the suffix, use suffix="".

      remove_buffers= If 1, this will clip each 2k pbd's data to the file's 2k
         extent, removing any buffer regions that may be present. If 0, then
         all data from the file will be used regardless of where it's actually
         located. The defaults to 1.

      buffer= Specifies a buffer in meters to add around each quarter quad
         tile. The buffer is a minimum, see extract_for_qq for details. Default
         is buffer=100. Use buffer=0 to suppress the buffer.

      uniq= Specifies whether data points should be contrained to only unique
         points by sod when saved to the pbd file. Default is 1. Set uniq=0 to
         avoid this constraint. (This is necessary with ATM data, which may
         have unreliable sod values.)

   Original David Nagle 2008-07-16
*/
   fix_dir, src_dir;
   fix_dir, dest_dir;
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, buffer, 100;

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   // Default a prefix that is empty
   default, prefix, "";
   if(strlen(prefix) && strpart(prefix, 0:0) != "_")
      prefix = prefix + "_";
   
   // Default a suffix that specifies data type
   default, suffix, "_" + ["fs", "ba", "be"](mode) + ".pbd";
   if(strlen(suffix)) {
      if(strpart(suffix, -3:0) != ".pbd")
         suffix = suffix + ".pbd";
      if(strpart(suffix, 1:1) != "_")
         suffix = "_" + suffix;
   }

   // Source files
   files = find(src_dir, glob=searchstr);
   files = files(sort(file_tail(files)));

   // Iterate over the source files to determine the qq tiles
   qqcodes = [];
   tstamp = 0;
   timer_init, tstamp;
   write, "Scanning source files to generate list of QQ tiles...";
   for(i = 1; i<= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files);
      basefile = file_tail(files(i));
      n = e = z = [];
      dt2utm, basefile, n, e, z;
      
      // Load data
      data = pbd_load(files(i));
      if(!numberof(data))
         continue;

      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, basefile, buffer=0);
         if(numberof(idx))
            data = unref(data)(idx);
         else
            continue;
      }

      // Get a list of the quarter quad codes represented by the data
      grow, qqcodes, get_utm_qqcode_coverage(get_member(data, north)/100.0,
         get_member(data, east)/100.0, z);
   }
   qqcodes = set_remove_duplicates(qqcodes);
   write, format=" %i QQ tiles will be generated\n", numberof(qqcodes);

   // Iterate over each source file to actually partition data
   write, "Scanning source files to generate QQ files:";
   for(i = 1; i<= numberof(files); i++) {
      // Extract UTM coordinates for data tile
      basefile = file_tail(files(i));
      n = e = z = [];
      dt2utm, basefile, n, e, z;

      write, format=" * [%d/%d] Scanning %s\n", i, numberof(files), basefile;
      
      // Load data
      data = pbd_load(files(i));
      if(!numberof(data))
         continue;
      
      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, basefile, buffer=0);
         data = data(idx);
         if(!numberof(data)) {
            write, "  Problem: No data found after buffers removed.";
            continue;
         }
      }

      // Iterate through each qq
      for(j = 1; j <= numberof(qqcodes); j++) {
         // Try to extract data for the qq
         idx = extract_for_qq(get_member(data, north)/100.0,
            get_member(data, east)/100.0, z, qqcodes(j), buffer=buffer);
         if(!numberof(idx)) // skip if no data
            continue;
         vdata = data(idx);

         // Make sure the data's zone matches the qq's zone
         qqzone = qq2uz(qqcodes(j));
         if(qqzone != z) {
            write, format="   - %s: Rezoning data %d -> %d\n", qqcodes(j), int(z), int(qqzone);
            rezone_data_utm, vdata, z, qqzone;
         }

         write, format="   - Writing for %s\n", qqcodes(j);

         // variable name is qqcode preceeded by "qq"
         vname = swrite(format="qq%s", qqcodes(j));

         // determine and create output directory
         outpath = dest_dir;
         if(dir_struc)
            outpath = outpath + qqcodes(j) + "/";
         mkdirp, outpath;

         // write data
         pbd_append, outpath + prefix + qqcodes(j) + suffix, vname, vdata, uniq=uniq;
      }
   }
}

func batch_qq_to_2k(src_dir, dest_dir, mode, searchstr=, suffix=,
remove_buffers=, buffer=, uniq=) {
/* DOCUMENT batch_qq_to_2k, src_dir, dest_dir, mode, searchstr=, suffix=,
   remove_buffers=, buffer=

   Crawls through a directory structure of quarter quad tiles to generate the
   corresponding 2km x 2km EAARL tiles. Input and output are both pbd files.

   The output directory will contain a directory structure of index tile
   directories that contain data tile directories that contain data tile files.

   Parameters:
   
      src_dir: The source directory. This should be the root directory of the
         directory structure containing the quarter quad tiles in pbd format
         that need to be converted into 2km tiles.

      dest_dir: The destination directory. The index tiles (containing data
         tiles) will be written here.

      mode: The type of EAARL data being used. Must be 1, 2, or 3 as follows:
         1 = first surface
         2 = bathy
         3 = bare earth

   Options:
      
      searchstr= The glob string to use. Narrows the criteria for inclusion in
         src_dir. Default is "*.pbd".

      suffix= A string to suffix at the end of each data tile file name. By
         default, this is two letters based on the mode: 1="fs", 2="ba",
         3="be". This can optionally include a trailing ".pbd" (if not present,
         it will be added) and can optionally be preceded by a leading "_" (if
         not present, it will be added). To suppress the suffix, use suffix="".

      remove_buffers= If 1, this will clip each qq pbd's data to the file's qq
         extent, removing any buffer regions that may be present. If 0, then
         all data from the file will be used regardless of where it's actually
         located. The defaults to 1.

      buffer= Specifies a buffer in meters to add around each data tile.
         Default is buffer=100. Use buffer=0 to suppress the buffer.

      uniq= Specifies whether data points should be contrained to only unique
         points by sod when saved to the pbd file. Default is 1. Set uniq=0 to
         avoid this constraint. (This is necessary with ATM data, which may
         have unreliable sod values.)

   Original David Nagle 2008-07-18
*/
   fix_dir, src_dir;
   fix_dir, dest_dir;
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, buffer, 100;

   // Depending on mode, set east/north to the right struct members
   if(mode == 1 || mode == 2) {
      east = "east";
      north = "north";
   } else if(mode == 3) {
      east = "least";
      north = "lnorth";
   } else {
      error, "Invalid mode.";
   }

   // Default a suffix that specifies data type
   default, suffix, "_" + ["fs", "ba", "be"](mode) + ".pbd";
   if(strlen(suffix)) {
      if(strpart(suffix, -3:0) != ".pbd")
         suffix = suffix + ".pbd";
      if(strpart(suffix, 1:1) != "_")
         suffix = "_" + suffix;
   }

   // Source files
   files = find(src_dir, glob=searchstr);
   files = files(sort(file_tail(files)));

   dtcodes = [];
   dtfiles = [];
   write, format="Batch converting quarter quads into data tiles:%s", "\n";
   for(i = 1; i<= numberof(files); i++) {
      basefile = file_tail(files(i));
      write, format="[%d/%d] %s     \r", i, numberof(files), basefile;
      qq = extract_qq(basefile);
      qqzone = qq2uz(qq);
      
      // load qq tile
      data = pbd_load(files(i));
      if(!numberof(data))
         continue;
      
      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         qq_list = get_utm_qqcodes(get_member(data, north)/100.0,
            get_member(data, east)/100.0, qqzone);
         data = data(where(qq == qq_list));
         if(numberof(data))
            continue;
      }

      // determine which data tiles are covered by dataset
      //   - note them as good
      new_dtcodes = get_utm_dtcodes(get_member(data, north)/100.0,
         get_member(data, east)/100.0, qqzone);
      dtcodes = set_union(new_dtcodes, dtcodes);
      
      // determine possible dtcodes (for buffer included)
      qq_dtcodes = get_utm_dtcode_candidates(get_member(data, north)/100.0,
         get_member(data, east)/100.0, qqzone, buffer);
      qq_itcodes = get_dt_itcodes(qq_dtcodes);

      // for each possible dtcode:
      for(j = 1; j <= numberof(qq_dtcodes); j++) {
         // extract relevant data
         idx = extract_for_dt(get_member(data, north)/100.0,
            get_member(data, east)/100.0, qq_dtcodes(j), buffer=buffer);
         if(!numberof(idx)) // skip if no data
            continue;
         vdata = data(idx);
         
         // make sure zones match; if not, rezone
         dtzone = [];
         dt2utm, qq_dtcodes(j), , , dtzone;
         if(dtzone != qqzone) 
            rezone_data_utm, vdata, dtzone, qqzone;

         // variable name is short dtcode
         vname = dt_short(qq_dtcodes(j));

         // determine and create output directory
         outpath = dest_dir + qq_itcodes(j) + "/" + qq_dtcodes(j) + "/";
         mkdirp, outpath;

         // write data
         pbd_append, outpath + qq_dtcodes(j) + suffix, vname, vdata, uniq=uniq;

         // note as created
         dtfiles = set_union(dtfiles, [outpath + qq_dtcodes(j) + suffix]);
      }
   }

   // iterate through created files and remove the ones not in the good list
   write, format="\nDeleting extraneous files...                            %s", "\n";
   dtfilecodes = dt_long(file_tail(dtfiles));
   removeidx = set_difference(dtfilecodes, dtcodes, idx=1);
   for(i = 1; i <= numberof(removeidx); i++) {
      remove, dtfiles(removeidx(i));
   }
}


