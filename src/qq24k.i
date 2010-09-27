// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func calculate_qq_extents(qqdir, mode=, glob=, remove_buffers=) {
/* DOCUMENT calculate_qq_extents(qqdir, mode=, glob=, remove_buffers=)
   Calculates the lat/lon extents for a each quarter quad using the given
   directory of qq pbd files. Returns a Yeti hash with the results.
*/
   local n, e;
   fix_dir, qqdir;
   default, glob, "*.pbd";
   default, remove_buffers, 1;

   // Source files
   files = find(qqdir, glob=glob);

   qqs = h_new();

   // Iterate over the source files to determine the 2k tiles
   stamp = 0;
   timer_init, tstamp;
   write, "Scanning quarter quad data to determine extents...";
   for(i = 1; i<= numberof(files); i++) {
      timer_tick, tstamp, i, numberof(files);
      basefile = file_tail(files(i));
      qq = extract_qq(basefile);
      z = qq2uz(qq);
      
      // Load data
      data = pbd_load(files(i));
      if(!numberof(data))
         continue;
      data2xyz, unref(data), e, n, mode=mode;

      // Restrict data to tile boundaries if remove_buffers = 1
      if(remove_buffers) {
         qq_list = get_utm_qqcodes(n, e, z);
         w = where(qq == qq_list);
         if(!numberof(w)) {
            write, "  Problem: No data found after buffers removed.";
            continue;
         }
         n = n(w);
         e = e(w);
      }

      // Convert data to lat/lon
      ll = utm2ll(n, e, z);

      // Find extents
      h_set, qqs, qq, h_new(
         "n", ll(max,2),
         "s", ll(min,2),
         "e", ll(max,1),
         "w", ll(min,1)
      );
   }
   return qqs;
}

func restrict_data_extent(data, tilename, buffer=, mode=) {
/* DOCUMENT data = restrict_data_extent(data, tilename, buffer=, mode=)
   Restricts the extent of the data based on its tile.

   Parameters:
      data: An array of EAARL data (VEG__, GEO, etc.).
      tilename: The name of the tile. Works for both 2k, 10k, and qq tiles.
         This can be the exact tile name (ie. "t_e123_n4567_12") or the tile
         name can be embedded (ie. "t_e123_n3456_12_n88.pbd").

   Options:
      buffer= A buffer in meters to apply around the tile. Default is 0, which
         constrains to the exact tile boundaries. A larger buffer will include
         more data.
      mode= The mode of the data. Can be any setting valid for data2xyz.
         "fs": First surface
         "be": Bare earth (default)
         "ba": Bathy
*/
// Original David Nagle 2009-11-23
   local e, n, idx;
   default, buffer, 0;
   default, mode, "be";

   data2xyz, data, e, n, mode=mode;
   tile = dt_short(tilename);
   if(tile) {
      if(strpart(tilename, 1:2) == "i_")
         idx = extract_for_it(unref(n), unref(e), tile, buffer=buffer);
      else
         idx = extract_for_dt(unref(n), unref(e), tile, buffer=buffer);
   } else {
      tile = extract_qq(tilename);
      if(tile)
         idx = extract_for_qq(unref(n), unref(e), qq2uz(tile), tile, buffer=buffer);
   }
   if(numberof(idx)) {
      data = data(unref(idx));
   } else {
      data = [];
   }
   return data;
}
