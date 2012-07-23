# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide l1pro::settings 1.0

namespace eval ::l1pro::settings::ops_conf::v {
    variable top .l1wid.opsconf
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
        max_sfc_sat     {gui_spinbox -100 100 1}
    }
}

proc ::l1pro::settings::ops_conf::gui_refresh {} {
    array set v::ops_conf [array get v::ops_conf]
}

proc ::l1pro::settings::ops_conf::gui_line {w text} {
    set lbl [winfo parent $w].lbl[winfo name $w]
    ttk::label $lbl -text $text
    grid $lbl $w
    grid $lbl -sticky e
    grid $w -sticky ew
}

proc ::l1pro::settings::ops_conf::gui_entry {w key} {
    set var [namespace which -variable v::ops_conf]
    ttk::entry $w.$key -textvariable ${var}($key)
    gui_line $w.$key "$key: "
}

proc ::l1pro::settings::ops_conf::gui_spinbox {w key from to inc} {
    set var [namespace which -variable v::ops_conf]
    ttk::spinbox $w.$key -textvariable ${var}($key) \
            -from $from -to $to -increment $inc
    gui_line $w.$key "$key: "
}

proc ::l1pro::settings::ops_conf::gui {} {
    set w $v::top
    destroy $w
    toplevel $w
    array unset v::ops_conf

    wm resizable $w 1 0
    wm title $w "ops_conf Settings"
    wm protocol $w WM_DELETE_WINDOW [namespace which -command gui_dead]

    ttk::frame $w.f
    set f $w.f

    set var [namespace which -variable v::ops_conf]

    dict for {key val} $v::settings {
        tky_tie add sync ${var}($key) with "ops_conf.$key" -initialize 1
        {*}[linsert $val 1 $f $key]
    }

    grid columnconfigure $w.f 1 -weight 1

    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    bind $f <Enter> [namespace which -command gui_refresh]
    bind $f <Visibility> [namespace which -command gui_refresh]
}

proc ::l1pro::settings::ops_conf::gui_dead {} {
    destroy $v::top
    array unset v::ops_conf
}

proc ::l1pro::settings::ops_conf::save {} {
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
