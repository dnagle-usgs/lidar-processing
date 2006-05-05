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


////////////////////////////////////////////////////////////////////////
// ls | awk -F- '{h = substr($2,1,2); m = substr($2,3,2); s=substr($2,5,2); print h*3600+m*60+s" "$3}' > cir.mask
////////////////////////////////////////////////////////////////////////

func load_cir_mask( fn ) {
 extern cir_mask
 cir_mask = array(short, 86400); 
 tmp = array(long,86400*2);
 f = open( fn, "r");
 n = read(f,format="%d", tmp );
 write,format="Read %d CIR file names from: %s\n", n, fn
 close,f
 for (i=1; i<= n; i+=2 ) {
   cir_mask(tmp(i)) = tmp(i+1);
 }
}
 

func gen_jgw_file( somd ) {
/* DOCUMENT gen_jgw_file(somd)

  This function generates jgw files to georef the CIR images. 

 Inputs: somd
externs: jgwpath  The path where the cir jpg files are loaded.
Returns: 0 if no cir file exists
         1 if it generated a jgw file
Outputs: a jgw file named after the cooresponding cir.jpg file.

*/
 extern jgwpath, jgwfndate, cir_mask
 somd %= 86400
 if ( !cir_mask(somd) ) {
    return 0;
 }

 a = gen_jgw( somd );
 hms = sod2hms(somd);
 ofn=swrite(format="%s%02d%02d%02d-%03d-cir.jgw", 
    jgwpath, hms(1),hms(2),hms(3), cir_mask(somd) );
 write,format="%s\n", ofn
 of = open(ofn,"w");
 write,of,format="%9.6f \n", a(1:4)    
 write,of,format="%12.3f \n", a(5:6)    
 close,of
}

func gen_jgw( somd ) {
/* DOCUMENT gen_jgw(somd)

 Gen_jgw(somd) generates JGW matrix elements. 

 Inputs:  somd (Seconds of the mission day)
 Returns: A 1d array of the six elements for the jgw file.

 

Written by Jason Woolard, NOAA, August 17, 1999
Updated by Jon Sellars and Bang Le, NOAA, December, 2005
Updated by Jon Sellars and Chris Parrish to Read CSV files 
  to create JGW world files for DSS Images April 2006

Converted to Yorick for EAARL CIR jgw generation, 
W. Wright and Jon Sellars 5/4/06
*/
extern iex_nav1hz;	// INS data dumbed down to 1hz

// determine the seconds of the day... this needs changed to somd sometime
timeBias = 1;
somd %= 86400
insI = where( iex_nav1hz.somd == somd )(1) ;
insI += timeBias;
somd
insI
ins
if ( is_void(insI) ) return 0;
ins = iex_nav1hz(insI);

Z = ins.alt;
X = ins.easting;
Y = ins.northing; 
P = ins.pitch; 
R = ins.roll; 
H = ins.heading; 

// ******************************************************
// Fixed variables
// ******************************************************
// CCD_X = along track meters
// CCD_Y = across track meters
// CCD_XY pixel size on CCD array meters
// Estimate for project area
// BS_PRH are adjustments from the boresite in degrees
     FL=0.01325
 CCD_X = 0.00888
 CCD_Y = 0.01184
CCD_XY = 0.0000074
 Geoid = -24.0
  BS_P = 1.00
  BS_R = 0.5
  BS_H = 0.75

 // Calculate pixel size based on flying height
    FH=Z + (-1.0 * Geoid)
    PixSz=(FH*CCD_XY)/FL


    // Convert heading to - clockwise and + CCW for 1st rotation matrix
    if (H >= 180.0) 
       H2= 360.0 - (H + BS_H);
    else 
      H2 = -((H + BS_H) * 1.0);
//

    Prad = (P + BS_P) * d2r
    Rrad = (R + BS_R) * d2r
    Hrad = (H + BS_H) * d2r
    H2rad = H2 * d2r

    // Create Rotation Coeff's
    Term1 = cos(H2rad)
    Term2= -1.0* (sin(H2rad))
    Term3 = sin(H2rad)

    // Create first four lines of world file
    // Resolution times rotation coeff's
    A=PixSz * Term1
    B=-1.0*(PixSz * Term2)
    C=(PixSz * Term3)
    D=-1.0*(PixSz *Term1)

    // Calculate s_inv
	s_inv = 1.0/(FL/FH)

	// Create terms for the M matrix
	M11 = cos(Prad)*sin(Hrad)
	M12 = -cos(Hrad)*cos(Rrad)-sin(Hrad)*sin(Prad)*sin(Rrad)
	M13 = cos(Hrad)*sin(Rrad)-sin(Hrad)*sin(Prad)*cos(Rrad)
	M21 = cos(Prad)*cos(Hrad)
	M22 = sin(Hrad)*cos(Rrad)-(cos(Hrad)*sin(Prad)*sin(Rrad))
	M23 = (-sin(Hrad)*sin(Rrad))-(cos(Hrad)*sin(Prad)*cos(Rrad))
	M31 = sin(Prad)
	M32 = cos(Prad)*sin(Rrad)
	M33 = cos(Prad)*cos(Rrad)

	// Define p matrix (+X direction of flight along track, +Y left wing across track, -FL)
	Xi = CCD_X/2.0
	Yi = CCD_Y/2.0
	FLneg = -1.0 * FL

	// s_inv * M * p + T(GPSxyz)
	UL_X = (s_inv *(M11* Xi + M12 * Yi + M13 * FLneg)) + X
	UL_Y = (s_inv *(M21* Xi + M22 * Yi + M23 * FLneg)) + Y
	UL_Z = (s_inv *(M31* Xi + M32 * Yi + M33 * FLneg)) + Z

// write, format="A=%f B=%f C=%f D=%f ULX=%f ULY=%f\n", A, B, C, D, UL_X, UL_Y
 return [A,B,C,D,UL_X, UL_Y];
}



