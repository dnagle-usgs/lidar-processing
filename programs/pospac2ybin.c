/***********************************************************************
 *  pospac2ybin.c
 *  Convert Applanix "pospac" data to a ybin file. 
 *  Original: W. Wright 8/7/2003
 *
 *  This program does the following:
 *    1) Reads little Endian binary pospac "sbet" data from stdin.
 *    2) drops x_velocity,  y_velocity, z_velocity, wander_angle,
 *      x_body_acceleration, y_body_acceleration, z_body_acceleration
 *      x_body_angular_rate, y_body_angular_rate, y_angular_rate.
 *    3) Converts the data from radians to decimal degrees.
 *    4) Computes true heading from platform_heading and wander_angle.
 *    5) Outputs a binary "ybin" file in the following format:
 *       
 *        32 byte string with start and record_cnt encoded
 *        as hex.
 *        string notes (at least 1024 bytes reserved here for notes)
 *        ......
 * start: r(1)
 *        r(2)    
 *        ....
 *        r(count) 
 *
 *
 *
 * Where "r" is structure composed of:
 *        somd    32 bit unsigned seconds of the mission day
 *        alt     32 bit signed integer. lsb=.001m or 1mm
 *        pitch   32 bit signed integer.  lsb = 360.0/2^31
 *        roll    32 bit signed integer.  lsb = 360.0/2^31
 *        heading 32 bit signed integer.  lsb = 360.0/2^31
 *        lat     32 bit latitude decimal degrees where lsb = 360.0 / 2^31
 *        lon     32 bit longitude decimal degrees  
 *
 *
***********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <math.h>

struct POSPAC {
  double time;				// used
  double latitude;			// used
  double longitude;			// used
  double altitude;			// used
  double x_velocity;			// na        
  double y_velocity;			// na        
  double z_velocity;			// na         
  double roll;				// used
  double pitch;				// used
  double platform_heading;		// used
  double wander_angle;			// used
  double x_body_acceleration;		// na
  double y_body_acceleration;		// na
  double z_body_acceleration;		// na
  double x_body_angular_rate;		// na
  double y_body_angular_rate;		// na
  double y_angular_rate;		// na
} pospac;


#define RAD2DEG (180.0/M_PI)
#define BIN_ANGLE ((RAD2DEG/360.0)*pow(2.0,31.0))

// The structure that will be read by ALPS
// to convert angles to double multiply by 360.0*2^31
struct POSPRH {
  unsigned long  somd;   // lsb = 1 second
  unsigned long    ns;   // lsb = 1e-9
  long            alt;   // lsb =  .001 meters (1mm)   *1e-3 for meters
  long          pitch;   // lsb on all angles = 360.0 / 2^31   *(2^-31)
  long           roll;
  long        heading;
  long            lat;   
  long            lon;
} posprh;


FILE *idf, *odf;
int idf_fd;
struct stat idf_stat;
unsigned int cnt=0, 
	     data_start,
	     start_somd,
	     nbr_input_recs;

char start[20];
char notes[2048]={"No comments"};

usage ( int rv ) {
     printf("\n\nUsage:\npospac2ybin inputfile outputfile\n\n");
     exit(rv);
}

main(int argc, char *argv[]) {
	unsigned int ft;
	char str[256];
   if ( argc < 3 ) {
     usage(1);
   }
   if ( (idf = fopen(argv[1], "r")) < 0 ) {
	   perror("");
	   usage(1);
   }

   if ( (odf = fopen(argv[2], "w")) < 0 ) {
	   perror("");
	   usage(1);
   }

  idf_fd = fileno(idf);
  fstat( idf_fd, &idf_stat);
  nbr_input_recs = idf_stat.st_size/sizeof(pospac);
  printf("\n %s contains %d sbet records\n", argv[1], nbr_input_recs);
  sprintf( str, "%08x ", nbr_input_recs);

  fwrite(start, sizeof(start), 1, odf);	        // 
  fwrite(&notes, sizeof(notes), 1, odf);	// save notes space

  // Store the ascii/hex byte offset to the start of data.
  data_start = ftell(odf);

  while ( !feof(idf) ) {
    fread( &pospac, sizeof(pospac), 1, idf);
     cnt++;
     if ( (cnt % 1000) == 0 ) {
       printf("\r%7d of %7d  %3.0f%c completed  ",    
          cnt, nbr_input_recs, ((float)cnt*100.0)/(float)nbr_input_recs, '%' );
     }
       posprh.somd = (unsigned int)pospac.time;
      posprh.ns    = (unsigned int)((pospac.time-(int)pospac.time) * 1.0e9);
      posprh.lat   = (int)(pospac.latitude*BIN_ANGLE);
      posprh.lon   = (int)(pospac.longitude*BIN_ANGLE);
      posprh.pitch = (int)(pospac.pitch*BIN_ANGLE);
      posprh.roll  = (int)(pospac.roll*BIN_ANGLE);
        posprh.alt = pospac.altitude*1000.0;
    posprh.heading = (int)((pospac.platform_heading)*BIN_ANGLE);
     if ( cnt == 1 ) {
       printf("\nStart time: %ld.%ld(somd)\n", posprh.somd, posprh.ns);
       start_somd = posprh.somd;
     }

    /*
     printf("%10u.%06u %12d %12d %12d %12d %12d %12d \n",
      posprh.somd, 
      posprh.ns,
      posprh.lat,
      posprh.lon,
      posprh.alt,
      posprh.pitch,
      posprh.roll,
      posprh.heading
     );
     */
     fwrite(&posprh, sizeof(posprh), 1, odf);
   }
  fseek( odf, 0, SEEK_SET);
  sprintf( start, "%08x %08x ", data_start, nbr_input_recs);
  fwrite(start, sizeof(start), 1, odf);	                // 
  fclose(odf);
   printf("\nStop  time: %ld.%ld, Mission time %3.2f(hrs)\n", 
		   posprh.somd, posprh.ns, (posprh.somd-start_somd)/3600.0);
   printf("\nConversion completed\n");
}






