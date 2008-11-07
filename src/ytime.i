/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

local ytime_i;
/* DOCUMENT ytime.i

   Functions to manipulate 32 bit time of day values.  These functions convert
   to/from soe, sod, and hms.  Hms is hours-minutes-seconds, soe is
   seconds-of-epoch (since midnight, Jan 1, 1970), and sod is seconds-of-day.
   There are 86400 seconds in a day.

   See also:
      getsod soe2sod soe2time hms2sod sod2hms time2soe time_correct is_leap
      year_cum_months soe2ymd ymd2doy time_plot time_diff
*/

extern _ys;
/* DOCUMENT _ys
   Array of integers representing the seconds of the year at midnight, Jan 1,
   in GMT for all years covered by a 32 bit seconds counter starting on Jan 1,
   1970 at midnight GMT. _ys(0) is for 1970, etc.
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

func getsod(void) {
/* DOCUMENT getsod()

   Returns the current SOD based on Yorick's timestamp() function.

   See also:
      timestamp parsedate
*/
   return (parsedate(timestamp())(4:6)*[3600,60,1])(sum);
}

func soe2sod(soe) {
/* DOCUMENT soe2sod(soe)   
            soe2somd(soe)

   Convert a soe time to an sod. Data type of return value is the same as
   the data type of soe.

   See also:
      soe2sod soe2time hms2sod sod2hms time2soe

*/
   return soe % 86400;
}

// Alias
soe2somd = soe2sod;

func soe2time( soe ) {
/* DOCUMENT soe2time( soe )
   This function converts a time/date seconds value such as used by Unix and
   DOS system into a return array consisting of:
      t(1)   Year
      t(2)  Day of Year
      t(3)  Seconds of the day
      t(4)  Hour 
      t(5)  Minute
      t(6)  Seconds

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
      to July 17, 2001 at 12am GMT.  You can easily generate time values with
      tcl clock scan. For example:
      clock scan "6/17/2001 12:00" -gmt 1
      returns 992779200

   Original: W. Wright wright@lidar.wff.nasa.gov 7/19/2001

   See also:
      soe2sod soe2time hms2sod sod2hms time2soe
*/
   t = array(int, 6 );
   t(1) = where ( soe >= _ys ) (0);          // Find starting seconds-of-year index
   t(2) = (soe - _ys( t(1) ) ) / 86400 + 1;  // Compute day-of-year ( Julian day??)
   t(3) = (soe - _ys( t(1) ) ) % 86400;      // Compute seconds-of-the-day
   t(1) += 1969;                             // Convert index into year
   t(4) = t(3) / 3600;                       // hours
   t(5) = (t(3) - (t(4)*3600))/60;           // Minutes
   t(6) = t(3) % 60;                         // Seconds
   return t;
}

func hms2sod ( t ) {
/* DOCUMENT hms2sod( t ) 
  
   Convert an HMS value to sod (seconds-of-day).  The HMS is in a form such
   as 120000 for 12 hours, 0 minutes, and 0 seconds. The type of the return
   value will match the type of the argument passed.

   See also:
      soe2sod soe2time hms2sod sod2hms time2soe
*/
   h = int(int(t) / 10000);
   m = (int(t) - int(h*10000)) / 100;
   s = t - (h*10000+m*100);
   sod = h*3600 + m*60 + s;
   return sod;
}

func sod2hms( a, noary=, decimal= ) {
/* DOCUMENT sod2hms(a, noary=, decimal=)
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

   See also:
      soe2sod soe2time hms2sod sod2hms time2soe
      rbgga.i: gga_find_times
*/
   hms = array(double, 3, numberof(a));
   hms(1,) = int(a/3600);     // find hours
   hms(2,) = int((a - int(hms(1,))*3600)/60);
   hms(3,) = a % 60;
   if(!decimal)
      hms = int(hms);
   if(noary)
      return (hms*[10^4,10^2,1])(sum,);
   else
      return hms;
}

func time2soe( a ) {
/* DOCUMENT time2sie( a ) 
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

   See also:
      soe2sod soe2time hms2sod sod2hms time2soe

   Original: W. Wright wright@lidar.wff.nasa.gov
*/
   idx = int(a(*,1)) - 1969;  // convert to index
   a(*,2)--;                  // convert to zero-based day number
   usehms = a(*,3) == 0;
   if(numberof(where(usehms)))
      a(*,3)(where(usehms)) = (a(*,4:6)(where(usehms)) * [3600,60,1])(sum);
   return _ys(idx) + a(*,2)*86400 + a(*,3);
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
   if(y % 4 != 0) leap = 0;
   else {
      if(y % 100 == 0 && y % 400 != 0) leap = 0;
      else leap = 1;
   }
   return leap;
}

func year_cum_months(year) {
/* DOCUMENT year_cum_months(year)
   For a given year, return the cumulative days for each month. (Includes
   leap days.)
*/
   months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
   months(2) += is_leap(year);
   return months(cum);
}

func soe2ymd(soe) {  
/* DOCUMENT soe2ymd(soe) 
   Function converts soe to ymd format: year, month, day.
   
   Input: soe

   Output is 3-value array where:
      array(1) = year
      array(2) = month
      array(3) = day
*/
   timevals = soe2time(soe);
   y = timevals(1);
   doy = timevals(2);
   
   months = year_cum_months(y);
   m = digitize(doy, months(2:)+1);
   d = doy - months(m);
   return int([y,m,d]);
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
   doy = ymd2doy(y, m, d);
   soe = time2soe([y, doy, sod, 0, 0, 0]);
   return soe;
}

func ymd2doy(y, m, d) {
/* DOCUMENT ymd2doy(y, m, d)
            ymd2doy(ymd)

   Given a year-month-day, this will return the day-of-year.

   If one argument is given, it should be in the form YYYYMMDD.

   If three arguments are given, they should be year, month, day.
*/
   if(is_void(m) && is_void(d)) {
      if(typeof(ymd) == "string") {
         y = m = d = 0;
         sread, format="%4d%2d%2d", y, m, d;
      } else {
         ymd = int(y);
         md = ymd % 10000;
         d = md % 100;
         m = (md - d) / 100;
         y = (ymd - md) / 10000;
      }
   }

   // The lengths of each month
   months = year_cum_months(y);

   return months(m) + d;
}

extern _leap_dates;
/* DOCUMENT _leap_dates
   Array of strings representing the dates on which leap seconds were added to UTC.
*/
_leap_dates = [
   "1981-06-30", "1982-06-30", "1983-06-30", "1985-06-30", "1987-12-31",
   "1989-12-31", "1990-12-31", "1992-06-30", "1993-06-30", "1994-06-30",
   "1995-12-31", "1997-06-30", "1998-12-31", "2005-12-31"
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
   res = (_leap_dates(*,) < date)(,sum);
   if(dimsof(date)(1))
      return res;
   else
      return res(1);
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
