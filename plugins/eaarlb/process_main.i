// vim: set ts=2 sts=2 sw=2 ai sr et:

local eaarl_processing_modes;
/* DOCUMENT eaarl_processing_modes
  This variable defines the routines needed to process EAARL data. New EAARL
  processing modes will get a new entry in this oxy object. This allows the
  processing functions to be generalized and extensible.
*/
if(is_void(eaarl_processing_modes)) eaarl_processing_modes = save();
save, eaarl_processing_modes,
  fs=save(
    process=process_fs,
    cast=fs_struct_from_obj
  ),
  ba=save(
    process=process_ba,
    cast=ba_struct_from_obj
  );

func process_eaarl(start, stop, mode=, ext_bad_att=, channel=, opts=) {
/* DOCUMENT process_eaarl(start, stop, mode=, ext_bad_att=, channel=, opts=)
  Processes EAARL data for the given raster ranges as specified by the given
  mode.

  Parameters:
    start: Raster number to start at. This may also be an array.
    stop: Raster number to stop at. This may also be an array and must match
      the size of START. If omitted, STOP is set to START.

    Alternately:

    start: May be a pulses object as returned by decode_rasters. In this case,
      STOP is ignored.

  Options:
    mode= Processing mode.
        mode="fs"   Process for first surface (default)
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by process_eaarl
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  restore_if_exists, opts, start, stop, mode, ext_bad_att, channel;

  extern eaarl_processing_modes;
  default, mode, "fs";

  if(!eaarl_processing_modes(*,mode))
    error, "invalid mode";
  local process, cast;
  restore, eaarl_processing_modes(noop(mode)), process, cast;

  passopts = save(start, stop, mode, ext_bad_att, channel);
  if(opts)
    passopts = obj_merge(opts, passopts);

  return cast(process(opts=passopts));
}

func make_eaarl(mode=, q=, ply=, ext_bad_att=, channel=, verbose=, opts=) {
/* DOCUMENT make_eaarl(mode=, q=, ply=, ext_bad_att=, channel=, verbose=, opts=)
  Processes EAARL data for the given mode in a region specified by the user.

  Options for selection:
    q= An index into pnav for the region to process.
    ply= A polygon that specifies an area to process. If Q is provided, PLY is
      ignored.
    Note: if neither Q nor PLY are provided, the user will be prompted to draw
    a box to select the region.

  Options for processing:
    mode= Processing mode.
        mode="fs"   Process for first surface (default)
    ext_bad_att= A value in meters. Points less than this close to the mirror
      (in elevation) are discarded. By default, this is 0 and is not applied.
    channel= Specifies which channel or channels to process. If omitted or set
      to 0, EAARL-A style channel selection is used. Otherwise, this can be an
      integer or array of integers for the channels to process.

  Additional options:
    verbose= Specifies verbosity level.
    opts= Oxy group that provides an alternative interface for providing
      function arguments/options. Any key/value pairs not used by process_eaarl
      will be passed through as-is to the underlying processing function.

  Returns:
    An array of EAARL point cloud data, in the struct appropriate for the
    data's type.
*/
  restore_if_exists, opts, mode, q, ply, ext_bad_att, channel, verbose;

  extern ops_conf, tans, pnav;

  default, mode, "fs";
  default, verbose, 1;

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
  rn_start = rn_stop = [];
  edb_raster_range_files, rn_arr(1,), rn_arr(2,), , rn_start, rn_stop;

  rn_counts = (rn_stop - rn_start + 1)(cum)(2:);

  count = numberof(rn_start);
  data = array(pointer, count);

  passopts = save(mode, channel, ext_bad_att, verbose);
  if(opts)
    passopts = obj_delete(obj_merge(opts, passopts), start, stop);

  status, start, msg="Processing; finished CURRENT of COUNT rasters",
    count=rn_counts(0);
  if(verbose)
    write, "Processing...";
  for(i = 1; i <= count; i++) {
    if(verbose) {
      write, format=" %d/%d: rasters %d through %d\n",
        i, count, rn_start(i), rn_stop(i);
    }
    data(i) = &process_eaarl(rn_start(i), rn_stop(i), opts=passopts);
    status, progress, rn_counts(i), rn_counts(0);
  }
  status, finished;

  data = merge_pointers(data);

  if(verbose)
    write, format=" Total points derived: %d\n", numberof(data);

  return data;
}
