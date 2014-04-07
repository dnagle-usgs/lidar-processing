// vim: set ts=2 sts=2 sw=2 ai sr et:

// This is the plugin version of src/calps_compat.i, see that file for details.

scratch = save(scratch, base);
base = file_dirname(current_include())+"/";

if(is_func(calps_compatibility)) {
  if(calps_compatibility() < 5) {
    // Prior to version 4, eaarl_decode_fast only supports scalar
    // eaarl_time_offset
    // Prior to version 5, eaarl_decode_fast hangs (possible infinite loop) on
    // some datasets
    eaarl_decode_fast = [];
  }
}

// Added 2013-09-24
if(!is_func(eaarl_decode_fast))
  include, base+"calps/eaarl_decode_fast.i";

if(!is_func(cent))
  include, base+"calps/cent.i";

if(!is_func(eaarl_fs_rx_cent_eaarlb))
  include, base+"calps/fs_rx.i";

restore, scratch;
