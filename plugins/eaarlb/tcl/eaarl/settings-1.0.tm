# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::settings 1.0

namespace eval ::eaarl::settings::ops_conf::v {
    variable top .l1wid.opsconf
    variable fieldframe
    variable ops_conf
    variable last_refresh 0

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

proc ::eaarl::settings::ops_conf::gui_refresh {} {
    # Throttle to every 3/4 second to prevent flooding Yorick in the background
    # (which can cause issues)
    set elapsed [expr {[clock milliseconds] - $v::last_refresh}]
    if {$elapsed > 750} {
        set v::last_refresh [clock milliseconds]
        array set v::ops_conf [array get v::ops_conf]
    }
}

proc ::eaarl::settings::ops_conf::applycmd {key old new} {
    exp_send "var_expr_tkupdate, \"ops_conf.$key\", \"$new\";\
            tkcmd, \"::eaarl::settings::ops_conf::gui_refresh\";\r"
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

    bind $f <Enter> [namespace which -command gui_refresh]
    bind $f <Visibility> [namespace which -command gui_refresh]

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
        tky_tie add read ${var}($key) from "ops_conf.$key" -initialize 1
        {*}[linsert $val 1 $v::fieldframe $key]
    }
    ::misc::idle ::eaarl::settings::ops_conf::gui_refresh
    ::misc::idle {wm geometry .l1wid.opsconf ""}
}

proc ::eaarl::settings::ops_conf::gui_dead {} {
    destroy $v::top
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

namespace eval ::eaarl::settings::bath_ctl::v {
    variable top .l1wid.bctl
    variable last_refresh 0

    variable presets {
         Clear {
            laser -2.4 water -0.6 agc -0.3 thresh 4.0
            first 11 last 220 sfc_last 12 maxsat 2
            lwing_dist 1 rwing_dist 3 lwing_factor 0.9 rwing_factor 0.9
         }
         Bays {
            laser -2.4 water -1.5 agc -3.0 thresh 4.0
            first 11 last 60 sfc_last 12 maxsat 2
            lwing_dist 1 rwing_dist 3 lwing_factor 0.9 rwing_factor 0.9
         }
         Turbid {
            laser -2.4 water -3.5 agc -6.0 thresh 2.0
            first 11 last 60 sfc_last 12 maxsat 2
            lwing_dist 1 rwing_dist 3 lwing_factor 0.9 rwing_factor 0.9
         }
         {Super shallow} {
            laser -2.4 water -2.4 agc -3.0 thresh 4.0
            first 9 last 30 sfc_last 12 maxsat 2
            lwing_dist 1 rwing_dist 3 lwing_factor 0.9 rwing_factor 0.9
         }
         {Shallow riverine} {
            laser -4.7 water -4.8 agc -3.3 thresh 3.0
            first 11 last 50 sfc_last 12 maxsat 2
            lwing_dist 1 rwing_dist 3 lwing_factor 0.9 rwing_factor 0.9
         }
    }

    variable guilayout {
        laser {Laser -5.0 -1.0 0.1}
        water {Water -10 0.1 0.1}
        agc {AGC -10 0.1 0.1}
        thresh {Thresh 0 50.0 0.1}
        first {First 0 300 1}
        last {Last 0 300 1}
        sfc_last {"Surface Last" 0 300 1}
        maxsat {"Max Sat" 0 10 1}
        lwing_dist {"Left Wing Dist" 1 100 1}
        rwing_dist {"Right Wing Dist" 1 100 1}
        lwing_factor {"Left Wing Factor" 0.0 1.0 0.1}
        rwing_factor {"Right Wing Factor" 0.0 1.0 0.1}
    }

    set ns [namespace current]
    foreach var {bath_ctl bath_ctl_chn4} {
        if {![info exists $var]} {
            variable $var
            foreach {field -} $guilayout {
                set ${var}($field) 0
                tky_tie add sync ${ns}::${var}($field) \
                        with "${var}.$field" -initalize 1
            }
        }
    }
    unset ns var field
}

proc ::eaarl::settings::bath_ctl::gui_main {} {
    set w $v::top
    destroy $w
    toplevel $w

    wm resizable $w 1 0
    wm title $w "Bathy Settings"

    menu $w.mb
    menu $w.mb.file
    menu $w.mb.preset
    menu $w.mb.preset.p1
    menu $w.mb.preset.p2

    set ns [namespace current]

    $w.mb add cascade -label File -underline 0 -menu $w.mb.file
    $w.mb.file add command -label "Load Bathy Parameters..." \
            -command ${ns}::load
    $w.mb.file add command -label "Save Bathy Parameters..." \
            -command ${ns}::save
    $w.mb.file add separator
    $w.mb.file add command -label "Close" \
            -command [list destroy $w]

    $w.mb add cascade -label "Presets" -underline 0 -menu $w.mb.preset
    $w.mb.preset add cascade -label "Channels 1, 2, and 3" -menu $w.mb.preset.p1
    $w.mb.preset add cascade -label "Channel 4" -menu $w.mb.preset.p2
    foreach {m var} [list p1 ${ns}::v::bath_ctl p2 ${ns}::v::bath_ctl_chn4] {
        foreach {preset -} $v::presets {
            $w.mb.preset.$m add command -label $preset \
                    -command [list ${ns}::preset $var $preset]
        }
    }

    $w configure -menu $w.mb

    ttk::frame $w.f
    set f $w.f
    ttk::labelframe $f.bath_ctl -text "Channels 1, 2, and 3"
    ttk::labelframe $f.bath_ctl_chn4 -text "Channel 4"

    foreach var [list bath_ctl bath_ctl_chn4] {
        foreach {key info} $v::guilayout {
            lassign $info name rmin rmax rinc fmt
            ttk::label $f.$var.lbl$key -text "${name}:"
            ttk::spinbox $f.$var.spn$key \
                -width 8 \
                -textvariable ${ns}::v::${var}($key) \
                -from $rmin -to $rmax -increment $rinc
            grid $f.$var.lbl$key $f.$var.spn$key -padx 2 -pady 2
            grid configure $f.$var.lbl$key -sticky e
            grid configure $f.$var.spn$key -sticky ew
        }
        grid columnconfigure $f.$var 1 -weight 1
    }

    grid $f.bath_ctl $f.bath_ctl_chn4 -sticky news -padx 2 -pady 2
    grid columnconfigure $f {0 1} -weight 1 -uniform 1

    grid $w.f -sticky news
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    bind $f <Enter> [namespace which -command gui_refresh]
    bind $f <Visibility> [namespace which -command gui_refresh]
}

proc ::eaarl::settings::bath_ctl::launch_win {window raster pulse channel} {
    set args [list -raster $raster -pulse $pulse -channel $channel]
    set ns [namespace current]
    set gui ${ns}::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::settings::bath_ctl::gui_embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::settings::bath_ctl::gui_embed {
    option -window -readonly 1 -default 4 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt

    component window
    component settings

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 4
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set ns [namespace parent]

        set f [$window pane bottom]
        ttk::labelframe $f.settings -text "Bathy Settings"
        grid $f.settings -sticky news -pady 3 -padx 3
        grid columnconfigure $f 0 -weight 1
        grid rowconfigure $f 0 -weight 1

        set settings $f.settings
        set f $f.settings

        foreach {key info} [set ${ns}::v::guilayout] {
            lassign $info name rmin rmax rinc fmt
            ttk::label $f.lbl$key -text "${name}:"
            ttk::spinbox $f.spn$key -width 3 \
                -from $rmin -to $rmax -increment $rinc
        }
        ttk::button $f.replot -text "Replot" \
                -command [mymethod replot]

        grid $f.lbllaser $f.spnlaser $f.lbllwing_dist $f.spnlwing_dist $f.lblfirst $f.spnfirst
        grid $f.lblwater $f.spnwater $f.lblrwing_dist $f.spnrwing_dist $f.lbllast $f.spnlast
        grid $f.lblagc $f.spnagc $f.lbllwing_factor $f.spnlwing_factor $f.lblthresh $f.spnthresh
        grid $f.lblmaxsat $f.spnmaxsat $f.lblrwing_factor $f.spnrwing_factor x x
        grid x x $f.lblsfc_last $f.spnsfc_last $f.replot -

        grid configure $f.spnlaser $f.spnfirst $f.spnwater $f.spnlast \
                $f.spnagc $f.spnmaxsat $f.spnthresh $f.spnlwing_dist \
                $f.spnlwing_factor $f.spnrwing_dist $f.spnrwing_factor \
                $f.spnsfc_last $f.replot -sticky news -padx 2 -pady 2
        grid configure $f.lbllaser $f.lblfirst $f.lblwater $f.lbllast \
                $f.lblagc $f.lblmaxsat $f.lblthresh $f.lbllwing_dist \
                $f.lbllwing_factor $f.lblrwing_dist $f.lblrwing_factor \
                $f.lblsfc_last -sticky e -padx 2 -pady 2
        grid columnconfigure $f {1 3 5} -weight 1 -uniform a

        bind $settings <Enter> ${ns}::gui_refresh
        bind $settings <Visibility> ${ns}::gui_refresh

        # Force initialization in case no options are given by caller
        $self configure -channel 1
        $self configure {*}$args
    }

    method clear_gui {} {
        $self destroy
    }

    method replot {} {
        set cmd "ex_bath, $options(-raster), $options(-pulse), graph=1,\
                win=$options(-window), xfma=1"
        if {$options(-channel)} {
            append cmd ", forcechannel=$options(-channel)"
        }
        exp_send "$cmd;\r"
    }

    method SetOpt {option value} {
        set options($option) $value
        wm title $window "Window $options(-window) - Raster $options(-raster)\
                Pulse $options(-pulse) Channel $options(-channel)"

        set f $settings
        set ns [namespace parent]
        if {$options(-channel) == 4} {
            $f configure -text "Bathy Settings for Channel 4"
            set var ${ns}::v::bath_ctl_chn4
        } elseif {$options(-channel) == 0} {
            $f configure -text "Bathy Settings for EAARL-A (Channels 1, 2, and 3)"
            set var ${ns}::v::bath_ctl
        } else {
            $f configure -text "Bathy Settings for Channels 1, 2, and 3"
            set var ${ns}::v::bath_ctl
        }
        foreach {key -} [set ${ns}::v::guilayout] {
            $f.spn$key configure -textvariable ${var}($key)
        }
    }

    method id {} {
        return [expr {[winfo id $plot]}]
    }
}

proc ::eaarl::settings::bath_ctl::gui_refresh {} {
    # Throttle to every 3/4 second to prevent flooding Yorick in the background
    # (which can cause issues)
    set elapsed [expr {[clock milliseconds] - $v::last_refresh}]
    if {$elapsed > 750} {
        set v::last_refresh [clock milliseconds]
        array set v::bath_ctl [array get v::bath_ctl]
        array set v::bath_ctl_chn4 [array get v::bath_ctl_chn4]
    }
}

proc ::eaarl::settings::bath_ctl::save {} {
    set fn [tk_getSaveFile -initialdir $::data_path \
            -filetypes {{{json files} {.json}} {{all files} {*}}}]
    if {$fn ne ""} {
        if {[file extension $fn] eq ".bctl"} {
            tk_messageBox -icon error -type ok -message \
                    "You chose a filename ending with \".bctl\", which is a\
                    deprecated format no longer used for bath_ctl settings.\
                    Please choose a filename ending in \".json\"."
        }
        if {[file extension $fn] ne ".json"} {
            append fn .json
        }
        exp_send "bath_ctl_save, \"$fn\";\r"
    }
}

proc ::eaarl::settings::bath_ctl::load {} {
    set fn [tk_getOpenFile -initialdir $::data_path \
            -filetypes {
                {{json files} {.json}}
                {{bctl files} {.bctl}}
                {{all files} {*}}
            }]
    if {$fn ne ""} {
        exp_send "bath_ctl_load, \"$fn\";\r"
        ::misc::idle [namespace which -command gui_refresh]
    }
}

proc ::eaarl::settings::bath_ctl::preset {var preset} {
    dict for {key val} [dict get $v::presets $preset] {
        set ${var}($key) $val
    }
}
