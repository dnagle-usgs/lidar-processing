/*

   $Id$
 
  Functions to work with the EAARL Axis digital camera.  

  Orginal W. Wright, 5-6-03 while in San Juan, Pr.

*/

require, "pnm.i"

write,"$Id$"


func jpg_read(filename)
/* DOCUMENT image= jpg_read(filename)

     read a jpg image from FILENAME.  Converts to pnm using the commandline
program convert to convert the image to a pnm file in the /tmp/directory.  
Use pli to display the image.

   SEE ALSO: pnm_display, pnm_write
 */
{
   cmd = swrite(format="convert %s /tmp/etmp.pnm", filename); 
   f = popen( cmd, 0);
   close,f;
   return pnm_read( "/tmp/etmp.pnm");
}


  cam1_roll_bias = 0.0;
  cam1_yaw_bias  = 0;
  cam1_pitch_bias  = 0.0;
  fov = 50.0 * pi/180.0;	// camera FOV


func cir_photo_orient( photo, 
        heading=, 
	pitch=, 
	roll=, 
	alt=, 
	center=, 
	offset=, 
	scale=, 
	win= 
) {
/* DOCUMENT photo_orient( p, 
	heading=, pitch=, roll= , center=, offset=, scale= 
  )

   Orient and display EAARL cam1 photos.  Where:
   p		The photo array.
   heading=	Aircraft heading in degrees.
   pitch=       Aircraft pitch (deg).
   roll=        Aircraft roll (deg).
   alt=         Aircraft AGL altitude in meters.
   center=
   offset=
   scale=
   win=         The window to display photo mosaic in.

   

*/

  if ( is_void( scale  ) ) scale  = [1.0, 1.0];
  if ( is_void( offset ) ) offset = [0.0, 0.0];
  if ( is_void(heading)  ) heading = 0.0;
  if ( is_void(win    )  ) win = 7;
  if ( is_void(roll   )  ) roll = 0.0;
  p = photo;
////  p(, , -15:0) = 0;		// zeros the time in the image
  //p = photo(,, 1:-16);		// removes the time image
  //heading = (-heading + cam1_yaw_bias  - 180.0) * pi / 180.0;
  heading = (-heading +cam1_yaw_bias)*pi/180.;
  s = sin(heading);
  c = cos(heading);
  dx = dimsof(p) (3)
  dy = dimsof(p) (4)
  alt += 30.0;		// make it sealevel more or less
  if ( alt ) { 
     xtk = 2.0 * tan( fov/2.0) * alt;
     scale(1) = scale(2) = xtk / dx;
   }
///////////////////print, "xtk", xtk, scale
  if ( is_void(center) ) {
    center = array( int, 2);
    center(2) = dx / 2.0;
    center(1) = dy / 2.0;  
  }
  roll_offset = tan( roll * pi/180.0) * alt;
 pitch_offset = tan( pitch * pi/180.0) * alt;
   x = span(-center(2), dx-center(2), dx+1 ) (,-:1:dy+1); 
   x += roll_offset;
   y = span(-center(1), dy-center(1), dy+1 ) (-:1:dx+1, ); 
   y += pitch_offset;
   xx =   (x * c - y * s) * scale(2);
   yy =   (x * s + y * c) * scale(1);
  window,win; plf, p, yy+offset(1), xx+offset(2), edges=0;
  return [xx, yy ];

}



func pref (junk) {
/* DOCUMENT pref 

*/
  lst = [];
  m  = array( long, 11 );
   while ( m(10) != 3 ) {
     window,5;
     m = mouse();
     if ( numberof(m) < 2 ) {
       lst = m(1:2);  
     } else {
       grow, lst, m(1:2);
     } 
     window,7;
     plmk, m(2), m(1),msize=.3,marker=2
     print, m(1:2);
  }
 return lst;
}


func cir_gref_photo( somd=, ioff=, offset=,ggalst=, skip=, drift=, date=, win= ) {
/* DOCUMENT gref_photo, somd=, ioff=, offset=, ggalst=, skip=

    smod=  A time in SOMD, or a list of times.
    ioff= Integer offset 
  offset=
  ggalst=
    skip= Images to skip
   drift= Clock drift to add


*/

 extern aa, aa2;
 if ( is_void(ioff) ) ioff = 0;
 if ( is_void(drift) ) drift = 0.0;
 if ( is_void(offset)) offset = 1.2;
 if (is_array(ggalst)) somd = int(gga.sod(ggalst(unique(int(gga.sod(ggalst))))))
 if (skip)  somd = somd(1:0:skip);
 write, somd
 for ( i = 1; i <=numberof(somd); i++ ) {
  sd = somd(i) + ioff;
  csomd = sd + offset + i * drift;
  heading = interp( tans.heading, tans.somd, csomd);
  roll    = interp( tans.roll   , tans.somd, csomd);
  roll = 0;
  pitch   = interp( tans.pitch  , tans.somd, csomd);
  pitch = 0;
  lat     = interp( pnav.lat, pnav.sod, csomd);
  lon     = interp( pnav.lon, pnav.sod, csomd);
  galt    = interp( pnav.alt, pnav.sod, csomd);
  ll2utm, lat, lon;
  northing = UTMNorthing;
  easting  = UTMEasting;
  zone     = UTMZone;
  hms = sod2hms( int(sd ) );   
  tkcmd, swrite(format="send cir.tcl tmp_image sod %d",int(sd));
  pause, 500;
  if (i==1) write, "heading, northing, easting, roll, pitch, galt, hms"
  print, heading, northing, easting, roll, pitch, galt, hms
  pname = "/tmp/tmp.jpg";
  photo = jpg_read( pname );
  cir_photo_orient, photo, 
	        alt= galt,
	    heading= heading,
	       roll= roll + ops_conf.roll_bias + cam1_roll_bias,
	     pitch = pitch + ops_conf.pitch_bias + cam1_pitch_bias,
	     offset = [ northing, easting ], win=win;
 }
}



