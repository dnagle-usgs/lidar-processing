
/******************************************************************* 
    $Id$

  fixdmars.c: 
   Based on dmarsd.c.  This program is used to read the "cat" files
   captured on dmars145 and fix the time.

  Original: W. Wright 12/5/2003

  Options:
     -d input device or file
     -O Uncompressed data file name.
     -P Printout every 200th converted values on stdout.
     -p Printout all converted values on stdout.

*******************************************************************/


#include "stdio.h"
#include "math.h"
#include <sys/time.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <assert.h>
#include <string.h>
#include <sched.h>
#include "dmars.h"

#define INP_BUFFER_SIZE 256*1024
#define ODF_BUFFER_SIZE 16*1024

#define DATALOGR_SCHED SCHED_FIFO


// The sp pointer will be set to point into shared memory.
extern char *optarg;


// Declare the data and set the header values
DMARS     raw = { 0x7e } ; 
NTPSOE ntpsoe = { 0x7d };



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
  i = stat (devfn, &sbuf);
  i = S_IFMT & sbuf.st_mode;

  if        (  i == S_IFREG  ) {  // if regular file
        ;
  } else if ( (i == S_IFCHR) ) {  // if a serial port
///    sprintf(str, "stty raw crtscts -echo 115200 <%s", devfn );       
    is_a_device++;
///    system( str );
  } else {			// neither one.
     printf ("\n%s is not a character device.\n", devfn);
     exit (1);
  }

  if ((devfd = fopen (devfn, "r+")) == NULL) {
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


 t = time( NULL );  
 strftime( sp->odfn,MAXLEN,"/data/%m%d%y-%H%M%S-dmars.bin", gmtime( &t ) ) ; 



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
          if ((odf = fopen (sp->odfn, "w")) == NULL)
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
       if ( sscanf( optarg, "%d", &timer ) == 0 )
         fail("Invalid timer value");
      break;
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
  

/***********************************************
   Main loop begins here
************************************************/
   sp->run = 1;
   sp->record_cnt = 0;
   sp->bad_checksums = 0;
   sp->bytes_written = 0;
   sp->dtis = 0;

   while ( sp->run ) {
     if ( at_eof( devfd ) ) 
        fail("EOF found on input stream");

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
	  fprintf(stderr,"Bad Checksum: Rec=%d Bad Recs=%d lgt=%8.3f ct=%8.3f\n", 
		sp->record_cnt, sp->bad_checksums, 
		lgt/200.0, ntohl(raw.data.tspo)/200.0
                );
          raw.data.tspo   = ntohl(raw.data.tspo);
          for (i=XG; i<= ZA; i++ ) 
             raw.data.sensor[i] = ntohs(raw.data.sensor[i] );
	  print_packet();
   } else {
      // Convert from big Endian to host endian (Little Endian)
       lgt = raw.data.tspo   = ntohl(raw.data.tspo);
       for (i=XG; i<= ZA; i++ ) 
           raw.data.sensor[i] = ntohs(raw.data.sensor[i] );


/************************************
 Copy the data packet to shared memory.
************************************/
  memcpy( &sp->data, &raw.data, sizeof(raw.data));
  tag = ' ';

  if ( odf ) sp->bytes_written += fwrite( &raw, 1, sizeof(raw), odf);
  switch ( print ) {
   case 'p':
         if ( tag == '*' ) print_packet();
     break;

   case 'P': 
         print_packet(); 
     break;
   }
  }
 }
}

