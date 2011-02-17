// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func las_extract_return(data, which=) {
/* DOCUMENT las_extract_return(data, which=)
   Extracts points from LAS_ALPS data based on whether they are first or last
   returns.

   Options:
      which= Specify whether to return first return or last return points.
            which="last"   Return last returns (default)
            which="first"  Return first returns
*/
   default, which, "last";

   w = [];
   if(which == "last") {
      w = where(data.ret_num == data.num_ret);
   } else if(which == "first") {
      w = where(data.ret_num == 1);
   } else {
      error, "Unknown value for which, must be \"first\" or \"last\"";
   }
   if(numberof(w))
      return data(w);
   else
      return [];
}
