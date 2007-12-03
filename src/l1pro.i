
/* 
    $Id$
   
    Yorick partner to l1pro.ytk.  
*/

write,"$Id$"

cd, src_path
require,  "pip.i"
require,  "set.i"
require,  "geo_bath.i" 
require,  "read_yfile.i" 
require,  "veg.i" 
require,  "batch_process.i" 
require,  "batch_multipip_process.i" 
require,  "comparison_fns.i" 
require,  "bathy_filter.i" 
require,  "data_rgn_selector.i"
require,  "wgs842nad83.i"
require,  "nad832navd88.i"
require,  "datum_converter.i"
require,  "gridr.i"
require,  "transect.i"
require,  "manual_filter.i"
require,  "ytriangulate.i"
require,  "ircf.i"
require,  "dataexplore.i"
require,  "determine_bias.i"
require,  "webview.i"
require,  "batch_datum_convert.i"

include,  "rcf.i"

func winlimits( win1, win2 ) {
/* DOCUMENT set_winlimits( window1, window2 )
    Convenient shortcut function to set the window limits in window2
    equal to the limits in window1. i.e. make window2 look like window1. 
*/
  window, win1;
  lm=limits();
  window, win2;
  limits,lm(1),lm(2),lm(3),lm(4);
  window, win1;
}

