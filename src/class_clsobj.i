// vim: set ts=2 sts=2 sw=2 ai sr et:

// To avoid name collisions breaking help, some functions get temporarily named
// with an underscore prefix.
scratch = save(scratch, tmp, clsobj_set, clsobj_apply, clsobj_remove,
  clsobj_drop, clsobj_classes, clsobj_query, clsobj_where, clsobj_grow,
  clsobj_index, clsobj_serialize);
tmp = save(__bless, set, apply, remove, drop, classes, query, where, grow,
  index, serialize, help);

__bless = "clsobj";
func clsobj(base, count) {
/* DOCUMENT clsobj()
  Creates a classification object. This can be called in one of two ways:

    data = clsobj(count)
      Creates an empty classification object that is allocated for COUNT
      items.
    data = clsobj(chardata)
      Restores a classification object using an array of character data
      CHARDATA, as returned by the serialize method.

  A clsobj object is comprised of two data members as well as various methods.
  In the documentation below, "data" is the result of a call to clsobj.

  Data members:
    data(count,)        long
      The number of items that this object is configured to classify. This
      number must not be changed by the user.
    data(data,)         group object
      This stores the classification data. Group member names are the
      classification names, and their values are character arrays indicating
      whether the class applies or not for each item. The end user should
      not interact with this directly in any way!! Its implementation is not
      guaranteed to remain constant. You should be able to get any
      information you'd want from this via the object's methods.

  Methods:
    data, help
      Displays this help documentation.
    data(serialize,)
      Returns an array of type char that represents the data stored in the
      object. This character array is opaque; outside code should not try to
      modify it. The classification object can be restored later by calling
      clsobj with this character data as its argument.
    data, set, class, vals
      Sets the values for classification CLASS to VALS. VALS must be either
      a scalar value (which is applied to all data points) or a vector whose
      size matches data(count,).
    data, apply, class, idx
      Applies the specified classification CLASS to the indices specified by
      IDX. Other indices are left unmodified. If CLASS did not previously
      exist, then all other values will be 0.
    data, remove, class, idx
      Removes the specified classification CLASS from the indices specified
      by IDX. Other indices are left unmodified. If CLASS did not previously
      exist, then all other values will be 0.
    data, drop, class
      Completely removes classification CLASS.
    data(classes,)
      Returns an array of the classifications currently in use by the
      object.
    data(query, expr)
      Performs a query on the classifications. The return result will be an
      array of size "count" (as from "data(count,)") where 1 indicates that
      the data point matches the expression EXPR and 0 indicates that it
      does not. See the section further below for information on
      expressions.
    data(where, expr)
      This is similar to data(query, expr) above. However, instead of
      returning a boolean array result, this returns an index list
      corresponding to it. It is exactly equivalent to where(data(query,
      expr)).
    data, grow, obj
      Appends the data from OBJ to the current object. If DATA had 10 items
      and OBJ had 5, then after the grow items 1-10 match the original DATA
      and items 11-15 match OBJ's data. Classes that do not exist in one or
      the other object are initialized to zeroes for that object's points.

  Classification names:
    The various methods that accept a classification name are constricted on
    what kind of input they will provide. A classification name must start
    with an alphabetic character or an underscore, and may be followed by any
    number of alphanumeric characters or underscores. In glob terms:
      [a-zA-Z_][a-zA-Z0-9_]*
    No spaces or other punctuation is allowed. The name may not start with a
    number. These rules are exactly the same as those imposed on Yorick
    variable names.

  Query expressions:
    The query and where methods accept expressions as their argument. An
    expression is a string. In the simplest case, this string is a
    classification name. So if you have a classification object "data" with
    classifications "first_return" and "last_return", you might make these
    calls:
      result = data(query, "first_return")
      w = data(where, "last_return")

    However, expressions can also be more complicated than that. Expressions
    accept a very limited subset of the Yorick language. The following
    operators are permitted:
      !     not/negation
      ==    equality
      !=    not equal
      &     and
      ~     xor
      |     or
    In addition to those operators, parentheses may be used for grouping. You
    may not use any other symbols, exept for whitespace and classification
    names. If you use invalid symbols or syntax, you will receive an error.

    Follows are some examples of more complex queries.

    Return all bare earth points that are also first returns:
      w = data(where, "bare_earth & first_return")
    Return all bare earth points that are not first returns:
      w = data(where, "bare_earth & !first_return")
    Return all canopy points that are neither first nor last returns.
      w = data(where, "canopy & !(first_return | last_return)")
    Return all points that are either first or last returns, but that are not
    both.
      w = data(where, "first_return ~ last_return")
*/
  data = save();
  if(numberof(count) > 1) {
    bits = count;

    zeroes = !bits;
    w = where(zeroes(:-1) & zeroes(2:));
    if(!numberof(w))
      error, "invalid data";

    // special case for no classes
    if(w(1) == 1) {
      count = numberof(bits);
      numclasses = 0;
    } else {
      classes = strchar(bits(:w(1)));
      bits = bits(w(1)+2:);
      numclasses = numberof(classes);
      count = numberof(bits) / long(ceil(numclasses/8.));
      bits = reform(bits, count, numberof(bits)/count);

      pos = 1;
      pow = 0;
      for(i = 1; i <= numclasses; i++) {
        save, data, classes(i), bool(2^pow & bits(,pos));
        pow++;
        if(pow == 8) {
          pos++;
          pow = 0;
        }
      }
    }
  } else if(!count) {
    error, "must provide either a count or data to restore";
  }
  obj = save(count, data);
  obj_copy, base, obj;
  return obj;
}

func clsobj_serialize(nil) {
  use, count, data;
  classes = use(classes,);
  numclasses = numberof(classes);
  // special case for no classes
  if(!numclasses)
    return array(char(0), count);
  bits = array(char, count, long(ceil(numclasses/8.)));

  pos = 1;
  pow = 0;
  for(i = 1; i <= numclasses; i++) {
    bits(,pos) |= data(classes(i)) << pow;
    pow++;
    if(pow == 8) {
      pos++;
      pow = 0;
    }
  }

  classes = strchar(classes);

  return grow(classes, char(0), bits(*));
}
serialize = clsobj_serialize;

func clsobj_set(class, vals) {
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
set = clsobj_set;

func clsobj_apply(class, idx) {
  if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
    error, "invalid classification name: " + class;
  use, count, data;
  val = data(*,class) ? data(noop(class)) : array(char, count);
  val(idx) = 1;
  save, data, noop(class), val;
}
apply = clsobj_apply;

func clsobj_remove(class, idx) {
  if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
    error, "invalid classification name: " + class;
  use, count, data;
  val = data(*,class) ? data(noop(class)) : array(char, count);
  val(idx) = 0;
  save, data, noop(class), val;
}
remove = clsobj_remove;

func clsobj_drop(class) {
  if(!regmatch("^[a-zA-Z_][a-zA-Z_0-9]*$", class))
    error, "invalid classification name: " + class;
  use, data;
  if(!data(*))
    return;
  keys = data(*,);
  w = where(keys != class);
  data = numberof(w) ? data(noop(w)) : save();
}
drop = clsobj_drop;

func clsobj_classes(nil) {
  use, data;
  return data(*,);
}
classes = clsobj_classes;

func clsobj_query(expr) {
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
  return math_eval_infix(expr, operators=["!", "==", "!=", "&", "~", "|"],
    variables=data, missing=array(char, count), accept_numbers=0);
}
query = clsobj_query;

func clsobj_where(expr) {
  return where(use(query, expr));
}
where = clsobj_where;

func clsobj_grow(obj) {
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
grow = clsobj_grow;

func clsobj_index(idx) {
  res = am_subroutine() ? use() : obj_copy(use(), recurse=1);
  if(is_string(idx))
    idx = use(where, idx);
  obj_index, res, idx;
  clsobj, res;
  return res;
}
index = clsobj_index;

help = closure(help, clsobj);

clsobj = closure(clsobj, restore(tmp));
restore, scratch;
