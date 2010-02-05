/* 
   Yorick partner to l1pro.ytk, to collect necessary .i files. 
*/

if(is_void(__l1pro_includes_included__)) {
   __l1pro_includes_included__ = 1;
   if(!is_void(src_path))
      cd, src_path;

   require, "eaarl.i";

   require, "atm.i";
   require, "batch_multipip_process.i";
   require, "batch_typ_convert.i";
   require, "batch_veg_energy.i";
   require, "bathy.i";
   require, "centroid-1.i";
   require, "compare_transects.i";
   require, "data_segments.i";
   require, "dataexplore.i";
   require, "datum_converter.i";
   require, "determine_bias.i";
   require, "drast.i";
   require, "geo_bath.i";
   require, "ircf.i";
   require, "irg.i";
   require, "kml.i";
   require, "pbd2las.i";
   require, "plcm.i";
   require, "qaqc_fns.i";
   require, "raspulsearch.i";
   require, "surface_topo.i";
   require, "veg.i";
   require, "ytriangulate.i";
}

// This would probably be better located elsewhere but for now...

func __ytk_l1pro_vars_filequery(fn, tclcmd) {
/* DOCUMENT __ytk_l1pro_vars_filequery, fn, tclcmd;
   Glue command used in background by l1pro::vars.
*/
   f = openb(fn);
   vars = *(get_vars(f)(1));
   data = "";
   for(i = 1; i <= numberof(vars); i++) {
      _structof = nameof(structof(get_member(f, vars(i))));
      _dimsof = strjoin(swrite(format="%d", dimsof(get_member(f, vars(i)))), ",");
      _sizeof = sizeof(get_member(f, vars(i)));
      data += swrite(format="%s {structof %s dimsof %s sizeof %d} ",
         vars(i), _structof, _dimsof, _sizeof);
   }

   tkcmd, swrite(format="%s {%s}", tclcmd, data);
}

func __ytk_l1pro_vars_externquery(____tclcmd____) {
   vars = symbol_names(3);
   vars = vars(where(vars != "____tclcmd____"));
   data = "";
   for(i = 1; i <= numberof(vars); i++) {
      _structof = nameof(structof(symbol_def(vars(i))));
      _dimsof = strjoin(swrite(format="%d", dimsof(symbol_def(vars(i)))), ",");
      _sizeof = sizeof(symbol_def(vars(i)));
      data += swrite(format="%s {structof %s dimsof %s sizeof %d} ",
         vars(i), _structof, _dimsof, _sizeof);
   }

   tkcmd, swrite(format="%s {%s}", ____tclcmd____, data);
}
