/*
  $Id$
*/
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include "eaarl.h"


/************************************************************


6/24/01
  Orginal by
  C. Wayne Wright 6/24/2001 wright@lidar.wff.nasa.gov

Usage:
  ls *.tld | efdb outputfile.bin


 Output file format:

     	XXXX   	32 bit offset to beginning of file name records
     	NNNN   	32 bit number of EAARL_INDEX records
     	ZZZZ   	32 bit number of file names

     	EAARL_INDEX-1    First EAARL_INDEX record.  XXXX points to here
     	EAARL_INDEX-2    Second
     	....             EAARL_INDEX records continue for NNNN records
XXXX-> 	LL   	16 bit filename-1 byte length
     	filename   LL length filename string
       	JJ       16 bit filename-2 byte length
     	filename   JJ length filename string
     	....       filename and length pairs continue for ZZZZ 




************************************************************/

typedef struct {
  unsigned seconds;
  unsigned fseconds;
  unsigned offset;
  unsigned raster_length;
  unsigned short file_number;
  unsigned char  pixels;
  unsigned char  digitizer;
} EAARL_INDEX __attribute__ ((packed)) ;

EAARL_INDEX eaarl_index;


unsigned int XXXX=0, XXXX_LOC = 0;
unsigned int NNNN=0, NNNN_LOC = 4;
unsigned int ZZZZ=0, ZZZZ_LOC = 8;


FILE *ifd;
int run = 1;				// loops until run=0

UI8 raster[ MAX_BYTES_PIXEL * NSEGS * 2 ];	// temp buffer for a raster
struct tl { 
  unsigned len          :       24;     // bytes in this raster
  unsigned type         :        8;     // type id wf=5
};

struct tl tl;				// holds a type/len
struct raster_header lrh, *rh;		// holds a raster header
UI32	offset, pixel_offset;		// fseek offsets

#define MAXSTR	1024

struct {
  char *fn;
  short len;
} nlst[ 1024 ] ;

main(unsigned int argc, char *argv[])
{
 unsigned short si;
 int i,j,k,n;
 int findex = 1;
 unsigned int offset;
 char *p, ifn[ MAXSTR ], odfn[ MAXSTR ], *fnlinked_list=NULL;
 FILE *idf, *odf;
 if ( argc > 1 ) {
   strncpy( odfn, argv[1], MAXSTR );
   if ( (odf = fopen(odfn, "w+" ) ) == NULL ) {
     perror(odfn); 
     exit(1);
   }
   printf("\nGenerating master index to: %s", odfn);
   fwrite( &XXXX, sizeof(XXXX), 1, odf );  // place holder for offset
   fwrite( &NNNN, sizeof(NNNN), 1, odf );  // place holder for record count
   fwrite( &ZZZZ, sizeof(ZZZZ), 1, odf );  // place holder for file name count
 }
  while ( 1)  {
    fgets( ifn, MAXSTR, stdin );
    if ( feof(stdin) ) break;
    p = strchr( ifn, '\n' ); 
    if ( p ) *p = (char)0;
    p = strchr( ifn, '\r' ); 
    if ( p ) *p = (char)0;
    printf("\n           Processing:    %s %d", ifn, findex);
    if ( (idf = fopen( ifn, "r" )) == NULL ) {
      perror(ifn); exit(1); 
    }


      nlst[findex].len = strlen( ifn );
      nlst[findex].fn  = (char *)malloc( nlst[findex].len );
      strncpy( nlst[findex].fn, ifn, nlst[findex].len );		// copy string in
      ZZZZ++;				// add to file name count

    rewind(idf);
    while ( !feof(idf) ) {
      offset = ftell( idf );
      if ( fread( &lrh, sizeof(lrh), 1, idf ) < 1 ) {
        break;
      }
      if ( lrh.len > sizeof( raster ) ) {
        printf("\nFile %s is corrupt.  Aborting\n", ifn );
        break;
      }
      if ( lrh.len == 0 ) {
        printf("\nZero length raster. File %s is corrupt.  Aborting\n", ifn );
        break;
      }
//      fread( &raster, sizeof(char), lrh.len-sizeof(lrh), idf );
      if ( fseek( idf, lrh.len - sizeof(lrh), SEEK_CUR ) != 0 ) {
        perror(ifn); 
        break;
      }
      rh = ( struct raster_header *) &lrh;
      NNNN++;
      eaarl_index.seconds = lrh.seconds;
      eaarl_index.fseconds = lrh.fseconds;
      eaarl_index.offset = offset;
      eaarl_index.raster_length = lrh.len;
      eaarl_index.file_number = findex;
      eaarl_index.pixels = lrh.npixels;
      eaarl_index.digitizer = lrh.digitizer;
      fwrite( &eaarl_index, sizeof(eaarl_index), 1, odf);
/*
      printf("\n%6d %8d %6d %6d %6d %6d %6d %6d %6d", findex, offset, rh->type, 
               rh->len, rh->seconds, rh->fseconds, rh->raster, rh->npixels, 
                                       rh->digitizer );
*/
      if ( (rh->seconds % 10) == 0 ) 
          printf("\r%d megabytes processed", offset/1000000);
    }
    printf("\r%d megabytes processed", offset/1000000);
    fclose(idf);  
    findex++;  
  }
    printf("\n");

// Install filename offset
    XXXX = ftell(odf);
    fseek( odf, XXXX_LOC, SEEK_SET);
    fwrite( &XXXX, sizeof(XXXX), 1, odf);		// write filename offset
    fwrite( &NNNN, sizeof(NNNN), 1, odf);		// write number records
    fwrite( &ZZZZ, sizeof(ZZZZ), 1, odf);		// write filename count

printf("\n%d files", ZZZZ );

// Install filename data at the end of the master index file
    fseek( odf, XXXX, SEEK_SET);
    for ( i = 1; i<= ZZZZ; i++ )  {
//       printf( "\n%d %d %s \n", i, nlst[i].len, nlst[i].fn );
       fwrite( &nlst[i].len, sizeof(short), 1, odf);		// write string length
       fwrite( nlst[i].fn, sizeof(char), nlst[i].len, odf);		// write string 
    }
    printf("\n");
     
}


