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
