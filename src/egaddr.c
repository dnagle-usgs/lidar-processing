/*
  $Id$
*/
#include <unistd.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "eaarl.h"

/************************************************************

  Program to generate an index of EAARL waveform data and
files.  

Usage:
 	ega somefile.tld

************************************************************/


FILE *fd, *ofd;

int run = 1;				// loops until run=0

UI8 raster[ MAX_BYTES_PIXEL * NSEGS * 2 ];	// temp buffer for a raster
struct tl { 
  unsigned len          :       24;     // bytes in this raster
  unsigned type         :        8;     // type id wf=5
};

struct tl tl;				// holds a type/len
struct raster_header rh;		// holds a raster header
UI32	offset, pixel_offset;		// fseek offsets

static  struct {
   unsigned long pulse;
   unsigned long offset;
  } stuff = {  0, 0 };

main(unsigned int argc, char *argv[])
{
 int i,j,k,n;
  if ( argc == 3 ) {
       fd = fopen(argv[1], "r");
      ofd = fopen( argv[2], "w+" );
  } 
  if ( (fd == NULL) || ( ofd == NULL ) ) {
	printf("\nCan't open %s\nUsage: ega somefile.tld somefile.idx\n\n", argv[1]);
	exit(1);
  }


// save space for a 32bit word at the beginning for the pulse count
// yorick will read this and then setup an array to hold the data.
  fwrite( &offset, sizeof(long int), 1, ofd ); 

  while ( run ) {
    n=fread( &tl, 1, sizeof(UI32), fd);
    switch (tl.type ) {
     case 5:	
	type5();	break;
    }
  }

  fseek( ofd, 0, SEEK_SET);	// go back to beginning 
  fwrite( &stuff.pulse, sizeof(stuff.pulse), 1, ofd);
  fprintf(stderr,"\n%d pixels processed. File: %s written\n", 
	stuff.pulse, argv[2]);
  fclose(ofd);
}

// This function will process a type5 EAARL record and 
// printout all the parts.
type5() {
 int i,j,k,n, ii, jj;
 static nrast = 0;
 struct pixel pixel, *pp;
 UI8 blen;
 UI16 len;
    nrast++;
    fseek( fd, offset, SEEK_SET);		// seek to start of this rec
    n=fread( &rh, 1, sizeof(struct raster_header), fd);	// read it in
    if ( n != sizeof(struct raster_header) ) {	// check size
	run = 0;				// if not the same, quit
    } else {					// print out raster data
    rh.npixels = 119;
    for (k=0; k<rh.npixels; k++ ) {		// get & print all wf data
//    printf("\n%lu %lu", nrast*200+k, ftell( fd ));
{
    stuff.offset = ftell(fd);
    stuff.pulse++;
    fwrite( &stuff, sizeof(stuff), 1, ofd);
    fseek( fd, sizeof(struct pixel), SEEK_CUR ); 
}
    fread( &blen, 1, sizeof(UI8), fd);		// get len of tx wf
    fseek( fd, blen, SEEK_CUR);			// read transmit wf
    for (j=0; j<4; j++ ) {
      fread( &len, 1, sizeof(UI16), fd);	// get wf0 len
      fseek( fd, len, SEEK_CUR);		// read rx0 waveform
     }
    }
     
     offset += rh.len;			// skip to next raster
     fseek( fd, offset, SEEK_SET);
    }
}

