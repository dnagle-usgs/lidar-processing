/*
   $Id$
*/

require, "dir.i"
require, "sel_file.i"
require, "ytime.i"
require, "map.i"
require, "string.i"
require, "pip.i"

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


write,"$Id$"

plmk_default,msize=.1

struct GGA {
  float sod;
  double lat;
  double lon;
  float alt;
};



extern gga
/* DOCUMENT gga

  gga is a structure containing:

   gga.sod      Seconds of the day.  
   gga.lat 	Latitude in degrees
   gga.lon	Longitude in degrees ( negative values for west )
   gga.alt 	Altitude in meters

   See also:  
     rbgga	Reads ybin files into Yorick.

*/


func rbgga( x, plt=, color=, map=, utm= ) {
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
      path = data_path+"/gps/";
   ifn = sel_file(ss="*.ybin", path=path)(1);
 } else {
    path = data_path+"/gps/";
    ifn  = get_openfn( initialdir=path, filetype="*gga.ybin" );
    ff = split_path( ifn, -1 );
    //data_path = ff(1);
    if (ff(2) == "") {
      write, "File not chosen.  Please reload gga file\n";
      exit;
    }
      
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

func gga_pip_sel(show, win=, color=, msize=, skip=, latutm=, llarr=) {
 /* DOCUMENT gga_pip_sel(show, win=, color=, msize=, skip=, latutm=, llarr=)
 This function uses the 'points in polygon' technique to select a region in the gga window.
 Also see: getPoly, plotPoly, testPoly, gga_win_sel
 */
 extern ZoneNumber, utm
 if ( is_void(win) ) 
	win = 6;
 window, win;
 if (!is_array(llarr)) {
     ply = getPoly();
     box = boundBox(ply);
     box_pts = ptsInBox(box, gga.lon, gga.lat);
     poly_pts = testPoly(ply, gga.lon(box_pts), gga.lat(box_pts));
     q = box_pts(poly_pts);
 }
 write,format="%d GGA records found\n", numberof(q);
 if ( (show != 0) && (show != 2)  ) {
   if ( is_void( msize ) ) msize = 0.1;
   if ( is_void( color ) ) color = "red";
   if ( is_void( skip  ) ) skip  = 10;
   plmk, gga.lat( q(1:0:skip)), gga.lon( q(1:0:skip)), msize=msize, color=color;
 }
 return q;
}



func gga_win_sel( show, win=, color=, msize=, skip= , latutm=, llarr=) {
/* DOCUMENT gga_win_sel( show, color=, msize=, skip= )

  There's a bug in yorick 1.5 which causes all the graphics screens to get fouled up
if you set show=1 when using this function.  The screen will reverse fg/bg and not respond
properly to the zoom buttons.
 
*/
 extern ZoneNumber, utm
 if ( is_void(win) ) 
	win = 6;

 window,win;
 if (!is_array(llarr)) {
   a = mouse(1,1,
  "Hold the left mouse button down, select a region:");
   a(1:4)
   minlon = min( [ a(1), a(3) ] )
   maxlon = max( [ a(1), a(3) ] )
   minlat = min( [ a(2), a(4) ] )
   maxlat = max( [ a(2), a(4) ] )
 } else {
   minlon = llarr(1);
   maxlon = llarr(2);
   minlat = llarr(3);
   maxlat = llarr(4);
 }
 if (latutm) {
   tkcmd, swrite(format="send_latlon_to_l1pro %7.3f %7.3f %7.3f %7.3f %d\n", minlon, maxlon, minlat, maxlat, utm);
 }
 if (show == 2) {
   /* plot a window over selected region */
   a_x=[minlon, maxlon, maxlon, minlon, minlon];
   a_y=[minlat, minlat, maxlat, maxlat, minlat];
   plg, a_y, a_x;
 }
 if (utm == 1) {
     minll = utm2ll(minlat, minlon, ZoneNumber(1));
     maxll = utm2ll(maxlat, maxlon, ZoneNumber(1));
     minlat = minll(2);
     maxlat = maxll(2);
     minlon = minll(1);
     maxlon = maxll(1);
     write, format="minlat = %7.3f, minlon= %7.3f\n", minlat, minlon;
 }

 q = where( gga.lon > minlon );
 if (is_array(q)) {
   qq = where( gga.lon(q) < maxlon );  q = q(qq);
 }
 if (is_array(q)) {
   qq = where( gga.lat(q) > minlat ); q = q(qq);
 }
 if (is_array(q)) {
   qq = where( gga.lat(q) < maxlat ); q = q(qq);
 }
 write,format="%d GGA records found\n", numberof(q);
 if ( (show != 0) && (show != 2)  ) {
   if ( is_void( msize ) ) msize = 0.1;
   if ( is_void( color ) ) color = "red";
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

func sel_region (q) {
   /* DOCUMENT sel_region(q)
      This function extracts the raster numbers for a region selected.  
      It returns a the array rn_arr containing start and stop raster numbers
      for each flightline.
      amar nayegandhi 9/18/02.
   */
  
   /* find the start and stop times using gga_find_times in rbgga.i */
   t = gga_find_times(q);

   if (is_void(t)) {
     write, "No flightline found in selected area. Please start again... \r";
     return
   }

   write, "\n";
   write,format="Total seconds of flightline data selected = %6.2f\n", 
         (t(dif, ))(,sum);


   /* now loop through the times and find corresponding start and 
      stop raster numbers 
   */
   no_t = numberof(t(1,));
   write, format="Number of flightlines selected = %d \n", no_t;
   rn_arr = array(int,2,no_t);
   tyes_arr = array(int,no_t);
   tyes_arr(1:0) = 1;
   write,""
   for (i=1;i<=numberof(t(1,));i++) {
      tyes = 1;
      write, format="Processing %d of %d\r", i, numberof(t(1,));
      if ((tans.somd(1) > t(2,i)) || (tans.somd(0) < t(1,i))) {
         write, format="Corresponding TANS data for flightline %d not found."+
                       "Omitting flightline ... \n",i;
	 tyes = 0;
	 tyes_arr(i)=0;
      } else if ((tans.somd(1) > t(1,i)) && (tans.somd(0) >= t(2,i))) {
         t(1,i) = tans.somd(1);
         write, format="Corresponding TANS data for beginning section"+
                       "of flightline %d not found.  Selecting part "+
                       "of flightline ... \n",i;
      } else if ((tans.somd(1) <= t(1,i)) && (tans.somd(0) < t(2,i))) {
         t(2,i) = tans.somd(0);
         write, format="Corresponding TANS data for end section of "+
                       "flightline %d not found.  Selecting part of "+
                       "flightline ... \n",i;
      }
      if (tyes) {
         rn_indx_start = where(((edb.seconds - soe_day_start) ) == int(t(1,i)));
         rn_indx_stop = where(((edb.seconds - soe_day_start) ) == ceil(t(2,i)));
         if (!is_array(rn_indx_start) || !is_array(rn_indx_stop)) {
            write, format="Corresponding Rasters for flightline %d not found."+
                          "  Omitting flightline ... \n",i;
	    rn_start = 0;
	    rn_stop = 0;
	    tyes_arr(i) = 0;
         } else {
            rn_start = rn_indx_start(1);
            rn_stop = rn_indx_stop(0);
         }

         rn_arr(,i) =  [rn_start, rn_stop];
      }
   }
   write,format="\nNumber of Rasters selected = %6d\n", (rn_arr(dif, )) (,sum); 



   /* use tyes_arr to decide first valid flightline */
   tindx = where(tyes_arr == 0);
   if (is_array(tindx))
   rn_arr(,tindx) = 0;
   return rn_arr;

} 

func gga_click_sel() {
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





func show_gga_track ( x=, y=, color=,  skip=, msize=, marker=, lines=, utm=   )  {
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
  if (utm == 1) {
  	/* convert latlon to utm */
	u = fll2utm(gga.lat, gga.lon);
	x = u(2,);
	y = u(1,);
  }

 if ( skip == 0 ) 
	skip = 1;

  if ( lines  ) {
     plg, y(1:0:skip), x(1:0:skip), color=color, marks=0;
     }

 if ( marker ) {
  plmk,y(1:0:skip), x(1:0:skip), 
    color=color, msize=msize, marker=marker;
    }
}

func plot_no_raster_fltlines (gga, edb) {
  /* Document no_raster_flightline (gga, edb)
      This function overplots the flight lines having no rasters with a different color.
*/

  /* amar nayegandhi 08/05/02 */

  extern soe_day_start;

  sod_edb = edb.seconds - soe_day_start;
  
  // find where the diff in sod_edb is greater than 1 second
  sod_dif = sod_edb(dif);
  indx = where((sod_dif > 5) & (sod_dif < 100000));
  if (is_array(indx)) {
    f_norast = sod_edb(indx);
    l_norast = sod_edb(indx+1);

    for (i = 1; i <= numberof(f_norast); i++) {
      indx1 = where((gga.sod >= f_norast(i)) & (gga.sod <= l_norast(i)));
      show_gga_track, x = gga.lon(indx1), y = gga.lat(indx1), skip = 0, color = "red", marker=1;
    } 
  }

}

  




if ( is_void(_ytk) ) 
	help, rbgga_help


