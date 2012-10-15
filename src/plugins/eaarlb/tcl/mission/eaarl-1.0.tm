# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide mission::eaarl 1.0
package require mission

namespace eval ::mission::eaarl {
    namespace import ::mission::gui::ystr

    proc initialize_path_mission {} {}
    proc initial_path_flight {} {}

    proc load_data {flight} {
        set flight [ystr $flight]
        exp_send "mission, load, \"$flight\";\r"
    }
    set ::mission::commands(load_data) ::mission::eaarl::load_data
}
