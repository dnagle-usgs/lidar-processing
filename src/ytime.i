/*
   $Id$
*/

local ytime ;
/* DOCUMENT ytime.i

  Functions to manipulate 32 bit time of day values.  These functions
convert to/from soe, sod, and hms.  Hms is hours-minutes-seconds, 
soe is seconds-of-epoch (since midnight, jan 1, 1970), and sod
is seconds-of-day.  There are 86400 seconds in a day.

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe

*/

/* Seconds of the year at midnight, jan 1 in GMT for all years
 covered by a 32 bit seconds counter starting on jan 1, 1970 at
 midnight gmt.
 This stuff generated with the following tcl code:

for { set y 1970 } { $y < 2038 } { incr y } {
  set s [ clock scan 1/1/$y -gmt 1 ]
  puts " $s,     // $y" 
}

*/
_ys = [ 
 0,     // 1970
 31536000,     // 1971
 63072000,     // 1972
 94694400,     // 1973
 126230400,     // 1974
 157766400,     // 1975
 189302400,     // 1976
 220924800,     // 1977
 252460800,     // 1978
 283996800,     // 1979
 315532800,     // 1980
 347155200,     // 1981
 378691200,     // 1982
 410227200,     // 1983
 441763200,     // 1984
 473385600,     // 1985
 504921600,     // 1986
 536457600,     // 1987
 567993600,     // 1988
 599616000,     // 1989
 631152000,     // 1990
 662688000,     // 1991
 694224000,     // 1992
 725846400,     // 1993
 757382400,     // 1994
 788918400,     // 1995
 820454400,     // 1996
 852076800,     // 1997
 883612800,     // 1998
 915148800,     // 1999
 946684800,     // 2000
 978307200,     // 2001
 1009843200,     // 2002
 1041379200,     // 2003
 1072915200,     // 2004
 1104537600,     // 2005
 1136073600,     // 2006
 1167609600,     // 2007
 1199145600,     // 2008
 1230768000,     // 2009
 1262304000,     // 2010
 1293840000,     // 2011
 1325376000,     // 2012
 1356998400,     // 2013
 1388534400,     // 2014
 1420070400,     // 2015
 1451606400,     // 2016
 1483228800,     // 2017
 1514764800,     // 2018
 1546300800,     // 2019
 1577836800,     // 2020
 1609459200,     // 2021
 1640995200,     // 2022
 1672531200,     // 2023
 1704067200,     // 2024
 1735689600,     // 2025
 1767225600,     // 2026
 1798761600,     // 2027
 1830297600,     // 2028
 1861920000,     // 2029
 1893456000,     // 2030
 1924992000,     // 2031
 1956528000,     // 2032
 1988150400,     // 2033
 2019686400,     // 2034
 2051222400,     // 2035
 2082758400,     // 2036
 2114380800     // 2037
 ];

func soe2sod( soe ) {
/* DOCUMENT soe2sod( soe ) 

   Convert a soe time to an sod.

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe

*/

  return int(soe) % 86400;
}



func soe2somd( soe ) {
/* DOCUMENT soe2sod( soe ) 

   Convert a soe time to an somd.

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe soe2somd

*/

  return int(soe) % 86400;
}



func soe2time( soe ) {
/* DOCUMENT soe2time( soe )
   This function converts a time/date seconds value such as used by 
Unix and DOS system into a return array consisting of:
  t(1)	Year
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
  returns the array [2001,167,43200,12,0,0]  giving the 
  year, year-day, seconds-of-day, hour, minutes, seconds.  The 992779200
  value cooresponds to July 17, 2001 at 12am GMT.  You can easily generate
  time values with tcl clock scan. For eaample:
  clock scan "6/17/2001 12:00" -gmt 1
  returns 992779200

  W. Wright wright@lidar.wff.nasa.gov 7/19/2001

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe

*/
  t = array(int, 6 );
  t(1) = where ( soe >= _ys ) (0) ;	// Find starting seconds-of-year index
  t(2) = (soe - _ys( t(1) ) ) / 86400 +1 ; // Compute day-of-year ( Julian day??)
  t(3) = (soe - _ys( t(1) ) ) % 86400;	// Compute seconds-of-the-day
  t(1) += 1969;				// Convert index into year
  t(4) = t(3) / 3600;			// hours
  t(5) = (t(3) - ( t(4)*3600))/60;      // Minutes
  t(6) = t(3) % 60;			// Seconds
  return t;
}

func hms2sod ( t ) {
/* DOCUMENT hms2sod( t ) 
  
   Convert an HMS value to sod (seconds-of-day).  The HMS is
in int form such as 120000 for 12 hours, 0 minutes, and 0 seconds.

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe

*/
   t = int(t);
    h = int ( t / 10000 );
    m = (t - int(h*10000 )) / 100   ;
    s = t - ( h*10000+m*100)
   sod = h*3600 + m*60 + s;
   return sod
}

func sod2hms( a ) {
/* DOCUMENT sod2hms(a)
   Convert an sod (second-of-day) time value to a three element
   array consisting of hours, minutes, and seconds.  This can be used
   where you need hours-minutes-seconds.  For example, you can use:

 hms = sod2hms( gga(1, q) );
  qq = where ((hms(3,) (dif) ) != 0 );
 write,format="cam1/cam1_2001_0714_%d%d%d_01.jpg\n", hms(1,),hms(2,),hms(3,)
 
  to generate EAARL digital camera photo reference file names from the
  gps data.

  See also:
    soe2sod soe2time hms2sod sod2hms time2soe

            rbgga.i: gga_find_times
  
*/
  hms = array(int, 3, numberof(a) );
  hms(1,) = int( a/3600 );		// find hours
  hms(2,) = (a - hms(1,)*3600)/60;
  hms(3,) = a % 60;
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


   W. Wright wright@lidar.wff.nasa.gov
*/
 idx = a(1) - 1969;		// convert to index
 a(2)--;			// convert to zero-based day number
 if ( a(3) == 0 ) 
   sod = a(4)*3600 + a(5)*60 + a(6) 
 else 
   sod = a(3);
   soe = _ys(idx) + a(2)*86400 + sod; 
 return soe;
}

func time_correct (path) {
   extern tca, edb ;
   fname = path+"tca.pbd";
   if (catch(0x02)) {
    return
   }
   f = openb(fname);
   restore, f, tca;
   edb.seconds = edb.seconds + tca;
   close, f;
}

func soe2ymd(soe) {	
/* DOCUMENT soe2ymd(soe) 
	Function converts soe to ymd format: year, month, day.
	
	Input: soe

	Output is 3-value array where:
		array(1) = year
		array(2) = month
		array(3) = day

	L. Mosher, 20031125
*/
	timevals = soe2time(soe);
	y = timevals(1);
	doy = timevals(2);
	
	if(y % 4 != 0) { leap = 0; }
	else {
		if(y % 100 == 0 && y % 400 != 0) { leap = 0; }
		else { leap = 1; }
	}
	
	if      (doy <= 31     ) {m =  1;d=doy         ;}
	else if (doy <= 59+leap) {m =  2;d=doy-31      ;}
	else if (doy <= 90+leap) {m =  3;d=doy-59 -leap;}
	else if (doy <=120+leap) {m =  4;d=doy-90 -leap;}
	else if (doy <=151+leap) {m =  5;d=doy-120-leap;}
	else if (doy <=181+leap) {m =  6;d=doy-151-leap;}
	else if (doy <=212+leap) {m =  7;d=doy-181-leap;}
	else if (doy <=243+leap) {m =  8;d=doy-212-leap;}
	else if (doy <=273+leap) {m =  9;d=doy-243-leap;}
	else if (doy <=304+leap) {m = 10;d=doy-273-leap;}
	else if (doy <=334+leap) {m = 11;d=doy-304-leap;}
	else                     {m = 12;d=doy-334-leap;}
	
	ymd = array(int, 3);
	ymd(1) = y;
	ymd(2) = m;
	ymd(3) = d;
	return ymd;	
}


/*


********************************************************************************

Plot alt vs sod and then compute the time and cost between two points
time_plot
time_diff

********************************************************************************

*/

extern data_path;

func time_plot( foo ) {
/* DOCUMENT time_plot( foo )
   Plots alt vs sod
*/
  window,4; fma
  plmk, pnav.alt, pnav.sod, msize=.1, marker=4
  limits
}

func time_diff( foo ) {
/* DOCUMENT  time_diff( foo )
   Computes time and cost for a flight
*/

  t = array(double, 2)
  t(1) = mouse()(1);
  t(2) = mouse()(1);
  dec_hr = ( (t(2)-t(1)) / 3600.0 )
  cost = dec_hr * 2000.0
  write,    format="Mission:  %s\n", data_path
  write,    format="Hours:    %9.4f\nCost:     %8.3f\n",   dec_hr, cost
  f = open("/tmp/ALPS_FlightTime.txt", "a")
  write, f, format="Mission:  %s\n", data_path
  write, f, format="Hours:    %9.4f\nCost:     %8.3f\n\n", dec_hr, cost
  close,f
}

write,"$Id$"
