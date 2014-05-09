// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

static void file_check(int nArgs, int amode)
{
  if(nArgs != 1) y_error("requires exactly one parameter");

  int type = yarg_string(0);
  if(type == 0) y_error("requires string input");

  if(type == 1) {
    // handle scalar

    ystring_t fn = ygets_q(0);
    ypush_int(access(fn, amode) == 0);

    return;
  }

  // type == 2; handle array

  long dims[Y_DIMSIZE];
  long count;
  ystring_t *fns = ygeta_q(0, &count, dims);
  int *result = ypush_i(dims);

  long i;
  for(i = 0; i < count; i++) {
    result[i] = (access(fns[i], amode) == 0);
  }
}

void Y_file_exists(int nArgs)
{
  file_check(nArgs, F_OK);
}

void Y_file_readable(int nArgs)
{
  file_check(nArgs, R_OK);
}

void Y_file_size(int nArgs)
{
  if(nArgs != 1) y_error("requires exactly one parameter");

  int type = yarg_string(0);
  if(type == 0) y_error("requires string input");

  struct stat st;

  if(type == 1) {
    // handle scalar
    ystring_t fn = ygets_q(0);
    if(stat(fn, &st) != 0)
      y_errorq("cannot access file %s", fn);
    ypush_long(st.st_size);
    return;
  }

  // type == 2; handle array

  long dims[Y_DIMSIZE];
  long count;
  ystring_t *fns = ygeta_q(0, &count, dims);
  long *result = ypush_l(dims);

  long i;
  for(i = 0; i < count; i++) {
    if(stat(fns[i], &st) != 0)
      y_errorq("cannot access file %s", fns[i]);
    result[i] = st.st_size;
  }
}
