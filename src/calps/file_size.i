// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_file_size(fn) {
/* DOCUMENT size = file_size(fn)
  Returns the size of the given file in bytes. The file must exist and must be
  readable. Accepts both scalar and array input.
*/
  if(is_scalar(fn)) {
    return sizeof(open(fn, "rb"));
  } else {
    result = array(long, dimsof(fn));
    for(i = 1; i <= numberof(result); i++)
      result(i) = file_size(fn(i));
    return result;
  }
}
if(!is_func(file_size)) file_size = nocalps_file_size;
