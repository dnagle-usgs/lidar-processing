// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";
require, "tiles_dt.i";
require, "tiles_qq.i";

func extract_tile(text, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT extract_tile(text, dtlength=, qqprefix=)
   Attempts to extract a tile name from each string in the given array of text.

   Options:
      dtlength= Dictates which kind of data tile name is returned when a data
         tile is detected. (Note: This has no effect on index tile names.)
         Valid values:
            dtlength="short"  Returns short form (default)
            dtlength="long"   Returns long form

      dtprefix= Dictates whether data tile and index tile names should be
         prefixed with t_ and i_ prefixes, respectively.
            dtprefix=1     Apply prefix
            dtprefix=0     Omit prefix
         By default, index tiles have dtprefix=1; data tiles have dtprefix=1
         when dtlength=="long" and dtprefix=0 otherwise.

      qqprefix= Dictates whether quarter quad tiles should be prefixed with
         "qq". Useful if they're going to be used as variable names. Valid
         values:
            qqprefix=0      No prefix added (default)
            qqprefix=1      Prefix added

   The 10km/2km/1km/250m tiling structure can resulting in ambiguous tile
   names. If the tile has a prefix of i_, q_, or c_, then it is parsed as an
   index tile, quad tile, or cell tile, respectively.  Otherwise, it is parsed
   as a data tile. If the string contains both a data tile and quarter quad
   name, the data tile name takes precedence. Tiles without parseable names
   will yield the nil string.
*/
// Original David Nagle 2009-12-09
   default, dtlength, "short";
   default, qqprefix, 0;
   qq = extract_qq(text, qqprefix=qqprefix);
   dt = extract_dt(text, dtlength=dtlength, dtprefix=dtprefix);
   dtq = extract_dtquad(text, dtlength=dtlength, dtprefix=dtprefix);
   dtc = extract_dtcell(text, dtlength=dtlength, dtprefix=dtprefix);

   prefix = strpart(text, 1:2);
   is_it = "i_" == prefix;
   is_dtq = "q_" == prefix;
   is_dtc = "c_" == prefix;

   result = array(string, dimsof(text));

   w = where(strlen(dt) > 0 & is_it);
   if(numberof(w))
      result(w) = dt2it(dt(w), dtlength=dtlength, dtprefix=dtprefix);

   w = where(strlen(dtc) > 0 & is_dtc & !strlen(result));
   if(numberof(w))
      result(w) = dtc(w);

   w = where(strlen(dtq) > 0 & is_dtq & !strlen(result));
   if(numberof(w))
      result(w) = dtq(w);

   w = where(strlen(dt) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = dt(w);

   w = where(strlen(qq) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = qq(w);

   return result;
}

func guess_tile(text, dtlength=, qqprefix=) {
/* DOCUMENT guess_tile(text, dtlength=, qqprefix=)
   Calls extract_tile and returns its result if it finds a valid tile name.
   Otherwise, attempts to guess a 2km tile name from the string. This
   currently will catch 2km tile names that do not have a zone identifier in
   the string.
*/
   local e, n, z;
   extern curzone;

   tile = extract_tile(text);
   w = where(!tile);
   if(numberof(w)) {
      regmatch, "e([1-9][0-9]{2}).*n([1-9][0-9]{3})", text(w), , e, n;
      wen = where(!(!e) & !(!n));
      if(numberof(wen)) {
         zone = curzone ? curzone : 15;
         if(!curzone)
            write, "Curzone not set! Using zone 15 to dummy tile names.";
         tile(w(wen)) = swrite(format="e%s_n%s_%d", e(wen), n(wen), zone);
      }
   }
   return tile;
}

func tile_type(text) {
/* DOCUMENT tile_type(text)
   Returns string indicating the type of tile used.  The return result (scalar
   or array, depending on the input) will have strings that mean the following:
      "dtcell" - 250-meter cell tile
      "dtquad" - One-kilometer quad tile
      "dt" - Two-kilometer data tile
      "it" - Ten-kilometer index tile
      "qq" - Quarter quad tile
      (nil) - Unparseable
   See extract_tile for information about how ambiguity is handled.
*/
   qq = extract_qq(text);
   dt = extract_dt(text);
   dtq = extract_dtquad(text);
   dtc = extract_dtcell(text);

   prefix = strpart(text, 1:2);
   is_it = "i_" == prefix;
   is_dtq = "q_" == prefix;
   is_dtc = "c_" == prefix;

   result = array(string, dimsof(text));

   w = where(strlen(dt) > 0 & is_it);
   if(numberof(w))
      result(w) = "it";

   w = where(strlen(dtc) > 0 & is_dtc & !strlen(result));
   if(numberof(w))
      result(w) = "dtcell";

   w = where(strlen(dtq) > 0 & is_dtq & !strlen(result));
   if(numberof(w))
      result(w) = "dtquad";

   w = where(strlen(dt) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = "dt";

   w = where(strlen(qq) > 0 & !strlen(result));
   if(numberof(w))
      result(w) = "qq";

   return result;
}

func utm2tile(east, north, zone, type, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT utm2tile(east, north, zone, type, dtlength=, dtprefix=, qqprefix=)
   Returns the tile name for each set of east/north/zone. Wrapper around
   utm2dt, utm2it, utm2qq, utm2dtcell, and utm2dtquad.
*/
   dtfuncs = h_new(dtcell=utm2dtcell, dtquad=utm2dtquad, dt=utm2dt, it=utm2it);
   if(h_has(dtfuncs, type))
      return dtfuncs(type)(east, north, zone, dtlength=dtlength,
         dtprefix=dtprefix);
   if(type == "qq")
      return utm2qq(east, north, zone, qqprefix=qqprefix);
   return [];
}

func utm2tile_names(east, north, zone, type, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT utm2tile_names(east, north, zone, type, dtlength=, dtprefix=,
   qqprefix=)
   Returns the unique tile names for the eastings/northings/zone. Wrapper
   around utm2dt_names, utm2it_names, utm2qq_names, utm2dtcell_names, and
   utm2dtquad_names.
*/
   dtfuncs = h_new(dtcell=utm2dtcell_names, dtquad=utm2dtquad_names,
      dt=utm2dt_names, it=utm2it_names);
   if(h_has(dtfuncs, type))
      return dtfuncs(type)(east, north, zone, dtlength=dtlength,
         dtprefix=dtprefix);
   if(type == "qq")
      return utm2qq_names(east, north, zone, qqprefix=qqprefix);
   return [];
}

func tile2uz(tile) {
/* DOCUMENT tile2uz(tile)
   Attempts to return a UTM zone for each tile in the array given. This is a
   wrapper around dt2uz and qq2uz. If both yield a result, then dt2uz wins
   out. 0 indicates that neither yielded a result.
*/
   tile = extract_tile(tile);

   dt = dt2uz(tile);
   qq = qq2uz(tile);

   result = dt;
   w = where(result == 0 & qq != 0);
   if(numberof(w)) {
      if(dimsof(result)(1))
         result(w) = qq(w);
      else
         result = qq;
   }

   return result;
}

func tile2bbox(tile) {
/* DOCUMENT bbox = tile2bbox(tile)
   Returns the bounding box for a tile: [south,east,north,west].
*/
   type = tile_type(tile);
   funcs = h_new(dtcell=dtcell2utm, dtquad=dtquad2utm, dt=dt2utm, it=it2utm,
      qq=qq2utm);

   if(h_has(funcs, type))
      return funcs(type)(tile, bbox=1);
   return [];
}

func tile2centroid(tile) {
/* DOCUMENT centroid = tile2centroid(tile)
   Returns the centroid for a tile: [north,east,zone].
*/
   type = tile_type(tile);
   funcs = h_new(dtcell=dtcell2utm, dtquad=dtquad2utm, dt=dt2utm, it=it2utm,
      qq=qq2utm);

   if(h_has(funcs, type))
      return funcs(type)(tile, centroid=1);
   return [];
}

func show_grid_location(m) {
/* DOCUMENT show_grid_location, win
   -or- show_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the index tile,
   data tile, quad name, and cell name.
   SEE ALSO: draw_grid
*/
   extern curzone;
   local quad, cell;
   if(!curzone) {
      write, "Please define curzone.";
      return;
   }

   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }

   write, format="Location: %.2f east, %.2f north, zone %d\n", m(1), m(2),
      curzone;

   fmt = "%15s: %-25s -or- %s\n";
   write, format=fmt, "Quarter Quad",
      utm2qq(m(1), m(2), curzone, qqprefix=0),
      utm2qq(m(1), m(2), curzone, qqprefix=1);
   write, format=fmt, "10km Index Tile",
      utm2it(m(1), m(2), curzone, dtlength="long"),
      utm2it(m(1), m(2), curzone, dtlength="short");
   write, format=fmt, "2km Data Tile",
      utm2dt(m(1), m(2), curzone, dtlength="long"),
      utm2dt(m(1), m(2), curzone, dtlength="short");
   write, format=fmt, "250m Cell",
      utm2dtcell(m(1), m(2), curzone, dtlength="long"),
      utm2dtcell(m(1), m(2), curzone, dtlength="short");
}

func extract_for_tile(east, north, zone, tile, buffer=) {
/* DOCUMENT idx = extract_for_tile(east, north, zone, tile, buffer=);
   Returns an index into north/east of all coordinates that fall within the
   bounds of the given tile. The buffer= option specifies a value to extend
   around the tile and defaults to 100. Set buffer=0 to disable buffer.
*/
   local xmin, xmax, ymin, ymax;
   default, buffer, 100;
   tile = extract_tile(tile);
   type = tile_type(tile);
   if(is_scalar(zone))
      zone = array(zone, dimsof(north));

   if(type == "qq") {
      return extract_for_qq(east, north, zone, tile, buffer=buffer);
   } else if(!type) {
      error, "Unknown tiling type.";
   } else {
      bbox = tile2bbox(tile);
      okzone = where(bbox(5) == zone);
      if(!numberof(okzone))
         return [];
      assign, bbox(:4) + [-1,1,1,-1]*buffer, ymin, xmax, ymax, xmin;
      idx = data_box(east(okzone), north(okzone), xmin, xmax, ymin, ymax);
      if(!numberof(idx))
         return [];
      return okzone(idx);
   }
}

func restrict_data_extent(data, tile, buffer=, mode=) {
/* DOCUMENT data = restrict_data_extent(data, tile, buffer=, mode=)
   Restricts the extent of the data based on its tile.

   Parameters:
      data: An array of EAARL data (VEG__, GEO, etc.).
      tile: The name of the tile. Works for both 2k, 10k, and qq tiles.
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
   zone = tile2uz(tile);
   idx = extract_for_tile(e, n, zone, tile, buffer=buffer);
   return numberof(idx) ? data(idx) : [];
}

func partition_by_tile(east, north, zone, type, buffer=, dtlength=, dtprefix=,
qqprefix=) {
/* DOCUMENT partition_by_tile(east, north, zone, type, buffer=, dtlength=,
   dtprefix=, verbose=)
   Partitions data given by east, north, and zone into the given TYPE of tiles.
   Type may be one of the following values:
      "qq" --> quarter quads
      "it" --> index tiles
      "dt" --> data tiles
      "dtquad" --> quad tiles
      "dtcell" --> cell tiles
*/
   default, buffer, 100;
   names = utm2tile_names(east, north, zone, type, dtlength=dtlength,
      dtprefix=dtprefix, qqprefix=qqprefix);
   tiles = h_new();
   count = numberof(names);
   for(i = 1; i <= count; i++) {
      idx = extract_for_tile(east, north, zone, names(i), buffer=buffer);
      if(numberof(idx))
         h_set, tiles, names(i), idx;
   }
   return tiles;
}

func partition_type_summary(north, east, zone, buffer=, schemes=) {
/* DOCUMENT partition_type_summary, north, east, zone, buffer=, schemes=
   Displays a summary of what the results would be for each of the
   partitioning schemes.
*/
// Original David B. Nagle 2009-04-07
   default, schemes, ["it", "qq", "dt"];
   for(i = 1; i <= numberof(schemes); i++) {
      tiles = partition_by_tile(east, north, zone, schemes(i), buffer=buffer);
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
day_shift=, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT save_data_to_tiles, data, zone, dest_dir, scheme=, mode=, suffix=,
   buffer=, shorten=, flat=, uniq=, overwrite=, verbose=, split_zones=,
   split_days=, day_shift=, dtlength=, dtprefix=, qqprefix=

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
         "dt" - 2km data tiles
         "it" - 10km index tiles
         "itdt" - Two-tiered index tile/data tile
         "dtquad" - 1km quad tiles
         "dtcell" - 250m cell tiles
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
      shorten= By default (shorten=0), the long form of dt, it, and itdt tile
         names will be used. If shorten=1, the short forms will be used. This
         is shorthand for dtlength settings:
            shorten=0   -->   dtlength="long"
            shorten=1   -->   dtlength="short"
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
            split_zones=0  Never split data out by zone. This is the default
                           for most schemes.
            split_zones=1  Split data out by zone if there are multiple zones
                           present. This is the default for the qq scheme.
            split_zones=2  Always split data out by zone, even if only one zone
                           is present.
         Note: If flat=1, split_zones is ignored.
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
      dtlength= Specifies whether to use the short or long form for data tile
         (and related) schemes. By default, this is set based on shorten=.
            dtlength="long"      Use long form: t_e234000_n3456000_15
            dtlength="short"     Use short form: e234_n3456_15
      dtprefix= Specifies whether to include the type prefix for data tile (and
         related) schemes. When enabled, index tiles are prefixed by i_, data
         tiles by t_, quad tiles by q_, and cell tiles by c_.
            dtprefix=0  Exclude prefix (default for dt when dtlength=="short")
            dtprefix=1  Include prefix (default for everything else)
      qqprefix= Specifies whether to prepend "qq" to the beginning of quarter
         quad names.
            qqprefix=0  Exclude prefix (default)
            qqprefix=1  Include prefix

   SEE ALSO: batch_tile
*/
// Original David Nagle 2009-07-06
   local n, e;
   default, scheme, "itdt";
   default, mode, "fs";
   default, suffix, string(0);
   default, buffer, 100;
   default, flat, 0;
   default, uniq, 1;
   default, overwrite, 0;
   default, verbose, 1;
   default, split_zones, scheme == "qq";
   default, split_days, 0;
   default, day_shift, 0;
   default, dtlength, (shorten ? "short" : "long");

   aliases = h_new("10k2k", "itdt", "2k", "dt", "10k", "it");
   if(h_has(aliases, scheme))
      scheme = aliases(scheme);

   bilevel = scheme == "itdt";
   if(bilevel) scheme = "dt";

   data2xyz, data, e, n, mode=mode;

   if(numberof(zone) == 1)
      zone = array(zone, dimsof(data));

   if(verbose)
      write, "Partitioning data...";
   tiles = partition_by_tile(e, n, zone, scheme, buffer=buffer,
      dtlength=dtlength, dtprefix=dtprefix, qqprefix=qqprefix);

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
         tiledir = file_join(dt2it(curtile, dtlength=dtlength,
            dtprefix=dtprefix), curtile);
      } else {
         tiledir = curtile;
      }
      vdata = data(idx);
      vzone = zone(idx);
      vname = (scheme == "qq") ? curtile : extract_dt(curtile);
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

func batch_tile(srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
split_zones=, split_days=, day_shift=, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT batch_tile, srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
   remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
   split_zones=, split_days=, day_shift=, dtlength=, dtprefix=, qqprefix=

   Loads the data in srcdir that matches searchstr= and partitions it into
   tiles, which are created in dstdir.

   Note: This operates in an "append" mode. If there are already files that
   have the same names as the files you are trying to create, they will be
   appended to. If you do not want that... delete them first!

   Parameters:
      srcdir: Directory of PBD data you want to tile.
      dstdir: Directory where your tiled data should go.

   Options:
      scheme= Partioning scheme to use. Valid values:
            scheme="itdt"     Tiered 10km/2km structure (default)
            scheme="dt"       2km structure
            scheme="it"       10km structure
            scheme="qq"       Quarter quad structure
      mode= Mode of data. Valid values include:
            mode="fs"         First surface (default)
            mode="be"         Bare earth
            mode="ba"         Bathy
      searchstr= Search string to use when locating input data. Example:
            searchstr="*.pbd"    (default)
      suffix= Suffix to append to file names when creating them. If your suffix
         does not end in .pbd, it will be auto-appended. Examples:
            suffix=".pbd"        (default)
            suffix="w84_fs"
            suffix="n88_g09_merged_be.pbd"
      remove_buffers= By default, it is assumed that your input data are
         already tiled and that any buffer regions on those tiles is
         redundant--and probably not well manually filtered. Thus, by default
         the buffers around the input tiles are removed. If your file names
         cannot be parsed as tile names, you'll get a warning message but
         they'll still be tiled (without removing anything). Valid settings:
            remove_buffers=1     Attempt to remove source data buffers
                                 (default)
            remove_buffers=0     Use source data as is
      buffer= By default, output tiles will have a 100m buffer added to them.
         You can change that with this setting. Examples:
            buffer=100     Include 100m buffer (default)
            buffer=250     Include 250m buffer
            buffer=0       Do not include a buffer
      uniq= Specifies whether to discard points with matching soe values.
            uniq=1   Discard points with matching soe values (default)
            uniq=0   Keep all points, even duplicates
      verbose= Specifies how much output should go to the screen.
            verbose=2   Keeps you extremely well-informed
            verbose=1   Provides estimated time to completion (default)
            verbose=0   No screen output at all
      zone= By default, the zone will be determined on a file-by-file basis
         based on the file's name. If no parseable tile name can be determined,
         the file will be ignored. You can specify a zone to use for all files
         with this option.
            zone=[]     No zone provided, autodetect (default)
            zone=17     Force all input data to be treated as being in zone 17
            zone=-1     After loading the data, use data.zone (useful for ATM)
      shorten= By default (shorten=0), the long form of dt, it, and itdt tile
         names will be used. If shorten=1, the short forms will be used. This
         is shorthand for dtlength settings:
            shorten=0   -->   dtlength="long"
            shorten=1   -->   dtlength="short"
      flat= By default, files will be created in a directory structure. This
         settings lets you force them all into a single directory.
            flat=0   Put files in tired directory structure. (default)
            flat=1   Put files all directly into dstdir.
      split_zones= Specifies how to handle multiple-zone data. This is ignored
         if flat=1. Valid settings:
            split_zones=0     Never split data by zone. (default for most
                              schemes)
            split_zones=1     Split by zone if multiple zones found (default
                              for qq)
            split_zones=2     Always split by zone, even if only one found
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
      dtlength= Specifies whether to use the short or long form for data tile
         (and related) schemes. By default, this is set based on shorten=.
            dtlength="long"      Use long form: t_e234000_n3456000_15
            dtlength="short"     Use short form: e234_n3456_15
      dtprefix= Specifies whether to include the type prefix for data tile (and
         related) schemes. When enabled, index tiles are prefixed by i_, data
         tiles by t_, quad tiles by q_, and cell tiles by c_.
            dtprefix=0  Exclude prefix (default for dt when dtlength=="short")
            dtprefix=1  Include prefix (default for everything else)
      qqprefix= Specifies whether to prepend "qq" to the beginning of quarter
         quad names.
            qqprefix=0  Exclude prefix (default)
            qqprefix=1  Include prefix

   SEE ALSO: save_data_to_tiles
*/
   default, mode, "fs";
   default, scheme, "10k2k";
   default, searchstr, "*.pbd";
   default, remove_buffers, 1;
   default, verbose, 1;

   // Locate files
   files = find(srcdir, glob=searchstr);

   // Get zones
   zones = tile2uz(file_tail(files));
   if(!is_void(zone))
      zones(*) = zone;

   // Check for missing zones
   if(noneof(zones)) {
      write, "None of the file names contained a parseable zone. Please use the zone= option.";
      return;
   } if(nallof(zones)) {
      w = where(zones == 0)
      write, "The following file names did not contain a parseable zone and will be skipped.\n (Consider using zone= to avoid this.)";
      write, format=" - %s\n", file_tail(files(w));
      write, "";

      files = files(w);
      zones = zones(w);
   }

   srt = msort(zones, files);
   zones = zones(srt);
   files = files(srt);

   // Check for missing tiles, if we need them.
   tiles = extract_tile(file_tail(files));
   if(remove_buffers && nallof(tiles)) {
      w = where(!tiles);
      write, "The following file names did not contain a parseable tile name. They will be\n retiled, but they cannot have any buffers removed; remove_buffers=1 will be\n ignored for these files."
      write, format=" - %s\n", file_tail(files(w));
      write, "";
   }

   count = numberof(files);
   sizes = double(file_size(files));
   if(count > 1)
      sizes = sizes(cum)(2:);

   t0 = tp = array(double, 3);
   timer, t0;
   passverbose = max(0, verbose-1);
   for(i = 1; i <= count; i++) {
      if(verbose > 1)
         write, format="\n----------\nRetiling %d/%d: %s\n", i, count,
            file_tail(files(i));

      data = pbd_load(files(i));

      if(remove_buffers && tiles(i) && numberof(data)) {
         filezone = zones(i);
         if(filezone < 0) {
            filezone = data.zone;
         }
         e = n = [];
         data2xyz, data, e, n, mode=mode;
         idx = extract_for_tile(unref(e), unref(n), filezone, tiles(i), buffer=0);
         if(numberof(idx))
            data = data(idx);
         else
            data = [];
      }

      if(!numberof(data)) {
         if(verbose > 1)
            write, " - Skipping, no data found for tile";
         continue;
      }

      filezone = zones(i);
      if(filezone < 0) {
         filezone = data.zone;
      }
      save_data_to_tiles, unref(data), unref(filezone), dstdir, scheme=scheme,
         suffix=suffix, buffer=buffer, shorten=shorten, flat=flat, uniq=uniq,
         verbose=passverbose, split_zones=split_zones, split_days=split_days,
         day_shift=day_shift;

      if(verbose)
         timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
   }

   if(verbose)
      timer_finished, t0;
}
