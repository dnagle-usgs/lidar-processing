// vim: set ts=2 sts=2 sw=2 ai sr et:
func restore_alps_data(fn, vname=, skip=) {
/* DOCUMENT restore_alps_data, fn, vname=, skip=
  Restores data from the given file. Updates the l1pro GUI as well.
*/
  local err, fvname;
  default, skip, 1;

  ext = strlower(file_extension(fn));
  // Load as EDF if extension is .edf or .bin
  if(anyof(ext == [".edf", ".bin"])) {
    data = edf_import(fn);
    default, vname, file_rootname(file_tail(fn));
  // Otherwise, assume PBD
  } else {
    data = pbd_load(fn, err, fvname);
    if(strlen(err)) {
      if(logger(warn))
        logger, warn, "restore_alps_data: Unable to load file due to error...\n"+
            "Problem file: "+fn+"\n"+
            "Error: "+err;
      write, format="Unable to load file due to error: %s\n", err;
      return;
    }
    default, vname, fvname;
  }

  if(skip > 1 && numberof(data))
    data = data(::skip);

  sanitize_vname, vname;

  // Variable already exists?
  if(symbol_exists(vname) && !is_void(symbol_def(vname))) {
    // Loading data equals loaded data? Do nothing except add to varlist.
    curdata = symbol_def(vname);
    if(
      numberof(curdata) == numberof(data)
      && structeq(structof(curdata), structof(data))
      && allof(curdata == data)
    ) {
      tkcmd, swrite(format="append_varlist %s", vname);
      tkcmd, swrite(format="set pro_var %s", vname);
      write, format="Data in file matches data found in existing variable of same name:\n  %s\n",
        vname;
      return;

    // Loading data is different than loaded data? Rename loaded out of the
    // way. Then fall through to add new.
    } else {
      newvname = vname + "_backup";
      if(symbol_exists(newvname) && !is_void(newvname)) {
        i = 1;
        do {
          i++;
          newvname = swrite(format="%s_backup%d", vname, i);
        } while(symbol_exists(newvname) && !is_void(newvname));
      }
      msg = swrite(format=
        "Data in file for variable %s does not match data found in " +
        "existing variable of same name. Backing up existing data " +
        "to %s.", vname, newvname);
      write, format="%s\n", strwrap(msg);
      symbol_set, newvname, curdata;
      tkcmd, swrite(format="rename_varlist %s %s", vname, newvname);
    }
  }

  symbol_set, vname, data;

  update_var_settings, data, vname, fn=fn;
  tkcmd, swrite(format="append_varlist %s", vname);
  tkcmd, swrite(format="set pro_var %s", vname);
  write, format="Loaded variable %s\n", vname;
  if(logger(info)) logger, info, "Loaded variable "+vname+" from "+fn;
}

func update_var_settings(data, vname, fn=) {
  if(is_void(_ytk) || !_ytk)
    return;
  default, fn, string(0);
  if(strlen(fn))
    fn = file_tail(fn);

  dstruc = structof(data);

  // Default, includes FS, R, CVEG_ALL, ZGRID, ATM, numerical, etc.
  dmode = "fs";

  // Special cases
  if(structeqany(dstruc, GEO, GEOALL)) {
    dmode = "ba";
  } else if(structeqany(dstruc, VEG, VEG_, VEG__, VEGALL, VEG_ALL, VEG_ALL_)) {
    if(!anyof(regmatch("(^|_)fs(t_|_|\.|$)", [vname, fn]))) {
      dmode = "be";
    }
  }

  tkcmd, swrite(format="dict set var_settings(%s) display_mode %s", vname, dmode);

  cbar = auto_cbar(data, "stdev", mode=dmode);
  tkcmd, swrite(format="dict set var_settings(%s) cmin %.2f", vname, cbar(1));
  tkcmd, swrite(format="dict set var_settings(%s) cmax %.2f", vname, cbar(2));
}
