#ifndef EAARL_H
#define EAARL_H

#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32
#define I64  long long
#define UI64 unsigned I64

#define NSEGS   	120     // number of segments to capture
#define TXWF_SIZE	10
#define RXWF_MAX_SIZE	250
#define MAX_WF_LEN	RXWF_MAX_SIZE	// maximum length of recorded waveform


#define RASTER_QUEUE_VERSION 	1000
#define NBUFS   		512
#define MAX_BYTES_PIXEL 	1800

#define DATA_IDLE	0
#define DATA_BEGIN	1
#define DATA_ON		2
#define DATA_STOP	3

// These are added to the range offset data to warn that the sample 
// did not cross either the transmit or receive threshold
#define INVALID_TXWF	0x4000	// When tx waveform doesnt cross threshold 
#define INVALID_RXWF	0x8000	// When rx waveform doesnt cross threshold

/************************************************************

  This structure describes the rasters queue as it is held
  in "mbuff" shared memory.  It is nominally on the order
  of 100mb.
  The pwb index are as follows:
   pwb [ a ] [ b ] [ c ]
  where a is:
    	0	offset to pixel structure
	1	offset to tx wf
	2	offset to rxwf0
	3	offset to rxwf1
	4	offset to rxwf2
	5	offset to rxwf3
  b is the index to the circular queue
  c is the pixel number index.  Be sure and add your pointer
  to the base of eaarl_raster_queue to each offset to form a 
  point to the data.  This is necessary to access things from 
  different processes which use different virtual addresses
  to point to this shared space.
************************************************************/
struct eaarl_raster_queue {
 int version;           	// version of this data structure
 UI32 raster;			// the raster counter
 int iidx;              	// data input index
 int oidx;              	// data output index
 UI8 run;			// system run flag
 UI8 rec_flag;			// record control flag
 UI8 status[ NBUFS ];		// buffer status, 0 empty 1=filling
 int bsz[ NBUFS ];      	// actual size of each buffer
 void * pwb[ 6 ] [ NBUFS ] [ NSEGS ];  // matrix of offsets to waveforms
 unsigned char bfr [ NBUFS ] [ MAX_BYTES_PIXEL  * 120 ]; // 110 megabytes
};

struct raster_header {
  unsigned len		:	24;	// bytes in this raster
  unsigned type 	: 	 8;	// type id wf=5
  UI32     seconds;			// seconds since 1970
  UI32 	  fseconds;			// fractional seconds 1.6us lsb
  UI32      raster;			// raster number
  UI16	   npixels	:	15;	// number of pixels in this raster
  UI16   digitizer	:	 1;	// digitizer 
} __attribute__ ((packed)) ;

struct pixel {
///////  UI16 	    spectra[46];		// passive spectra
  unsigned  offset_time	:	24;	// lsb=200e-9
  unsigned  nwaveforms	:	 8;	// number of waveforms in this sample
  UI8	    txbias;			// the transmit bias
  UI8	    rxbias[4];	
  I16	    scan_angle;			// scan angle counts
  UI16	    wf_offset;			// offset to first point (irange)
  UI16      len;			// length of following data
} __attribute__ ((packed)) ;


/*
   See /proc/cpuinfo for clock speed.  This macro from :
.- M A I A -------------------------------------------------.
|      Multimedia Application Integration Architecture      |
| A Free/Open Source Plugin API for Professional Multimedia |
`----------------------> http://www.linuxaudiodev.com/maia -'
.- David Olofson -------------------------------------------.
| Audio Hacker - Open Source Advocate - Singer - Songwriter |
`--------------------------------------> david@linuxdj.com -'

 post to the rtlinux list.
 static __inline__ unsigned long long int rdtsc(void)
 the above works as well.


*/

extern __inline__ unsigned long long int rdtsc(void)
{
        unsigned long long int x;
        __asm__ volatile (".byte 0x0f, 0x31" : "=A" (x));
        return x;
}

#endif


