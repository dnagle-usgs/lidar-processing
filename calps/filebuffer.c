// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <stdio.h>
#include <string.h>
#include "yapi.h"

#include "filebuffer.h"

static void filebuffer_load(filebuffer_t *fb, long offset)
{
  long len = FILEBUFFER_SIZE;
  if(offset == fb->offset) return;
  fb->offset = offset;
  fseek(fb->f, offset, SEEK_SET);
  if(offset + len > fb->size)
  {
    len = fb->size - offset;
  }
  fread(fb->buffer, len, 1, fb->f);
}

static void filebuffer_check(filebuffer_t *fb, long offset, long len)
{
  if(offset + len > fb->size) y_error("attempt to read outside file bounds");
  if(offset < fb->offset || offset + len > fb->offset + FILEBUFFER_SIZE)
  {
    filebuffer_load(fb, offset);
  }
}

filebuffer_t * filebuffer_open(const char *fn)
{
  long i;
  filebuffer_t *fb = ypush_scratch(sizeof(filebuffer_t), filebuffer_close);
  fb->f = fopen(fn, "rb");
  if(!fb->f) y_error("unable to open file");

  fseek(fb->f, 0, SEEK_END);
  fb->size = ftell(fb->f);

  fb->offset = -1 * FILEBUFFER_SIZE;
  return fb;
}

void filebuffer_close(void *ptr)
{
  filebuffer_t *fb = ptr;
  fclose(fb->f);
}

long filebuffer_i32(filebuffer_t *fb, long offset)
{
  filebuffer_check(fb, offset, 4);
  offset -= fb->offset;
  return (
    fb->buffer[offset]
    | (fb->buffer[offset+1] << 8)
    | (fb->buffer[offset+2] << 16)
    | (fb->buffer[offset+3] << 24)
    );
}

long filebuffer_i24(filebuffer_t *fb, long offset)
{
  filebuffer_check(fb, offset, 3);
  offset -= fb->offset;
  return (
    fb->buffer[offset]
    | (fb->buffer[offset+1] << 8)
    | (fb->buffer[offset+2] << 16)
    );
}

long filebuffer_i16(filebuffer_t *fb, long offset)
{
  filebuffer_check(fb, offset, 2);
  offset -= fb->offset;
  return (fb->buffer[offset] | (fb->buffer[offset+1] << 8));
}

unsigned char filebuffer_i8(filebuffer_t *fb, long offset)
{
  filebuffer_check(fb, offset, 1);
  return fb->buffer[offset-fb->offset];
}

char * filebuffer_read(filebuffer_t *fb, long offset, long len)
{
  long dims[Y_DIMSIZE];
  long i = 0;
  char *out = NULL;

  if(len > FILEBUFFER_SIZE) y_error("attempt to read exceeded buffer size");
  filebuffer_check(fb, offset, len);

  dims[0] = 1;
  dims[1] = len;
  out = ypush_c(dims);

  offset -= fb->offset;
  for(i = 0; i < len; i++)
    out[i] = fb->buffer[offset+i];

  return out;
}
