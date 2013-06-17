// vim: set ts=2 sts=2 sw=2 ai sr et:

func process_selection_rasters(&rn_start, &rn_stop, q, ply) {
/* DOCUMENT process_selection_rasters, &rn_start, &rn_stop, q, ply
  Converts Q (an index into pnav) or PLY (a polygon) into a selection of raster
  indices. RN_START and RN_STOP will be arrays of equal length indicating the
  start and stop raster of each segment. The raster ranges will be broken up
  based on the TLD files they occur in.

  If ops_conf, tans, or pnav are void, an error will occur. If no rasters are
  found, the process will abort.
*/
  extern ops_conf, tans, pnav;

  rn_start = rn_stop = [];

  if(is_void(ops_conf))
    error, "ops_conf is not set";
  if(is_void(tans))
    error, "tans is not set";
  if(is_void(pnav))
    error, "pnav is not set";

  if(is_void(q))
    q = pnav_sel_rgn(region=ply);

  // find start and stop raster numbers for all flightlines
  rn_arr = sel_region(q, verbose=verbose);

  if(is_void(rn_arr)) {
    write, "No rasters found, aborting";
    return;
  }

  // Break rn_arr up into per-TLD raster ranges instead
  edb_raster_range_files, rn_arr(1,), rn_arr(2,), , rn_start, rn_stop;
}
