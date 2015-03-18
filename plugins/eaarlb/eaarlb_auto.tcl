package require plugins
package require hook

# The only place that the EAARL version is specified is the namespace name. All
# other code references it via the namespace in order to make it easier to
# compare this file across versions and to make it easier to set up a new copy
# for future EAARLs.
namespace eval ::plugins::eaarlb {
    ::hook::add plugins_load [namespace current]::hook_plugins_load
    ::hook::add plugins_load_post [namespace current]::hook_plugins_load_post

    proc hook_plugins_load {name} {
        if {$name ne [namespace tail [namespace current]]} return
    }

    proc hook_plugins_load_post {name} {
        if {$name ne [namespace tail [namespace current]]} return
    }
}
