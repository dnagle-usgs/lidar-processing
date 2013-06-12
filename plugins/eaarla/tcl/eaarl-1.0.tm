# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide eaarl 1.0

namespace eval ::eaarl {}

package require eaarl::main
package require eaarl::bathconf
package require eaarl::drast
package require eaarl::jsonlog
package require eaarl::load
package require eaarl::pixelwf
package require eaarl::processing
package require eaarl::raster
package require eaarl::rawwf
package require eaarl::settings
package require eaarl::sync
package require eaarl::transmit
package require eaarl::tscheck

namespace eval ::eaarl {
   variable process_mapping {
      "First Return Topo"  fs
      "Submerged Topo"     bathy
      "Topo Under Veg"     veg
      "Multi Peak Veg"     cveg
   }

   variable autoclean_after_process 1
   variable usecentroid 1
   variable avg_surf 1
   variable ext_bad_att 20

   variable processing_mode fs
   variable pro_var_next fs_all

   proc processing_mode_changed {a b c} {
      variable pro_var_next
      variable processing_mode
      set mapping {
         fs fs_all veg veg_all bathy depth_all cveg cveg_all
      }
      if {$pro_var_next in [list fs_all depth_all veg_all cveg_all wave_data]} {
         set pro_var_next [dict get $mapping $processing_mode]
      }
   }

   trace add variable \
         ::eaarl::processing_mode write ::eaarl::processing_mode_changed

   proc on_load {} {
      foreach script $::l1pro::on_eaarl_load {
         catch [list uplevel #0 $script]
      }
   }
}
