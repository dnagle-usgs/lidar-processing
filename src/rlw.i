// vim: set ts=3 sts=3 sw=3 ai sr et:

func i32(data, offset, big=) {
/* DOCUMENT i32(data, offset, big=)
   Converts the 4-byte values stored in data at the given offset(s) into 32-bit
   words. (However, the return type will be 4 or 8 bytes.)

   By default, treats data as little-endian. Use big=1 for big-endian.

   SEE ALSO: i16 i24 i32char
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

   SEE ALSO: i16 i32 i24char
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

   SEE ALSO: i24 i32 i16char
*/
   shift = big ? [8,0] : [0,8];
   return (short(data(offset)) << shift(1)) | (short(data(offset+1)) << shift(2));
}

func i32char(data, big=) {
/* DOCUMENT i32char(data, big=)
   Converts the given integer values from data into a character array, treating
   the integer values as signed 32-bit words.

   By default, treats data as little-endian. Use big=1 for big-endian.

   SEE ALSO: i16char i24char i32
*/
   shift = big ? [24,16,8,0] : [0,8,16,24];
   result = array(char, 4, numberof(data));
   for(i = 1; i <= 4; i++)
      result(i,) = char((data >> shift(i)) & 255);
   return result(*);
}

func i24char(data, big=) {
/* DOCUMENT i24char(data, big=)
   Converts the given integer values from data into a character array, treating
   the integer values as signed 24-bit words.

   By default, treats data as little-endian. Use big=1 for big-endian.

   SEE ALSO: i16char i32char i24
*/
   shift = big ? [16,8,0] : [0,8,16];
   result = array(char, 3, numberof(data));
   for(i = 1; i <= 3; i++)
      result(i,) = char((data >> shift(i)) & 255);
   return result(*);
}

func i16char(data, big=) {
/* DOCUMENT i16char(data, big=)
   Converts the given integer values from data into a character array, treating
   the integer values as signed 16-bit words.

   By default, treats data as little-endian. Use big=1 for big-endian.

   SEE ALSO: i24char i32char i16
*/
   shift = big ? [8,0] : [0,8];
   result = array(char, 2, numberof(data));
   for(i = 1; i <= 2; i++)
      result(i,) = char((data >> shift(i)) & 255);
   return result(*);
}
