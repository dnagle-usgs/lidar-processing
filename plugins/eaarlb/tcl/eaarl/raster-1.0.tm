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
    set gui [config $window {*}$args]
    return [$gui plotcmd]
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
    option -window -readonly 1 -default 11 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -channel -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt

    option -units -default ns
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

    component window
    component pane

    # Step amount for raster stepping
    variable raststep 2

    variable rawwf_plot 0
    variable rawwf_win 9
    variable bathy_plot 0
    variable bathy_win 8
    variable transmit_plot 0
    variable transmit_win 16

    # Keeps track of the state of the Georeference options. They are only
    # enabled when both the channel is not 0 and Georeference is enabled.
    variable geo_opt_state 0

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 11
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        trace add variable [myvar options](-channel) write \
                [mymethod TraceGeoOptState]
        trace add variable [myvar options](-geo) write \
                [mymethod TraceGeoOptState]

        $self Gui
        $self configure {*}$args
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
            pack $pane.$section -side top -fill x -expand 1
        }
    }

    method Gui_browse {f} {
        ttk::label $f.lblChan -text "Channel:"
        mixin::combobox::mapping $f.cboChan \
                -mapping {1 1 2 2 3 3 4 4 tx 0} \
                -altvariable [myvar options](-channel) \
                -state readonly \
                -width 2 \
                -modifycmd [mymethod IdlePlot]

        ttk::separator $f.sepChan \
                -orient vertical

        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -textvariable [myvar options](-raster) \
                -from 1 -to 100000000 -increment 1 \
                -width 5
        ::mixin::revertable $f.spnRast \
                -command [list $f.spnRast apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot]
        ttk::spinbox $f.spnStep \
                -textvariable [myvar raststep] \
                -from 1 -to 100000 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnStep \
                -command [list $f.spnStep apply] \
                -valuetype number
        ttk::button $f.btnRastPrev \
                -image ::imglib::vcr::stepbwd \
                -style Toolbutton \
                -command [mymethod IncrRast -1] \
                -width 0
        ttk::button $f.btnRastNext \
                -image ::imglib::vcr::stepfwd \
                -style Toolbutton \
                -command [mymethod IncrRast 1] \
                -width 0
        ttk::separator $f.sepRast \
                -orient vertical
        ttk::label $f.lblPulse -text "Pulse:"
        ttk::spinbox $f.spnPulse \
                -textvariable [myvar options](-pulse) \
                -from 1 -to 120 -increment 1 \
                -width 3
        ::mixin::revertable $f.spnPulse \
                -command [list $f.spnPulse apply] \
                -valuetype number \
                -applycommand [mymethod ApplyIdlePlot]
        ttk::separator $f.sepPulse \
                -orient vertical
        ttk::button $f.btnLims \
                -image ::imglib::misc::limits \
                -style Toolbutton \
                -width 0 \
                -command [mymethod limits]
        ttk::button $f.btnReplot \
                -image ::imglib::misc::refresh \
                -style Toolbutton \
                -width 0 \
                -command [mymethod plot]

        pack $f.lblChan $f.cboChan \
                $f.sepChan \
                $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev $f.btnRastNext \
                $f.sepRast \
                $f.lblPulse $f.spnPulse \
                $f.sepPulse \
                $f.btnLims $f.btnReplot \
                -side left
        pack $f.spnRast -fill x -expand 1
        pack $f.sepChan $f.sepRast $f.sepPulse -fill y -padx 2

        tooltip $f.lblRast $f.spnRast \
                "Raster number"
        tooltip $f.spnStep \
                "Amount to step by"
        tooltip $f.btnRastPrev $f.btnRastNext \
                "Step through rasters by step increment"
        tooltip $f.btnLims \
                "Reset the limits on the plot so everything is visible."
        tooltip $f.btnReplot \
                "Replots the current plot. Also plots linked plots (such as
                bathy or raw waveform) if any are selected."
    }

    method Gui_sync {f} {
        foreach type {rawwf bathy transmit} {
            set name [string totitle $type]
            ttk::checkbutton $f.lbl$name \
                    -text ${name}: \
                    -variable [myvar ${type}_plot]
            pack $f.lbl$name -side left

            ttk::spinbox $f.spn$name \
                    -width 2 \
                    -from 0 -to 63 -increment 1 \
                    -textvariable [myvar ${type}_win]
            ::mixin::statevar $f.spn$name \
                    -statemap {0 disabled 1 normal} \
                    -statevariable [myvar ${type}_plot]
            pack $f.spn$name -side left -padx {0 1}
        }
        $f.lblRawwf configure -text "Raw WF"

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
        pack $f.btnBrowse $f.btnSelect -side right

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
        ttk::checkbutton $f.limits -text "Reset limits" \
                -variable [myvar options](-autolims)
        ttk::checkbutton $f.tx -text "Stack transmit" \
                -variable [myvar options](-tx) \
                -command [mymethod plot]
        ttk::checkbutton $f.bathy -text "Show bathy" \
                -variable [myvar options](-bathy) \
                -command [mymethod plot -autolims 0]
        foreach w [list $f.tx $f.bathy] {
            ::mixin::statevar $w \
                    -statemap {
                        0 disabled 1 normal 2 normal 3 normal 4 normal
                    } \
                    -statevariable [myvar options](-channel)
        }
        pack $f.lblunits $f.units $f.limits $f.tx $f.bathy \
                -in $f.fra1 -side left -padx 2

        ttk::frame $f.fra2
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
                -in $f.fra2 -side left -padx 2

        ttk::frame $f.fra3
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
                -in $f.fra3 -side left -padx 2

        pack $f.fra1 $f.fra2 $f.fra3 \
                -side top -anchor w -fill x -pady 2
    }

    method SetOpt {option value} {
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

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {args} {
        array set opts [array get options]
        array set opts $args

        set cmd ""
        append cmd "show_rast, $opts(-raster), channel=$opts(-channel),\
                win=$opts(-window)"
        if {$opts(-channel) == 0} {
            append cmd ", units=\"$opts(-units)\""
        } else {
            appendif cmd \
                    {!$opts(-geo)}      ", units=\"$opts(-units)\"" \
                    $opts(-geo)         ", geo=1" \
                    $opts(-geo)         ", rcfw=$opts(-rcfw)" \
                    $opts(-geo)         ", eoffset=$opts(-eoffset)" \
                    $opts(-tx)          ", tx=1" \
                    $opts(-bathy)       ", bathy=1"
        }
        appendif cmd \
                $opts(-usecmin)     ", cmin=$opts(-cmin)" \
                $opts(-usecmax)     ", cmax=$opts(-cmax)" \
                $opts(-showcbar)    ", showcbar=1" \
                {!$opts(-autolims)} ", autolims=0"
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {args} {
        set cmd [$self plotcmd {*}$args]
        append cmd [::eaarl::sync::multicmd \
                -raster $options(-raster) -pulse $options(-pulse) \
                -channel $options(-channel) \
                -rawwf $rawwf_plot -rawwfwin $rawwf_win \
                -bath $bathy_plot -bathwin $bathy_win \
                -tx $transmit_plot -txwin $transmit_win]
        exp_send "$cmd\r"
    }

    method examine {mode} {
        set type rast
        if {$options(-geo)} {set type geo}
        set cmd "drast_msel, $options(-raster), type=\"$type\""
        appendif cmd \
                1                   ", rx=$rawwf_plot" \
                $transmit_plot      ", tx=1" \
                $bathy_plot         ", bath=1" \
                1                   ", winsel=$options(-window)" \
                $rawwf_plot         ", winrx=$rawwf_win" \
                $transmit_plot      ", wintx=$transmit_win" \
                $bathy_plot         ", winbath=$bathy_win" \
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
