
/* 
    $Id$
   
    Yorick partner to l1pro.ytk.  
*/

write,"$Id$"

cd, src_path
require,  "pip.i"
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


