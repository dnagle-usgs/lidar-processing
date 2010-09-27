// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_dt(text, dtlength=) {
/* DOCUMENT extract_dt(text, dtlength=)
   Attempts to extract a data tile name from each string in TEXT.

   Options:
      dtlength= Dictates whether to use the short or long form for data tile
         names. Valid values:
            dtlength="short"     Short form (default)
            dtlength="long"      Long form
*/
   local e, n, z;
   default, dtlength, "short";
   dt2utm_km, text, e, n, z;
   w = where(bool(e) & bool(n) & bool(z));
   result = array(string(0), dimsof(text));
   fmt = (dtlength == "short") ? "e%d_n%d_%d" : "t_e%d000_n%d000_%d";
   if(numberof(w))
      result(w) = swrite(format=fmt, e(w), n(w), z(w));
   return result;
}
