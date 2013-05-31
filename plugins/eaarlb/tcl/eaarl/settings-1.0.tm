# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::settings 1.0

namespace eval ::eaarl::settings::ops_conf::v {
    variable top .l1wid.opsconf
    variable fieldframe ""
    variable ops_conf

    variable settings {
        name            {gui_entry}
        varname         {gui_entry}
        roll_bias       {gui_spinbox -45 45 0.01}
        pitch_bias      {gui_spinbox -45 45 0.01}
        yaw_bias        {gui_spinbox -45 45 0.01}
        scan_bias       {gui_spinbox -100 100 0.001}
        range_biasM     {gui_spinbox -100 100 0.0001}
        range_biasNS    {gui_spinbox -100 100 0.0001}
        x_offset        {gui_spinbox -100 100 0.001}
        y_offset        {gui_spinbox -100 100 0.001}
        z_offset        {gui_spinbox -100 100 0.001}
        chn1_range_bias {gui_spinbox -10000 10000 0.01}
        chn2_range_bias {gui_spinbox -10000 10000 0.01}
        chn3_range_bias {gui_spinbox -10000 10000 0.01}
        chn4_range_bias {gui_spinbox -10000 10000 0.01}
        chn1_dx         {gui_spinbox 0 1000 1}
        chn1_dy         {gui_spinbox 0 1000 1}
        chn2_dx         {gui_spinbox 0 1000 1}
        chn2_dy         {gui_spinbox 0 1000 1}
        chn3_dx         {gui_spinbox 0 1000 1}
        chn3_dy         {gui_spinbox 0 1000 1}
        chn4_dx         {gui_spinbox 0 1000 1}
        chn4_dy         {gui_spinbox 0 1000 1}
        delta_ht        {gui_spinbox 0 1000 1}
        max_sfc_sat     {gui_spinbox -100 100 1}
        minsamples      {gui_spinbox 0 100 1}
        tx_clean        {gui_spinbox 0 100 1}
        dmars_invert    {gui_spinbox 0 1 1}
    }
}

proc ::eaarl::settings::ops_conf::applycmd {key old new} {
    exp_send "var_expr_tkupdate, \"ops_conf.$key\", \"$new\";\r"
   # Generating an error tells the revertable control not to apply the change;
   # this prevents an inconsistent state if Yorick doesn't actually accept the
   # value (during a mouse wait for instance).
   return -code error
}

proc ::eaarl::settings::ops_conf::gui_line {w key} {
    set text "$key: "
    ::mixin::revertable $w.$key \
            -applycommand [list ::eaarl::settings::ops_conf::applycmd $key]
    set lbl $w.lbl$key
    ttk::label $w.lbl$key -text $text
    ::misc::tooltip $w.$key $w.lbl$key \
            "Press Enter to apply current changes to field. Press Escape to\
            revert current changes to field."
    ttk::button $w.app$key -text "\u2713" \
            -style Toolbutton \
            -command [list $w.$key apply]
    ::misc::tooltip $w.app$key "Apply current changes to field"
    ttk::button $w.rev$key -text "x" \
            -style Toolbutton \
            -command [list $w.$key revert]
    ::misc::tooltip $w.rev$key "Revert current changes to field"
    grid $w.lbl$key $w.$key $w.app$key $w.rev$key
    grid $w.lbl$key -sticky e
    grid $w.$key -sticky ew
}

proc ::eaarl::settings::ops_conf::gui_entry {w key} {
    set var [namespace which -variable v::ops_conf]
    ttk::entry $w.$key -textvariable ${var}($key)
    gui_line $w $key
}

proc ::eaarl::settings::ops_conf::gui_spinbox {w key from to inc} {
    set var [namespace which -variable v::ops_conf]
    ttk::spinbox $w.$key -textvariable ${var}($key) \
            -from $from -to $to -increment $inc
    gui_line $w $key
    $w.$key configure -valuetype number
}

proc ::eaarl::settings::ops_conf::gui {} {
    set w $v::top
    destroy $w
    toplevel $w
    array unset v::ops_conf *

    wm resizable $w 1 0
    wm title $w "ops_conf Settings"
    wm protocol $w WM_DELETE_WINDOW [namespace which -command gui_dead]

    ttk::frame $w.f
    set f $w.f
    set v::fieldframe $f

    grid columnconfigure $w.f 1 -weight 1

    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    ybkg eaarl_ops_conf_gui_init
}

proc ::eaarl::settings::ops_conf::gui_init {fields} {
    set var [namespace which -variable v::ops_conf]
    foreach key $fields {
        if {[dict exists $v::settings $key]} {
            set val [dict get $v::settings $key]
        } else {
            set val [list gui_entry]
        }
        ybkg tksync add \"ops_conf.$key\" \"${var}($key)\"
        {*}[linsert $val 1 $v::fieldframe $key]
    }
    ::misc::idle {wm geometry .l1wid.opsconf ""}
}

proc ::eaarl::settings::ops_conf::gui_dead {} {
    destroy $v::top
    set var [namespace which -variable v::ops_conf]
    foreach key [array names v::ops_conf] {
        ybkg tksync remove \"ops_conf.$key\" \"${var}($key)\"
    }
    array unset v::ops_conf *
}

proc ::eaarl::settings::ops_conf::save {} {
    set fn [tk_getSaveFile -parent .l1wid \
            -title "Select destination to save current ops_conf settings" \
            -filetypes {
                {"Yorick files" .i}
                {"All files" *}
            }]

    if {$fn ne ""} {
        exp_send "write_ops_conf, \"$fn\"\r"
    }
}

proc ::eaarl::settings::ops_conf::view {json {name {}}} {
    set i 1
    while {[winfo exists ${v::top}view${i}]} {
        incr i
    }
    set w ${v::top}view${i}
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    if {$name eq ""} {
        wm title $w "mission_constants"
    } else {
        wm title $w "mission_constants: $name"
    }

    ttk::frame $w.f
    set f $w.f

    grid columnconfigure $w.f 1 -weight 1

    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    set data [::json::json2dict $json]
    dict for {key val} $data {
        ttk::entry $f.$key
        $f.$key insert end $val
        $f.$key state readonly
        ttk::label $f.lbl$key -text "${key}: "
        grid $f.lbl$key $f.$key
        grid $f.lbl$key -sticky e
        grid $f.$key -sticky ew
    }
}
