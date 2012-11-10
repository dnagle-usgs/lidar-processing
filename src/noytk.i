require, "logger.i";

// Provides many of the functions provided by YTK as no-op replacements that
// log a warning. This will try to let ALPS continue running when it tries to
// use YTK when it's not present, but may not always be successful.

func initialize_ytk(ytk_fn, tky_fn) {
  if(logger(warn))
    logger, warn, "call to initialize_ytk when not running YTK";
}

func open_tkcmd_fifo(fn) {
  if(logger(warn))
    logger, warn, "call to open_tkcmd_fifo when not running YTK";
}

func open_tky_fifo(fn) {
  if(logger(warn))
    logger, warn, "call to open_tky_fifo when not running YTK";
}

func tkcmd(s, async=) {
  if(logger(warn))
    logger, warn, "call to tkcmd when not running YTK:\n  "+pr1(s);
}


func tksetval(tkvar, yval) {
  if(logger(warn))
    logger, warn, "call to tksetval when not running YTK:\n"+
      "  tkvar="+pr1(tkvar)+" yval="+pr1(yval);
}

func tksetvar(tkvar, yvar) {
  if(logger(warn))
    logger, warn, "call to tksetvar when not running YTK:\n"+
      "  tkvar="+pr1(tkvar)+" yvar="+pr1(yvar);
}

func tksetsym(tkvar, ysym) {
  if(logger(warn))
    logger, warn, "call to tksetsym when not running YTK:\n"+
      "  tkvar="+pr1(tkvar)+" ysym="+pr1(ysym);
}

func tksetfunc(tkvar, yfunc, ..) {
  if(logger(warn)) {
    msg = "call to tksetfunc when not running YTK:\n";
    msg += "  tkvar="+pr1(tkvar);
    msg += "  yfunc="+pr1(yfunc);
    while(more_args())
      msg += "  (arg)="+pr1(next_arg());
    logger, warn, msg;
  }
}

func var_expr_tkupdate(expr, tkval) {
  if(logger(warn))
    logger, warn, "call to var_expr_tkupdate when not running YTK:\n"+
      "  expr="+pr1(expr)+" tkval="+pr1(tkval);
}

func var_expr_get(expr) {
  if(logger(warn))
    logger, warn, "call to var_expr_get when not running YTK:\n"+
      "  expr="+pr1(expr);
}

func var_expr_set(expr, val) {
  if(logger(warn))
    logger, warn, "call to var_expr_set when not running YTK:\n"+
      "  expr="+pr1(expr)+" val="+pr1(val);
}

func source(fn) {
  if(logger(warn))
    logger, warn, "call to source when not running YTK:\n"+
      "  fn="+pr1(fn);
}
