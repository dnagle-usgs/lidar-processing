/*
   i32, i24, and i16.

   These functions each take a char array, and an index
 into that array, and return an integer value representing
 the multi-byte little endian value represented by those
 bytes.  


*/

// Default to  converting litte endian values
_bitweights = [1,256,65536,16777216];

func set_endian_type( endian ) {
/* DOCUMENT set_endian_type( endian )

     endian = "big" for Big Endian (Sun)
     endian = "little" for Little Endian (Intel)

  Sets conversion method for i32, i24, i16, etc.

 See also i32, i16, i24.
*/
extern _bitweights;
 if ( endian == "little" ) {
    _bitweights = [1,256,65536,16777216];
 } 
 if ( endian == "big" )  { 
    _bitweights = [16777216,65536,256,1];
 }
}



func i32( ary, idx  ) {
/* DOCUMENT i32(ary, index)
   Converts the 4 byte values stored in ary at byte index
   into a 32 bit word.

   See also i32, i24, i16
*/
  r = idx:idx+3
  return ( (ary(r) * _bitweights(1:4) ) (sum)  );
}

func i24( ary, idx  ) {
/* DOCUMENT i24(ary, index)
   Converts the 3 byte values stored in ary at byte index
   into a 32 bit word.  While the return value is 32 bits,
   it's range is 24 bits.

   See also i32, i24, i16
*/
  r = idx:idx+2
  return ( (ary(r) * _bitweights(1:3) ) (sum)  );
}

func i16( ary, idx  ) {
/* DOCUMENT i32(ary, index)
   Converts the 2 byte values stored in ary at byte index
   into a signed 16 bit word.

   See also i32, i24, i16
*/
  r = idx:idx+1
  return short( (ary(r) * _bitweights(1:2) ) (sum)  );
}
