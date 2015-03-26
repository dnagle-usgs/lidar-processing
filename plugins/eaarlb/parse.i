// vim: set ts=2 sts=2 sw=2 ai sr et:

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

  dmreg = "0[1-9]|1[012]";            // (date) month reg exp 01-12
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

  dmreg = "0[1-9]|1[012]";            // (date) month reg exp 01-12
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
