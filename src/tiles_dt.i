// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func dt_short(dtcodes) {
/* DOCUMENT shortnames = dt_short(dtcodes)
   Returns abbreviated names for an array of data tile codes. Strings that
   aren't data tile codes become string(0).

   Example:
      > dt_short("t_e466000_n3354000_16")
      "e466_n3354_16"
*/
//  Original David Nagle 2008-07-21
   local e, n, z;
   dt2utm_km, dtcodes, e, n, z;
   w = where(bool(e) & bool(n) & bool(z));
   result = array(string(0), dimsof(dtcodes));
   if(numberof(w))
      result(w) = swrite(format="e%s_n%s_%s", e(w), n(w), z(w));
   return result;
}

func dt_long(dtcodes) {
/* DOCUMENT longnames = dt_long(dtcodes)
   Returns full names for an array of data tile codes. Strings that aren't
   data tile codes become string(0).

   Example:
      > dt_long("e466_n3354_16")
      "t_e466000_n3354000_16"
*/
//  Original David Nagle 2008-08-07
   local e, n, z;
   dt2utm_km, dtcodes, e, n, z;
   w = where(bool(e) & bool(n) & bool(z));
   result = array(string(0), dimsof(dtcodes));
   if(numberof(w))
      result(w) = swrite(format="t_e%s000_n%s000_%s", e(w), n(w), z(w));
   return result;
}

