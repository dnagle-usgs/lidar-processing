// vim: set ts=2 sts=2 sw=2 ai sr et:

local hook_func;
/* DOCUMENT Hook Functions
  Functions that will be used as hooks (via hook_add) should follow this
  template:

    func example_hook(env) {
      // Do stuff...
      return env;
    }

  Hook functions will always be called with one argument, ENV, which is an oxy
  group containing variables from the calling context. The hook function is
  expected to return that ENV object, possibly with modifications made. Hook
  functions are allowed to modify variables defined in ENV. However, they
  should not add new variables. (They should also not remove variables; doing
  so is equivalent to leaving them unmodified.)

  To find out what variables are passed as part of ENV for a given hook, you
  will need to consult the code where the hook is invoked.

  SEE ALSO: hook_add, hook_remove, hook_invoke
*/

scratch = save(scratch, hooks);

// If hook_add is a closure, then retrieve its data chunk to avoid losing any
// existing hooks. Otherwise, initialize hooks as an empty oxy object.
hooks = (is_func(hook_add) == 5) ? hook_add.data : save();

func hook_add(hooks, hook_name, func_name, priority) {
/* DOCUMENT hook_add, "<hook_name>", "<func_name>"
  -or- hook_add, "<hook_name>", "<func_name>", <priority>
  Adds a function to a hook. Functions are specified by name. Do -not- pass a
  function in as a function, always provide its name.
  
  If priority is given, it must be a numerical value and specifies when the
  function should be invoked relative to other hooks for this function. Default
  is 0. Functions to be invoked sooner should have lower values, functions to
  be invoked later should have higher values. Functions with the same priority
  will be invoked in an arbitrary order.

  If the hook is already associated with the given function, then its priority
  is updated.

  SEE ALSO: hook_remove, hook_invoke, hook_func
*/
  if(is_void(priority)) priority = 0;
  item = obj2struct(save(func_name, priority));

  // If there are no hooks for this hook name, then initialize it using the
  // specified hook function.
  if(!hooks(*,hook_name)) {
    save, hooks, noop(hook_name), [item];
    return;
  }

  tmp = hooks(noop(hook_name));
  w = where(tmp.func_name == func_name);
  // If the hook already exists, check to see if it has the right priority.
  // Otherwise add it.
  if(numberof(w)) {
    w = w(1);
    if(tmp(w).priority == priority) return;
    tmp(w).priority = priority;
  } else {
    grow, tmp, item;
  }
  tmp = tmp(sort(tmp.priority));
  save, hooks, noop(hook_name), tmp;
}

func hook_remove(hooks, hook_name, func_name) {
/* DOCUMENT hook_remove, "<hook_name>", "<func_name>"
  Removes a function from a hook. Functions are specified by name.
  SEE ALSO: hook_add, hook_invoke, hook_func
*/
  // If there are no hooks for this hook name, then there's nothing to remove.
  if(!hooks(*,hook_name)) return;

  // If the func name is not among the hooks for this hook name, then there's
  // nothing to remove.
  tmp = hooks(noop(hook_name));
  if(noneof(tmp.func_name == func_name)) return;

  // If the func name is among the hooks but there's only one hook, then the
  // end result is no hooks.
  if(numberof(tmp) == 1) {
    save, hooks, noop(hook_name), [];
    return;
  }

  // Otherwise, get rid of the specified hook function.
  w = where(tmp.func_name != func_name);
  save, hooks, noop(hook_name), tmp(w);
}

func hook_query(hooks, hook_name, full=) {
/* DOCUMENT hook_query("<hook_name>")
  -or- hook_query("<hook_name>", full=1)
  Returns a list of all hook functions defined for this hook name.

  If full=1, then it instead returns a list of structs such that
  result.func_name are the functions and result.priority is the corresponding
  priority.
*/
  // If there are no hooks for this hook name, return empty array.
  if(!hooks(*,hook_name)) return;

  // Otherwise, return hooks for this hook name.
  result = hooks(noop(hook_name));
  if(full) return result;
  return result.func_name;
}

func hook_has(hook_name) {
/* DOCUMENT hook_has("<hook_name>")
  Returns a boolean indicating whether the named hook has any hook functions
  associated with it at present.
*/
  return (numberof(hook_query(hook_name)) > 0);
}

func hook_invoke(hooks, hook_name, &env) {
/* DOCUMENT hook_invoke, "<hook_name>", env
  Invokes a hook. This will result in all functions attached to that hook being
  called. There are two ways to use this function. The normal case (where
  variables from the current context will be passed to hook functions) is:

    restore, hook_invoke("hook_name", save(foo, bar, ..));

  Where "hook_name" should be the name of the hook and "foo, bar, .." should be
  a list of variables in the current context to provide to the hook functions.

  If no variables need to be provided to the hook functions, then this shorter
  case may instead be used:

    hook_invoke, "hook_name";

  It is permissible for a hook invocation to later add additional variables.
  However, a hook invocation should not remove variables without first making
  sure nothing is referencing that variable.

  The variable names passed in to ENV should be fairly descriptive. If calling
  context is using a poorly named variable, update that code to use a
  well-named variable -before- adding the hook.

  SEE ALSO: hook_add, hook_remove, hook_func
*/
  if(!hooks(*,hook_name)) return env;

  func_names = hooks(noop(hook_name)).func_name;
  for(i = 1; i <= numberof(func_names); i++)
    env = symbol_def(func_names(i))(env);

  return env;
}

hook_add = closure(hook_add, hooks);
hook_remove = closure(hook_remove, hooks);
hook_query = closure(hook_query, hooks);
hook_invoke = closure(hook_invoke, hooks);
restore, scratch;
