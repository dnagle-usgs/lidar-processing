/**********************************************************

   $Id$ 
   W. Wright 6/30/2003

   This program locates and removes linefeed characters
inserted by the Windows commandline ftp program when it
is used to download binary data without the "bi" option
turned on.  Without the "bi" option, the dos ftp program 
assumes the file is ASCII and it replaces all 0x0a 
bytes with the byte pair 0x0d followed by 0x0a which is 
a carriage return followed by a linefeed.  Needless to say,
this seriously fouls up a binary file which contains any
0x0a bytes.  

The main use for this program is to "fix" raw binary 
Ashtech data which was accidently downloaded without the
"bi" option enabled.


Usage:
  fix-dos-crlf-ash  < file-with-problems.ash > fixed-file.ash 

  The program will display a running count of the errors that
  it repairs.  NOTE***  Do not run this program using a repaired
  file for input, only run against input files which were 
  corrupted by the windows/dos ftp program.

**********************************************************/
#include <stdio.h>
unsigned char c,d,e;
unsigned int repairs = 0;
main() {

  while ( !feof(stdin) ) {		// do the following until end-of-file
    c = getchar() & 0xff ;		// get a single char
    if ( c == 0x0d ) {                  // see if it's a CR
       d = getchar();                   // if it's a CR, get the next character
       if ( d == 0x0a ) {               // If this one is a LF, then
          putchar(d);                   //   send it to the output stream
          if ( (++repairs % 1024) == 0 ) fprintf(stderr,"\r  %7d  repairs made", repairs );
       } else {                           // if it wasn't a CRLF pair, then 
          ungetc(d, stdin);             //   put "d" back on the input stream
          putchar(c);                   // and output the previous "c"
       }
    } else putchar(c);                  // if "c" wasn't a CR, then simply output the char.
 }
 fprintf(stderr,"\r  %7d  repairs made", repairs );
 fprintf(stderr,"\n");
}
