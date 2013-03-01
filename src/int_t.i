// vim: set ts=2 sts=2 sw=2 ai sr et:

extern int8_t, int16_t, int32_t;
/* DOCUMENT int8_t, int16_t, in32_t
  These define the smallest integer types that will hold 8-bit, 16-bit, and
  32-bit values. On many systems, this will result in:

    int8_t = char
    int16_t = short
    int32_t = int

  However, for sanity's sake, checks are done to ensure this. If you're on a
  really old 16-bit system, perhaps you will end up with int32 being a long.

  These are intended for use in structs that will only ever be kept in memory.
  If you intend to save a struct to file, these SHOULD NOT be used.

  Primarily, these are intended for readability's sake. "int32" much better
  expressed "this needs a 4-byte integer" than "int" does, and may help prevent
  people from bumping it up to a "long" when it's not necessary.
*/

// char has to be at least one byte...
if(sizeof(char) >= 1) {
  int8_t = char;
} else {
  error, "Crazy system detected without a char big enough for a byte";
}

if(sizeof(char) >= 2) {
  int16_t = char;
} else if(sizeof(short) >= 2) {
  int16_t = short;
} else if(sizeof(int) >= 2) {
  int16_t = int;
} else if(sizeof(long) >= 2) {
  int16_t = long;
} else {
  error, "No integers can hold 16-bit values";
}

if(sizeof(char) >= 4) {
  int32_t = char;
} else if(sizeof(short) >= 4) {
  int32_t = short;
} else if(sizeof(int) >= 4) {
  int32_t = int;
} else if(sizeof(long) >= 4) {
  int32_t = long;
} else {
  error, "No integers can hold 32-bit values";
}
