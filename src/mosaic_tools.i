write, "$Id$";
require, "cir-mosaic.i";

local pnav_segmenting;
/* DOCUMENT pnav_segmenting

   A small collection of utility functions have been developed to work with
   segments of flightlines in the GGA/PNAV data. Following are some terminology
   and variables used throughout the related documentation.

   pnav: The global array "pnav" (also called "pnav") that contains the GPS
      coordinates of the flight track. (This variable is hard-coded by the ALPS
      software.)

   q: The name of the variable used to hold the index list into pnav as returned
      by Rubberband Box or Points in Polygon. (This variable is hard-coded by
      the 'Process EAARL Data' GUI.)

   segment: A "segment" is a continuous piece of a flightline. A segment can be
      thought of as any subsection of pnav that can be represented as pnav(a:b),
      where a and b are valid indexes into pnav. Thus, if you draw a rubber-band
      box over a small region of the data that has five lines passing through
      it, you will find five segments represented by that rubber-band boxes's
      data. Note that a segment cannot be subsampled and still be thought of as
      a "segment". While this might logically be the case, for the purposes of
      this code we restrict the definition of a segment to being a series of
      continous, sequential, uninterrupted points.

   pnav_idxlist: Denotes an index list into pnav. This could be any index list: a
      single segment, several segments, random points, or even the entire
      extent of the pnav array. The variable q is a specific example of a
      pnav_idxlist.

   seg_idx: Denotes an index into the list of segments logically contained
      within a pnav_idxlist.

   seg_idxlist: Denotes a list of indexes into the list of segments logically
      contained within a pnav_idxlist.

   Functions that are useful for working with pnav segments, defined in this file:

      segment_count
      segment_index
      extract_segment
      extract_segments
      plot_segment
      plot_all

   Since index lists are effectively sets, the following functions from set.i
   are also useful for working with pnav segments:

      set_union
      set_intersection
      set_difference

   Once you have a list that you'd like to extract, this function from
   cir-mosaic.i is helpful:

      copy_pnav_cirs
*/

func segment_index(pnav_idxlist) {
/* DOCUMENT segment_indices = segment_index(pnav_idxlist)

   The segment_index function will return a list of indices into the given
   index list. The indices returned by this function specify where individual
   tracklines begin and end within the index list. If there are n segments, and
   x is a number between 1 and n representing one of those segments, then the
   indices for segment x are segment_indices(x):segment_indices(x+1)-1. (Thus,
   segment_index always returns an array with one more element than the number
   of segments present.)

   See also: pnav_segmenting segment_count extract_segment
*/
   return grow(1, where(pnav_idxlist(dif) > 1) + 1, numberof(pnav_idxlist) + 1);
}

func segment_count(pnav_idxlist) {
/* DOCUMENT count = segment_count(pnav_idxlist)
   
   The segment_count function returns the number of segments found within the
   pnav_idxlist.

   See also: pnav_segmenting segment_index extract_segment plot_segment
*/
   // Original David Nagle 2008-10-28
   return numberof(where(pnav_idxlist(dif) > 1)) + 1;
}

func extract_segment(pnav_idxlist, seg_idx) {
/* DOCUMENT segment = extract_segment(pnav_idxlist, seg_idx)
   
   The extract_segment function returns a list of indices corresponding to a
   segment.

   See also: pnav_segmenting segment_count plot_segment segment_index
      extract_segments
*/
   // Original David Nagle 2008-10-28
  seg_indexes = segment_index(pnav_idxlist);
  return pnav_idxlist(seg_indexes(seg_idx):seg_indexes(seg_idx+1)-1);
}

func extract_segments(pnav_idxlist, seg_idxlist) {
/* DOCUMENT new_pnav_idx = extract_segments(pnav_idxlist, seg_idxlist)

   The extract_segments function will return a list of indexes into pnav
   representing all of the segments specified by the array seg_idxlist. This is
   equivalent to calling extract_segment repeatedly, then merging all of its
   results.

   See also: pnav_segmenting extract_segment
*/
   // Original David Nagle 2008-10-28
   ret = [];
   for(i = 1; i <= numberof(seg_idxlist); i++) {
      ret = set_union(ret, extract_segment(pnav_idxlist, seg_idxlist(i)));
   }
   return ret;
}

func plot_segment(pnav_idxlist, seg_idx) {
/* DOCUMENT plot_segment, pnav_idxlst, seg_idx

   Plots markers for each point of the given segment.

   See also: pnav_segmenting plot_all
*/
   // Original David Nagle 2008-10-28
   extern pnav;
   idx = extract_segment(pnav_idxlist, seg_idx);
   plmk, pnav(idx).lat, pnav(idx).lon, marker=4, msize=0.2, color="blue";
}

func plot_all(pnav_idxlist) {
/* DOCUMENT plot_all, pnav_idxlist
   
   Plots markers for all points in the given pnav_idxlist.

   See also: pnav_segmenting plot_segment
*/
   // Original David Nagle 2008-10-28
   extern pnav;
   plmk, pnav(pnav_idxlist).lat, pnav(pnav_idxlist).lon, marker=4, msize=0.2, color="blue";
}

/*

   Things we need to prepare in Yorick for Inpho:

      * Divide the images up into 10km index tiles. (If necessary, sub-segment tiles.)
      * Create gpsins files for each tile using pnav + ins.
      * Create tile definitions for each tile.
      * Create an xyz file for each tile with the tile's FS point cloud.

   Each tile has the following directory/file structure:

   Y  e640_n4500_18/
   Y  +- data/
   Y  |  +- merged.gpsins
   Y  |  +- (200?-??-??.gpsins - per-date gpsins files)
   Y  |  +- tile_defns.txt
   Y  +- segments/
   Y  |  +- 01_e642480n4498010/
   Y  |  |  +- images/
   Y  |  |  |  +- (0?????-??????-cir.jpg - CIR images)
   I  |  |  +- project/
   I  |  |  |  +- (inpho project files)
   Y  +- images/
   Y  |  +- (0?????-??????-cir.jpg - CIR images)
   I  +- project/
   I  |  +- (inpho project files - merged, if there were segments)
   Y  +- xyz/
   Y  |  +- merged.xyz
   Y  |  +- (t_e..._n88_..._merged_fs_rcf_mf_fs.xyz - fs xyz files)
   I  |  +- (inpho converted DEM)
   I  +- orthos/
   I  |  +- full/
   I  |  |  +- (full ortho images, high resolution)
   I  |  +- clipped/
   I  |  |  +- (clipped ortho images, mosaic resolution)
   I  +- mosaic/
   I  |  +- (mosaic images)

*/

func prepare_cir_for_inpho(conf_file, photo_dir, xyz_file, inpho_dir,
   downsample=, tile_buffer=, xyz_buffer=, defn_buffer=,
   make_xyz=, make_gpsins=, make_defn=, make_images=
) {
// Original David Nagle 2009-03-03
   default, downsample, 2;
   default, tile_buffer, 250;
   default, xyz_buffer, 750;
   default, defn_buffer, 100;
   default, make_xyz, 1;
   default, make_gpsins, 1;
   default, make_defn, 1;
   default, make_images, 1;
   extern tans;

   // Step 1: Load in conf file and figure out which images we're working with.

   write, format="Loading conf file...%s", "\n";
   mission_load, conf_file;

   write, format="Locating images...%s", "\n";
   photo_files = find(photo_dir, glob="*.jpg");
   if(!numberof(photo_files))
      error, "No files found.";

   write, format="Found %d images\n", numberof(photo_files);
   write, format="Determining second-of-epoch values...%s", "\n";
   photo_soes = cir_to_soe(file_tail(photo_files));
   if(downsample > 1) {
      write, format="Downsampling images...%s", "\r";
      w = where(int(photo_soes) % downsample == 0);
      if(numberof(w)) {
         photo_files = photo_files(w);
         photo_soes = photo_soes(w);
         write, format="Downsampled to %d images\n", numberof(w);
      } else {
         error, "Downsampling eliminated all images.";
      }
   }

   write, format="Calculating dates...%s", "\n";
   photo_dates = soe2date(photo_soes);
   date_list = set_remove_duplicates(photo_dates);

   // Step 2: Load tans data for images
   write, format="Calculating tans data for %d dates...\n", numberof(date_list);
   photo_tans = array(IEX_ATTITUDEUTM, dimsof(photo_soes));
   for(i = 1; i <= numberof(date_list); i++)  {
      write, format=" - %d: Interpolating for %s...\n", i, date_list(i);
      missiondate_current, date_list(i);
      missiondata_load, "dmars";

      w = where(photo_dates == missiondate_current());
      
      photo_tans(w).somd = soe2sod(photo_soes(w));
      photo_tans(w).lat = interp(tans.lat, tans.somd, photo_tans(w).somd);
      photo_tans(w).lon = interp(tans.lon, tans.somd, photo_tans(w).somd);
      photo_tans(w).alt = interp(tans.alt, tans.somd, photo_tans(w).somd);
      photo_tans(w).roll = interp(tans.roll, tans.somd, photo_tans(w).somd);
      photo_tans(w).pitch = interp(tans.pitch, tans.somd, photo_tans(w).somd);
      photo_tans(w).heading = interp_angles(tans.heading, tans.somd, photo_tans(w).somd);
   }
   
   write, format="Converting WGS84 to NAD83 to NAVD88...%s", "\n";
   wgs = transpose([photo_tans.lon, photo_tans.lat, photo_tans.alt]);
   nad = wgs842nad83(unref(wgs));
   navd = nad832navd88(unref(nad));
   photo_tans.lon = navd(1,);
   photo_tans.lat = navd(2,);
   photo_tans.alt = navd(3,);

   write, format="Converting lat/lon to UTM...%s", "\n";
   utm = fll2utm(photo_tans.lat, photo_tans.lon);
   photo_tans.northing = utm(1,);
   photo_tans.easting = utm(2,);
   photo_tans.zone = utm(3,);
   utm = [];

   // Step 3: Partition images.
   dtcodes = get_utm_dtcodes(photo_tans.northing,
      photo_tans.easting, photo_tans.zone);
   itcodes = dt_short(set_remove_duplicates(get_dt_itcodes(dtcodes)));
   dtcodes = [];

   itiles = h_new();
   write, format="Partitioning images into %d index tiles...\n", numberof(itcodes);
   for(i = 1; i <= numberof(itcodes); i++) {
      write, format=" - %d: %s\n", i, itcodes(i);
      z = it2utm(itcodes(i))(3);
      w = where(photo_tans.zone == z);
      idx = extract_for_it(photo_tans(w).northing, photo_tans(w).easting,
         itcodes(i), buffer=tile_buffer);
      if(numberof(idx))
         h_set, itiles, itcodes(i), w(idx);
   }
   itcodes = h_keys(itiles);
   write, format="Found %d total index tiles, processing...\n", numberof(itcodes);

   // Iterate through image directories and...
   for(i = 1; i <= numberof(itcodes); i++) {
      itcode = itcodes(i);
      itdir = file_join(inpho_dir, itcode);
      idx = itiles(itcode);
      write, format=" - %d: %s\n", i, itcode;

      // Step 4: ... copy images
      if(make_images) {
         write, format="   * Copying %d images...\n", numberof(idx);
         dest_dir = file_join(itdir, "images");
         mkdirp, dest_dir;
         for(j = 1; j <= numberof(idx); j++) {
            current_file = photo_files(idx(j));
            file_copy, current_file,
               file_join(dest_dir, file_tail(current_file));
         }
      }

      // Step 5: ... generate .gpsins files
      if(make_gpsins) {
         write, format="   * Generating .gpsins file...%s", "\n";
         mkdirp, file_join(itdir, "data");
         gpsins_file = file_join(itdir, "data", "merged.gpsins");
         f = open(gpsins_file, "w");
         write, f, linesize=2000, format="%s %.3f %.3f %.3f %.4f %.4f %.4f\n",
            file_rootname(file_tail(photo_files(idx))),
            photo_tans.easting(idx), photo_tans.northing(idx), photo_tans.alt(idx),
            photo_tans.roll(idx), photo_tans.pitch(idx), photo_tans.heading(idx);
         close, f;
      }

      // Step 6: ... generate .xyz files
      if(make_xyz) {
         write, format="   * Generating .xyz file...%s", "\n";
         bbox = it2utm(itcode, bbox=1);
         min_n = bbox(1) - xyz_buffer;
         max_n = bbox(3) + xyz_buffer;
         min_e = bbox(4) - xyz_buffer;
         max_e = bbox(2) + xyz_buffer;
         fin = open(xyz_file, "r");
         mkdirp, file_join(itdir, "xyz");
         fout = open(file_join(itdir, "xyz", "merged.xyz"), "w");
         tstamp = lc = 0;
         timer_init, tstamp;
         for(;;) {
            lc++;
            timer_tick, tstamp, lc, lc+1, swrite(format="     + Processing line %d...", lc);
            line = rdline(fin);
            if(!line) break;
            east = north = alt = double(0);
            sread, line, east, north, alt;
            if(
               min_n <= north & north <= max_n &
               min_e <= east  & east  <= max_e
            ) {
               write, fout, format="%.2f %.2f %.2f\n", east, north, alt;
            }
         }
         close, fin;
         close, fout;
         write, format="%s", "\n";
      }

      // Step 7: ... generate tile definitions
      if(make_defn) {
         dtcodes = get_utm_dtcodes(
            photo_tans.northing(idx), photo_tans.easting(idx), photo_tans.zone(idx));
         dtcodes = dt_short(set_remove_duplicates(dtcodes));
         write, format="   * Generating tile definitions for %d data tiles...\n", numberof(dtcodes);
         f = open(file_join(itdir, "data", "tile_defns.txt"), "w");
         for(j = 1; j <= numberof(dtcodes); j++) {
            write, format="     + %d: %s\n", j, dtcodes(j);
            bbox = dt2utm(dtcodes(j), bbox=1);
            write, f, format="%c%s%c %d %d %d %d\n", 0x22, dtcodes(j), 0x22,
               int(bbox(3) + defn_buffer), int(bbox(4) - defn_buffer),
               int(bbox(1) - defn_buffer), int(bbox(2) + defn_buffer);
         }
         close, f;
      }

   }

}

func batch_load_and_write_cir_gpsins(img_dirs, globs, mission_dirs=, pnav_files=, ins_files=, dest_dir=) {
   for(i = 1; i <= numberof(globs); i++) {
      if(numberof(mission_dirs) && is_void(pnav_files)) {
         pnav_file = autoselect_pnav(mission_dirs(i));
      } else {
         pnav_file = pnav_files(i);
      }

      if(numberof(mission_dirs) && is_void(ins_files)) {
         ins_file = autoselect_iexpbd(mission_dirs(i));
      } else {
         ins_file = ins_files(i);
      }

      dest_name = file_tail(mission_dirs(i));

      load_and_write_cir_gpsins,
         pnav_file, ins_file, img_dirs, globs(i), dest_dir=dest_dir, dest_name=dest_name;
   }
}

func load_and_write_cir_gpsins(pnav_file, ins_file, img_dirs, glob, dest_dir=, dest_name=) {
   extern pnav;
   load_iexpbd, ins_file;
   pnav = rbpnav(fn=pnav_file);
   for(i = 1; i <= numberof(img_dirs); i++) {
      dest = file_join(img_dirs(i));
      if(dest_name)
         dest += "_" + dest_name;
      dest += ".gpsins";
      if(!is_void(dest_dir))
         dest = file_join(dest_dir, file_tail(dest));
      write_cir_gpsins, img_dirs(i), dest, glob=glob;
   }
}

func write_cir_gpsins(imgdir, outfile, glob=) {
/* DOCUMENT write_cir_gpsins, imgdir, outfile
   
   This will create a file (specified by outfile) containing the GPS and INS
   data for all the images found within imgdir. The GPS and INS data must be
   already loaded globally.

   This was written to facilitate the transference of this data into Inpho's
   OrthoMaster software. It expects the outfile's extension to be .gps or
   .gpsins.
*/
   // Original David Nagle 2008-10-28
   default, glob, "*.jpg";

   files = find(imgdir, glob=glob);

   if(!numberof(files)) {
      write, "No files were found.";
      return;
   }

   files = file_tail(files);
   files = file_rootname(files);
   files = set_remove_duplicates(files);

   hms = atoi(strsplit(files, "-")(,2));
   sod = int(hms2sod(hms) % 86400);
   data = get_img_info(sod);
   //u = fll2utm(data(3,), data(2,));
   /*
      data(1,) - 1 if we interpolated data; 0 if not
      data(2,) - lon
      data(3,) - lat
      data(4,) - alt
   */

   nad83 = wgs842nad83([data(2:4,)]);
   navd88 = nad832navd88(nad83);
   u = fll2utm(navd88(2,), navd88(1,));
   data(4,) = navd88(3,);

   w = where(data(1,));
   
   if(numberof(w)) {
      f = open(outfile, "w");
      write, f, linesize=2000, format="%s %.10f %.10f %.4f %.4f %.4f %.4f\n",
         files(w),
         u(2,w), u(1,w), data(4,w), data(5,w), data(6,w), data(7,w);
      close, f;
   } else {
      write, "No files had data.";
   }
}

func get_img_info(sod, offset=) {
/* DOCUMENT data = get_img_info(sod)
   Returns array of data:
      data(1,) - 1 if we interpolated data; 0 if not
      data(2,) - lon
      data(3,) - lat
      data(4,) - alt
      data(5,) - roll
      data(6,) - pitch
      data(7,) - heading

   return [lon, lat, alt, rol, pitch, heading];
*/
   extern iex_nav;
   extern pnav;

   default, offset, 1.12;

   sod += offset;
   iex_sod = iex_nav.somd % 86400;

   result = array(double, 7, numberof(sod));
   result(1,) = 0;

   w = where(iex_sod(min) <= sod & sod <= iex_sod(max));
   if(numberof(w)) {
      result(1,w) = 1;
      result(2,w) = interp(iex_nav.lon, iex_sod, sod(w));
      result(3,w) = interp(iex_nav.lat, iex_sod, sod(w));
      result(4,w) = interp(iex_nav.alt, iex_sod, sod(w));
      result(5,w) = interp(iex_nav.roll, iex_sod, sod(w));
      result(6,w) = interp(iex_nav.pitch, iex_sod, sod(w));
      result(7,w) = interp_angles(iex_nav.heading, iex_sod, sod(w));
   }

   return result;
}

func get_img_ins(sod) {
/* DOCUMENT ins = get_img_ins(sod)

   Returns the ins data for the given sod value.

   See also: write_cir_gpsins
*/
   // Original David Nagle 2008-10-28
   extern iex_nav1hz;
   extern cir_mounting_bias;
   extern camera_specs;

   if(is_void(iex_nav1hz)) return -5;

   sod %= 86400;
   w = where(int(iex_nav1hz.somd) == sod);
   if(!numberof(w))
      return -6;
   ins_idx = w(1);

   ins = iex_nav1hz(ins_idx)(1);

   ins.roll    += cir_mounting_bias.roll;
   ins.pitch   += cir_mounting_bias.pitch;
   ins.heading += cir_mounting_bias.heading;
   
   return ins;
}

func get_img_pnav(sod) {
   extern pnav;
   if(is_void(pnav)) return -5;

   pnav_idx = where(int(pnav.sod) == sod)(1);
   if(is_void(pnav_idx)) return -6;
   
   return pnav(pnav_idx);
}

func make_cir_index_tiles(srcdir, destdir, gpsins, zone, buffer=) {
/* DOCUMENT gen_cir_tiles, pnav, src, dest, copyjgw=, abbr=

   This function partitions images into 10k by 10k index tiles.

   Parameters:
      srcdir:  Path to full set of images
      destdir: Path to place index tiles
      gpsins:  Path to gpsins file with all gpsins data
      zone:    UTM zone of data

   Options:
      buffer=  Buffer to include around tile; default 250km
*/
   fix_dir, src;
   fix_dir, dest;
   default, buffer, 250;

   write, "Generating file list...";
   files = find(srcdir, glob="*.jpg");
   files = files(sort(file_tail(files)));

   write, "Loading data...";
   f = open(gpsins);
   lines = rdfile(f);
   close, f;
   data = strsplit(lines, " ")(,1:3);
   data(,1) += ".jpg";
   lines = [];

   // We need to now merge files and data

   file_names = file_tail(files);
   data_names = data(,1);

   file_idx = set_intersection(file_names, data_names, idx=1);
   data_idx = set_intersection(data_names, file_names, idx=1);
   file_names = data_names = [];

   if(numberof(file_idx) < 1 || numberof(data_idx) < 1) {
      write, "Data problem, aborting...";
      return;
   }

   files = files(file_idx);
   data = data(data_idx,);
   file_idx = data_idx = [];

   files = files(sort(file_tail(files)));
   data = data(sort(data(,1)),);

   data(,1) = files;
   files = [];

   itcodes = get_dt_itcodes(get_utm_dtcodes(atod(data(,3)), atod(data(,2)), zone));
   itcodes = set_remove_duplicates(itcodes);

   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(itcodes); i++) {
      bbox = it2utm(itcodes(i), bbox=1);
      min_n = bbox(1) - buffer;
      max_n = bbox(3) + buffer;
      min_e = bbox(4) - buffer;
      max_e = bbox(2) + buffer;
      w = where(
         min_n <= atod(data(,3)) & atod(data(,3)) <= max_n &
         min_e <= atod(data(,2)) & atod(data(,2)) <= max_e
      );
      if(numberof(w)) {
         short_name = dt_short(itcodes(i));
         dest_path = file_join(destdir, short_name, "images");
         mkdirp, dest_path;
         write, format="[%d/%d] Creating %s with %d files\n",
            i, numberof(itcodes), short_name, numberof(w);
         for(j = 1; j <= numberof(data(w,1)); j++) {
            file_copy, data(w(j),1), file_join(dest_path, file_tail(data(w(j),1)));
            timer_tick, tstamp, j, numberof(w);
         }
      } else {
         write, format="Skipping %s, no files found\n", short_name;
      }
   }
}

func segment_cir_dir(srcdir, destdir, gpsins, buffer=, threshold=) {
   fix_dir, srcdir;
   fix_dir, destdir;
   default, buffer, 250;
   default, threshold, 600;
   tile_size = 256000;

   write, "Generating file list...";
   files = find(srcdir, glob="*.jpg");
   files = files(sort(file_tail(files)));

   write, "Loading data...";
   f = open(gpsins);
   lines = rdfile(f);
   close, f;
   data = strsplit(lines, " ")(,1:3);
   data(,1) += ".jpg";
   lines = [];

   // We need to now merge files and data

   file_names = file_tail(files);
   data_names = data(,1);

   file_idx = set_intersection(file_names, data_names, idx=1);
   data_idx = set_intersection(data_names, file_names, idx=1);
   file_names = data_names = [];

   if(numberof(file_idx) < 1 || numberof(data_idx) < 1) {
      write, "Data problem, aborting...";
      return;
   }

   files = files(file_idx);
   data = data(data_idx,);
   file_idx = data_idx = [];

   files = files(sort(file_tail(files)));
   data = data(sort(data(,1)),);

   data(,1) = files;
   files = [];

   write, format=" Number of files: %d\n", numberof(data(,1));
   __subdivide_cir, data, destdir, buffer, threshold, 1;
}

func __subdivide_cir(data, dest, buffer, threshold, depth) {
   bound_e = ceil(atod(data(,2))(max) / 10.) * 10;
   bound_w = floor(atod(data(,2))(min) / 10.) * 10;
   bound_n = ceil(atod(data(,3))(max) / 10.) * 10;
   bound_s = floor(atod(data(,3))(min) / 10.) * 10;
   if(
      numberof(data(,1)) > threshold
      && (bound_e - bound_w > 10 || bound_n - bound_s > 10)
   ) {
      if(bound_e - bound_w > bound_n - bound_s) {
         // Split east/west
         bound_mid = median(atod(data(,2)));
         bbox_e = [bound_n, bound_e, bound_s, bound_mid + 5];
         bbox_w = [bound_n, bound_mid - 5, bound_s, bound_w];
         idxlist_e = get_bounds_idxlist(data, bbox_e, buffer);
         idxlist_w = get_bounds_idxlist(data, bbox_w, buffer);
         write, format="%s- Split east (%d) / west (%d)\n",
            array(" ", depth)(sum), numberof(idxlist_e), numberof(idxlist_w);
         __subdivide_cir, data(idxlist_e,), dest, buffer, threshold, depth+1;
         __subdivide_cir, data(idxlist_w,), dest, buffer, threshold, depth+1;
      } else {
         // Split north/south
         bound_mid = median(atod(data(,3)));
         bbox_n = [bound_n, bound_e, bound_mid + 5, bound_w];
         bbox_s = [bound_mid - 5, bound_e, bound_s, bound_w];
         idxlist_n = get_bounds_idxlist(data, bbox_n, buffer);
         idxlist_s = get_bounds_idxlist(data, bbox_s, buffer);
         write, format="%s- Split north (%d) / south (%d)\n",
            array(" ", depth)(sum), numberof(idxlist_n), numberof(idxlist_s);
         __subdivide_cir, data(idxlist_n,), dest, buffer, threshold, depth+1;
         __subdivide_cir, data(idxlist_s,), dest, buffer, threshold, depth+1;
      }
   } else {
      tile = swrite(format="e%d0n%d0",
         int(bound_w/10), int(bound_s/10));
      bbox = [bound_n, bound_e, bound_s, bound_w];
      if(numberof(data(,1)) && numberof(get_bounds_idxlist(data, bbox, 0)) > 0) {
         write, format="%s* %s: %d files\n",
            array(" ", depth)(sum), tile, numberof(data(,1));
         dest_dir = dest + tile + "/";
         mkdirp, dest_dir;
         for(i = 1; i <= numberof(data(,1)); i++) {
            file_copy, data(i,1), dest_dir + file_tail(data(i,1));
         }
      } else {
         write, format=" ! Skipping %s, no files within strict bounds\n",
            tile;
      }
   }
}

func get_bounds_idxlist(data, bbox, buffer) {
   max_n = bbox(1) + buffer;
   max_e = bbox(2) + buffer;
   min_n = bbox(3) - buffer;
   min_e = bbox(4) - buffer;
   return where(
      min_n <= atod(data(,3)) & atod(data(,3)) <= max_n &
      min_e <= atod(data(,2)) & atod(data(,2)) <= max_e
   );
}

func cir_tuner(state) {
   extern iex_nav;

   iex_nav.somd %= 86400;
   // cir_mounting_bias
   // GEoid
   // batch_gen_jgw_file
   // calls gen_jgw_file(somd) for each file
   //   somd %= 86400
   // calls gen_jgw_sod(somd)
   //   somd += 1
   //   looks up in iex_nav1hz to get PRH
   //   PRH += cir_mounting_bias
   //   pulls in Geoid
   // calls gen_jgw(ins, cam, Geoid)
   //   where ins is IEX_ATTITUDEUTM with
   //       easting northing alt pitch roll heading
   //   and Geoid is elevation

   // Test offsets to:
   //    easting northing alt pitch roll heading elevation time

   generations = 10000;
   target_rmse = 0.01;
/*
   state = h_new(
      offset_time=0.0, dev_time=0.0067, bmin_time=-3.0, bmax_time=3.0,
      offset_northing=0.0, dev_northing=0.0033, bmin_northing=-4.0, bmax_northing=4.0,
      offset_easting=0.0, dev_easting=0.0033, bmin_easting=-4.0, bmax_easting=4.0,
      offset_alt=0.0, dev_alt=0.0033, bmin_alt=-4.0, bmax_alt=4.0,
      offset_pitch=0.0, dev_pitch=0.0033, bmin_pitch=-180.0, bmax_pitch=180.0,
      offset_roll=0.0, dev_roll=0.0033, bmin_roll=-180.0, bmax_roll=180.0,
      offset_heading=0.0, dev_heading=0.0033, bmin_heading=-180.0, bmax_heading=180.0,
      offset_elevation=-20.0, dev_elevation=0.0333, bmin_elevation=-60.0, bmax_elevation=20.0,
      directory=photo_dir, camera=camera_specs, window=1,
      files=find(photo_dir, glob="*.jpg")
   );
   */
   h_set, state, "files", find(state.directory, glob="*.jpg");

   if(h_has(state, "window")) {
      window, state.window;
      fma;
      plg, [0,0], [0, generations], color="black";
   }

   state = simulated_annealing(state, generations, target_rmse, __atcpsa_energy, __atcpsa_neighbor, __atcpsa_temperature, show_status=__atcpsa_status);
   write, " ";
   write, "Best result:";
   h_show, state;
   return state;
}

func __atcpsa_energy(state) {
   jpgs = state.files;
   for(i = 1; i <= numberof(jpgs); i++) {
      somd = hms2sod(atoi(strpart(jpgs(i), -13:-8)));
      somd += state.offset_time;
      data = get_img_info(somd);

      u = fll2utm(data(2), data(1));
      ins = IEX_ATTITUDEUTM();
      ins.northing = u(1);
      ins.easting = u(2);
      ins.alt = data(3);
      ins.roll = data(4);
      ins.pitch = data(5);
      ins.heading = data(6);

      // Move location from INS to camera
      reference_point = [ins.easting, ins.northing, ins.alt];
      delta = [state.offset_x, state.offset_y, state.offset_z];
      rotation = [ins.roll, ins.pitch, ins.heading];
      new_loc = transform_delta_rotation(reference_point, delta, rotation);
      ins.easting = new_loc(1);
      ins.northing = new_loc(2);
      ins.alt = new_loc(3);

      // Combine offset and INS to get camera attitude
      ins_M = tbr_to_matrix(ins.roll, ins.pitch, ins.heading);
      off_M = tbr_to_matrix(state.offset_roll, state.offset_pitch, state.offset_heading);
      //joint_M = ins_M(+,) * off_M(,+);
      joint_M = off_M(+,) * ins_M(,+);
      joint_tbr = matrix_to_tbr(joint_M);
      // Convert rotations from INS to camera
      ins.roll = joint_tbr(1);
      ins.pitch = joint_tbr(2);
      ins.heading = joint_tbr(3);

      jgw_data = gen_jgw(ins, state.camera, state.offset_elevation);

      jgw_file = file_rootname(jpgs(i)) + ".jgw";
      f = open(jgw_file, "w");
      write, f, format="%.6f\n", jgw_data;
      close, f;
   }

   cmd = "./pto_cir.pl " + state.directory + " " + state.directory;
   rmse = atod(popen_rdfile(cmd)(1));

   return rmse;
}

func __atcpsa_neighbor(state) {
   state = h_copy(state);

   fields = strsplit("time x y z roll pitch heading elevation", " ");

   for(i = 1; i <= numberof(fields); i++) {
      field = fields(i);
      val = h_get(state, "offset_" + field);
      dev = h_get(state, "dev_" + field);
      bmin = h_get(state, "bmin_" + field);
      bmax = h_get(state, "bmax_" + field);
      val = val + random_n() * dev;
      val = bound(val, bmin, bmax);
      h_set, state, "offset_" + field, val;
   }

   return state;
}

func __atcpsa_temperature(time) {
   //upper = 1.4427; // 50% probability for 1m difference  = approx -1 / log(.5)
   //upper = 0.33381; // 5% probability for 1m difference = approx -1 / log(.05)
   upper = 0.021715; // 1% probability for 10cm difference = approx -0.1 / log(.01)
   //lower = 0.0144; // 50% probability for 1cm difference = approx -.01 / log(.5)
   //lower = 0.00334; // 5% probability for 1cm difference = approx -.01 / log(.05)
   lower = 0.000217; // 1% probability for 1mm difference = approx -.001 / log(.01)
   return upper - (upper - lower) * time;
}

func __atcpsa_status(status) {
   if(status.iteration % 5 == 0) {
      write, format="%d/%d: %.3f\n", status.iteration, status.max_iterations, status.energy;
      write, format="  Current best: %.3f\n", status.best_energy;
      state = status.best_state;
      fields = strsplit("time x y z roll pitch heading elevation", " ");
      for(i = 1; i <= numberof(fields); i++) {
         write, format="    %10s= %.3f\n", fields(i), h_get(state, "offset_" + fields(i));
      }
      if(h_has(state, "window")) {
         window, state.window;
         plmk, status.best_energy, status.iteration, msize=0.1, marker=1, color="blue";
         plmk, status.energy, status.iteration, msize=0.1, marker=1, color="red";
         limits;
      }
      write, " ";
   }
}

func new_gen_jgws(photo_dir, elev=, glob=) {
   extern camera_specs;
   default, elev, 0;
   default, glob, "*-cir.jpg";
   jpgs = find(photo_dir, glob=glob);

   files = file_tail(file_rootname(jpgs));

   hms = atoi(strsplit(files, "-")(,2));
   sod = int(hms2sod(hms) % 86400);
   raw_ins = get_img_info(sod);
   u = fll2utm(raw_ins(3,), raw_ins(2,));
   w = where(raw_ins(1,));

   tstamp = [];
   if(numberof(w)) {
      timer_init, tstamp;
      for(j = 1; j <= numberof(w); j++) {
         timer_tick, tstamp, j, numberof(w);
         i = w(j);

         ins = IEX_ATTITUDEUTM();
         ins.somd = sod(i);
         ins.northing = u(1,i);
         ins.easting = u(2,i);
         ins.zone = u(3,i);
         ins.lat = raw_ins(3,i);
         ins.lon = raw_ins(2,i);
         ins.alt = raw_ins(4,i);
         ins.roll = raw_ins(5,i);
         ins.pitch = raw_ins(6,i);
         ins.heading = raw_ins(7,i);

         jgw_data = gen_jgw(ins, camera_specs, elev);
         jgw_file = file_rootname(jpgs(i)) + ".jgw";
         f = open(jgw_file, "w");
         write, f, format="%.6f\n", jgw_data(1:4);
         write, f, format="%.3f\n", jgw_data(5:6);
         close, f;

      }
   }
}
