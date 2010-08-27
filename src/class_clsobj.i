// vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab:

scratch = save(tmp, scratch);
tmp = save(set, apply, remove, drop, classes, query, where, grow);

func clsobj(base, count) {
   obj = save(count, data=save());
   obj_copy, base, obj;
   return obj;
}

func set(class, vals) {
   if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
      error, "invalid classification name: " + class;
   use, count, data;
   vals = bool(vals);
   if(is_scalar(vals))
      vals = array(vals, count);
   if(numberof(vals) != count)
      error, "invalid number of vals";
   save, data, noop(class), vals;
}

func apply(class, idx) {
   if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
      error, "invalid classification name: " + class;
   use, count, data;
   val = data(*,class) ? data(noop(class)) : array(char, count);
   val(idx) = 1;
   save, data, noop(class), val;
}

func remove(class, idx) {
   if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
      error, "invalid classification name: " + class;
   use, count, data;
   val = data(*,class) ? data(noop(class)) : array(char, count);
   val(idx) = 0;
   save, data, noop(class), val;
}

func drop(class) {
   if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
      error, "invalid classification name: " + class;
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
   strtrim, expr;

   // simple query - bare class name that exists
   if(data(*,expr))
      return data(noop(expr));

   // simple query - bare class name that does not exist
   if(regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", expr))
      return array(char, count);

   // null query
   if(!strlen(expr))
      return array(char, count);

   // complicated query -- parse and convert to postfix stack
   postfix = deque();
   opstack = deque();
   while(strlen(expr)) {
      // Check for operators
      if(anyof(strpart(expr, :2) == ["==", "!="])) {
         while(anyof(opstack(last,) == ["!", "==", "!="]))
            postfix, push, opstack(pop,);
         opstack, push, strpart(expr, :2);
         expr = strtrim(strpart(expr, 3:), 1);
      } else if(strpart(expr, :1) == "!") {
         while(opstack(last,) == "!")
            postfix, push, opstack(pop,);
         opstack, push, "!";
         expr = strtrim(strpart(expr, 2:), 1);
      } else if(strpart(expr, :1) == "&") {
         while(anyof(opstack(last,) == ["!", "==", "!=", "&"]))
            postfix, push, opstack(pop,);
         opstack, push, "&";
         expr = strtrim(strpart(expr, 2:), 1);
      } else if(strpart(expr, :1) == "~") {
         while(anyof(opstack(last,) == ["!", "==", "!=", "&", "~"]))
            postfix, push, opstack(pop,);
         opstack, push, "~";
         expr = strtrim(strpart(expr, 2:), 1);
      } else if(strpart(expr, :1) == "|") {
         while(anyof(opstack(last,) == ["!", "==", "!=", "&", "~", "|"]))
            postfix, push, opstack(pop,);
         opstack, push, "|";
         expr = strtrim(strpart(expr, 2:), 1);
      // Handle parentheses
      } else if(strpart(expr, :1) == "(") {
         opstack, push, "(";
         expr = strtrim(strpart(expr, 2:), 1);
      } else if(strpart(expr, :1) == ")") {
         while(opstack(count,) && opstack(last,) != "(")
            postfix, push, opstack(pop,);
         if(!opstack(count,))
            error, "mismatched parentheses";
         opstack, pop;
         expr = strtrim(strpart(expr, 2:), 1);
      // Handle classification names; store as values
      } else {
         offset = strgrep("^[a-zA-Z_][a-zA-Z_0-9]*", expr);
         if(offset(2) == -1)
            error, "invalid input";
         postfix, push, use(query, strpart(expr, offset));
         expr = strtrim(strpart(expr, offset(2)+1:), 1);
      }
   }
   while(opstack(count,)) {
      if(opstack(last,) == "(")
         error, "mismatched parentheses";
      postfix, push, opstack(pop,);
   }
   opstack = [];

   // Evaluate postfix queue
   work = deque();
   while(postfix(count,)) {
      token = postfix(shift,);
      if(!is_string(token)) {
         work, push, token;
      } else if(token == "!") {
         if(work(count,) < 1)
            error, "invalid input";
         work, push, !work(pop,);
      } else if(work(count,) < 2) {
         error, "invalid input";
      } else {
         A = work(pop,);
         B = work(pop,);
         if(token == "==")
            work, push, A == B;
         else if(token == "!=")
            work, push, A != B;
         else if(token == "&")
            work, push, A & B;
         else if(token == "~")
            work, push, A ~ B;
         else if(token == "|")
            work, push, A | B;
         else
            error, "invalid input";
      }
   }
   if(work(count,) == 1)
      return work(pop,);
   else
      error, "invalid input";
}

func where(expr) {
   return where(use(query, expr));
}

func grow(obj) {
   use, data, count;

   thiscount = count;
   thatcount = obj.count;
   count = thiscount + thatcount;

   // Split up class names into three lists:
   // left - classes only the current object has
   // both - classes they both have
   // right - classes only the incoming object has
   classes = set_intersect3(use(classes,), obj(classes,));

   // Any classes the incoming object doesn't have can get extended with 0's
   numleft = numberof(classes.left);
   for(i = 1; i <= numleft; i++) {
      curclass = classes.left(i);
      this = use(query, curclass);
      that = array(char(0), thatcount);
      save, data, noop(curclass), grow(this, that);
   }

   // Any classes they both have can get appended together
   numboth = numberof(classes.both);
   for(i = 1; i <= numboth; i++) {
      curclass = classes.both(i);
      this = use(query, curclass);
      that = obj(query, curclass);
      save, data, noop(curclass), grow(this, that);
   }

   // Any classes the current object lacks get prefilled with 0's
   numright = numberof(classes.right);
   for(i = 1; i <= numright; i++) {
      curclass = classes.right(i);
      this = array(char(0), thiscount);
      that = obj(query, curclass);
      save, data, noop(curclass), grow(this, that);
   }
}

clsobj = closure(clsobj, restore(tmp));
restore, scratch;
