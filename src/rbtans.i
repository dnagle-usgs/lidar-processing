/*
 $Id$

  rbtans.i
  This program reads a binary file of tans-vector data generated by
  the tans2bin.c program.  The input data file begines with a single
  32 bit integer which contains the number of tans sample points following
  it in the file.  The points which follow are single precision floating
  point binary values in the following order, sow, roll, pitch, heading.  sow
  is seconds of the week, and the rest are in degrees with pitch and roll 
  varying from -180:+180 and heading from 0:360.
  
Returns an array of type TANS as follows:

   tans.somd	Second of the mission day.
   tans.roll	Degrees of roll
   tans.pitch   Degrees of pitch
   tans.heading Degrees of heading **Note: Heading values range from 
		0 to 360. Passing through 0 or 360 causes a wrap-around
		which will cause invalid results if you try to use the
		data with "interp".  To correct the problem, break the
		heading into it's X and Y components for a unit circle,
		do the interp on those components, and then reform the
		heading in degrees (or radians).

History:
  1/21/02  Added correction for gps time offset. Modified the comments, 
           changed sod to somd.
 11/13/01  Modified to: 1) convert time from sow, to sod, 2) check and
           correct for midnight rollover. -WW

*/

struct TANS {
  double somd;
  float roll;
  float pitch;
  float heading;
};


require, "sel_file.i"
require, "ytime.i"
write,"$Id$"

plmk_default,msize=.1

if ( is_void( gps_time_correction ) )
  gps_time_correction = -13.0

func rbtans( junk, fn= ) {
 extern data_path;
 extern tans_filename;
 if ( !is_void( fn ) ) {
    ifn = fn;
    ff = split_path( ifn, -1 );
    data_path = ff(1);
 } else {
 path = data_path+"/tans/"
if ( _ytk ) {
    ifn  = get_openfn( initialdir=path, filetype="*.ybin" );
    if (strmatch(ifn, "ybin") == 0) {
          exit, "NO FILE CHOSEN, PLEASE TRY AGAIN\r";
    }
    ff = split_path( ifn, -1 );
    data_path = ff(1);
 } else {
 if ( is_void(data_path) )
   data_path = rdline(prompt="Enter data path:");
 ifn = sel_file(ss="*.ybin", path=data_path+"/tans/")(1);
 }
}


n = int(0)
idf = open( ifn, "rb");
 tans_filename = ifn;

// get the integer number of records
_read, idf,  0, n

tans = array( int, 4, n);
_read(idf, 4, tans);


// compute seconds of the day
//////////tans(1,) = tans(1,) % 86400;

// check and correct midnight rollover
  q = where( tans(1, ) < 0 );		// look for neg spike
/****
  if ( numberof(q) ) {			// if found, then correct
    rng = q(1)+1:dimsof(tans(1,) )(2);  // determine values to correct
    tans(1,) += 86400;			// add 86400 seconds
  }
******/


write,format="Using %f seconds to correct time-of-day\n", gps_time_correction
write,format="%s", 
              "               Min          Max\n"
 t = array( TANS, dimsof(tans)(3) );
 t.somd    = tans(1,)/1000.0 + gps_time_correction ;
 t.roll    = tans(2,)/1000.0;
 t.pitch   = tans(3,)/1000.0;
 t.heading = tans(4,)/1000.0;

write, format="  SOD:%14.3f %14.3f %6.2f hrs\n", t.somd(min), t.somd(max), 
	(t.somd(max)-t.somd(min))/ 3600.0
write, format=" Roll:%14.3f %14.3f\n", t.roll(min), t.roll(max)
write, format="Pitch:%14.3f %14.3f\n", t.pitch(min), t.pitch(max)
print, "Tans_Information_Loaded"
t.roll(min)
t.roll(max)
 if ( 
      ( t.roll(min) < -180.0)  || 
      ( t.roll(max) >  360.0)  ||
      (t.pitch(min) < -180.0)  ||
      (t.pitch(max) >  360.0)  
    ) {
   if ( _ytk ) {
    tkcmd, "tk_messageBox -icon error -message { \
      The Tans Vector data you loaded appears to be in the old format.\
      You need to regenerate the tans ybin file before you can continue.\
      }"
   } else {
     write,"************ WARNING *******************"
     write,"The Tans Vector data you loaded appears"
     write,"to be in the old format.  You need to "
     write,"regenerate the tans ybin file before you"
     write,"can continue."
     write,"****************************************"
   }
 }
 return t;
}


func prepare_sf_pkt (sod, psf) {
  /* this function prepares a packet for sf_a.tcl which contains the pitch, roll, heading information
     for every camera photo every 1 second */
  /* amar nayegandhi 03/05/2002. */

  extern tans
  //write, "Preparing tans packet for sf_a.tcl";

  //no_t = (dimsof(tans)(2)/10); 
  //if ((dimsof(tans)(2)%10) != 0) no_t++;

  idx = where(tans.somd == sod);

  t = tans(idx);
  // now write it out to a temp file for process id psf
  tmpfile = swrite(format="/tmp/tans_pkt.%d",psf);
  f = open(tmpfile, "w");
  write, f, format="%7d, %3.3f, %3.3f, %4.3f", (int)(t.somd), t.pitch, t.roll, t.heading;
  close, f

  
  //t = array(TANS, no_t);

  //t.somd = tans(1::10).somd;
  //t.roll = tans(1::10).roll;
  //t.pitch = tans(1::10).pitch;
  //t.heading = tans(1::10).heading;


  return

}

func make_sf_tans_file(tmpfile) {
  /* this function writes out a tmpfile containing tans information for sf */
  f = open(tmpfile, "w");
  write, f, format=" %7d, %3.3f, %3.3f, %4.3f\n", (int)(pkt_sf.somd), pkt_sf.pitch, pkt_sf.roll, pkt_sf.heading;
  close, f
  }



