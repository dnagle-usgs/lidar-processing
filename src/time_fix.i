/*
 time_fix.i
 W. Wright 10-22-03

*************************************************************************
*************************************************************************

 *** Caution *** This function can easily wipe out your waveform 
                 dataset.  Use with extreme caution.

 The purpose of this collection of functions is to correct the seconds
 field in the raw waveform data and in the index file.  The problem 
 happens when the clock onboard the aircraft doesn't get set properly.

 -Wayne

*************************************************************************
*************************************************************************

*/

func time_fix( b,e, deltat ) {
/* DOCUMENT  time_fix( b,e, deltat )

   b is the starting raster
   e is the ending raster
   deltat is the time diff in seconds to add

*/

 is = long(1);			// place to store seconds
 lastfidx = -1;
 for (n=0, i=b; i<=e; n++, i++ ) {
   r = get_erast( rn=i, timeonly=1 );
   len  = i24(r,1);
   type = r(4);
   if ( type == 5 ) {		// make sure it's a type 5 record
      secs = i32(r,5);          // get the time word using the normal way
      sadr = edb(i).offset + 4;   // compute offset direct to seconds
      _read, _eidf, sadr, is
//      write, format="%6d %2d %5d %7d %7d \n", i, type, len, secs, is+deltat
      _write, _eidf, sadr, is+deltat;
      if  ( n % 5000 ) {
        if ( lastfidx != edb(i).file_number ) {
          lastfidx = edb(i).file_number;
          write,format="%3d %s updated\n", lastfidx, edb_files(lastfidx);
        }
        p = float(float(n) / float(e-b))
        write, format="  %4.2f%% complete  \r", p * 100.0;
      }
   }
 }
 write,"\nDone"

}


