// vim: set ts=2 sts=2 sw=2 ai sr et:
struct shoal {
  string name;
  float lat;
  float lon;
  string dmlat;
  string dmlon;
  char state;
  char type;
}

func list_reefs(idx) {
/* DOCUMENT list_reefs;
  list_reefs, idx;

  Lists the reefs, which are defined in extern shoals.

  Optional argument idx is an array of indexes into shoals to display. If
  omitted, it defaults to indgen(numberof(shoals)).
*/
  extern shoals;
  if(is_void(shoals)) load_reefs;
  default, idx, indgen(numberof(shoals));
  s = shoals(idx);
  write,format="%3d %20s %9.3f %9.3f %10s %10s\n",
    idx, s.name, s.lat, s.lon, s.dmlat, s.dmlon;
}

func load_reefs(void, fn=) {
/* DOCUMENT load_reefs;
  load_reefs, fn=;

  Loads the data for reefs.i. This data is automatically loaded from
  fla-reefs.dat in the maps directory. However, you can override the path to
  your fla-reefs.dat file if necessary using the fn= option.

  Reefs data is stored in an extern shoals for later use.
*/
  extern utm, alpsrc, shoals;
  default, fn, file_join(alpsrc.maps_dir, "fla-reefs.dat");

  // Check for fla-reefs.dat; complain if it doesn't exist.
  if(!file_exists(fn))
    error, "Could not find data file for reefs.i: fla-reefs.dat";

  // n = number of reefs, hard-coded to match fla-reefs.dat
  n = 205;

  st = array(char, n);
  rt = array(char, n);
  name = array(string, n);
  dmlat = array(string, n);
  dmlon = array(string, n);
  lat = array(float, n);
  lon = array(float, n);
  junk = array(string, n);
  aunk = array(string, n);

  f = open(file_join(alpsrc.maps_dir, "fla-reefs.dat"), "r");
  read, f, format="%d %d %s %s %s %f %f", st, rt, name, dmlat, dmlon, lat, lon;
  close, f;

  shoals = array(shoal, n);
  shoals.name = name;
  shoals.lat = lat;
  shoals.lon = lon;
  shoals.dmlat = dmlat;
  shoals.dmlon = dmlon;
  shoals.state = st;
  shoals.type = rt;
}

func plot_reefs(void, win=) {
/* DOCUMENT plot_reefs;
  plot_reefs, win=;

  Plots the reefs data, from extern shoals. If win= is specified, that window
  will be used instead of the current one.

  If extern utm is defined and true, values will be plotted in UTM. Otherwise,
  they will be plotted in lat/lon.
*/
  extern utm, shoals;
  if(is_void(shoals)) load_reefs;

  if(!is_void(win)) {
    win_old = current_window();
    window, win;
  }

  if(utm) {
    utm_arr = fll2utm(shoals.lat, shoals.lon);
    y = utm_arr(1,);//lat
    x = utm_arr(2,);//lon
  } else {
    y = shoals.lat;
    x = shoals.lon;
  }
  name = shoals.name;

  for(i = 1; i <= numberof(name); i++) {
    if(shoals.state(i)) {
      if(shoals.type(i) == 1) {
        plt, name(i), x(i), y(i), tosys=1, height=3, justify="CC", color="black";
        plmk, y(i), x(i), color="black", msize=.4, marker=4;
      } else if(shoals.type(i) == 2) {
        plt, name(i), x(i), y(i), tosys=1, height=3, justify="CC", color="blue";
        plmk, y(i), x(i), color="blue", msize=.3, marker=1, width=10;
      }
    }
  }

  if(!is_void(win)) {
    window_select, win_old;
  }
}
