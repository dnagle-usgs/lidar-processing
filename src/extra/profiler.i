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
*/

scratch = save(scratch, tmp, profiler_enter, profiler_leave, profiler_report,
  profiler_clear);

tmp = save(data, enter, leave, report, clear);

if(is_obj(profiler) && profiler(*,"data") && is_obj(profiler.data)) {
  data = profiler.data;
} else {
  data = save();
}

func profiler_enter(name) {
  data = profiler.data;
  if(!data(*,name)) {
    save, profiler.data, noop(name),
      save(start=[0.,0.,0.], time=[0.,0.,0.], calls=0);
  }
  start = array(double, 3);
  timer, start;
  save, profiler.data(noop(name)), start;
}
enter = profiler_enter;

func profiler_leave(name) {
  if(!profiler.data(*,name)) error, name+" not started";
  cur = profiler.data(noop(name));
  stop = array(double, 3);
  timer, stop;
  time = cur.time + (stop - cur.start);
  calls = cur.calls + 1;
  save, profiler.data(noop(name)), time, calls;
}
leave = profiler_leave;

func profiler_report(names, srt=) {
  if(is_void(names)) names = profiler.data(*,);
  if(is_void(names)) return;

  count = numberof(names);

  if(srt) {
    key = double(indgen(count));
    if(srt == "alpha") {
      key = names;
    } else if(srt == "calls") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler.data(names(i)).calls;
      }
    } else if(srt == "cpu") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler.data(names(i)).time(1);
      }
    } else if(srt == "system") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler.data(names(i)).time(2);
      }
    } else if(srt == "wall") {
      for(i = 1; i <= count; i++) {
        key(i) = profiler.data(names(i)).time(3);
      }
    } else if(srt == "avg cpu") {
      for(i = 1; i <= count; i++) {
        calls = profiler.data(names(i)).calls;
        key(i) = calls ? profiler.data(names(i)).time(1)/calls : 0;
      }
    } else if(srt == "avg system") {
      for(i = 1; i <= count; i++) {
        calls = profiler.data(names(i)).calls;
        key(i) = calls ? profiler.data(names(i)).time(2)/calls : 0;
      }
    } else if(srt == "avg wall") {
      for(i = 1; i <= count; i++) {
        calls = profiler.data(names(i)).calls;
        key(i) = calls ? profiler.data(names(i)).time(3)/calls : 0;
      }
    }
    names = names(msort(key, names));
  }

  for(i = 1; i <= numberof(names); i++) {
    write, format="%s\n", names(i);
    if(!profiler.data(*,names(i))) {
      write, format="  %d calls\n", 0;
      continue;
    }
    cur = profiler.data(names(i));
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
report = profiler_report;

func profiler_clear(void) {
  save, profiler, data=save();
}
clear = profiler_clear;

profiler = restore(tmp);
restore, scratch;
