// vim: set ts=2 sts=2 sw=2 ai sr et:

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

profiler_data = h_new();

func profiler_enter(name) {
  extern profiler_data;
  start = array(double, 3);
  timer, start;
  if(catch(0x08)) {
    h_set, profiler_data, name, h_new(start=start, time=[0.,0.,0.], calls=0);
    return;
  }
  h_set, profiler_data(name), start=start;
}

func profiler_leave(name) {
  extern profiler_data;
  stop = array(double, 3);
  timer, stop;
  cur = profiler_data(name);
  h_set, cur, time=cur.time + stop - cur.start, calls=cur.calls + 1;
}

func profiler_report(names, srt=, searchstr=) {
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
    } else if(srt == "cpu") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler_data(names(i)).time(1);
      }
    } else if(srt == "system") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler_data(names(i)).time(2);
      }
    } else if(srt == "wall") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler_data(names(i)).time(3);
      }
    } else if(srt == "avg cpu") {
      for(i = 1; i <= count; i++) {
        calls = profiler_data(names(i)).calls;
        key(i) = calls ? profiler_data(names(i)).time(1)/calls : 0;
      }
    } else if(srt == "avg system") {
      for(i = 1; i <= count; i++) {
        calls = profiler_data(names(i)).calls;
        key(i) = calls ? profiler_data(names(i)).time(2)/calls : 0;
      }
    } else if(srt == "avg wall") {
      for(i = 1; i <= count; i++) {
        calls = profiler_data(names(i)).calls;
        key(i) = calls ? profiler_data(names(i)).time(3)/calls : 0;
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
    write, format="  %s:\n", "CPU";
    write, format="    %g seconds\n", cur.time(1);
    write, format="    %g seconds/call\n", cur.time(1)/cur.calls;
    write, format="  %s:\n", "System";
    write, format="    %g seconds\n", cur.time(2);
    write, format="    %g seconds/call\n", cur.time(2)/cur.calls;
    write, format="  %s:\n", "Wall";
    write, format="    %g seconds\n", cur.time(3);
    write, format="    %g seconds/call\n", cur.time(3)/cur.calls;
  }
}

func profiler_clear(void) {
  extern profiler_data;
  profiler_data=h_new();
}
