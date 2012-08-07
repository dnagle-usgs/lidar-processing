// vim: set ts=2 sts=2 sw=2 ai sr et:

func json_log_load(fn) {
/* DOCUMENT json_log_load(fn)
  Loads a json log file, which is a text file where each row is a JSON record.
  Returns an oxy group that corresponds.
*/
  f = open(fn, "r");

  result = save();
  while(line = rdline(f)) {
    grp = json_decode(line, objects="");

    if(grp(*) != 1)
      continue;

    parent = grp(*,1);
    grp = grp(1);

    if(!result(*,parent))
      save, result, noop(parent), save();
    current = result(noop(parent));

    keys = set_difference(grp(*,), "soe");
    for(i = 1; i <= numberof(keys); i++) {
      tmp = grp(keys(i));
      save, tmp, soe=grp.soe;

      if(!current(*,keys(i)))
        save, current, keys(i), save();
      save, current(keys(i)), string(0), tmp;
    }
  }
  close, f;

  for(i = 1; i <= result(*); i++) {
    for(j = 1; j <= result(noop(i))(*); j++) {
      save, result(noop(i)), noop(j), obj_transpose(result(noop(i),noop(j)), ary=1);
    }
  }

  return result;
}

func json_log_key_summary(data) {
/* DOCUMENT json_log_key_summary(data)
  Returns an oxy group object summarizing the content of the JSON log data in
  DATA. This is intended to be used primarily by the GUI.
*/
  result = save();
  for(i = 1; i <= data(*); i++) {
    parent = data(noop(i));
    res1 = save();
    for(j = 1; j <= parent(*); j++) {
      child = parent(noop(j));
      res2 = save();
      for(k = 1; k <= child(*); k++) {
        save, res2, child(*,k), strtrim(info(child(noop(k)))(sum));
      }
      save, res1, parent(*,j), res2;
    }
    save, result, data(*,i), res1;
  }
  return result;
}

func tky_json_log_summary(cmd, data) {
/* DOCUMENT tky_json_log_summary, cmd, data;
  Glue function for l1pro::eaarlb::json_log::gui that sends summary data for a
  json log file to a Laser Log Explorer GUI using the given Tcl command prefix.
  Data is sent in JSON format.
*/
  summary = json_log_key_summary(data);
  json = json_encode(summary);
  tkcmd, swrite(format="%s {%s}", cmd, json);
}

func tky_json_log_plot(data, key, cat, y, x, line=, marker=, win=, xfma=) {
/* DOCUMENT tky_json_log_plot, y, x, line=, marker=, win=, xfma=
  Simple wrapper around plg and plmk for use by the Laser Log Explorer GUI.
*/
  local type, color, size;
  default, line, "hide";
  default, marker, "hide";
  default, win, 17;
  default, xfma, 1;

  Y = data(noop(key), noop(cat), noop(y));
  X = data(noop(key), noop(cat), noop(x));

  wbkp = current_window();
  window, win;
  if(xfma) fma;
  if(strpart(line, :4) != "hide") {
    parse_plopts, line, type, color, size;
    plg, Y, X, type=type, color=color, width=size;
  }
  if(strpart(marker, :4) != "hide") {
    parse_plopts, marker, type, color, size;
    plmk, Y, X, marker=type, color=color, msize=size;
  }
  x = regsub("_", x, "!_", all=1);
  y = regsub("_", y, "!_", all=1);
  xytitles, x, y;
  pltitle, regsub("_", cat, "!_", all=1);
  window_select, wbkp;
}
