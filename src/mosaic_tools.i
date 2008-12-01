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

func write_cir_gpsins(imgdir, outfile) {
/* DOCUMENT write_cir_gpsins, imgdir, outfile
   
   This will create a file (specified by outfile) containing the GPS and INS
   data for all the images found within imgdir. The GPS and INS data must be
   already loaded globally.

   This was written to facilitate the transference of this data into Inpho's
   OrthoMaster software. It expects the outfile's extension to be .gps or
   .gpsins.
*/
   // Original David Nagle 2008-10-28
   files = find(imgdir, glob="*.jpg");

   files = file_tail(files);
   files = file_rootname(files);

   f = open(outfile, "w");
   for(i = 1; i <= numberof(files); i++) {
      hms = strsplit(files(i), "-")(2);
      hms = atoi(hms);
      sod = hms2sod(hms) + 1;
      data = get_img_info(sod);
      if(!is_void(data)) {
         write, f, format="%s %.10f %.10f %.4f %.4f %.4f %.4f\n",
            files(i),
            data(1), data(2), data(3), data(4), data(5), data(6);
      }
   }
   close, f;
}

func get_img_info(sod) {
/* DOCUMENT get_img_info(sod)
   return [lon, lat, alt, rol, pitch, heading];
*/
   extern iex_nav;
   extern pnav;

   if(pnav.sod(max) < sod || sod < pnav.sod(min))
      return [];
   if(iex_nav.somd(max) < sod || sod < iex_nav.somd(min))
      return [];

   lon = interp(pnav.lon, pnav.sod, sod);
   lat = interp(pnav.lat, pnav.sod, sod);
   alt = interp(pnav.alt, pnav.sod, sod);
   rol = interp(iex_nav.roll, iex_nav.somd, sod);
   pitch = interp(iex_nav.pitch, iex_nav.somd, sod);
   heading = interp_angles(iex_nav.heading, iex_nav.somd, sod);

   return [lon, lat, alt, rol, pitch, heading];
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

struct CIR_PNAV {
   string file;
   float sod;
   double x;
   double y;
   float alt;
};

func dump_cir_pbd(imgdir, pbddest) {
   extern pnav;
   fix_dir, imgdir;
   files = find(imgdir, glob="*.jpg");
   files_sod = hms2sod(atoi(strpart(files, -13:-8))) + 1;

   cir_pnav = array(CIR_PNAV, numberof(files));
   cir_pnav.file = "";

   for(i = 1; i <= numberof(files); i++) {
      w = where(pnav.sod == files_sod(i));
      if(numberof(w) == 1) {
         w = w(1);
         cir_pnav(i).file = file_tail(files(i));
         cir_pnav(i).sod = pnav(w).sod;
         cir_pnav(i).x = pnav(w).lon;
         cir_pnav(i).y = pnav(w).lat;
         cir_pnav(i).alt = pnav(w).alt;
      }
   }

   w = where(cir_pnav.file != "");
   if(numberof(w)) {
      cir_pnav = cir_pnav(w);
      pbd_append, pbddest, "cir_pnav", cir_pnav, uniq=0;
      write, "Exported!";
   } else {
      write, "No data to export!";
   }
}

func segment_cir_dir(srcdir, pbd, destdir, zone) {
   fix_dir, srcdir;
   fix_dir, destdir;
   buffer = 250;
   tile_size = 256000;

   write, "Generating file list...";
   files = find(srcdir, glob="*.jpg");
   files = files(sort(file_tail(files)));

   f = openb(pbd);
   data = get_member(f, f.vname);
   data = data(sort(data.file));

   // We need to now merge files and data

   file_names = file_tail(files);
   data_names = data.file;

   file_idx = set_intersection(file_names, data_names, idx=1);
   data_idx = set_intersection(data_names, file_names, idx=1);
   file_names = data_names = [];

   if(numberof(file_idx) < 1 || numberof(data_idx) < 1) {
      write, "Data problem, aborting...";
      return;
   }

   files = files(file_idx);
   data = data(data_idx);
   file_idx = data_idx = [];

   files = files(sort(file_tail(files)));
   data = data(sort(data.file));

   data.file = files; // merge complete!
   files = [];

   // replace lat/lon geographic coords with utm coords
   coords = fll2utm(data.y, data.x, force_zone=zone);
   data.x = coords(1,);
   data.y = coords(2,);
   coords = [];

   if(1) {
      write, format=" Number of files: %d\n", numberof(data);
      __subdivide_alt, data, zone, destdir, buffer;
   } else {
      bounds_n = int(ceil (data.y(max) / tile_size)) * tile_size;
      bounds_s = int(floor(data.y(min) / tile_size)) * tile_size;
      bounds_e = int(ceil (data.x(max) / tile_size)) * tile_size;
      bounds_w = int(floor(data.x(min) / tile_size)) * tile_size;

      write, format=" Segmenting with initial tile size of %d, buffer of %d...\n",
         tile_size, buffer;
      for(n = bounds_s; n < bounds_n; n += tile_size) {
         for(e = bounds_w; e < bounds_e; e += tile_size) {
            bbox = int([n + tile_size, e + tile_size, n, e]);
            idxlist = get_bounds_idxlist(data, bbox, buffer);
            if(numberof(idxlist)) {
               write, format=" - Tile n%d, e%d (%d)\n",
                  bbox(1), bbox(2), numberof(idxlist);
               __subdivide_cirs, data(idxlist), bbox, zone, destdir, buffer;
            }
         }
      }
   }
}

func __subdivide_alt(data, zone, dest, buffer) {
   threshold = 600;
   bound_e = ceil(data.x(max) / 1000.) * 1000;
   bound_w = floor(data.x(min) / 1000.) * 1000;
   bound_n = ceil(data.y(max) / 1000.) * 1000;
   bound_s = floor(data.y(min) / 1000.) * 1000;
   if(
      numberof(data) > threshold
      && (bound_e - bound_w > 1000 || bound_n - bound_s > 1000)
   ) {
      min_diff = numberof(data) * 2;
      min_mark = 0;
      for(x = bound_w + 1000; x < bound_e; x += 1000) {
         bbox_e = [bound_n, bound_e, bound_s, x];
         bbox_w = [bound_n, x, bound_s, bound_w];
         idxlist_e = get_bounds_idxlist(data, bbox_e, buffer);
         idxlist_w = get_bounds_idxlist(data, bbox_w, buffer);
         diff = abs(numberof(idxlist_e) - numberof(idxlist_w));
         if(diff < min_diff) {
            min_diff = diff
            min_mark = x;
         }
      }
      for(y = bound_s + 1000; y < bound_n; y += 1000) {
         bbox_n = [bound_n, bound_e, y, bound_w];
         bbox_s = [y, bound_e, bound_s, bound_w];
         idxlist_n = get_bounds_idxlist(data, bbox_n, buffer);
         idxlist_s = get_bounds_idxlist(data, bbox_s, buffer);
         diff = abs(numberof(idxlist_n) - numberof(idxlist_s));
         if(diff < min_diff) {
            min_diff = diff
            min_mark = -1 * y;
         }
      }
      if(min_mark > 0) {
         bbox_e = [bound_n, bound_e, bound_s, min_mark];
         bbox_w = [bound_n, min_mark, bound_s, bound_w];
         idxlist_e = get_bounds_idxlist(data, bbox_e, buffer);
         idxlist_w = get_bounds_idxlist(data, bbox_w, buffer);
         write, format=" - Subdividing east (%d) and west (%d)\n",
            numberof(idxlist_e), numberof(idxlist_w);
         __subdivide_alt, data(idxlist_e), zone, dest, buffer;
         __subdivide_alt, data(idxlist_w), zone, dest, buffer;
      } else if(min_mark < 0) {
         min_mark = abs(min_mark);
         bbox_n = [bound_n, bound_e, min_mark, bound_w];
         bbox_s = [min_mark, bound_e, bound_s, bound_w];
         idxlist_n = get_bounds_idxlist(data, bbox_n, buffer);
         idxlist_s = get_bounds_idxlist(data, bbox_s, buffer);
         write, format=" - Subdividing north (%d) and south (%d)\n",
            numberof(idxlist_n), numberof(idxlist_s);
         __subdivide_alt, data(idxlist_n), zone, dest, buffer;
         __subdivide_alt, data(idxlist_s), zone, dest, buffer;
      }
   } else {
      tile = swrite(format="w%ds%de%dn%dz%d",
         int(bound_w/1000), int(bound_s/1000), int(bound_e/1000), int(bound_n/1000), int(zone));
      bbox = [bound_n, bound_e, bound_s, bound_w];
      if(numberof(data) && numberof(get_bounds_idxlist(data, bbox, 0)) > 0) {
         write, format=" * Copying %d files to %s\n",
            numberof(data), tile;
         dest_dir = dest + tile + "/";
         mkdirp, dest_dir;
         for(i = 1; i <= numberof(data); i++) {
            file_copy, data.file(i), dest_dir + file_tail(data.file(i));
         }
      } else {
         write, format=" ! Skipping %s, no files within strict bounds\n",
            tile;
      }
   }
}

func __subdivide_cirs(data, bbox, zone, dest, buffer) {
   // bbox = [n, e, s, w]
   threshold = 1200;
   size_ns = bbox(1) - bbox(3);
   size_ew = bbox(2) - bbox(4);
   if(numberof(data) > threshold && (size_ns > 1000 || size_ew > 1000)) {
      bbox_n = bbox + [0, 0, size_ns/2., 0];
      bbox_s = bbox + [-size_ns/2., 0, 0, 0];
      bbox_e = bbox + [0, 0, 0, size_ew/2.];
      bbox_w = bbox + [0, -size_ew/2., 0, 0];
      idxlist_n = get_bounds_idxlist(data, bbox_n, buffer);
      idxlist_s = get_bounds_idxlist(data, bbox_s, buffer);
      idxlist_e = get_bounds_idxlist(data, bbox_e, buffer);
      idxlist_w = get_bounds_idxlist(data, bbox_w, buffer);
      diff_ns = abs(numberof(idxlist_n) - numberof(idxlist_s));
      diff_ew = abs(numberof(idxlist_e) - numberof(idxlist_w));
      if(diff_ns < diff_ew || size_ew < 1001) {
         write, format="   * Subdividing north (%d) and south (%d)\n",
            numberof(idxlist_n), numberof(idxlist_s);
         __subdivide_cirs, data(idxlist_n), bbox_n, zone, dest, buffer;
         __subdivide_cirs, data(idxlist_s), bbox_s, zone, dest, buffer;
      } else {
         write, format="   * Subdividing east (%d) and west (%d)\n",
            numberof(idxlist_e), numberof(idxlist_w);
         __subdivide_cirs, data(idxlist_e), bbox_e, zone, dest, buffer;
         __subdivide_cirs, data(idxlist_w), bbox_w, zone, dest, buffer;
      }
   } else {
      tile = swrite(format="w%ds%de%dn%dz%d",
         int(bbox(4)/1000), int(bbox(3)/1000), int(bbox(2)/1000), int(bbox(1)/1000),
         int(zone));
      if(numberof(data) && numberof(get_bounds_idxlist(data, bbox, 0)) > 0) {
         write, format="   * Copying %d files to %s\n",
            numberof(data), tile;
         dest_dir = dest + tile + "/";
         mkdirp, dest_dir;
         for(i = 1; i <= numberof(data); i++) {
            file_copy, data.file(i), dest_dir + file_tail(data.file(i));
         }
      } else {
         write, format="   * Skipping %s, no files within strict bounds\n",
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
      min_n <= data.y & data.y <= max_n &
      min_e <= data.x & data.x <= max_e
   );
}
