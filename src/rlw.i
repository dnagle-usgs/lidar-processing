// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:
/*
   i32, i24, and i16.

   These functions each take a char array and an offset(s) into the array, then
   return integer values representing the little endian value represented by
   the bytes. Keyword big=1 will return the big endian instead.
*/

func i32(data, offset, big=) {
/* DOCUMENT i32(data, offset, big=)
   Converts the 4-byte values stored in data at the given offset(s) into 32-bit
   words. (However, the return type will be 4 or 8 bytes.)

   By default, treats data as little-endian. Use big=1 for big-endian.

   See also: i16 i24
*/
   shift = big ? [24,16,8,0] : [0,8,16,24];
   return (long(data(offset)) << shift(1)) |
      (long(data(offset+1)) << shift(2)) |
      (long(data(offset+2)) << shift(3)) |
      (long(data(offset+3)) << shift(4));
}

func i24(data, offset, big=) {
/* DOCUMENT i24(data, offset, big=)
   Converts the 3-byte values stored in data at the given offset(s) into 24-bit
   words. (However, the return type will be 4 or 8 bytes.)

   By default, treats data as little-endian. Use big=1 for big-endian.

   See also: i16 i32
*/
   shift = big ? [16,8,0] : [0,8,16];
   return (long(data(offset)) << shift(1)) |
      (long(data(offset+1)) << shift(2)) |
      (long(data(offset+2)) << shift(3));
}

func i16(data, offset, big=) {
/* DOCUMENT i16(data, offset, big=)
   Converts the 2-byte values stored in data at the given offset(s) into signed
   16-bit words.

   By default, treats data as little-endian. Use big=1 for big-endian.

   See also: i24 i32
*/
   shift = big ? [8,0] : [0,8];
   return (short(data(offset)) << shift(1)) | (short(data(offset+1)) << shift(2));
}
