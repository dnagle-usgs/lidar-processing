# vim: set ts=3 sts=3 sw=3 ai sr et:

package provide eaarl 1.0

namespace eval ::eaarl {}

package require eaarl::main
package require eaarl::drast
package require eaarl::jsonlog
package require eaarl::load
package require eaarl::pixelwf
package require eaarl::processing
package require eaarl::rasters
package require eaarl::settings
package require eaarl::tscheck

namespace eval ::eaarl {
   proc on_load {} {
      foreach script $::l1pro::on_eaarl_load {
         catch [list uplevel #0 $script]
      }
   }
}
