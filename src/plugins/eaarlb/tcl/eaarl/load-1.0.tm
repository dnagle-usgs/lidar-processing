# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::load 1.0
package require mission::eaarl

namespace eval eaarl::load {
    proc prompt {type} {
        set base $::mission::path
        if {$base eq "" || ![file isdirectory $base]} {
            set base $::_ytk(initialdir)
        }

        set parent [focus]
        if {$parent eq ""} {
            set parent .
        }

        set filetype [dict get $::mission::detail_filetypes "$type file"]
        set chosen [tk_getOpenFile \
                -initialdir $base \
                -filetypes $filetype \
                -parent $parent \
                -title "Select $type file"]

        if {$chosen ne "" && ![file isfile $chosen]} {
            set chosen ""
        }

        return $chosen
    }

    proc ops_conf {{fn ""}} {
        if {$fn eq ""} {set fn [prompt ops_conf]}
        if {$fn eq ""} return
        exp_send "ops_conf_filename = \"$fn\";\
                ops_conf = load_ops_conf(ops_conf_filename);\r"
    }

    proc edb {{fn ""}} {
        if {$fn eq ""} {set fn [prompt edb]}
        if {$fn eq ""} return
        exp_send "load_edb, fn=\"$fn\";\r"
    }

    proc pnav {{fn ""}} {
        if {$fn eq ""} {set fn [prompt pnav]}
        if {$fn eq ""} return
        exp_send "pnav = rbpnav(fn=\"$fn\");\r"
    }

    proc ins {{fn ""}} {
        if {$fn eq ""} {set fn [prompt ins]}
        if {$fn eq ""} return
        exp_send "ins_filename = \"$fn\"; "
        if {[file extension $fn] in {.pbd .pdb}} {
            exp_send "load_iexpbd, ins_filename;\r"
        } else {
            exp_send "iex_head = []; tans = iex_nav = rbtans(fn=ins_filename);\r"
        }
    }

    proc bath_ctl {{fn ""}} {
        if {$fn eq ""} {set fn [prompt bath_ctl]}
        if {$fn eq ""} return
        exp_send "bath_ctl_load, \"$fn\";\r"
    }
}
