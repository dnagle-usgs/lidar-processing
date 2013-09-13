// vim: set ts=2 sts=2 sw=2 ai sr et:

// i32, i24, and i16 leverage an obscure feature of wrap_args. If f is an open
// filehandle, then i32(f.raw, offset) would normally load the entire f.raw
// into memory prior to running the function. The args(i,:) syntax of wrap_args
// lets us refer to f.raw directly -without- loading it into memory. This means
// we are only reading the specific characters we are interested in, rather
// than loading the entire file to memory.

// fi32, fi24, and fi16 are improved alternatives to the above functions. For
// whatever reason, they operate faster and should be used instead when
// operating on files. However, they can only be used for a scalar value
// (unlike the above functions, which accept arrays of offsets).

func fi32(f, offset, big=) {
/* DOCUMENT fi32(f, offset, big=)
  Reads 4 bytes from file F starting at OFFSET and converts into a 32-bit word.
  OFFSET is 1-based instead of 0-based, for compatibility with i32. The return
  type will be long.

  By default, treats data as little-endian. Use big=1 for big-endian.
*/
  shift = big ? [24,16,8,0] : [0,8,16,24];
  data = array(char, 4);
  _read, f, offset-1, data;
  return (long(data(1)) << shift(1)) |
    (long(data(2)) << shift(2)) |
    (long(data(3)) << shift(3)) |
    (long(data(4)) << shift(4));
}

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

func fi24(f, offset, big=) {
/* DOCUMENT fi24(f, offset, big=)
  Reads 3 bytes from file F starting at OFFSET and converts into a 24-bit word.
  OFFSET is 1-based instead of 0-based, for compatibility with i24. The return
  type will be long.

  By default, treats data as little-endian. Use big=1 for big-endian.
*/
  shift = big ? [16,8,0] : [0,8,16];
  data = array(char, 3);
  _read, f, offset-1, data;
  return (long(data(1)) << shift(1)) |
    (long(data(2)) << shift(2)) |
    (long(data(3)) << shift(3));
}

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

func fi16(f, offset, big=) {
/* DOCUMENT fi16(f, offset, big=)
  Reads 2 bytes from file F starting at OFFSET and converts into a 16-bit word.
  OFFSET is 1-based instead of 0-based, for compatibility with i16. The return
  type will be short.

  By default, treats data as little-endian. Use big=1 for big-endian.
*/
  shift = big ? [8,0] : [0,8];
  data = array(char, 2);
  _read, f, offset-1, data;
  return (long(data(1)) << shift(1)) |
    (long(data(2)) << shift(2));
}

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
