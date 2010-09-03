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
   tkcmd, "varplot::gui";
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
   pmode = dmode = 0;

   // Special cases
   if(structeqany(dstruc, GEO, GEOALL)) {
      pmode = 1;
      dmode = 1;
   } else if(structeqany(dstruc, VEG, VEG_, VEG__, VEGALL, VEG_ALL, VEG_ALL_)) {
      pmode = 2;
      if(!anyof(regmatch("(^|_)fs(t_|_|\.|$)", [vname, fn]))) {
         dmode = 3;
      }
   }

   tkcmd, swrite(format="dict set var_settings(%s) processing_mode [lindex $l1pro_data(processing_mode) %d]", vname, pmode);
   tkcmd, swrite(format="dict set var_settings(%s) display_type [lindex $l1pro_data(display_types) %d]", vname, dmode);

   cbar = auto_cbar(data, "stdev", mode=["fs","ba","","be"](dmode+1));
   tkcmd, swrite(format="dict set var_settings(%s) cmin %.2f", vname, cbar(1));
   tkcmd, swrite(format="dict set var_settings(%s) cmax %.2f", vname, cbar(2));
}

func set_read_yorick(data, vname=, fn=) {
/* DOCUMENT set_read_yorick(data, vname=, fn=)
   This function sets the cmin and cmax values in the Process EAARL data GUI
   amar nayegandhi 05/06/03
*/
   local cminmax, pmode, dmode;

   if(!is_void(pmode)) {
      tkcmd, swrite(format="processing_mode_by_index %d", pmode);
      tkcmd, swrite(format="display_type_by_index %d", dmode);
      auto_cbar, data, "stdev", mode=["fs","ba","","be"](dmode+1);
   }

   tkcmd, swrite("if {$cbv == 1} {set plot_settings(cmin) $cbvc(cmin)}");
   tkcmd, swrite("if {$cbv == 1} {set plot_settings(cmax) $cbvc(cmax)}");
   tkcmd, swrite("if {$cbv == 1} {set plot_settings(msize) $cbvc(msize)}");
   tkcmd, swrite("if {$cbv == 1} {set plot_settings(mtype) $cbvc(mtype)}");
}

