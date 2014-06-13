# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide eaarl 1.0

namespace eval ::eaarl {}

package require eaarl::main
package require eaarl::bathconf
package require eaarl::chanconf
package require eaarl::drast
package require eaarl::jsonlog
package require eaarl::load
package require eaarl::pixelwf
package require eaarl::processing
package require eaarl::raster
package require eaarl::rawwf
package require eaarl::sbconf
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
      "Shallow Bathy"      sb
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

   variable usechannel_1 0
   variable usechannel_2 0
   variable usechannel_3 0
   variable usechannel_4 0

   variable processing_mode f
   variable pro_var_next fs_all

   proc processing_mode_changed {a b c} {
      variable pro_var_next
      variable processing_mode
      variable usechannel_1
      variable usechannel_2
      variable usechannel_3
      variable usechannel_4

      set mapping {
         f fs v veg b depth sb shallow
         old_fs fs old_bathy depth old_veg veg old_cveg cveg
      }

      set tokens [split $pro_var_next _]
      set prefix [join [lrange $tokens 0 end-1] _]
      set suffix [lindex $tokens end]

      # Only change if suffix matches valid pattern
      if {![regexp {^(?:all|(ch(?:a?n)?)(?!$)1?2?3?4?)$} $suffix - chan]} return
      if {$chan eq ""} {set chan "chn"}

      # Only change prefix if prefix is in known list
      if {$prefix in [list fs veg depth shallow cveg]} {
         set prefix [dict get $mapping $processing_mode]
      }

      set oldsuffix $suffix
      set suffix $chan
      if {$usechannel_1} {append suffix 1}
      if {$usechannel_2} {append suffix 2}
      if {$usechannel_3} {append suffix 3}
      if {$usechannel_4} {append suffix 4}
      if {$suffix eq $chan} {set suffix all}

      set pro_var_next "${prefix}_${suffix}"
   }

   foreach var {
      usechannel_1 usechannel_2 usechannel_3 usechannel_4 processing_mode
   } {
      trace add variable \
            ::eaarl::$var write ::eaarl::processing_mode_changed
   }
   unset var


   proc on_load {} {
      foreach script $::l1pro::on_eaarl_load {
         catch [list uplevel #0 $script]
      }
   }
}
