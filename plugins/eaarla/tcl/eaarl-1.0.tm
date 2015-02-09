# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide eaarl 1.0

namespace eval ::eaarl {}

package require eaarl::main
package require eaarl::bathconf
package require eaarl::chanconf
package require eaarl::drast
package require eaarl::jsonlog
package require eaarl::load
package require eaarl::mpconf
package require eaarl::pixelwf
package require eaarl::processing
package require eaarl::raster
package require eaarl::rawwf
package require eaarl::settings
package require eaarl::sync
package require eaarl::transmit
package require eaarl::tscheck
package require eaarl::vegconf

namespace eval ::eaarl {
   variable channel_count 3
   variable channel_list {1 2 3}

   variable process_mapping {
      "First Return Topo"  f
      "Submerged Topo"     b
      "Topo Under Veg"     v
      "DEV: Multi-Peak (Experimental)" mp
      "OLD: First Return Topo"  old_fs
      "OLD: Submerged Topo"     old_bathy
      "OLD: Topo Under Veg"     old_veg
      "OLD: Multi Peak Veg"     old_cveg
   }

   variable autoclean_after_process 1
   variable usecentroid 1
   variable avg_surf 1
   variable ext_bad_att 20
   variable interactive_batch [expr {$::alpsrc(cores_local) >= 3}]

   variable processing_mode f
   variable pro_var_next fs_all

   proc processing_mode_changed {a b c} {
      variable pro_var_next
      variable processing_mode
      set mapping {
         f fs_all v veg_all b depth_all mp mp_all
         old_fs fs_all old_bathy depth_all old_veg veg_all old_cveg cveg_all
      }
      if {$pro_var_next in [list fs_all depth_all veg_all cveg_all]} {
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
