
/*
   $Id$

   dmars2iex.c

   Converts DMARS IMU and system time data into Inertial Explorer
   generic raw format.

   Original: W. Wright 12/21/2003


*/

#include "stdio.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <string.h>
#include "math.h"
#include <time.h>

#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32


  FILE *idf, *odf;

I32 dmars_2_gps;
I32 recs_written = 0;

I32 gps_time_offset = -2;



/*******************************************************
   The basic payload data from the DMARS.  This plus the
   header byte, 0x7e, are  the only parts that are
   checksumed.
*******************************************************/
typedef struct {
  UI32 tspo;            // Ticks since power on;
  UI8  status;
  I16 sensor[6];
}  __attribute__ ((packed)) DMARS_DATA;
                                                                                                      



typedef struct  {
  char   szHeader[8];
  char   bIsIntelOrMotorola;
  double dVersionNumber;
  int    bDeltaTheta;
  int    bDeltaVelocity;
  double dDataRateHz;
  double dGyroScaleFactor;
  double dAccelScaleFactor;
  int    iUtcOrGpsTime;
  int    iRcvTimeOrCorrTime;
  int    dTimeTagBias;

// For EAARL DMARS Use.
  UI32   nrecs;		// number of records;
  char   Reserved[443];
} IEX_HEADER __attribute__ ((packed));

typedef struct {
  double   sow;
  long gx,gy,gz;
  long ax,ay,az; 
} IEX_RECORD __attribute__ ((packed));


IEX_HEADER hdr;

configure_header() {
  strcpy(hdr.szHeader, "$IMURAW");
  hdr.bIsIntelOrMotorola  =     0;
  hdr.dVersionNumber      =   2.0;
  hdr.bDeltaTheta         =     0;
  hdr.bDeltaVelocity      =     0;
  hdr.dDataRateHz         = 200.0;
  hdr.dGyroScaleFactor    =  90.0/(pow(2.0,15.0));
  hdr.dAccelScaleFactor   =  19.6/(pow(2.0,15.0));
  hdr.iUtcOrGpsTime       =     2;
  hdr.iRcvTimeOrCorrTime  =     2;
  hdr.dTimeTagBias        =   0.0;

// EAARL Specific stuff below
  hdr.nrecs	          =     0; // Gets filled in after pass 1.
}


/*
   1) Read our dmars file and determine:
      a) Total number of records
      b) Time offset to add to convert dmars to GMT.
         (Use a record near the end for time offset determination.)
   2) Rewind the input file.
   3) Reread the file and:
      a) Add the time offset to get to GPS
      b) Write the record to the output file.
   4) Repeat 3a,b for all records.

*/

UI32 time_recs;
UI32 dmars_recs;
UI32 current_rec;

typedef struct {
  UI32 secs;
  UI32 usecs;
  UI32 dmars_ticks;
} XTIME;
XTIME  *tarray;

time_rec(FILE *f, int pass) {
  struct timeval tv;
  fread( &tv, sizeof(tv), 1, idf);
  switch (pass) {
   case 1:
     tarray[time_recs].secs = tv.tv_sec + gps_time_offset;
     tarray[time_recs].usecs = tv.tv_usec;
     time_recs++;
     break;
   case 2:	// Just skip the time data in pass 2.
     break;
  }
}

dmars_rec( FILE *f, FILE *odf, int pass) {
 static int cnt = 0;
  UI8 xor, lxor;
  DMARS_DATA dmars;
  IEX_RECORD iex;
  fread( &dmars, sizeof(dmars), 1, idf);
  lxor = fgetc(idf);		// read the xor byte
  switch ( pass ) {
   case 1:
    dmars_recs++;
    tarray[time_recs].dmars_ticks = dmars.tspo;
    if ( (++current_rec % 10000) == 0 ) 
       fprintf(stderr,"Processing rec: %6d   \r", 
         current_rec
       );
    break;

   case 2:
#define GX 0
#define GY 1
#define GZ 2
#define AX 3
#define AY 4
#define AZ 5
     iex.gy =  dmars.sensor[  GX ];   
     iex.gx = -dmars.sensor[  GY ];   
     iex.gz =  dmars.sensor[  GZ ];   
     iex.ay =  dmars.sensor[  AX ];   
     iex.ax = -dmars.sensor[  AY ];   
     iex.az =  dmars.sensor[  AZ ];   
     iex.sow = (dmars.tspo/200.0 + dmars_2_gps) ;
if ( cnt++ == 0 )
 fprintf(stderr,"\nFirst dmars sow: %8.3f\n", iex.sow);
     fwrite( &iex, sizeof(iex), 1, odf );
     recs_written++;
    if ( (++current_rec % 10000) == 0 ) 
       fprintf(stderr,"Processing: %6d of %6d %2.0f%% complete \r", 
         current_rec, 
         dmars_recs, 
         100.0*(float)current_rec/(float)dmars_recs 
       );
    break;
  }
}

pass1( FILE *f ) {
  I32 type;
  current_rec = 0;
  fprintf(stderr,"Pass 1...\n");
  tarray = (XTIME *)malloc(86400*sizeof(XTIME));
  while ( (type=fgetc(idf)) != EOF ) {
    switch (type) {
      case 0x7d:  time_rec(f, 1); break;
      case 0x7e: dmars_rec(f, NULL, 1); break;
    }
  } 
  hdr.nrecs = dmars_recs;
  rewind(f);
// Output the header record again
  fwrite( &hdr, sizeof(hdr), 1, odf );
}


pass2( FILE *f, FILE *odf ) {
  I32 type;
  current_rec = 0;
  fprintf(stderr,"Pass 2...");
  while ( (type=fgetc(idf)) != EOF ) {
    switch (type) {
      case 0x7d:  time_rec(f,2); break;
      case 0x7e: dmars_rec(f,odf,2); break;
    }
  } 

}

process_options( int argc, char *argv[] ) {
 extern char *optarg;
 extern int optind, opterr, optopt;
 int c;
  while ( (c=getopt(argc,argv, "o:t:")) != EOF ) 
   switch (c) {
    case 'o':
      if ( (odf=fopen(optarg,"w+")) == NULL ) {
        fprintf(stderr,"Can't open %s\n", optarg);
        exit(1);
      }
      break;

    case 't':
      break;
  }

  if ( argv[ optind ] == NULL ) {
    fprintf(stderr,"No input file given.\n");
    exit(1);
  } else {
    if (( idf = fopen(argv[optind], "r")) == NULL ) {
      fprintf(stderr,"Can't open %s.\n", argv[optind] );
      exit(1);
    }
  }
}



main( int argc, char *argv[] ) {
  UI32 idx;
  struct tm *tm;
 idf = stdin;
 odf = stdout;
  process_options(argc, argv );
  configure_header();
  pass1(idf);

// Backup 10 minutes from the end of the file
// to sync up time with DMARS.
  idx = time_recs-600;
  fprintf(stderr,"\n%d Time recs, %d DMARS recs %d, sizeof(hdr)=%d sizeof(IEX_RECORD)=%d, gscale=%f ascale=%f\n", 
          tarray, 
          time_recs, 
          dmars_recs,
	  sizeof(hdr),
          sizeof(IEX_RECORD),
          hdr.dGyroScaleFactor,
          hdr.dAccelScaleFactor
         );
  tm = gmtime( (time_t *)&tarray[idx].secs );
  dmars_2_gps = (tm->tm_wday*86400 +tarray[idx].secs%86400) - 
                tarray[idx].dmars_ticks/200 ;
  { char str[256];
    strftime(str, 256, "%F Day:%u  %T", tm);
    fprintf(stderr,"%s", str);
  }
  fprintf(stderr,"\nOffset: %d %6.6f %6.6f %d %d\n", 
           tarray[idx].secs, 
           1.0e-6*tarray[idx].usecs,
           tarray[idx].dmars_ticks/200.0, 
           dmars_2_gps,
	   idx
        );

  rewind(idf);

// Output the header record
  fwrite( &hdr, sizeof(hdr), 1, odf );


// Now output the dmars records
  pass2(idf, odf);
  fprintf(stderr,"\nRecs Written: %d\n", recs_written);
  fclose(odf);
}



