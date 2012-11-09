// vim: set ts=2 sts=2 sw=2 ai sr et:

// Glue for the GUI

func gui_mission_select(flight, key, path) {
/* DOCUMENT gui_mission_select, "<flight>", "<key>", "<path>"
  Used by "Select Detected..." button in Mission Configuration GUI.
*/
  if(!mission(details,*,"autolist")) {
    write, "Autolisting not available - did you load a plugin yet?";
    return;
  }

  options = mission(details, autolist, flight, key, path);

  if(((strpart(key, -3:) == " dir") || (strpart(key, -4:) == " file"))) {
    for(i = 1; i <= numberof(options); i++) {
      if(strlen(options(i)))
        options(i) = file_relative(mission.data.path, options(i));
    }
  }

  json = json_encode(save(flight, key, path, options));
  tkcmd, swrite(format="::mission::gui_select {%s}", json);
}
