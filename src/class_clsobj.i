// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

scratch = save(tmp, scratch);
tmp = save(set, apply, remove, drop, classes, query, where);

func clsobj(base, count) {
   obj = save(count, data=save());
   obj_copy, base, obj;
   return obj;
}

func set(class, vals) {
   use, count, data;
   vals = bool(vals);
   if(is_scalar(vals))
      vals = array(vals, count);
   if(numberof(vals) != count)
      error, "invalid number of vals";
   save, data, noop(class), vals;
}

func apply(class, idx) {
   use, count, data;
   val = data(*,class) ? data(noop(class)) : array(char, count);
   val(idx) = 1;
   save, data, noop(class), val;
}

func remove(class, idx) {
   use, count, data;
   val = data(*,class) ? data(noop(class)) : array(char, count);
   val(idx) = 0;
   save, data, noop(class), val;
}

func drop(class) {
   use, data;
   if(!data(*))
      return;
   keys = data(*,);
   w = where(keys != class);
   data = numberof(w) ? data(noop(w)) : save();
}

func classes(nil) {
   use, data;
   return data(*,);
}

func query(expr) {
   use, count, data;
   if(data(*,expr))
      return data(noop(expr));
   return array(char, count);
}

func where(expr) {
   return where(use(query, expr));
}

clsobj = closure(clsobj, restore(tmp));
restore, scratch;
