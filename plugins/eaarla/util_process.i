
func processed_obj2dyn_dual(pulses) {
/* DOCUMENT result = processed_obj2dyn_dual(pulses)
  Converts an oxy group containing pulse data (as returned by one of the
  processing functions, such as process_fs) into an array of struct data. The
  struct is dynamically generated based on the fields present in the group.

  Some additional behavioral notes:
    - a ptime field (type: long) will be added if not present
    - these fields will be removed if present:
      tx, rx, fs_slant_range, irange, scan_angle
    - many fields will be re-ordered; unrecognized fields will be kept in their
      existing order, but moved to the end
    - the output array will use a struct named "DYN_PC_DUAL"; this struct is
      not defined anywhere and will not necessarily be the same across multiple
      calls
*/
  data = obj_copy(pulses);

  // Remove fields that should not go into a final result
  obj_delete, data, tx, rx, fs_slant_range, irange, scan_angle;

  // Make sure ptime field is present
  if(!data(*,"ptime")) save, data, ptime=array(0, dimsof(data.fx));

  // These fields should come first (if present) and in this order
  fields = [
    "raster","pulse","channel","digitizer","ptime","soe",
    "mx","my","mz",
    "fx","fy","fz",
    "lx","ly","lz",
    "fchannel","lchannel",
    "ftx","ltx",
    "frx","lrx",
    "fbias","lbias",
    "fintensity","lintensity",
    "bback1","bback2",
    "ret_num","num_rets"
  ];

  // Retrieve fields that are present
  idx = data(*,fields);
  w = where(idx);
  if(numberof(w)) {
    result = data(idx(w));
  } else {
    result = save();
  }

  // Merge all fields into results. Existing fields keep their ordering, new
  // fields go at the end in their current order.
  obj_merge, result, data;

  return obj2struct(result, name="DYN_PC_DUAL", ary=1);
}
