write, "$Id$";
require, "cir-mosaic.i";

local gga_segmenting;
/* DOCUMENT gga_segmenting

   A small collection of utility functions have been developed to work with
   segments of flightlines in the GGA/PNAV data. Following are some terminology
   and variables used throughout the related documentation.

   gga: The global array "gga" (also called "pnav") that contains the GPS
      coordinates of the flight track. (This variable is hard-coded by the ALPS
      software.)

   q: The name of the variable used to hold the index list into gga as returned
      by Rubberband Box or Points in Polygon. (This variable is hard-coded by
      the 'Process EAARL Data' GUI.)

   segment: A "segment" is a continuous piece of a flightline. A segment can be
      thought of as any subsection of gga that can be represented as gga(a:b),
      where a and b are valid indexes into gga. Thus, if you draw a rubber-band
      box over a small region of the data that has five lines passing through
      it, you will find five segments represented by that rubber-band boxes's
      data. Note that a segment cannot be subsampled and still be thought of as
      a "segment". While this might logically be the case, for the purposes of
      this code we restrict the definition of a segment to being a series of
      continous, sequential, uninterrupted points.

   gga_idxlist: Denotes an index list into gga. This could be any index list: a
      single segment, several segments, random points, or even the entire
      extent of the gga array. The variable q is a specific example of a
      gga_idxlist.

   seg_idx: Denotes an index into the list of segments logically contained
      within a gga_idxlist.

   seg_idxlist: Denotes a list of indexes into the list of segments logically
      contained within a gga_idxlist.

   Functions that are useful for working with gga segments, defined in this file:

      segment_count
      segment_index
      extract_segment
      extract_segments
      plot_segment
      plot_all

   Since index lists are effectively sets, the following functions from set.i
   are also useful for working with gga segments:

      set_union
      set_intersection
      set_difference
*/

func segment_index(gga_idxlist) {
/* DOCUMENT segment_indices = segment_index(gga_idxlist)

   The segment_index function will return a list of indices into the given
   index list. The indices returned by this function specify where individual
   tracklines begin and end within the index list. If there are n segments, and
   x is a number between 1 and n representing one of those segments, then the
   indices for segment x are segment_indices(x):segment_indices(x+1)-1. (Thus,
   segment_index always returns an array with one more element than the number
   of segments present.)

   See also: gga_segmenting segment_count extract_segment
*/
   return grow(1, where(gga_idxlist(dif) > 1) + 1, numberof(gga_idxlist) + 1);
}

func segment_count(gga_idxlist) {
/* DOCUMENT count = segment_count(gga_idxlist)
   
   The segment_count function returns the number of segments found within the
   gga_idxlist.

   See also: gga_segmenting segment_index extract_segment plot_segment
*/
   // Original David Nagle 2008-10-28
   return numberof(where(gga_idxlist(dif) > 1)) + 1;
}

func extract_segment(gga_idxlist, seg_idx) {
/* DOCUMENT segment = extract_segment(gga_idxlist, seg_idx)
   
   The extract_segment function returns a list of indices corresponding to a
   segment.

   See also: gga_segmenting segment_count plot_segment segment_index
      extract_segments
*/
   // Original David Nagle 2008-10-28
  seg_indexes = segment_index(gga_idxlist);
  return gga_idx(seg_indexes(seg_idx):seg_indexes(seg_idx+1)-1);
}

func extract_segments(gga_idxlist, seg_idxlist) {
/* DOCUMENT new_gga_idx = extract_segments(gga_idxlist, seg_idxlist)

   The extract_segments function will return a list of indexes into gga
   representing all of the segments specified by the array seg_idxlist. This is
   equivalent to calling extract_segment repeatedly, then merging all of its
   results.

   See also: gga_segmenting extract_segment
*/
   // Original David Nagle 2008-10-28
   ret = [];
   for(i = 1; i <= numberof(seg_idxlist); i++) {
      ret = set_union(ret, extract_segment(gga_idxlist, seg_idxlist(i)));
   }
   return ret;
}

func plot_segment(gga_idxlist, seg_idx) {
/* DOCUMENT plot_segment, gga_idxlst, seg_idx

   Plots markers for each point of the given segment.

   See also: gga_segmenting plot_all
*/
   // Original David Nagle 2008-10-28
   extern gga;
   idx = extract_segment(gga_idxlist, seg_idx);
   plmk, gga(idx).lat, gga(idx).lon, marker=4, msize=0.2, color="blue";
}

func plot_all(gga_idxlist) {
/* DOCUMENT plot_all, gga_idxlist
   
   Plots markers for all points in the given gga_idxlist.

   See also: gga_segmenting plot_segment
*/
   // Original David Nagle 2008-10-28
   extern gga;
   plmk, gga(gga_idxlist).lat, gga(gga_idxlist).lon, marker=4, msize=0.2, color="blue";
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
      sod = hms2sod(hms);
      ins = get_img_ins(sod);
      write, f, format="%s %.4f %.4f %.4f %.4f %.4f %.4f\n",
         files(i), ins.easting, ins.northing, ins.alt, ins.roll, ins.pitch, ins.heading;
   }
   close, f;
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

   timeBias = 1;
   sod %= 86400;
   sod += timeBias;
   ins_idx = where(int(iex_nav1hz.somd) == sod)(1);
   if(is_void(ins_idx)) return -6;

   ins = iex_nav1hz(ins_idx)(1);

   ins.roll    += cir_mounting_bias.roll;
   ins.pitch   += cir_mounting_bias.pitch;
   ins.heading += cir_mounting_bias.heading;
   
   return ins;
}
