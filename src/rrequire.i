// vim: set ts=2 sts=2 sw=2 ai sr et:

if(is_void(orequire)) orequire = require;

func rrequire(hist, source) {
/* DOCUMENT rrequire, source
  SOURCE should be a scalar string, to be interpreted as a filename like
  "yorick_source.i". This file will be sourced if it hasn't already been.

  Unlike the builtin require, rrequire is recursive-aware. It detects
  dependency loops and will refrain from re-requiring a file if it's currently
  already being required.

  Typically, the builtin require will be replaced by rrequire and the original
  require will be renamed to orequire.
*/
  // If you want to see a dependency tree, manually change this to if(1)
  if(0) {
    write, format="%s", " ";
    for(i = 1; i <= numberof(hist.prev); i++)
      write, format="%s", "| ";
    write, format="%s", source;
    if(anyof(hist.prev == source))
      write, format="%s", " (loop)";
    write, format="%s", "\n";
  }
  if(anyof(hist.prev == source)) {
    // If you want to debug recursive requires, manually change this to if(1)
    if(0) {
      write, "recursive require detected:";
      w = where(hist.prev == source)(1);
      loop = hist.prev(w:);
      write, format="%s", "  ";
      write, format=" %s ->", loop;
      write, format=" %s\n", source;
    }
  } else {
    save, hist, prev=grow(hist.prev, source);
    orequire, source;
    if(numberof(hist.prev) > 1)
      save, hist, prev=hist.prev(:-1);
    else
      save, hist, prev=[];
  }
}

rrequire = closure(rrequire, save(prev=[]));

require = rrequire;
