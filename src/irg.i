/*
   $Id$
*/



  struct AA { double soe(120); short  irange(120); short  sa(120); };

func irg( b, e ) {
/* DOCUMENT irg(b, e) 
   Returns an array of irange values from record
   b to record e.

   return array:
   a(1, ) = offset_time 
   a(2, ) = irange 
   a(3, ) = sa  (scan angle )
*/
  len = e - b;
//  a = array( float, 3, 120, len+1);
  a = array( AA,  len + 1 );
  "";
  for ( di=1, si=b; si<e; di++, si++ ) {
    rp = decode_raster( get_erast( rn=si )) ;
    a(di).soe = rp.offset_time ;
    a(di).irange = rp.irange;
    a(di).sa  = rp.sa;
    write,format="  %d/%d     \r", di, len
  }
  return a;
}



