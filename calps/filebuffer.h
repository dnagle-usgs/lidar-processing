// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <string.h>
#include "yapi.h"

// 1 MB buffer size
#define FILEBUFFER_SIZE (1024 * 1024)

typedef struct
{
  FILE *f;
  long size;
  long offset;
  unsigned char buffer[FILEBUFFER_SIZE];
} filebuffer_t;

filebuffer_t * filebuffer_open(const char *fn);
void filebuffer_close(void *ptr);
long filebuffer_i32(filebuffer_t *fb, long offset);
long filebuffer_i24(filebuffer_t *fb, long offset);
long filebuffer_i16(filebuffer_t *fb, long offset);
unsigned char filebuffer_i8(filebuffer_t *fb, long offset);
char * filebuffer_read(filebuffer_t *fb, long offset, long len);
