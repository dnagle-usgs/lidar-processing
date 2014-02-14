
local filters_create, filters_apply, filters_merge;
/* DOCUMENT
  stack = filters_create(<name1>=save(...), <name2>=save(...), prev=, next=):
  stack = filters_merge(stack, prev=, next=);
  filters_apply, &input, state, stack, name;

  These functions provide a basic framework for handling a filter stack.

  A "filter" is a function that performs some action on an input. A filter
  stack contains information about a series of filters that should be applied
  to an input, in order.

  The function to be used as a filter should have this call signature:
      func myfilter(&input, filter, state) {}
  The parameters are:
    input, which is the data to be acted upon in some way. This is an output
      parameter, so that it can be modified in place.
    filter, which is an oxy group containing parameters supplied to the filter
      stack that will be of use to this filter function.
    state, which is an oxy group containing parameters supplied by the calling
      context.

  A filter stack is an oxy group containing one or more named members. Each
  member is an oxy group that defines a filter operation. A filter operation
  must have one member named "function" that defines the function to call. The
  filter operation group will be passed to the filter function as its "filter"
  parameter and may contain any number of additional members to be used by the
  filter function. Each filter operation may reference another filter operation
  using a "next" member, allowing a series of filters to be chained.

  A filter operation group has three reserved member names: function, next, and
  prev. The names "function" and "next" are reserved because they have uses as
  described above. The name "prev" is also reserved for symmetry to "next", and
  so that it is easier to contruct the groups via utility functions.

  The filter stack has two reserved names, "prev" and "next". The other names
  (supplied by the user) describe individual filter operations series. For
  example, dirload allows the caller to apply filtering on "files" (the list of
  files to examine), "data" (data as loaded from a single file), and "merged"
  (the final merged data).

  Here is a contrived example of a filter stack:

    filters = save(
      files=save(
        function=filter_func_1,
        mode="fs",
        next=save(
          function=filter_func_2,
          mode="fs",
          buffer=100
        )
      ),
      data=save(
        function=filter_func_3,
        next=save(
          function=filter_func_4,
          date="2000-01-01"
        )
      )
    );

  -- filters_create --
  This function is a simple wrapper around filters_merge for convenience. It
  wraps ups its arguments as an oxy group (except for prev= and next=), then
  passes that along with prev= and next= to filters_merge.

  So this:
    stack = filters_create(
      foo=save(function=myfilter1),
      bar=save(function=myfilter2, mode="fs"),
      prev=stack_prev,
      next=stack_next
    );

  Is equivalent to this:
    stack = filters_merge(
      save(
        foo=save(function=myfilter1),
        bar=save(function=myfilter2, mode="fs")
      ),
      prev=stack_prev,
      next=stack_next
    );

  This is the function that will typically be used to construct filter stacks.

  -- filters_merge --
  Merges two or three filter stacks together.

    stack = filters_merge(stack, prev=, next=);

  All three parameters should be function stacks. They will be merged together
  so that the ordering prev -> stack -> next is ensured.

  -- filters_apply --
  Applies a named filter in a filter stack to an input.

    filters_apply, &input, state, stack, name

  INPUT and STATE are as described earlier in terms of inputs to filtering
  functions. STACK is a filtering stack, and NAME specifies which named filter
  in the stack to use. Two examples of calls:

    filters_apply, data, save(), stack, "example1"
    filters_apply, data, save(foo=1, bar=2), stack, "example2"

  This is used within a function that wants to allow the caller to apply
  filters to it internally.
*/

func filters_create(args) {
// filters = filters_create(foo=save(function=...), prev=, next=)
  filters = args2obj(args);
  prev = filters.prev;
  next = filters.next;
  w = where(filters(*,) != "prev" & filters(*,) != "next");
  filters = filters(noop(w));
  return filters_merge(filters, prev=prev, next=next);
}

func filters_merge(stack, prev=, next=) {
  if(!stack) stack = save();
  if(prev) stack = filters_merge(prev, next=stack);
  if(next) {
    keys = next(*,);
    kcount = numberof(keys);
    for(i = 1; i <= kcount; i++) {
      if(stack(*,keys(i))) {
        temp = stack(keys(i));
        while(temp.next) temp = temp.next;
        save, temp, next=next(keys(i));
      } else {
        save, stack, keys(i), next(keys(i));
      }
    }
  }
  return stack;
}

func filters_apply(&input, state, stack, name) {
  if(!stack(*,name)) return;
  filter = stack(noop(name));
  while(filter) {
    f = filter.function;
    if(is_string(f)) f = symbol_def(f);
    f, input, filter, state;
    filter = filter.next;
  }
}
