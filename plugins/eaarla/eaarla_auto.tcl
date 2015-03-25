package require plugins
package require hook

# The only place that the EAARL version is specified is the namespace name. All
# other code references it via the namespace in order to make it easier to
# compare this file across versions and to make it easier to set up a new copy
# for future EAARLs.
namespace eval ::plugins::eaarla {
    ::hook::add "::plugins::menu_build_plugin" [namespace current]::hook_menu_build_plugin
    ::hook::add plugins_load [namespace current]::hook_plugins_load
    ::hook::add plugins_load_post [namespace current]::hook_plugins_load_post

    namespace import ::plugins::make_hook
    namespace import ::plugins::define_hook_set

    proc hook_menu_build_plugin {name is_loaded mb} {
        if {$name ne [namespace tail [namespace current]]} return
        if {!$is_loaded} return
        $mb add command -label "Processing GUI" \
                -command ::eaarl::main::gui
    }

    define_hook_set pre
    proc hook_plugins_load {name} {
        if {$name ne [namespace tail [namespace current]]} return

        plugins::apply_hooks pre
    }

    define_hook_set post
    proc hook_plugins_load_post {name} {
        if {$name ne [namespace tail [namespace current]]} return

        set ::eaarl::channel_count 3
        set ::eaarl::channel_list {1 2 3}

        set ::mission::imagery_types {rgb cir}
        set ::mission::detail_types {
            "data_path dir"
            "date"
            "edb file"
            "pnav file"
            "ins file"
            "ops_conf file"
            "bathconf file"
            "vegconf file"
            "mpconf file"
            "rgb dir"
            "rgb file"
            "cir dir"
        }

        plugins::apply_hooks post
    }
}
