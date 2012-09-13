# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide plugins 1.0
package require tooltip

namespace eval plugins {
    variable loaded
}

proc ::plugins::plugins_list {} {
    set result {}
    foreach plugin [lsort [glob plugins/*/manifest.json]] {
        lappend result [lindex [split $plugin /] 1]
    }
    return $result
}

proc ::plugins::menu_build {plugin mb} {
    variable loaded
    $mb delete 0 end
    ::tooltip::tooltip clear $mb
    if {$plugin ni $loaded} {
        if {"" != [info procs ::plugins::${plugin}::menu_preload]} {
            ::plugins::${plugin}::menu_preload $mb
        } else {
            ::plugins::menu_preload $plugin $mb
        }
    } else {
        if {"" != [info procs ::plugins::${plugin}::menu_postload]} {
            ::plugins::${plugin}::menu_postload $mb
        } else {
            ::plugins::menu_postload $plugin $mb
        }
    }
}

proc ::plugins::menu_preload {plugin mb} {
    $mb add command -label "Load" \
            -command [list exp_send "plugins_load, \"$plugin\";\r"]
}

proc ::plugins::menu_postload {plugin mb} {
    $mb add command -label "Loaded" -state disabled
}
