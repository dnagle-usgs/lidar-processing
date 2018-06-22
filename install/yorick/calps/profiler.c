// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:

// This time.h requires -lrt to compile
#include <time.h>

#include "yapi.h"

#define NANOSECONDS 1000000000L

static long profiler_offset = 0L;
static long profiler_sec = 1L;
static long profiler_nsec = NANOSECONDS;

// Initializes profiler_sec and profiler_nsec
// Resets profiler_offset
// Accepts one argument, places
// Returns nothing
void Y_profiler_init(int nArgs)
{
  long places;
  struct timespec current;

  if(nArgs != 1)
    y_error("profiler_init requires exactly one argument");

  places = ygets_l(0);
  if(places < 0 || places > 9)
    y_error("places argument must be between 0 and 9");

  profiler_sec = 1;
  profiler_nsec = NANOSECONDS;

  while(places) {
    places--;
    profiler_sec *= 10;
    profiler_nsec /= 10;
  }

  clock_gettime(CLOCK_MONOTONIC, &current);
  profiler_offset = (long)current.tv_sec;

  ypush_nil();
}

// Returns value last passed into Y_profiler_init
void Y_profiler_lastinit(int nArgs)
{
  long places = 0, sec = profiler_sec;
  while(sec > 1) {
    places++;
    sec /= 10;
  }

  ypush_long(places);
}

// Resets profiler_offset
// Returns nothing
void Y_profiler_reset(int nArgs)
{
  struct timespec current;
  clock_gettime(CLOCK_MONOTONIC, &current);
  profiler_offset = (long)current.tv_sec;
  ypush_nil();
}

// Returns current clock ticks
// Meaning of "clock ticks" is dependent on places value and last offset but
// are always good for measuring relative time (as in profiling)
void Y_profiler_ticks(int nArgs)
{
  struct timespec current;
  clock_gettime(CLOCK_MONOTONIC, &current);
  ypush_long(
    ((long)current.tv_sec - profiler_offset)*profiler_sec +
    (long)current.tv_nsec/profiler_nsec
  );
}
