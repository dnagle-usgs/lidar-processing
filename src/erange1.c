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
    $Id$

6-20-02 
  modified to output ascii with correct argv parameters.  amar nayegandhi.
6-27-01
  modified to output binary

3/12/01
  C. Wayne Wright 12/11/2000 wright@lidar.wff.nasa.gov

  Simple program to read "raw" EAARL data files and print
contents to the stdout.  *** LINUX X86 ONLY ***  This program 
will only work on Linux or other X86 platform with little 
endian data representation. 

Usage:
 	erange somefile

************************************************************/


FILE *fd, *odf;

int run = 1;				// loops until run=0

UI8 raster[ MAX_BYTES_PIXEL * NSEGS * 2 ];	// temp buffer for a raster
struct tl { 
  unsigned len          :       24;     // bytes in this raster
  unsigned type         :        8;     // type id wf=5
};

struct tl tl;				// holds a type/len
struct raster_header rh;		// holds a raster header
UI32	offset, pixel_offset;		// fseek offsets

main(unsigned int argc, char *argv[])
{
 int i,j,k,n;
  if (argc == 1) 
	  printf("No files to open.  Usage erange somefile.tld \n");
  if ( argc == 2 ) { 
	fd = fopen(argv[1], "r");
    if ( fd == NULL ) {
	printf("\nCan't open %s\nUsage: erange somefile.tld\n\n", argv[1]);
	exit(1);
    }
  }

  if ( argc == 3 ) {
	odf = fopen( argv[2], "w+");
  if ( odf == NULL ) { 
	printf("\nCan't open %s\nUsage: erange somefile.tld someoutput.erange1\n\n", argv[1]);
	exit(1);
    }
  }



  while ( run ) {
    n=fread( &tl, 1, sizeof(UI32), fd);
    switch (tl.type ) {
     case 5:	
	type5();	break;
    }
  }

  printf("\n");
}

float centroid( I16 *a, UI16 len, int *minv )  ;

// This function will process a type5 EAARL record and 
// printout all the parts.
type5() {
 int i,j,k,n, ii, jj;
 static nrast = 0, pulse_number=0;
 struct pixel pixel, *pp;
 UI8 txdata[128], data [4] [4096];
 I16 itxd[128], txbias;
 I16 idata [4] [4096], idatabias[4];
 UI8 blen;
 UI16 len;
 float ct, cr0, cr1, cr2, cr3;
 double  seconds;
 int  txmax, max0, max1, max2, max3;
    nrast++;
    fseek( fd, offset, SEEK_SET);		// seek to start of this rec
    n=fread( &rh, 1, sizeof(struct raster_header), fd);	// read it in
    if ( n != sizeof(struct raster_header) ) {	// check size
	run = 0;				// if not the same, quit
    } else {					// print out raster data
     seconds = rh.seconds + rh.fseconds * 1.6e-6;
/////     printf("\n\ntype=%3d %7d secs=%8x fsecs=%8x sod=%15.6f ras=%7d npix=%3d dig=%d", 
///	rh.type, rh.len, 
///	rh.seconds, rh.fseconds, seconds, rh.raster, rh.npixels, rh.digitizer); 
    for (k=0; k<rh.npixels; k++ ) {			// get & print all wf data
    pulse_number++;
    pp =  (struct pixel *) ftell( fd );
    fread( &pixel, 1, sizeof(struct pixel), fd); // get pixel struct
    fread( &blen, 1, sizeof(UI8), fd);		// len of tx wf
    fread( &txdata, 1, blen, fd);		// read transmit wf
    for (j=0; j<4; j++ ) {
      fread( &len, 1, sizeof(UI16), fd);	// get wf0 len
      fread( &data[j][0], 1, len, fd);		// read rx0 waveform
    }
////////    printf("\n\nk=%3x %7x %3x %3x %5x %5x %5x %3x", 
//	   k,
//	   pixel.offset_time, pixel.nwaveforms, pixel.txbias, 
//         pixel.scan_angle, pixel.wf_offset, pixel.len, blen );
/////    printf("\ntxwf[%d]", blen);
    txbias = ( ~pixel.txbias & 0xff );
    for (i=0; i<blen; i++ ) {
	itxd[i] = ((I16)(~txdata[i] &0xff) - txbias );
//	printf(" %3d", itxd[i] );
    }
    for (j=0; j<4; j++ ) {
      idatabias[j] = (I16)(~pixel.rxbias[j]&0xff);
///////      printf("\nrxwf%d[%3d](%3d) \nwf%d ", j, len, idatabias[j], j);
      for (i=0; i<len; i++ ) {
	idata[j][i] = (I16)(~data[j][i]&0xff) - idatabias[j];
//        printf("%d ", idata[j][i]);
      }
    }
     
    ct = centroid( itxd, blen, &txmax );
    cr0 = centroid( &idata[0][0], 20, &max0);
    cr1 = centroid( &idata[1][0], 20, &max1);
    cr2 = centroid( &idata[2][0], 20, &max2);
    cr3 = centroid( &idata[3][0], 20, &max3);
/////   if ( pixel.wf_offset < 5000 ) 

printf("%f %d %10.2f %d\n", 
   seconds + pixel.offset_time * 1.6e-6,
   pixel.scan_angle,
   (float)(pixel.wf_offset&0x3fff) - ct + cr0,
   max0
);
/*
    printf("\n %6d %8d %15.6f %8d %8d %4d %6d %8.3f %3d %5.3f %3d %8.3f %3d %8.3f %3d %8.3f %3d %c%c", 
		nrast,
		pp,
		seconds + pixel.offset_time * 1.6e-6,
		pulse_number,
		pixel.offset_time,
		pixel.scan_angle,
		pixel.wf_offset,
		ct, txmax,
	        (float)(pixel.wf_offset&0x3fff) - ct + cr0 , max0,
		(float)(pixel.wf_offset&0x3fff) - ct + cr1 , max1,
		(float)(pixel.wf_offset&0x3fff) - ct + cr2 , max2,
		(float)(pixel.wf_offset&0x3fff) - ct + cr3 , max3,
		(pixel.wf_offset&0x8000) ? ' ' : ' ',
		(pixel.wf_offset&0x4000) ? ' ' : ' '
		);
*/
    for (j=0; j<4; j++ ) {
////////      printf("\nrx%d[%3d](%3d) %d", j,len, pixel.rxbias[j], k);
      for (i=0; i<len; i++ )
//	printf(" %4d", data[j][i] - pixel.rxbias[j] );
	;
     } 
    }
     offset += rh.len;			// skip to next raster
     fseek( fd, offset, SEEK_SET);
    }
}


typedef struct CDAT {
  UI16 nsat; 		// number of saturated pixels
  UI16 max;		// maximum value 
  UI16 min;		// minimum value 
  UI16 total;		// total integrated power
} CDAT;

float centroid( I16 *a, UI16 len, int *minv )  {
 int v, i,j, mnx;
 float sum, mom, cent;
 int mn;
 for (mnx=0, mn=0, sum=0.0, mom=0.0, i=0; i<len; i++ ) {
   v = a[i];
   sum += v;
   mom += ( v * (float)i );
   if ( v >= mn ) {
      mn = v; mnx = i;
   }
 }
 if ( sum != 0.0 ) cent = mom / sum;
 //      printf("\ncent = %3d %5d %f", mn, mnx,  cent );
 if ( minv != NULL ) *minv = mn;
 return cent;
}

