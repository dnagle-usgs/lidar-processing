require, "eaarl.i";
require, "photo.i";
require, "random.i";
require, "evolve.i";
write,"$Id$";

/*
   Functions to work with the EAARL Axis digital camera.  

   Orginal W. Wright, 5-6-03 while in San Juan, Pr.
*/

cam1_roll_bias = 0.0;
cam1_pitch_bias  = 0.0;
fov = 50.0 * pi/180.0;   // camera FOV


func cir_photo_orient(photo, heading=, pitch=, roll=, alt=, center=, offset=,
scale=, win=) {
/* DOCUMENT cir_photo_orient, photo, heading=, pitch=, roll=, alt=, center=,
   offset=, scale=, win=
   
   Orient and display EAARL cir photos.

   photo:   The photo array. An array of rgb values with dims [3, 3, width,
            height].
   heading= Aircraft heading in degrees.
   pitch=   Aircraft pitch (deg).
   roll=    Aircraft roll (deg).
   alt=     Aircraft AGL altitude in meters.
   center=  Manually specify the center of the image. [y,x]
   offset=  Offset [y,x] to apply to image when plotting.
   scale=   Manually provide scaling info if the alt is unavailable.
   win=     The window to display photo mosaic in. If this is not provided, the
            image will not be displayed.

   If biases/adjustments are to be applied to the heading, pitch, roll, and/or
   alt, they should be done to the values before they are passed to this
   function.
*/
   return photo_orient(photo, heading=heading, pitch=pitch, roll=roll, center=center, offset=offset, scale=scale, win=win, mounting_biases=[0.0, 0.0, 0.0]);
}

func cir_gref_photo( somd=, ioff=, offset=,pnavlst=, skip=, drift=, date=, win= ) {
/* DOCUMENT gref_photo, somd=, ioff=, offset=, pnavlst=, skip=

    smod=  A time in SOMD, or a list of times.
    ioff= Integer offset
  offset=
  pnavlst= An index into pnav specifying which images are of interest.
    skip= Images to skip
   drift= Clock drift to add
*/
   extern pnav;

   default, somd, [];
   default, ioff, 0;
   default, offset, 1.2;
   default, pnavlst, [];
   default, skip, 0;
   default, drift, 0.0;
   default, date, [];
   default, win, [];

   if(is_array(pnavlst))
      somd = set_remove_duplicates(int(pnav.sod(pnavlst)));

   if(skip)
      somd = somd(::skip);

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
      if (i==1) write, "heading, northing, easting, roll, pitch, galt, hms";
      print, heading, northing, easting, roll, pitch, galt, hms;
      pname = "/tmp/tmp.jpg";
      photo = jpg_read(pname);
      cir_photo_orient, photo,
         alt= galt,
         heading= heading,
         roll= roll + ops_conf.roll_bias + cam1_roll_bias,
         pitch = pitch + ops_conf.pitch_bias + cam1_pitch_bias,
         offset = [ northing, easting ], win=win;
   }
}

// Possible error messages from cir code.
cir_error = array(string,100);
cir_error( 1) = "Operation completed normally.";
cir_error(-1) = "The cir_mask array is void.";
cir_error(-2) = "No CIR photo exists at the requested SOD value.";
cir_error(-3) = "The jgwinfo(1) path isn't set. See set_jgwinfo.";
cir_error(-4) = "The jgwinfo(2) date isn't set. See set_jgwinfo.";
cir_error(-5) = "The structure iex_nav1hz is void. Load a DMARS dataset to correct this problem.";
cir_error(-6) = "No attitude data found for that time.";
cir_error(-8) = "The iex_nav data variable is void.";
cir_error(-9) = "";
cir_error(-10)= "";
cir_error(-12)= "";
cir_error(-13)= "";
cir_error(-14)= "";
cir_error(-15)= "";

func load_cir_mask( fn ) {
/* DOCUMENT load_cir_mask( fn )

 Original: W. Wright 5/4/2006

031006-214859-332-cir.jpg

*/
 extern cir_mask
 cir_mask = array(short, 86400);
 tmp = array(long,86400*2);
 ds = ""; ts=""; ms = int(0); hh = int(0); mm=int(0); ss=int(0);
 f = open( fn, "r");
 for (i=1; i<86400; i++ ) {
  n = read(f,format="%06s-%02d%02d%02d-%d", ds,hh,mm,ss,ms );
  if ( n == 0 ) break;
    sod = hh*3600+mm*60+ss;
    cir_mask(sod) = sod;
 }
 write,format="Read %d CIR file names from: %s\n", i-1, fn
 close,f
 return 1;
}

func gen_jgw_files( somd_list ) {
/* DOCUMENT gen_jgw_files( somd_list )

 Generates jgw files for each element of the somd_list.

ls | grep jgw > junk
tar --remove-files -cvzf jgwfiles.tgz -T junk


Original W. Wright 5/6/06
*/
 extern jgwinfo, camera_specs
  n = numberof( somd_list );
n
  if ( is_void( jgwinfo ) ) {
   write,"Operation aborted.  The jgwinfo array must be set first.  try: help, jgwinfo"
  }
 write,""
 gen_cir_nav(camera_specs.trigger_delay);
  for (i=1; i<= n; i++ ) {
     e = gen_jgw_file( somd_list(i));     // Generate each jgw file.
     if ( e != 1 ) {
       write,format="Error %d for sod:%d\n", e, i;
     }
     if ( (i % 100) == 0  ) write, format=" Generated: %d of %d (%3.0f%%) jgw files\r", i, n, (i*100.0/n);
  }
   i--;
   write, format=" Generated: %d of %d (%3.0f%%) jgw files\r", i, n, (i*100.0/n);
   write,"\nOperation completed.\n"
  return 1;
}

// Set the jgwinfo array to two "" strings.
if ( is_void( jgwinfo) ) {
  jgwinfo = array(string,2);
  jgwinfo(1) = jgwinfo(2) = "";
}

func set_jgw_info( dir, m, d, y ) {
/* DOCUMENT set_jgw_info( dir, m, d, y)


  Use this function to either set or query the current output
  path and date.  The jgwinfo is an array of two strings, where
  jgwinfo(1) is the directory to store the jgw files and
  jgwinfo(2) is the date string specfic to the CIR camera in the
  format mmddyy. Note that the mm sarts at zero, so january is
  0 and december is 11.

 set-jgw_info() with no parameters will return the current value
 of the jgwinfo array.

  Example:  set_jgw_info, "/tmp", 4,11,06

  The above sets the output diretroy to "/tmp" and the date to
  to 4/11/2006.  **** Important note **** The month in the jpg and
  jgw file will appear to be early by one month. For example, if
  you set the month to April or 4, it will appear in the file  name
  as March or 3.  I know it's odd, but we now have millions of photos
  named that way, and code to read them.

  Example jpg file name: 021406-193951-326-cir.jpg

Original W. Wright 5/6/06
*/
 extern jgwinfo
 if ( is_void(dir) ) return jgwinfo;
 if ( y > 2000) y -= 2000;
 jgwinfo(1) = dir;
 jgwinfo(2)=swrite(format="%02d%02d%02d", m-1,d,y);
}

func batch_gen_jgw_file(photo_dir, date, progress=, mask=) {
/* DOCUMENT batch_gen_jgw_file, photo_dir, date, progress=, mask=

   Generates jgw files for each CIR image in photo_dir's subdirectories. Since
   find is used, any directory structure will work. The date argument should be
   "mmddyy" where mm is the month minus 1. (So January is 00, and December is
   11.)

   The jgw file will be in the same directory as its associated jpg.

   This function uses file_dirname, which requires yeti_regex.i. See dir.i for
   more info.

   Set progress=0 to disable progress information.

   If mask= is provided, it should be an array as array(short, 86400) that
   indicates, for each SOD value, whether or not the image at that time should
   have a JGW generated. 1 means generate, 0 means don't. The default is
   mask=array(1, 86400), which means that all files get jgws.

   Note: This will set the extern cir_mask to array(1, 86400) if it's void to
   avoid error messages from gen_jgw_file.
*/
   extern jgwinfo, cir_error, cir_mask, iex_nav1hz;
   fix_dir, photo_dir;
   default, progress, 1;
   default, cir_mask, array(short(1), 86400);

   // The default mask matches the time boundaries of iex_nav1hz
   temp = array(short(0), 86400);
   temp(int(ceil(iex_nav1hz.somd(min)))-1:int(iex_nav1hz.somd(max))-1) = 1;
   default, mask, temp;
   temp = [];

   jpgs = find(photo_dir, glob="*-cir.jpg");
   if(progress) {
      tstamp = 0;
      timer_init, tstamp;
      write, format="Generating JGW's for %d files.\n", numberof(jpgs);
   }
   for(i = 1; i <= numberof(jpgs); i++) {
      if(progress)
         timer_tick, tstamp, i, numberof(jpgs);
      somd = hms2sod(atoi(strpart(jpgs(i), -13:-8)));
      if(!mask(somd)) continue;
      jgwinfo = [file_dirname(jpgs(i)), date];
      ret = gen_jgw_file(somd);
      if(ret < 1) {
         if(progress) write, "";
         if(ret == 0) msg = "No file found.";
         else msg = cir_error(ret);
         write, format="Error for image %s: %s\n", jpgs(i), msg;
      }
   }
}

func gen_jgw_file( somd ) {
/* DOCUMENT gen_jgw_file(somd)

  This function generates jgw files to georef the CIR images.

 Inputs: somd
externs: jgwinfo  The path and date where the cir jpg files are loaded.
Returns: 0 if no cir file exists
         1 if it generated a jgw file
        -1 if cir_mask is void
        -2 if the no photo exists at the sod
        -3 The jgwinfo(1) path isn't set. See set_jgwinfo
        -4 The jgwinfo(2) date isn't set. See set_jgwinfo

Outputs: a jgw file named after the cooresponding cir.jpg file.

Original W. Wright 5/6/06

*/
   extern jgwinfo, jgwfndate, cir_mask;
   somd %= 86400;
   somd = int(somd);

   if (is_void(cir_mask)) return -1;
   if (!cir_mask(somd)) return -2;
   if (jgwinfo(1) =="") return -3;
   if (jgwinfo(2) =="") return -4;

   jgw_data = gen_jgw_sod(somd);
   if (numberof(jgw_data) == 1) { // an error is one element long, return it now.
      return jgw_data;
   }
   hms = sod2hms(somd, str=1);
   ofn = swrite(format="%s/%s-%s-cir.jgw",
         jgwinfo(1), jgwinfo(2), hms);
   jpg_ofn=swrite(format="%s-%s-cir.jpg",
         jgwinfo(2), hms);
   of = open(ofn,"w");
   write, of, format="%.6f\n", jgw_data(1:4);
   write, of, format="%.3f\n", jgw_data(5:6);
   close, of;
   return 1;
}

// Camera mounting bias values.
//
struct CIR_MOUNTING_BIAS {
   string name;   // Aircraft id (N-Number).
   float pitch;   // +nose up
   float roll;    // +cw (roll to the right)
   float heading; // +cw (right turn)
   float x;       // Offset from Camera to IMU along the fuselage toward the nose
   float y;       // Offset across the fueslage, positive toward the right wing
   float z;       // Offset +up
}

cir_mounting_bias_n111x = CIR_MOUNTING_BIAS();
cir_mounting_bias_n48rf = CIR_MOUNTING_BIAS();

//=================================================
// For N111x. Calibrated using 3/14/2006
// Ocean Springs, Ms. runway passes.
//=================================================
cir_mounting_bias_n111x.name = "n111x";
cir_mounting_bias_n111x.pitch  = 1.655;    // Now, set the bias values.
cir_mounting_bias_n111x.roll   =-0.296;
cir_mounting_bias_n111x.heading= 0.0;

//=================================================
// For N48rf calibrated using 4/11/2006 KSPG
//=================================================
cir_mounting_bias_n48rf.name = "n48rf";
cir_mounting_bias_n48rf.pitch  = -0.10 + 0.03 + 0.5 -0.5;    // Now, set the bias values.
cir_mounting_bias_n48rf.roll   = 0.50 - .28 + 0.03 + 0.75 - 0.14 -0.7;
cir_mounting_bias_n48rf.heading= 0.375 - 0.156 + 0.1;


//=================================================
// Camera specifications.
//=================================================
struct CAMERA_SPECS {
  string name;          // Camera name;
  double focal_length;  // focal length in meters
  double ccd_x;         // detector x dim in meters.  Along fuselage.
  double ccd_y;         // detector y dim in meters.  Across the fuselage.;
  double ccd_xy;        // Detector pixel size in meters.
  double trigger_delay; // Time from trigger to photo capture in seconds.
  double sensor_width;  // width of sensor in pixels
  double sensor_height; // height of sensor in pixels
  double pix_x;         // pixel size on sensor in meters
  double pix_y;         // pixel size on sensor in meters
}

///////////////////////////////////////////
// MS4000 info
///////////////////////////////////////////
ms4000_specs = CAMERA_SPECS();
ms4000_specs.name = "ms4000";
ms4000_specs.focal_length = 0.01325;
ms4000_specs.ccd_x = 0.00888;
ms4000_specs.ccd_y = 0.01184;
ms4000_specs.ccd_xy = 7.40e-6 * 1.02;
ms4000_specs.trigger_delay = 0.120;
ms4000_specs.sensor_width = 1600;
ms4000_specs.sensor_height = 1199;
ms4000_specs.pix_x = 7.4e-6; // 7.4 micron
ms4000_specs.pix_y = 7.4e-6; // 7.4 micron

camera_specs = ms4000_specs;
cir_mounting_bias = cir_mounting_bias_n111x;

/*
   The original gen_jgw function was a composite of the following functions
   gen_jgw_sod and gen_jgw. It was split into those two functions by David
   Nagle on 2008-12-01 to allow for more generalized JGW creation.

   The original gen_jgw had these comments associated with it:

   Original transformation code written by Jon Sellars and/or
   Chris parrish December, 2005.
   Updated by Jon Sellars and Bang Le, NOAA, December, 2005
   Updated by Jon Sellars and Chris Parrish to Read CSV files
   to create JGW world files for DSS Images April 2006

   Converted to Yorick for EAARL CIR jgw generation,
   W. Wright and Jon Sellars 5/4/2006

   Integrated with EAARL ALPS W. Wright 5/7/2006
*/

func gen_jgw_sod( somd ) {
/* DOCUMENT gen_jgw_sod(somd)
   Gen_jgw_sod(somd) generates JGW matrix elements.

   Inputs:  somd (Seconds of the mission day)
   Returns: A 1d array of the six elements for the jgw file.
*/
   extern iex_nav1hz;   // INS data dumbed down to 1hz
   extern cir_mounting_bias;
   extern camera_specs; // Camera specifications
   extern Geoid;

   // determine the seconds of the day... this needs changed to somd sometime
   timeBias = 1;     // the CIR acquisition times are off by exactly one second
   somd %= 86400;
   if ( is_void(iex_nav1hz) ) return -5;

   //================================================================================
   // Here we locate the index for our sod value.  We truncate it to integer seconds
   // for the search.  The actual time in the iex_nav1hz entry will already be offset
   // by the trigger_delay.
   //================================================================================
   somd += timeBias;
   insI = where( int(iex_nav1hz.somd) == somd )(1) ;
   if ( is_void(insI) ) return -6;
   ins = iex_nav1hz(insI);

   // Apply biases
   ins.pitch += cir_mounting_bias.pitch;
   ins.roll += cir_mounting_bias.roll;
   ins.heading += cir_mounting_bias.heading;


   // THe following should be determined by the lidar elevation. Right now it
   // is the ITRF elev offset to the airfield
   // Elevation offset from ground to nad83 ell.
   default, Geoid, -21.28;

   return gen_jgw(ins, camera_specs, Geoid);
}


func gen_jgw(ins, camera, elev, spatial_offset=) {
/* DOCUMENT gen_jgw(ins, camera, elev)
   Generates the JGW matrix for the data represented by the ins data, the
   camera specs, and the terrain elevation given.

   Parameters:
      ins: Should be a single-value instance of IEX_ATTITUDEUTM. If
         appropriate, biases should already be applied to it.
      camera: Should be a single-value instance of CAMERA_SPECS.
      elev: Should be the terrain height at the location of the image.

   Returns:
      A 6-element array of doubles, corresponding to the contents of the JGW
      file that should be created for the image.
*/
   default, spatial_offset, [-0.180, 0.170, 0.310];

   X = ins.easting;
   Y = ins.northing;
   Z = ins.alt;
   P = ins.pitch;
   R = ins.roll;
   H = ins.heading;

   CCD_X = camera_specs.ccd_x;
   CCD_Y = camera_specs.ccd_y;
   CCD_XY= camera_specs.ccd_xy;
   FL= camera_specs.focal_length;
   Xi = camera_specs.pix_x;
   Yi = camera_specs.pix_y;
   dimension_x = camera_specs.sensor_width;
   dimension_y = camera_specs.sensor_height;


   // Calculate pixel size based on flying height
   FH = Z + (-1.0 * elev);
   PixSz = (FH * CCD_XY)/FL;

   // Convert heading to - clockwise and + CCW for 1st and 3rd rotation matrix
   if (H >= 180.0)
      H2 = 360.0 - H;
   else
      H2 = 0 - H;

   Prad = P * d2r;
   Rrad = R * d2r;
   Hrad = H * d2r;
   H2rad = H2 * d2r;

   // Create Rotation Coeff
   Term1 = cos(H2rad);
   Term2 = -1.0 * (sin(H2rad));
   Term3 = sin(H2rad);

   // Create first four lines of world file
   // Resolution times rotation coeffs
   A = PixSz * Term1;
   B = -1.0 * (PixSz * Term2);
   C = (PixSz * Term3);
   D = -1.0 * (PixSz * Term1);

   // Calculate s_inv
   s_inv = 1.0/(FL/FH);

   // Create terms for the M matrix
   M11 = cos(Prad)*sin(Hrad);
   M12 = -cos(Hrad)*cos(Rrad)-sin(Hrad)*sin(Prad)*sin(Rrad);
   M13 = cos(Hrad)*sin(Rrad)-sin(Hrad)*sin(Prad)*cos(Rrad);
   M21 = cos(Prad)*cos(Hrad);
   M22 = sin(Hrad)*cos(Rrad)-(cos(Hrad)*sin(Prad)*sin(Rrad));
   M23 = (-sin(Hrad)*sin(Rrad))-(cos(Hrad)*sin(Prad)*cos(Rrad));
   M31 = sin(Prad);
   M32 = cos(Prad)*sin(Rrad);
   M33 = cos(Prad)*cos(Rrad);

   FLneg = -1.0 * FL;

   // s_inv * M * p + T(GPSxyz) CENTER PIX (Used to be UL_X, UL_Y, UL_Z)
   CP_X =
      M11 * spatial_offset(1) + M12 * spatial_offset(2) +
      M13 * spatial_offset(3) +
      (s_inv *(M11* Xi + M12 * Yi + M13 * FLneg)) + X;
   CP_Y =
      M21 * spatial_offset(1) + M22 * spatial_offset(2) +
      M23 * spatial_offset(3) +
      (s_inv *(M21* Xi + M22 * Yi + M23 * FLneg)) + Y;
   CP_Z =
      M31 * spatial_offset(1) + M32 * spatial_offset(2) +
      M33 * spatial_offset(3) +
      (s_inv *(M31* Xi + M32 * Yi + M33 * FLneg)) + FH;

   //Calculate Upper left corner (from center) in mapping space, rotate, apply
   //to center coords in mapping space
   Yoff0 = PixSz * (dimension_y / 2.);
   Xoff0 = PixSz * -1 * (dimension_x / 2.);

   Xoff1 = (Term1 * Xoff0) + (Term2 * Yoff0);
   Yoff1 = (Term3 * Xoff0) +(Term1 * Yoff0);

   NewX = Xoff1 + CP_X;
   NewY = Yoff1 + CP_Y;

   //Calculate offset to move corner to the ground "0" won't need this again
   //until we start doing orthos
   //Xoff0 = (tan(Ang_X + Prad)) * UL_Z
   //Yoff0 = (tan(Ang_Y + Rrad)) * UL_Z

   //Rotate offset to cartesian (+ y up +x right), rotate to mapping frame,
   //apply to mapping frame
   //Xoff1 = -1.00 * Yoff0
   //Yoff1 = Xoff0

   //Xoff2 = (Term1 * Xoff1) + (Term2 * Yoff1)
   //Yoff2 = (Term3 * Xoff1) + (Term1 * Yoff1)

   //NewX = UL_X + Xoff2
   //NewY = UL_Y + Yoff2

   return [A,B,C,D,NewX,NewY];
}

func gen_cir_tiles(pnav, src, dest, copyjgw=, abbr=) {
/* DOCUMENT gen_cir_tiles, pnav, src, dest, copyjgw=, abbr=

This function converts the cir image files (and corresponding world files)  from a "minute" directory into our regular 2k by 2k tiling format.

 Inputs:
   pnav:  "gps" or "pnav" data array for that mission day.
   src : source directory where the cir files in the "minute" format  are stored.
   dest: destination directory.
   copyjgw = set to 1 to copy the corresponding jgw files along with the jpg
      files.  Set to 0 if you don't want the jgw files to be copied over.
      Default = 1.
   abbr = set to 1 to use an "abbreviated" naming scheme for the directories.
      Instead of having a nested index tile/data tile format like normal EAARL
      data, this will create a single tier of directories named as
      e###_n####_##. Default = 0.
*/
   fix_dir, src;
   fix_dir, dest;
   default, copyjgw, 1;
   default, abbr, 0;

   write, "Generating a list of all images...";
   files = find(src, glob="*.jpg");
   files_sod = hms2sod(atoi(strpart(files, -13:-8)));

   utm_coords = fll2utm(pnav.lat, pnav.lon);
   north = utm_coords(1,);
   east = utm_coords(2,);
   zone = utm_coords(3,);
   utm_coords = [];

   tstamp = [];
   timer_init, tstamp;
   for(i = 1; i <= numberof(files); i++) {
      w = where(pnav.sod == files_sod(i));
      if(numberof(w) == 1) {
         w = w(1);
         dt=get_utm_dtcodes(north(w), east(w), zone(w));
         if(abbr) {
            dts = dt_short(dt);
            fdir = swrite(format="%s/%s/", dest, dts);
         } else {
            it=get_dt_itcodes(dt);
            fdir = swrite(format="%s/%s/%s/", dest, it, dt);
         }
         mkdirp, fdir;
         file_copy, files(i), fdir + file_tail(files(i));
         if (copyjgw) {
            jgwfile = file_rootname(files(i))+".jgw";
            if (file_exists(jgwfile)) {
               file_copy, jgwfile, fdir + file_tail(jgwfile);
            }
         }
         timer_tick, tstamp, i, numberof(files);
      }
   }
}

func copy_sod_cirs(sods, src, dest, copyjgw=, progress=) {
/* DOCUMENT copy_sod_cirs, sods, src, dest, copyjgw=, progress=

   Given an array of SOD values, this copies all corresponding CIR images
   located in src to dest.

   Set copyjgw=0 to disable copying of the associated jgw files (enabled by
   default). Set progress=0 to disable progress information (enabled by
   default).
*/
   fix_dir, src;
   fix_dir, dest;
   default, copyjgw, 1;
   default, progress, 1;
   mkdirp, dest;
   files = find(src, glob=swrite(format="*-%s-cir.jpg", sod2hms(sods, str=1)));
   for(i = 1; i <= numberof(files); i++) {
      cmd = "cp " + files(i) + " " + dest;
      if(progress)
         cmd;
      system, cmd;
      if(copyjgw) {
         jgwfile = file_rootname(files(i))+".jgw";
         if(file_exists(jgwfile)) {
            cmd = "cp " + jgwfile + " " + dest;
            if(progress)
               cmd;
            system, cmd;
         }
      }
   }
}

func copy_pnav_cirs(q, src, dest, copyjgw=, progress=) {
/* DOCUMENT copy_pnav_cirs, q, src, dest, copyjgw=, progress=

   Given a where query result q, this will copy CIR images located in src that
   correspond to pnav.sod(q) to the destination directory dest. This is useful
   in conjunction with the return value of points in polygon and similar tools.

   Set copyjgw=0 to disable copying of the associated jgw files (enabled by
   default). Set progress=0 to disable progress information (enabled by
   default).
*/
   extern pnav;
   copy_sod_cirs, pnav.sod(q), src, dest, copyjgw=copyjgw, progress=progress;
}

func tune_cir_parameters(photo_dir, date, fixed_roll=, fixed_pitch=,
fixed_heading=, fixed_geoid=, mask=, maxgen=, initial_biases=, initial_geoid=,
stdevs=, no_evolve=, pto_script=, win=) {
/* DOCUMENT tune_cir_parameters(photo_dir, date, fixed_roll=, fixed_pitch=,
   fixed_heading=, fixed_geoid=, mask=, maxgen=, initial_biases=,
   initial_geoid=, stdevs=, no_evolve=, pto_script=, win=)

   Warning: This function is experimental!

   This is used to tune the parameters used to make JGWs for CIR images: roll,
   pitch, heading, and geoid. It tunes these parameters using an optimization
   algorithm that is similar to simulated annealing or evolution strategy
   (depending on the exact parameters used).

   The approach is thus:

      1. Find a subset of CIR images that overlap and contain several different
         flightlines. Alternately, find several such subsets of images. Put
         all of these images in a single directory. Try not to use more than
         a few hundred images; certainly no more ~500 images in most cases. As
         few as 20-30 can sometimes yeild results, though.

      2. Take these images to a Windows machine. Use autopano to generate
         control points for these images. You can find autopano here:
            http://autopano.kolor.com/
         Make sure you use autopano_v103 or later, as it is substantially
         improved over previous versions. The command you want to use to make
         control points is:
            autopano.exe /project:hugin /size:800 /keys:8
         You want to run that from within the image directory (from the Windows
         command line). It will generate one or more *.pto files. You can try
         different values for /size: and /keys:, but make sure /project:hugin
         is always set. See autopano's documentation for more information
         about that software.

      3. Optionally, open up each PTO file in Hugin to make sure the control
         points generated are good. You can find hugin here:
            http://hugin.sourceforge.net/
         You want to usually avoid having control points on bodies of waters,
         because they are typically not stable. Control points on shadows or
         vehicles or people are similarly not stable. Sometimes, good control
         points are difficult to find due to distortion and parallax. You can
         manually add and/or remove control points as desired, then save the
         files.

      3. Copy the *.pto files back to the linux machine and put them in a
         directory.  This can be the same directory as the images, or it can be
         a different directory. It doesn't matter.

      4. Run this function.

   You may have to try many different combinations of parameters to get good
   results, and you may have to run the function repeatedly, starting it with
   the last session's best result each time.

   The procedure of tuning the CIR parameters is a trial-and-error approach
   that may be trying to solve the wrong problem but still can yield improved
   results.  As such, you may not get good results. The RMSD given by this
   function for each set of parameters is a good guideline for how well the
   images in the subset fit together, but may not represent the dataset as a
   whole. Thus, it is important to test the tuned parameters against other
   images outside of the subset, preferably from other flightlines in the same
   mission day.

   Note that this essentially speeds up what would be done manually. Normally,
   you would tweak the four parameters manually, run the JGWs, then take a look
   at them to see if it improved things. This function requires a bit more
   setup time, but allows you to explore magnitudes more combinations of
   parameters in a much shorter time period.

   Sometimes, however, it does not work *AT ALL*. Sometimes, it will tell you
   that the roll is 50 degrees and the pitch is -80 and the heading is 90
   degrees.  This is your hint that you can't use the function to optimize
   those paramters.  Try fixing them at the default and just optimize the
   geoid. The geoid might be any value; it isn't usually the actual geoid
   because (at present) cir-mosaic's other functions generate jgw's without
   compensating for the actual elevation.  Eventually using the lidar data to
   do so will probably partly or largely obsolete this function.

   Parameters:
      photo_dir: The directory to the CIR photo subset.
      date: A string in MMDDYY format, where MM is the month minus 1.

   Options:
      fixed_roll= If specified, this forces the roll to the given fixed value.
      fixed_pitch= If specified, this forces the pitch to the given fixed
         value.
      fixed_heading= If specified, this forces the heading to the given fixed
         value.
      fixed_geoid= If specified, this forces the geoid to the given fixed
         value.
      mask= An array that indicates whether the jgw for the image at any given
         SOD should be generated (1) or not (0). The default is array(short(1),
         86400), which specifies that all images can have jgws generated.
      maxgen= The maximum number of generations that will be run before
         termination. The default is 10000.
      initial_biases= Defaults to cir_mounting_bias_n111x.
      initial_geoid= Defaults to -30.
      stdevs= The standard deviations to use when generating random adjustments
         for the parameters. This is an array of doubles that matches the
         params, where each element is the standard deviation to use for that
         parameter.  The random adjustments are generated from a standard
         normal distribution with mean=0 and the given standard deviation. The
         default is [0.25, 0.25, 0.25, 1.0].
      no_evolve= If set to 1, then no optimization takes place. Instead, it
         uses the given parameters to generate the jgws for the given photo
         directory, then stops.
      pto_script= The location of the script to use to determine the RMSM. The
         default is "./pto_cir.pl".
*/
   extern cir_mounting_bias;
   extern cir_mounting_bias_n111x;
   extern Geoid;

   default, maxgen, 10000;
   default, mask, array(short(1), 86400);
   default, stdevs, [0.25, 0.25, 0.25, 1.0];
   default, no_evolve, 0;
   default, initial_biases, cir_mounting_bias_n111x;
   default, initial_geoid, -30.0;
   default, pto_script, "./pto_cir.pl";

   state = h_new(
      photo_dir=photo_dir, date=date, mask=mask, pto_script=pto_script,
      roll=initial_biases.roll,
      pitch=initial_biases.pitch,
      heading=initial_biases.heading,
      geoid=initial_geoid
   );

   if(!is_void(win)) {
      h_set, state, "window", win;
      window, win;
      plg, [0,0], [0, maxgen];
   }

   if(!is_void(fixed_roll))
      h_set, state, "fixed_roll", fixed_roll;
   if(!is_void(fixed_pitch))
      h_set, state, "fixed_pitch", fixed_pitch;
   if(!is_void(fixed_heading))
      h_set, state, "fixed_heading", fixed_heading;
   if(!is_void(fixed_geoid))
      h_set, state, "fixed_geoid", fixed_geoid;

   fields = ["roll", "pitch", "heading", "geoid"];
   for(i = 1; i <= numberof(fields); i++) {
      h_set, state, "stdev_" + fields(i), stdevs(i);
      if(h_has(state, "fixed_" + fields(i)))
         h_set, state, fields(i), h_get(state, "fixed_" + fields(i));
   }

   state = simulated_annealing(state, maxgen, 0.01,
      __tcpsa_energy, __tcpsa_neighbor, __tcpsa_temperature,
      show_status=__tcpsa_status);

   return state;
}

func __tcpsa_energy(state) {
   extern cir_mounting_bias;
   extern Geoid;

   cir_mounting_bias.roll = state.roll;
   cir_mounting_bias.pitch = state.pitch;
   cir_mounting_bias.heading = state.heading;
   Geoid = state.geoid;

   batch_gen_jgw_file, state.photo_dir, state.date, progress=0, mask=state.mask;

   cmd = state.pto_script + " " + state.photo_dir + " " + state.photo_dir + " ";
   f = popen(cmd, 0);
   rmse = 0.0;
   read, f, rmse;
   close, f;

   return rmse;
}

func __tcpsa_neighbor(state) {
   state = h_copy(state);
   fields = ["roll", "pitch", "heading", "geoid"];
   for(i = 1; i <= numberof(fields); i++) {
      if(h_has(state, "fixed_" + fields(i))) {
         h_set, state, fields(i), h_get(state, "fixed_" + fields(i));
      } else {
         val = h_get(state, fields(i));
         dev = h_get(state, "stdev_" + fields(i));
         h_set, state, fields(i), val + random_n() * dev;
      }
   }
   return state;
}

func __tcpsa_temperature(time) {
   return 0.995 ^ (1 + time * 999);
}

func __tcpsa_status(status) {
   write, format="%d/%d: %.3f\n", status.iteration, status.max_iterations, status.energy;
   if(h_has(status.state, "window")) {
      window, h_get(status.state, "window");
      plmk, status.energy, status.iteration, msize=0.1, marker=1;
   }
}

func subsample_lines(q, skip=) {
/* DOCUMENT subsample_lines(q, skip=)

   Given an array of indices q into a flightline, this subsamples the
   flightlines. In other words, it returns only selected lines in the set. You
   can use skip= to control this behavior. The default, skip=2, returns every
   other flightline. Using skip=1 just returns all data. Using skip=3 returns
   every third, etc.

   This will ONLY work if q is the original indices returned from Points in
   Polygon or similar. If you've subsampled it (ie, q = q(::2)), this function
   will not function correctly. It'll effectively subsample *within* the
   flightlines.

   Original: David Nagle 2007-12-17
*/
   if(!numberof(q))
      return;
   default, skip, 2;
   qdif = q(dif);
   boundaries = where(q(dif) > 1);
   if(!numberof(boundaries))
      return q;
   boundaries = grow(0, boundaries, numberof(q));
   starts = boundaries(:-1) + 1;
   ends = boundaries(2:);
   starts = starts(::skip);
   ends = ends(::skip);
   filter = array(0, numberof(q));
   qq = [];
   for(i = 1; i <= numberof(starts); i++) {
      grow, qq, q(starts(i):ends(i));
   }
   return qq;
}
