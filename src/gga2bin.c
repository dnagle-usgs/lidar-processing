/*
  $Id$
*/

#include <stdio.h>
#include <math.h>
#include <string.h>
#include <dirent.h>     // for MAXNAMLEN
#include <unistd.h>     // for access()

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
 int nb;
 float sod, lat, lon, alt, s;
 int h, m, n, good=0, badcnt=0, line=0;
 char  comma[]=",";
 char *p, *t, *latp, *lonp, *tp;
 char str[MAXSTR*2], scp[ MAXSTR+2 ];
 int cksum, sum, i;
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

   while ( 1 ) {

// clear the string before use
  memset( str, 0, MAXSTR );
   
// get the nmea string
     fgets( str, MAXSTR-4, idf );
     if (feof(idf)) 
	     break;
    line++;

// compute the checksum.  
     for (i=0, sum=0; i<strlen(str); i++ ) {
       if ( str[i]=='$') continue;
       if ( str[i] == '*' ) break;
       sum = sum ^ str[i];
     }
     i++;
     cksum = strtol(  &str[i], NULL, 16 );
     //printf("cksum = %02x ; sum = %02x\n",cksum, sum);
//     str[ strlen(str)-2] = 0;
     if ( cksum != sum ) {
 	printf("%8d: %s %02x %02x\n",  line, str, sum, cksum); 
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
         n = sscanf( t, "%02d%02d%f", &h, &m, &s);
	 if ( n == 3 ) 
            sod = h*3600 + m*60 + s;
	 else nb++;
	break;

       case LAT:
         latp = t;
	 n = sscanf( t, "%02d%f", &h, &s );
	if ( n == 2 ) 
	 lat = h + s/60.0;
	else
	 nb++;
	break;

	case NS:  
	  lat = ( *t == 'S' ) ? -lat : lat;
	break;

       case LON:
         lonp = t;
	 n = sscanf( t, "%03d%f", &h, &s );
	if ( n == 2 ) 
	 lon = h + s/60.0;
	else
	  nb++;
	break;

	case EW:  
	  lon = ( *t == 'W' ) ? -lon : lon;
	break;

	case ALT:
	  n = sscanf( t, "%f", &alt );
	  if ( n != 1) nb++;
	break;
       }
      }
   if ( nb == 0 ) {
   good++;
   if (good == 1) {
      gga.lon = (float)lon;
      gga.lat = (float)lat;
      }
   if ( abs((int)lon - (int)gga.lon) > 1 ) {
 	printf("------> %8d: %s %02x %02x\n",  line, str, sum, cksum); 
	good--;
	badcnt++;
   } else {
   if ( abs((int)lat - (int)gga.lat) > 1 ) {
 	printf("-----------> %8d: %s %02x %02x\n",  line, str, sum, cksum); 
	good--;
	badcnt++;
   } else {
   gga.sod = (float)sod;
   gga.lat = (float)lat;
   gga.lon = (float)lon;
   gga.alt = (float)alt;
   //printf("--- %8d \n",line);
   fwrite( &gga, sizeof(gga), 1, odf);
   }
   }
/*
if ( line > 152960 )  {
   printf("%7d====%s %s %s %f %f>%s", line,tp, latp, lonp, lat,lon,scp );
}
*/
// printf("\n%f %f %f %f", gga.sod, gga.lat, gga.lon, gga.alt);
     } else {
 	printf("<------>%8d: %s\n",  line, scp); 
	badcnt++;
     }
    }
   }
  fseek( odf, 0, SEEK_SET);
  fwrite( &good, sizeof(int), 1, odf);          // install count
  printf("\n%d total points, %d good points, %d bad points\n", line, good, badcnt);           
}

