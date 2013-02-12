// vim: set ts=2 sts=2 sw=2 ai sr et:

local handler_func;
/* DOCUMENT Handler Functions
  Functions that will be used as handlers (via handler_set) should follow this
  template:

    func example_handler(env) {
      // Do stuff...
      return env;
    }

  Handler functions will always be called with one argument, ENV, which is an
  oxy group containing variables from the calling context. The handler function
  is expected to return that ENV object, possibly with modifications made.
  Handler functions are allowed to modify variables defined in ENV. However,
  they should not add new variables. (They should also not remove variables;
  doing so is equivalent to leaving them unmodified.)

  To find out what variables are passed as part of ENV for a given handler, you
  will need to consult the code where the handler is invoked.

  SEE ALSO: handler_set, handler_clear, handler_get, handler_has,
  handler_invoke
*/

scratch = save(scratch, handlers);

// If handler_set is a closure, then retrieve its data chunk to avoid losing
// any existing handlers. Otherwise, initialize as an empty oxy object.
handlers = (is_func(handler_set) == 5) ? handler_set.data : save();

func handler_set(handlers, handler_name, func_name) {
/* DOCUMENT handler_set, "<handler_name>", "<func_name>"
  Sets a function for a handler. Functions are specified by name. Do -not- pass
  a function in as a function, always provide its name.

  SEE ALSO: handler_clear, handler_get, handler_has, handler_invoke,
  handler_func
*/
  save, handlers, noop(handler_name), func_name;
}

func handler_clear(handlers, handler_name) {
/* DOCUMENT handler_clear, "<handler_name>"
  Clears the function associated with a handler name. (Does nothing if no
  function is set.)

  SEE ALSO: handler_set, handler_get, handler_has, handler_invoke, handler_func
*/
  save, handlers, noop(handler_name), string(0);
}

func handler_get(handlers, handler_name) {
/* DOCUMENT handler_get("<handler_name>")
  Returns the function for a given handler name, or [] if none is set.

  SEE ALSO: handler_set, handler_clear, handler_has, handler_invoke,
  handler_func
*/
  // If there is no handler set, return nothing
  if(!handlers(*,handler_name)) return;
  // If the handler set is the null string, return nothing
  if(!handlers(noop(handler_name))) return;

  return handlers(noop(handler_name));
}

func handler_has(handler_name) {
/* DOCUMENT handler_has("<handler_name>")
  Returns 1 if the specified handler name has a function set; 0 otherwise.

  SEE ALSO: handler_set, handler_clear, handler_get, handler_invoke,
  handler_func
*/
  return !is_void(handler_get(handler_name));
}

func handler_invoke(handlers, handler_name, &env) {
/* DOCUMENT handler_invoke("<handler_name>", env)
  Invokes a handler. This will result in the function attached to that handler
  being called. There are two ways to use this function. The normal case (where
  variables from the current context will be passed to the handler function)
  is:

    restore, handler_invoke("handler_name", save(foo, bar, ..));

  Where "handler_name" should be the name of the handler and "foo, bar, .."
  should be a list of variables in the current context to provide to the
  handler function.

  If no variables need to be provided to the handler function, then this
  shorter case may instead be used:

    handler_invoke, "handler_name";

  It is permissible for a handler invocation to later add additional variables.
  However, a handler invocation should not remove variables without first
  making sure nothing is referencing that variable.

  The variable names passed in to ENV should be fairly descriptive. If calling
  context is using a poorly named variable, update that code to use a
  well-named variable -before- adding the handler.

  IMPORTANT: This function will throw an error if there is no handler set. So
  you should generally wrap this with "handler_has".

    if(handler_has("<handler_name>")) {
      restore, handler_invoke("<handler_name>", save(foo, bar, ..));
    } else {
      // default action if no handler is set, which might be an error or
      // warning message
    }

  SEE ALSO: handler_set, handler_clear, handler_get, handler_has, handler_func
*/
  func_name = handler_get(handler_name);
  if(is_void(func_name))
    error, "no handler set for "+handler_name;
  env = symbol_def(func_name)(env);
  return env;
}

handler_set = closure(handler_set, handlers);
handler_clear = closure(handler_clear, handlers);
handler_get = closure(handler_get, handlers);
handler_invoke = closure(handler_invoke, handlers);
restore, scratch;
