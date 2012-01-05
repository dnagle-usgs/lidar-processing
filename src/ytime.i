// vim: set ts=2 sts=2 sw=2 ai sr et:

extern _ys;
/* DOCUMENT _ys
  Array of integers representing the seconds of the epoch at midnight, Jan 1,
  in GMT for all years covered by a 32 bit seconds counter starting on Jan 1,
  1970 at midnight GMT. _ys(1) is for 1970, etc.
*/
/* Older versions generated _ys externally with the following Tcl code, then
  copied/pasted the full data array into this file.

  for { set y 1970 } { $y < 2038 } { incr y } {
    set s [ clock scan 1/1/$y -gmt 1 ]
    puts " $s,     // $y"
  }
*/

__years = indgen(1970:2037);
_ys = array(365*24*60*60, numberof(__years));
_ys(where(__years % 4 == 0)) += 24 * 60 * 60;
_ys = _ys(cum)(:-1);
__years = [];

__months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

func getsod(void) {
/* DOCUMENT getsod()

  Returns the current SOD based on Yorick's timestamp() function.

  SEE ALSO: timestamp, parsedate, getsoe
*/
  return (parsedate(timestamp())(4:6)*[3600,60,1])(sum);
}

func getsoe(void) {
/* DOCUMENT getsoe()

  Returns the current SOE based on Yorick's timestamp() function.

  SEE ALSO: timestamp, getsod
*/
  soe = [];
  timestamp, soe;
  return soe;
}

func soe2sod(soe) {
/* DOCUMENT soe2sod(soe)
        soe2somd(soe)

  Convert a soe time to an sod. Data type of return value is the same as
  the data type of soe.

  SEE ALSO: soe2sod soe2time hms2sod sod2hms time2soe

*/
  return soe % 86400;
}

// Alias
soe2somd = soe2sod;

func soe2time(soe) {
/* DOCUMENT soe2time(soe)
  This function converts a time/date seconds value such as used by Unix and
  DOS system into a return array consisting of:
    t(..,1)  Year
    t(..,2)  Day of Year
    t(..,3)  Seconds of the day
    t(..,4)  Hour
    t(..,5)  Minute
    t(..,6)  Seconds

  For more information, try:
    man n clock
    man date
    man gettimeofday
    man ftime
    man time

  or from Yorick:
    help, timestamp

  Usage Example:   soe2time( 992779200 )
    returns the array [2001,167,43200,12,0,0]  giving the year, year-day,
    seconds-of-day, hour, minutes, seconds.  The 992779200 value corresponds
    to June 17, 2001 at 12am GMT.  You can easily generate time values with
    tcl clock scan. For example:
    clock scan "6/17/2001 12:00" -gmt 1
    returns 992779200

  Original: W. Wright wright@lidar.wff.nasa.gov 7/19/2001

  SEE ALSO: soe2sod soe2time hms2sod sod2hms time2soe
*/
  yd = soe2yd(soe);
  sod = soe2sod(soe);
  hms = sod2hms(sod);
  return grow(unref(yd), sod(..,-), unref(hms));
}

func soe2yd(soe) {
/* DOCUMENT soe2yd(soe)
  Converts a seconds-of-the-epoch value into year, day-of-year values.
*/
  extern _ys;
  y = digitize(soe, _ys) - 1;
  d = int((soe - _ys(y)) / 86400 + 1);
  y += 1969;
  return [y, d];
}

func hms2sod (h, m, s) {
/* DOCUMENT hms2sod(hms)
  hms2sod(h, m, s)

  Convert an HMS value to sod (seconds-of-day). The HMS can be provided in two
  ways:

    hms2sod(hms), where hms is in the format 1200000 for 12:00:00.
    hms2sod(h,m,s), where h, m, and s are 12, 00, and 00 for 12:00:00.

  The return value will have the same type and dimensions as the input
  value(s). If h, m, and s are arrays, they must be conformable.

  SEE ALSO: soe2sod soe2time hms2sod sod2hms time2soe
*/
  if(is_void(m)) {
    t = h;
    h = int(int(t) / 10000);
    m = (int(t) - int(h*10000)) / 100;
    s = t - (h*10000+m*100);
  }
  sod = h*3600 + m*60 + s;
  return sod;
}

func sod2hms(sod, noary=, decimal=, str=) {
/* DOCUMENT sod2hms(sod, noary=, decimal=, str=)

  Converts a second-of-the-day time value to a hours-minutes-seconds value.

  With no options specified, it will return an array conformable with sod,
  adding a final dimension of length 3, as such:

    [hours, minutes, seconds]

  If decimal is 0 (or omitted) the values will be long integers; otherwise,
  doubles.

  If noary=1, an array of equivalent dimensions to sod will be returned with
  numerical values in the format HHMMSS (or if decimal=1, HHMMSS.SSS).

  Convert an sod (second-of-day) time value to a three element
  array consisting of hours, minutes, and seconds.  This can be used
  where you need hours-minutes-seconds.  For example, you can use:

    hms = sod2hms( gga(1, q) );
    qq = where ((hms(3,) (dif) ) != 0 );
    write,format="cam1/cam1_2001_0714_%d%d%d_01.jpg\n", hms(1,),hms(2,),hms(3,)

  to generate EAARL digital camera photo reference file names from the gps
  data.

  A non-zero value for noary= will cause the values to be returned as a
  floats such that 120000 is 12 hours, 0 minutes, and 0 seconds.

  If decimal is set to 1, then the return values will be doubles. Otherwise,
  they will be integers.

  SEE ALSO: soe2sod soe2time hms2sod sod2hms time2soe gga_find_times
*/
  default, noary, 0;
  default, decimal, 0;
  default, str, 0;

  if(str)
    return swrite(format="%06d", sod2hms(unref(sod), noary=1));

  hours = int(sod/3600);
  minutes = int((sod - hours*3600)/60);
  seconds = unref(sod) % 60;

  if(decimal)
    seconds = double(unref(seconds));
  else
    seconds = long(unref(seconds));

  if(noary)
    return hours * 10000 + minutes * 100 + seconds;
  else
    return [hours, minutes, seconds];
}

func time2soe( a ) {
/* DOCUMENT time2soe( a )
  Converts an array of date/time values to a Unix/DOS seconds of the
  Epoch value (SOE).

  Example:
    time2soe( [2001,191,43200,12,0,0] );
  returns: 994766400
  a(1) year;
  a(2) year-day;
  a(3) second-of-the-day;
  a(4) hours
  a(5) minutes
  a(6) seconds;

  If a(3) is zero, then it will use a(4:6) to compute the seconds of
  the day, and then compute the SOE.  If a(3) is non-zero, then it
  ignores a(4:6).

  SEE ALSO: soe2sod soe2time hms2sod sod2hms time2soe

  Original: W. Wright wright@lidar.wff.nasa.gov
*/
  extern _ys;
  // SOE values only fit in doubles and longs
  if(is_real(a))
    a = double(a);
  else if(is_integer(a))
    a = long(a);
  idx = int(a(..,1)) - 1969;  // convert to index
  a(..,2)--;                  // convert to zero-based day number
  usehms = a(..,3) == 0;
  if(anyof(usehms)) {
    temp = a(..,3);
    temp(where(usehms)) = 3600 * a(..,4)(where(usehms)) +
      60 * a(..,5)(where(usehms)) + a(..,6)(where(usehms));
    a(..,3) = temp;
    temp = [];
  }
  return _ys(idx) + a(..,2)*86400 + a(..,3);
}

func time_correct (path) {
  extern tca, edb;
  fname = path+"tca.pbd";
  if (catch(0x02)) {
    return;
  }
  f = openb(fname);
  restore, f, tca;
  edb.seconds = edb.seconds + tca;
  close, f;
}

func is_leap(y) {
/* DOCUMENT is_leap(year)
  Returns 1 if year is a leap year, 0 otherwise.
*/
  leap = ((y % 4 == 0) & (y % 100 != 0)) | (y % 400 == 0);
  return leap;
}

func soe2ymd(soe) {
/* DOCUMENT soe2ymd(soe)
  Function converts soe to ymd format: year, month, day.

  Input: soe

  Output is 3-value array where:
    array(..,1) = year
    array(..,2) = month
    array(..,3) = day
*/
  extern __months;

  yd = soe2yd(soe);
  year = yd(..,1);
  doy = yd(..,2);
  yd = [];

  leaps = is_leap(year);
  wy = where(leaps);
  wn = where(!leaps);

  my = dy = mn = dn = [];
  if(numberof(wy)) {
    months = __months;
    months(2) += 1;
    months = months(cum);
    my = digitize(doy(wy), months(2:)+1);
    dy = doy(wy) - months(my);
  }
  if(numberof(wn)) {
    months = __months(cum);
    mn = digitize(doy(wn), months(2:)+1);
    dn = doy(wn) - months(mn);
  }
  month = merge(my, mn, leaps);
  day = merge(dy, dn, leaps);

  return [year, month, day];
}

func ymd2date(year, month, day) {
/* DOCUMENT date = ymd2date(year, month, day);
  date = ymd2date(ymd);

  Converts ymd format to date format. Input can either be an array of [year,
  moth, day] or can be three separate arrays of year, month, day (which must
  all have the same dimensions). Output will be conformable with input.

  The output is in string format as "YYYY-MM-DD".
*/
  if(is_void(month)) {
    ymd = year;
    year = ymd(..,1);
    month = ymd(..,2);
    day = ymd(..,3);
    ymd = [];
  }

  return swrite(format="%04d-%02d-%02d",
    unref(year), unref(month), unref(day));
}

func soe2date(soe) {
/* DOCUMENT date = soe2date(soe)
  Given a seconds-of-the-epoch value, returns the date as "YYYY-MM-DD". Output
  will have same dimensions as input.
*/
  return ymd2date(soe2ymd(unref(soe)));
}

func date2soe(date, sod) {
/* DOCUMENT soe = date2soe(date)
  soe = date2soe(date, sod)

  Converts a string date in YYYY-MM-DD format with an optional sod value into
  a seconds of the epoch value.

  If sod is not specified, it defaults to 0. This can be useful to determine
  the offset to add to a set of sod values to convert them all to soe values
  when they all share the same date.
*/
// Original David B. Nagle 2009-05-18
  date = get_date(unref(date));
  y = atoi(strpart(date, 1:4));
  m = atoi(strpart(date, 6:7));
  d = atoi(strpart(date, 9:10));
  return ymd2soe(y, m, d, sod);
}

func ymd2soe(y, m, d, sod) {
/* DOCUMENT soe = ymd2soe(y, m, d)
  soe = ymd2soe(y, m, d, sod)

  Converts a year, month, day, and sod into a seconds of the epoch value.

  If sod is not specified, it defaults to 0. This can be useful to determine
  the offset to add to a set of sod values to convert them all to soe values
  when they all share the same date.

  The values y, m, and d should all be scalar integers. If provided, sod can
  be either a scalar or an array.
*/
// Original David Nagle 2008-11-07
  default, sod, 0;
  doy = ymd2doy(y, unref(m), unref(d));
  return time2soe([unref(y), unref(doy), 0, 0, 0, 0]) + unref(sod);
}

func ymd2doy(year, month, day) {
/* DOCUMENT ymd2doy(y, m, d)
        ymd2doy(ymd)

  Given a year-month-day, this will return the day-of-year.

  If one argument is given, it should be in the form YYYYMMDD.

  If three arguments are given, they should be year, month, day. Year, month,
  and day must be conformable.

  Output will be conformable with input.
*/
  extern __months;

  if(is_void(month) && is_void(day)) {
    if(typeof(year) == "string") {
      ymd = year;
      year = month = day = array(int, dimsof(ymd));
      sread, ymd, format="%4d%2d%2d", year, month, day;
    } else {
      ymd = int(year);
      md = ymd % 10000;
      day = md % 100;
      month = (md - day) / 100;
      year = (ymd - md) / 10000;
    }
  }

  leaps = is_leap(year);
  wy = where(leaps);
  wn = where(!leaps);

  my = dy = mn = dn = [];
  if(numberof(wy)) {
    months = __months;
    months(2) += 1;
    months = months(cum);
    doyy = months(long(month(wy))) + day(wy);
  }
  if(numberof(wn)) {
    months = __months(cum);
    doyn = months(long(month(wn))) + day(wn);
  }
  doy = merge(doyy, doyn, leaps);

  return doy;
}

extern _leap_dates;
/* DOCUMENT _leap_dates
  Array of strings representing the dates on which leap seconds were added to
  UTC. This only includes leap dates starting with 1980, which is when GPS
  time was started.
*/
_leap_dates = [
  "1981-06-30", "1982-06-30", "1983-06-30", "1985-06-30", "1987-12-31",
  "1989-12-31", "1990-12-31", "1992-06-30", "1993-06-30", "1994-06-30",
  "1995-12-31", "1997-06-30", "1998-12-31", "2005-12-31", "2008-12-31",
  "2012-06-30"
];

func gps2utc(date, sod) {
/* DOCUMENT gps2utc(date, sod)
  Given a date (formatted as "YYYY-MM-DD") and a GPS time sod, this converts
  it to UTC time sod by applying the leap seconds offset.
*/
  return sod - gps_utc_offset(date);
}

func utc2gps(date, sod) {
/* DOCUMENT utc2gps(date, sod)
  Given a date (formatted as "YYYY-MM-DD") and a GPS time sod, this converts
  it to UTC time sod by applying the leap seconds offset.
*/
  return sod + gps_utc_offset(date);
}

func gps_utc_offset(date) {
/* DOCUMENT gps_utc_offset(date)
  Calculates the leap seconds offset between GPS and UTC for a given date.
*/
  extern _leap_dates;
  if(is_scalar(date))
    return (_leap_dates < date)(sum);

  res = array(short, dimsof(date));
  for(i = 1; i <= numberof(_leap_dates); i++)
    res += _leap_dates(i) < date;
  return res;
}

_gps2utc_epoch_offset = ymd2soe(1980, 1, 6);

func gps_epoch_to_utc_epoch(soe) {
  extern _gps2utc_epoch_offset;
  soe += _gps2utc_epoch_offset;
  sod = soe2sod(soe);
  ymd = soe2date(unref(soe));
  sod = gps2utc(ymd, unref(sod));
  return date2soe(unref(ymd), unref(sod));
}

func utc_epoch_to_gps_epoch(soe) {
  extern _gps2utc_epoch_offset;
  sod = soe2sod(soe);
  ymd = soe2date(unref(soe));
  sod = utc2gps(ymd, unref(sod));
  soe = date2soe(unref(ymd), unref(sod));
  return unref(soe) - _gps2utc_epoch_offset;
}

func soe2gpssow(soe, &week) {
/* DOCUMENT sow = soe2gpssow(soe)
  sow = soe2gpssow(soe, &week)

  Given a seconds-of-the-epoch value, this will return the GPS
  seconds-of-the-week corresponding to it. If the optional second argument is
  given, then the GPS week number will be stored in the variable specified.
*/
// Original David Nagle 209-11-16
  // GPS weeks start on 1980-01-06 and are modulo 1024
  // ymd2soe(1980, 1, 6) => 315964800
  // seconds in a week => 60 * 60 * 24 * 7 => 604800
  week = (long(soe - 315964800) / 604800) % 1024;
  return (soe - 315964800) % 604800;
}

func gpssow2soe(sow, refsoe) {
/* DOCUMENT soe = gpssow2soe(sow, refsoe)
  Given a GPS seconds-of-the-week and a reference seconds-of-the-epoch from
  the same week, this will return the corresponding seconds-of-the-epoch
  value.
*/
  offset = long((refsoe - 315964800) / 604800.) * 604800 + 315964800;
  return offset + sow;
}

/*******************************************************************************
* Plot alt vs sod and then compute the time and cost between two points
* time_plot
* time_diff
*******************************************************************************/

extern data_path;

func time_plot( foo ) {
/* DOCUMENT time_plot( foo )
  Plots alt vs sod
*/
  window,4;
  fma;
  plmk, pnav.alt, pnav.sod, msize=.1, marker=4;
  limits;
}

func time_diff( foo ) {
/* DOCUMENT  time_diff( foo )
  Computes time and cost for a flight
*/
  t = array(double, 2);
  t(1) = mouse()(1);
  t(2) = mouse()(1);
  dec_hr = ( (t(2)-t(1)) / 3600.0 );
  cost = dec_hr * 2000.0;
  write,    format="Mission:  %s\n", data_path;
  write,    format="Hours:    %9.4f\nCost:     %8.3f\n",   dec_hr, cost;
  f = open("/tmp/ALPS_FlightTime.txt", "a");
  write, f, format="Mission:  %s\n", data_path;
  write, f, format="Hours:    %9.4f\nCost:     %8.3f\n\n", dec_hr, cost;
  close,f;
}

func determine_gps_time_correction(fn, verbose=) {
/* DOCUMENT determine_gps_time_correction(fn, verbose=)
  This function determines the gps_time_correction automatically based on the year of the survey.
  If survey date is before year 2006, gps_time_correction = -13.
  If survey date is after year 2006, gps_time_correction = -14.
  The survey date is read from the fn input variable which can either be the global data_path variable or the edb file name when the eaarl database is loaded.
  It is assumed that the data set mission day directory has the following naming convention: yyyy-mm-dd or yyyymmdd.
  If extern gps_time_correction is set, the function returns 1, else returns 0.

  Amar Nayegandhi, 12/23/2007.

  Modified David Nagle 2008-12-24:
  * Now uses gps_utc_offset from ytime.i, which will more easily accomodate
    future leap seconds.
  * No longer requires a mission day directory with name of yyyy-mm-dd or
    yyyymmdd. It will parse out a yyyy-mm-dd or yyyymmdd from the last path
    element that starts with such a sequence.
  * Now outputs a status message so the user knows that the correction has
    been set (or that it hasn't, if this fails).
*/
  extern gps_time_correction;
  default, verbose, 1;
  success = 0;

  parts = file_split(file_dirname(fn));
  dates = get_date(parts);
  w = where(dates);
  if(numberof(w)) {
    ymd = dates(w(0));
    correction = gps_utc_offset(ymd) * -1.0;
    success = 1;

    if(is_void(gps_time_correction) || gps_time_correction != correction) {
      gps_time_correction = correction;
      if(verbose) {
        write, format=" *** NOTE: gps_time_correction is now set to %.1f seconds\n", gps_time_correction;
        write, format=" ***       based on detected date: %s\n", ymd;
      }
    }
  } else if(verbose && is_void(gps_time_correction)) {
    write, "*** NOTE: gps_time_correction could not be set!";
    write, "***       You will have to set it manually. You may also have to manually";
    write, "***       apply it to some of the data you have loaded."
  }

  return success;
}

func soe2iso8601(soe) {
/* DOCUMENT soe2iso8601(soe)
  Converts a seconds-of-the-epoch value into a date-time string that's
  compatible with ISO 8601:

    YYYY-MM-DD HH:MM:SS

  SEE ALSO: soe2sod soe2time soe2ymd
*/
// Original David Nagle 2009-01-07
  ymd = int(soe2ymd(soe));
  time = int(soe2time(soe));
  return swrite(format="%04d-%02d-%02d %02d:%02d:%02d",
    ymd(..,1), ymd(..,2), ymd(..,3), time(..,4), time(..,5), time(..,6));
}

func seconds2prettytime(seconds, maxparts=) {
/* DOCUMENT seconds2prettytime(seconds, maxparts=)
  Converts a duration in seconds to a pretty-printed text representation of
  the same duration.

  If maxparts is used, it limits how many parts will get emitted. It is only
  compatible with scalar input.

  Examples:
    > seconds2prettytime(0)
    "0 seconds"
    > seconds2prettytime(1)
    "1 second"
    > seconds2prettytime(100)
    "1 minute, 40 seconds"
    > seconds2prettytime(3600)
    "1 hour"
    > seconds2prettytime(3000000)
    "4 weeks, 6 days, 17 hours, 20 minutes"
    > seconds2prettytime([1,2,3,4])
    ["1 second","2 seconds","3 seconds","4 seconds"]
    > seconds2prettytime([[1,2],[3,4]])
    [["1 second","2 seconds"],["3 seconds","4 seconds"]]
    > seconds2prettytime(1.234)
    "1 second"
    > seconds2prettytime(3000000, maxparts=2)
    "4 weeks, 6 days"
    > seconds2prettytime(86401)
    "1 day, 1 second"
    > seconds2prettytime(86401, maxparts=2)
    "1 days"
*/
// Original David Nagle 2009-12-29
  dims = dimsof(seconds);
  if(!is_void(maxparts) && !is_scalar(seconds))
    error, "maxparts= only compatible with scalars.";
  seconds = reform(long(seconds), [1, numberof(seconds)]);
  s = seconds % 60;
  m = (seconds / 60) % 60;
  h = (seconds / 3600) % 24;
  d = (seconds / 86400) % 7;
  w = seconds / 604800;
  vals = [w,d,h,m,s];
  names = array(["week","day","hour", "minute", "second"], numberof(seconds));
  names = transpose(names);
  if(maxparts) {
    w = where(vals != 0);
    if(numberof(w)) {
      discard = w(1) + maxparts;
      if(discard <= numberof(vals))
        vals(discard:numberof(vals)) = 0;
    }
  }
  w = where(vals != 1);
  if(numberof(w))
    names(w) += "s";
  pretty = swrite(format="#%d %s, ", vals, names)(,sum);
  pretty = regsub("#0 [^#]*, ", pretty, "", all=1);
  pretty = regsub("#", pretty, "", all=1);
  pretty = regsub(", $", pretty, "");
  w = where(strlen(pretty) == 0);
  if(numberof(w))
    pretty(w) = "0 seconds";
  return dims(0) ? reform(pretty, dims) : pretty(1);
}
