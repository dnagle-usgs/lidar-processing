// vim: set ts=3 sts=3 sw=3 ai sr et:

scratch = save(scratch, tmp, deque_push, deque_pop, deque_unshift, deque_shift,
   deque_first, deque_last, deque_count, deque_help);
tmp = save(data, push, pop, unshift, shift, first, last, count, help);

func deque(base, data) {
/* DOCUMENT deque()
   Creates a double-ended queue ("deque") object. This can be called in one of
   two ways.

      data = deque()
         Without any arguments, DATA is an empty deque.
      data = deque(items)
         When passed an argument, the argument must be a group object that
         should serve as the initial data to store within the deque (as its
         "data" member).

   The deque object is comprised of a single data member and seven methods. In
   the documentation below, an object named "data" is used to represent an
   instance of a deque object.

      data, help
         Displays this documentation.

      data.data
      data(data,)
         This is the data member. The items stored in the deque are kept here.
         Items added by deque methods will be anonymous.

      data, push, item1, item2, item3, ...
      data(push, item1, item2, item3, ...)
         Pushes one or more items onto the end of the deque. If called as a
         function, returns the total number of items in the deque.

      data, pop
      data(pop,)
         Removes the last item from the deque, returning it if called as a
         function. If no items are in the deque, this is a no-op and [] will be
         returned.

      data, unshift, item1, item2, item3, ...
      data(unshift, item1, item2, item3, ...)
         Pushes one or more items onto the front of the deque. Their order is
         maintained, so that the first item given becomes the first item in the
         deque, the second item given becomes the second item in the deque, and
         so on. If called as a function, returns the total number of items in
         the deque.

      data, shift
      data(shift,)
         Removes the first item from the deque, returning it if called as a
         function. If no items are in the deque, this is a no-op and [] will be
         returned.

      data(first,)
      data(last,)
         Returns the first or last item of the deque, or [] if it is empty.

      data(count,)
         Returns the number of items in the deque.

   A deque can serve as a stack by only using push/pop. It can serve as a queue
   by only using push/shift.
*/
   obj = obj_copy(base);
   data = is_void(data) ? save() : obj_copy(data);
   save, obj, data;
   return obj;
}

func deque_push(val, ..) {
   use, data;
   save, data, string(0), val;
   while(more_args())
      save, data, string(0), next_arg();
   return data(*);
}
push = deque_push;

func deque_pop(nil) {
   use, data;
   result = data(*) ? data(0) : [];
   data = (data(*) > 1 ? data(:-1) : save());
   return result;
}
pop = deque_pop;

func deque_unshift(val, ..) {
   use, data;
   count = data(*);
   save, data, string(0), val;
   while(more_args())
      save, data, string(0), next_arg();
   data = data(long(roll(indgen(data(*)), data(*)-count)));
   return data(*);
}
unshift = deque_unshift;

func deque_shift(nil) {
   use, data;
   result = data(*) ? data(1) : [];
   data = (data(*) > 1 ? data(2:) : save());
   return result;
}
shift = deque_shift;

func deque_first(nil) {
   use, data;
   return data(*) ? data(1) : [];
}
first = deque_first;

func deque_last(nil) {
   use, data;
   return data(*) ? data(0) : [];
}
last = deque_last;

func deque_count(nil) {
   use, data;
   return data(*);
}
count = deque_count;

help = closure(help, deque);

deque = closure(deque, restore(tmp));
restore, scratch;
