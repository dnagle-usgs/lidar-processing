
/******************************************************************* 
    $Id$

  fixdmars.c: 
   Based on dmarsd.c and dmars2iex.c.  
   This program is used to read the "cat" files captured on dmars145 
   and transform it to a *.imu" file that iex can read.

  Original: W. Wright 4/7/2004

  Options:
     -d input device or file
     -t Time offset in SOE, sod, or sow
     -O Uncompressed data file name.
     -P Printout every 200th converted values on stdout.
     -p Printout all converted values on stdout.

*******************************************************************/


#include "stdio.h"
#include "math.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <assert.h>
#include <string.h>
#include "dmars.h"

#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32


#define INP_BUFFER_SIZE 256*1024
#define ODF_BUFFER_SIZE 16*1024

#define DATALOGR_SCHED SCHED_FIFO


// The sp pointer will be set to point into shared memory.
extern char *optarg;

// THe value to add to the IMU data to get in sync with the gps.
unsigned long int time_offset = 0 ;


// Declare the data and set the header values
DMARS     raw = { 0x7e } ; 
NTPSOE ntpsoe = { 0x7d };

/*******************************************************
   The basic payload data from the DMARS.  This plus the
   header byte, 0x7e, are  the only parts that are
   checksumed.
*******************************************************/

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
  UI32   nrecs              __attribute__ ((packed));           // number of records;
} IEX_HEADER __attribute__ ((packed));

typedef struct {
  double   sow;
  long gx,gy,gz;
  long ax,ay,az;
} IEX_RECORD __attribute__ ((packed));

IEX_RECORD iex;
IEX_HEADER hdr;

// bsow beginning seconds of the week
 double bsow, esow;


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
  hdr.nrecs               =     0; // Gets filled in after pass 1.
}


display_header() {
#define MAXSTR 256
 char s[MAXSTR];
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
  fprintf(stderr,
  " Start SOW: %9.3f          Stop SOW: %9.3f\n", bsow, esow
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








FILE *odf = NULL;
FILE *devfd = NULL;
FILE *dmars_log = NULL;

char default_gzip = 0;		// 1 for gzip, 0 for normal file
char is_a_device = 0;
char  print= ' ';		// print flag
char   tag = ' ';
char inp_buffer[ INP_BUFFER_SIZE ];
char odf_buffer[ ODF_BUFFER_SIZE ];


int shmid;
UI32 timer = 0L;
UI32  sum; 

STATS stats, *sp;




/**********************************************
//
**********************************************/
verify_fn( char *fn, char *str ) {
          strncpy (fn, str, MAXLEN);
          if ((odf = fopen (fn, "r")))
            {
              printf ("\nThe file \"%s\" exists.  I don\'t overwrite files!\n",
                      fn);
              exit (1);
            }
}

/**********************************************
//
**********************************************/
select_device( char *devfn ) {
  char str[ MAXLEN ];
  struct stat sbuf;
  int i;
  strncpy (devfn, optarg, MAXLEN);

  if ((devfd = fopen (devfn, "r")) == NULL) {
      perror ("");
      exit (1);
  }

  setbuffer( devfd, inp_buffer, INP_BUFFER_SIZE);

}

/**********************************************
//
**********************************************/
fail( char *s ) {
  puts(s);
  exit(1);
}


/**********************************************
//
**********************************************/
print_packet( ) {
     printf("\n %6d %6d %c %6.3f %2x %6d %6d %6d %6d %6d %6d %02x:%02x", 
	raw.data.tspo, 
        sp->dtis,
        tag,
        raw.data.tspo * 5.0e-3,
	raw.data.status, 
	raw.data.sensor[XG], 
	raw.data.sensor[YG], 
	raw.data.sensor[ZG], 
	raw.data.sensor[XA], 
	raw.data.sensor[YA], 
	raw.data.sensor[ZA],
        raw.xor,
        sum
     );  
}


/**********************************************
//
**********************************************/
update_minmax( MINMAX *p, I16 v ) {
  if ( v < p->min ) p->min = v;
  if ( v > p->max ) p->max = v;
}

at_eof( FILE *dev) {
  if ( is_a_device ) 
     return 0;

 if ( feof( dev ) ) 
      return 1;
  else 
      return 0;
}

#define IQSZ 256
static int ii=0;
static int oi=0;
char q[ IQSZ ];
/**********************************************
  Code to Queue input data so we can revert
  to it should the checksum be in error.
**********************************************/
qfgetc( FILE *f ) {
 int c;
  if ( ii == oi ) {
    c = fgetc( f );
    q[ ii++ ] = c;
    oi++;
    ii &= 0xff;
    oi &= 0xff;
  }  else {
    c = q[ oi++];
    oi &= 0xff;
  }
  return c;
}



/**********************************************
//
**********************************************/
main( int argc, char *argv[] ) {
  UI8 c, *p;
  int i ;
  int n = 1;
  int opt;
  int secs = 0, lgt;
  double dmars_soe, ntp_soe;
  time_t t;
  I32 accu[6];

  
  devfd = stdin;		// read from stdin by default
  sp = &stats;



/************************************
// Determine option settings.
************************************/
  while (( opt=getopt(argc,argv, "d:O:pPt:")) != EOF ) {
   switch (opt) {
     case 'd':
          select_device( sp->devfn );
          break;

     case 'O':
//          verify_fn( sp->odfn, optarg);
	  strncpy( sp->odfn, optarg, MAXLEN );
          if ((odf = fopen (sp->odfn, "w+")) == NULL)
            {
              perror ("");
              exit (1);
            }

          // use our own larger buffer.
          setbuffer( odf, odf_buffer, ODF_BUFFER_SIZE ); 
          break;

     case 'p':
        print = 'p';
      break;

     case 'P':
        print = 'P';
      break;

     case 't':
       if ( sscanf( optarg, "%d", &time_offset ) == 0 )
         fail("Invalid time_offset value.");
      break;

     default:
	printf("\nUsage: ");
	printf("\ndmarscat2iex -t N -d infile -O outfile\n");
        exit(1);
   }
  }

/************************************
  If the user didn't specify an
 output file, then create a name
 and setup a pipe thru gzip.
*************************************/
  if (   odf == NULL ) {
    char str[MAXLEN];
     strcpy(str, sp->odfn);
     if ((odf = fopen (str, "w")) == NULL) {
        perror ("");
        exit (1);
     }
  }

  if ( devfd == NULL ) fail("\nNo input device/file specified\n");
  if ( devfd == stdin) printf("\nReading data from stdin\n");

  configure_header_defaults();


// Output the header record again
  fwrite( &hdr, sizeof(hdr), 1, odf );

  

/***********************************************
   Main loop begins here
************************************************/
   sp->run = 1;
   sp->record_cnt = 0;
   sp->bad_checksums = 0;
   sp->bytes_written = 0;
   sp->dtis = 0;

   while ( sp->run ) {
     if ( at_eof( devfd ) ) {
	sp->run = 0;
	break;
     }
	

/************************************
 Find the header byte (0x7e).
************************************/
     while ( (c=qfgetc( devfd )) != 0x7e )
          if ( at_eof(devfd)) break;

   sp->record_cnt++;

  { char *p;
     p = (char *)&raw.data;
     for (i=0; i<sizeof(raw.data); i++ )
         p[i] = qfgetc(devfd);
  }
     raw.xor = qfgetc(devfd);
     p = (unsigned char *) &raw.data;


/************************************
 Compute the xor checksum for the 
 packet.
************************************/
     for ( sum=0x7e, i=0; i<sizeof(raw.data); i++ ) sum ^= p[i];

/************************************
 If the xor checksums agree, then 
 continue processing.
************************************/
   if ( sum != raw.xor  ) { 
      if ( sp->record_cnt > 1000 ) 	// ignore the first 1000 records
          sp->bad_checksums++;
	  oi = oi - 18;
          oi &= 0xff;
	  fprintf(stderr,"\nBad Checksum: Rec=%d Bad Recs=%d lgt=%8.3f ct=%8.3f\n", 
		sp->record_cnt, sp->bad_checksums, 
		lgt/200.0, ntohl(raw.data.tspo)/200.0
                );
          raw.data.tspo   = ntohl(raw.data.tspo);
          for (i=XG; i<= ZA; i++ ) 
             raw.data.sensor[i] = ntohs(raw.data.sensor[i] );
////	  print_packet();
   } else {   // Good records are processed in this block
      // Convert from big Endian to host endian (Little Endian)
       hdr.nrecs++;
       lgt = raw.data.tspo   = ntohl(raw.data.tspo);
       for (i=XG; i<= ZA; i++ ) 
           raw.data.sensor[i] = ntohs(raw.data.sensor[i] );

      #define GX 0
#define GY 1
#define GZ 2
#define AX 3
#define AY 4
#define AZ 5
// Convert the order to that of iex.
     iex.gy =  raw.data.sensor[  GX ];
     iex.gx = -raw.data.sensor[  GY ];
     iex.gz =  raw.data.sensor[  GZ ];
     iex.ay =  raw.data.sensor[  AX ];
     iex.ax = -raw.data.sensor[  AY ];
     iex.az =  raw.data.sensor[  AZ ];
     iex.sow = (raw.data.tspo/200.0 + time_offset ) ;
     if ( hdr.nrecs == 1 ) bsow = iex.sow;
     if ( odf ) sp->bytes_written += fwrite( &iex, sizeof(iex), 1, odf);
   }
   if ( (hdr.nrecs % 10000) == 0 ) printf("%7d Records processed   \r", hdr.nrecs);
  }
  esow = iex.sow;
  rewind(odf);
  fwrite( &hdr, sizeof(hdr), 1, odf );
  fclose(odf);
  display_header();
  printf("\n%7d Total records processed", hdr.nrecs);
  printf("\n");
}

