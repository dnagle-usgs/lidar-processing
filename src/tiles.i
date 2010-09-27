// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func draw_grid(w) {
/* DOCUMENT draw_grid, w
   Draws a 10k/2k grid in window W using the window's current limits. The grid
   will contain one or more of the following kinds of grid lines:
      10km tile: violet
      2km tile: red
      1km quad: dark grey
      250m cell: light grey
   SEE ALSO: show_grid_location draw_qq_grid
*/
   local x0, x1, y0, y1;
   default, w, 5;
   old_w = current_window();
   window, w;
   ll = long(limits()/2000) * 2000;

   // Only show 10km tiles if range is >= 8km; otherwise, 2km
   if(ll(4) - ll(3) >= 8000) {
      ll = long(ll/10000)*10000;
      ll([2,4]) += 10000;
   } else {
      ll([2,4]) += 2000;
   }
   assign, ll, x0, x1, y0, y1;

   // Only show quads and cells when within 4km
   if (y1 - y0 <= 4000) {
      plgrid, indgen(y0:y1:250), indgen(x0:x1:250), color=[200,200,200],
         width=0.1;
      plgrid, indgen(y0:y1:1000), indgen(x0:x1:1000), color=[120,120,120],
         width=0.1;
   }

   // Always show 2km tile, though with a smaller width when zoomed out
   width = (y1 - y0 >= 8000) ? 3 : 5;
   plgrid, indgen(y0:y1:2000), indgen(x0:x1:2000), color=[250,140,140],
      width=width;

   // Only show 1km tiles if range is >= 8km
   if(y1 - y0 >= 8000) {
      plgrid, indgen(y0:y1:10000), indgen(x0:x1:10000), color=[170,120,170],
         width=7;
   }

   window_select, old_w;
}

func show_grid_location(m) {
/* DOCUMENT show_grid_location, win
   -or- show_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the index tile,
   data tile, quad name, and cell name.
   SEE ALSO: draw_grid show_qq_grid_location
*/
   extern curzone;
   local quad, cell;
   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }
   write, format="10km index tile : %s\n", get_utm_itcodes(m(2), m(1), curzone);
   get_utm_dt_quadcell, m(2), m(1), quad, cell;
   write, format="2km data tile   : %s   quad %s cell %d\n",
      get_utm_dtcodes(m(2), m(1), curzone), quad, cell;
}

func draw_qq_grid(win, pts=) {
/* DOCUMENT draw_qq_grid, win, pts=
   Draws a quarter quad grid for the given window. This will draw all quads and
   quarter quads that fall within the visible region in the given window. Quads
   are in red, quarter quads in grey.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.

   If the current plot crosses UTM zone boundaries, please set fixedzone.

   SEE ALSO: show_qq_grid_location draw_grid
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   extern curzone;
   if(!curzone) {
      write, "Please define curzone. draw_qq_grid aborting";
      return;
   }

   old_win = window();
   window, win;
   lims = limits();

   // Pull utm into directional variables
   w = lims(1);
   e = lims(2);
   s = lims(3);
   n = lims(4);

   // Make the limits sticky to avoid repeated redraw performance hit
   limits, w, e, s, n;

   // Get lat/lon coords for each corner
   ne = utm2ll(n, e, curzone);
   nw = utm2ll(n, w, curzone);
   se = utm2ll(s, e, curzone);
   sw = utm2ll(s, w, curzone);

   // Re-assign the directional variables to lat/lon extremes
   w = min(nw(1), sw(1));
   e = max(ne(1), se(1));
   s = min(sw(2), se(2));
   n = max(nw(2), ne(2));

   ew = 0.125 * indgen(int(floor(w*8.0)):int(ceil(e*8.0)));
   ns = 0.125 * indgen(int(floor(s*8.0)):int(ceil(n*8.0)));

   llgrid = [ew(-,), ns(,-)];
   qq = calc24qq(llgrid(*,2), llgrid(*,1));

   draw_q, qq, win, pts=pts;
   window, old_win;
}

func draw_qq(qq, win, pts=) {
/* DOCUMENT draw_qq, qq, win, pts=
   Draws a grey box for the given quarter quad(s) in the given window.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   for(i = 1; i <= numberof(qq); i++) {
      bbox = qq2ll(qq(i), bbox=1);
      draw_ll_box, bbox, win, pts=pts, color=[120,120,120];
   }
}

func draw_q(qq, win, pts=) {
/* DOCUMENT draw_qq, qq, win, pts=
   For the given quarter quad(s), red boxes will be drawn for the quads and
   grey boxes will be drawn inside for the quarter quads, in the given window.

   If given, pts= specifies how many points to drop along each side of the
   quarter quad between corners. Default is pts=3. Minimum is pts=1.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   q = set_remove_duplicates(strpart(qq, 1:-1));
   for(i = 1; i <= numberof(q); i++) {
      draw_qq, q(i) + ["a","b","c","d"], win, pts=pts;
      q_a = qq2ll(q(i)+"a", bbox=1);
      q_c = qq2ll(q(i)+"c", bbox=1);
      bbox = [q_a(1), q_a(2), q_c(3), q_c(4)];
      draw_ll_box, bbox, win, pts=pts*2+1, color=[250,20,20];
   }
}

func draw_ll_box(bbox, win, pts=, color=) {
/* DOCUMENT draw_ll_box, bbox, win, pts=, color=
   Given a lat/lon bounding box (as [south, east, north, west]), this will
   draw it in utm in the given window.

   If given pts= specifies how many points to drop along each side of the
   box between corners. Default is pts=3. Minimum is pts=1.

   If given color= specifies the color to draw with. Default is black.
*/
// Original David Nagle 2008-07-18
   if(is_void(win)) return;
   default, pts, 3;
   if(pts < 1) pts = 1;
   default, color, "black";
   ll_x = grow(
      array(bbox(2), pts+1), span(bbox(2), bbox(4), pts+2),
      array(bbox(4), pts), span(bbox(4), bbox(2), pts+2) );
   ll_y = grow(
      span(bbox(1), bbox(3), pts+2), array(bbox(3), pts),
      span(bbox(3), bbox(1), pts+2), array(bbox(1), pts+1) );
   utm = fll2utm(ll_y, ll_x);
   u_x = utm(2,);
   u_y = utm(1,);

   old_win = window();
   window, win;
   plg, u_y, u_x, color=color;
   window, old_win;
}

func show_qq_grid_location(m) {
/* DOCUMENT show_qq_grid_location, win
   -or- show_qq_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the quarter quad
   tile name.
   SEE ALSO: draw_qq_grid show_grid_location
*/
   extern curzone;
   if(!curzone) {
      write, "Aborting. Please define curzone.";
      return;
   }
   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }
   qq = get_utm_qqcodes(m(2), m(1), curzone);
   write, format="Quarter Quad: %s\n", qq(1);
}

func partition_into_2k(north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_into_2k(north, east, zone, buffer=, shorten=, verbose=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into 2km data tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      shorten= If set to 1, the tile names will be in the short form
         (e466_n3354_16). Default is long form (t_e466000_n3354000_16).
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;
   default, verbose, 0;

   if(verbose)
      write, "- Calculating 2km tile names...";
   dtcodes = get_utm_dtcode_coverage(north, east, zone);
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      dtcodes = dt_short(unref(dtcodes));
   }

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(dtcodes);
   for(i = 1; i <= numberof(dtcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(dtcodes), dtcodes(i);
      this_zone = dt2uz(dtcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_dt(data(1,), data(2,), dtcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, dtcodes(i), idx;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_into_10k(north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_into_10k(north, east, zone, buffer=, shorten=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into 10km index tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      shorten= If set to 1, the tile names will be in the short form
         (e460_n3350_16). Default is long form (i_e460000_n3350000_16).
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, shorten, 0;
   default, verbose, 0;

   if(verbose)
      write, "- Calculating 10km tile names...";
   itcodes = get_utm_itcode_coverage(north, east, zone);
   if(shorten) {
      if(verbose)
         write, "- Shortening tile names...";
      itcodes = dt_short(unref(itcodes));
   }

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(itcodes);
   for(i = 1; i <= numberof(itcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(itcodes), itcodes(i);
      this_zone = dt2uz(itcodes(i));
      data = rezone_utm(north, east, zone, this_zone);
      idx = extract_for_it(data(1,), data(2,), itcodes(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, itcodes(i), idx;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_into_qq(north, east, zone, buffer=, verbose=) {
/* DOCUMENT partition_into_qq(north, east, zone, buffer=, verbose=)
   Given a set of points represented by northing, easting, and zone, this will
   return a Yeti hash that partitions them into quarter quad tiles.

   Parameters:
      north: Northing in meters
      east: Easting in meters
      zone: Zone (must be array conforming to north/east)

   Options:
      buffer= A buffer around the tile to include, in meters. Defaults to
         100m. Set to 0 to constrain to exact tile boundaries.
      verbose= Set to 1 to get progress output. Defaults to 0 (silent).

   Returns:
      A yeti hash. The keys are the tile names, the values are the indexes
      into north/east/zone.
*/
// Original David B. Nagle 2009-04-01
   default, buffer, 100;
   default, verbose, 0;
   if(verbose)
      write, "- Calculating quarter-quad tile names...";
   qqcodes = get_utm_qqcode_coverage(north, east, zone);

   tiles = h_new();
   if(verbose)
      write, format=" - Calculating indices for %d tiles...\n", numberof(qqcodes);
   for(i = 1; i <= numberof(qqcodes); i++) {
      if(verbose)
         write, format="   * Processing %d/%d: %s\n", i, numberof(qqcodes), qqcodes(i);
      w = extract_for_qq(north, east, zone, qqcodes(i), buffer=buffer);
      if(numberof(w))
         h_set, tiles, qqcodes(i), w;
      else if(verbose)
         write, "    !! No points found, discarding tile!";
   }
   return tiles;
}

func partition_by_tile_type(type, north, east, zone, buffer=, shorten=, verbose=) {
/* DOCUMENT partition_by_tile_type(type, north, east, zone, buffer=, shorten=, verbose=)
   This is a wrapper around other partition types that allows the user to call
   the right one based on a type parameter.

   There are three legal values for type. They are listed below along with the
   functions each maps to.
      qq --> partition_into_qq
      2k --> partition_into_2k
      10k --> partition_into_10k

   Also:
      dt --> Alias for 2k
      it --> Alias for 10k

   Arguments and options are passed to the functions as is, as appropriate.
*/
// Original David B. Nagle 2009-04-01
   if(type == "qq") {
      return partition_into_qq(north, east, zone, buffer=buffer, verbose=verbose);
   } else if(type == "2k" || type == "dt") {
      return partition_into_2k(north, east, zone, buffer=buffer, verbose=verbose,
         shorten=shorten);
   } else if(type == "10k" || type == "it") {
      return partition_into_10k(north, east, zone, buffer=buffer, verbose=verbose,
         shorten=shorten);
   } else {
      error, "Invalid type";
   }
}

func partition_type_summary(north, east, zone, buffer=) {
/* DOCUMENT partition_type_summary, north, east, zone, buffer=
   Displays a summary of what the results would be for each of the
   partitioning schemes.
*/
// Original David B. Nagle 2009-04-07
   schemes = ["10k", "qq", "2k"];
   for(i = 1; i <= numberof(schemes); i++) {
      tiles = partition_by_tile_type(schemes(i), north, east, zone,
         buffer=buffer);
      write, format="Summary for: %s\n", schemes(i);
      tile_names = h_keys(tiles);
      write, format="  Number of tiles: %d\n", numberof(tile_names);
      counts = array(long, numberof(tile_names));
      for(j = 1; j <= numberof(tile_names); j++) {
         counts(j) = numberof(tiles(tile_names(j)));
      }
      qs = long(quartiles(counts));
      write, format="  Images per tile:%s", "\n";
      write, format="            Minimum: %d\n", counts(min);
      write, format="    25th percentile: %d\n", qs(1);
      write, format="    50th percentile: %d\n", qs(2);
      write, format="    75th percentile: %d\n", qs(3);
      write, format="            Maximum: %d\n", counts(max);
      write, format="               Mean: %d\n", long(counts(avg));
      write, format="                RMS: %.2f\n", counts(rms);
      write, format="%s", "\n";
   }
}

func save_data_to_tiles(data, zone, dest_dir, scheme=, mode=, suffix=, buffer=,
shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=, split_days=,
day_shift=) {
/* DOCUMENT save_data_to_tiles, data, zone, dest_dir, scheme=, mode=, suffix=,
   buffer=, shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=,
   split_days=, day_shift=

   Given an array of data (which must be in an ALPS data structure such as
   VEG__) and a scalar or array of zone corresponding to it, this will create
   PBD files in dest_dir partitioned using the given scheme.

   Parameters:
      data: Array of data in ALPS data struct
      zone: Scalar or array of UTM zone of data
      dest_dir: Destination directory for output pbd files

   Options:
      scheme= Should be one of the following; defaults to "10k2k".
         "qq" - Quarter quad tiles
         "2k" - 2-km data tiles
         "10k" - 10-km index tiles
         "10k2k" - Two-tiered index tile/data tile
      mode= Specifies the data mode to use. Can be any value valid for
         data2xyz.
            mode="fs"   First surface
            mode="ba"   Bathymetry
            mode="be"   Bare earth
      suffix= Specifies the suffix to use when naming the files. By default,
         files are named (tile-name).pbd. If suffix is provided, they will be
         named (tile-name)_(suffix).pbd. (Without the parentheses.)
      buffer= Specifies a buffer to include around each tile, in meters.
         Defaults to 100.
      shorten= By default (shorten=0), the long form of 2k, 10k, and 10k2k tile
         names will be used. If shorten=1, the short forms will be used.
      flat= If set to 1, then no directory structure will be created. Instead,
         all files will be created directly into dest_dir.
      uniq= With the default value of uniq=1, only unique data points
         (determined by soe) will be stored in the output pbd files; duplicates
         will be removed. Set uniq=0 to keep duplicate data points.
      overwrite= By default, data will be appended to any existing pbd files.
         Set overwrite=1 to clobber them instead.
      verbose= By default, progress information will be provided. Set verbose=0
         to silence it.
      split_zones= This can be set to one of the following three values:
         0 = Never split data out by zone. This is the default for most schemes.
         1 = Split data out by zone if there are multiple zones present. This
            is the default for the qq scheme.
         2 = Always split data out by zone, even if only one zone is present.
         (Note: If flat=1, split_zones is ignored.)
      split_days= Enables splitting the data by day. If enabled, the per-day
         files for each tile will be kept together and will be differentiated
         by date in the filename.
            split_days=0      Do not split by day. (default)
            split_days=1      Split by days, adding _YYYYMMDD to filename.
      day_shift= Specifies an offset in seconds to apply to the soes when
         determining their YYYYMMDD value for split_days. This can be used to
         shift time periods into the previous/next day when surveys are flown
         close to UTC midnight. The value is added to soe only for determining
         the date; the actual soe values remain unchanged.
            day_shift=0          No shift; UTC time (default)
            day_shift=-14400     -4 hours; EDT time
            day_shift=-18000     -5 hours; EST and CDT time
            day_shift=-21600     -6 hours; CST and MDT time
            day_shift=-25200     -7 hours; MST and PDT time
            day_shift=-28800     -8 hours; PST and AKDT time
            day_shift=-32400     -9 hours; AKST time
*/
// Original David Nagle 2009-07-06
   local n, e;
   default, scheme, "10k2k";
   default, mode, "fs";
   default, suffix, string(0);
   default, buffer, 100;
   default, shorten, 0;
   default, flat, 0;
   default, uniq, 1;
   default, overwrite, 0;
   default, verbose, 1;
   default, split_zones, scheme == "qq";
   default, split_days, 0;
   default, day_shift, 0;

   bilevel = scheme == "10k2k";
   if(bilevel) scheme = "2k";

   data2xyz, data, e, n, mode=mode;

   if(numberof(zone) == 1)
      zone = array(zone, dimsof(data));

   if(verbose)
      write, "Partitioning data...";
   tiles = partition_by_tile_type(scheme, n, e, zone, buffer=buffer,
      shorten=shorten, verbose=verbose);

   tile_names = h_keys(tiles);
   tile_names = tile_names(sort(tile_names));

   if(verbose)
      write, format=" Creating files for %d tiles...\n", numberof(tile_names);
   
   tile_zones = long(tile2uz(tile_names));
   uniq_zones = numberof(set_remove_duplicates(tile_zones));
   if(uniq_zones == 1 && split_zones == 1)
      split_zones = 0;
   for(i = 1; i <= numberof(tile_names); i++) {
      curtile = tile_names(i);
      idx = tiles(curtile);
      if(bilevel) {
         if(shorten)
            tiledir = file_join(
               swrite(format="i_%s", dt_short(get_dt_itcodes(curtile))),
               swrite(format="t_%s", curtile)
            );
         else
            tiledir = file_join(get_dt_itcodes(curtile), curtile);
      } else {
         tiledir = curtile;
      }
      vdata = data(idx);
      vzone = zone(idx);
      vname = (scheme == "qq") ? curtile : dt_short(curtile);
      tzone = tile_zones(i);

      // Coerce zones
      rezone_data_utm, vdata, vzone, tzone;

      outpath = dest_dir;
      if(!flat && split_zones)
         outpath = file_join(outpath, swrite(format="zone_%d", tzone));
      if(!flat && tiledir)
         outpath = file_join(outpath, tiledir);
      mkdirp, outpath;

      if(split_days) {
         dates = soe2date(vdata.soe + day_shift);
         date_uniq = set_remove_duplicates(dates);
         for(j = 1; j <= numberof(date_uniq); j++) {
            date_suffix = "_" + regsub("-", date_uniq(j), "", all=1);
            outfile = curtile + date_suffix;
            if(suffix) outfile += "_" + suffix;
            if(strpart(outfile, -3:) != ".pbd")
               outfile += ".pbd";

            outdest = file_join(outpath, outfile);

            if(overwrite && file_exists(outdest))
               remove, outdest;

            dname = vname + date_suffix;
            dw = where(dates == date_uniq(j));

            pbd_append, outdest, dname, vdata(dw), uniq=uniq;

            if(verbose)
               write, format=" %d: %s\n", i, outfile;
         }
      } else {
         outfile = curtile;
         if(suffix) outfile += "_" + suffix;
         if(strpart(outfile, -3:) != ".pbd")
            outfile += ".pbd";

         outdest = file_join(outpath, outfile);

         if(overwrite && file_exists(outdest))
            remove, outdest;

         pbd_append, outdest, vname, vdata, uniq=uniq;

         if(verbose)
            write, format=" %d: %s\n", i, outfile;
      }
   }
}
