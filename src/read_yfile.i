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
      write, format="Unable to load file due to error: %s\n", err;
      return;
    }
    default, vname, fvname;
  }

  if(skip > 1 && numberof(data))
    data = data(::skip);

  sanitize_vname, vname;
  symbol_set, vname, data;
  update_var_settings, data, vname, fn=fn;
  tkcmd, swrite(format="append_varlist %s", vname);
  tkcmd, swrite(format="set pro_var %s", vname);
  write, format="Loaded variable %s\n", vname;
}

func set_read_tk(junk) {
  /* DOCUMENT set_read_tk(vname)
   This function sets the variable name in the Process Eaarl Data gui
  amar nayegandhi 05/05/03
  */

  extern vname
  tkcmd, swrite(format="append_varlist %s",vname);
  tkcmd, "l1pro::tools::varmanage::gui";
  tkcmd, swrite(format="set pro_var %s", vname);
  write, "Tk updated \r";

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
