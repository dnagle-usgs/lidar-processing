/*
  $Id$
*/

#include <stdio.h>
#include <math.h>
#include <string.h>
 
/*
    gga2bin.c          
   
     This program reads a nmea gpgga string, verifies it's checksum,
     and converts the time, lat,lon, and altitude to binary for reading
     into yorick.

*/

#define MAXSTR  1024 
static struct {
  float sod, lat, lon, alt;
 } gga;                                

main( int argc, char *argv[] ) {    
 FILE *idf, *odf;
 float sod, lat, lon, alt, s;
 int h, m, n, nb, good=0, badcnt=0, line=0;
 char  comma[]=",";
 char *p, *t, *latp, *lonp, *tp;
 char str[MAXSTR*2], scp[ MAXSTR+2 ];
 int cksum, sum, i;
  if ( (idf=fopen( argv[1], "r" ) ) == NULL ) {
    perror(""); exit(1);
  }
  if ( ( odf=fopen(argv[2], "w+")) == NULL ) {
    perror(""); exit(1);
  }                                                      
  

// write placeholder for the number of records.  We'll reposition to
// this after we know how many elements there are.
    fwrite( &good, sizeof(int), 1, odf);                          

   while ( !feof(idf) ) {

// get the nmea string
     fgets( str, MAXSTR-4, idf );
    line++;

// compute the checksum.  
     for (i=0, sum=0; i<strlen(str); i++ ) {
       if ( str[i]=='$') continue;
       if ( str[i] == '*' ) break;
       sum = sum ^ str[i];
     }
     i++;
     cksum = strtol(  &str[i], NULL, 16 );
//     str[ strlen(str)-2] = 0;
     if ( cksum != sum ) {
 	printf("%8d: %s %02x\n",  line, str, sum); 
	badcnt++;
     } else {	// good data
// Process the time substring into second of the day
       p = &str[0];
       strcpy( scp, str );
       for (nb=0, i=0; i<10; i++ ) {
       t = strsep( &p, comma );

#define HMS	1
#define LAT	2
#define NS	3
#define LON	4
#define EW	5
#define ALT	9
       switch (i) {
       case HMS:
         tp = t;
         sscanf( t, "%02d%02d%f", &h, &m, &s);
         sod = h*3600 + m*60 + s;
	break;

       case LAT:
         latp = t;
	 n = sscanf( t, "%02d%f", &h, &s );
	if ( n != 2 ) nb++;
	 lat = h + s/60.0;
	break;

	case NS:  
	  lat = ( *t == 'S' ) ? -lat : lat;
	break;

       case LON:
         lonp = t;
	 sscanf( t, "%03d%f", &h, &s );
	 lon = h + s/60.0;
	break;

	case EW:  
	  lon = ( *t == 'W' ) ? -lon : lon;
	break;

	case ALT:
	  sscanf( t, "%f", &alt );
	break;
       }
      }
   if ( nb == 0 ) {
   good++;
   gga.sod = sod;
   gga.lat = lat;
   gga.lon = lon;
   gga.alt = alt;
   fwrite( &gga, sizeof(gga), 1, odf);
/*
if ( line > 152960 )  {
   printf("%7d====%s %s %s %f %f>%s", line,tp, latp, lonp, lat,lon,scp );
}
*/
// printf("\n%f %f %f %f", gga.sod, gga.lat, gga.lon, gga.alt);
     } else {
 	printf("%8d: %s\n",  line, scp); 
	badcnt++;
     }
    }
   }
  fseek( odf, 0, SEEK_SET);
  fwrite( &good, sizeof(int), 1, odf);          // install count
  printf("\n%d total points, %d good points, %d bad points\n", line, good, badcnt);           
}

