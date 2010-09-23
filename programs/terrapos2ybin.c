#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <dirent.h>     // for MAXNAMLEN
#include <unistd.h>     // for access();
 
/*
    terrapos2ybin.c
   
     This program reads the ascii output (IPAS format) of the TerraPOS program
     and converts the time, date, lat,lon, pdop, svs, flag, veast, vnorth,
     vup, and altitude to binary for reading into yorick.
*/

#define MAXSTR  1024 


char *changename( char *ostr, char *nstr, char *txt ) {
  char *pstr;

  strncpy(nstr, ostr, MAXNAMLEN-1); // make a copy

  // if the file doesn't have an extension, we can still pick up
  // (an incorrect) period from the start of the path when using
  // 'find'.
  pstr = strrchr( nstr, '.');       // find the period
  if ( !pstr || pstr == nstr ) {    // no period,
    pstr = nstr;
    while ( *(++pstr) != '\0');     // find the end of the string
  }

  strcpy(pstr, txt);                // append the text
  return(nstr);
}


main( int argc, char *argv[] ) {    
 FILE *idf, *odf;
 float sod;
 int good=0, badcnt=0, line=0;

 float gpsTime, lat, lon, alt;
 int q;
 float sdN, sdE, sdH;
 float vnorth, veast, vup;
 float sdVN, sdVE, sdVUp;
 int sv;
 float pdop;
 float rms=0; //Default value, not present in TerraPOS output
 int flag=1; //Default value, not present in TerraPOS output

 char str[MAXSTR*2], scp[ MAXSTR+2 ];
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

// this reads and discards the commentary at the top.  
// We want to change this to keep the comments,and append them
// to the end of the data
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );
     fgets( str, MAXSTR-4, idf );

   while ( !feof(idf) ) {

// get the string from the file
     fgets( str, MAXSTR-4, idf );
//      printf( "%s", str );
    line++; good++;

  sscanf(str,"%f %f %f %f %d %f %f %f %f %f %f %f %f %f %d %f",
			  &gpsTime,
			  &lat, &lon, &alt,
			  &q,
			  &sdN, &sdE, &sdH,
			  &vnorth, &veast, &vup,
			  &sdVN, &sdVE, &sdVUp,
              &sv, &pdop);

  sod = fmod(gpsTime, 24*60*60);
{
   static struct {
    short svs;
    short flag;
    float sod; 
    float pdop;
    float alt;
    float rms;
    float veast;
    float vnorth;
    float vup;
    double lat;
    double lon;
   } pnav;                                
/*
   printf("%d %4.1f %8.1f %12.8f %12.8f %6.3f %5.3f %7.3f %7.3f %7.3f\n", 
       line, pdop, sod, lat, lon, alt, rms, veast, vnorth, vup);
*/
   pnav.sod    = sod;    pnav.svs = sv;   pnav.pdop = pdop;
   pnav.lat    = lat;    pnav.lon = lon;  pnav.alt  = alt; 
   pnav.rms    = rms;    pnav.flag= flag; pnav.veast=veast;
   pnav.vnorth = vnorth; pnav.vup = vup;
   fwrite( &pnav, sizeof(pnav), 1, odf);
 }
}
  fseek( odf, 0, SEEK_SET);
  fwrite( &good, sizeof(int), 1, odf);          // install count
  printf("\n%d total points, %d good points, %d bad points\n", line, good, badcnt);           
}
