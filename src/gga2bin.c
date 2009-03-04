/*********************************************************************
  $Id$
*********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <dirent.h>     // for MAXNAMLEN
#include <unistd.h>     // for access()

/*********************************************************************
    gga2bin.c          
   
     This program reads a nmea gpgga string, verifies it's checksum,
     and converts the time, lat,lon, and altitude to binary for reading
     into yorick.

*********************************************************************/

#define MAXSTR  1024 
static struct {
  float sod, lat, lon, alt;
 } gga;                                

 int 
   total_gga=0,
   good_gga=0, 
    bad_gga=0, 
   total_temp=0,
    line=0;
 FILE *idf, *odf;

/*********************************************************************
*********************************************************************/
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

/*********************************************************************
  If string *t is at the beginning of string *s, then return 1
  else 0.
*********************************************************************/
is ( char *s, char *t ) {
  if ( strncmp(s,t,strlen(t)) == 0 )
	return 1;
  else 
	return 0;
}

 int nb;
/*********************************************************************
  Decode gpgga messages
*********************************************************************/
gpgga(char *str) {
 int n;
 int h,m;
 int cksum, sum, i;
 char scp[MAXSTR+2], *p, *t, *latp, *lonp, *tp;
 char  comma[]=",";
 float sod, lat, lon, alt, s;

   total_gga++;

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
// 	printf("xx %8d: %s %02x %02x\n",  line, str, sum, cksum); 
	bad_gga++;
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
	if ( n == 2 )  {
	 lat = h + s/60.0;
        }
	else
	 nb++;
	break;

	case NS:  
	  lat = ( *t == 'S' ) ? -lat : lat;
	break;

       case LON:
         lonp = t;
	 n = sscanf( t, "%03d%f", &h, &s );
	if ( n == 2 ) {
	 lon = h + s/60.0;
        }
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
   good_gga++;
   if (good_gga == 1) {
      gga.lon = (float)lon;
      gga.lat = (float)lat;
      }
   if ( abs((int)lon - (int)gga.lon) > 1 ) {
	good_gga--;
	bad_gga++;
   } else {
   if ( abs((int)lat - (int)gga.lat) > 1 ) {
	good_gga--;
	bad_gga++;
   } else {
   gga.sod = (float)sod;
   gga.lat = (float)lat;
   gga.lon = (float)lon;
   gga.alt = (float)alt;
   fwrite( &gga, sizeof(gga), 1, odf);
    }
   }
     } else {
	bad_gga++;
     }
    }
}

/*********************************************************************
*********************************************************************/
temperature(str) {
  total_temp++;
}


/*********************************************************************
*********************************************************************/
main( int argc, char *argv[] ) {    
 int nb;
 int h, m, n;
 char str[MAXSTR*2], scp[ MAXSTR+2 ];
  if ( (idf=fopen( argv[1], "r" ) ) == NULL ) {
    perror(""); exit(1);
  }

  if ( argc == 2 ) {  // generate and open the output file
    char *pfname, nfname[MAXNAMLEN];
    changename(argv[1], nfname, ".ybin");
    fprintf(stderr, "creating output file: %s\n", nfname);
    if ( ( odf=fopen(nfname, "w+")) == NULL ) {
        perror(""); exit(1);
    }
  } else {    // open the file given on the cmdline

    if ( ( odf=fopen(argv[2], "w+")) == NULL ) {
      perror(""); exit(1);
    }                                                      
  }
  

// write placeholder for the number of records.  We'll reposition to
// this after we know how many elements there are.
    fwrite( &good_gga, sizeof(int), 1, odf);                          

   while ( 1 ) {
  memset( str, 0, MAXSTR ); 		// clear the string before use
     fgets( str, MAXSTR-4, idf ); 	// get a nmea string
     if (feof(idf)) 
	     break;
    line++;

    if      ( is(str, "GPGGA") )             gpgga( str );
    if      ( is(str, "$GPGGA") )            gpgga( str );
    else if ( is(str, "PASHR,TMP,") )  temperature( str );
    else ;
  }
  fseek( odf, 0, SEEK_SET);
  fwrite( &good_gga, sizeof(int), 1, odf);          // install count
  printf("\n%d total points", line);
  printf("\n        Good    Bad");
  printf("\n GGA: %6d %6d", good_gga, bad_gga);           
  printf("\nTemp: %6d %6d", total_temp, 0);           
  printf("\n");
}

