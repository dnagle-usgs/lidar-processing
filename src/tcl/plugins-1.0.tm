# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide plugins 1.0
package require tooltip

if {![namespace exists plugins]} {
    namespace eval plugins {
        namespace export define_hook_set make_hook apply_hooks remove_hooks
        variable loaded {}
    }
}

proc ::plugins::plugins_list {} {
    set result {}
    foreach plugin [lsort [glob ../plugins/*/manifest.json]] {
        lappend result [lindex [split $plugin /] 2]
    }
    return $result
}

proc ::plugins::menu_build {mb} {
    $mb delete 0 end
    destroy {*}[winfo children $mb]
    foreach plugin [plugins_list] {
        menu $mb.$plugin \
                -postcommand [list ::plugins::menu_build_plugin $plugin $mb.$plugin]
        $mb add cascade -label $plugin -menu $mb.$plugin
    }
}

proc ::plugins::menu_build_plugin {plugin mb} {
    variable loaded
    $mb delete 0 end
    ::tooltip::tooltip clear $mb

    set is_loaded [expr {$plugin in $loaded}]

    ::hook::invoke "::plugins::menu_build_plugin" $plugin $is_loaded $mb
    if {[$mb index end] ne "none"} {return}

    if {$is_loaded} {
        $mb add command -label "Loaded" -state disabled
    } else {
        $mb add command -label "Load" \
                -command [list exp_send "plugins_load, \"$plugin\";\r"]
    }
}

# For use by plugins

# Creates a new hook set in the calling namespace with the given name.
# This is basically just a wrapper around creating a variable.
proc ::plugins::define_hook_set {which} {
    set ns [uplevel 1 namespace current]
    set var hooks_${which}
    if {[info vars ${ns}::$var] eq ""}  {
        set ${ns}::$var {}
    }
}

# This is a wrapper around proc for creating a hook.
# Arguments:
#   which: name of a defined hook set
#   hook: the name of the hook to attach to
#   arg: an argument list
#   body: proc body
proc ::plugins::make_hook {which hook arg body} {
    set ns [uplevel 1 namespace current]
    set var hooks_${which}
    variable ${ns}::${var}
    # Cannot allow :: in proc names or it becomes a namespace qualifier
    set proc hook_[string map {: _} $hook]
    dict set ${var} $hook $proc
    proc ${ns}::$proc $arg $body
}

# Applies the hooks defined with make_hook
# which: the hook set to apply
proc ::plugins::apply_hooks {which} {
    set ns [uplevel 1 namespace current]
    set var hooks_${which}
    variable ${ns}::${var}
    dict for {hook proc} [set $var] {
        ::hook::add $hook [list ${ns}::$proc]
    }
}

# Removes hooks defined with make_hook and applied by apply_hooks
# which: the hook set to remove
proc ::plugins::remove_hooks {which} {
    set ns [uplevel 1 namespace current]
    set var hooks_${which}
    variable ${ns}::${var}
    dict for {hook proc} [set $var] {
        ::hook::remove $hook [list ${ns}::$proc]
    }
}
