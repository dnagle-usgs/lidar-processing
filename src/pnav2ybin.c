/*
  $Id$
*/

#include <stdio.h>
#include <math.h>
#include <string.h>
 
/*
    pnav2ybin.c          
   
     This program reads the ascii output of the Ashtech ppdif-pnav program
     and converts the time, date, lat,lon, pdop, svs, flag, veast, vnorth,
     vup, and altitude to binary for reading into yorick.

*/

#define MAXSTR  1024 

main( int argc, char *argv[] ) {    
 FILE *idf, *odf;
 float sod, s;
 int h, m, good=0, badcnt=0, line=0;

  char junk[256];
  int mt, dd, yy;
  int hh,mm;
  float ss;
  int sv; 
  float pdop;
  char ns;
  float lat;
  char ew;
  float lon, alt, rms;
  int flag;
  float veast, vnorth, vup;

 char str[MAXSTR*2], scp[ MAXSTR+2 ];
  if ( (idf=fopen( argv[1], "r" ) ) == NULL ) {
    perror(""); exit(1);
  }
  if ( ( odf=fopen(argv[2], "w+")) == NULL ) {
    perror(""); exit(1);
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

   while ( !feof(idf) ) {

// get the string from the file
     fgets( str, MAXSTR-4, idf );
//      printf( "%s", str );
    line++; good++;
  sscanf(str,"%s %d/%d/%d %d:%d:%f %d %f %c %f %c %f %f %f %d %f %f %f",
                     &junk,
                        &mt,&dd,&yy,
                                 &hh,&mm,&ss,&sv,&pdop,
                                                &ns,&lat,
                                                      &ew,&lon,
                                                            &alt,
                                                               &rms,
                                                                  &flag,
                                                                     &veast,&vnorth,
                                                                            &vup); 

  sod = hh*3600 + mm*60 + ss;
  lat = ( toupper(ns) == 'N' ) ?  lat : -lat;
  lon = ( toupper(ew) == 'W' ) ? -lon :  lon;
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

