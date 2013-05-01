# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::transmit 1.0

namespace eval ::eaarl::transmit {
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

proc ::eaarl::transmit::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::transmit::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::transmit::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::transmit::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::transmit::embed {
    option -window -readonly 1 -default 9 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt

    component window
    component pane

    # Step amount for raster stepping
    variable raststep 2

    variable raster_plot 0
    variable raster_win 11
    variable rawwf_plot 0
    variable rawwf_win 9
    variable bathy_plot 0
    variable bathy_win 8

    # The current window width
    variable win_width 450

    constructor {args} {
        if {[dict exist $args -window]} {
            set win [dict get $args -window]
        } else {
            set win 9
        }
        set window [::yorick::window::path $win]
        $window clear_gui
        $window configure -owner $self

        set pane [$window pane bottom]

        $self Gui
        $window configure -resizecmd [mymethod Resize]

        $self configure {*}$args
    }

    method Resize {width height} {
        if {$width == $win_width} return

        set win_width $width

        pack forget $pane.browse $pane.sync
        if {$win_width > 600} {
            pack $pane.browse $pane.sync \
                -side left -fill x
            pack configure $pane.browse -expand 1
        } else {
            pack $pane.browse $pane.sync \
                -side top -fill x -expand 1
        }
    }

    method Gui {} {
        # Create GUI
        set sections [list browse sync]
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
        ttk::label $f.lblRast -text "Raster:"
        ttk::spinbox $f.spnRast \
                -textvariable [myvar options](-raster) \
                -from 1 -to 100000000 -increment 1 \
                -width 5
        ::mixin::revertable $f.spnRast \
                -command [list $f.spnRast apply] \
                -valuetype number \
                -applycommand [mymethod IdlePlot]
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
                -applycommand [mymethod IdlePlot]
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

        pack $f.lblRast $f.spnRast $f.spnStep $f.btnRastPrev $f.btnRastNext \
                $f.sepRast \
                $f.lblPulse $f.spnPulse \
                $f.sepPulse \
                $f.btnLims $f.btnReplot \
                -side left
        pack $f.spnRast -fill x -expand 1
        pack $f.sepRast $f.sepPulse -fill y -padx 2

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
                raster or raw waveform) if any are selected."
    }

    method Gui_sync {f} {
        foreach type {raster rawwf bathy} {
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
        $f.lblRawwf configure -text "Raw WF:"
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - \
                Transmit Waveform - \
                Raster $options(-raster) Pulse $options(-pulse)"
    }

    method IncrRast {dir} {
        incr options(-raster) [expr {$raststep * $dir}]
        if {$options(-raster) < 1} {
            set options(-raster) 1
        }
        $self plot
    }

    method IdlePlot {old new} {
        ::misc::idle [mymethod plot]
    }

    method limits {} {
        exp_send "window, $options(-window); limits;\r"
    }

    # Returns the command that can be used to (re)plot this window
    method plotcmd {} {
        return "show_wf_transmit,\
                $options(-raster), $options(-pulse),\
                win=$options(-window); "
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]
        append cmd [::eaarl::sync::multicmd \
                -raster $options(-raster) -pulse $options(-pulse) \
                -rast $raster_plot -rastwin $raster_win \
                -bath $bathy_plot -bathwin $bathy_win \
                -rawwf $rawwf_plot -rawwfwin $rawwf_win]
        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}