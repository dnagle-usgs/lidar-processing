# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::raster 1.0

namespace eval ::eaarl::raster {
    namespace import ::misc::tooltip
    namespace import ::misc::appendif
}

# plot <window> [-opt val -opt val ...]
# plotcmd <window> [-opt val -opt val ...]
# config <window> [-opt val -opt val ...]
#
# Each of the above commands will launch the embedded window GUI for wf
# plots if it does not exist. Each will also update the GUI with the given
# options, if any are provided.
#
# config does only the above. It returns the GUI's command.
#
# plot will additionally trigger a plot replot, using the window's current
# options. It returns the GUI's command.
#
# plotcmd is like plot but will instead return the Yorick command (suitable for
# sending via expect)

proc ::eaarl::raster::plotcmd {window args} {
    set extra [list]
    if {[dict exists $args -highlight]} {
        dict set extra -highlight [dict get $args -highlight]
        dict unset args -highlight
    }
    set gui [config $window {*}$args]
    return [$gui plotcmd {*}$extra]
}

proc ::eaarl::raster::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::raster::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::raster::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::raster::embed {
    option -window -readonly 1 -default 20 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt

    option -units -default ns
    option -range_bias -default 0
    option -usecmin -default 0
    option -cmin -default 1
    option -usecmax -default 0
    option -cmax -default 255
    option -geo -default 0
    option -rcfw -default 50
    option -eoffset -default 0
    option -tx -default 0
    option -autolims -default 1
    option -showcbar -default 0
    option -bathy -default 0
    option -bg -default 0

    component window
    component pane
    component sync

    # Step amount for raster stepping
    variable raststep 2

    variable lock_channel 0

    # The current window width
    variable win_width 450

    # Keeps track of the state of the Georeference options. They are only
    # enabled when both the channel is not 0 and Georeference is enabled.
    variable geo_opt_state 0

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 20
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        set sync [::eaarl::sync::manager create %AUTO%]

        trace add variable [myvar options](-channel) write \
                [mymethod TraceGeoOptState]
        trace add variable [myvar options](-geo) write \
                [mymethod TraceGeoOptState]

        $self Gui
        $window configure -resizecmd [mymethod Resize]

        $self configure {*}$args
    }

    destructor {
        $sync destroy
    }

    method Resize {width height} {
        if {$width == $win_width} return

        set win_width $width

        grid forget $pane.browse $pane.sync $pane.settings
        if {$win_width > 600} {
            grid $pane.browse $pane.settings -sticky news
            grid $pane.sync   ^ -sticky news
            grid columnconfigure $pane 0 -weight 1
        } else {
            grid $pane.browse -sticky ew
            grid $pane.sync -sticky ew
            grid $pane.settings -sticky ew
            grid columnconfigure $pane 0 -weight 1
        }

        if {$win_width < 500 || ($win_width > 600 && $win_width < 1000)} {
            $pane.browse.chkChan configure -text "Chan:"
        } else {
            $pane.browse.chkChan configure -text "Channel:"
        }

        if {$win_width > 600 && $win_width < 1000} {
            $pane.browse.lblRast configure -text "Rast:"
            $pane.browse.lblPulse configure -text "Pls:"
        } else {
            $pane.browse.lblRast configure -text "Raster:"
            $pane.browse.lblPulse configure -text "Pulse:"
        }
    }

    method Gui {} {
        # Create GUI
        set sections [list browse sync settings]
        foreach section $sections {
            ttk::frame $pane.$section \
                    -relief ridge \
                    -borderwidth 1 \
                    -padding 1
            $self Gui_$section $pane.$section
            grid $pane.$section -sticky ew
        }
        grid columnconfigure $pane 0 -weight 1
    }

    method Gui_browse {f} {
        ::eaarl::chanconf::raster_browser $f $self \
                -chanshow padlock -txchannel 1

        tooltip $f.chkChan $f.cboChan \
                "Channel for this raster.

                Locking the padlock will cause the channel to remain fixed
                while using tools such as \"Examine Pixels\". Otherwise it will
                change to reflect the channel of the selected point."
    }

    method Gui_sync {f} {
        $sync build_gui $f.fraSync -exclude rast
        pack $f.fraSync -side left -anchor nw -fill x -expand 1

        ttk::button $f.btnSelect \
                -image ::imglib::handup \
                -style Toolbutton \
                -width 0 \
                -command [mymethod examine single]
        ttk::button $f.btnBrowse \
                -image ::imglib::handup2 \
                -style Toolbutton \
                -width 0 \
                -command [mymethod examine browse]
        pack $f.btnBrowse $f.btnSelect -side right -anchor ne

        tooltip $f.btnSelect \
                "Allows you to click on the plot once to select a waveform to
                view in the synced windows."
        tooltip $f.btnBrowse \
                "Allows you to click on the plot multiple times to select
                waveforms to view in the synced windows."
    }

    method Gui_settings {f} {
        ttk::frame $f.fra1
        ttk::label $f.lblunits -text "Units:"
        mixin::combobox $f.units -width 6 \
                -state readonly \
                -values [list ns meters feet] \
                -textvariable [myvar options](-units) \
                -modifycmd [mymethod plot]
        foreach w [list $f.units $f.lblunits] {
            mixin::statevar $w \
                    -statemap {
                        0 {readonly !disabled}
                        1 {readonly disabled}
                    } \
                    -statevariable [myvar options](-geo)
        }
        ttk::checkbutton $f.rangebias -text "Remove range bias" \
                -variable [myvar options](-range_bias) \
                -command [mymethod plot]
        ttk::checkbutton $f.limits -text "Reset limits" \
                -variable [myvar options](-autolims)
        pack $f.lblunits $f.units $f.rangebias $f.limits \
                -in $f.fra1 -side left -padx 2

        ttk::frame $f.fra2
        ttk::checkbutton $f.tx -text "Show transmit above return" \
                -variable [myvar options](-tx) \
                -command [mymethod plot]
        ttk::checkbutton $f.bathy -text "Show bathy" \
                -variable [myvar options](-bathy) \
                -command [mymethod plot -autolims 0]
        ttk::checkbutton $f.bg -text "Solid background" \
                -variable [myvar options](-bg) \
                -command [mymethod plot]
        pack $f.tx $f.bathy $f.bg \
                -in $f.fra2 -side left -padx 2

        foreach w [list $f.rangebias $f.tx $f.bathy] {
            ::mixin::statevar $w \
                    -statemap {
                        0 disabled 1 normal 2 normal 3 normal 4 normal
                    } \
                    -statevariable [myvar options](-channel)
        }

        ttk::frame $f.fra3
        ttk::checkbutton $f.showcbar -text "Show colobar" \
                -variable [myvar options](-showcbar) \
                -command [mymethod plot -autolims 0]
        ttk::checkbutton $f.usecmin -text "CMin:" \
                -variable [myvar options](-usecmin) \
                -command [mymethod plot -autolims 0]
        ttk::spinbox $f.cmin \
                -textvariable [myvar options](-cmin) \
                -from 0 -to 255 -increment 1 \
                -width 3
        mixin::statevar $f.cmin \
                -statemap {0 disabled 1 normal} \
                -statevariable [myvar options](-usecmin)
        mixin::revertable $f.cmin \
                -command [list $f.cmin apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot -autolims 0]
        ttk::checkbutton $f.usecmax -text "CMax:" \
                -variable [myvar options](-usecmax) \
                -command [mymethod plot -autolims 0]
        ttk::spinbox $f.cmax \
                -textvariable [myvar options](-cmax) \
                -from 0 -to 255 -increment 1 \
                -width 3
        mixin::statevar $f.cmax \
                -statemap {0 disabled 1 normal} \
                -statevariable [myvar options](-usecmax)
        mixin::revertable $f.cmax \
                -command [list $f.cmax apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot -autolims 0]
        pack $f.showcbar $f.usecmin $f.cmin $f.usecmax $f.cmax \
                -in $f.fra3 -side left -padx 2

        ttk::frame $f.fra4
        ttk::checkbutton $f.geo -text "Georeference" \
                -variable [myvar options](-geo) \
                -command [mymethod plot]
        ttk::label $f.lblrcfw -text "RCF:"
        ttk::spinbox $f.rcfw \
                -textvariable [myvar options](-rcfw) \
                -from 0 -to 10000 -increment 10 \
                -width 5
        mixin::revertable $f.rcfw \
                -command [list $f.rcfw apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot -autolims 0]
        ttk::label $f.lbleoffset -text "Elev offset:"
        ttk::spinbox $f.eoffset \
                -textvariable [myvar options](-eoffset) \
                -from -1000 -to 1000 -increment 0.1 \
                -width 5
        mixin::revertable $f.eoffset \
                -command [list $f.eoffset apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot -autolims 0]
        ::mixin::statevar $f.geo \
                -statemap {0 disabled 1 normal 2 normal 3 normal 4 normal} \
                -statevariable [myvar options](-channel)
        foreach w [list $f.lblrcfw $f.rcfw $f.lbleoffset $f.eoffset] {
            mixin::statevar $w \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar geo_opt_state]
        }
        pack $f.geo $f.lblrcfw $f.rcfw $f.lbleoffset $f.eoffset \
                -in $f.fra4 -side left -padx 2

        pack $f.fra1 $f.fra2 $f.fra3 $f.fra4 \
                -side top -anchor w -fill x -pady 2
    }

    method SetOpt {option value} {
        if {$option eq "-channel" && $lock_channel} return
        set options($option) $value
        $self UpdateTitle
    }

    method UpdateTitle {} {
        set chan "Channel $options(-channel)"
        if {$options(-channel) == 0} {
            set chan "Transmit"
        }
        wm title $window "Window $options(-window) - \
                Raster - \
                Raster $options(-raster) $chan"
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    method IdlePlot {args} {
        ::misc::idle [mymethod plot {*}$args]
    }

    method ApplyIdlePlot {args} {
        # skip the old, new args
        set args [lrange $args 0 end-2]
        ::misc::idle [mymethod plot {*}$args]
    }

    method TraceGeoOptState {old new op} {
        set geo_opt_state [expr {$options(-channel) != 0 && $options(-geo)}]
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {args} {
        array set opts [list -highlight 0]
        array set opts [array get options]
        array set opts $args

        if {$lock_channel} {
            set opts(-channel) $options(-channel)
        }

        set cmd ""
        append cmd "show_rast, $opts(-raster), channel=$opts(-channel),\
                win=$opts(-window)"
        if {$opts(-channel) == 0} {
            append cmd ", units=\"$opts(-units)\""
        } else {
            appendif cmd \
                    {!$opts(-geo)}      ", units=\"$opts(-units)\"" \
                    $opts(-range_bias)  ", range_bias=1" \
                    $opts(-geo)         ", geo=1" \
                    $opts(-geo)         ", rcfw=$opts(-rcfw)" \
                    $opts(-geo)         ", eoffset=$opts(-eoffset)" \
                    $opts(-tx)          ", tx=1" \
                    $opts(-bathy)       ", bathy=1"
        }
        appendif cmd \
                $opts(-highlight)   ", highlight=$opts(-highlight)" \
                $opts(-usecmin)     ", cmin=$opts(-cmin)" \
                $opts(-usecmax)     ", cmax=$opts(-cmax)" \
                $opts(-showcbar)    ", showcbar=1" \
                {!$opts(-autolims)} ", autolims=0" \
                $opts(-bg)          ", bg=1"
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {args} {
        set cmd [$self plotcmd {*}$args]
        append cmd [$sync plotcmd \
                -raster $options(-raster) -pulse $options(-pulse) \
                -channel $options(-channel)]
        exp_send "$cmd\r"
    }

    method examine {mode} {
        set cmd "drast_msel, $options(-raster)"
        appendif cmd \
                1                   ", winsel=$options(-window)" \
                1                   ", optstr=\"[$sync getopts]\"" \
                {$mode eq "single"} ", single=1"
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        trace remove variable [myvar options](-channel) write \
                [mymethod TraceGeoOptState]
        trace remove variable [myvar options](-geo) write \
                [mymethod TraceGeoOptState]
        $self destroy
    }
}
