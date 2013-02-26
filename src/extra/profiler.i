// vim: set ts=2 sts=2 sw=2 ai sr et:

// This requires C-ALPS functionality.
require, "calps.i";

if(!is_func(profiler_ticks)) error, "you need to update C-ALPS";

extern profiler;
/* DOCUMENT profiler
  This is intended to aid a programmer in profiling code execution times. None
  of this functionality should occur in commited code. It is intended for
  temporary use during development.

  Typical usage is to bracket code segments of interest like so:

    profiler, enter, "section 1";
    // code to examine
    profiler, leave, "section 1";

  Where "section 1" is whatever descriptive name you like. Then you can get a
  report with:

    profiler, report

  Or, to see just selected items:

    profiler, report, "section 1";
    profiler, report, ["section 1", "section 2"];

  This can be used to profile entire functions in one of two ways. If your
  function only has one point of return, you can easily put the profiling at
  the start and end of the function. Here is a contrived and inefficient
  example.

    func sum_min_max(ary) {
      profiler, enter, "sum_min_max";
      result = [];
      if(numberof(ary)) {
        result = ary(*)(min) + ary(*)(max);
      }
      profiler, leave, "sum_min_max";
      return result;
    }

  If your code has multiple points of exit, you will have to put a
  profiler,leave call before each point of exit. Alternately, you can also put
  the profiler,enter profiler,leave calls around a function call instead.

    func sum_min_max(ary) {
      if(!numberof(ary)) return [];
      return ary(*)(min) + ary(*)(max);
    }

    bigarray = indgen(100000);
    total = 0;
    for(i = 1; i <= 100; i++) {
      bigarray = bigarray(sort(bigarray));
      profiler, enter, "sum_min_max";
      total += sum_min_max(bigarray);
      profiler, leave, "sum_min_max";
    }

  To clear current profiler data, use "profiler, clear".

  The "profiler, report" command accepts a few options:

    srt= Allows you to specify how to sort the output information. Valid values
      are:
        srt="alpha"       Alphabetical by name
        srt="calls"       By number of calls made
        srt="cpu"         By CPU seconds
        srt="system"      By system seconds
        srt="wall         By wall seconds
        srt="avg cpu"     By average CPU seconds per call
        srt="avg system"  By average system seconds per call
        srt="avg wall"    By average wall seconds per call
      All sorting is in ascending order. That means that for everything except
      "alpha", the "worst" items will be at the bottom.

    searchstr= Allows you to restrict output to profiling names that match a
      given search string (or array of search strings).
*/

if(!is_hash(profiler_data)) profiler_data = h_new();
if(is_void(profiler_depth)) profiler_depth = 0;
if(is_void(profiler_counts)) profiler_counts = array(0, 100);
if(is_void(profiler_overhead)) profiler_overhead = 0;

func profiler_enter(name) {
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
      Otherwise, profiler_reset is called.
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
