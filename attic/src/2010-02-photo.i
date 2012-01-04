/******************************************************************************\
* The functions in this file were moved to the attic on 2010-02-26. These      *
* functions have not been in use for several years. Further, their             *
* functionality is deprecated in favor of other functions and approaches. More *
* specific information on this is provided in comments ahead of each function. *
\******************************************************************************/

/*
  Functions to work with the EAARL Axis digital camera.  

  Orginal W. Wright, 5-6-03 while in San Juan, Pr.
*/

cam1_roll_bias = 9.0;
cam1_yaw_bias  = -3.5 - 180.0;
cam1_pitch_bias  = 0.0;
fov = 43.0 * pi/180.0;	// camera FOV

/*
   Function jpg_read is redundant to (and less efficient than) the similarly
   named function jpeg_read from Yorick-z. Moreover, the pnm-based
   functionality this function provides can also be found in the function
   img_read from yutils, if Yorick-z is not available.
*/
func jpg_read(filename) {
/* DOCUMENT image= jpg_read(filename)

   Reads the JPG image specified by filename and returns an array of RGB values
   that represent the image. The array will have dims [3, 3, width, height].

   Internally, this uses the command line program convert to translate the file
   into a pnm, which it then reads.

   Use pli to display the image.

   SEE ALSO: pnm_display, pnm_write, pnm_read
*/
   // Rewritten 2008-12-29 David Nagle
   temp_dir = mktempdir();
   pnm_file = file_join(temp_dir, "image.pnm");

   system, swrite(format="convert %s %s", filename, pnm_file); 
   pnm_data = pnm_read(pnm_file);

   remove, pnm_file;
   rmdir, temp_dir;

   return pnm_data;
}

/*
   This was only designed to work with our older RGB camera and has not been
   updated for the new one. The core functionality is deprecated in favor of
   mosaic_tools' functionality.
*/
func cam_photo_orient(photo, heading=, pitch=, roll=, alt=, center=, offset=,
scale=, win=) {
/* DOCUMENT cam_photo_orient(photo, heading=, pitch=, roll=, alt=, center=, offset=,
scale=, win=)
   Orient and display cam RGB photos. See photo_orient for information on
   parameters.

   This extends photo_orient by doing the following:
      * The last 16 rows of image data are discarded (to remove the black line).
      * The altitude has 40 meters added.
      * The default cam1 biases are applied.
*/
   extern cam1_roll_bias, cam1_yaw_bias, cam1_pitch_bias;
   alt += 40.0;
   photo = photo(,,:-16);
   biases = [cam1_roll_bias, cam1_yaw_bias, cam1_pitch_bias];
   return photo_orient(photo, heading=heading, pitch=pitch, roll=roll, alt=alt,
      center=center, offset=offset, scale=scale, win=win,
      mounting_biases=biases);
}

/*
   This was replaced by similar but more flexible functionality in
   jpeg_support.i.
*/
func photo_orient_jgw(photo, jgw, win=) {
/* DOCUMENT photo_orient_jgw, photo, jgw, win=
   [x, y] = photo_orient_jgw(photo, jgw, win=)

   Orients and optionally plots an image with a jgw.

   Parameters:
      photo - A three-dimensional array of type char, as returned by
         jpeg_read.
      jgw - A six-element array that defines the JGW affine matrix for the
         image. See affine_transform for an explanation of what formats the
         matrix may be in.

   Options:
      win= The window number to plot the image in. If omitted or set to -1, no
         plotting will occur.

   Returns:
      An array [x, y]. Each of x and y are two-dimensional arrays that match
      photo's dimensions. These define the mesh that photo should be plotted
      to, as such:

         plf, photo, y, x, edges=0;
*/
// Original David B. Nagle 2009-03-25
   default, win, -1;

   // Image dimensions
   xd = dimsof(photo)(3);
   yd = dimsof(photo)(4);

   // Generate the indices for each axes, then recast them so that each pixel
   // of photo is bounded
   x = indgen(0:xd);
   y = indgen(0:yd);
   xy = [unref(x)(,-), unref(y)(-,)];
   x = xy(..,1);
   y = xy(..,2);

   // affine_transform only works on one dimensional arrays, so we have to
   // reform to 1d and then back to 2d
   x = reform(unref(x), [1, (xd+1)*(yd+1)]);
   y = reform(unref(y), [1, (xd+1)*(yd+1)]);
   affine_transform, x, y, jgw;
   x = reform(unref(x), [2, xd+1, yd+1]);
   y = reform(unref(y), [2, xd+1, yd+1]);

   if(win >= 0) {
      old_win = current_window();
      window, win;
      plf, photo, y, x, edges=0;
      window_select, old_win;
   }

   if(!am_subroutine())
      return [x, y];
}

/*
   This was only designed to work with our older RGB camera and has not been
   updated for the new one. The core functionality is deprecated in favor of
   mosaic_tools' functionality.
*/
func photo_orient(photo, heading=, pitch=, roll=, alt=, center=, offset=,
scale=, win=, mounting_biases=) {
/* DOCUMENT coordinates = photo_orient(photo, heading=, pitch=, roll=, alt=,
   center=, offset=, scale=, win=, mounting_biases=)

   Orient and display EAARL photos.

   photo:   The photo array. An array of rgb values with dims [3, 3, width,
            height].
   heading= Aircraft heading in degrees.
   pitch=   Aircraft pitch in degrees.
   roll=    Aircraft roll in degrees.
   alt=     Aircraft above-ground-level altitude in meters.
   center=  Manually specify the center of the image (as [y,x]).
   offset=  Offset [y,x] to apply to image when plotting.
   scale=   Manually specify scaling info if alt is unavailable.
   win=     The window to display the photo in. If not provided, no image will
            be plotted.
   mounting_biases=  An array [roll, pitch, yaw] of values in degrees to apply
            to the roll, pitch, and heading of the aircraft to adjust for
            mounting biases of the camera.
*/
// Rewritten David B. Nagle 2008-12-29

   extern fov;

   default, heading, 0.0;
   default, pitch, 0.0;
   default, roll, 0.0;
   default, alt, 0.0;
   default, offset, [0.0, 0.0];
   default, scale, [1.0, 1.0];
   default, win, 7;
   default, mounting_biases, [0.0, 0.0, 0.0];

   assign, mounting_biases, roll_bias, pitch_bias, yaw_bias;

   roll += roll_bias;
   pitch += pitch_bias;
   heading += yaw_bias;

   // Convert aeronautical heading (clockwise, degrees) to mathematical heading
   // (counter-clockwise, radians)
   heading *= -pi / 180.0;

   // Convert roll and pitch from degrees to radians
   roll *= pi/180.0;
   pitch *= pi/180.0;

   // dx and dy are the width/height of image
   dx = dimsof(photo)(3);
   dy = dimsof(photo)(4);

   if (alt) { 
      xtk = 2.0 * tan(fov/2.0) * alt;
      scale(1) = scale(2) = xtk / dx;
   }

   if(is_void(center))
      center = int([dy, dx]/2.0);

   x = span(-center(2), dx-center(2), dx+1)(,-:1:dy+1); 
   y = span(-center(1), dy-center(1), dy+1)(-:1:dx+1,); 

   roll_offset = tan(roll) * alt;
   pitch_offset = tan(pitch) * alt;

   x += roll_offset;
   y += pitch_offset;

   s = sin(heading);
   c = cos(heading);
   rotated_x = (x * c - y * s) * scale(2);
   rotated_y = (x * s + y * c) * scale(1);

   if(! is_void(win)) {
      window, win;
      plf, photo, rotated_y+offset(1), rotated_x+offset(2), edges=0;
   }

   return [rotated_x, rotated_y];
}

/*
   As noted below, this has been unused for a very long time.
*/
// TODO: DEPRECATED
func pref (junk) {
/* DOCUMENT pref 
   
   2008-12-29: This function appears unused.  It will be removed at a future
   time if nobody removes this note and explains its utility. -DBN
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
      plmk, m(2), m(1),msize=.3,marker=2;
      print, m(1:2);
   }
   return lst;
}

/*
   This was only designed to work with our older RGB camera and has not been
   updated for the new one. The core functionality is deprecated in favor of
   mosaic_tools' functionality.
*/
func gref_photo( somd=, ioff=, offset=,ggalst=, skip=, drift=, date=, win= ) {
/* DOCUMENT gref_photo, somd=, ioff=, offset=, ggalst=, skip=

    smod=  A time in SOMD, or a list of times.
    ioff= Integer offset 
  offset=
  ggalst=
    skip= Images to skip
   drift= Clock drift to add


*/

 if ( is_void(ioff) ) ioff = 0;
 if ( is_void(drift) ) drift = 0.0;
 if ( is_void(offset)) offset = 0;
 if (is_array(ggalst)) somd = int(gga.sod(ggalst(unique(int(gga.sod(ggalst))))))
 if (skip)  somd = somd(1:0:skip);
 write, somd
 // find the camera file names in the cam1/ subdir
 cmd = swrite(format="ls -1 %s",data_path+"cam1/");
 f = popen(cmd, 0);
 s  = "";
 n = read(f, format="%s",s);
 close, f;
 t = *pointer(s);
 ch = where(t=='_' | t == '-' | t == '.');
 ch = grow(0,ch,numberof(t)+1);
 so = 0;
 for (i=1;i<=numberof(ch)-2;i++) {
   aa = (t(ch(i)+1:ch(i+1)-1));
   a = sread(string(&aa), format="%6d",so);
   if (a==1 && numberof(aa)==6) break;
 }
 fn1 = string(&t(1:ch(i)));
 fn2 = string(&t(ch(i+1):));
 
 for ( i = 1; i <=numberof(somd); i++ ) {
  sd = somd(i) + ioff;
  csomd = sd + offset + i * drift;
  heading = interp( tans.heading, tans.somd, csomd);
  roll    = interp( tans.roll   , tans.somd, csomd);
  pitch   = interp( tans.pitch  , tans.somd, csomd);
  lat     = interp( pnav.lat, pnav.sod, csomd);
  lon     = interp( pnav.lon, pnav.sod, csomd);
  galt    = interp( pnav.alt, pnav.sod, csomd);
  ll2utm, lat, lon;
  northing = UTMNorthing;
  easting  = UTMEasting;
  zone     = UTMZone;
  hms = sod2hms(sd, str=1);
  pname = swrite(format="%s%s%s%s", 
         data_path + "cam1/", 
         fn1,
         hms,
	 fn2 ); 
  print, heading, northing, easting, roll, pitch, galt, hms
  photo = jpg_read( pname );
  photo_orient, photo, 
	        alt= galt,
	    heading= heading,
	       roll= roll + ops_conf.roll_bias + cam1_roll_bias,
	     pitch = pitch + ops_conf.pitch_bias + cam1_pitch_bias,
	     offset = [ northing, easting ], win=win;
 }
}
