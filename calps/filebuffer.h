// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <string.h>
#include "yapi.h"

/* filebuffer library
 *
 * This provides an API for reading data from a binary file using an internal
 * buffer. This provides much higher performance than directly reading from the
 * file since individual small calls to the hard drive are much, much slower
 * than making a few larger calls and storing the results in memory.
 *
 * This library is optimized for forward sequential access. Highly random
 * access may not see much gain from this and may even see a performance
 * penalty. However, a small amount of backtracking will not cause a problem.
 * (For instance, making two passes over a file has a negligible impact since
 * you only backtrack once.)
 *
 * Warning: Some API methods will place items on the Yorick stack to
 * dynamically allocate memory. See the documentation below for details on
 * which methods do so.
 */

// Size of internal buffer, currently 1 MB
#define FILEBUFFER_SIZE (1024 * 1024)

// Opaque type used for filebuffer handle.
typedef struct filebuffer_t filebuffer_t;

/* filebuffer_open
 *
 * Opens a binary file and initializes it for the filebuffer API. Returns an
 * opaque handle filebuffer_t* that can be used with other API calls to read
 * data from file.
 *
 * This pushes one entry onto the Yorick stack to allocate the mmeory for the
 * filebuffer handle. The filebuffer handle will release its internal resources
 * (such as its file handle) when Yorick releases its memory.
 */
filebuffer_t * filebuffer_open(const char *fn);

/* filebuffer_size
 * Returns the size of the underlying file.
 */
long filebuffer_size(filebuffer_t *fb);

/* filebuffer_i32
 * Returns the 32-bit little endian word at the given offset.
 */
long filebuffer_i32(filebuffer_t *fb, long offset);

/* filebuffer_i24
 * Returns the 24-bit little endian word at the given offset.
 */
long filebuffer_i24(filebuffer_t *fb, long offset);

/* filebuffer_i16
 * Returns the 16-bit little endian word at the given offset.
 */
long filebuffer_i16(filebuffer_t *fb, long offset);

/* filebuffer_i8
 * Returns the 8-bit little endian word at the given offset.
 */
unsigned char filebuffer_i8(filebuffer_t *fb, long offset);

/* filebuffer_read
 *
 * Reads LEN bytes at OFFSET and returns as a pointer to an array of char.
 *
 * This pushes one entry onto the Yorick stack to allocate the memory for the
 * array of char.
 *
 * Warning: The maximum LEN permitted is FILEBUFFER_SIZE. Larger reads will
 * result in an error.
 */
char * filebuffer_read(filebuffer_t *fb, long offset, long len);
