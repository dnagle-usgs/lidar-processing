// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_file_readable(filename) {
/* DOCUMENT file_readable(filename)
  Returns 1 or 0 indicating whether the specified filename is readable.
*/
  if(dimsof(filename)(1)) {
    result = array(short, dimsof(filename));
    for(i = 1; i <= numberof(filename); i++) {
      result(i) = file_readable(filename(i));
    }
    return result;
  } else {
    if(catch(-1)) {
      return 0;
    }
    f = open(filename, "rb");
    return 1;
  }
}
if(!is_func(file_readable)) file_readable = nocalps_file_readable;
