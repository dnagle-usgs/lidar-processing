// vim: set ts=2 sts=2 sw=2 ai sr et:

func set_sf_bookmarks(controller) {
/* DOCUMENT set_sf_bookmarks, controller;
  Used internally by the mission configuration GUI when creating SF instances
  to set bookmarks for an entire mission.
*/
  flights = mission(get,);
  for(i = 1; i <= numberof(flights); i++) {
    set_sf_bookmark, controller, flights(i);
  }
}

func set_sf_bookmark(controller, flight) {
/* DOCUMENT set_sf_bookmark, controller, flight;
  Used internally by the mission configuration GUI when creating SF instances
  to set bookmarks for a single flight.
*/
  loaded = mission.data.loaded;
  mission, load, flight;
  if(!is_void(edb)) {
    fmt = "%s bookmark add %d {%s}"
    soe = long(edb.seconds(min));
    tkcmd, swrite(format=fmt, controller, soe, flight+" (edb start");
    soe = long(edb.seconds(max));
    tkcmd, swrite(format=fmt, controller, soe, flight+" (edb end)");
  }
  mission, load, loaded;
}
