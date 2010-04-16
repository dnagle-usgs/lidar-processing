#include "stdio.h"
#include "math.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <assert.h>
#include <string.h>
#include <math.h>
#include <ncurses.h>

#define G 9.80665
                                                                                                      
#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32



FILE *f;

typedef struct {
   struct timeval tv;
} __attribute__ ((packed)) NTPSOE;
 

typedef struct {
  UI32 tspo;            // Ticks since power on;
  UI8  status;
  I16 sensor[6];
  UI8 cksum;
}  __attribute__ ((packed)) DMARS_DATA;

DMARS_DATA raw_dmars;
NTPSOE ntpsoe;


unsigned int tcount, dcount, count;
double start, stop, et;

main( int argc, char *argv[]) {
 unsigned char t;
 int last_time;
 unsigned long int offset;
  f = stdin;
  if ( (f = fopen( argv[1], "r")) == NULL ) {
    printf("Usage is:   rdmars inputfile\n");
    return -1;
  }
  while ( !feof(f) ) {
    offset = ftell(f);
    t = fgetc( f );
    switch (t) {
     case 0x7d:
       fread( &ntpsoe, sizeof(ntpsoe), 1, f);
       if ( tcount == 0 ) 
	start = ntpsoe.tv.tv_sec + ntpsoe.tv.tv_usec*1.0e-6;;
       tcount++;
       break;

     case 0x7e:
       fread( &raw_dmars, sizeof(raw_dmars), 1, f);
       dcount++;
       if ( (raw_dmars.tspo - last_time) > 1 ) {
         printf("\nGap detected: offset=0x%08lx tspo=0x%08x %8.3f %6.3f", offset, raw_dmars.tspo,
           raw_dmars.tspo/200.0, (raw_dmars.tspo - last_time)/200.0);
       }
       last_time = raw_dmars.tspo;
       break;
    }
  }
  stop = ntpsoe.tv.tv_sec + ntpsoe.tv.tv_usec*1.0e-6;;
  et = stop - start;
  printf("\nTime recs:%d Dmars recs:%d Et:%8.4f %6.3fhrs\n", tcount, dcount, et, et/3600.0 );

}




