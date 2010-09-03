// This would probably be better located elsewhere but for now...
require, "eaarl.i";

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
