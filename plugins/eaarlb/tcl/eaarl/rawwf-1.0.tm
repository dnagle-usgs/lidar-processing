# vim: set ts=4 sts=4 sw=4 ai sr et:

package provide eaarl::rawwf 1.0

namespace eval ::eaarl::rawwf {
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

proc ::eaarl::rawwf::plotcmd {window args} {
    set gui [config $window {*}$args]
    return [$gui plotcmd]
}

proc ::eaarl::rawwf::plot {window args} {
    set gui [config $window {*}$args]
    $gui plot
    return $gui
}

proc ::eaarl::rawwf::config {window args} {
    set gui [namespace current]::window_$window
    if {[info commands $gui] ne ""} {
        $gui configure {*}$args
    } else {
        ::eaarl::rawwf::embed $gui {*}$args -window $window
    }
    return $gui
}

snit::type ::eaarl::rawwf::embed {
    option -window -readonly 1 -default 9 -configuremethod SetOpt
    option -raster -default 1 -configuremethod SetOpt
    option -pulse -default 60 -configuremethod SetOpt
    option -channels -default {1 2 3} \
            -configuremethod SetChannels \
            -cgetmethod GetChannels
    option -chan1 -default 1
    option -chan2 -default 1
    option -chan3 -default 1
    option -chan4 -default 0
    option -amp_bias -default 0
    option -range_bias -default 1
    option -tx -default 0
    option -units -default meters

    component window
    component pane

    # Step amount for raster stepping
    variable raststep 2

    variable raster_plot 0
    variable raster_win 11
    variable bathy_plot 0
    variable bathy_win 8
    variable transmit_plot 0
    variable transmit_win 16

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
        ttk::frame $f.fraChannels
        foreach channel {1 2 3 4} {
            # \u2009 is the unicode "thin space" character
            ttk::checkbutton $f.chkChan$channel \
                    -variable [myvar options](-chan$channel) \
                    -style Toolbutton \
                    -text "\u2009$channel\u2009" \
                    -command [mymethod IdlePlot - -]
            tooltip $f.chkChan$channel \
                    "Enable or disable plotting channel $channel"
        }
        grid $f.chkChan1 $f.chkChan2 $f.chkChan3 $f.chkChan4 \
                -in $f.fraChannels -sticky news
        grid columnconfigure $f.fraChannels {0 1 2 3} \
                -weight 1 -uniform 1

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

        pack $f.fraChannels \
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
                raster or raw waveform) if any are selected."
    }

    method Gui_sync {f} {
        foreach type {raster bathy transmit} {
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
    }

    method Gui_settings {f} {
        ttk::checkbutton $f.tx -text "Show transmit above return" \
                -variable [myvar options](-tx) \
                -command [mymethod plot]
        ttk::checkbutton $f.ampbias -text "Remove amplitude bias" \
                -variable [myvar options](-amp_bias) \
                -command [mymethod plot]
        ttk::checkbutton $f.rangebias -text "Remove range bias" \
                -variable [myvar options](-range_bias) \
                -command [mymethod plot]
        ttk::label $f.lblunits -text "Units:"
        ::mixin::combobox $f.units -width 6 \
                -state readonly \
                -values [list ns meters feet] \
                -textvariable [myvar options](-units) \
                -modifycmd [mymethod plot]
        grid $f.ampbias - $f.tx - \
                -sticky w
        grid $f.rangebias - $f.lblunits $f.units \
                -sticky w
        grid configure $f.lblunits -sticky e
        grid columnconfigure $f {0 2} -uniform 1
        grid columnconfigure $f {1 3} -uniform 2 -weight 1
    }

    method SetOpt {option value} {
        set options($option) $value
        $self UpdateTitle
    }

    method SetChannels {option value} {
        set options($option) $value
        foreach channel {1 2 3 4} {
            set chan{$channel} 0
        }
        foreach channel $value {
            set chan{$channel} 1
        }
    }

    method UpdateTitle {} {
        wm title $window "Window $options(-window) - \
                Raw Waveform - \
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
        set cmd ""
        append cmd "show_wf, $options(-raster), $options(-pulse),\
                win=$options(-window), units=\"$options(-units)\""
        appendif cmd \
                $options(-chan1)        ", c1=1" \
                $options(-chan2)        ", c2=1" \
                $options(-chan3)        ", c3=1" \
                $options(-chan4)        ", c4=1" \
                $options(-tx)           ", tx=1" \
                $options(-amp_bias)     ", amp_bias=1" \
                $options(-range_bias)   ", range_bias=1"
        append cmd "; "
        return $cmd
    }

    # (Re)plots the window
    method plot {} {
        set cmd [$self plotcmd]

        if {$raster_plot} {
            append cmd "show_rast, $options(-raster), win=$raster_win,\
                    channel=1, autolims=0; "
        }

        if {$bathy_plot} {
            append cmd [::eaarl::bathconf::plotcmd $bathy_win \
                    -raster $options(-raster) -pulse $options(-pulse)]
        }

        if {$transmit_plot} {
            append cmd "show_wf_transmit, $options(-raster),\
                    $options(-pulse), win=$transmit_win; "
        }

        exp_send "$cmd\r"
    }

    # Used by associated window when resetting the GUI for something else
    method clear_gui {} {
        $self destroy
    }
}
