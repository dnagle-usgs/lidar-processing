package require plugins

::tcl::tm::path add [file join [app_root_dir] .. plugins eaarla tcl]

package require mission::eaarl
package require eaarl
package require sf::model::cir
package require sf::model::rgb

namespace eval ::plugins::eaarla {}

proc ::plugins::eaarla::menu_postload {mb} {
    $mb add command -label "Processing GUI" \
            -command ::eaarl::main::gui
}

eaarl::on_load
