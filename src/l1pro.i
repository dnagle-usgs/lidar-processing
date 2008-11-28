/* 
   Yorick partner to l1pro.ytk, to collect necessary .i files. 
*/

if(is_void(__l1pro_includes_included__)) {
   __l1pro_includes_included__ = 1;
   require, "eaarl.i";
   write,"$Id$";
   cd, src_path;
   require, "atm.i";
   require, "batch_datum_convert.i";
   require, "batch_multipip_process.i";
   require, "bathy.i";
   require, "centroid-1.i";
   require, "compare_transects.i";
   require, "dataexplore.i";
   require, "datum_converter.i";
   require, "determine_bias.i";
   require, "drast.i";
   require, "geo_bath.i";
   require, "info.i";
   require, "ircf.i";
   require, "irg.i";
   require, "manual_filter.i";
   require, "nad832navd88.i";
   require, "pbd2las.i";
   require, "plcm.i";
   require, "qaqc_fns.i";
   require, "surface_topo.i";
   require, "veg.i";
   require, "webview.i";
   require, "wgs842nad83.i";
   require, "ytriangulate.i";
}
