// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func get_date(text) {
/* DOCUMENT get_date(text)
   Given an arbitrary string of text, this will parse out the date and return
   it in YYYY-MM-DD format.

   This will match using the following rules:
   * The date must be at the beginning of the string.
   * The date may be in YYYY-MM-DD or YYYYMMDD format. (But cannot be in
     YYYY-MMDD or YYYYMM-DD format.)
   * If there are any characters following the date, the first must not be a
     number. (So 20020101pm is okay but 200201019 is not.)

   If text is an array of strings, then an array of strings (with the same
   dimensions) will be returned.

   If a string does not contain a parseable date, then the nil string
   (string(0)) will be returned instead.
*/
   // Original David Nagle 2008-12-24 (as part of ytime.i's
   // determine_gps_time_correction)
   // The year may be in the range 1970 to 2099.
   yreg = "19[789][0-9]|20[0-9][0-9]";
   // The month may be in the range 01 to 12.
   mreg = "0[1-9]|1[0-2]";
   // The day may be in the range 01 to 31.
   dreg = "0[1-9]|[12][0-9]|3[01]";

   full_reg = swrite(format="^(%s)(-?)(%s)\\2(%s)($|[^0-9])", yreg, mreg, dreg);

   m_full = m_year = m_dash = m_month = m_day = [];
   w = where(regmatch(full_reg, text, m_full, m_year, m_dash, m_month, m_day));
   
   result = array(string(0), dimsof(text));
   if(numberof(w)) {
      result(w) = swrite(format="%s-%s-%s", m_year(w), m_month(w), m_day(w));
   }

   return result;
}

func cir_to_soe(filename, offset=) {
/* DOCUMENT cir_to_soe(filename, offset=)
   Parses a CIR image's filename and returns the second of the epoch from when
   it was taken.

   Three formats of CIR image filename are handled. The first two are for CIR
   images acquired starting in 2004:
      MMDDYY-HHMMSS-cir.jpg
      MMDDYY-HHMMSS-FFF-cir.jpg
   Where MM is a month 00-11 (add 1 to get the real month) and FFF is a
   fractional second value that is ignored; all other fields are as expected.
   The third format handled is for the new format CIR images acquired starting
   in 2010/2011:
      YYYYMMDD-HHMMSS.FFFF.jpg
   Where FFFF is fractional seconds and is *not* ignored and all other fields
   are as expected.

   offset specifies an offset to apply to the raw soe value. By default, the
   first two formats receive an offset of offset=1.12 which should correct them
   to the correct time value. The third format receives no offset (offset=0) by
   default).

   This can handle array input, and can even handle an array of strings where
   each of the three formats are represented.
*/
// Original David B. Nagle 2009-02-23
   dmreg = "0[0-9]|1[01]";             // (date) month reg exp 00-11
   ddreg = "0[1-9]|[12][0-9]|3[01]";   // (date) day reg exp 01-31
   dyreg = "[890123][0-9]";            // (date) year reg exp 80-39
   threg = "[01][0-9]|2[0-3]";         // (time) hour reg exp 00-23
   tmreg = "[0-5][0-9]";               // (time) minute reg exp 00-59
   tsreg = "[0-5][0-9]";               // (time) second reg exp 00-59
   tfreg = "[0-9][0-9][0-9]";          // (time) frac reg 000-999 ignored

   full_reg = swrite(format="^(%s)(%s)(%s)-(%s)(%s)(%s)(-%s)?-cir.jpg$",
      dmreg, ddreg, dyreg, threg, tmreg, tsreg, tfreg);
   
   m_full = m_dm = m_dd = m_dy = m_th = m_tm = m_ts = [];
   w = where(regmatch(full_reg, filename, m_full,
      m_dm, m_dd, m_dy, m_th, m_tm, m_ts));

   result = array(double(-1), dimsof(filename));
   if(numberof(w)) {
      off = is_void(offset) ? 1.12 : offset;
      yy = atod(m_dy(w));
      c20 = yy > 60; // 20th century
      yyyy = array(double, dimsof(yy));
      if(anyof(c20))
         yyyy(where(c20)) = yy(where(c20)) + 1900;
      if(nallof(c20))
         yyyy(where(!c20)) = yy(where(!c20)) + 2000;

      result(w) = ymd2soe(
         yyyy, atod(m_dm(w))+1, atod(m_dd(w)),
         hms2sod(atod(m_th(w)), atod(m_tm(w)), off + atod(m_ts(w))));
   }

   dmreg = "0[1-9]|1[12]";             // (date) month reg exp 01-12
   dyreg = "20[1-6][0-9]";             // (date) year reg exp 10-69
   tfreg = "[0-9][0-9][0-9][0-9]";     // (time) fraction sec reg 0000 - 9999

   full_reg = swrite(format="^(%s)(%s)(%s)-(%s)(%s)(%s).(%s).jpg$",
      dyreg, dmreg, ddreg, threg, tmreg, tsreg, tfreg);

   m_full = m_dy = m_dm = m_dd = m_th = m_tm = m_ts = m_tf = [];
   w = where(regmatch(full_reg, filename, m_full,
      m_dy, m_dm, m_dd, m_th, m_tm, m_ts, m_tf));

   if(numberof(w)) {
      off = is_void(offset) ? 0. : offset;
      secs = off + atod(m_ts(w)) + atod(m_tf(w))/10000.;
      result(w) = ymd2soe(atod(m_dy(w)), atod(m_dm(w)), atod(m_dd(w)),
         hms2sod(atod(m_th(w)), atod(m_tm(w)), secs));
   }

   return result;
}

func cam_to_soe(filename, offset=) {
/* DOCUMENT cam_to_soe(filename, offset=)
   Parses an RGB image's filename and returns the second of the epoch from when
   it was taken.

   offset specifies an offset to apply to the raw soe value. By default,
   offset=0.
*/
   default, offset, 0;

   dmreg = "0[1-9]|1[02]";             // (date) month reg exp 01-12
   ddreg = "0[1-9]|[12][0-9]|3[01]";   // (date) day reg exp 01-31
   dyreg = "[12][90][890123][0-9]";    // (date) year reg exp 1980-2039
   threg = "[01][0-9]|2[0-3]";         // (time) hour reg exp 00-23
   tmreg = "[0-5][0-9]";               // (time) minute reg exp 00-59
   tsreg = "[0-5][0-9]";               // (time) second reg exp 00-59

   reg = "^cam1(47|)_(CAM1_|)";
   reg += swrite(format="(%s)(-|_)(%s)(-|)(%s)_", dyreg, dmreg, ddreg);
   reg += swrite(format="(%s)(%s)(%s)([-_][0-9][0-9]|)\.jpg$", threg, tmreg, tsreg);

   m_full = m_dm = m_dd = m_dy = m_th = m_tm = m_ts = m_no = [];
   w = where(regmatch(reg, filename, m_full,
      m_no, m_no, m_dy, m_no, m_dm, m_no, m_dd, m_th, m_tm, m_ts, m_no));

   result = array(double(-1), dimsof(filename));
   if(numberof(w)) {
      result(w) = ymd2soe(
         atod(m_dy(w)), atod(m_dm(w)), atod(m_dd(w)),
         hms2sod(atod(m_th(w)), atod(m_tm(w)), offset+atod(m_ts(w))));
   }

   return result;
}

func parse_rn(rn) {
/* DOCUMENT parse_rn(rn)
   Simple wrapper that returns [rasterno, pulseno] for the given rn.
*/
// Original David Nagle 2009-07-21
   return [rn&0xffffff, rn/0xffffff];
}

func parse_datum(text) {
/* DOCUMENT parse_datum(text)
   Given a text string, this parses the datum information out of it if possible.

   This expects to find the datum formatted in one of the following kinds of
   ways:

      WGS-84:
         *_w84_* *_w84.* w84_*
      NAD-83:
         *_n83_* *_n83.* n83_*
      NAVD-88 without geoid:
         *_n88_* *_n88.* n88_*
      NAVD-88 with geoid:
         *_n88_g96_* *_n88_g96.* n88_g96_*
         *_n88_g99_* *_n88_g99.* n88_g99_*
         *_n88_g03_* *_n88_g03.* n88_g03_*
         *_n88_g03dep_* *_n88_g03dep.* n88_g03dep_*
         *_n88_g06_* *_n88_g06.* n88_g06_*
         *_n88_g09_* *_n88_g09.* n88_g09_*

   Four pieces of information will be returned: [datum, geoid, prefix, suffix]
   These pieces are:
      datum: The datum string, one of "w84", "n83", or "n88".
      geoid: The geoid string, one of "96", "99", "03", "03dep", "06", or
         "09". ("03dep" is for the deprecated version of GEOID03.)
      prefix: Anything in "text" that came before the datum/geoid.
      suffix: Anything in "text" that came after the datum/geoid.

   If no datum could be parsed, then all four values will be (nil).
   If no geoid could be parsed or if it is not applicable, it will be (nil).

   This can handle array input as well as scalar. For arrays, you can index
   the results as follows:
      result(..,1) - datum
      result(..,2) - geoid
      result(..,3) - prefix
      result(..,4) - suffix
*/
// Original David Nagle 2009-12-24
   scalar = is_scalar(text);

   part1 = part2 = part3 = datum = geoid = [];
   regmatch, "(^.*?(^|_))(w84|n83|n88)((\.|_|$).*$)", text, , part1, , datum, part2;
   regmatch, "^_g(96|99|03dep|03|06|09)((\.|_|$).*$)", part2, , geoid, part3;

   w = where(datum != "n88");
   if(numberof(w)) {
      if(scalar)
         geoid = string(0);
      else
         geoid(w) = string(0);
   }

   w = where(strlen(geoid));
   if(numberof(w)) {
      if(scalar)
         part2 = part3;
      else
         part2(w) = part3(w);
   }

   part3 = [];

   return [datum, geoid, part1, part2];
}
