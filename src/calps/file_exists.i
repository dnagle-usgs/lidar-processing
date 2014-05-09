// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_file_exists(filename) {
/* DOCUMENT file_exists(filename)

  Checks if the file 'filename' exists.

  Returns '0' if the file does not exist, and '1' if the file exists
*/
  fdir = file_dirname(filename);
  fname = file_tail(filename);
  if(dimsof(filename)(1)) {
    result = array(0, dimsof(filename));
    for(i = 1; i <= numberof(filename); i++) {
      result(i) = numberof(lsfiles(fdir(i), glob=fname(i)));
    }
    return result;
  } else {
    return numberof(lsfiles(fdir, glob=fname));
  }
}
if(!is_func(file_exists)) file_exists = nocalps_file_exists;
