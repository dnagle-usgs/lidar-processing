// vim: set ts=2 sts=2 sw=2 ai sr et:

func lsr_load_json(fn) {
/* DOCUMENT lsr_load_json(fn)
  Loads a laser log file, which is a text file where each row is a JSON record.
  Returns an oxy group that corresponds.
*/
  f = open(fn, "r");

  result = save();
  while(line = rdline(f)) {
    lsr = json_decode(line, objects="");
    if(!lsr(*,"LSR") || !lsr.LSR(*,"soe"))
      continue;

    lsr = lsr.LSR;

    keys = set_difference(lsr(*,), "soe");
    for(i = 1; i <= numberof(keys); i++) {
      grp = lsr(keys(i));
      save, grp, soe=lsr.soe;

      if(!result(*,keys(i)))
        save, result, keys(i), save();
      save, result(keys(i)), string(0), grp;
    }
  }
  close, f;

  for(i = 1; i <= result(*); i++)
    save, result, noop(i), obj_transpose(result(noop(i)), ary=1);

  return result;
}

func lsr_key_summary(data) {
/* DOCUMENT lsr_key_summary(data)
  Returns an oxy group object summarizing the content of the laser data in
  DATA. This is intended to be used primarily by the GUI.
*/
  result = save();
  for(i = 1; i <= data(*); i++) {
    grp = data(noop(i));
    res = save();
    for(j = 1; j <= grp(*); j++) {
      save, res, grp(*,j), strtrim(info(grp(noop(j)))(sum));
    }
    save, result, data(*,i), res;
  }
  return result;
}

func tky_lsr_summary(cmd, data) {
/* DOCUMENT tky_lsr_summary, cmd, data;
  Glue function for l1pro::eaarlb::lsr::gui that sends summary data for a laser
  json file to a Laser Log Explorer GUI using the given Tcl command prefix.
  Data is sent in JSON format.
*/
  summary = lsr_key_summary(data);
  json = json_encode(summary);
  tkcmd, swrite(format="%s {%s}", cmd, json);
}

func tky_lsr_plot(data, cat, y, x, line=, marker=, win=, xfma=) {
/* DOCUMENT tky_lsr_plot, y, x, line=, marker=, win=, xfma=
  Simple wrapper around plg and plmk for use by the Laser Log Explorer GUI.
*/
  local type, color, size;
  default, line, "hide";
  default, marker, "hide";
  default, win, 17;
  default, xfma, 1;

  Y = data(noop(cat))(noop(y));
  X = data(noop(cat))(noop(x));

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
