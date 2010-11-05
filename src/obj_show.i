// vim: set ts=2 sts=2 sw=2 ai sr et:

func obj_show(workers, obj, prefix=, maxary=, maxchild=, maxdepth=) {
/* DOCUMENT obj_show, obj;
  -or- output = obj_show(obj);
  Display contents of object OBJ in a tree-like representation. Keyword PREFIX
  can be used to prepend a prefix to the printed lines. Keyword MAXARY (default
  5) can be used to specify the maximum number of elements for printing array
  values. Keyword MAXCHILD (default 20) can be used to specify the maximum
  number of child entries for recursing into heirarchical structures. Keyword
  MAXDEPTH (default 5) can be used to specify the maximum recursion depth for
  heirarchical structures.
*/
  if(is_void(maxary)) maxary=5;
  if(is_void(maxchild)) maxchild=20;
  if(is_void(maxdepth)) maxdepth=5;
  curdepth = 0;
  output = "";
  workers, _recurse, obj, "TOP", (is_void(prefix) ? "" : prefix), 0;
  if(am_subroutine())
    write, format="%s", output;
  return output;
}

/*
  Custom workers can be defined externally by creating a function with
  parameters (obj, name, prefix1, prefix2). Then add an entry to obj_show's
  workers like so:
    save, obj_show.data, typename=customworker
  where typename is the result of typeof(item).
*/

scratch = save(tmp, _array, _closure, __closure, scratch);
__closure = closure;
tmp = save(_recurse, oxy_object, hash_table, float, double, char, short, int,
  long, pointer, string, void, symlink, closure);

func _recurse(obj, name, prefix, stage) {
  this = use();
  curdepth++;
  if(stage == 1)
    prefix += [" |-", " | "];
  else if(stage == 2)
    prefix += [" `-", "   "];
  else
    prefix += ["", ""];
  if(this(*,typeof(obj)))
    this, typeof(obj), obj, name, prefix(1), prefix(2);
  else
    output += swrite(format="%s %s (%s)\n", prefix(1), name, typeof(obj));
  curdepth--;
}

func oxy_object(obj, name, prefix1, prefix2) {
  count = obj(*);
  output += swrite(format="%s %s (oxy_object, %d %s)\n",
    prefix1, name, count, (count == 1 ? "entry" : "entries"));
  if(curdepth == maxdepth || count > maxchild)
    return;
  for(i = 1; i <= count; i++) {
    key = obj(*,i);
    if(!key) key = "(nil)";
    call, use(_recurse, obj(noop(i)), key, prefix2, 1 + (i == count));
  }
}

func hash_table(obj, name, prefix1, prefix2) {
  key_list = h_keys(obj);
  count = numberof(key_list);
  if(count)
    key_list = key_list(sort(key_list));
  ev = h_evaluator(obj);
  output += swrite(format="%s %s (hash_table, %s%d %s)\n",
    prefix1, name, (ev ? "evaluator=\""+ev+"\", " : ""),
    count, (count == 1 ? "entry" : "entries"));
  if(curdepth == maxdepth || count > maxchild)
    return;
  for(k = 1; k <= count; k++) {
    key = key_list(k);
    call, use(_recurse, h_get(obj,key), key, prefix2, 1 + (k == count));
  }
}

func _array(obj, name, prefix1, prefix2) {
  descr = typeof(obj);
  dims = dimsof(obj);
  n = numberof(dims);
  k = 1;
  while (++k <= n) {
    descr += swrite(format=",%d", dims(k));
  }
  if(numberof(obj) <= maxary) {
    output += swrite(format="%s %s (%s) %s\n", prefix1, name, descr,
      sum(print(obj)));
  } else {
    output += swrite(format="%s %s (%s)\n", prefix1, name, descr);
  }
}
float=_array;
double=_array;
char=_array;
short=_array;
int=_array;
long=_array;
pointer=_array;
string=_array;

func void(obj, name, prefix1, prefix2) {
  output += swrite(format="%s %s (void) []\n", prefix1, name);
}

func symlink(obj, name, prefix1, prefix2) {
  output += swrite(format="%s %s (%s) \"%s\"\n", prefix1, name, typeof(obj),
    name_of_symlink(obj));
}

func _closure(obj, name, prefix1, prefix2) {
  this = use();
  output += swrite(format="%s %s (closure)\n", prefix1, name);
  if(curdepth == maxdepth || 4 > maxchild)
    return;
  this, _recurse, obj.function_name, "function_name", prefix2, 1;
  this, _recurse, obj.data_name, "data_name", prefix2, 1;
  this, _recurse, obj.function, "function", prefix2, 1;
  this, _recurse, obj.data, "data", prefix2, 2;
}
closure = _closure

obj_show = __closure(obj_show, restore(tmp));
restore, scratch;
