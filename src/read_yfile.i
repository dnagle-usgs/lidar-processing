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
   if(structeqany(dstruc, FS, R, CVEG_ALL)) {
      pmode = 0;
      dmode = 0;
   } else if(structeqany(dstruc, GEO, GEOALL)) {
      pmode = 1;
      dmode = 1;
   } else if(structeqany(dstruc, VEG, VEG_, VEG__, VEGALL, VEG_ALL, VEG_ALL_)) {
      pmode = 2;
      if(anyof(regmatch("(^|_)fs(t_|_|\.|$)", [vname, fn]))) {
         dmode = 0;
      } else {
         dmode = 3;
      }
   } else if(structeq(dstruc, ZGRID) || is_numerical(data)) {
      pmode = 0;
      dmode = 0;
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

func merge_data_pbds(filepath, write_to_file=, merged_filename=, nvname=, uniq=, skip=, searchstring=, fn_all=) {
 /*DOCUMENT merge_data_pbds(filename) 
   This function merges the EAARL processed pbd data files in the given filepath
   INPUT:
   filepath : the path where the pbd files are to be merged
   write_to_file : set to 1 if you want to write the merged pbd to file
   merged_filename : the merged filename where the merged pbd file will be written to.
   vname = the variable name for the merged data
   uniq = set to 1 if you want to delete the same records (keep only unique records).
   skip = set to subsample the data sets read in.
   amar nayegandhi 05/29/03
   */

 if (!skip) skip = 1;
 skip = int(skip);
 eaarl = [];
 // find all the pbd files in filepath

  if ( is_void(fn_all) ) {
    s = array(string, 10000);
    if (searchstring) ss = [searchstring];
    if (!searchstring) ss = ["*.pbd"];
    scmd = swrite(format="find %s -name '%s'", filepath, ss);
    fp = 1; lp = 0;
    for (i=1; i<=numberof(scmd); i++) {
        f=popen(scmd(i), 0);
        n = read(f,format="%s", s );
        close, f;
        lp = lp + n;
        if (n) fn_all = s(fp:lp);

/*
    // 2009-01-29: added to remove output file from the list to be merged
    // THIS CANNOT BE UNIVERSALLY APPLIED... an output file can contain "merged" in its filename and be a valid file to merge.
    mgd_idx = strmatch(fn_all,"merged",1);
    fn_all = fn_all(where(!mgd_idx));
    n = numberof(fn_all);
*/

        fp = fp + n;
    }
  }

  if(numberof(fn_all)) {
     eaarl_size = 0;
     eaarl_struct = [];
     for(i = 1; i <= numberof(fn_all); i++) {
        write, format="Getting size of file %d of %d\r", i, numberof(fn_all);
        f = openb(fn_all(i));
        if(get_member(f, f.vname) != 0) {
           // The next line deliberately uses integer math, which truncates
           eaarl_size += (numberof(get_member(f, f.vname))+skip-1)/skip;
           // The above should be faster than
           // numberof(get_member(f,f.vname)(::skip)) because it doesn't need
           // to actually load the data into memory
           if(is_void(eaarl_struct)) {
              // The "obvious" way to do this would be:
              //    eaarl_struct = structof(get_member(f, f.vname)(1))
              // However, that results in a structure definition that is tied
              // to the file, which is not usuable when we try to create an
              // array with it. Using the temporary variable avoids that issue.
              temp = get_member(f, f.vname)(1);
              eaarl_struct = structof(temp);
              temp = [];
           }
        }
        close, f;
     }
     write, format="\nAllocating data array of size %d...\n", eaarl_size;
     eaarl = array(eaarl_struct, eaarl_size);
     idx = 1;
     for(i = 1; i <= numberof(fn_all); i++) {
        write, format="Merging file %d of %d\r", i, numberof(fn_all);
        f = openb(fn_all(i));
        if(get_member(f, f.vname) != 0) {
           idx_upper = idx + (numberof(get_member(f, f.vname))+skip-1)/skip - 1;
           eaarl(idx:idx_upper) = get_member(f, f.vname)(::skip);
           idx = idx_upper + 1;
        }
        close, f;
     }
  }

 if (uniq) {
   write, "Finding unique elements in array..."
   // sort the elements by soe
   idx = sort(eaarl.soe);
   if (!is_array(idx)) {
     write, "No Records found.";
     return
   }
   eaarl = eaarl(idx);
   // now use the unique function with ret_sort=1
   idx = unique(eaarl.soe, ret_sort=1);
   if (!is_array(idx)) {
     write, "No Records found.";
     return
   }
   eaarl = eaarl(idx);
 }

 if (write_to_file) {
   // write merged data out to merged_filename
   if (!merged_filename) merged_filename = filepath+"data_merged.pbd";
   if (!nvname) {
     // create variable vname if required
     a = eaarl(1);
     b = structof(a);
     if (structeq(a, FS)) nvname = "fst_merged";
     if (structeq(a, GEO)) nvname = "bat_merged";
     if (structeq(a, VEG__)) nvname = "bet_merged";
     if (structeq(a, CVEG_ALL)) nvname = "mvt_merged";
   }
   vname=nvname
   f = createb(merged_filename);
   add_variable, f, -1, vname, structof(eaarl), dimsof(eaarl);
   get_member(f,vname) = eaarl;
   save, f, vname;
   close, f;
 }

 write, format="Merged %d files, skip = %d \n", numberof(fn_all), skip;


 return eaarl
}

func subsample_pbd_data (fname=, skip=,output_to_file=, ofname=) {
  /* DOCUMENT subsample_pbd_data(fname, skip=)
    This function subsamples the pbd file at the skip value.
  //amar nayegandhi 06/15/03
   INPUT:
     fname = filename to input.  If not defined, a pop-up window will be called to select the file.
     skip = the subsample (default = 10)
     output_to_file = set to 1 if you want the output to be written out to a file.
     ofname = the name of the output file name.  Valid only when output_to_file = 1.  If not defined, same as input file name with a "-skip-xx" added to it.
     OUTPUT:
       If called as a function, returned array is the subsampled data array.
  */
  
  extern initialdir;
  if (!skip) skip = 10;

  //read pbd file
  if (!fname) {
   if (is_void(initialdir)) initialdir = "/data/";
   fname  = get_openfn( initialdir=initialdir, filetype="*.pbd", title="Open PBD Data File" );
  }
  
  fif = openb(fname); 
  //restore, fif, vname, plyname, qname;
  restore, fif, vname;
  eaarl = get_member(fif, vname)(1:0:skip);
  //ply = get_member(fif, plyname);
  //q = get_member(fif, qname);
  close, fif;
  if (output_to_file == 1) {
    if (!ofname) {
      sp = split_path(fname, 0, ext=1)
      ofname = sp(1)+swrite(format="-skip%d",skip)+sp(2);
    }
    fof = createb(ofname);
    save, fof, vname;
    add_variable, fof, -1, vname, structof(eaarl), dimsof(eaarl);
    get_member(fof, vname) = eaarl;
    //add_variable, fof, -1, qname, structof(q), dimsof(q);
    //get_member(fof, qname) = q;
    //add_variable, fof, -1, plyname, structof(ply), dimsof(ply);
    //get_member(fof, plyname) = ply;
    close, fof;
  }
  return eaarl;
  
}
