// vim: set ts=2 sts=2 sw=2 ai sr et:

local tksync;
/* DOCUMENT tksync
  Provides functionality to keep Tcl/Tk updated with changes to Yorick
  variables.

  The primary two methods are:

    tksync, add, "<yvar>", "<tkvar>"
      Adds monitoring to <yvar> to update <tkvar>.
    tksync, remove, "<yvar>", "<tkvar>"
      Removes monitoring on <yvar> for <tkvar>

  Both arguments must be strings. <yvar> may be a simple Yorick variable
  name, or it may be an oxy or Yeti hash element using dot notation. Some
  examples of valid <yvar> values: "myvar", "myobj.item". <tkvar> may be any
  Tcl variable, including array members. Examples of valid <tkvar> values:
  "myglobalvar", "::myns::myvar", "::myary(key)".

  Both of the above method will also accept arrays of values, provided both
  arrays are of the same size. This lets you define multiple pairs to sync in
  one call.

  There are two additional methods.

    tksync, check
      Checks to see if any Yorick variables have changed and, if so, sends an
      update to Tcl. This normally isn't needed, but it may be helpful to
      call during a long-running process if you know you just updated a
      variable used in the GUI.

    tksync, background
      Schedules a background process. When Yorick is idle, this will
      periodically call tksync,check. This background process is
      automatically kicked off at startup. To cancel it, run:
        after, 0, tksync, background
      To start it back up, just run the command normally again:
        tksync, background

  By default, tksync,background schedules itself every 0.25 seconds. If you
  want to change that interval, you can update the interval member. For
  example, this makes it schedule every 1.5 seconds:

    save, tksync, interval=1.5;
*/

scratch = save(scratch, tmp, tksync_add, tksync_remove, tksync_check,
  tksync_background);
tmp = save(cache, interval, add, remove, check, background);

if(is_obj(tksync) && is_obj(tksync.cache)) {
  cache = tksync.cache;
} else {
  cache = save();
}
if(is_obj(tksync) && is_numerical(tksync.interval)) {
  interval = tksync.interval;
} else {
  interval = 0.25;
}

func tksync_add(yvar, tkvar) {
  cache = tksync.cache;

  count = numberof(yvar);
  if(numberof(tkvar) != count) error, "count mismatch";

  for(i = 1; i <= count; i++) {
    // Retrieve value for current yvar
    val = var_expr_get(yvar(i));

    // Initialize a cache entry if needed
    if(!cache(*,yvar(i))) {
      save, cache, yvar(i), save(val, tkvars=[]);
    }

    // Update the list of tkvars and save to cache
    tkvars = set_remove_duplicates(grow(tkvar(i), cache(yvar(i)).tkvars));
    save, cache(yvar(i)), tkvars;

    // Initialize variable in Tk
    tksetval, tkvar, val;
  }

  save, tksync, cache;
}
add = tksync_add;

func tksync_remove(yvar, tkvar) {
  cache = tksync.cache;

  count = numberof(yvar);
  if(numberof(tkvar) != count) error, "count mismatch";

  for(i = 1; i <= count; i++) {
    // If yvar isn't present, nothing to do
    if(!cache(*,yvar(i))) continue;

    // Remove tkvar if present
    tkvars = set_difference(cache(yvar(i)).tkvars, tkvar(i));

    // Update cache -- either with new shorter tkvars list or by removing
    // entry from cache entirely
    if(numberof(tkvars)) {
      save, cache(yvar(i)), tkvars;
    } else {
      obj_delete, cache, yvar(i);
    }
  }

  save, tksync, cache;
}
remove = tksync_remove;

func tksync_check(void) {
  cache = tksync.cache;

  for(i = 1; i <= cache(*); i++) {
    val = var_expr_get(cache(*,i));

    // If cached value matches current value, then no need to update Tk
    // (Updating when not needed would spam Tk horribly)
    if(val == cache(noop(i)).val) continue;

    tkvars = cache(noop(i)).tkvars;
    for(j = 1; j <= numberof(tkvars); j++) {
      tksetval, tkvars(j), val;
    }
    save, cache(noop(i)), val;
  }

  save, tksync, cache;
}
check = tksync_check;

func tksync_background(void) {
  // Cancel any scheduled background requests (to avoid having several going
  // at once)
  after, -, tksync, background;
  // Check for updated variables
  tksync, check;
  // Schedule a new background request
  after, tksync.interval, tksync, background;
}
background = tksync_background;

tksync = restore(tmp);
restore, scratch;

tksync, background;
