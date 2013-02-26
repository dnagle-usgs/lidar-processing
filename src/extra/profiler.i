// vim: set ts=2 sts=2 sw=2 ai sr et:

// This requires C-ALPS functionality.
require, "calps.i";

if(!is_func(profiler_ticks)) error, "you need to update C-ALPS";

extern profiler;
/* DOCUMENT profiler
  This is intended to aid a programmer in profiling code execution times. None
  of this functionality should occur in commited code. It is intended for
  temporary use during development.

  Typical use is to bracket code segments of interest like so:

    profiler, enter, "section 1";
    // code to examine
    profiler, leave, "section 1";

  You can then receive a report using "profiler, report".

  Before using the profiler, you should use profiler_calibrate. You can use
  this to set the precision you need for the timing as well as to set the
  calibration constant to remove the profiling overhead from its timings. (You
  should also call it again if you ever change the places= value.)

  Before any act of profiling, you should use profiler_clear to reset all
  tracked data. (Otherwise, subsequent profilings will stack on each other.)
*/

extern profiler_enter, profiler_leave;
/* DOCUMENT
  profiler_enter, "<name>"
  profiler_leave, "<name>"

  Tells the profiler that you are entering or leaving a section code described
  by the given NAME. Profiler will count this as a call to that name and tally
  the time taken.
*/

if(!is_hash(profiler_data)) profiler_data = h_new();
if(is_void(profiler_depth)) profiler_depth = 0;
if(is_void(profiler_counts)) profiler_counts = array(0, 100);
if(is_void(profiler_overhead)) profiler_overhead = 0;

func profiler_enter(name) {
// Documented above
  extern profiler_data, profiler_depth, profiler_counts;
  profiler_depth++;
  profiler_counts(:profiler_depth)++;
  start = profiler_ticks();
  if(catch(0x08)) {
    h_set, profiler_data, name, h_new(start=start, time=0, calls=0);
    return;
  }
  h_set, profiler_data(name), start=start;
}

func profiler_leave(name) {
// Documented above
  extern profiler_data, profiler_depth, profiler_counts, profiler_overhead;
  stop = profiler_ticks();
  cur = profiler_data(name);
  h_set, cur, calls=cur.calls + 1,
    time=cur.time + (stop - cur.start) -
      profiler_counts(profiler_depth) * profiler_overhead;
  profiler_counts(profiler_depth) = 0;
  profiler_depth--;
}

func profiler_report(names, srt=, searchstr=) {
/* DOCUMENT profiler_report, names, srt=, searchstr=
  Provides a profiling report.

  NAMES is optional and specifies which profiling names to display. If omitted,
  all names are used.

  srt= Allows you to specify how to sort the output information. Valid values
    are:
      srt="alpha"       Alphabetical by name
      srt="calls"       By number of calls made
      srt="ticks"       By ticks
      srt="avg ticks"   By average ticks per call
    All sorting is in ascending order. That means that for everything except
    "alpha", the "worst" items will be at the bottom.

  searchstr= Allows you to restrict output to profiling names that match a
    given search string (or array of search strings).
*/
  extern profiler_data;
  if(is_void(names)) names = h_keys(profiler_data);

  count = numberof(names);
  if(!count) return;

  if(!is_void(searchstr)) {
    keep = array(0, count);
    for(i = 1; i <= numberof(searchstr); i++)
      keep |= strglob(searchstr(i), names);
    names = names(where(keep));
    count = numberof(names);
  }

  if(srt) {
    key = double(indgen(count));
    if(srt == "alpha") {
      key = names;
    } else if(srt == "calls") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler_data(names(i)).calls;
      }
    } else if(srt == "ticks") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler_data(names(i)).time;
      }
    } else if(srt == "avg ticks") {
      for(i = 1; i <= count; i++) {
        calls = profiler_data(names(i)).calls;
        key(i) = calls ? profiler_data(names(i)).time/calls : 0;
      }
    }
    names = names(msort(key, names));
  }

  for(i = 1; i <= numberof(names); i++) {
    write, format="%s\n", names(i);
    if(!h_has(profiler_data, names(i))) {
      write, format="  %d calls\n", 0;
      continue;
    }
    cur = profiler_data(names(i));
    write, format="  %d calls\n", cur.calls;
    if(!cur.calls) continue;
    write, format="  %d ticks\n", cur.time;
    write, format="  %d ticks/call\n", cur.time/cur.calls;
  }
}

func profiler_clear(void, places=, maxdepth=) {
/* DOCUMENT profiler_clear, places=, maxdepth=
  Clears current profiling data. Also resets the offset for timing data.

  Options:
    places= If provided, profiler_init will be called with this as an argument.
      Otherwise, profiler_reset is called. PLACES specifies how many decimal
      places you want in your integer time value. Using places=9 means time
      will be tracked in nanoseconds; places=3 means time will be tracked in
      milliseconds. (By default, places=0.)
    maxdepth= If provided, this will change the maximum profiling depth for
      nested profiling. Default depth is 100. If you exceed the maximum profile
      depth, you'll get an error.
*/
  extern profiler_data, profiler_counts, profiler_depth, profiler_overhead;
  default, maxdepth, 100;
  profiler_data=h_new();
  profiler_counts = array(0, maxdepth);
  profiler_depth = 0;
  if(is_void(places)) {
    profiler_reset;
  } else {
    profiler_overhead = 0;
    profiler_init, places;
  }
}

func profiler_calibrate(count, places=, maxdepth=) {
/* DOCUMENT profiler_calibrate, count, places=, maxdepth=
  Calibrates the profiler overhead. COUNT specifies how many times we should
  loop to determine that value. If omitted, COUNT defaults to 10000. However, a
  value like 1000000 (or larger) would be better.

  For convenience, places= and maxdepth= are passed through to profiler_clear
  if they are provided.
*/
  extern profiler_overhead;
  profiler_clear, places=places, maxdepth=maxdepth;
  profiler_overhead = 0;
  default, count, 10000;

  // Calculate the overhead of two calls to profiler_ticks + a loop of COUNT
  start = profiler_ticks();
  for(i = 1; i <= count; i++) {}
  stop = profiler_ticks();
  loop_ticks = stop - start;

  // Calculate the overhead of the above loop + COUNT * 5 profilings
  // (Using nested profiling to depth 5 to at least partially account for
  // potential variance due to depth)
  start = profiler_ticks();
  for(i = 1; i <= count; i++) {
    profiler_enter, "calibration";
    profiler_enter, "calibration";
    profiler_enter, "calibration";
    profiler_enter, "calibration";
    profiler_enter, "calibration";
    profiler_leave, "calibration";
    profiler_leave, "calibration";
    profiler_leave, "calibration";
    profiler_leave, "calibration";
    profiler_leave, "calibration";
  }
  stop = profiler_ticks();
  prof_ticks = stop - start;

  ticks_per_prof = double(prof_ticks - loop_ticks)/count/5;
  profiler_overhead = long(ticks_per_prof);

  write, format="Ticks per profiling: %g\n", ticks_per_prof;
  write, format="Set profiler_overhead to: %d\n", profiler_overhead;

  profiler_clear;
}
