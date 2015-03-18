package require plugins
package require hook

# The only place that the EAARL version is specified is the namespace name. All
# other code references it via the namespace in order to make it easier to
# compare this file across versions and to make it easier to set up a new copy
# for future EAARLs.
namespace eval ::plugins::eaarlb {
    ::hook::add plugins_load [namespace current]::hook_plugins_load
    ::hook::add plugins_load_post [namespace current]::hook_plugins_load_post

    variable pre_hooks {}
    variable post_hooks {}

    proc hook_plugins_load {name} {
        if {$name ne [namespace tail [namespace current]]} return

        variable pre_hooks
        dict for {hook proc} $pre_hooks {
            ::hook::add $hook [namespace current]::$proc
        }
    }

    proc hook_plugins_load_post {name} {
        if {$name ne [namespace tail [namespace current]]} return

        set ::eaarl::channel_count 4
        set ::eaarl::channel_list {1 2 3 4}

        variable post_hooks
        dict for {hook proc} $post_hooks {
            ::hook::add $hook [namespace current]::$proc
        }
    }
}
