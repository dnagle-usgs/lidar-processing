
/*
    Original is in the dmars CVS on kiwi
   $Id$ 
    Original W. Wright
*/
#define G 9.80665

#define I8   char
#define UI8  unsigned I8
#define I16  short
#define UI16 unsigned I16
#define I32  int
#define UI32 unsigned I32

// Maximum string length
#define MAXLEN 256

#define XG 0
#define YG 1
#define ZG 2
#define XA 3
#define YA 4
#define ZA 5

#define INTLZ_BIT 	0x80
#define GYRO_ENABLE     0x40
#define HI_TEMP         0x20
#define LO_TEMP         0x10
#define GPS1HZ          0x01

/*******************************************************
   The basic payload data from the DMARS.  This plus the
   header byte, 0x7e, are  the only parts that are
   checksumed.
*******************************************************/
typedef struct {
  UI32 tspo;		// Ticks since power on;
  UI8  status;
  I16 sensor[6];
}  __attribute__ ((packed)) DMARS_DATA;

/*******************************************************
  The full DMARS packet including the header, data, and
  checksum.
*******************************************************/
typedef struct {
  UI8  header;		// 0x7e fixed
  DMARS_DATA data;
  UI8  xor;
} __attribute__ ((packed)) DMARS;


/*******************************************************
  Our time tag data packet that gets interjected once
 per second.
*******************************************************/
typedef struct {
   UI8 header;			// 0x7d
   struct timeval tv;
} __attribute__ ((packed)) NTPSOE;


typedef struct {
  I16 min, max;
} MINMAX;

typedef struct {
  UI8 run;	           // Run while non zero.
  UI32 dmars_log;	   // Record of total seconds the DMARS has been on.
  UI32 record_cnt;         // Total packets received.
  UI32 bad_checksums;      // Number of bad packets.
  UI32 bytes_written;      // total bytes written.
  char devfn[ MAXLEN ];	   // Input device.
  char  odfn[ MAXLEN ];    // Output data file.
  UI32 dtis;		   // time diff integer seconds to system NTP time.
  double tdiff;            // Difference between computer and DMARS time.
  DMARS_DATA data;	   // copy of the latest data packet.
  MINMAX minmax[6];        // Minmax
  I16   avg[6];          // Averaged values.
} STATS;



