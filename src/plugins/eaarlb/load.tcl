package require plugins
package require eaarl

package require mission::eaarl

namespace eval ::plugins::eaarlb {}

proc ::plugins::eaarlb::menu_postload {mb} {
    $mb add command -label "Processing GUI" \
            -command ::eaarl::main::gui
}
