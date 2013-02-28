// vim: set ts=2 sts=2 sw=2 ai sr et:

// i32, i24, and i16 leverage an obscure feature of wrap_args. If f is an open
// filehandle, then i32(f.raw, offset) would normally load the entire f.raw
// into memory prior to running the function. The args(i,:) syntax of wrap_args
// lets us refer to f.raw directly -without- loading it into memory. This means
// we are only reading the specific characters we are interested in, rather
// than loading the entire file to memory.

func i32(args) {
/* DOCUMENT i32(data, offset, big=)
  Converts the 4-byte values stored in data at the given offset(s) into 32-bit
  words. (However, the return type will be 4 or 8 bytes.)

  By default, treats data as little-endian. Use big=1 for big-endian.

  SEE ALSO: i16 i24 i32char
*/
  shift = args("big") ? [24,16,8,0] : [0,8,16,24];
  return (long(args(1,:)(args(2))) << shift(1)) |
    (long(args(1,:)(args(2)+1)) << shift(2)) |
    (long(args(1,:)(args(2)+2)) << shift(3)) |
    (long(args(1,:)(args(2)+3)) << shift(4));
}
wrap_args, i32;

func i24(args) {
/* DOCUMENT i24(data, offset, big=)
  Converts the 3-byte values stored in data at the given offset(s) into 24-bit
  words. (However, the return type will be 4 or 8 bytes.)

  By default, treats data as little-endian. Use big=1 for big-endian.

  SEE ALSO: i16 i32 i24char
*/
  shift = args("big") ? [16,8,0] : [0,8,16];
  return (long(args(1,:)(args(2))) << shift(1)) |
    (long(args(1,:)(args(2)+1)) << shift(2)) |
    (long(args(1,:)(args(2)+2)) << shift(3));
}
wrap_args, i24;

func i16(args) {
/* DOCUMENT i16(data, offset, big=)
  Converts the 2-byte values stored in data at the given offset(s) into signed
  16-bit words.

  By default, treats data as little-endian. Use big=1 for big-endian.

  SEE ALSO: i24 i32 i16char
*/
  shift = args("big") ? [8,0] : [0,8];
  return (short(args(1,:)(args(2))) << shift(1)) |
    (short(args(1,:)(args(2)+1)) << shift(2));
}
wrap_args, i16;

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
