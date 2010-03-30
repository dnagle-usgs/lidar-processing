/*
  2/25/02 ww changed to properly handle somd.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <dirent.h>     // for MAXNAMLEN
#include <unistd.h>     // for access()

/*
    tans2bin.c

    This program reads an input ascii file of tans vector data
 in the format: time roll pitch heading   where time is in seconds
 of the week.  This program strips out the attitude records and
 checks the limits on pitch roll time and heading to insure 
 they are reasonable.  The output format is binary so it can be
 quickly be read into Yorick.  The first item is a 32 bit 
 integer describing the number of time/roll/pitch/heading values
 to follow.  Time is converted to seconds-of-the-day.

     If only one filename is given, the output filename is generated
 by replacing everything after the last period with "ybin" or adding
 ".ybin" to the end if there is no period.  If a file already exists
 with the generated named, the program exits instead of over writing
 it.

*/

#define MAXSTR	1024

struct {
  long sod, roll, pitch, heading;
 } attitude;


char *changename( char *ostr, char *nstr, char *txt ) {
  char *pstr;

	strncpy(nstr, ostr, MAXNAMLEN-1); // make a copy

  pstr = strrchr( nstr, '.');       // find the period
  if ( !pstr ) {                    // no period,
	  pstr = nstr;
	  while ( *(++pstr) != '\0');     // find the end of the string
  }

	strcpy(pstr, txt);                // append the text
  return(nstr);
}

main( int argc, char *argv[] ) {
FILE *idf, *odf;
 int rec, good, badcnt, bad, i, n;
 float fgt=-1.0, gap, maxgap;
 char str[ MAXSTR ];
 float  roll, pitch, heading;
 double sod, lgt, sow;
 const double sid = 86400.0;		// seconds in a day
 int day;
 maxgap = 1.0;

  if ( (idf=fopen( argv[1], "r" ) ) == NULL ) {
    perror(""); exit(1);
  }

  if ( argc == 2 ) {  // generate and open the output file
    char *pfname, nfname[MAXNAMLEN];
		changename(argv[1], nfname, ".ybin");
    fprintf(stderr, "creating output file: %s\n", nfname);
    if ( access(nfname, F_OK) == 0 ) {
      fprintf(stderr, "file %s exists, please remove it first\n", nfname);
			exit(-1);
    } else {
      if ( ( odf=fopen(nfname, "w+")) == NULL ) {
        perror(""); exit(1);
      }
    }
  } else {    // open the file given on the cmdline

    if ( ( odf=fopen(argv[2], "w+")) == NULL ) {
       perror(""); exit(1);
    }
  }


// write placeholder for the number of records.  We'll reposition to
// this after we know how many elements there are.
    fwrite( &good, sizeof(int), 1, odf);

    rec = good = badcnt = 0;
    gap = 0.0;
    while ( fgets( str, MAXSTR, idf ) > 0  ) {
     if ( strncmp( str, "0x9a", 4 ) ==0 ) {
       n = sscanf( str, "0x9a %lf %f %f %f", &sow, &roll, &pitch, &heading );
       if ( n == 4 ) {
          bad = 0;
          if ( (pitch < -180.0 ) || ( pitch > 180.0 )) bad++;
          if ( (roll < -180.0 ) || ( roll > 180.0 )) bad++;
          if ( (heading < 0.0 ) || ( heading > 360.0 )) bad++;
	  pitch = ( pitch > 180.0 ) ? pitch - 360.0 : pitch;
	  if ( sow == 0.0 ) bad++;
	  if ( sow < lgt )  bad++;
          if ( bad == 0 )  {
             if ( fgt == -1.0 ) {
	        sod = fmod( sow, sid); 
	 	fgt = sow - sod;	// save first good time value
printf("\nfgt=fgt=%lf sow=%lf sod=%lf sid=%lf", fgt, sow, sod, sid);
             }

	     attitude.heading = heading *1000.0;
	     attitude.roll    = roll    *1000.0;
	     attitude.pitch   = pitch   *1000.0;

/************************************************************************
 Tricky biz follows.........
 
 Seconds of the week from the tans are in 0.1 increments which do not 
 comvert to exact binary values.  In order to transport the values to 
 the ybin file, it is read as a double, which frequently rounds to 
 something 0.9999. 

 The orginal float code caused a rounding error on the order of 0.025
 seconds.
**************************************************************************/
	     attitude.sod = (((int)((sow - fgt) * 1000.0)+1)/10) * 10; 

	     if ( good ) fwrite( &attitude, sizeof(attitude), 1, odf );
	     gap = sod - lgt;
	     if ( (gap >= maxgap) && good ) {
                printf("%10.2f %10d %9.5f %7.3f %7.3f %7.3f\n", gap, sod, fmod(sow, sid), roll, pitch, heading );
	     }
	     lgt = sod;
             good++;
 	  } else badcnt++;
       } 
     }
  }
  good--;		// account for dropping first point
  fseek( odf, 0, SEEK_SET);
  fwrite( &good, sizeof(int), 1, odf);		// install count
  printf("\n%d good points, %d bad points\n", good, badcnt);
}


