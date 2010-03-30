
/********************************************************************
   dmars2iex.c

   Converts DMARS IMU and system time data into Inertial Explorer
   generic raw format.

   Original: W. Wright 12/21/2003
********************************************************************/

#include "stdio.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include "math.h"
#include <time.h>
#include <dirent.h>     // for changename(argv[1], nfname, ".imr");
#include <stdlib.h>

#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32


  FILE *idf, *odf;

I32 dmars_2_gps;
I32 recs_written = 0;

int seek_offset = 0;

I32 gps_time_offset = 0;

I32 toff = 600;

UI32 time_recs;
UI32 dmars_recs;
UI32 current_rec;

#define SECS_WEEK (86400*7)
double bsow, esow, bsowe=-1;	// beginning seconds of the week
int week_rollover = 0;

typedef struct {
  UI32 secs;
  UI32 usecs;
  UI32 dmars_ticks;
} XTIME;
XTIME  *tarray;

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
  double dVersionNumber     __attribute__ ((packed));
  int    bDeltaTheta        __attribute__ ((packed));
  int    bDeltaVelocity     __attribute__ ((packed));
  double dDataRateHz        __attribute__ ((packed));
  double dGyroScaleFactor   __attribute__ ((packed));
  double dAccelScaleFactor  __attribute__ ((packed));
  int    iUtcOrGpsTime      __attribute__ ((packed));
  int    iRcvTimeOrCorrTime __attribute__ ((packed));
  double dTimeTagBias       __attribute__ ((packed));

  char   Reserved[443];

// For EAARL DMARS Use.
  UI32   nrecs              __attribute__ ((packed));		// number of records;
} IEX_HEADER __attribute__ ((packed));

typedef struct {
  double   sow;
  long gx,gy,gz;
  long ax,ay,az; 
} IEX_RECORD __attribute__ ((packed));


IEX_HEADER hdr;

configure_header_defaults() {
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
  hdr.dTimeTagBias        =  13.0;

// EAARL Specific stuff below
  hdr.nrecs	          =     0; // Gets filled in after pass 1.
}

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


week_rollover_warning() {
  fprintf(stderr,"\
\n********************************************************************\
\n*****  Week Rollover occured!!!  The output will be truncated    ***\
\n*****  to the end of the week so IEX will not become confused    ***\
\n*****  and screwup.                                              ***\
\n********************************************************************\n");
   week_rollover = 1;
}


 time_t * it( double v ) {
 static time_t i;
 i = v;
 return &i;
}

display_header() {
#define MAXSTR 256
 char s[MAXSTR];
 double start_secs, end_secs, day_start_sow;
 start_secs = tarray[0].secs;
 end_secs   = tarray[time_recs-1].secs;
 bsow = fmod(start_secs, SECS_WEEK);
 fprintf(stderr, "bsow = %f\nbsowe = %f\n\n", bsow, bsowe);
 bsow = start_secs - bsowe;
 esow = end_secs - start_secs + bsow;
////  bsowe = (int)(start_secs/SECS_WEEK) * SECS_WEEK;
 fprintf(stderr, "bsow = %f\nesow = %f\nbsowe = %f\nstart_secs = %f, end_secs = %f\n",
     bsow, esow, bsowe, start_secs, end_secs);
 fprintf(stderr,
  "------------------------------------------------------------------\n"
 );
 if ( hdr.bIsIntelOrMotorola ) 
    strcpy(s,"BigEndian");
 else
    strcpy(s,"Intel");
  fprintf(stderr,
  "    Header: %s             Version:%6.3f     Byte Order: %s\n",
      hdr.szHeader,
      hdr.dVersionNumber,
      s
  );
  fprintf(stderr,
  "DeltaTheta:%2d            Delta Velocity:%2d          Data Rate: %3.0fHz \n",
      hdr.bDeltaTheta,
      hdr.bDeltaVelocity,
      hdr.dDataRateHz
  );
  if ( hdr.iUtcOrGpsTime )
     strcpy(s,"GPS");
  else
     strcpy(s,"UTC");
  fprintf(stderr,
  "Gyro Scale: %8.6e    Accel Scale: %8.6e    Time: %s\n",
      hdr.dGyroScaleFactor,
      hdr.dAccelScaleFactor,
      s
  );
  fprintf(stderr,
  " Time Corr: %1d                 Time Bias: %4.3f    Total Recs: %7d\n",
      hdr.iRcvTimeOrCorrTime,
      hdr.dTimeTagBias,
      hdr.nrecs
  );
  {
    char start[MAXSTR], stop[MAXSTR], wk[MAXSTR];
    strftime( start, MAXSTR,"%D %T", gmtime( it(start_secs)));
    strftime(  stop, MAXSTR,"%D %T", gmtime( it(end_secs)));
    strftime(    wk, MAXSTR,"%D %T", gmtime( it(bsowe)));
  fprintf(stderr, "\
 Start SOE: %9.0f          Stop SOE: %9.0f     Bsowe: %9.0f\n\
 Date/Time: %17s            %17s     %17s\n", 
     start_secs, end_secs, bsowe, start, stop, wk
  );
  }
  fprintf(stderr,
  " Start SOW: %9.0f         Stop SOW: %9.0f\n", bsow, esow
  );  

  fprintf(stderr,
  "  Duration: %6.1f/secs (%4.3f/hrs)\n",
       esow-bsow,
       (esow-bsow)/3600.0
  );
  fprintf(stderr,
   "------------------------------------------------------------------\n"
  );

}


/*
   1) Read our dmars file and determine:
      a) Total number of records
      b) Time offset to add to convert dmars to GMT or GPS.
         (Use a record near the end for time offset determination.)
   2) Rewind the input file.
   3) Reread the file and:
      a) Add the time offset to get to GPS
      b) Write the record to the output file.
   4) Repeat 3a,b for all records.

*/


time_rec(FILE *f, int pass) {
  struct timeval tv;
  struct tm *tm;
  int rv=1;
  int sod;
  fread( &tv, sizeof(tv), 1, idf);
  if ( time_recs == 0 ) {
     tarray[0].secs = tv.tv_sec + gps_time_offset ;
 
     if ( tarray[0].secs > 1136073600 )
        hdr.dTimeTagBias        =  14.0;

     if ( tarray[0].secs > 1230699600 )
        hdr.dTimeTagBias        =  15.0;

     tm = gmtime( (time_t *)&tarray[0].secs );
       sod = tarray[0].secs % 86400;
     bsowe = tarray[0].secs - sod - tm->tm_wday*86400;
  }
  switch (pass) {
   case 1:
     tarray[time_recs].secs = tv.tv_sec + gps_time_offset ;
     tarray[time_recs].usecs = tv.tv_usec;

     if  ((((tv.tv_sec + gps_time_offset  ) - bsowe) ) >= (SECS_WEEK-1)) {
	rv =0;
     } else 
        time_recs++;
     break;
   case 2:	// Check for crossing a SOW boundry and stop if found.
     if  ((((tv.tv_sec + gps_time_offset  ) - bsowe) ) >= (SECS_WEEK-1))
	rv =0;
     break;
  }
  return rv;
}

dmars_rec( FILE *f, FILE *odf, int pass) {
 static int cnt = 0;
  UI8 xor, lxor;
  DMARS_DATA dmars;
  IEX_RECORD iex;
  static double osow = 0.0;
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

     if ( osow > iex.sow )
       printf("TIME REVERSAL: %f : %f\n", iex.sow, osow);
     else {
       osow = iex.sow;

if ( cnt++ == 0 )
 fprintf(stderr,"\nFirst dmars sow: %8.3f\n", iex.sow);
     fwrite( &iex, sizeof(iex), 1, odf );
     recs_written++;
     }
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
  int rv=1;
  current_rec = 0;
  fprintf(stderr,"Pass 1...\n");
  tarray = (XTIME *)malloc(86400*sizeof(XTIME));
  while ( (type=fgetc(idf)) != EOF ) {
    switch (type) {
      case 0x7d:  
	  rv=time_rec(f, 1); break;

      case 0x7e: dmars_rec(f, NULL, 1); break;
    }
    if ( rv == 0 ) {
      week_rollover_warning();
      break;
    } 
  }
  hdr.nrecs = dmars_recs;
// Output the header record again
  if (odf) fwrite( &hdr, sizeof(hdr), 1, odf );
}


pass2( FILE *f, FILE *odf ) {
  I32 type;
  int rv=1;
  current_rec = 0;
  fprintf(stderr,"Pass 2...");
  while ( (type=fgetc(idf)) != EOF ) {
    switch (type) {
      case 0x7d:  rv=time_rec(f,2); break;
      case 0x7e: dmars_rec(f,odf,2); break;
    }
    if ( rv == 0 ) {
      week_rollover_warning;
      break;
    }
  } 

}

process_options( int argc, char *argv[] ) {
 extern char *optarg;
 extern int optind, opterr, optopt;
 char nfname[MAXNAMLEN];
 int c, flag=0;
  while ( (c=getopt(argc,argv, "l:Oo:t:T:")) != EOF ) 
   switch (c) {
    case 'O':       //  program will compute the output name
		  flag = 1;
			break;
    case 'o':
      if ( (odf=fopen(optarg,"w+")) == NULL ) {
        fprintf(stderr,"Can't open %s\n", optarg);
        exit(1);
      }
      break;

    case 'l':
      // 2009-04-18:  This option is to skip past the beginning
      // of the file if the flight was started right before
      // the beginning of the week, such as near midnight UTC
      // on a Saturday.  rwm
      sscanf(optarg, "%d", &seek_offset);
      break;

    case 'T':
      if( sscanf(optarg,"%d", &toff ) != 1 ) {
       perror("Invalid backoff time offset.");
       exit(1);
      }
      break;

    case 't':
      if( sscanf(optarg,"%lf", &hdr.dTimeTagBias ) != 1 ) {
       perror("Invalid time offset.");
       exit(1);
      }
      break;

    default:
	perror("Invalid option");
 	exit(1);
  }

  if ( argv[ optind ] == NULL ) {
      fprintf(stderr,"No input file given.\n");
      exit(1);
  } else {
    if (( idf = fopen(argv[optind], "r")) == NULL ) {
      fprintf(stderr,"Can't open %s.\n", argv[optind] );
      exit(1);
    }
    fseek(idf, seek_offset * sizeof(DMARS_DATA), SEEK_SET);
		if ( flag ) {     //  user used -O
			changename(argv[optind], nfname, ".imr");
			if ( (odf=fopen(nfname,"w+")) == NULL ) {
				fprintf(stderr,"Can't open %s\n", nfname);
				exit(1);
			}
		}

  }
}



main( int argc, char *argv[] ) {
  UI32 idx;
  struct tm *tm;
  idf = stdin;
  odf = NULL;

  configure_header_defaults();
  process_options(argc, argv );
  pass1(idf);
  display_header();

// Backup "toff" (option -T)  seconds from the end of the file
// to sync up time with DMARS.
  idx = time_recs - toff;
  fprintf(stderr, "\
  Time Recs: %-5d          DMARS Recs: %-7d\n\
sizeof(hdr): %-5d  sizeof(IEX_RECORD): %-7d\n", 
          time_recs, 
          dmars_recs,
          sizeof(hdr),
          sizeof(IEX_RECORD)
     );
  tm = gmtime( (time_t *)&tarray[idx].secs );
  dmars_2_gps = (tm->tm_wday*86400 +tarray[idx].secs%86400) - 
                tarray[idx].dmars_ticks/200 ;
  { char str[256];
    printf("sow = %d\n", tm->tm_wday*86400);
    strftime(str, 256, "%F Day:%u  %T", tm);
    fprintf(stderr,"%s", str);
  }
  fprintf(stderr,"\nGPS Seconds of the week time offset: %d seconds\n", 
           dmars_2_gps
        );

  if ( odf == NULL ) 
	exit(0);
  rewind(idf);
  fseek(idf, seek_offset * sizeof(DMARS_DATA), SEEK_SET);


// Now output the dmars records
  pass2(idf, odf);
  fprintf(stderr,"\nRecs Written: %d\n", recs_written);
  fclose(odf);
}




