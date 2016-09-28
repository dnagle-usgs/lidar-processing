func py_convert_mission(void, force=) {
/* DOCUMENT py_convert_mission
  Updates the current mission to be Python friendly. For each defined flight:
    - The ops_conf will be saved out as JSON, if needed
    - The gps will be saved out as HDF5, if needed
    - The ins will be saved out as HDF5, if needed
  Any newly generated files will be applied to the mission configuration.
*/
  flights = mission(get,);

  for(i = 1; i <= numberof(flights); i++) {
    mission, load, flights(i);

    if(mission(has, flights(i), "ops_conf file")) {
      fn = mission(get, flights(i), "ops_conf file");
      if(file_extension(fn) == ".i") {
        fn = ops_conf_i_to_json_filename(fn);
        write_ops_conf, fn;
        mission, details, set, flights(i), "ops_conf file", fn;
      }
    }

    if(mission(has, flights(i), "pnav file")) {
      fn = mission(get, flights(i), "pnav file");
      if(file_extension(fn) == ".ybin") {
        fn = file_rootname(fn) + ".gps.h5";
        h5_gps, fn;
        mission, details, set, flights(i), "pnav file", fn;
      }
    }

    if(mission(has, flights(i), "ins file")) {
      ifn = mission(get, flights(i), "ins file");
      if(anyof(file_extension(ifn) == [".pbd",".pdb"])) {
        ofn = file_rootname(ifn) + ".ins.h5";
        h5_ins, ifn, ofn;
        mission, details, set, flights(i), "ins file", ofn;
      }
    }
  }
}
