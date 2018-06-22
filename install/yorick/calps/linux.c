// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

#include <sys/types.h>
#include <unistd.h>
#include "yapi.h"

void Y_get_pid(int nArgs)
{
  PushIntValue(getpid());
}
