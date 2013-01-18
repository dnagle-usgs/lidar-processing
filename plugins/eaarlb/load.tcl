package require plugins

::tcl::tm::path add [file join [app_root_dir] .. plugins eaarlb tcl]

package require mission::eaarl
package require eaarl
package require sf::model::cir
package require sf::model::rgb

namespace eval ::plugins::eaarlb {}

proc ::plugins::eaarlb::menu_postload {mb} {
    $mb add command -label "Processing GUI" \
            -command ::eaarl::main::gui
}

eaarl::on_load
