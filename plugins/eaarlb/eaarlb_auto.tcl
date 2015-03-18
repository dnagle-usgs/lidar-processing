package require plugins
package require hook

# The only place that the EAARL version is specified is the namespace name. All
# other code references it via the namespace in order to make it easier to
# compare this file across versions and to make it easier to set up a new copy
# for future EAARLs.
namespace eval ::plugins::eaarlb {
    ::hook::add plugins_load [namespace current]::hook_plugins_load
    ::hook::add plugins_load_post [namespace current]::hook_plugins_load_post

    namespace import ::plugins::make_hook
    namespace import ::plugins::define_hook_set

    define_hook_set pre
    proc hook_plugins_load {name} {
        if {$name ne [namespace tail [namespace current]]} return

        plugins::apply_hooks pre
    }

    define_hook_set post
    proc hook_plugins_load_post {name} {
        if {$name ne [namespace tail [namespace current]]} return

        set ::eaarl::channel_count 4
        set ::eaarl::channel_list {1 2 3 4}

        set ::mission::imagery_types {rgb nir}
        set ::mission::detail_types {
            "data_path dir"
            "date"
            "edb file"
            "pnav file"
            "ins file"
            "ops_conf file"
            "bathconf file"
            "vegconf file"
            "sbconf file"
            "mpconf file"
            "cfconf file"
            "rgb dir"
            "nir dir"
        }

        plugins::apply_hooks post
    }

    make_hook pre "eaarl::main::gui below separator" {f} {
        ttk::label $f.channels -text "Channel:"
        foreach chan {1 2 3 4} {
            ttk::checkbutton $f.chan$chan \
                    -text $chan \
                    -variable ::eaarl::usechannel_$chan
        }
        lower [ttk::frame $f.fch]
        grid $f.chan1 $f.chan2 $f.chan3 $f.chan4 \
            -in $f.fch -sticky w -padx 2
        grid $f.channels $f.fch -sticky ew -padx 2 -pady 2
        grid $f.channels -sticky e
    }

    make_hook pre "eaarl::main::menu::menu_settings" {mb} {
        $mb add separator
        $mb add checkbutton -variable ::eaarl::usechannel_1 \
                -label "Use channel 1"
        $mb add checkbutton -variable ::eaarl::usechannel_2 \
                -label "Use channel 2"
        $mb add checkbutton -variable ::eaarl::usechannel_3 \
                -label "Use channel 3"
        $mb add checkbutton -variable ::eaarl::usechannel_4 \
                -label "Use channel 4"
    }
}
