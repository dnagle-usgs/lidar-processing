/*
   $Id$
*/

require, "dir.i"
require, "sel_file.i"
require, "ytime.i"
require, "map.i"
require, "string.i"

local rbgga_help 
/* DOCUMENT rbgga_help

       ** FUNCTIONS AND DATA IN THIS FILE **
  
   You can find out more about the functions/externs below by
 typing:  help, function-name.  For example: help, rbgga   
   
 v=rbgga()        Reads,plots ybin data files.
 gga_win_sel      Lets you select a rectangular area with the mouse.
 gga_click_times  Mouse selected area data sod start/stop times.
 gga_find_times   Finds sod start/stop times using results from gga_win_sel.
 show_gga_track   Displays lat/lon data.  
 mk_photo_list    Generates a list of photo files for sf.tcl.

Externs: 
    gga           The global that rbgga reads data into.
    data_path     The global path to this dataset.

Other:
    rbgga_help    This help information.

*/


/* DOCUMENT rbgga.i
  $Id$

  This collection of functions and procedures manipulates and plots
  GPS NMEA GGA data. Before the data are can be read by these functions,
  it must be verified and converted by the gga2bin.c. program.  

  $Log$
  Revision 1.5  2002/01/19 04:02:07  wwright

   added plot command to sf_a.tcl so you can plot the displayed lat/lon
  position on the Yorick-6 window if ytk/eaarl.ytk is running.

  Revision 1.4  2002/01/17 02:29:20  wwright

  small changes to rbgga.i

  Revision 1.3  2002/01/16 14:13:45  wwright

   Added function to rbgga to permit selecting a flightline section from the
  gga map on win6, and then setting the sf photoviewer to the corresponding
  picture.

  Revision 1.2  2002/01/16 05:04:54  wwright

  changes to rbgga.i to fix several functions to work with the gga structure instead
  of the old gga array.

  Revision 1.1.1.1  2002/01/04 06:33:51  wwright
  Initial deposit in CVS.


  Revision 1.0  2001/08/11 06:23:20  wwright
  Initial revision

  Global variables:

   gga(1,)     seconds of the day.  
   gga(2,) 	lat
   gga(3,)	lon
   gga(4,)	alt

Functions:
  rbgga
  gga_win_sel( show, win=, color=, msize=, skip= )
  gga_click_times()
  show_gga_track ( x=, y=, color=,  skip=, msize=, marker=, lines=   )  
  mk_photo_list( q )
  gga_find_times( q, plt= ) 

*/


write,"rbgga.i as of 1/15/2002 loaded"

plmk_default,msize=.1

struct GGA {
  float sod;
  double lat;
  double lon;
  float alt;
};



extern gga
/* DOCUMENT gga

  gga is a 4xN array of floats holding the following:

   gga(1,)      Seconds of the day.  
   gga(2,) 	Latitude in degrees
   gga(3,)	Longitude in degrees ( negative values for west )
   gga(4,)	Altitude in meters

   See also:  
     rbgga	Reads ybin files into Yorick.

*/


func rbgga( x, plt=, color=, map= ) {
/* DOCUMENT v = rbgga( plt=(0/1), map=(0/1) ) 

   The rbgga function reads converted NMEA GPGGA gps message data.  
 The data are produced by the gga2bin.c program.  The data from the file 
 is read into the global variable gga.  Many functions in this 
 package work with the default gga variable.  This function returns an
 array of GGA structures.

 To look at some data, try the following at the Yorick prompt:

  rbgga, plt=1
  load_map

 See also: 
  Variables: gga data_path
  Functions: gga_win_sel show_gga_track mk_photo_list gga_click_times
	     gga_find_times rbgga
      Other: map.i:  load_map ll2utm convert_map

*/

 extern gga, data_path;
 if ( is_void( _ytk ) ) {
   if ( is_void( data_path) )
      data_path = set_data_path();
   ifn = sel_file(ss="*.ybin", path=data_path+"/gps/")(1);
 } else {
    ifn  = get_openfn( initialdir="/data/0/", filetype="*gga.ybin" );
    ff = split_path( ifn, -1 );
    data_path = ff(1);
 }

n = int(0)
idf = open( ifn, "rb");

// get the integer number of records
_read, idf,  0, n

gga = array( float, 4, n);
_read(idf, 4, gga);

mxlat = gga(2,max)
mnlat = gga(2,min)
mxlon = gga(3,max);
mnlon = gga(3,min);

// Now see if we flew thru midnight gmt by looking for a negative
// time delta.
 mtd = min( gga(1, ) (dif) );		// find min time diff
 if ( mtd < 0.0 ) {
  q = where( gga(1, ) < gga(1,1) );	// adjust all times past midnight
  gga(1,q) += 86400;
  write, "**** Note: This mission went through GPS midnight\n"
 }
 mission_duration_secs = gga(1,0) - gga(1,1);
write,format="%s", 
              "               Min          Max\n"
write, format="SOD:%14.3f %14.3f %6.2f hrs\n", gga(1,1), gga(1,0), 
   mission_duration_secs / 3600.0;
write,format="%s", "HMS:     "
write,format="%d:", sod2hms(gga(1,1))
write,format="%s", "      "
write, format="%d:", sod2hms(gga(1,0))
write, format="\nLat:%14.3f %14.3f\n", gga(2,min), gga(2,max)
write, format="Lon:%14.3f %14.3f\n", gga(3,min), gga(3,max)

   if ( is_void( plt ) ) {
     write, format="%s\n", "gga now loaded.\n\
     Enter: show_gga_track to see it \n\
     or type: help, rbgga for more info."
   } else if ( plt !=0 ) {
      if ( is_void(color) ) 
	color = "red";
      show_gga_track, color=color
   }

   if ( is_void( map ) == 0 ) {
     if ( map == 1 ) 
	load_map;
   } 
   g = array( GGA, n );
   g.sod = gga(1,);
   g.lat = gga(2,);
   g.lon = gga(3,);
   g.alt = gga(4,);
   return g;
}

func gga_win_sel( show, win=, color=, msize=, skip= ) {
/* DOCUMENT gga_win_sel( show, color=, msize=, skip= )

  There's a bug in yorick 1.5 which causes all the graphics screens to get fouled up
if you set show=1 when using this function.  The screen will reverse fg/bg and not respond
properly to the zoom buttons.
 
*/
 if ( is_void(win) ) 
	win = 6;

 window,win;
 a = mouse(1,1,
  "Hold the left mouse button down, select a region:");
 a(1:4)
 minlon = min( [ a(1), a(3) ] )
 maxlon = max( [ a(1), a(3) ] )
 minlat = min( [ a(2), a(4) ] )
 maxlat = max( [ a(2), a(4) ] )
 q = where( gga.lon > minlon );
 qq = where( gga.lon(q) < maxlon );  q = q(qq);
 qq = where( gga.lat(q) > minlat ); q = q(qq);
 qq = where( gga.lat(q) < maxlat ); q = q(qq);
 write,format="%d GGA records found\n", numberof(q);
 if ( show != 0  ) {
   if ( is_void( msize ) ) msize = 0.1;
   if ( is_void( color ) ) color = "blue";
   if ( is_void( skip  ) ) skip  = 10;
   plmk, gga.lat( q(1:0:skip)), gga.lon( q(1:0:skip)), msize=msize, color=color;
 }
 return q;
}

func gga_click_start_isod(x) {
/* DOCUMENT gga_click_start_isod

   Select a region from the gga map. This procedure will then show the picture at the start
of the selected region.  You can then use the "Examine Rasters" button on sf to see the raster
and continue looking at data down the flight line. 

*/
   st = gga_find_times(  gga_win_sel(0)  );
   if ( numberof( st ) ) {
     st = int( st(min) ) 
     send_sod_to_sf, st;		// command sf and drast there.
   }
  write,"region_selected"
  return st;
}

func gga_click_times( x )  {
/* DOCUMENT gga_click_times(x)
   
   Finds and returns the start/stop sod pairs for the selected 
   gga data.


   See also: gga, rbgga, gga_find_times, gga_win_sel
*/
  t =  gga_find_times(  gga_win_sel(0)  ); 
  write,format="%6.2f total seconds selected\n", (t(dif, )) (,sum)
  return t;
}

func gga_find_times( q, win=, plt= ) {
/* DOCUMENT gga_find_times(q)

   This function finds the start and stop times from a list generated
   by the gga_win_sel() function. It returns an array of 2xN floats
   where  (1, ) is the starting sod of the segment and (2, ) is the
   ending sod.  Sos is Seconds-of-day.

  See also: gga_win_sel, rbgga, plmk
            ytime.i: sod2hms
*/

// begin with "q" list of selected points
// add a 0 element to the start and end so they will produce
//   a dif.
   lq = grow( [1], q ); lq = grow( lq, [1]  );

// Now we take the first dif of the sods in the gga records and
// then get a list of all the places where the dif is larger than
// one second.  This list "endptlist" will be an index into the list
// "lq" where had a change larger than one second.  Adding one to
// "endptlist" gets us the starting point of the next segment.
   endptlist = where( abs((gga.sod(lq) (dif)) ) > 1 )
   if ( numberof( endptlist ) == 0 ) 
	return ;
   startptlist = endptlist+1;
 
  // start of each line is at qq+1
  // end of each line is at qq
  startggasod = gga.sod( lq(startptlist));
   stopggasod = gga.sod( lq(endptlist) );

// The startggasod and stopggasod have bogus values at the beginning
// and end so we want to fix that and also copy the proper start/stop
// times to a 2-by-n array to be returned to the caller.
  ssa = array( float, 2, numberof( startggasod) -1 );
  ssa(1, ) = startggasod(1:-1);
  ssa(2, ) = stopggasod(2:0);

// to see a plot of the selected times with green/red markers 
// at the beginning and end of each list, enab enable the following:
  if ( is_void( plt ) )
	plt = 0;
  if ( plt == 1 ) {
    if ( is_void(win) ) 
      win=6
    window,win;
    fma; 
    plmk, gga.sod( q),q;		// plot the selected times
    plmk, startggasod(1:-1), lq(startptlist(1:-1)), color="green", msize=.3
    plmk, stopggasod(2:0)-1, lq(startptlist(2:0)-1), color="red", msize=.3
    limits;
  }
  return ssa;
}


func mk_photo_list( q, ofn= ) {
/* DOCUMENT mk_photo_list(q)
   
   Returns a list of photo file names for the selected region.
*/
   ssl = gga_find_times( q );		// get the start/stop times
   t = [];
   for ( i = 1; i < dimsof(ssl)(3); i++ ) 
	grow, t, indgen( int(ssl(1,i)):int(ssl(2,i)));
  
   hms = sod2hms( t );
   pfn = array( string, numberof(hms) );
   if ( is_void( ofn ) == 0 ) {
      s = array(string, 100 );
      scmd = swrite(format="/bin/ls -1 %s | head", data_path + "/cam1/"  ) ;
      f = popen(scmd, 0)
      n = read(f,format="%s", s );
      close,f;
      date = strpart( s(1), 11:14);
      year = strpart( s(1), 6:9);
year
date

      f = open( ofn, "w" );
      n = write( f, format="cam1/cam1_%s_%s_%02d%02d%02d_01.jpg\n", 
        year, date,
        hms(1,),hms(2,),hms(3,) ); 
      write,format="%d photos written to %s\n", dimsof(hms)(3), ofn;
      close,f;
   }
      pfn = swrite( format="cam1/cam1_2001_0714_%02d%02d%02d_01.jpg", 
        hms(1,),hms(2,),hms(3,) );
   return pfn;
}





func show_gga_track ( x=, y=, color=,  skip=, msize=, marker=, lines=   )  {
/* DOCUMENT show_gga_track, x=,y=, color=, skip=, msize=, marker=, lines=

   Plot the GPS gga position lat/lon data in the current window.
   The color, msize, and marker options are same as plmk.  The data 
   are presumed to be in the gga array in the following format.

   gga(1,)      seconds of the day (sod).
   gga(2,)      lat (deg)
   gga(3,)      lon (deg)
   gga(4,)      alt (m)

  Examples:
   show_gga_track
   Plots the track with default values which are red lines and 
   red square markers.  By default it skips 20 points.  For quicker
   plots, turn off the markers with marker=0;

   show_gga_track,color="magenta",msize=0.2,skip=10,marker=1
    
   show_gga_track,color="magenta",msize=0.1,skip=50,marker=0
   show_gga_track,color="red",msize=0.3,skip=10,marker=1
   show_gga_track,color="red",msize=0.3,skip=10,marker=1

   show_gga_track,color="red",msize=0.3,skip=10,marker=1,lines=0
   Plots markers only, no lines. 

   You can also give show_gga_track the x and y values to plot with
   the x= and y= parameters.  This is useful when you want to overplot 
   several missions and retain one in the global gga array.
   

   See also: plmk, plg, color

*/
  if ( is_void( msize ) ) 
	msize= 0.1;
  if ( is_void( marker ) ) 
	marker= 1;
  if ( is_void( skip ) ) 
	skip = 50;
  if ( is_void( color ) )
	color = "red";
  if ( is_void( lines ) ) 
     lines = 1;
  if ( is_void( x ) ) {
        x = gga.lon;
        y = gga.lat;
  }

 if ( skip == 0 ) 
	skip = 1;

  if ( lines  ) 
     plg, y(1:0:skip), x(1:0:skip), color=color, marks=0;

 if ( marker ) 
  plmk,y(1:0:skip), x(1:0:skip), 
    color=color, msize=msize, marker=marker;
}


if ( is_void(_ytk) ) 
	help, rbgga_help


