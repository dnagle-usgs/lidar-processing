/*
   ************************ DEPRECATION NOTICE 2009-04-15 ************************
   This file is deprecated in favor of mosaic_tools.i. If you need to create
   JGW files for imagery, you probably want to use mosaic_tools.i instead.
*/
write, "***************************************************************************";
write, "* WARNING: You are loading cir-mosaic.i. This file has been deprecated in *";
write, "* favor of mosaic_tools.i.                                                *";
write, "***************************************************************************";

require, "eaarl.i";
require, "photo.i";
require, "random.i";
require, "evolve.i";
require, "mosaic_biases.i";
write,"$Id$";

/*
   Functions to work with the EAARL Axis digital camera.  

   Orginal W. Wright, 5-6-03 while in San Juan, Pr.
*/

cam1_roll_bias = 0.0;
cam1_pitch_bias  = 0.0;
fov = 50.0 * pi/180.0;   // camera FOV

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

// Set the jgwinfo array to two "" strings.
if ( is_void( jgwinfo) ) {
  jgwinfo = array(string,2);
  jgwinfo(1) = jgwinfo(2) = "";
}

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
   return photo_orient(photo, heading=heading, pitch=pitch, roll=roll,
      center=center, offset=offset, scale=scale, win=win,
      mounting_biases=[0.0, 0.0, 0.0]);
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

func load_cir_mask( fn ) {
/* DOCUMENT load_cir_mask( fn )

 Original: W. Wright 5/4/2006

031006-214859-332-cir.jpg

*/
   extern cir_mask;
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
   write,format="Read %d CIR file names from: %s\n", i-1, fn;
   close,f;
   return 1;
}

func gen_jgw_files( somd_list ) {
/* DOCUMENT gen_jgw_files( somd_list )

 Generates jgw files for each element of the somd_list.

ls | grep jgw > junk
tar --remove-files -cvzf jgwfiles.tgz -T junk


Original W. Wright 5/6/06
*/
   extern jgwinfo, camera_specs;
   n = numberof( somd_list );
   if ( is_void( jgwinfo ) ) {
      write, "Operation aborted. The jgwinfo array must be set first. try: help, jgwinfo";
   }
   gen_cir_nav, camera_specs.trigger_delay;
   for (i=1; i<= n; i++ ) {
      e = gen_jgw_file(somd_list(i));     // Generate each jgw file.
      if(e != 1)
         write,format="Error %d for sod:%d\n", e, i;
      if((i % 100) == 0)
         write, format=" Generated: %d of %d (%3.0f%%) jgw files\r", i, n, (i*100.0/n);
   }
   i--;
   write, format=" Generated: %d of %d (%3.0f%%) jgw files\r", i, n, (i*100.0/n);
   write,"\nOperation completed.\n";
   return 1;
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
   extern jgwinfo;
   if (is_void(dir)) return jgwinfo;
   if (y > 2000) y -= 2000;
   jgwinfo(1) = dir;
   jgwinfo(2) = swrite(format="%02d%02d%02d", m-1,d,y);
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
   extern camera_mounting_bias;
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
   ins.pitch += camera_mounting_bias.pitch;
   ins.roll += camera_mounting_bias.roll;
   ins.heading += camera_mounting_bias.heading;


   // THe following should be determined by the lidar elevation. Right now it
   // is the ITRF elev offset to the airfield
   // Elevation offset from ground to nad83 ell.
   default, Geoid, -21.28;

   return gen_jgw(ins, Geoid, camera=camera_specs);
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
